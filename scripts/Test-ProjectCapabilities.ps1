[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$HarnessRoot
)

# [CmdletBinding()] 가 있으면 PS 5.1 은 param 기본값 평가 시 $PSScriptRoot 를 비워 둔다.
if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Common.ps1')

$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$harness = (Resolve-Path -LiteralPath $HarnessRoot).Path
$issues = [System.Collections.Generic.List[object]]::new()

function Add-Issue([string]$severity, [string]$code, [string]$message) {
    $issues.Add([pscustomobject]@{ severity = $severity; code = $code; message = $message })
}

foreach ($relative in @('mcp-catalog.json', 'skill-catalog.json')) {
    $path = Join-HarnessPath $harness 'catalogs' $relative
    try {
        $catalog = Read-HarnessJson -Path $path
        $duplicates = @($catalog.entries | Group-Object id | Where-Object Count -gt 1)
        foreach ($duplicate in $duplicates) { Add-Issue 'FAIL' 'DUPLICATE_CATALOG_ID' "$relative has duplicate id: $($duplicate.Name)" }
    }
    catch { Add-Issue 'FAIL' 'CATALOG_PARSE' "$relative cannot be parsed: $($_.Exception.Message)" }
}

$lockPath = Join-HarnessPath $project '.ai' 'capability-lock.json'
if (-not (Test-Path -LiteralPath $lockPath)) {
    Add-Issue 'INFO' 'LOCK_NOT_FOUND' 'No project capability lock exists; no on-demand capability has been recorded.'
} else {
    try {
        $lock = Read-HarnessJson -Path $lockPath
        # scope 는 project 만 허용하는 것이 아니다.
        # 공용 런타임(machine_user)은 설계상 정당한 범위이므로 FAIL 이 아니다.
        # 단 기본값은 여전히 project 이고, 그 외 값은 명시적으로 알려진 것만 허용한다.
        $allowedScopes = @('project', 'machine_user', 'client_user')
        foreach ($capability in $lock.capabilities) {
            if ($allowedScopes -notcontains $capability.scope) {
                Add-Issue 'FAIL' 'UNKNOWN_SCOPE' "$($capability.type)/$($capability.id) has unknown scope '$($capability.scope)'."
            } elseif ($capability.scope -ne 'project') {
                Add-Issue 'INFO' 'NON_PROJECT_SCOPE' "$($capability.type)/$($capability.id) is $($capability.scope) scoped (shared runtime)."
            }
            if ($capability.PSObject.Properties.Name -contains 'project_root' -and $capability.project_root) {
                Add-Issue 'FAIL' 'MACHINE_PATH_IN_LOCK' "$($capability.id) records a machine-specific project_root; it is wrong on every other machine."
            }
            if ($capability.version -eq 'latest' -or "$($capability.version)" -match '[\*\^~]') { Add-Issue 'FAIL' 'UNPINNED_VERSION' "$($capability.id) is not pinned to an exact version." }
            if ("$($capability.source)" -match '(?i)(token|password|secret|api[_-]?key)=') { Add-Issue 'FAIL' 'SECRET_PATTERN' "$($capability.id) source appears to contain a credential." }
        }
    } catch { Add-Issue 'FAIL' 'LOCK_PARSE' "capability-lock.json cannot be parsed: $($_.Exception.Message)" }
}

$desiredPath = Join-HarnessPath $project '.ai' 'mcp' 'desired.json'
if (Test-Path -LiteralPath $desiredPath) {
    try {
        $desired = Read-HarnessJson -Path $desiredPath
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
