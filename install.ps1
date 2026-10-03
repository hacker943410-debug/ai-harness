#Requires -Version 5.1
<#
    AI Harness — 부트스트랩

    한 줄 설치·업데이트:

        irm https://raw.githubusercontent.com/hacker943410-debug/ai-harness/main/install.ps1 | iex

    옵션을 주려면 (irm | iex 는 인자를 못 넘긴다) 환경변수를 쓴다:

        $env:AI_HARNESS_PATH = 'C:\dev\ai-harness'
        irm https://raw.githubusercontent.com/hacker943410-debug/ai-harness/main/install.ps1 | iex

    파일로 내려받아 실행할 때는 -Path / -Ref / -SkipChecks 도 받는다.

    이 스크립트가 하는 일
        1. 사전 조건 확인 (PowerShell 5.1+ / git / Node 22+ / npm)
        2. 클론 위치 검증 (비ASCII·동기화 폴더·깊은 경로·UNC 를 거른다)
        3. 없으면 clone, 있으면 fetch 후 정본 main으로 갱신  ← 설치와 업데이트가 같은 명령
        4. 비밀값 가드 활성화 (core.hooksPath)
        5. 저장소 자체 검사 실행
        6. 다음 단계 안내

    하지 않는 일
        도구 루트(Layer B)를 만들지 않는다. MCP 를 설치하거나 등록하지 않는다.
        인증하지 않는다. 프로젝트(Layer C)를 건드리지 않는다.
        그것들은 각각 확인 절차를 가진 별도 단계다.

    사용자가 고쳐 둔 저장소는 건드리지 않는다.
    커밋 안 한 변경이 있거나 origin 보다 앞서 있으면 보고만 하고 멈춘다.

    주의 1: 이 파일은 iex 로 실행될 수 있다. 그때는 호출자 세션에서 도는 것이므로
    `exit` 를 쓰면 사용자의 PowerShell 창이 닫힌다. 전부 함수 안에서 return 한다.

    주의 2: **param() 블록을 쓰지 않는다.**
    이 파일은 .ps1 이라 UTF-8 BOM 이 붙어야 하고(PS 5.1 은 BOM 이 없으면 ANSI 로 디코딩한다),
    그 BOM 은 `irm` 을 통과해 문자열 선두에 U+FEFF 로 남는다.
    선두 U+FEFF 가 있으면 `param` 이 더 이상 첫 statement 가 아니게 되어 iex 가 파싱에 실패한다.
    실제로 실패했다 — BOM 은 param 블록만 깨뜨리고 나머지 구문은 멀쩡히 통과한다.
    그래서 옵션은 환경변수와 $args 로 받는다.
#>

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

# PS 5.1의 native stderr가 호출자의 ErrorActionPreference를 바꾸지 않게 격리한다.
function Invoke-HarnessGit {
    param([string[]]$Arguments)
    $ErrorActionPreference = 'Continue'
    $output = @(& git @Arguments 2>&1 | ForEach-Object { $_.ToString() })
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Resolve-HarnessRevision {
    param([string]$Path, [string]$Ref)
    if ($Ref -match '^[0-9a-fA-F]{40}$') {
        $candidates = @($Ref)
    } elseif ($Ref -match '^refs/(tags|heads)/(.+)$') {
        $valid = Invoke-HarnessGit -Arguments @('check-ref-format', $Ref)
        if ($valid.ExitCode -ne 0) { throw '올바르지 않은 명시적 Ref입니다.' }
        if ($Ref.StartsWith('refs/heads/')) { $candidates = @('refs/remotes/origin/' + $Ref.Substring(11)) }
        else { $candidates = @($Ref) }
    } else {
        $valid = Invoke-HarnessGit -Arguments @('check-ref-format', "refs/heads/$Ref")
        if ($valid.ExitCode -ne 0) { throw 'Ref는 원격 브랜치, 태그 또는 전체 커밋 SHA여야 합니다.' }
        # 로컬의 오래된 main은 후보에서 제외한다. 동명 브랜치/태그는 모호하므로 거부한다.
        $candidates = @("refs/remotes/origin/$Ref", "refs/tags/$Ref")
    }
    $resolvedCommits = @()
    foreach ($candidate in $candidates) {
        $resolved = Invoke-HarnessGit -Arguments @('-C', $Path, 'rev-parse', '--verify', '--end-of-options', ($candidate + '^{commit}'))
        if ($resolved.ExitCode -eq 0 -and $resolved.Output.Count -eq 1 -and $resolved.Output[0] -match '^[0-9a-fA-F]{40}$') {
            $resolvedCommits += $resolved.Output[0].ToLowerInvariant()
        }
    }
    if ($resolvedCommits.Count -gt 1) { throw '동명 브랜치와 태그가 있습니다. refs/tags/<이름> 또는 refs/heads/<이름>을 명시하세요.' }
    if ($resolvedCommits.Count -eq 1) { return $resolvedCommits[0] }
    throw '요청한 Ref의 커밋을 찾지 못했습니다. 다른 버전으로 대신 적용하지 않습니다.'
}

# A shared legacy source may be referenced by active projects. Never move it
# across a major boundary; stage a separate candidate for project migration.
function Get-HarnessMajorUpgradeCandidate {
    param([string]$Path, [string]$Before, [string]$Target)
    $versions = @()
    foreach ($revision in @($Before, $Target)) {
        $value = Invoke-HarnessGit -Arguments @('-C', $Path, 'show', ($revision + ':HARNESS_VERSION'))
        $text = ($value.Output -join "`n")
        if ($value.ExitCode -ne 0) {
            $value = Invoke-HarnessGit -Arguments @('-C', $Path, 'show', ($revision + ':POLICY_INDEX.yaml'))
            $text = ($value.Output -join "`n")
        }
        if ($text -match '(?m)^\s*(?:harness_version:\s*["'']?)?(\d+)\.\d+') { $versions += [int]$Matches[1] }
        else { $versions += $null }
    }
    if ($null -ne $versions[0] -and $null -ne $versions[1] -and $versions[0] -ne $versions[1]) {
        $parent = Split-Path -Parent $Path
        $leaf = Split-Path -Leaf $Path
        return (Join-Path $parent ($leaf + '-v' + $versions[1]))
    }
    return $null
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
        if ($blocked -contains 'git') {
            throw 'git 없이는 하네스를 받을 수 없습니다. git 설치 후 다시 실행하세요.'
        }
        elseif ($SkipChecks) {
            Write-Output ''
            Write-Output "  -SkipChecks 가 지정돼 계속합니다. 빠진 것: $($blocked -join ', ')"
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
        throw '설치 위치 검증에 실패했습니다.'
    }

    # -----------------------------------------------------------------------
    # 3. 받기 — 없으면 clone, 있으면 갱신
    # -----------------------------------------------------------------------
    $gitDir = Join-Path $Path '.git'
    $exists = Test-Path -LiteralPath $gitDir

    # v5.0부터 GitHub main이 Canonical update channel이다.
    # 특정 release/tag/branch를 고정하려면 -Ref 또는 AI_HARNESS_REF를 명시한다.
    if (-not $Ref) { $Ref = 'main' }

    if ($exists) {
        Write-Step "업데이트  (이미 있습니다)"

        $status = Invoke-HarnessGit -Arguments @('-C', $Path, 'status', '--porcelain')
        if ($status.ExitCode -ne 0) { throw '기존 저장소 상태를 확인하지 못했습니다.' }
        if ($status.Output.Count -gt 0) {
            Write-Item '!!' "커밋하지 않은 변경이 $($status.Output.Count)건 있습니다."
            Write-Item '  ' "git -C `"$Path`" status"
            throw '추적 변경과 untracked 파일을 먼저 보존·정리하세요. 업데이트를 중단했습니다.'
        }

        $beforeResult = Invoke-HarnessGit -Arguments @('-C', $Path, 'rev-parse', 'HEAD')
        if ($beforeResult.ExitCode -ne 0) { throw '기존 HEAD를 확인하지 못했습니다.' }
        $before = ($beforeResult.Output -join '').Trim()
        $fetch = Invoke-HarnessGit -Arguments @('-C', $Path, 'fetch', '--tags', '--prune', 'origin')
        if ($fetch.ExitCode -ne 0) { throw '원격 fetch에 실패했습니다. HEAD를 변경하지 않았습니다.' }

        # HEAD 가 브랜치면 그것은 **작업용 클론**이다. 지정 Ref로 강제 이동시키면
        # 사용자가 작업하던 자리를 조용히 옮기는 것이 된다.
        # 소비용 설치는 detached 로 두므로, 이 구분이 곧 "누구의 저장소인가"의 판정이다.
        $branchResult = Invoke-HarnessGit -Arguments @('-C', $Path, 'rev-parse', '--abbrev-ref', 'HEAD')
        if ($branchResult.ExitCode -ne 0) { throw '현재 브랜치를 확인하지 못했습니다.' }
        $branch = ($branchResult.Output -join '').Trim()

        if ($branch -ne 'HEAD') {
            $remoteBranch = Invoke-HarnessGit -Arguments @('-C', $Path, 'rev-parse', '--verify', '--end-of-options', ("refs/remotes/origin/$branch" + '^{commit}'))
            if ($remoteBranch.ExitCode -ne 0 -or $remoteBranch.Output.Count -ne 1 -or $remoteBranch.Output[0] -notmatch '^[0-9a-fA-F]{40}$') {
                throw '현재 브랜치와 같은 원격 브랜치를 찾지 못했습니다. 브랜치를 보존했습니다.'
            }
            $target = $remoteBranch.Output[0].ToLowerInvariant()
            $aheadResult = Invoke-HarnessGit -Arguments @('-C', $Path, 'rev-list', '--count', "$target..HEAD")
            $ahead = 0
            if ($aheadResult.ExitCode -ne 0 -or -not [int]::TryParse(($aheadResult.Output -join '').Trim(), [ref]$ahead)) {
                throw '브랜치 선행 커밋을 확인하지 못했습니다.'
            }
            if ($ahead -gt 0) { throw "로컬 '$branch'가 원격보다 앞서거나 분기했습니다. 브랜치와 HEAD를 보존했습니다." }
            $candidate = Get-HarnessMajorUpgradeCandidate -Path $Path -Before $before -Target $target
            if ($candidate) {
                Write-Item '  ' 'Major version change: existing shared source and active projects are preserved.'
                Invoke-HarnessBootstrap -Path $candidate -Ref $target -SkipChecks:$SkipChecks
                Write-Item '  ' "Candidate ready: $candidate. Use PROJECT_INIT.md to checkpoint, migrate, verify and resume each project."
                return
            }
            $merge = Invoke-HarnessGit -Arguments @('-C', $Path, 'merge', '--ff-only', $target)
            if ($merge.ExitCode -ne 0) { throw 'fast-forward에 실패했습니다. 업데이트 성공으로 판정하지 않습니다.' }
            Write-Item 'ok' "브랜치 '$branch' 를 fast-forward 했습니다.  $before -> $target"
            Write-Item '  ' "작업용 클론으로 보여 Ref($Ref)로 강제 이동하지 않았습니다. 브랜치 그대로 둡니다."
        }
        else {
            $target = Resolve-HarnessRevision -Path $Path -Ref $Ref
            $candidate = Get-HarnessMajorUpgradeCandidate -Path $Path -Before $before -Target $target
            if ($candidate) {
                Write-Item '  ' 'Major version change: existing shared source and active projects are preserved.'
                Invoke-HarnessBootstrap -Path $candidate -Ref $target -SkipChecks:$SkipChecks
                Write-Item '  ' "Candidate ready: $candidate. Use PROJECT_INIT.md to checkpoint, migrate, verify and resume each project."
                return
            }
            $checkout = Invoke-HarnessGit -Arguments @('-C', $Path, 'checkout', '--quiet', '--detach', $target)
            if ($checkout.ExitCode -ne 0) { throw '확인한 커밋으로 이동하지 못했습니다.' }
            if ($before -eq $target) { Write-Item 'ok' "요청한 Ref와 일치합니다 ($target)" }
            else { Write-Item 'ok' "$before  ->  $target  (detached)" }
        }
    }
    else {
        Write-Step "받기  ($Ref)"
        $clone = Invoke-HarnessGit -Arguments @('-c', 'core.autocrlf=false', '-c', 'core.longpaths=true', 'clone', '--quiet', '--no-checkout', $RepoUrl, $Path)
        if ($clone.ExitCode -ne 0) { throw '클론에 실패했습니다. 네트워크와 경로를 확인하세요.' }
        $target = Resolve-HarnessRevision -Path $Path -Ref $Ref
        $checkout = Invoke-HarnessGit -Arguments @('-C', $Path, 'checkout', '--quiet', '--detach', $target)
        if ($checkout.ExitCode -ne 0) { throw '확인한 커밋을 체크아웃하지 못했습니다.' }
        Write-Item 'ok' "$Path  ($Ref, detached)"
    }

    $headResult = Invoke-HarnessGit -Arguments @('-C', $Path, 'rev-parse', 'HEAD')
    $head = ($headResult.Output -join '').Trim()
    if ($headResult.ExitCode -ne 0 -or $head -ne $target) { throw '적용된 HEAD가 확인한 목표 커밋과 다릅니다.' }
    Write-Item '  ' "HEAD $head"

    # -----------------------------------------------------------------------
    # 4. 비밀값 가드
    # -----------------------------------------------------------------------
    Write-Step '비밀값 가드'
    $hooks = Invoke-HarnessGit -Arguments @('-C', $Path, 'config', 'core.hooksPath', '.githooks')
    if ($hooks.ExitCode -ne 0) { throw '비밀값 가드를 활성화하지 못했습니다.' }
    Write-Item 'ok' 'core.hooksPath = .githooks  (커밋 전 비밀값·머신 상태 차단)'

    # -----------------------------------------------------------------------
    # 5. 저장소 자체 검사
    # -----------------------------------------------------------------------
    Write-Step '저장소 검사'
    $checker = Join-Path (Join-Path $Path 'scripts') 'Test-HarnessRepo.ps1'
    if (Test-Path -LiteralPath $checker) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $checker -HarnessRoot $Path
        if ($LASTEXITCODE -ne 0) { throw '저장소 검사가 실패했습니다. 받은 HEAD를 사용하기 전에 오류를 해소하세요.' }
    }
    else {
        throw 'Test-HarnessRepo.ps1을 찾지 못했습니다. 저장소 검증을 완료할 수 없습니다.'
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

# ---------------------------------------------------------------------------
# 옵션 해석 — param 블록 없이 (위 주의 2)
#   irm | iex   : 환경변수
#   파일 실행    : -Path / -Ref / -SkipChecks
# ---------------------------------------------------------------------------
$optPath = $env:AI_HARNESS_PATH
$optRef = $env:AI_HARNESS_REF
$optSkip = ($env:AI_HARNESS_SKIP_CHECKS -in @('1', 'true', 'True', 'yes'))

$argv = @($args)
for ($i = 0; $i -lt $argv.Count; $i++) {
    $a = [string]$argv[$i]
    if ($a -match '^-{1,2}Path$') { $i++; if ($i -lt $argv.Count) { $optPath = [string]$argv[$i] } }
    elseif ($a -match '^-{1,2}Ref$') { $i++; if ($i -lt $argv.Count) { $optRef = [string]$argv[$i] } }
    elseif ($a -match '^-{1,2}SkipChecks$') { $optSkip = $true }
}

Invoke-HarnessBootstrap -Path $optPath -Ref $optRef -SkipChecks:$optSkip
