#Requires -Version 5.1
<#
    AI Harness — 부트스트랩

    한 줄 설치·업데이트:

        irm https://raw.githubusercontent.com/hacker943410-debug/ai-harness/main/install.ps1 | iex

    옵션을 주려면 (irm | iex 는 인자를 못 넘긴다):

        & ([scriptblock]::Create((irm https://raw.githubusercontent.com/hacker943410-debug/ai-harness/main/install.ps1))) -Path 'C:\dev\ai-harness'

    이 스크립트가 하는 일
        1. 사전 조건 확인 (PowerShell 5.1+ / git / Node 22+ / npm)
        2. 클론 위치 검증 (비ASCII·동기화 폴더·깊은 경로·UNC 를 거른다)
        3. 없으면 clone, 있으면 fetch 후 최신 태그로 이동  ← 설치와 업데이트가 같은 명령
        4. 비밀값 가드 활성화 (core.hooksPath)
        5. 저장소 자체 검사 실행
        6. 다음 단계 안내

    하지 않는 일
        도구 루트(Layer B)를 만들지 않는다. MCP 를 설치하거나 등록하지 않는다.
        인증하지 않는다. 프로젝트(Layer C)를 건드리지 않는다.
        그것들은 각각 확인 절차를 가진 별도 단계다.

    사용자가 고쳐 둔 저장소는 건드리지 않는다.
    커밋 안 한 변경이 있거나 origin 보다 앞서 있으면 보고만 하고 멈춘다.

    주의: 이 파일은 iex 로 실행될 수 있다. 그때는 호출자 세션에서 도는 것이므로
    `exit` 를 쓰면 사용자의 PowerShell 창이 닫힌다. 전부 함수 안에서 return 한다.
#>
[CmdletBinding()]
param(
    [string]$Path,
    [string]$Ref,
    [switch]$SkipChecks
)

$RepoUrl = 'https://github.com/hacker943410-debug/ai-harness.git'
$RepoWeb = 'https://github.com/hacker943410-debug/ai-harness'

function Write-Step {
    param([string]$Text)
    Write-Output ''
    Write-Output "== $Text"
}

function Write-Item {
    param([string]$Mark, [string]$Text)
    Write-Output ("   {0} {1}" -f $Mark, $Text)
}

function Test-AsciiPath {
    param([string]$Value)
    return ($Value -notmatch '[^\x00-\x7F]')
}

function Get-LatestRemoteTag {
    param([string]$Url)
    # 핀 고정을 강제하는 도구가 자기 자신은 떠다니는 HEAD 로 받으면 앞뒤가 맞지 않는다.
    # 태그를 원격에서 직접 읽으므로 이 스크립트에 버전을 박지 않는다.
    $lines = @(& git ls-remote --tags --refs $Url 2>$null)
    if ($LASTEXITCODE -ne 0) { return $null }
    $tags = @()
    foreach ($line in $lines) {
        if ($line -match 'refs/tags/(v\d+\.\d+(\.\d+)?)$') { $tags += $Matches[1] }
    }
    if ($tags.Count -eq 0) { return $null }
    $sorted = @($tags | Sort-Object -Property @{ Expression = { [version]($_ -replace '^v', '') } })
    return $sorted[-1]
}

function Invoke-HarnessBootstrap {
    param([string]$Path, [string]$Ref, [switch]$SkipChecks)

    try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { }

    Write-Output ''
    Write-Output '--------------------------------------------------------------------'
    Write-Output '  AI Harness — 설치 / 업데이트'
    Write-Output '--------------------------------------------------------------------'
    Write-Output "  저장소 : $RepoWeb  (Public, MIT)"
    Write-Output '  이 스크립트는 하네스를 받기만 합니다.'
    Write-Output '  도구 설치·등록·인증은 각각 확인을 받는 별도 단계입니다.'

    # -----------------------------------------------------------------------
    # 1. 사전 조건
    # -----------------------------------------------------------------------
    Write-Step '사전 조건'
    $blocked = @()

    Write-Item 'ok' "PowerShell $($PSVersionTable.PSVersion)"

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        Write-Item 'ok' ((& git --version) -join '')
    }
    else {
        Write-Item '!!' 'git 이 없습니다.'
        Write-Item '  ' '설치: winget install --id Git.Git   (또는 https://git-scm.com)'
        $blocked += 'git'
    }

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nodeVer = ((& node --version) -join '').TrimStart('v')
        $major = 0
        $null = [int]::TryParse(($nodeVer -split '\.')[0], [ref]$major)
        if ($major -ge 22) { Write-Item 'ok' "Node $nodeVer" }
        else {
            Write-Item '!!' "Node $nodeVer — 22 이상이 필요합니다."
            Write-Item '  ' '설치: winget install --id OpenJS.NodeJS.LTS'
            $blocked += 'node'
        }
    }
    else {
        Write-Item '!!' 'Node 가 없습니다. (MCP 런타임 설치에 필요)'
        Write-Item '  ' '설치: winget install --id OpenJS.NodeJS.LTS'
        $blocked += 'node'
    }

    if ($blocked.Count -gt 0) {
        if ($SkipChecks) {
            Write-Output ''
            Write-Output "  -SkipChecks 가 지정돼 계속합니다. 빠진 것: $($blocked -join ', ')"
        }
        elseif ($blocked -contains 'git') {
            Write-Output ''
            Write-Output '  git 없이는 받을 수 없습니다. 설치 후 다시 실행하세요.'
            return
        }
        else {
            Write-Output ''
            Write-Output '  Node 는 하네스를 받는 데는 필요 없지만 MCP 런타임 설치에 필요합니다.'
            Write-Output '  받기는 계속합니다.'
        }
    }

    # -----------------------------------------------------------------------
    # 2. 위치
    # -----------------------------------------------------------------------
    Write-Step '설치 위치'
    if (-not $Path) { $Path = Join-Path $env:LOCALAPPDATA 'AI-Harness' }

    $problems = @()
    if (-not (Test-AsciiPath $Path)) {
        $problems += '경로에 비ASCII 문자(한글 등)가 있습니다. 콘솔 코드페이지에 따라 깨지고 .cmd 런처 생성이 거부됩니다.'
    }
    if ($Path -match '[&()^%!]') {
        $problems += '경로에 & ( ) ^ % ! 가 있습니다. .cmd 래퍼에서 깨집니다.'
    }
    if ($Path -match 'OneDrive|Dropbox|Google ?Drive|iCloud') {
        $problems += '동기화 폴더입니다. 설정·상태 파일이 의도치 않게 동기화됩니다.'
    }
    if ($Path.StartsWith('\\')) {
        $problems += 'UNC/네트워크 경로입니다. npm 설치가 느리거나 실패합니다.'
    }
    if ($Path.Length -gt 60) {
        $problems += "경로가 깁니다($($Path.Length)자). node_modules 가 MAX_PATH 에 걸릴 수 있습니다."
    }

    Write-Item '  ' $Path
    foreach ($p in $problems) { Write-Item '!!' $p }
    if ($problems.Count -gt 0) {
        Write-Output ''
        Write-Output '  다른 위치를 지정하세요. 예:'
        Write-Output "    & ([scriptblock]::Create((irm $RepoWeb/raw/main/install.ps1))) -Path 'C:\dev\ai-harness'"
        return
    }

    # -----------------------------------------------------------------------
    # 3. 받기 — 없으면 clone, 있으면 갱신
    # -----------------------------------------------------------------------
    $gitDir = Join-Path $Path '.git'
    $exists = Test-Path -LiteralPath $gitDir

    if (-not $Ref) {
        $Ref = Get-LatestRemoteTag $RepoUrl
        if (-not $Ref) {
            Write-Output ''
            Write-Output '  원격 태그를 읽지 못했습니다. 네트워크 또는 접근 권한을 확인하세요.'
            return
        }
    }

    if ($exists) {
        Write-Step "업데이트  (이미 있습니다)"

        $status = @(& git -C $Path status --porcelain 2>$null)
        if ($status.Count -gt 0) {
            Write-Item '!!' "커밋하지 않은 변경이 $($status.Count)건 있습니다. 건드리지 않겠습니다."
            Write-Item '  ' "git -C `"$Path`" status"
            return
        }

        $before = ((& git -C $Path describe --tags --always 2>$null) -join '').Trim()
        & git -C $Path fetch --tags --prune origin 2>&1 | Out-Null

        # HEAD 가 브랜치면 그것은 **작업용 클론**이다. 태그로 detach 시키면
        # 사용자가 작업하던 자리를 조용히 옮기는 것이 된다.
        # 소비용 설치는 detached 로 두므로, 이 구분이 곧 "누구의 저장소인가"의 판정이다.
        $branch = ((& git -C $Path rev-parse --abbrev-ref HEAD 2>$null) -join '').Trim()

        if ($branch -ne 'HEAD') {
            $ahead = ((& git -C $Path rev-list --count "origin/$branch..$branch" 2>$null) -join '').Trim()
            if ($ahead -and ($ahead -ne '0')) {
                Write-Item '!!' "로컬 '$branch' 가 origin 보다 $ahead 커밋 앞서 있습니다. 건드리지 않겠습니다."
                Write-Item '  ' '하네스를 직접 개발 중인 PC 로 보입니다. git push 로 올리세요.'
                return
            }
            & git -C $Path merge --ff-only "origin/$branch" 2>&1 | Out-Null
            $after = ((& git -C $Path describe --tags --always 2>$null) -join '').Trim()
            Write-Item 'ok' "브랜치 '$branch' 를 fast-forward 했습니다.  $before -> $after"
            Write-Item '  ' "작업용 클론으로 보여 태그($Ref)로 옮기지 않았습니다. 브랜치 그대로 둡니다."
        }
        else {
            & git -C $Path checkout --quiet $Ref 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Item '!!' "'$Ref' 로 이동하지 못했습니다."
                return
            }
            $after = ((& git -C $Path describe --tags --always 2>$null) -join '').Trim()
            if ($before -eq $after) { Write-Item 'ok' "이미 최신입니다 ($after)" }
            else { Write-Item 'ok' "$before  ->  $after" }
        }
    }
    else {
        Write-Step "받기  ($Ref)"
        & git -c core.autocrlf=false -c core.longpaths=true clone --quiet --branch $Ref $RepoUrl $Path 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Item '!!' '클론에 실패했습니다. 네트워크와 경로를 확인하세요.'
            return
        }
        Write-Item 'ok' "$Path  ($Ref)"
    }

    $head = ((& git -C $Path rev-parse --short HEAD 2>$null) -join '').Trim()
    Write-Item '  ' "HEAD $head"

    # -----------------------------------------------------------------------
    # 4. 비밀값 가드
    # -----------------------------------------------------------------------
    Write-Step '비밀값 가드'
    & git -C $Path config core.hooksPath .githooks 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Item 'ok' 'core.hooksPath = .githooks  (커밋 전 비밀값·머신 상태 차단)' }
    else { Write-Item '!!' '설정하지 못했습니다. 수동: git -C "' + $Path + '" config core.hooksPath .githooks' }

    # -----------------------------------------------------------------------
    # 5. 저장소 자체 검사
    # -----------------------------------------------------------------------
    Write-Step '저장소 검사'
    $checker = Join-Path (Join-Path $Path 'scripts') 'Test-HarnessRepo.ps1'
    if (Test-Path -LiteralPath $checker) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $checker
    }
    else {
        Write-Item '!!' 'Test-HarnessRepo.ps1 을 찾지 못했습니다.'
    }

    # -----------------------------------------------------------------------
    # 6. 다음 단계
    # -----------------------------------------------------------------------
    Write-Output ''
    Write-Output '--------------------------------------------------------------------'
    Write-Output '  받았습니다. 아직 아무것도 설치·등록되지 않았습니다.'
    Write-Output '--------------------------------------------------------------------'
    Write-Output ''
    Write-Output '  1) 어떤 도구를 쓸지 고르기  (설명을 들으며 하나씩 선택)'
    Write-Output "     $Path\scripts\Invoke-HarnessEscort.ps1 -SavePlan .\escort.json"
    Write-Output '     * 대화형입니다. 터미널에서 직접 실행하세요.'
    Write-Output '       그냥 목록만 보려면  -List  /  한 항목만  -Explain <번호>'
    Write-Output ''
    Write-Output '  2) 이 PC 에 하네스 적용  (진단 -> 계획 -> 확인 -> 적용)'
    Write-Output "     $Path\workflows\HARNESS_INSTALL.md  를 따릅니다."
    Write-Output "     $Path\scripts\Get-HarnessEnvironment.ps1"
    Write-Output ''
    Write-Output '  3) 프로젝트에 연결  (프로젝트 폴더에서, 최초 1회)'
    Write-Output "     AI 에게: `"$Path\PROJECT_INIT.md 를 읽고 현재 프로젝트를 초기화해줘`""
    Write-Output '     Claude Code 라면  /plugin marketplace add hacker943410-debug/ai-harness'
    Write-Output '                       /plugin install ai-harness@ai-harness   ->  /harness-init'
    Write-Output ''
    Write-Output '  다음에 업데이트할 때도 같은 한 줄입니다:'
    Write-Output "     irm $RepoWeb/raw/main/install.ps1 | iex"
    Write-Output ''
}

Invoke-HarnessBootstrap -Path $Path -Ref $Ref -SkipChecks:$SkipChecks
