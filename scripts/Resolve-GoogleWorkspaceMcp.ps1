[CmdletBinding()]
param([string]$ToolsRoot)

$candidates = @()
if ($env:AI_HARNESS_GOOGLE_MCP_COMMAND) { $candidates += $env:AI_HARNESS_GOOGLE_MCP_COMMAND }
$userValue = [Environment]::GetEnvironmentVariable('AI_HARNESS_GOOGLE_MCP_COMMAND', 'User')
if ($userValue) { $candidates += $userValue }
if ($ToolsRoot) { $candidates += (Join-Path ([IO.Path]::GetFullPath($ToolsRoot)) 'google-workspace-mcp\google-workspace-mcp.cmd') }
$candidates += 'C:\AI-Tools\google-workspace-mcp\google-workspace-mcp.cmd'

$resolved = $candidates | Select-Object -Unique | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $resolved) {
    [pscustomobject]@{ found = $false; command = $null; authenticated = $false }
    exit 1
}
$token = Join-Path $env:USERPROFILE '.config\google-workspace-mcp\profiles\default\tokens.json'
[pscustomobject]@{ found = $true; command = $resolved; authenticated = Test-Path -LiteralPath $token }
