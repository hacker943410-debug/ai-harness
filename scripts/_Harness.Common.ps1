#Requires -Version 5.1
<#
    AI Harness — 공통 헬퍼

    목적: 경로·인코딩 버그의 단일 수정 지점.
    각 스크립트가 개별적으로 -Encoding 을 기억하거나 Join-Path 관용구를 반복하면
    한 곳만 빠뜨려도 조용히 깨진다. 여기서 한 번만 옳게 하고 전부 여기를 쓴다.

    사용:
        . (Join-Path $PSScriptRoot '_Harness.Common.ps1')

    이 파일은 UTF-8 with BOM 으로 저장한다.
    Windows PowerShell 5.1 은 BOM 이 없으면 소스를 ANSI 코드페이지로 디코딩하므로
    (이 PC 는 949) 한글 문자열이 깨지거나 파서 오류가 난다.
#>

# 여기서 Set-StrictMode 를 호출하지 않는다.
# 이 파일은 dot-source 되므로 호출자 스코프에 적용되어,
# 기존 스크립트의 동작을 헬퍼가 몰래 바꾸게 된다. 엄격 모드는 각 스크립트가 스스로 정한다.

# PS 5.1 에는 $IsWindows 자동 변수가 없다(PS 7 에는 있다). 함수보다 먼저 정의한다.
$script:HarnessIsWindows = $true
$isWinVar = Get-Variable -Name IsWindows -ErrorAction SilentlyContinue
if ($isWinVar) { $script:HarnessIsWindows = [bool]$isWinVar.Value }

# ---------------------------------------------------------------------------
# 경로
# ---------------------------------------------------------------------------

<#
    Join-Path 를 직접 쓰지 않는 이유 두 가지.

    1. Join-Path 의 2번째 인자는 재정규화되지 않는다.
       Join-Path '/home/u' 'catalogs\x.json' 은 유닉스에서
       '/home/u/catalogs\x.json' 이라는 '백슬래시가 든 파일명 하나'를 만든다.

    2. Join-Path 는 PSDrive 를 해석한다.
       존재하지 않는 드라이브(Z:\)에서 DriveNotFoundException 을 던지므로,
       "없음"으로 처리해야 할 상황이 스크립트 오류가 된다.

    [IO.Path]::Combine 은 순수 문자열 연산이라 둘 다 해당하지 않는다.
#>
function Join-HarnessPath {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)][object[]]$Segments)

    # 파라미터 타입이 [string[]] 이면, 배열 하나를 통째로 넘겼을 때
    # PowerShell 이 그것을 $OFS(기본 공백)로 이어붙여 단일 문자열로 만든다.
    #   Join-HarnessPath @('C:\root','catalogs','x.json')  ->  'C:\root catalogs x.json'
    # [object[]] 로 받고 직접 평탄화해서 두 호출 방식을 모두 지원한다.
    $flat = New-Object System.Collections.Generic.List[string]
    function Add-Flat($item) {
        if ($null -eq $item) { return }
        if ($item -is [string]) { $flat.Add($item); return }
        if ($item -is [System.Collections.IEnumerable]) {
            foreach ($sub in $item) { Add-Flat $sub }
            return
        }
        $flat.Add([string]$item)
    }
    foreach ($s in $Segments) { Add-Flat $s }

    $sep = [string][IO.Path]::DirectorySeparatorChar
    $norm = @()
    foreach ($s in $flat) {
        if ([string]::IsNullOrWhiteSpace($s)) { continue }
        $norm += $s.Replace('\', $sep).Replace('/', $sep)
    }
    if ($norm.Count -eq 0) { return $null }

    $acc = $norm[0]
    for ($i = 1; $i -lt $norm.Count; $i++) { $acc = [IO.Path]::Combine($acc, $norm[$i]) }
    return $acc
}

# $env:USERPROFILE 은 Windows 에만 존재한다.
# 유닉스에서 그대로 쓰면 Join-Path 가 null 인자로 예외를 던진다.
function Get-HarnessHome {
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    if ($env:HOME) { return $env:HOME }
    return [Environment]::GetFolderPath('UserProfile')
}

function Get-HarnessConfigHome {
    if ($env:LOCALAPPDATA) { return $env:LOCALAPPDATA }
    if ($env:XDG_CONFIG_HOME) { return $env:XDG_CONFIG_HOME }
    return (Join-HarnessPath (Get-HarnessHome) '.config')
}

function Get-HarnessToolsRoot {
    param([string]$Override)
    if ($Override) { return [IO.Path]::GetFullPath($Override) }
    if ($env:AI_HARNESS_TOOLS_ROOT) { return $env:AI_HARNESS_TOOLS_ROOT }
    $userValue = [Environment]::GetEnvironmentVariable('AI_HARNESS_TOOLS_ROOT', 'User')
    if ($userValue) { return $userValue }
    if ($env:LOCALAPPDATA) { return (Join-HarnessPath $env:LOCALAPPDATA 'AI-Tools') }
    return (Join-HarnessPath (Get-HarnessHome) '.ai-tools')
}

# ---------------------------------------------------------------------------
# 인코딩
# ---------------------------------------------------------------------------

<#
    PS 5.1 의 -Encoding utf8 은 BOM 을 붙이고, PS 7 은 붙이지 않는다.
    같은 코드가 호스트에 따라 다른 바이트를 만든다는 뜻이고,
    JSON.parse 와 npm 은 선행 U+FEFF 를 거부한다.
    그래서 JSON 읽기/쓰기는 항상 명시적 UTF8Encoding($false) 로 한다.
#>
function Get-HarnessUtf8NoBom { return (New-Object System.Text.UTF8Encoding($false)) }

function Read-HarnessText {
    param([Parameter(Mandatory = $true)][string]$Path)
    $text = [IO.File]::ReadAllText($Path, (Get-HarnessUtf8NoBom))
    return $text.TrimStart([char]0xFEFF)
}

function Read-HarnessJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Read-HarnessText -Path $Path | ConvertFrom-Json)
}

function Write-HarnessJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$InputObject,
        [int]$Depth = 12
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $json = $InputObject | ConvertTo-Json -Depth $Depth
    [IO.File]::WriteAllText($Path, $json, (Get-HarnessUtf8NoBom))
}

function Write-HarnessText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    [IO.File]::WriteAllText($Path, $Text, (Get-HarnessUtf8NoBom))
}

<#
    네이티브 CLI 의 stdout 을 캡처하는 스크립트에서 호출한다.
    powershell -NoProfile 콘솔은 OEM 코드페이지를 상속하므로(여기서는 949)
    비ASCII 경로가 깨진 채로 잡히고, 그 문자열로 만든 지문은 영구 drift 를 만든다.
#>
function Initialize-HarnessConsole {
    try {
        [Console]::OutputEncoding = (Get-HarnessUtf8NoBom)
        $global:OutputEncoding = (Get-HarnessUtf8NoBom)
    } catch {
        Write-Verbose "콘솔 인코딩을 설정하지 못했습니다: $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# 시간
# ---------------------------------------------------------------------------

# 로컬 오프셋은 커밋되는 lock 파일을 계속 흔든다. 항상 UTC.
function Get-HarnessUtcStamp { return [DateTimeOffset]::UtcNow.ToString('o') }

# ---------------------------------------------------------------------------
# 경로 신뢰성 (보안)
# ---------------------------------------------------------------------------

<#
    공용 도구 루트는 소유자/SYSTEM/Administrators 외에는 쓸 수 없어야 한다.
    C:\ 바로 아래 만든 폴더는 Authenticated Users: Modify 를 상속받으므로,
    관리자 권한 없는 다른 로컬 사용자가 MCP 실행 파일을 교체할 수 있다.
    실제로 이 하네스의 초기 구성이 그 상태였다.
#>
function Test-HarnessPathTrust {
    param([Parameter(Mandatory = $true)][string]$Path)

    $result = [ordered]@{ path = $Path; trusted = $true; checked = $false; offenders = @() }
    if (-not (Test-Path -LiteralPath $Path)) {
        $result.trusted = $false
        $result.offenders = @('path_not_found')
        return [pscustomobject]$result
    }
    if (-not $script:HarnessIsWindows) { return [pscustomobject]$result }   # 비Windows 는 미구현

    try {
        $acl = Get-Acl -LiteralPath $Path
        $allowedSids = @('S-1-5-18', 'S-1-5-32-544')
        $me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $writeRights = 'Write|Modify|FullControl|TakeOwnership|ChangePermissions'

        $bad = @()
        foreach ($ace in $acl.Access) {
            if ($ace.AccessControlType -ne 'Allow') { continue }
            if ("$($ace.FileSystemRights)" -notmatch $writeRights) { continue }
            $sid = $null
            try { $sid = $ace.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value } catch { }
            if ($sid -and ($allowedSids -contains $sid -or $sid -eq $me)) { continue }
            if ($sid -and $sid.StartsWith('S-1-5-80')) { continue }   # 서비스 SID
            $bad += "$($ace.IdentityReference) [$($ace.FileSystemRights)]"
        }
        $result.checked = $true
        $result.offenders = $bad
        $result.trusted = ($bad.Count -eq 0)
    } catch {
        $result.checked = $false
        $result.trusted = $false
        $result.offenders = @("acl_read_failed: $($_.Exception.Message)")
    }
    return [pscustomobject]$result
}
