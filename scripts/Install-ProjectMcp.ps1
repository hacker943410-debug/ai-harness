[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Id,
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$Version,
    [string]$Reason = 'capability_gap',
    [string]$HarnessRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$catalogPath = Join-Path (Resolve-Path -LiteralPath $HarnessRoot).Path 'catalogs\mcp-catalog.json'
$catalog = Get-Content -Raw -Encoding utf8 -LiteralPath $catalogPath | ConvertFrom-Json
$matches = @($catalog.entries | Where-Object id -eq $Id)
if ($matches.Count -ne 1) { throw "MCP '$Id' was not found uniquely in the catalog." }
$entry = $matches[0]
if ($entry.status -eq 'discovery_only') { throw "MCP '$Id' is discovery_only. Verify it in the official Registry before installation." }

$kind = $entry.install.kind
if ($kind -eq 'npm') {
    if (-not $Version) { throw "An exact -Version is required for local npm MCP installation." }
    if ($Version -eq 'latest' -or $Version.Contains('*') -or $Version.Contains('^') -or $Version.Contains('~')) {
        throw 'Version must be exact; latest, wildcards, caret, and tilde ranges are not allowed.'
    }
    $packageSpec = "$($entry.install.package)@$Version"
    if ($PSCmdlet.ShouldProcess($project, "npm install --save-dev --save-exact $packageSpec")) {
        if (-not (Test-Path -LiteralPath (Join-Path $project 'package.json'))) {
            throw 'Project package.json is required for project-local npm MCP installation.'
        }
        Push-Location -LiteralPath $project
        try { & npm install --save-dev --save-exact $packageSpec } finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) { throw "npm exited with code $LASTEXITCODE." }
    } else { return }
} elseif ($kind -eq 'remote') {
    if (-not $PSCmdlet.ShouldProcess($project, "record remote MCP $Id")) { return }
} else {
    throw "MCP '$Id' uses install kind '$kind'. Confirm current official coordinates and configure it with the client-specific project adapter."
}

$aiDir = Join-Path $project '.ai'
$mcpDir = Join-Path $aiDir 'mcp'
New-Item -ItemType Directory -Force -Path $mcpDir | Out-Null
$desiredPath = Join-Path $mcpDir 'desired.json'
if (Test-Path -LiteralPath $desiredPath) {
    $desired = Get-Content -Raw -Encoding utf8 -LiteralPath $desiredPath | ConvertFrom-Json
} else {
    $desired = [pscustomobject]@{ schema_version = '1.0'; servers = @() }
}
$server = [pscustomobject]@{
    id = $Id
    transport = if ($kind -eq 'remote') { 'streamable_http' } else { 'stdio' }
    package = if ($kind -eq 'npm') { $entry.install.package } else { $null }
    version = if ($kind -eq 'npm') { $Version } else { $null }
    url = if ($kind -eq 'remote') { $entry.install.url } else { $null }
    credential_refs = @()
    risk = $entry.risk
}
$desired.servers = @($desired.servers | Where-Object id -ne $Id) + $server
$desired | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 -LiteralPath $desiredPath

$lockPath = Join-Path $aiDir 'capability-lock.json'
if (Test-Path -LiteralPath $lockPath) {
    $lock = Get-Content -Raw -Encoding utf8 -LiteralPath $lockPath | ConvertFrom-Json
} else {
    $lock = [pscustomobject]@{ schema_version = '1.0'; project_root = $project; capabilities = @() }
}
$remaining = @($lock.capabilities | Where-Object { -not ($_.type -eq 'mcp' -and $_.id -eq $Id) })
$source = if ($kind -eq 'npm') { $entry.install.package } else { $entry.install.url }
$record = [pscustomobject]@{
    type = 'mcp'; id = $Id; source = $source; version = $Version; content_hash = $null
    scope = 'project'; reason = $Reason; status = 'configured'; config_path = '.ai/mcp/desired.json'
    recorded_at = [DateTimeOffset]::Now.ToString('o')
}
$lock.capabilities = @($remaining + $record)
$lock | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 -LiteralPath $lockPath
Write-Output "MCP '$Id' is recorded for this project. Apply the desired entry to the active client's official project MCP configuration, then run a read-only smoke test before marking it verified."
