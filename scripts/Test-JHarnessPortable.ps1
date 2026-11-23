#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PackageRoot,
    [string]$EvidenceRoot,
    [string]$BootstrapScript,
    [string]$PackageArchive,
    [string]$Alpha3PackageRoot
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '_Harness.Common.ps1')
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) { throw 'NATIVE_WINDOWS_POWERSHELL_5_REQUIRED' }
$package=[IO.Path]::GetFullPath($PackageRoot).TrimEnd('\')
$packageManifest=[IO.File]::ReadAllText((Join-HarnessPath $package '.agents/j-harness/manifest.json')) | ConvertFrom-Json
if (-not $EvidenceRoot) { $EvidenceRoot=Join-Path ([IO.Path]::GetTempPath()) ('jh-portable-test-'+[guid]::NewGuid().ToString('N')) }
$lab=[IO.Path]::GetFullPath($EvidenceRoot).TrimEnd('\')
if ($lab -eq [IO.Path]::GetPathRoot($lab) -or (Test-Path -LiteralPath $lab)) { throw 'NEW_EVIDENCE_DIRECTORY_REQUIRED' }
for($cursor=$lab;$cursor;$cursor=[IO.Path]::GetDirectoryName($cursor)) {
    if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'LINK_EVIDENCE_PATH_REFUSED' }
}
[IO.Directory]::CreateDirectory($lab)|Out-Null
$utf8=New-Object Text.UTF8Encoding($false)
function Inside([string]$relative) {
    $target=[IO.Path]::GetFullPath((Join-Path $lab $relative))
    if (-not $target.StartsWith($lab+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'TEST_PATH_ESCAPE' }
    return $target
}
function Write-Utf8([string]$file,[string]$value) { [IO.File]::WriteAllText($file,$value,$utf8) }
function Expect([bool]$condition,[string]$message) { if(-not $condition) { throw $message } }
function Quote([string]$value) { return "'"+$value.Replace("'","''")+"'" }
function Tree([string]$root) {
    if(-not(Test-Path -LiteralPath $root)) { return 'ABSENT' }
    $rows=@(Get-ChildItem -LiteralPath $root -Force -Recurse | Sort-Object FullName | ForEach-Object {
        $name=$_.FullName.Substring($root.Length)
        if($_.PSIsContainer){'D '+$name}else{'F '+$name+' '+(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
    })
    return ($rows -join "`n")
}
$sentinel=Inside 'global home unavailable'
Write-Utf8 $sentinel 'SENTINEL: global home must never be opened as a directory or changed.'
$sentinelHash=(Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash
$native=[IO.Path]::Combine([string[]]@($env:SystemRoot,'System32','WindowsPowerShell','v1.0','powershell.exe'))
$processEnvironment=@{};foreach($name in @('PATH','HOME','USERPROFILE','CODEX_HOME')) { $processEnvironment[$name]=[Environment]::GetEnvironmentVariable($name,'Process') }
$persistentEnvironment=@{};foreach($scope in @('User','Machine')){foreach($name in @('PATH','HOME','USERPROFILE','CODEX_HOME')){$persistentEnvironment[$scope+':'+$name]=[Environment]::GetEnvironmentVariable($name,$scope)}}
$checks=New-Object 'System.Collections.Generic.List[string]'
$runNumber=0
function Run([string]$label,[string]$command,[int]$exitCode=0) {
    $script:runNumber++
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$native
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("`$ErrorActionPreference='Stop'; `$ProgressPreference='SilentlyContinue'; [Console]::OutputEncoding=[Text.UTF8Encoding]::new(`$false); "+$command))
    $info.Arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand '+$encoded
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $info.StandardOutputEncoding=$utf8;$info.StandardErrorEncoding=$utf8
    $info.EnvironmentVariables['PATH']=''
    foreach($name in @('HOME','USERPROFILE','CODEX_HOME')){$info.EnvironmentVariables[$name]=$sentinel}
    $process=New-Object Diagnostics.Process;$process.StartInfo=$info
    $null=$process.Start()
    $stdoutTask=$process.StandardOutput.ReadToEndAsync();$stderrTask=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit(180000)){$process.Kill();throw ('TIMEOUT: '+$label)}
    $stdout=$stdoutTask.Result;$stderr=$stderrTask.Result
    Write-Utf8 (Inside ('{0:D2}-{1}.stdout.txt' -f $script:runNumber,$label)) $stdout
    Write-Utf8 (Inside ('{0:D2}-{1}.stderr.txt' -f $script:runNumber,$label)) $stderr
    Expect ($process.ExitCode -eq $exitCode) ($label+': exit '+$process.ExitCode+' expected '+$exitCode+' '+$stderr)
    if($exitCode -eq 0){return $stdout}else{return $stdout+$stderr}
}
function Installer([string]$project,[string]$action='Plan',[string]$selectedPackage=$package) {
    return '& '+(Quote (Join-Path $selectedPackage 'Install-JHarnessLocal.ps1'))+' -ProjectPath '+(Quote $project)+' -Action '+$action+$(if($action -eq 'Install'){' -ApproveInstall'})
}
function Upgrade([string]$project,[string]$action='Plan') {
    return (Installer $project $action)+' -Upgrade'
}
function Launcher([string]$project,[string]$arguments) { return '& '+(Quote (Join-Path $project 'JHarness.ps1'))+' '+$arguments }
try {
    $project=Inside '한글 프로젝트 with spaces'
    $beforePackage=Tree $package
    $plan=Run 'plan-new' (Installer $project) | ConvertFrom-Json
    Expect ($plan.result -eq 'PLAN_ONLY_NOT_INSTALLED' -and $plan.coreVersion -eq $packageManifest.version -and $plan.productVersion -eq $packageManifest.distributionVersion) 'PLAN_VERSION_OR_RESULT'
    Expect (-not(Test-Path -LiteralPath $project)) 'PLAN_CREATED_PROJECT'
    Expect ((Tree $package) -ceq $beforePackage) 'PLAN_CHANGED_PACKAGE'
    $checks.Add('Plan is read only for absent project and package')
    [IO.Directory]::CreateDirectory($project)|Out-Null
    $guidance=Join-Path $project 'AGENTS.md';$prefix="USER INSTRUCTIONS: preserve these exact bytes.`r`n"
    Write-Utf8 $guidance $prefix
    $beforeProject=Tree $project
    $null=Run 'plan-existing' (Installer $project)
    Expect ((Tree $project) -ceq $beforeProject) 'PLAN_CHANGED_EXISTING_PROJECT'
    $receipt=Run 'install' (Installer $project 'Install') | ConvertFrom-Json
    Expect ($receipt.result -eq 'V8_PROJECT_INSTALL_COMPLETE' -and $receipt.coreVersion -eq $packageManifest.version -and $receipt.productVersion -eq $packageManifest.distributionVersion -and $receipt.globalConnectionRequired -eq $false) 'INSTALL_RECEIPT'
    Expect ([IO.File]::ReadAllText($guidance).StartsWith($prefix,[StringComparison]::Ordinal)) 'USER_GUIDANCE_PREFIX_CHANGED'
    $guidanceHash=(Get-FileHash -LiteralPath $guidance -Algorithm SHA256).Hash
    foreach($command in @('status','doctor')){
        $result=Run $command (Launcher $project $command) | ConvertFrom-Json
        Expect ($result.effective -eq 'READY_LOCAL' -and $result.version -eq $packageManifest.version -and $result.projectBinding -eq 'BOUND_VERIFIED' -and $result.globalConnectionRequired -eq $false) ('COMMAND_FAILED: '+$command)
    }
    $cmd=[IO.Path]::Combine($env:SystemRoot,'System32','cmd.exe')
    $cmdStatus=Run 'cmd-status' ('Set-Location -LiteralPath '+(Quote $project)+'; & '+(Quote $cmd)+' /d /c ".\JHarness.cmd status"; exit $LASTEXITCODE') | ConvertFrom-Json
    Expect ($cmdStatus.effective -eq 'READY_LOCAL') 'CMD_LAUNCHER_FAILED'
    $isolated=Run 'launcher-ignores-ambient-node-options' ('$env:NODE_OPTIONS='+ (Quote '--jh-invalid-test-option') +'; '+(Launcher $project 'doctor')) | ConvertFrom-Json
    Expect ($isolated.runtimeIntegrity -eq 'VERIFIED' -and $isolated.clientGuidance.agents -eq 'MANAGED_BLOCK_PRESENT' -and
        $isolated.clientGuidance.modelApplication -eq 'NOT_OBSERVED') 'LAUNCHER_INHERITED_AMBIENT_NODE_OPTIONS_OR_MISREPORTED_GUIDANCE'
    $checks.Add('Pinned launcher ignores invalid ambient Node options and verifies the canonical project guidance')
    $setup=Run 'setup-repeat' (Launcher $project 'setup') | ConvertFrom-Json
    Expect ($setup.changed -eq $false) 'SETUP_NOT_IDEMPOTENT'
    $repeat=Run 'install-repeat' (Installer $project 'Install') | ConvertFrom-Json
    Expect ($repeat.alreadyPresent -eq $true -and $repeat.guidanceChanged -eq $false) 'INSTALL_NOT_IDEMPOTENT'
    Expect ((Get-FileHash -LiteralPath $guidance -Algorithm SHA256).Hash -ceq $guidanceHash) 'REPEAT_CHANGED_GUIDANCE'
    $checks.Add('Native PS5 install, status, doctor, setup and repeat install with empty PATH and file homes')
    $goal='Verify "quoted goal" and Korean 한국어 arguments'
    $begun=Run 'quoted-goal-begin' (Launcher $project ('begin '+(Quote $goal))) | ConvertFrom-Json
    Expect ($begun.goal -ceq $goal) 'QUOTED_GOAL_CHANGED'
    $null=Run 'quoted-advance-plan' (Launcher $project ('advance plan --note '+(Quote 'Run literal quotes and backslashes through the bundled Windows launcher')))
    $null=Run 'quoted-advance-implement' (Launcher $project 'advance implement')
    $bundledNode=[IO.Path]::Combine([string[]]@($project,'.agents','j-harness','vendor','win-x64','node.exe'))
    $code='console.log("quoted 한국어"); console.log(JSON.stringify(process.argv.slice(1)));'
    $payload='argument "double quote" and spaces'
    $trailing='C:\fixture path\'
    $verifyArguments=@('-e',$code,$payload,$trailing,'')
    # Quote the literal delimiter: native PowerShell consumes a bare -- for script calls.
    $verifyCommand='verify '+(Quote '--')+' '+(Quote $bundledNode)+' '+(($verifyArguments | ForEach-Object {Quote $_}) -join ' ')
    $verified=Run 'quoted-argv-verify' (Launcher $project $verifyCommand) | ConvertFrom-Json
    Expect ($verified.result -eq 'PASS' -and $verified.exitCode -eq 0) 'QUOTED_ARGV_VERIFICATION_FAILED'
    Expect ($verified.arguments.Count -eq $verifyArguments.Count) 'QUOTED_ARGV_COUNT_CHANGED'
    for($index=0;$index -lt $verifyArguments.Count;$index++){
        Expect ([Convert]::ToBase64String($utf8.GetBytes([string]$verified.arguments[$index])) -ceq [Convert]::ToBase64String($utf8.GetBytes($verifyArguments[$index]))) ('QUOTED_ARGV_BYTES_CHANGED: '+$index)
    }
    $stdout=[IO.File]::ReadAllText((Join-Path $verified.logDirectory ($verified.id+'.stdout.txt')))
    $lines=@($stdout.TrimEnd("`r","`n") -split '\r?\n')
    Expect ($lines[0] -ceq 'quoted 한국어') 'QUOTED_CODE_STDOUT_CHANGED'
    $observedArgv=ConvertFrom-Json -InputObject $lines[1]
    Expect ($observedArgv.Count -eq 3 -and $observedArgv[0] -ceq $payload -and $observedArgv[1] -ceq $trailing -and $observedArgv[2] -ceq '') 'EXECUTED_QUOTED_ARGV_CHANGED'
    $progress=Run 'quoted-argv-progress' (Launcher $project 'progress') | ConvertFrom-Json
    Expect ($progress.state.goal -ceq $goal -and $progress.state.verification.argumentCount -eq $verifyArguments.Count -and $progress.state.verification.result -eq 'PASS') 'PERSISTED_QUOTED_VERIFICATION_CHANGED'
    Expect ($null -eq $progress.state.verification.PSObject.Properties['arguments']) 'RAW_ARGV_PERSISTED'
    Expect ($progress.state.verification.runId -eq $begun.runId -and @($progress.events | Where-Object {$_.runId -ne $begun.runId}).Count -eq 0) 'WORKFLOW_CORRELATION_MISSING'
    $checks.Add('Actual workflow preserves quoted goal, UTF8 JavaScript, double quotes, spaces, trailing slash and empty argv bytes')

    $firstProject=Inside '첫 프로젝트'
    $installCommand='& '+(Quote (Join-Path $package 'Install-JHarness.cmd'))+' -ProjectPath '+(Quote $firstProject)+' -ApproveInstall; exit $LASTEXITCODE'
    $firstInstall=Run 'first-project-install-cmd' $installCommand | ConvertFrom-Json
    Expect ($firstInstall.result -eq 'V8_PROJECT_INSTALL_COMPLETE' -and $firstInstall.next -eq '.\JHarness.cmd quickstart') 'FIRST_PROJECT_INSTALL_FAILED'
    $firstBefore=Tree $firstProject
    $badge=Run 'first-project-verified-badge' (Launcher $firstProject 'badge')
    Expect ($badge.Trim() -ceq ('[J Harness v'+$packageManifest.version+']') -and
        (Tree $firstProject) -ceq $firstBefore) 'FIRST_PROJECT_BADGE_FAILED_OR_MUTATED'
    $firstQuickstart=Run 'first-project-quickstart' (Launcher $firstProject 'quickstart')
    Expect ($firstQuickstart.Contains('select codex') -and $firstQuickstart.Contains('select claude') -and
        $firstQuickstart.Contains('select agy') -and (Tree $firstProject) -ceq $firstBefore) 'FIRST_PROJECT_SELECTION_MENU_FAILED'
    $firstSelection=Run 'first-project-select' (Launcher $firstProject 'select claude')
    $firstResume=Run 'first-project-quickstart-resume' (Launcher $firstProject 'quickstart')
    $firstDoctor=Run 'first-project-selection-doctor' (Launcher $firstProject 'doctor') | ConvertFrom-Json
    $firstEnvironment=Run 'first-project-environment' (Launcher $firstProject 'environment plan') | ConvertFrom-Json
    Expect ($firstSelection.Contains('https://code.claude.com/docs/en/quickstart') -and
        $firstResume.Contains('https://code.claude.com/docs/en/quickstart') -and
        $firstDoctor.clientSelection.state -eq 'SELECTED' -and $firstDoctor.clientSelection.client -eq 'claude' -and
        $firstEnvironment.selectedClient -eq 'claude') 'FIRST_PROJECT_SELECTED_CLI_NOT_RESTORED'

    $null=Run 'first-project-begin' (Launcher $firstProject ('begin '+(Quote '숫자 합계 프로그램을 만들고 실행하는 법을 알려줘')))
    $null=Run 'first-project-plan' (Launcher $firstProject ('advance plan --note '+(Quote '2와 3을 넣으면 5가 나오는지 실제로 테스트한다')))
    $null=Run 'first-project-implement' (Launcher $firstProject 'advance implement')
    $app=Join-Path $firstProject 'total.cjs'
    Write-Utf8 $app "module.exports = values => values.reduce((sum, value) => sum + value, 1);"
    Write-Utf8 (Join-HarnessPath $firstProject 'test.cjs') "require('node:assert/strict').equal(require('./total.cjs')([2, 3]), 5); console.log('TOTAL=5');"
    Write-Utf8 (Join-HarnessPath $firstProject 'README.md') 'This sample sums a list of numbers. Run test.cjs using the bundled Node from .agents/j-harness/vendor/win-x64/node.exe and expect TOTAL=5.'
    $firstNode=Join-HarnessPath $firstProject '.agents/j-harness/vendor/win-x64/node.exe'
    $firstVerify='verify '+(Quote '--')+' '+(Quote $firstNode)+' test.cjs'
    $failed=Run 'first-project-failed-test' (Launcher $firstProject $firstVerify) 1 | ConvertFrom-Json
    Expect ($failed.result -eq 'FAIL' -and $failed.exitCode -eq 1) 'FIRST_PROJECT_TEST_FAILURE_NOT_OBSERVED'
    $null=Run 'first-project-failed-handoff' (Launcher $firstProject 'advance handoff') 1
    $null=Run 'first-project-fix-stage' (Launcher $firstProject 'advance implement')
    Write-Utf8 $app "module.exports = values => values.reduce((sum, value) => sum + value, 0);"
    $passed=Run 'first-project-passing-test' (Launcher $firstProject $firstVerify) | ConvertFrom-Json
    Expect ($passed.result -eq 'PASS' -and $passed.exitCode -eq 0 -and $passed.stdoutTail.Trim() -ceq 'TOTAL=5') 'FIRST_PROJECT_RESULT_WRONG'
    $null=Run 'first-project-handoff' (Launcher $firstProject 'advance handoff')
    $finished=Run 'first-project-finish' (Launcher $firstProject 'finish --guide README.md') | ConvertFrom-Json
    Expect ($finished.result -eq 'COMPLETE_LOCAL_VERIFIED' -and $finished.guide -eq 'README.md') 'FIRST_PROJECT_HANDOFF_FAILED'
    $checks.Add('First project uses the documented install command and read-only guidance, then fails, fixes, runs and hands off a local app')

    $relocated=Inside '복사 이동 project'
    Copy-Item -LiteralPath $project -Destination $relocated -Recurse
    $relocatedStatus=Run 'relocated-status' (Launcher $relocated 'status') | ConvertFrom-Json
    Expect ($relocatedStatus.effective -eq 'READY_LOCAL') 'RELOCATION_FAILED'
    $checks.Add('Copied installed project works at another Korean path')
    $core=[IO.Path]::Combine([string[]]@($relocated,'.agents','j-harness','runtime','core','cli.mjs'))
    [IO.File]::AppendAllText($core,"`nthrow Error('DAMAGED_CORE_EXECUTED');",$utf8)
    $damaged=Run 'damaged-runtime' (Launcher $relocated 'status') 1
    Expect ($damaged -match 'HASH_DRIFT|HASH_MISMATCH' -and $damaged -notmatch 'DAMAGED_CORE_EXECUTED') 'DAMAGED_RUNTIME_EXECUTED_OR_ACCEPTED'
    $node=[IO.Path]::Combine([string[]]@($relocated,'.agents','j-harness','vendor','win-x64','node.exe'))
    Move-Item -LiteralPath $node -Destination ($node+'.missing')
    $missing=Run 'missing-bundled-node' (Launcher $relocated 'status') 1
    Expect ($missing -match 'BUNDLED_NODE_REQUIRED_NO_GLOBAL_FALLBACK') 'MISSING_NODE_FELL_BACK'
    # Keep the genuine fixture binary aside and put different bytes at its original path.
    Write-Utf8 $node 'Synthetic invalid executable for the bundled Node hash check.'
    $corruptNode=Run 'corrupt-bundled-node' (Launcher $relocated 'status') 1
    Expect ($corruptNode -match 'BUNDLED_NODE_HASH_MISMATCH_NO_FALLBACK') 'CORRUPT_NODE_NOT_BLOCKED_BEFORE_EXECUTION'
    $checks.Add('Corrupt Core, missing bundled Node and corrupt bundled Node blocked before execution with no fallback')
    $conflict=Inside '사용자 launcher conflict';[IO.Directory]::CreateDirectory($conflict)|Out-Null
    Write-Utf8 (Join-Path $conflict 'JHarness.cmd') 'USER LAUNCHER DO NOT CHANGE'
    $conflictBefore=Tree $conflict
    $blocked=Run 'launcher-conflict' (Installer $conflict 'Install') 1
    Expect ($blocked -match 'EXISTING_USER_FILE_PRESERVED') 'LAUNCHER_CONFLICT_NOT_BLOCKED'
    Expect ((Tree $conflict) -ceq $conflictBefore) 'LAUNCHER_CONFLICT_CHANGED_PROJECT'
    $legacy=Inside '기존 v7 프로젝트';[IO.Directory]::CreateDirectory((Join-Path $legacy '.ai'))|Out-Null
    Write-Utf8 ([IO.Path]::Combine($legacy,'.ai','harness-project.json')) '{"harness":{"version":"7.0.0","product":"AI Harness"},"custom":"preserve"}'
    $legacyBefore=Tree $legacy
    $blocked=Run 'legacy-binding' (Installer $legacy 'Install') 1
    Expect ($blocked -match 'EXISTING_PROJECT_HARNESS_REQUIRES_EXPLICIT_MIGRATION') 'LEGACY_BINDING_NOT_BLOCKED'
    Expect ((Tree $legacy) -ceq $legacyBefore) 'LEGACY_BINDING_CHANGED'
    $checks.Add('User launcher and legacy binding preserved byte for byte')
    $upgradeResult='NOT_RUN_NO_ALPHA3_PACKAGE'
    if($Alpha3PackageRoot){
        $alpha3=[IO.Path]::GetFullPath($Alpha3PackageRoot)
        $alphaManifest=Join-HarnessPath $alpha3 '.agents/j-harness/manifest.json'
        Expect ((Get-FileHash -LiteralPath $alphaManifest -Algorithm SHA256).Hash.ToLowerInvariant() -ceq '8b3f4dc932d92525322cf8b733a518bc16679bec8efe161ac9e3e7e0e4a71224') 'ALPHA3_TEST_MANIFEST_PIN_MISMATCH'
        $old=Inside '알파3'
        [IO.Directory]::CreateDirectory($old)|Out-Null
        $oldGuide=Join-Path $old 'AGENTS.md'
        $oldBinding=Join-HarnessPath $old '.ai/harness-project.json'
        $oldRuntime=Join-HarnessPath $old '.agents/j-harness'
        $artifactDir=Join-HarnessPath $old '.jh-artifacts/j-harness-core'
        $newline=[Environment]::NewLine
        $userPrefix='사용자 규칙: Keep exact CRLF bytes.'+$newline
        $userSuffix=$newline+'추가 규칙: Keep the suffix.'+$newline
        [IO.File]::WriteAllText($oldGuide,$userPrefix,[Text.UTF8Encoding]::new($true))
        $null=Run 'alpha3-install' (Installer $old 'Install' $alpha3)
        [IO.File]::AppendAllText($oldGuide,$userSuffix,$utf8)
        $guideBytes=[IO.File]::ReadAllBytes($oldGuide)
        $originalBinding=[IO.File]::ReadAllText($oldBinding)
        $customBinding=$originalBinding.Replace('"beginner_mode": true','"beginner_mode": false').Replace(
            '"schema_version": 4,','"schema_version": 4, "custom": {"version": "8.0.0-core-beta.1", "large": 9007199254740993, "keep": ["한국어", {"tail": true}]}, "verification_scope": {"include": ["check.cjs"]},')
        Write-Utf8 $oldBinding $customBinding
        Write-Utf8 (Join-Path $old 'check.cjs') "console.log('alpha3 evidence');"
        Write-Utf8 (Join-Path $old 'README.md') 'Run the bundled Node executable with check.cjs and read the local verification result before completing this test.'
        $null=Run 'alpha3-begin' (Launcher $old ('begin '+(Quote 'upgrade preservation test')))
        $activeBefore=Tree $old
        $active=Run 'upgrade-blocks-active-workflow' ((Upgrade $old)+'; exit $LASTEXITCODE') 1
        Expect ($active -match 'ACTIVE_WORKFLOW_BLOCKS_UPGRADE' -and (Tree $old) -ceq $activeBefore) 'ACTIVE_UPGRADE_NOT_BLOCKED'
        $null=Run 'alpha3-plan' (Launcher $old ('advance plan --note '+(Quote 'Run the local fixture')))
        $null=Run 'alpha3-implement' (Launcher $old 'advance implement')
        $oldNode=Join-HarnessPath $oldRuntime 'vendor/win-x64/node.exe'
        $null=Run 'alpha3-verify' (Launcher $old ('verify '+(Quote '--')+' '+(Quote $oldNode)+' check.cjs'))
        $null=Run 'alpha3-handoff' (Launcher $old 'advance handoff')
        $oldState=Run 'alpha3-finish' (Launcher $old 'finish') | ConvertFrom-Json
        $stateHash=(Get-FileHash -LiteralPath (Join-Path $artifactDir 'workflow.json')).Hash
        $eventsHash=(Get-FileHash -LiteralPath (Join-Path $artifactDir 'events.jsonl')).Hash
        $oldLogs=Tree (Join-Path $artifactDir 'logs')
        $productBefore=(Get-FileHash -LiteralPath (Join-Path $old 'check.cjs')).Hash
        Write-Utf8 (Join-Path $artifactDir 'lessons.json') '[{"cause":"keep this historical note"}]'
        $lessonHash=(Get-FileHash -LiteralPath (Join-Path $artifactDir 'lessons.json')).Hash

        $oldTree=Tree $old
        $plan=Run 'upgrade-plan-readonly' (Upgrade $old) | ConvertFrom-Json
        Expect ($plan.result -eq 'PLAN_ONLY_NOT_UPGRADED' -and $plan.previousProductVersion -eq '8.0.0-alpha.3' -and
            $plan.productVersion -eq $packageManifest.distributionVersion -and (Tree $old) -ceq $oldTree) 'UPGRADE_PLAN_MUTATED_OR_WRONG'
        $oldReadme=Join-Path $old 'JHarness-README.md'
        $readmeBytes=[IO.File]::ReadAllBytes($oldReadme)
        [IO.File]::AppendAllText($oldReadme,$newline+'User-managed text',$utf8)
        $customReadme=(Get-FileHash -LiteralPath $oldReadme).Hash
        $conflict=Run 'upgrade-blocks-user-launcher-conflict' ((Upgrade $old)+'; exit $LASTEXITCODE') 1
        Expect ($conflict -match 'CUSTOM_LAUNCHER_REQUIRES_REVIEW' -and (Get-FileHash -LiteralPath $oldReadme).Hash -ceq $customReadme) 'UPGRADE_LAUNCHER_CONFLICT_DISCARDED'
        [IO.File]::WriteAllBytes($oldReadme,$readmeBytes)

        # The old runtime ignores this malformed future setting. The new doctor
        # rejects it after activation, which exercises a real rollback.
        $badBinding=$customBinding.Replace('"schema_version": 4,','"schema_version": 4, "supervisor": {"required": "invalid"},')
        Write-Utf8 $oldBinding $badBinding
        $oldPayload=Tree $oldRuntime
        $rollback=Run 'upgrade-fails-post-activation-and-restores' ((Upgrade $old 'Install')+'; exit $LASTEXITCODE') 1
        Expect ($rollback -match 'SUPERVISOR_REQUIRED_MUST_BE_BOOLEAN' -and $rollback -match 'ALPHA3_RESTORED_VERIFIED') 'UPGRADE_ROLLBACK_NOT_VERIFIED'
        Expect ((Tree $oldRuntime) -ceq $oldPayload -and [IO.File]::ReadAllText($oldBinding) -ceq $badBinding -and
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($oldGuide)) -ceq [Convert]::ToBase64String($guideBytes) -and
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($oldReadme)) -ceq [Convert]::ToBase64String($readmeBytes)) 'UPGRADE_ROLLBACK_RESTORED_WRONG_BYTES'
        Write-Utf8 $oldBinding $customBinding

        $receipt=Run 'upgrade-apply' (Upgrade $old 'Install') | ConvertFrom-Json
        Expect ($receipt.result -eq 'V8_PROJECT_UPGRADE_COMPLETE' -and $receipt.effective -eq 'READY_LOCAL') 'UPGRADE_APPLY_FAILED'
        $backup=[IO.Path]::GetFullPath((Join-Path $old $receipt.transaction))
        Expect ($backup.StartsWith($old+'\',[StringComparison]::OrdinalIgnoreCase) -and (Tree (Join-HarnessPath $backup 'previous-runtime')) -ceq $oldPayload) 'UPGRADE_PREVIOUS_RUNTIME_NOT_PRESERVED'
        $expectedBinding=$customBinding.Replace('"version": "8.0.0-core-beta.1",'+[char]10,'"version": "'+$receipt.coreVersion+'",'+[char]10)
        $expectedBinding=$expectedBinding.Replace($receipt.previousManifestSha256,$receipt.manifestSha256)
        Expect ([IO.File]::ReadAllText($oldBinding) -ceq $expectedBinding) 'UPGRADE_UNMANAGED_BINDING_BYTES_CHANGED'
        $newGuide=[IO.File]::ReadAllBytes($oldGuide)
        $pattern='(?s)<!-- J-HARNESS-PORTABLE:START -->.*?<!-- J-HARNESS-PORTABLE:END -->'
        $canonical=[regex]::Match([IO.File]::ReadAllText($guidance),$pattern)
        Expect ($canonical.Success -and $canonical.Value.Contains('[J Harness v'+$receipt.coreVersion+']')) 'FRESH_BRIDGE_MISSING_BADGE'
        $expectedGuide=[regex]::Replace([Text.Encoding]::UTF8.GetString($guideBytes),$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m) $canonical.Value})
        Expect ([Text.Encoding]::UTF8.GetString($newGuide) -ceq $expectedGuide) 'UPGRADE_UNMANAGED_GUIDANCE_BYTES_CHANGED'
        Expect ((Get-FileHash -LiteralPath (Join-Path $artifactDir 'workflow.json')).Hash -ceq $stateHash -and
            (Get-FileHash -LiteralPath (Join-Path $artifactDir 'events.jsonl')).Hash -ceq $eventsHash -and
            (Get-FileHash -LiteralPath (Join-Path $artifactDir 'lessons.json')).Hash -ceq $lessonHash -and
            (Tree (Join-Path $artifactDir 'logs')) -ceq $oldLogs -and
            (Get-FileHash -LiteralPath (Join-Path $old 'check.cjs')).Hash -ceq $productBefore) 'UPGRADE_WORKFLOW_OR_PRODUCT_CHANGED'
        $progress=Run 'upgrade-preserved-progress' (Launcher $old 'progress') | ConvertFrom-Json
        Expect ($progress.state.runId -eq $oldState.runId -and $progress.currentVerificationResult -eq 'STALE' -and
            $progress.staleVerificationReason -eq 'RUNTIME_CHANGED_PREVIOUS_PASS_INVALID') 'PREVIOUS_VERIFICATION_NOT_STALE_AFTER_UPGRADE'
        $upgraded=Tree $old
        $repeat=Run 'upgrade-repeat' (Upgrade $old 'Install') | ConvertFrom-Json
        Expect ($repeat.result -eq 'ALREADY_CURRENT' -and (Tree $old) -ceq $upgraded) 'UPGRADE_REPEAT_CHANGED_FILES'

        # Model a process interrupted after swapping files and before recording
        # success. Use the real prepared journal and exact activated bytes.
        Move-Item -LiteralPath (Join-Path $backup 'receipt.json') -Destination (Join-Path $backup 'test-completed-receipt.json')
        $upgradeLock=Join-Path (Split-Path -Parent $backup) 'upgrade.lock'
        $lockRun=Split-Path -Leaf $backup
        Write-Utf8 $upgradeLock (@{run=$lockRun;pid=$PID}|ConvertTo-Json -Compress)
        $recoverCommand=(Upgrade $old 'Recover')+' -ApproveInstall'
        $live=Run 'upgrade-recovery-blocks-live-process' ($recoverCommand+'; exit $LASTEXITCODE') 1
        Expect ($live -match 'UPGRADE_PROCESS_STILL_RUNNING') 'LIVE_UPGRADE_RECOVERY_NOT_BLOCKED'
        Write-Utf8 $upgradeLock (@{run=$lockRun;pid=2147483647}|ConvertTo-Json -Compress)
        $recovery=Run 'upgrade-recovers-interrupted-activation' $recoverCommand | ConvertFrom-Json
        Expect ($recovery.result -eq 'ALPHA3_RESTORED_VERIFIED' -and -not(Test-Path -LiteralPath $upgradeLock) -and
            (Tree $oldRuntime) -ceq $oldPayload -and [IO.File]::ReadAllText($oldBinding) -ceq $customBinding -and
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($oldGuide)) -ceq [Convert]::ToBase64String($guideBytes) -and
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($oldReadme)) -ceq [Convert]::ToBase64String($readmeBytes)) 'INTERRUPTED_UPGRADE_RECOVERY_FAILED'
        $upgradeResult='PASS_ALPHA3_UPGRADE_ROLLBACK_AND_INTERRUPTED_ACTIVATION_RECOVERY'
        $checks.Add('Pinned Alpha 3 upgrade preserves user bytes and work records, blocks active work and drift, and is idempotent')
        $checks.Add('Doctor failure automatically restores Alpha 3; journal recovery refuses a live process and restores a simulated interrupted activation')
    }
    $bootstrapResult='NOT_RUN_LOCAL_PACKAGE_TEST'
    if($BootstrapScript -or $PackageArchive){
        Expect ([bool]$BootstrapScript -and [bool]$PackageArchive) 'BOOTSTRAP_SCRIPT_AND_ARCHIVE_REQUIRED_TOGETHER'
        $bootstrap=[IO.Path]::GetFullPath($BootstrapScript);$archive=[IO.Path]::GetFullPath($PackageArchive)
        $bootstrapProject=Inside '기본 설치 bootstrap project'
        $bootstrapCommand='& '+(Quote $bootstrap)+' -ProjectPath '+(Quote $bootstrapProject)+' -PackagePath '+(Quote $archive)
        $bootstrapPlan=Run 'bootstrap-plan' ($bootstrapCommand+' -Action Plan') | ConvertFrom-Json
        Expect ($bootstrapPlan.result -eq 'PLAN_ONLY_NOT_INSTALLED' -and -not(Test-Path -LiteralPath $bootstrapProject)) 'BOOTSTRAP_PLAN_MUTATED_PROJECT'
        Expect ($bootstrapPlan.sha256 -ceq (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()) 'BOOTSTRAP_RELEASE_PIN_DOES_NOT_MATCH_BUILT_ZIP'
        $bootstrapInstall=Run 'bootstrap-offline-install' ($bootstrapCommand+' -Action Install -ApproveInstall') | ConvertFrom-Json
        Expect ($bootstrapInstall.result -eq 'V8_PROJECT_INSTALL_COMPLETE' -and $bootstrapInstall.effective -eq 'READY_LOCAL') 'BOOTSTRAP_INSTALL_FAILED'
        $wrongZip=Inside 'wrong-hash.zip';Write-Utf8 $wrongZip 'UNTRUSTED ZIP MUST NEVER BE EXTRACTED'
        $wrongProject=Inside 'wrong ZIP untouched project'
        $wrongCommand='& '+(Quote $bootstrap)+' -ProjectPath '+(Quote $wrongProject)+' -PackagePath '+(Quote $wrongZip)+' -Action Install -ApproveInstall; exit $LASTEXITCODE'
        $wrongResult=Run 'bootstrap-wrong-zip' $wrongCommand 2
        Expect ($wrongResult -match 'V8_PACKAGE_SHA256_MISMATCH_NO_FALLBACK' -and -not(Test-Path -LiteralPath $wrongProject)) 'WRONG_ZIP_ACCEPTED_OR_CREATED_PROJECT'
        $bootstrapResult='PASS_PINNED_OFFLINE_DEFAULT_BOOTSTRAP_NETWORK_NOT_RUN'
        $checks.Add('Default bootstrap installs pinned ZIP offline and refuses wrong ZIP hash before creating project')
        if($Alpha3PackageRoot){
            $bootstrapUpgrade='& '+(Quote $bootstrap)+' -ProjectPath '+(Quote $old)+' -PackagePath '+(Quote $archive)+' -Upgrade'
            $beforeBootstrapUpgrade=Tree $old
            $preview=Run 'bootstrap-upgrade-plan' ($bootstrapUpgrade+' -Action Plan') | ConvertFrom-Json
            Expect ($preview.result -eq 'PLAN_ONLY_NOT_UPGRADED' -and $preview.previousProductVersion -eq '8.0.0-alpha.3' -and
                (Tree $old) -ceq $beforeBootstrapUpgrade) 'BOOTSTRAP_UPGRADE_PLAN_MUTATED_OR_WRONG'
            $updated=Run 'bootstrap-upgrade-apply' ($bootstrapUpgrade+' -Action Install -ApproveInstall') | ConvertFrom-Json
            Expect ($updated.result -eq 'V8_PROJECT_UPGRADE_COMPLETE' -and $updated.productVersion -eq $packageManifest.distributionVersion) 'BOOTSTRAP_UPGRADE_FAILED'
            $bootstrapBackup=Join-Path $old $updated.transaction
            Move-Item -LiteralPath (Join-Path $bootstrapBackup 'receipt.json') -Destination (Join-Path $bootstrapBackup 'test-completed-receipt.json')
            Write-Utf8 $upgradeLock (@{run=(Split-Path -Leaf $bootstrapBackup);pid=2147483647}|ConvertTo-Json -Compress)
            $bootstrapRecover=Run 'bootstrap-upgrade-recover' ($bootstrapUpgrade+' -Action Recover -ApproveInstall') | ConvertFrom-Json
            Expect ($bootstrapRecover.result -eq 'ALPHA3_RESTORED_VERIFIED' -and (Tree $oldRuntime) -ceq $oldPayload -and
                (Get-FileHash -LiteralPath (Join-Path $old 'check.cjs')).Hash -ceq $productBefore) 'BOOTSTRAP_RECOVERY_DID_NOT_RESTORE_PREVIOUS_RUNTIME'
            $checks.Add('Default bootstrap upgrades and recovers Alpha 3 through one pinned ZIP entry point')
        }
    }
    Expect ((Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash -ceq $sentinelHash) 'GLOBAL_HOME_SENTINEL_CHANGED'
    foreach($name in $processEnvironment.Keys){Expect ([Environment]::GetEnvironmentVariable($name,'Process') -ceq $processEnvironment[$name]) ('PROCESS_ENV_CHANGED: '+$name)}
    foreach($scope in @('User','Machine')){foreach($name in @('PATH','HOME','USERPROFILE','CODEX_HOME')){Expect ([Environment]::GetEnvironmentVariable($name,$scope) -ceq $persistentEnvironment[$scope+':'+$name]) ('PERSISTENT_ENV_CHANGED: '+$scope+':'+$name)}}
    Expect ((Tree $package) -ceq $beforePackage) 'PACKAGE_CHANGED_DURING_INSTALL'
    $checks.Add('No package, global home, process or persistent environment changes')
    $summary=[ordered]@{result='PASS';powershell=$PSVersionTable.PSVersion.ToString();checks=@($checks.ToArray());evidence=$lab;rollbackAfterSetup='NOT_RUN';networkBootstrap=$bootstrapResult;upgrade=$upgradeResult}
    Write-Utf8 (Inside 'summary.json') ($summary|ConvertTo-Json -Depth 6)
    $summary|ConvertTo-Json -Depth 6
} catch {
    Write-Utf8 (Inside 'failure.txt') ($_|Out-String)
    Write-Error ('PORTABLE_TEST_FAILED; evidence preserved: '+$lab+'; '+$_.Exception.Message)
    exit 1
}
# All isolated evidence, including failed attempts, remains available for review.
exit 0
