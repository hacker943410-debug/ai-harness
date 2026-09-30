[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Id,
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$Reason = 'capability_gap',
    [string]$HarnessRoot,
    [string]$Client = 'AllNative',
    [switch]$AllowDiscoveryOnly
)

# [CmdletBinding()] 가 있으면 PS 5.1 은 param 기본값 평가 시 $PSScriptRoot 를 비워 둔다.
if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Common.ps1')
. (Join-Path $PSScriptRoot '_Harness.SkillContent.ps1')

$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$catalogPath = Join-HarnessPath (Resolve-Path -LiteralPath $HarnessRoot).Path 'catalogs' 'skill-catalog.json'
$catalog = Read-HarnessJson -Path $catalogPath
$entry = @($catalog.entries | Where-Object id -eq $Id)
if ($entry.Count -ne 1) { throw "Skill '$Id' was not found uniquely in the catalog." }
$entry = $entry[0]
if ($entry.status -eq 'discovery_only' -and -not $AllowDiscoveryOnly) {
    throw "Skill '$Id' is discovery_only. Verify its current source and audit before installing."
}
if (-not $entry.source) { throw "Skill '$Id' has no verified source." }

$aiDir = Join-HarnessPath $project '.ai'
$lockPath = Join-HarnessPath $aiDir 'capability-lock.json'
# Read persisted state before mutating any installed files.
if (Test-Path -LiteralPath $lockPath) {
    $lock = Read-HarnessJson -Path $lockPath
} else {
    $lock = [pscustomobject]@{ schema_version = '1.0'; capabilities = @() }
}
$prior = @($lock.capabilities | Where-Object { $_.type -eq 'skill' -and $_.id -eq $Id })
$installations = @()
foreach ($old in $prior) {
    foreach ($installation in @($old.installations)) {
        if ($null -eq $installation) { continue }
        $installation.config_path = ConvertTo-HarnessSkillPath $installation.config_path
        $installations += $installation
    }
    foreach ($path in @(([string]$old.config_path).Split(';') | Where-Object { $_ })) {
        $path = ConvertTo-HarnessSkillPath $path
        if (@($installations | Where-Object config_path -eq $path).Count -eq 0) {
            # Preserve legacy paths without relabeling the old SKILL.md hash.
            $installations += [pscustomobject]@{
                client_id = 'legacy'; config_path = $path; content_hash = $null
                content_hash_algorithm = $null; status = 'installed'; recorded_at = $old.recorded_at
            }
        }
    }
}

$installedPaths = @()
$installedRelativePaths = @()
$contentHash = $null

if ($entry.PSObject.Properties.Name -contains 'bundled_path' -and $entry.bundled_path) {
    $source = Join-HarnessPath (Resolve-Path -LiteralPath $HarnessRoot).Path $entry.bundled_path
    if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md'))) {
        throw "Bundled Skill source is invalid: $source"
    }

    # Native Skill 설치 위치는 Client descriptor가 소유한다.
    # 새 CLI 추가 시 이 스크립트를 고치지 않고 settings/clients/<id>.client.json만 추가한다.
    $clientDir = Join-HarnessPath (Resolve-Path -LiteralPath $HarnessRoot).Path 'settings' 'clients'
    $descriptors = @()
    if ($Client -eq 'AllNative') {
        foreach ($df in @(Get-ChildItem -LiteralPath $clientDir -Filter '*.client.json' -File -ErrorAction Stop)) {
            $d = Read-HarnessJson -Path $df.FullName
            if ($d.skill_support -and $d.skill_support.native -and $d.skill_support.project_path_template) {
                $descriptors += $d
            }
        }
    } else {
        $descriptorPath = Join-Path $clientDir ("{0}.client.json" -f $Client.ToLowerInvariant())
        if (-not (Test-Path -LiteralPath $descriptorPath)) {
            throw "Client descriptor not found: $Client"
        }
        $d = Read-HarnessJson -Path $descriptorPath
        if (-not ($d.skill_support -and $d.skill_support.native -and $d.skill_support.project_path_template)) {
            throw "Client '$Client' does not declare native project Skill support."
        }
        $descriptors += $d
    }

    if ($descriptors.Count -eq 0) {
        throw "No native Skill-capable client descriptors were found."
    }

    $targetSpecs = @()
    foreach ($d in $descriptors) {
        $rel = ([string]$d.skill_support.project_path_template).Replace('{skill_id}', $Id)
        $rel = ConvertTo-HarnessSkillPath $rel
        if ([IO.Path]::IsPathRooted($rel) -or $rel -match '(^|[\\/])\.\.([\\/]|$)') {
            throw "Unsafe project_path_template for client '$($d.client_id)': $rel"
        }
        $targetSpecs += [pscustomobject]@{ path = (Join-HarnessPath $project $rel); rel = $rel; client_id = $d.client_id }
    }
    $targetSpecs = @($targetSpecs | Sort-Object path -Unique)
    $targets = @($targetSpecs | ForEach-Object { $_.path })

    $commandText = "copy bundled skill '$Id' to: " + ($targets -join ', ')
    if (-not $PSCmdlet.ShouldProcess($project, $commandText)) { return }

    $contentHash = Get-HarnessSkillContentHash -Root $source
    foreach ($spec in $targetSpecs) {
        $dest = $spec.path
        if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -Recurse -Force -LiteralPath $source -Destination $dest
        if (-not (Test-Path -LiteralPath (Join-Path $dest 'SKILL.md'))) {
            throw "Bundled Skill install verification failed: $dest"
        }
        $destinationHash = Get-HarnessSkillContentHash -Root $dest
        if ($destinationHash -ne $contentHash) { throw "Bundled Skill content verification failed: $dest" }
        $installations = @($installations | Where-Object config_path -ne $spec.rel)
        $installations += [pscustomobject]@{
            client_id = $spec.client_id; config_path = $spec.rel; content_hash = $destinationHash
            content_hash_algorithm = 'sha256-tree-v1'; status = 'installed'; recorded_at = (Get-HarnessUtcStamp)
        }
        $installedPaths += $dest
        $installedRelativePaths += $spec.rel
    }


} else {
    $commandText = "npx skills add $($entry.source) --skill $Id"
    if (-not $PSCmdlet.ShouldProcess($project, $commandText)) { return }

    $previousTelemetry = $env:DISABLE_TELEMETRY
    try {
        $env:DISABLE_TELEMETRY = '1'
        Push-Location -LiteralPath $project
        try { & npx skills add $entry.source --skill $Id } finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) { throw "Skills CLI exited with code $LASTEXITCODE." }
    } finally {
        $env:DISABLE_TELEMETRY = $previousTelemetry
    }
}

$remaining = @($lock.capabilities | Where-Object { -not ($_.type -eq 'skill' -and $_.id -eq $Id) })
$configPathValue = $null
if ($installedRelativePaths.Count -gt 0) {
    $installations = @($installations | Sort-Object config_path -Unique)
    $configPathValue = ($installations.config_path -join ';')
    $hashes = @($installations.content_hash | Sort-Object -Unique)
    if (@($installations | Where-Object { $_.content_hash_algorithm -ne 'sha256-tree-v1' -or -not $_.content_hash }).Count -gt 0 -or $hashes.Count -ne 1) {
        $contentHash = $null
    } else { $contentHash = $hashes[0] }
}
$record = [pscustomobject]@{
    type = 'skill'; id = $Id; source = $entry.source; version = $null; content_hash = $contentHash
    scope = 'project'; reason = $Reason; status = 'installed'
    config_path = $configPathValue
    recorded_at = (Get-HarnessUtcStamp)
}
if ($installedRelativePaths.Count -gt 0) {
    $record | Add-Member -NotePropertyName installations -NotePropertyValue @($installations)
    $record | Add-Member -NotePropertyName content_hash_algorithm -NotePropertyValue 'sha256-tree-v1'
}
New-Item -ItemType Directory -Force -Path $aiDir | Out-Null
$lock.capabilities = @($remaining + $record)
Write-HarnessJson -Path $lockPath -InputObject $lock -Depth 8
Write-Output "Installed project skill '$Id' for $Client. Restart the agent session if the client requires rediscovery."
