[CmdletBinding()]
param([string]$ToolsRoot)

# 공용 Google Workspace MCP 런타임의 위치를 해석한다. 읽기 전용이며 아무것도 설치하지 않는다.
#
# 탐색 순서 (첫 번째 성공이 이긴다). 절대경로를 유일한 후보로 두지 않는다.
#   1. -ToolsRoot 파라미터
#   2. AI_HARNESS_GOOGLE_MCP_COMMAND (프로세스 → User)
#   3. AI_HARNESS_TOOLS_ROOT        (프로세스 → User)
#   4. 플랫폼 기본값  %LOCALAPPDATA%\AI-Tools
#   5. 레거시        C:\AI-Tools     ← 해석은 되지만 drift 로 보고한다

. (Join-Path $PSScriptRoot '_Harness.Common.ps1')

$rel = 'google-workspace-mcp\google-workspace-mcp.cmd'
$candidates = New-Object System.Collections.Generic.List[object]

function Add-Candidate([string]$path, [string]$source) {
    if ($path) { $candidates.Add([pscustomobject]@{ path = $path; source = $source }) }
}

# 후보 경로 조립에 Join-Path 를 쓰지 않는다.
# Join-Path 는 PSDrive 를 해석하므로 존재하지 않는 드라이브(예: Z:\)에서
# DriveNotFoundException 을 던진다 → "없음(4)" 이어야 할 상황이 스크립트 오류가 된다.
# [IO.Path]::Combine 은 순수 문자열 연산이라 파일시스템을 건드리지 않는다.
function Join-Rel([string]$root) {
    if (-not $root) { return $null }
    return [IO.Path]::Combine($root, $rel)
}

if ($ToolsRoot) { Add-Candidate (Join-Rel ([IO.Path]::GetFullPath($ToolsRoot))) 'parameter' }

Add-Candidate $env:AI_HARNESS_GOOGLE_MCP_COMMAND 'command_env_process'
Add-Candidate ([Environment]::GetEnvironmentVariable('AI_HARNESS_GOOGLE_MCP_COMMAND', 'User')) 'command_env_user'

Add-Candidate (Join-Rel $env:AI_HARNESS_TOOLS_ROOT) 'tools_root_env_process'
Add-Candidate (Join-Rel ([Environment]::GetEnvironmentVariable('AI_HARNESS_TOOLS_ROOT', 'User'))) 'tools_root_env_user'

if ($env:LOCALAPPDATA) { Add-Candidate ([IO.Path]::Combine($env:LOCALAPPDATA, 'AI-Tools', $rel)) 'platform_default' }
Add-Candidate (Join-Rel 'C:\AI-Tools') 'legacy_tools_root'

$hit = $candidates | Where-Object { Test-Path -LiteralPath $_.path } | Select-Object -First 1

if (-not $hit) {
    [pscustomobject]@{
        found = $false; command = $null; tools_root_source = $null
        auth_files_present = $false; authenticated = 'unknown'; drift = @('absent')
    }
    exit 4   # 4 = 없음. 스크립트 실패(1)와 구분한다.
}

# drift 는 "어떤 후보가 이겼는가"가 아니라 "실제로 해석된 경로가 어디인가"로 판정한다.
# -ToolsRoot 로 레거시 경로를 직접 지정해도 레거시는 레거시다.
$drift = @()
$legacyRoots = @('C:\AI-Tools')
foreach ($lr in $legacyRoots) {
    if ($hit.path.StartsWith($lr, [StringComparison]::OrdinalIgnoreCase)) { $drift += 'legacy_tools_root'; break }
}

# 자격증명 파일의 "존재"는 인증 여부가 아니다. 토큰은 만료되거나 폐기될 수 있다.
# 실제 인증 판정은 read-only API 호출을 수행하는 검증 단계만 할 수 있다.
$profileRoot = Join-HarnessPath (Get-HarnessHome) '.config' 'google-workspace-mcp' 'profiles' 'default'
$authFiles = (Test-Path -LiteralPath (Join-HarnessPath $profileRoot 'credentials.json')) -and
             (Test-Path -LiteralPath (Join-HarnessPath $profileRoot 'tokens.json'))

[pscustomobject]@{
    found              = $true
    command            = $hit.path
    tools_root_source  = $hit.source
    auth_files_present = $authFiles
    authenticated      = 'unknown'
    drift              = $drift
}

if ($drift.Count -gt 0) { exit 3 }   # 3 = 발견했으나 조치가 필요한 drift
exit 0
