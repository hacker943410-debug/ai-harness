[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Id,
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$Reason = 'capability_gap',
    [string]$HarnessRoot,
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
$commandText = "npx skills add $($entry.source) --skill $Id"
if (-not $PSCmdlet.ShouldProcess($project, $commandText)) { return }

New-Item -ItemType Directory -Force -Path $aiDir | Out-Null
$previousTelemetry = $env:DISABLE_TELEMETRY
try {
    $env:DISABLE_TELEMETRY = '1'
    Push-Location -LiteralPath $project
    try { & npx skills add $entry.source --skill $Id } finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { throw "Skills CLI exited with code $LASTEXITCODE." }
} finally {
    $env:DISABLE_TELEMETRY = $previousTelemetry
}

if (Test-Path -LiteralPath $lockPath) {
    $lock = Read-HarnessJson -Path $lockPath
} else {
    # project_root 를 기록하지 않는다 (머신 절대경로가 커밋되면 다른 PC 에서 틀린 값이 된다).
    $lock = [pscustomobject]@{ schema_version = '1.0'; capabilities = @() }
}
$remaining = @($lock.capabilities | Where-Object { -not ($_.type -eq 'skill' -and $_.id -eq $Id) })
$record = [pscustomobject]@{
    type = 'skill'; id = $Id; source = $entry.source; version = $null; content_hash = $null
    scope = 'project'; reason = $Reason; status = 'installed'; config_path = $null
    recorded_at = (Get-HarnessUtcStamp)
}
$lock.capabilities = @($remaining + $record)
Write-HarnessJson -Path $lockPath -InputObject $lock -Depth 8
Write-Output "Installed project skill '$Id'. Restart the agent session if the client requires rediscovery."
