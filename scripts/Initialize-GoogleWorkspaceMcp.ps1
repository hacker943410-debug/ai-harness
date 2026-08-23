[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ToolsRoot = $(if ($env:AI_HARNESS_TOOLS_ROOT) { $env:AI_HARNESS_TOOLS_ROOT } else { 'C:\AI-Tools' }),
    [string]$Profile = 'default',
    [switch]$RegisterInstalledClients
)

$ErrorActionPreference = 'Stop'
$runtime = Join-Path ([IO.Path]::GetFullPath($ToolsRoot)) 'google-workspace-mcp'
$launcher = Join-Path $runtime 'google-workspace-mcp.cmd'
$packageJson = Join-Path $runtime 'package.json'
$packageVersion = '3.4.4'

if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw 'Node.js와 npm이 필요합니다. Node.js 22 이상을 먼저 설치하세요.'
}
$nodeMajor = [int]((& node --version).TrimStart('v').Split('.')[0])
if ($nodeMajor -lt 22) { throw "Node.js 22 이상이 필요합니다. 현재 major version: $nodeMajor" }

if (-not (Test-Path -LiteralPath $launcher)) {
    if (-not $PSCmdlet.ShouldProcess($runtime, "Install Google Workspace MCP $packageVersion")) { return }
    New-Item -ItemType Directory -Force -Path $runtime | Out-Null
    @{ name = 'local-google-workspace-mcp-runtime'; private = $true; version = '1.0.0'; dependencies = @{ '@dguido/google-workspace-mcp' = $packageVersion } } |
        ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 -LiteralPath $packageJson
    Push-Location -LiteralPath $runtime
    try { & npm install --ignore-scripts } finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { throw "npm install failed with exit code $LASTEXITCODE" }
    @"
@echo off
set "GOOGLE_WORKSPACE_SERVICES=drive,gmail,calendar,docs,sheets,slides,contacts"
set "GOOGLE_WORKSPACE_MCP_PROFILE=$Profile"
set "GOOGLE_WORKSPACE_TOON_FORMAT=true"
"$runtime\node_modules\.bin\google-workspace-mcp.cmd" start
"@ | Set-Content -Encoding ascii -LiteralPath $launcher
}

[Environment]::SetEnvironmentVariable('AI_HARNESS_GOOGLE_MCP_COMMAND', $launcher, 'User')
$env:AI_HARNESS_GOOGLE_MCP_COMMAND = $launcher
$credentialRoot = Join-Path $env:USERPROFILE ".config\google-workspace-mcp\profiles\$Profile"
$result = [ordered]@{ command = $launcher; installed = Test-Path -LiteralPath $launcher; credential_present = Test-Path -LiteralPath (Join-Path $credentialRoot 'credentials.json'); token_present = Test-Path -LiteralPath (Join-Path $credentialRoot 'tokens.json'); clients = @() }

if ($RegisterInstalledClients) {
    if (Get-Command codex -ErrorAction SilentlyContinue) {
        & codex mcp get google-workspace *> $null
        if ($LASTEXITCODE -ne 0 -and $PSCmdlet.ShouldProcess('Codex user config', 'Register google-workspace MCP')) { & codex mcp add google-workspace -- $launcher }
        $result.clients += 'codex'
    }
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        & claude mcp get google-workspace *> $null
        if ($LASTEXITCODE -ne 0 -and $PSCmdlet.ShouldProcess('Claude user config', 'Register google-workspace MCP')) { & claude mcp add --scope user google-workspace -- $launcher }
        $result.clients += 'claude'
    }
    if (Get-Command agy -ErrorAction SilentlyContinue) {
        $agyConfig = Join-Path $env:USERPROFILE '.gemini\config\mcp_config.json'
        $agyDirectory = Split-Path -Parent $agyConfig
        if ((Test-Path -LiteralPath $agyConfig) -and ((Get-Item -LiteralPath $agyConfig).Length -gt 0)) {
            $agyJson = Get-Content -Raw -Encoding utf8 -LiteralPath $agyConfig | ConvertFrom-Json
        } else {
            $agyJson = [pscustomobject]@{}
        }
        if (-not $agyJson.mcpServers) { $agyJson | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{}) }
        if (-not $agyJson.mcpServers.'google-workspace' -and $PSCmdlet.ShouldProcess('AGY global MCP config', 'Register google-workspace MCP')) {
            $agyJson.mcpServers | Add-Member -NotePropertyName 'google-workspace' -NotePropertyValue ([pscustomobject]@{ command = $launcher })
            New-Item -ItemType Directory -Force -Path $agyDirectory | Out-Null
            $agyJson | ConvertTo-Json -Depth 20 | Set-Content -Encoding utf8 -LiteralPath $agyConfig
        }
        $result.clients += 'agy'
    }
}
[pscustomobject]$result
