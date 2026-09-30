#Requires -Version 5.1
[CmdletBinding()]
param([string]$HarnessRoot)
if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Common.ps1')
. (Join-Path $PSScriptRoot '_Harness.SkillContent.ps1')
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('harness-skill-test-' + [guid]::NewGuid())
$count = 0
function Assert-Test([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:count++
    Write-Output "PASS: $Name"
}
function Read-Skill {
    $lock = Read-HarnessJson -Path (Join-HarnessPath $project '.ai' 'capability-lock.json')
    return @($lock.capabilities | Where-Object id -eq 'dashboard-builder')[0]
}
function Install-TestSkill([string]$Client) {
    & (Join-HarnessPath $HarnessRoot 'scripts' 'Install-ProjectSkill.ps1') -Id dashboard-builder -HarnessRoot $fixture -ProjectRoot $project -Client $Client | Out-Null
}
try {
    $fixture = Join-Path $sandbox 'harness'
    $project = Join-Path $sandbox 'project'
    New-Item -ItemType Directory -Force $fixture, $project | Out-Null
    foreach ($dir in @('catalogs', 'settings', 'skills')) {
        Copy-Item -Force -Recurse -LiteralPath (Join-HarnessPath $HarnessRoot $dir) -Destination (Join-Path $fixture $dir)
    }
    $source = Join-HarnessPath $fixture 'skills' 'dashboard-builder'
    $lockPath = Join-HarnessPath $project '.ai' 'capability-lock.json'
    & (Join-HarnessPath $HarnessRoot 'scripts' 'Install-ProjectSkill.ps1') -Id dashboard-builder -HarnessRoot $fixture -ProjectRoot $project -Client Codex -WhatIf | Out-Null
    Assert-Test (-not (Test-Path $lockPath) -and -not (Test-Path (Join-Path $project '.ai'))) 'WhatIf does not create state'
    Install-TestSkill Codex
    $first = Read-Skill
    $node = Get-HarnessNativeCommand 'node'
    if (-not $node) { throw 'Node is required for schema regression tests.' }
    & $node (Join-HarnessPath $HarnessRoot 'scripts' 'harness-schema-validate.mjs') --schema (Join-HarnessPath $HarnessRoot 'schemas' 'capability-lock.schema.json') $lockPath
    Assert-Test ($LASTEXITCODE -eq 0) 'fresh lock satisfies schema'
    $lock = Read-HarnessJson $lockPath
    $other = [pscustomobject]@{ type='mcp'; id='test-other'; source='test'; scope='project'; status='installed'; recorded_at='2026-09-30T00:00:00Z' }
    $lock.capabilities += $other
    Write-HarnessJson -Path $lockPath -InputObject $lock -Depth 8
    Install-TestSkill Claude
    Install-TestSkill AGY
    $skill = Read-Skill
    Assert-Test (@($skill.installations).Count -eq 3) 'separate clients retain all three paths'
    Assert-Test ($skill.content_hash -eq $first.content_hash) 'same content has common hash'
    Assert-Test (@((Read-HarnessJson $lockPath).capabilities | Where-Object id -eq 'test-other').Count -eq 1) 'unrelated capability preserved'
    Install-TestSkill Codex
    Install-TestSkill AllNative
    Assert-Test (@((Read-Skill).installations).Count -eq 3) 'reinstall and AllNative are idempotent'
    $report = & (Join-HarnessPath $HarnessRoot 'scripts' 'Test-ProjectCapabilities.ps1') -ProjectRoot $project -HarnessRoot $fixture
    Assert-Test ($report.overall -eq 'PASS') 'installed content passes project validator'

    $baseline = Get-HarnessSkillContentHash $source
    foreach ($relative in @('scripts/validate_dashboard.py', 'references/data-analysis.md', 'templates/dashboard-brief.md')) {
        $file = Join-HarnessPath $source $relative
        $bytes = [IO.File]::ReadAllBytes($file)
        [IO.File]::AppendAllText($file, "`nchanged", [Text.UTF8Encoding]::new($false))
        Assert-Test ((Get-HarnessSkillContentHash $source) -ne $baseline) "hash detects $relative change without SKILL.md edit"
        [IO.File]::WriteAllBytes($file, $bytes)
    }
    $extra = Join-Path $source '.hidden-test'
    [IO.File]::WriteAllText($extra, 'hidden')
    $added = Get-HarnessSkillContentHash $source
    Assert-Test ($added -ne $baseline) 'hash detects hidden file addition'
    Move-Item -LiteralPath $extra -Destination (Join-Path $source '.renamed-test')
    Assert-Test ((Get-HarnessSkillContentHash $source) -ne $added) 'hash detects rename'
    Remove-Item -Force -LiteralPath (Join-Path $source '.renamed-test')
    Assert-Test ((Get-HarnessSkillContentHash $source) -eq $baseline) 'deletion restores original hash'
    (Get-Item (Join-Path $source 'SKILL.md')).LastWriteTimeUtc = [datetime]::UtcNow.AddDays(-2)
    Assert-Test ((Get-HarnessSkillContentHash $source) -eq $baseline) 'mtime excluded'
    $relocated = Join-Path $sandbox 'relocated'
    Copy-Item -Force -Recurse -LiteralPath $source -Destination $relocated
    Assert-Test ((Get-HarnessSkillContentHash $relocated) -eq $baseline) 'absolute root excluded'

    [IO.File]::AppendAllText((Join-HarnessPath $source 'scripts' 'validate_dashboard.py'), "`n# changed")
    Install-TestSkill Claude
    $mixed = Read-Skill
    Assert-Test ($null -eq $mixed.content_hash) 'mixed installations have no misleading common hash'
    Assert-Test (@($mixed.installations | Where-Object client_id -eq 'codex')[0].content_hash -eq $baseline) 'untargeted client keeps old hash'
    $report = & (Join-HarnessPath $HarnessRoot 'scripts' 'Test-ProjectCapabilities.ps1') -ProjectRoot $project -HarnessRoot $fixture
    Assert-Test ($report.overall -eq 'PASS') 'mixed valid installations pass integrity checks'
    [IO.File]::AppendAllText((Join-HarnessPath $project '.claude' 'skills' 'dashboard-builder' 'SKILL.md'), 'tampered')
    $report = & (Join-HarnessPath $HarnessRoot 'scripts' 'Test-ProjectCapabilities.ps1') -ProjectRoot $project -HarnessRoot $fixture
    Assert-Test (@($report.issues | Where-Object code -eq 'SKILL_CONTENT_HASH_MISMATCH').Count -eq 1) 'tampering fails integrity check'
    Install-TestSkill Claude

    Remove-Item -Force -Recurse -LiteralPath (Join-HarnessPath $project '.agents' 'skills' 'dashboard-builder')
    $report = & (Join-HarnessPath $HarnessRoot 'scripts' 'Test-ProjectCapabilities.ps1') -ProjectRoot $project -HarnessRoot $fixture
    Assert-Test (@($report.issues | Where-Object code -eq 'SKILL_PATH_MISSING').Count -eq 1) 'missing installation fails validation'
    Install-TestSkill AGY
    if (-not $script:HarnessIsWindows) {
    $linkRoot = Join-Path $sandbox 'link-root'
    New-Item -ItemType Directory $linkRoot | Out-Null
    New-Item -ItemType SymbolicLink -Path (Join-Path $linkRoot 'linked-skill') -Target $source | Out-Null
    $rejected = $false
    try { $null = Get-HarnessSkillContentHash $linkRoot } catch { $rejected = $true }
    Assert-Test $rejected 'links rejected before traversal'
    Remove-Item -Force -LiteralPath (Join-Path $linkRoot 'linked-skill')

    } else { Write-Output 'SKIP: link test requires Windows symlink privilege; verify separately.' }

    # Migrate old semicolon paths without pretending their old hash is a tree hash.
    $lock = Read-HarnessJson $lockPath
    $legacy = Read-Skill
    $legacy.PSObject.Properties.Remove('installations')
    $legacy.PSObject.Properties.Remove('content_hash_algorithm')
    $legacy.content_hash = 'old-single-file-hash'
    $lock.capabilities = @($other, $legacy)
    Write-HarnessJson -Path $lockPath -InputObject $lock -Depth 8
    Install-TestSkill Codex
    $migrated = Read-Skill
    Assert-Test (@($migrated.installations).Count -eq 3 -and $null -eq $migrated.content_hash) 'legacy paths retained with unknown hashes'
    $report = & (Join-HarnessPath $HarnessRoot 'scripts' 'Test-ProjectCapabilities.ps1') -ProjectRoot $project -HarnessRoot $fixture
    Assert-Test (@($report.issues | Where-Object code -eq 'SKILL_HASH_MIGRATION_REQUIRED').Count -eq 2) 'legacy untargeted paths require migration'
    Install-TestSkill AllNative
    $lock = Read-HarnessJson $lockPath
    $skill = Read-Skill
    $skill.installations += $skill.installations[0]
    $lock.capabilities = @($other, $skill)
    Write-HarnessJson -Path $lockPath -InputObject $lock -Depth 8
    $report = & (Join-HarnessPath $HarnessRoot 'scripts' 'Test-ProjectCapabilities.ps1') -ProjectRoot $project -HarnessRoot $fixture
    Assert-Test (@($report.issues | Where-Object code -eq 'DUPLICATE_SKILL_PATH').Count -eq 1) 'duplicate paths fail validation'
    foreach ($unsafe in @('../escape', 'C:/escape', '/escape', '\\server\share')) {
        $rejected = $false
        try { $null = ConvertTo-HarnessSkillPath $unsafe } catch { $rejected = $true }
        Assert-Test $rejected "reject unsafe path $unsafe"
    }
    Write-Output "PASS: $count installation regression assertions ($($PSVersionTable.PSVersion))"
} finally {
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -Force -Recurse -LiteralPath $sandbox }
}
