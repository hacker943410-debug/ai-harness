#Requires -Version 5.1
[CmdletBinding()]
param([string]$HarnessRoot, [switch]$KeepFixtures)
if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Common.ps1')
. (Join-Path $PSScriptRoot '_Harness.Skill.ps1')
$harness = (Resolve-Path -LiteralPath $HarnessRoot).Path
$fixture = Join-HarnessPath ([IO.Path]::GetTempPath()) ('h51-' + [Guid]::NewGuid().ToString('N').Substring(0, 6))
New-Item -ItemType Directory -Path $fixture | Out-Null
$results = [System.Collections.Generic.List[object]]::new()
function Assert-True([bool]$Value, [string]$Message) { if (-not $Value) { throw $Message } }
function Test-Case([string]$Name, [scriptblock]$Body) {
    try { & $Body; $results.Add([pscustomobject]@{ name = $Name; result = 'PASS' }); Write-Output "PASS $Name" }
    catch { $results.Add([pscustomobject]@{ name = $Name; result = 'FAIL' }); Write-Output "FAIL $Name : $($_.Exception.Message)" }
}
function Git-Test([string[]]$Arguments) {
    $output = @(& git @Arguments 2>&1 | ForEach-Object { $_.ToString() })
    if ($LASTEXITCODE -ne 0) { throw ('Fixture git command failed: ' + ($output -join ' ')) }
    return ($output -join [Environment]::NewLine)
}
function Commit-Test([string]$Path, [string]$Message) {
    $null = Git-Test @('-C', $Path, 'add', '.')
    $null = Git-Test @('-C', $Path, '-c', 'user.name=Harness Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', $Message)
    return Git-Test @('-C', $Path, 'rev-parse', 'HEAD')
}
# Load functions only: never run the bootstrap's network entrypoint.
$parseErrors = $null; $tokens = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-HarnessPath $harness 'install.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw 'Bootstrap parse failed.' }
foreach ($definition in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
    . ([scriptblock]::Create($definition.Extent.Text))
}
$script:realGit = (Get-Item Function:Invoke-HarnessGit).ScriptBlock
$script:failureMode = ''
function Invoke-HarnessGit {
    param([string[]]$Arguments)
    if (($script:failureMode -eq 'fetch' -and $Arguments -contains 'fetch') -or ($script:failureMode -eq 'merge' -and $Arguments -contains 'merge')) {
        return [pscustomobject]@{ ExitCode = 1; Output = @('Injected local failure') }
    }
    & $script:realGit -Arguments $Arguments
}
$RepoWeb = 'local fixture'
$sourceRepo = Join-HarnessPath $fixture 'source'
$RepoUrl = Join-HarnessPath $fixture 'origin.git'
$null = Git-Test @('init', '-q', '-b', 'main', $sourceRepo)
New-Item -ItemType Directory -Path (Join-HarnessPath $sourceRepo 'scripts') | Out-Null
$stub = Join-HarnessPath $sourceRepo 'scripts' 'Test-HarnessRepo.ps1'
Write-HarnessText $stub "param([string]$([char]36)HarnessRoot) exit 0"
Write-HarnessText (Join-HarnessPath $sourceRepo 'marker.txt') 'first'
$first = Commit-Test $sourceRepo 'first'
$null = Git-Test @('-C', $sourceRepo, 'tag', 'fixture-v1')
$null = Git-Test @('clone', '-q', '--bare', $sourceRepo, $RepoUrl)
$stale = Join-HarnessPath $fixture 'stale'
$dev = Join-HarnessPath $fixture 'dev'
$null = Git-Test @('clone', '-q', $RepoUrl, $stale)
$null = Git-Test @('-C', $stale, 'checkout', '-q', '--detach', $first)
$null = Git-Test @('clone', '-q', $RepoUrl, $dev)
Write-HarnessText (Join-HarnessPath $sourceRepo 'marker.txt') 'second'
$second = Commit-Test $sourceRepo 'second'
$null = Git-Test @('-C', $sourceRepo, 'push', '-q', $RepoUrl, 'main')

function Bootstrap-Test([string]$Path, [string]$Ref = 'main', [switch]$FailureExpected) {
    $script:lastBootstrapOutput = @()
    $failed = $false
    try { Invoke-HarnessBootstrap -Path $Path -Ref $Ref -SkipChecks | ForEach-Object { $script:lastBootstrapOutput += "$_" } }
    catch { $failed = $true; $script:lastBootstrapError = $_.Exception.Message }
    Assert-True ($failed -eq [bool]$FailureExpected) ("Bootstrap failure status was wrong: " + $script:lastBootstrapError)
    if ($FailureExpected) {
        Assert-True (-not ($script:lastBootstrapOutput -match '받았습니다')) 'Failure printed success guidance.'
    }
}
Test-Case 'default clone uses remote main and detached HEAD' {
    $path = Join-HarnessPath $fixture 'new'
    Bootstrap-Test $path
    Assert-True ((Git-Test @('-C', $path, 'rev-parse', 'HEAD')) -eq $second) 'Wrong default HEAD.'
    Assert-True ((Git-Test @('-C', $path, 'rev-parse', '--abbrev-ref', 'HEAD')) -eq 'HEAD') 'New consumption install is on a branch.'
}
Test-Case 'detached update ignores stale local main' {
    Bootstrap-Test $stale
    Assert-True ((Git-Test @('-C', $stale, 'rev-parse', 'HEAD')) -eq $second) 'Stale local main was used.'
}
Test-Case 'dirty untracked file blocks update and preserves bytes' {
    $path = Join-HarnessPath $stale 'plan.json'
    Write-HarnessText $path '{"fixture":true}'
    $before = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    Bootstrap-Test $stale -FailureExpected
    Assert-True ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $before) 'Untracked file changed.'
    Assert-True ((Git-Test @('-C', $stale, 'rev-parse', 'HEAD')) -eq $second) 'Dirty HEAD changed.'
    Remove-Item -LiteralPath $path
}
Test-Case 'fetch failure preserves HEAD and stops success' {
    $script:failureMode = 'fetch'
    try { Bootstrap-Test $stale -FailureExpected } finally { $script:failureMode = '' }
    Assert-True ((Git-Test @('-C', $stale, 'rev-parse', 'HEAD')) -eq $second) 'HEAD changed on fetch failure.'
}
Test-Case 'merge failure preserves development branch' {
    $script:failureMode = 'merge'
    try { Bootstrap-Test $dev -FailureExpected } finally { $script:failureMode = '' }
    Assert-True ((Git-Test @('-C', $dev, 'rev-parse', 'HEAD')) -eq $first) 'Failed merge changed HEAD.'
}
Test-Case 'development branch fast-forwards and stays on its branch' {
    Bootstrap-Test $dev 'fixture-v1'
    Assert-True ((Git-Test @('-C', $dev, 'rev-parse', 'HEAD')) -eq $second) 'Branch did not fast-forward.'
    Assert-True ((Git-Test @('-C', $dev, 'rev-parse', '--abbrev-ref', 'HEAD')) -eq 'main') 'Branch was detached.'
}
Test-Case 'local ahead branch is preserved' {
    Write-HarnessText (Join-HarnessPath $dev 'local.txt') 'local'
    $ahead = Commit-Test $dev 'local'
    Bootstrap-Test $dev -FailureExpected
    Assert-True ((Git-Test @('-C', $dev, 'rev-parse', 'HEAD')) -eq $ahead) 'Local commit was lost.'
}
Test-Case 'tag pin selects exact detached commit' {
    Bootstrap-Test $stale 'fixture-v1'
    Assert-True ((Git-Test @('-C', $stale, 'rev-parse', 'HEAD')) -eq $first) 'Tag pin was not honored.'
}
Test-Case 'full commit SHA works for a new install' {
    $path = Join-HarnessPath $fixture 'sha'
    Bootstrap-Test $path $first
    Assert-True ((Git-Test @('-C', $path, 'rev-parse', 'HEAD')) -eq $first) 'Full SHA was not honored.'
}
Test-Case 'unavailable full SHA fails without fallback' {
    Bootstrap-Test $stale ('0' * 40) -FailureExpected
    Assert-True ((Git-Test @('-C', $stale, 'rev-parse', 'HEAD')) -eq $first) 'Invalid SHA fell back.'
}
Test-Case 'ambiguous tag and branch require an explicit ref' {
    $null = Git-Test @('-C', $sourceRepo, 'branch', 'fixture-v1')
    $null = Git-Test @('-C', $sourceRepo, 'push', '-q', $RepoUrl, 'refs/heads/fixture-v1')
    Bootstrap-Test $stale 'fixture-v1' -FailureExpected
    Bootstrap-Test $stale 'refs/tags/fixture-v1'
    Assert-True ((Git-Test @('-C', $stale, 'rev-parse', 'HEAD')) -eq $first) 'Explicit tag resolved incorrectly.'
    Bootstrap-Test $stale 'refs/heads/fixture-v1'
    Assert-True ((Git-Test @('-C', $stale, 'rev-parse', 'HEAD')) -eq $second) 'Explicit branch resolved incorrectly.'
}
Test-Case 'repository checker failure blocks success' {
    Write-HarnessText $stub "param([string]$([char]36)HarnessRoot) exit 1"
    $null = Commit-Test $sourceRepo 'failing checker'
    $null = Git-Test @('-C', $sourceRepo, 'push', '-q', $RepoUrl, 'main')
    Bootstrap-Test (Join-HarnessPath $fixture 'badcheck') -FailureExpected
}
Test-Case 'missing repository checker blocks success' {
    Remove-Item -LiteralPath $stub
    $null = Commit-Test $sourceRepo 'missing checker'
    $null = Git-Test @('-C', $sourceRepo, 'push', '-q', $RepoUrl, 'main')
    Bootstrap-Test (Join-HarnessPath $fixture 'nocheck') -FailureExpected
}

$project = Join-HarnessPath $fixture '한글프로젝트'
New-Item -ItemType Directory -Path $project | Out-Null
$installer = Join-HarnessPath $harness 'scripts' 'Install-ProjectSkill.ps1'
$validator = Join-HarnessPath $harness 'scripts' 'Test-ProjectCapabilities.ps1'
$lockPath = Join-HarnessPath $project '.ai' 'capability-lock.json'
function Install-Test { & $installer -Id dashboard-builder -ProjectRoot $project -HarnessRoot $harness @args | Out-Null }
function Check-Test { & $validator -ProjectRoot $project -HarnessRoot $harness }
Test-Case 'WhatIf leaves a Korean project and environment unchanged' {
    $location = (Get-Location).Path; $telemetry = $env:DISABLE_TELEMETRY
    Install-Test -WhatIf
    Assert-True (@(Get-ChildItem -LiteralPath $project -Force).Count -eq 0) 'WhatIf wrote project files.'
    Assert-True ((Get-Location).Path -eq $location -and $env:DISABLE_TELEMETRY -eq $telemetry) 'WhatIf changed environment or cwd.'
}
Test-Case 'AllNative installs two unique destinations with full hashes' {
    Install-Test
    $lock = Read-HarnessJson $lockPath
    $record = @($lock.capabilities)[0]
    Assert-True (@($record.config_path -split ';').Count -eq 2) 'Shared Codex/AGY destination was not deduplicated.'
    Assert-True (Test-Path -LiteralPath (Join-HarnessPath $project '.agents' 'skills' 'dashboard-builder' 'SKILL.md')) 'Codex path is incorrect.'
    Assert-True ((Check-Test).overall -eq 'PASS') 'Fresh install failed verification.'
    & node (Join-HarnessPath $harness 'scripts' 'harness-schema-validate.mjs') --schema (Join-HarnessPath $harness 'schemas' 'capability-lock.schema.json') $lockPath | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) 'Generated lock does not conform to its schema.'
}
$cleanLock = [IO.File]::ReadAllBytes($lockPath)
$nativePath = Join-HarnessPath $project '.agents' 'skills' 'dashboard-builder'
$reference = @(Get-ChildItem -LiteralPath (Join-HarnessPath $nativePath 'references') -File)[0].FullName
$cleanReference = [IO.File]::ReadAllBytes($reference)
Test-Case 'reference tampering is detected and overwrite requires Force' {
    Write-HarnessText $reference 'local modification'
    Assert-True ((Check-Test).overall -eq 'FAIL') 'Reference tampering was missed.'
    $before = (Get-FileHash -LiteralPath $reference -Algorithm SHA256).Hash
    $failed = $false
    try { Install-Test } catch { $failed = $true }
    Assert-True $failed 'Modified Skill was overwritten without Force.'
    Assert-True ((Get-FileHash -LiteralPath $reference -Algorithm SHA256).Hash -eq $before) 'Modified reference was lost.'
    Assert-True ([Convert]::ToBase64String([IO.File]::ReadAllBytes($lockPath)) -eq [Convert]::ToBase64String($cleanLock)) 'Refusal changed the lock.'
}
Test-Case 'multi-client move failure restores originals and the lock' {
    $beforeAgents = (Get-HarnessSkillManifest $nativePath).Hash
    $claudePath = Join-HarnessPath $project '.claude' 'skills' 'dashboard-builder'
    $beforeClaude = (Get-HarnessSkillManifest $claudePath).Hash
    function Move-Item {
        [CmdletBinding()]param([string]$LiteralPath, [string]$Destination)
        if ((Split-Path -Leaf $LiteralPath) -eq 'stage-1') { throw 'Injected second target failure' }
        Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination
    }
    $failed = $false
    try { Install-Test -Force } catch { $failed = $true } finally { Remove-Item Function:Move-Item }
    Assert-True $failed 'Injected replacement failure was ignored.'
    Assert-True ((Get-HarnessSkillManifest $nativePath).Hash -eq $beforeAgents) 'Agents Skill was not restored.'
    Assert-True ((Get-HarnessSkillManifest $claudePath).Hash -eq $beforeClaude) 'Claude Skill was not restored.'
    Assert-True ([Convert]::ToBase64String([IO.File]::ReadAllBytes($lockPath)) -eq [Convert]::ToBase64String($cleanLock)) 'Rollback changed lock bytes.'
}
Test-Case 'Force replacement succeeds and leaves no transaction directory' {
    Install-Test -Force
    Assert-True ((Check-Test).overall -eq 'PASS') 'Forced install failed verification.'
    Assert-True (@(Get-ChildItem -LiteralPath (Join-HarnessPath $project '.ai') -Filter '.skill-install-*' -Force).Count -eq 0) 'Transaction directory leaked.'
}
Test-Case 'staging failure preserves all installed files and lock bytes' {
    $beforeAgents = (Get-HarnessSkillManifest $nativePath).Hash
    $claudePath = Join-HarnessPath $project '.claude' 'skills' 'dashboard-builder'
    $beforeClaude = (Get-HarnessSkillManifest $claudePath).Hash
    $beforeLock = [IO.File]::ReadAllBytes($lockPath)
    function Copy-Item {
        [CmdletBinding()]param([string]$LiteralPath, [string]$Destination, [switch]$Recurse, [switch]$Force)
        if ((Split-Path -Leaf $Destination) -eq 'stage-1') { throw 'Injected staging failure' }
        Microsoft.PowerShell.Management\Copy-Item -LiteralPath $LiteralPath -Destination $Destination -Recurse:$Recurse -Force:$Force
    }
    $failed = $false
    try { Install-Test -Force } catch { $failed = $true } finally { Remove-Item Function:Copy-Item }
    Assert-True $failed 'Staging failure was ignored.'
    Assert-True ((Get-HarnessSkillManifest $nativePath).Hash -eq $beforeAgents -and (Get-HarnessSkillManifest $claudePath).Hash -eq $beforeClaude) 'Staging failure changed installed Skills.'
    Assert-True ([Convert]::ToBase64String([IO.File]::ReadAllBytes($lockPath)) -eq [Convert]::ToBase64String($beforeLock)) 'Staging failure changed the lock.'
}
Test-Case 'locked capability file causes replacement rollback' {
    $beforeAgents = (Get-HarnessSkillManifest $nativePath).Hash
    $claudePath = Join-HarnessPath $project '.claude' 'skills' 'dashboard-builder'
    $beforeClaude = (Get-HarnessSkillManifest $claudePath).Hash
    $beforeLock = [IO.File]::ReadAllBytes($lockPath)
    $heldLock = [IO.File]::Open($lockPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $failed = $false
    try { Install-Test -Force } catch { $failed = $true } finally { $heldLock.Dispose() }
    Assert-True $failed 'Lock replacement failure was ignored.'
    Assert-True ((Get-HarnessSkillManifest $nativePath).Hash -eq $beforeAgents -and (Get-HarnessSkillManifest $claudePath).Hash -eq $beforeClaude) 'Lock replacement failure changed installed Skills.'
    Assert-True ([Convert]::ToBase64String([IO.File]::ReadAllBytes($lockPath)) -eq [Convert]::ToBase64String($beforeLock)) 'Lock replacement failure changed lock bytes.'
}
Test-Case 'reference deletion is detected' {
    Remove-Item -LiteralPath $reference
    Assert-True ((Check-Test).overall -eq 'FAIL') 'Deleted reference was missed.'
    [IO.File]::WriteAllBytes($reference, $cleanReference)
}
Test-Case 'additional unrecorded file is detected' {
    $extra = Join-HarnessPath $nativePath 'extra.txt'
    Write-HarnessText $extra 'extra'
    Assert-True ((Check-Test).overall -eq 'FAIL') 'Extra file was missed.'
    Remove-Item -LiteralPath $extra
}
Test-Case 'legacy SKILL.md hash remains compatible' {
    $lock = Read-HarnessJson $lockPath
    foreach ($name in @('bundle_hash', 'hash_algorithm', 'files')) { $lock.capabilities[0].PSObject.Properties.Remove($name) }
    Write-HarnessJson $lockPath $lock -Depth 12
    $check = Check-Test
    Assert-True ($check.overall -eq 'PASS_WITH_INFO' -and @($check.issues | Where-Object code -eq 'LEGACY_SKILL_HASH').Count -gt 0) 'Legacy hash was misinterpreted.'
    [IO.File]::WriteAllBytes($lockPath, $cleanLock)
}
Test-Case 'duplicate capability record is rejected' {
    $lock = Read-HarnessJson $lockPath
    $lock.capabilities = @($lock.capabilities) + @($lock.capabilities[0])
    Write-HarnessJson $lockPath $lock -Depth 12
    Assert-True (@((Check-Test).issues | Where-Object code -eq 'DUPLICATE_CAPABILITY').Count -gt 0) 'Duplicate record was missed.'
    [IO.File]::WriteAllBytes($lockPath, $cleanLock)
}
Test-Case 'empty path list cannot bypass bundle verification' {
    $lock = Read-HarnessJson $lockPath
    $lock.capabilities[0].config_path = '; '
    Write-HarnessJson $lockPath $lock -Depth 12
    Assert-True (@((Check-Test).issues | Where-Object code -eq 'SKILL_PATH_MISSING').Count -gt 0) 'Empty path bypassed integrity verification.'
    [IO.File]::WriteAllBytes($lockPath, $cleanLock)
}
Test-Case 'partial bundle metadata is rejected by validator and schema' {
    $lock = Read-HarnessJson $lockPath
    $lock.capabilities[0].PSObject.Properties.Remove('bundle_hash')
    Write-HarnessJson $lockPath $lock -Depth 12
    Assert-True (@((Check-Test).issues | Where-Object code -eq 'SKILL_HASH_FORMAT').Count -gt 0) 'Partial bundle metadata was treated as a legacy lock.'
    & node (Join-HarnessPath $harness 'scripts' 'harness-schema-validate.mjs') --schema (Join-HarnessPath $harness 'schemas' 'capability-lock.schema.json') $lockPath | Out-Null
    Assert-True ($LASTEXITCODE -eq 1) 'Schema accepted partial bundle metadata.'
    [IO.File]::WriteAllBytes($lockPath, $cleanLock)
}
Test-Case 'outside project paths are rejected' {
    $failed = $false
    try { $null = Get-HarnessProjectPath $project '../outside' } catch { $failed = $true }
    Assert-True $failed 'Parent traversal was allowed.'
}
Test-Case 'junction destination cannot reach outside the project' {
    $outside = Join-HarnessPath $fixture 'outside'
    New-Item -ItemType Directory -Path $outside | Out-Null
    $link = Join-HarnessPath $project 'linked'
    New-Item -ItemType Junction -Path $link -Target $outside | Out-Null
    try {
        $failed = $false
        try { $null = Get-HarnessProjectPath $project 'linked/skill' } catch { $failed = $true }
        Assert-True $failed 'Junction traversal was allowed.'
    } finally { [IO.Directory]::Delete($link) }
}
$failures = @($results | Where-Object result -eq 'FAIL')
Write-Output ("RESULT {0}/{1} passed; external AI calls: 0" -f ($results.Count - $failures.Count), $results.Count)
if ($KeepFixtures -or $failures.Count -gt 0) { Write-Output "Fixtures retained: $fixture" }
else {
    # Delete only the exact resolved temporary root created by this invocation.
    $resolvedFixture = (Resolve-Path -LiteralPath $fixture).Path
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char[]]'\/')
    if (-not $resolvedFixture.StartsWith($tempRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolvedFixture) -notmatch '^h51-[a-f0-9]{6}$') { throw 'Unsafe fixture cleanup target.' }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
if ($failures.Count -gt 0) { exit 1 }
