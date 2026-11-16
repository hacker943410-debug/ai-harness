#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PackageRoot,
    [string]$EvidenceRoot,
    [string]$BootstrapScript,
    [string]$PackageArchive
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) { throw 'NATIVE_WINDOWS_POWERSHELL_5_REQUIRED' }
$package=[IO.Path]::GetFullPath($PackageRoot).TrimEnd('\')
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
function Launcher([string]$project,[string]$arguments) { return '& '+(Quote (Join-Path $project 'JHarness.ps1'))+' '+$arguments }
try {
    $project=Inside '한글 프로젝트 with spaces'
    $beforePackage=Tree $package
    $plan=Run 'plan-new' (Installer $project) | ConvertFrom-Json
    Expect ($plan.result -eq 'PLAN_ONLY_NOT_INSTALLED' -and $plan.coreVersion -eq '8.0.0-core-beta.1') 'PLAN_VERSION_OR_RESULT'
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
    Expect ($receipt.result -eq 'V8_PROJECT_INSTALL_COMPLETE' -and $receipt.coreVersion -eq '8.0.0-core-beta.1' -and $receipt.globalConnectionRequired -eq $false) 'INSTALL_RECEIPT'
    Expect ([IO.File]::ReadAllText($guidance).StartsWith($prefix,[StringComparison]::Ordinal)) 'USER_GUIDANCE_PREFIX_CHANGED'
    $guidanceHash=(Get-FileHash -LiteralPath $guidance -Algorithm SHA256).Hash
    foreach($command in @('status','doctor')){
        $result=Run $command (Launcher $project $command) | ConvertFrom-Json
        Expect ($result.effective -eq 'READY_LOCAL' -and $result.version -eq '8.0.0-core-beta.1' -and $result.globalConnectionRequired -eq $false) ('COMMAND_FAILED: '+$command)
    }
    $cmd=[IO.Path]::Combine($env:SystemRoot,'System32','cmd.exe')
    $cmdStatus=Run 'cmd-status' ('Set-Location -LiteralPath '+(Quote $project)+'; & '+(Quote $cmd)+' /d /c ".\JHarness.cmd status"; exit $LASTEXITCODE') | ConvertFrom-Json
    Expect ($cmdStatus.effective -eq 'READY_LOCAL') 'CMD_LAUNCHER_FAILED'
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
    Expect ($progress.state.goal -ceq $goal -and $progress.state.verification.arguments[1] -ceq $code -and $progress.state.verification.result -eq 'PASS') 'PERSISTED_QUOTED_VERIFICATION_CHANGED'
    $checks.Add('Actual workflow preserves quoted goal, UTF8 JavaScript, double quotes, spaces, trailing slash and empty argv bytes')
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
    Move-Item -LiteralPath ($node+'.missing') -Destination $node
    $binaryStream=[IO.File]::Open($node,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try{$firstByte=$binaryStream.ReadByte();$binaryStream.Position=0;$binaryStream.WriteByte([byte]($firstByte -bxor 255))}finally{$binaryStream.Dispose()}
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
    }
    Expect ((Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash -ceq $sentinelHash) 'GLOBAL_HOME_SENTINEL_CHANGED'
    foreach($name in $processEnvironment.Keys){Expect ([Environment]::GetEnvironmentVariable($name,'Process') -ceq $processEnvironment[$name]) ('PROCESS_ENV_CHANGED: '+$name)}
    foreach($scope in @('User','Machine')){foreach($name in @('PATH','HOME','USERPROFILE','CODEX_HOME')){Expect ([Environment]::GetEnvironmentVariable($name,$scope) -ceq $persistentEnvironment[$scope+':'+$name]) ('PERSISTENT_ENV_CHANGED: '+$scope+':'+$name)}}
    Expect ((Tree $package) -ceq $beforePackage) 'PACKAGE_CHANGED_DURING_INSTALL'
    $checks.Add('No package, global home, process or persistent environment changes')
    $summary=[ordered]@{result='PASS';powershell=$PSVersionTable.PSVersion.ToString();checks=@($checks.ToArray());evidence=$lab;rollbackAfterSetup='NOT_RUN';networkBootstrap=$bootstrapResult}
    Write-Utf8 (Inside 'summary.json') ($summary|ConvertTo-Json -Depth 6)
    $summary|ConvertTo-Json -Depth 6
} catch {
    Write-Utf8 (Inside 'failure.txt') ($_|Out-String)
    Write-Error ('PORTABLE_TEST_FAILED; evidence preserved: '+$lab+'; '+$_.Exception.Message)
    exit 1
}
# All isolated evidence, including failed attempts, remains available for review.
