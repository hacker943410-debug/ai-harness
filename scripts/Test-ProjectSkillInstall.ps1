#Requires -Version 5.1
[CmdletBinding()]
param([string]$HarnessRoot)
if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Common.ps1')
. (Join-Path $PSScriptRoot '_Harness.Skill.ps1')
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('harness-skill-test-' + [guid]::NewGuid())
$count = 0
function Assert-Test([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:count++
    Write-Output "PASS: $Name"
}
function Read-Skill {
    return @((Read-HarnessJson $lockPath).capabilities | Where-Object id -eq 'dashboard-builder')[0]
}
function Install-TestSkill([string]$Client, [switch]$Force) {
    & (Join-HarnessPath $HarnessRoot 'scripts/Install-ProjectSkill.ps1') -Id dashboard-builder -HarnessRoot $fixture -ProjectRoot $project -Client $Client -Force:$Force | Out-Null
}
function Check-Test {
    & (Join-HarnessPath $HarnessRoot 'scripts/Test-ProjectCapabilities.ps1') -ProjectRoot $project -HarnessRoot $fixture
}
function Assert-Schema {
    & node (Join-HarnessPath $HarnessRoot 'scripts/harness-schema-validate.mjs') --schema (Join-HarnessPath $HarnessRoot 'schemas/capability-lock.schema.json') $lockPath | Out-Null
    Assert-Test ($LASTEXITCODE -eq 0) 'capability lock satisfies schema'
}
try {
    $fixture = Join-Path $sandbox 'harness'
    $project = Join-Path $sandbox 'project'
    New-Item -ItemType Directory -Force -Path $fixture, $project | Out-Null
    foreach ($dir in @('catalogs', 'settings', 'skills')) {
        Copy-Item -Force -Recurse -LiteralPath (Join-HarnessPath $HarnessRoot $dir) -Destination (Join-Path $fixture $dir)
    }
    $source = Join-HarnessPath $fixture 'skills/dashboard-builder'
    $lockPath = Join-HarnessPath $project '.ai/capability-lock.json'
    & (Join-HarnessPath $HarnessRoot 'scripts/Install-ProjectSkill.ps1') -Id dashboard-builder -HarnessRoot $fixture -ProjectRoot $project -Client Codex -WhatIf | Out-Null
    Assert-Test (-not (Test-Path (Join-Path $project '.ai'))) 'WhatIf creates no state'
    Install-TestSkill Codex
    $baseline = (Get-HarnessSkillManifest $source).Hash
    Install-TestSkill Claude
    Install-TestSkill AGY
    $skill = Read-Skill
    Assert-Test (@($skill.config_path -split ';').Count -eq 2) 'separate clients retain both unique destinations'
    Assert-Test (@($skill.installations).Count -eq 2) 'shared Codex and AGY destination is deduplicated'
    Assert-Test ($skill.bundle_hash -eq $baseline -and (Check-Test).overall -eq 'PASS') 'identical installations have a verified common hash'
    Assert-Schema
    $lock = Read-HarnessJson $lockPath
    $other = [pscustomobject]@{ type='mcp'; id='test-other'; source='test'; scope='project'; status='installed'; recorded_at='2026-10-13T00:00:00Z' }
    $lock.capabilities += $other
    Write-HarnessJson $lockPath $lock -Depth 16
    Install-TestSkill AllNative
    Assert-Test (@((Read-Skill).installations).Count -eq 2) 'AllNative reinstall is idempotent'
    Assert-Test (@((Read-HarnessJson $lockPath).capabilities | Where-Object id -eq 'test-other').Count -eq 1) 'unrelated MCP capability is preserved'
    foreach ($relative in @('scripts/validate_dashboard.py', 'references/data-analysis.md', 'templates/dashboard-brief.md')) {
        $file = Join-HarnessPath $source $relative
        $bytes = [IO.File]::ReadAllBytes($file)
        [IO.File]::AppendAllText($file, "`nchanged", [Text.UTF8Encoding]::new($false))
        Assert-Test ((Get-HarnessSkillManifest $source).Hash -ne $baseline) "full hash detects $relative changes"
        [IO.File]::WriteAllBytes($file, $bytes)
    }
    $extra = Join-Path $source '.hidden-test'
    [IO.File]::WriteAllText($extra, 'hidden')
    $added = (Get-HarnessSkillManifest $source).Hash
    Assert-Test ($added -ne $baseline) 'full hash detects hidden files'
    Move-Item -LiteralPath $extra -Destination (Join-Path $source '.renamed-test')
    Assert-Test ((Get-HarnessSkillManifest $source).Hash -ne $added) 'full hash detects renames'
    Remove-Item -LiteralPath (Join-Path $source '.renamed-test')
    Assert-Test ((Get-HarnessSkillManifest $source).Hash -eq $baseline) 'file deletion restores original hash'
    (Get-Item (Join-Path $source 'SKILL.md')).LastWriteTimeUtc = [datetime]::UtcNow.AddDays(-2)
    Assert-Test ((Get-HarnessSkillManifest $source).Hash -eq $baseline) 'mtime is excluded from hash'
    $relocated = Join-Path $sandbox 'relocated'
    Copy-Item -Recurse -LiteralPath $source -Destination $relocated
    Assert-Test ((Get-HarnessSkillManifest $relocated).Hash -eq $baseline) 'absolute root is excluded from hash'
    [IO.File]::AppendAllText((Join-HarnessPath $source 'scripts/validate_dashboard.py'), "`n# changed")
    Install-TestSkill Claude -Force
    $mixed = Read-Skill
    Assert-Test ($null -eq $mixed.bundle_hash -and $null -eq $mixed.content_hash) 'mixed installations have no misleading common hash'
    Assert-Test (@($mixed.installations | Where-Object config_path -like '.agents/*')[0].bundle_hash -eq $baseline) 'untargeted installation retains its recorded hash'
    Assert-Test ((Check-Test).overall -eq 'PASS') 'different valid installations pass integrity checks'
    Assert-Schema
    $tampered = Join-HarnessPath $project '.agents/skills/dashboard-builder/SKILL.md'
    [IO.File]::AppendAllText($tampered, 'tampered')
    Assert-Test ((Check-Test).overall -eq 'FAIL') 'untargeted installation tampering is detected'
    $savedLock = [IO.File]::ReadAllBytes($lockPath)
    $failed = $false
    try { Install-TestSkill Codex } catch { $failed = $true }
    Assert-Test ($failed -and [Convert]::ToBase64String([IO.File]::ReadAllBytes($lockPath)) -eq [Convert]::ToBase64String($savedLock)) 'overwrite refusal preserves the lock'
    Install-TestSkill AllNative -Force
    $cleanLock = [IO.File]::ReadAllBytes($lockPath)
    $lock = Read-HarnessJson $lockPath
    $lock.capabilities[1].installations += $lock.capabilities[1].installations[0]
    Write-HarnessJson $lockPath $lock -Depth 16
    Assert-Test (@((Check-Test).issues | Where-Object code -eq 'DUPLICATE_SKILL_PATH').Count -gt 0) 'duplicate installation paths are rejected'
    [IO.File]::WriteAllBytes($lockPath, $cleanLock)
    $lock = Read-HarnessJson $lockPath
    $lock.capabilities[1].config_path = '.agents/skills/dashboard-builder'
    Write-HarnessJson $lockPath $lock -Depth 16
    Assert-Test (@((Check-Test).issues | Where-Object code -eq 'SKILL_PATH_SUMMARY_MISMATCH').Count -gt 0) 'path summary cannot hide an installation'
    [IO.File]::WriteAllBytes($lockPath, $cleanLock)
    $lock = Read-HarnessJson $lockPath
    $lock.capabilities[1].PSObject.Properties.Remove('installations')
    Write-HarnessJson $lockPath $lock -Depth 16
    Install-TestSkill Codex
    Assert-Test (@((Read-Skill).installations).Count -eq 2 -and (Check-Test).overall -eq 'PASS') 'existing v6 full-hash locks migrate without losing paths'
    $lock = Read-HarnessJson $lockPath
    $skill = Read-Skill
    foreach ($name in @('installations', 'bundle_hash', 'hash_algorithm', 'files')) { $skill.PSObject.Properties.Remove($name) }
    $lock.capabilities = @($other, $skill)
    Write-HarnessJson $lockPath $lock -Depth 16
    Install-TestSkill Codex
    Assert-Test (@((Read-Skill).installations).Count -eq 2 -and (Check-Test).overall -eq 'PASS_WITH_INFO') 'legacy paths remain unverified until reinstalled'
    Install-TestSkill AllNative
    Assert-Test ((Check-Test).overall -eq 'PASS') 'AllNative completes legacy migration'
    Assert-Schema
    Write-Output "PASS: $count installation regression assertions ($($PSVersionTable.PSVersion))"
} finally {
    $resolvedSandbox = [IO.Path]::GetFullPath($sandbox)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedSandbox.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolvedSandbox) -notlike 'harness-skill-test-*') { throw 'Unsafe test cleanup path.' }
    if (Test-Path -LiteralPath $resolvedSandbox) { Remove-Item -Force -Recurse -LiteralPath $resolvedSandbox }
}
