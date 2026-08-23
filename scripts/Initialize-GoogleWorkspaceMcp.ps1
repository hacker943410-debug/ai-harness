[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ToolsRoot = $(
        if ($env:AI_HARNESS_TOOLS_ROOT) { $env:AI_HARNESS_TOOLS_ROOT }
        elseif ([Environment]::GetEnvironmentVariable('AI_HARNESS_TOOLS_ROOT','User')) { [Environment]::GetEnvironmentVariable('AI_HARNESS_TOOLS_ROOT','User') }
        elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'AI-Tools' }
        else { 'C:\AI-Tools' }
    ),
    [string]$Profile = 'default',
    [switch]$RegisterInstalledClients
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Common.ps1')
Initialize-HarnessConsole

$runtime = Join-HarnessPath ([IO.Path]::GetFullPath($ToolsRoot)) 'google-workspace-mcp'
$launcher = Join-HarnessPath $runtime 'google-workspace-mcp.cmd'
$packageJson = Join-HarnessPath $runtime 'package.json'
$packageVersion = '3.4.4'

if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw 'Node.js와 npm이 필요합니다. Node.js 22 이상을 먼저 설치하세요.'
}
$nodeMajor = [int]((& node --version).TrimStart('v').Split('.')[0])
if ($nodeMajor -lt 22) { throw "Node.js 22 이상이 필요합니다. 현재 major version: $nodeMajor" }

if (-not (Test-Path -LiteralPath $launcher)) {
    if (-not $PSCmdlet.ShouldProcess($runtime, "Install Google Workspace MCP $packageVersion")) { return }
    New-Item -ItemType Directory -Force -Path $runtime | Out-Null
    # npm 은 선행 BOM 이 있는 package.json 을 거부한다.
    # PS 5.1 의 Set-Content -Encoding utf8 은 BOM 을 붙이므로 쓰면 안 된다.
    Write-HarnessJson -Path $packageJson -Depth 4 -InputObject @{
        name = 'local-google-workspace-mcp-runtime'
        private = $true
        version = '1.0.0'
        dependencies = @{ '@dguido/google-workspace-mcp' = $packageVersion }
    }
    Push-Location -LiteralPath $runtime
    try { & npm install --ignore-scripts } finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { throw "npm install failed with exit code $LASTEXITCODE" }
    # .cmd 는 cmd.exe 가 콘솔 OEM 코드페이지로 읽는다. UTF-8 로 써도 비ASCII 경로는 깨진다.
    # 기존 코드는 -Encoding ascii 로 써서 비ASCII 문자를 조용히 '?' 로 바꿨다.
    # 조용한 손상 대신 명시적 실패로 바꾼다. (M7 에서 런처 생성 자체를 없앤다.)
    $binPath = Join-HarnessPath $runtime 'node_modules' '.bin' 'google-workspace-mcp.cmd'
    if ($binPath -match '[^\x00-\x7F]') {
        throw "런타임 경로에 비ASCII 문자가 있어 .cmd 런처를 안전하게 생성할 수 없습니다: $binPath`n" +
              "ASCII 경로의 -ToolsRoot 를 사용하거나, .bin shim 을 직접 등록하세요."
    }
    $launcherText = @"
@echo off
set "GOOGLE_WORKSPACE_SERVICES=drive,gmail,calendar,docs,sheets,slides,contacts"
set "GOOGLE_WORKSPACE_MCP_PROFILE=$Profile"
set "GOOGLE_WORKSPACE_TOON_FORMAT=true"
"$binPath" start
"@
    [IO.File]::WriteAllText($launcher, $launcherText, [Text.Encoding]::ASCII)
}

[Environment]::SetEnvironmentVariable('AI_HARNESS_GOOGLE_MCP_COMMAND', $launcher, 'User')
$env:AI_HARNESS_GOOGLE_MCP_COMMAND = $launcher
$credentialRoot = Join-HarnessPath (Get-HarnessHome) '.config' 'google-workspace-mcp' 'profiles' $Profile
$result = [ordered]@{
    command            = $launcher
    installed          = Test-Path -LiteralPath $launcher
    credential_present = Test-Path -LiteralPath (Join-HarnessPath $credentialRoot 'credentials.json')
    # 토큰 파일의 존재는 인증 여부가 아니다. 만료·폐기될 수 있다.
    auth_files_present = Test-Path -LiteralPath (Join-HarnessPath $credentialRoot 'tokens.json')
    authenticated      = 'unknown'
    clients            = @()
}

if ($RegisterInstalledClients) {
    # "등록 명령을 실행했다"와 "등록됐다"는 다른 사건이다.
    # 이전 판은 add 성공 여부와 무관하게 clients 목록에 이름을 넣어,
    # codex 가 실제로는 미등록인데 등록 완료로 보고되는 상태를 만들었다.
    # 항상 등록 후 재조회로 확인하고, 그 결과만 기록한다.
    if (Get-Command codex -ErrorAction SilentlyContinue) {
        & codex mcp get google-workspace *> $null
        if ($LASTEXITCODE -ne 0 -and $PSCmdlet.ShouldProcess('Codex global config', 'Register google-workspace MCP')) {
            & codex mcp add google-workspace -- $launcher | Out-Null
        }
        & codex mcp get google-workspace *> $null
        $result.clients += [pscustomobject]@{ client = 'codex'; registered = ($LASTEXITCODE -eq 0) }
    }
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        & claude mcp get google-workspace *> $null
        if ($LASTEXITCODE -ne 0 -and $PSCmdlet.ShouldProcess('Claude user config', 'Register google-workspace MCP')) {
            & claude mcp add --scope user google-workspace -- $launcher | Out-Null
        }
        & claude mcp get google-workspace *> $null
        $result.clients += [pscustomobject]@{ client = 'claude'; registered = ($LASTEXITCODE -eq 0) }
    }
    if (Get-Command agy -ErrorAction SilentlyContinue) {
        # 설정 파일을 직접 편집하지 않는다. `agy mcp add` 는 공식 명령이며 upsert 다.
        # 설정 파일 경로를 가정하는 코드는 클라이언트가 경로를 바꾸면 조용히 틀린 답을 준다.
        $registered = (& agy mcp list 2>&1 | Out-String) -match 'google-workspace'
        if (-not $registered -and $PSCmdlet.ShouldProcess('AGY global MCP config', 'Register google-workspace MCP')) {
            & agy mcp add google-workspace $launcher | Out-Null
            # 등록 후 반드시 되읽어 확인한다. 명령 실행과 등록 완료는 다른 사건이다.
            $registered = (& agy mcp list 2>&1 | Out-String) -match 'google-workspace'
        }
        $result.clients += [pscustomobject]@{ client = 'agy'; registered = [bool]$registered }
    }
}
[pscustomobject]$result
