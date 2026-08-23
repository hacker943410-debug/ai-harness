[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$HarnessRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$harness = (Resolve-Path -LiteralPath $HarnessRoot).Path
$issues = [System.Collections.Generic.List[object]]::new()

function Add-Issue([string]$severity, [string]$code, [string]$message) {
    $issues.Add([pscustomobject]@{ severity = $severity; code = $code; message = $message })
}

foreach ($relative in @('catalogs\mcp-catalog.json', 'catalogs\skill-catalog.json')) {
    $path = Join-Path $harness $relative
    try {
        $catalog = Get-Content -Raw -Encoding utf8 -LiteralPath $path | ConvertFrom-Json
        $duplicates = @($catalog.entries | Group-Object id | Where-Object Count -gt 1)
        foreach ($duplicate in $duplicates) { Add-Issue 'FAIL' 'DUPLICATE_CATALOG_ID' "$relative has duplicate id: $($duplicate.Name)" }
    }
    catch { Add-Issue 'FAIL' 'CATALOG_PARSE' "$relative cannot be parsed: $($_.Exception.Message)" }
}

$lockPath = Join-Path $project '.ai\capability-lock.json'
if (-not (Test-Path -LiteralPath $lockPath)) {
    Add-Issue 'INFO' 'LOCK_NOT_FOUND' 'No project capability lock exists; no on-demand capability has been recorded.'
} else {
    try {
        $lock = Get-Content -Raw -Encoding utf8 -LiteralPath $lockPath | ConvertFrom-Json
        foreach ($capability in $lock.capabilities) {
            if ($capability.scope -ne 'project') { Add-Issue 'FAIL' 'NON_PROJECT_SCOPE' "$($capability.type)/$($capability.id) is not project scoped." }
            if ($capability.version -eq 'latest' -or "$($capability.version)" -match '[\*\^~]') { Add-Issue 'FAIL' 'UNPINNED_VERSION' "$($capability.id) is not pinned to an exact version." }
            if ("$($capability.source)" -match '(?i)(token|password|secret|api[_-]?key)=') { Add-Issue 'FAIL' 'SECRET_PATTERN' "$($capability.id) source appears to contain a credential." }
        }
    } catch { Add-Issue 'FAIL' 'LOCK_PARSE' "capability-lock.json cannot be parsed: $($_.Exception.Message)" }
}

$desiredPath = Join-Path $project '.ai\mcp\desired.json'
if (Test-Path -LiteralPath $desiredPath) {
    try {
        $desired = Get-Content -Raw -Encoding utf8 -LiteralPath $desiredPath | ConvertFrom-Json
        $duplicates = @($desired.servers | Group-Object id | Where-Object Count -gt 1)
        foreach ($duplicate in $duplicates) { Add-Issue 'FAIL' 'DUPLICATE_MCP' "Duplicate MCP id: $($duplicate.Name)" }
    } catch { Add-Issue 'FAIL' 'MCP_DESIRED_PARSE' "desired.json cannot be parsed: $($_.Exception.Message)" }
}

if ($issues.Count -eq 0) {
    [pscustomobject]@{ overall = 'PASS'; project = $project; issues = @() }
} else {
    $overall = if (@($issues | Where-Object severity -eq 'FAIL').Count -gt 0) { 'FAIL' } else { 'PASS_WITH_INFO' }
    [pscustomobject]@{ overall = $overall; project = $project; issues = @($issues) }
}
