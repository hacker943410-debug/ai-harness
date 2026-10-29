#Requires -Version 5.1
[CmdletBinding()]
param([string]$HarnessRoot)
if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Common.ps1')
. (Join-Path $PSScriptRoot '_Harness.Skill.ps1')

$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('reviewed-skill-test-' + [guid]::NewGuid().ToString('N'))
$count = 0
function Assert-Test([bool]$Condition, [string]$Label) {
    if (-not $Condition) { throw "FAIL: $Label" }
    $script:count++
    Write-Output "PASS: $Label"
}
function Assert-Throws([scriptblock]$Action, [string]$Pattern, [string]$Label) {
    $caught = ''
    try { & $Action | Out-Null } catch { $caught = $_.Exception.Message }
    Assert-Test ($caught -match $Pattern) $Label
}
try {
    $fixture = Join-Path $sandbox 'harness'
    $project = Join-Path $sandbox 'project'
    $reviewed = Join-Path $sandbox 'reviewed-skill'
    New-Item -ItemType Directory -Force -Path $fixture, $project | Out-Null
    foreach ($dir in @('catalogs', 'settings', 'skills')) {
        Copy-Item -Force -Recurse -LiteralPath (Join-HarnessPath $HarnessRoot $dir) -Destination (Join-Path $fixture $dir)
    }
    Copy-Item -Recurse -LiteralPath (Join-HarnessPath $fixture 'skills/dashboard-builder') -Destination $reviewed
    $hash = (Get-HarnessSkillManifest $reviewed).Hash
    $catalogPath = Join-HarnessPath $fixture 'catalogs/skill-catalog.json'
    $catalog = Read-HarnessJson -Path $catalogPath
    $entry = @($catalog.entries | Where-Object { $_.id -eq 'dashboard-builder' })[0]
    $entry.status = 'discovery_only'
    $entry.PSObject.Properties.Remove('bundled_path')
    Write-HarnessJson -Path $catalogPath -InputObject $catalog -Depth 20

    $installer = Join-HarnessPath $HarnessRoot 'scripts/Install-ProjectSkill.ps1'
    $common = @{ Id = 'dashboard-builder'; ProjectRoot = $project; HarnessRoot = $fixture; Client = 'Codex'; AllowDiscoveryOnly = $true }
    Assert-Throws { & $installer @common } 'EXTERNAL_SKILL_REVIEW_REQUIRED' 'external Skill cannot install from network by default'
    Assert-Throws { & $installer @common -ReviewedSourceDirectory $reviewed -ExpectedTreeHash 'untrusted' } 'EXTERNAL_SKILL_HASH_INVALID' 'invalid review hash is rejected'
    Assert-Throws { & $installer @common -ReviewedSourceDirectory $reviewed -ExpectedTreeHash ('0' * 64) } 'EXTERNAL_SKILL_HASH_MISMATCH' 'mismatched source hash is rejected'
    Assert-Test (-not (Test-Path -LiteralPath (Join-Path $project '.ai'))) 'rejected installations create no project state'

    & $installer @common -ReviewedSourceDirectory $reviewed -ExpectedTreeHash $hash | Out-Null
    $lockPath = Join-HarnessPath $project '.ai/capability-lock.json'
    $lock = Read-HarnessJson -Path $lockPath
    $skill = @($lock.capabilities | Where-Object { $_.id -eq 'dashboard-builder' })[0]
    Assert-Test ($skill.bundle_hash -eq $hash -and $skill.hash_algorithm -eq 'sha256-tree-v1') 'reviewed Skill has full tree hash in lock'
    Assert-Test (@($skill.installations).Count -eq 1) 'reviewed Skill has one tracked target'
    $result = & (Join-HarnessPath $HarnessRoot 'scripts/Test-ProjectCapabilities.ps1') -ProjectRoot $project -HarnessRoot $fixture
    Assert-Test ($result.overall -eq 'PASS') 'reviewed Skill passes project capability verification'
    & node (Join-HarnessPath $HarnessRoot 'scripts/harness-schema-validate.mjs') --schema (Join-HarnessPath $HarnessRoot 'schemas/capability-lock.schema.json') $lockPath | Out-Null
    Assert-Test ($LASTEXITCODE -eq 0) 'reviewed Skill lock passes JSON schema'
    $installed = Join-HarnessPath $project '.agents/skills/dashboard-builder/SKILL.md'
    [IO.File]::AppendAllText($installed, "`nmodified")
    $result = & (Join-HarnessPath $HarnessRoot 'scripts/Test-ProjectCapabilities.ps1') -ProjectRoot $project -HarnessRoot $fixture
    Assert-Test ($result.overall -eq 'FAIL') 'post-install tampering is detected'
    Write-Output "PASS: $count reviewed external Skill assertions"
} finally {
    $full = [IO.Path]::GetFullPath($sandbox)
    $root = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char[]]'\\/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $full) -notlike 'reviewed-skill-test-*') { throw 'Unsafe cleanup directory' }
    if (Test-Path -LiteralPath $full) { Remove-Item -Recurse -Force -LiteralPath $full }
}
