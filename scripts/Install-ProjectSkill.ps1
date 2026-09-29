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
New-Item -ItemType Directory -Force -Path $aiDir | Out-Null

$installedPaths = @()
$installedRelativePaths = @()
$contentHash = $null

if ($entry.PSObject.Properties.Name -contains 'bundled_path' -and $entry.bundled_path) {
    $source = Join-Path (Resolve-Path -LiteralPath $HarnessRoot).Path ($entry.bundled_path -replace '/', [IO.Path]::DirectorySeparatorChar)
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
        $rel = $rel -replace '/', [IO.Path]::DirectorySeparatorChar
        if ([IO.Path]::IsPathRooted($rel) -or $rel -match '(^|[\\/])\.\.([\\/]|$)') {
            throw "Unsafe project_path_template for client '$($d.client_id)': $rel"
        }
        $targetSpecs += [pscustomobject]@{ path = (Join-Path $project $rel); rel = $rel; client_id = $d.client_id }
    }
    $targetSpecs = @($targetSpecs | Sort-Object path -Unique)
    $targets = @($targetSpecs | ForEach-Object { $_.path })

    $commandText = "copy bundled skill '$Id' to: " + ($targets -join ', ')
    if (-not $PSCmdlet.ShouldProcess($project, $commandText)) { return }

    foreach ($spec in $targetSpecs) {
        $dest = $spec.path
        if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -Recurse -Force -LiteralPath $source -Destination $dest
        if (-not (Test-Path -LiteralPath (Join-Path $dest 'SKILL.md'))) {
            throw "Bundled Skill install verification failed: $dest"
        }
        $installedPaths += $dest
        $installedRelativePaths += $spec.rel
    }

    $contentHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $source 'SKILL.md')).Hash.ToLowerInvariant()
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

if (Test-Path -LiteralPath $lockPath) {
    $lock = Read-HarnessJson -Path $lockPath
} else {
    # project_root 를 기록하지 않는다 (머신 절대경로가 커밋되면 다른 PC 에서 틀린 값이 된다).
    $lock = [pscustomobject]@{ schema_version = '1.0'; capabilities = @() }
}
$remaining = @($lock.capabilities | Where-Object { -not ($_.type -eq 'skill' -and $_.id -eq $Id) })
$configPathValue = $null
if ($installedRelativePaths.Count -gt 0) { $configPathValue = $installedRelativePaths -join ';' }
$record = [pscustomobject]@{
    type = 'skill'; id = $Id; source = $entry.source; version = $null; content_hash = $contentHash
    scope = 'project'; reason = $Reason; status = 'installed'
    config_path = $configPathValue
    recorded_at = (Get-HarnessUtcStamp)
}
$lock.capabilities = @($remaining + $record)
Write-HarnessJson -Path $lockPath -InputObject $lock -Depth 8
Write-Output "Installed project skill '$Id' for $Client. Restart the agent session if the client requires rediscovery."
