[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Id,
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$Version,
    [string]$Reason = 'capability_gap',
    [string]$HarnessRoot
)

# [CmdletBinding()] 가 있으면 PS 5.1 은 param 기본값 평가 시 $PSScriptRoot 를 비워 둔다.
if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Common.ps1')

$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$catalogPath = Join-HarnessPath (Resolve-Path -LiteralPath $HarnessRoot).Path 'catalogs' 'mcp-catalog.json'
$catalog = Read-HarnessJson -Path $catalogPath
# $Matches 는 -match 가 채우는 자동 변수다. 같은 이름을 쓰면 나중에 조용히 덮인다.
$hits = @($catalog.entries | Where-Object id -eq $Id)
if ($hits.Count -ne 1) { throw "MCP '$Id' was not found uniquely in the catalog." }
$entry = $hits[0]
if ($entry.status -eq 'discovery_only') { throw "MCP '$Id' is discovery_only. Verify it in the official Registry before installation." }

$kind = $entry.install.kind

# 공용 런타임은 PC 에 하나만 둔다.
# 프로젝트마다 설치하면 (1) 버전이 프로젝트 수만큼 갈라지고
# (2) 각 사본이 같은 OAuth 토큰을 쓰게 되며 (3) 정본이 매니페스트인지
# 프로젝트 lock 인지 아무도 모르게 된다. 여기서 막지 않으면 반드시 그렇게 된다.
if ($kind -eq 'shared_runtime') {
    $rid = $entry.install.runtime_id
    throw ("MCP '$Id' 는 공용 런타임입니다(install.kind=shared_runtime). 프로젝트별로 설치하지 않습니다.`n" +
           "  PC 에 설치 : .\scripts\Install-HarnessRuntime.ps1 -RuntimeId $rid`n" +
           "  인증       : .\scripts\Connect-HarnessRuntimeAuth.ps1 -RuntimeId $rid`n" +
           "  검증       : .\scripts\Test-HarnessRuntime.ps1 -RuntimeId $rid`n" +
           "  클라이언트 : .\scripts\Sync-HarnessClients.ps1 -SavePlan .\sync.json`n" +
           "  버전의 정본은 $($entry.install.manifest) 입니다.")
}

if ($kind -eq 'npm') {
    if (-not $Version) { throw "An exact -Version is required for local npm MCP installation." }
    if ($Version -eq 'latest' -or $Version.Contains('*') -or $Version.Contains('^') -or $Version.Contains('~')) {
        throw 'Version must be exact; latest, wildcards, caret, and tilde ranges are not allowed.'
    }
    $packageSpec = "$($entry.install.package)@$Version"
    if ($PSCmdlet.ShouldProcess($project, "npm install --save-dev --save-exact $packageSpec")) {
        if (-not (Test-Path -LiteralPath (Join-HarnessPath $project 'package.json'))) {
            throw 'Project package.json is required for project-local npm MCP installation.'
        }
        # npm 은 PATH 에서 .ps1 로 먼저 잡히고, .ps1 은 ExecutionPolicy 의 지배를 받는다.
        # Restricted 인 PC 에서는 npm 이 실행되기도 전에 PSSecurityException 으로 죽는다.
        $npmExe = Get-HarnessNativeCommand 'npm'
        if (-not $npmExe) { throw 'npm not found on PATH.' }
        Push-Location -LiteralPath $project
        try { & $npmExe install --save-dev --save-exact $packageSpec } finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) { throw "npm exited with code $LASTEXITCODE." }
    } else { return }
} elseif ($kind -eq 'remote') {
    if (-not $PSCmdlet.ShouldProcess($project, "record remote MCP $Id")) { return }
} else {
    throw "MCP '$Id' uses install kind '$kind'. Confirm current official coordinates and configure it with the client-specific project adapter."
}

$aiDir = Join-HarnessPath $project '.ai'
$mcpDir = Join-HarnessPath $aiDir 'mcp'
New-Item -ItemType Directory -Force -Path $mcpDir | Out-Null
$desiredPath = Join-HarnessPath $mcpDir 'desired.json'
if (Test-Path -LiteralPath $desiredPath) {
    $desired = Read-HarnessJson -Path $desiredPath
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
Write-HarnessJson -Path $desiredPath -InputObject $desired -Depth 8

$lockPath = Join-HarnessPath $aiDir 'capability-lock.json'
if (Test-Path -LiteralPath $lockPath) {
    $lock = Read-HarnessJson -Path $lockPath
} else {
    # project_root 를 기록하지 않는다. 커밋되는 lock 에 머신 절대경로가 들어가면
    # 다른 모든 PC 에서 틀린 값이 된다.
    $lock = [pscustomobject]@{ schema_version = '1.0'; capabilities = @() }
}
$remaining = @($lock.capabilities | Where-Object { -not ($_.type -eq 'mcp' -and $_.id -eq $Id) })
$source = if ($kind -eq 'npm') { $entry.install.package } else { $entry.install.url }
$record = [pscustomobject]@{
    type = 'mcp'; id = $Id; source = $source; version = $Version; content_hash = $null
    scope = 'project'; reason = $Reason; status = 'configured'; config_path = '.ai/mcp/desired.json'
    recorded_at = (Get-HarnessUtcStamp)
}
$lock.capabilities = @($remaining + $record)
Write-HarnessJson -Path $lockPath -InputObject $lock -Depth 8
Write-Output "MCP '$Id' is recorded for this project. Apply the desired entry to the active client's official project MCP configuration, then run a read-only smoke test before marking it verified."
