[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Id,
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$Reason = 'capability_gap',
    [string]$HarnessRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$AllowDiscoveryOnly
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$catalogPath = Join-Path (Resolve-Path -LiteralPath $HarnessRoot).Path 'catalogs\skill-catalog.json'
$catalog = Get-Content -Raw -Encoding utf8 -LiteralPath $catalogPath | ConvertFrom-Json
$entry = @($catalog.entries | Where-Object id -eq $Id)
if ($entry.Count -ne 1) { throw "Skill '$Id' was not found uniquely in the catalog." }
$entry = $entry[0]
if ($entry.status -eq 'discovery_only' -and -not $AllowDiscoveryOnly) {
    throw "Skill '$Id' is discovery_only. Verify its current source and audit before installing."
}
if (-not $entry.source) { throw "Skill '$Id' has no verified source." }

$aiDir = Join-Path $project '.ai'
$lockPath = Join-Path $aiDir 'capability-lock.json'
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
    $lock = Get-Content -Raw -Encoding utf8 -LiteralPath $lockPath | ConvertFrom-Json
} else {
    $lock = [pscustomobject]@{ schema_version = '1.0'; project_root = $project; capabilities = @() }
}
$remaining = @($lock.capabilities | Where-Object { -not ($_.type -eq 'skill' -and $_.id -eq $Id) })
$record = [pscustomobject]@{
    type = 'skill'; id = $Id; source = $entry.source; version = $null; content_hash = $null
    scope = 'project'; reason = $Reason; status = 'installed'; config_path = $null
    recorded_at = [DateTimeOffset]::Now.ToString('o')
}
$lock.capabilities = @($remaining + $record)
$lock | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 -LiteralPath $lockPath
Write-Output "Installed project skill '$Id'. Restart the agent session if the client requires rediscovery."
