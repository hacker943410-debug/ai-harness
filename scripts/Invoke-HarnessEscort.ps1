#Requires -Version 5.1
<#
    AI Harness — 설치 에스코트

    목적: 하네스를 처음 세팅하는 사람이 "무슨 도구가 있고, 나한테 뭐가 필요하고,
          이걸 깔면 무엇을 감수하는지"를 알고 결정하게 한다.
          아는 사람만 쓸 수 있는 도구는 설치되지 않은 것과 같다.

    이 스크립트는 아무것도 적용하지 않는다.
    결정을 모아 계획 파일(harness-change-plan v1.0)로 내고, 적용은 Install-Harness.ps1 이 한다.
    적용하는 문은 하나여야 한다. 둘이 되는 순간 확인 절차를 우회하는 길이 생긴다.

    사용:
        .\Invoke-HarnessEscort.ps1                          # 대화형 (기본)
        .\Invoke-HarnessEscort.ps1 -SavePlan .\escort.json  # 결정을 계획 파일로
        .\Invoke-HarnessEscort.ps1 -List                    # 전체 목록만 (읽기 전용, 비대화)
        .\Invoke-HarnessEscort.ps1 -Explain playwright      # 한 항목만 쉬운 말로
        .\Invoke-HarnessEscort.ps1 -Tips                    # 카탈로그 보는 법

    종료 코드: 0 = 정상, 1 = 오류, 3 = 대화형이 필요한데 입력을 받을 수 없음

    설명 문구는 이 파일이 아니라 catalogs/escort-glossary.json 과
    catalogs/escort-profiles.json 에 있다. 항목이 늘어도 여기를 고치지 않는다.
#>
[CmdletBinding()]
param(
    [string]$HarnessRoot,
    [string]$ProjectRoot,
    [string]$SavePlan,
    [string]$ProfileId,
    [string]$Explain,
    [switch]$List,
    [switch]$Tips
)

# [CmdletBinding()] 가 있으면 PS 5.1 은 param 기본값 평가 시 $PSScriptRoot 를 비워 둔다.
if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }
if (-not $ProjectRoot) { $ProjectRoot = (Get-Location).Path }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Runtime.ps1')
Initialize-HarnessConsole

$root = (Resolve-Path -LiteralPath $HarnessRoot).Path

# ---------------------------------------------------------------------------
# 데이터 적재 — 설명은 전부 여기서 온다
# ---------------------------------------------------------------------------
$glossary = Read-HarnessJson -Path (Join-HarnessPath $root 'catalogs' 'escort-glossary.json')
$profiles = Read-HarnessJson -Path (Join-HarnessPath $root 'catalogs' 'escort-profiles.json')
$mcpCat   = Read-HarnessJson -Path (Join-HarnessPath $root 'catalogs' 'mcp-catalog.json')
$skillCat = Read-HarnessJson -Path (Join-HarnessPath $root 'catalogs' 'skill-catalog.json')

# ---------------------------------------------------------------------------
# 출력 헬퍼
# ---------------------------------------------------------------------------
$script:Line = ('-' * 74)

function Write-Head {
    param([string]$Text)
    Write-Output ''
    Write-Output $script:Line
    Write-Output "  $Text"
    Write-Output $script:Line
}

function Write-Wrapped {
    param([string]$Text, [string]$Indent = '    ', [int]$Width = 68)
    if (-not $Text) { return }
    $words = $Text -split '\s+'
    $cur = ''
    foreach ($w in $words) {
        if ($cur -and (($cur.Length + 1 + $w.Length) -gt $Width)) {
            Write-Output "$Indent$cur"
            $cur = $w
        }
        elseif ($cur) { $cur = "$cur $w" }
        else { $cur = $w }
    }
    if ($cur) { Write-Output "$Indent$cur" }
}

# ---------------------------------------------------------------------------
# 입력 헬퍼 — 비대화 환경에서 절대 매달리지 않는다
# ---------------------------------------------------------------------------
$script:EmptyReads = 0

function Read-EscortLine {
    param([string]$Prompt)
    if ($script:EmptyReads -ge 3) {
        Write-Output ''
        Write-Output '입력을 받을 수 없습니다. 대화형 콘솔에서 다시 실행하세요.'
        Write-Output "  목록만 보기 : .\scripts\Invoke-HarnessEscort.ps1 -List"
        Write-Output "  항목 설명   : .\scripts\Invoke-HarnessEscort.ps1 -Explain <id>"
        exit 3
    }
    $answer = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($answer)) { $script:EmptyReads++ } else { $script:EmptyReads = 0 }
    return $answer.Trim()
}

function Read-YesNo {
    param([string]$Prompt, [string]$Default = 'n')
    while ($true) {
        $a = (Read-EscortLine "$Prompt").ToLower()
        if (-not $a) { return $Default }
        if ($a -in @('y', 'yes', 'ㅛ', '예', 'ㅇ')) { return 'y' }
        if ($a -in @('n', 'no', '아니오', 'ㄴ')) { return 'n' }
        if ($a -in @('l', 'later', '나중')) { return 'l' }
        Write-Output '    y / n / l 중에서 골라 주세요.'
    }
}

# ---------------------------------------------------------------------------
# 사전 조회
# ---------------------------------------------------------------------------
function Get-GlossaryEntry {
    param($Table, [string]$Key)
    if (-not $Key) { return $null }
    $prop = $Table.PSObject.Properties[$Key]
    if ($prop) { return $prop.Value }
    return $null
}

function Get-DomainPlain {
    param([string]$Domain)
    $d = Get-GlossaryEntry $glossary.domains $Domain
    if ($d) { return "$($d.label) — $($d.plain)" }
    return "$Domain — $($glossary.fallback.domain)"
}

function Get-DomainLabel {
    param([string]$Domain)
    $d = Get-GlossaryEntry $glossary.domains $Domain
    if ($d) { return $d.label }
    return $Domain
}

function Get-CapabilityPlain {
    param([string]$Capability)
    $exact = Get-GlossaryEntry $glossary.capability_terms $Capability
    if ($exact) { return $exact }
    foreach ($p in $glossary.capability_patterns) {
        if ($Capability -match $p.match) {
            $term = ($Capability -replace '_', ' ')
            return ($p.plain -replace '\{term\}', $term)
        }
    }
    return ($glossary.fallback.capability -replace '\{raw\}', $Capability)
}

function Get-InstallInfo {
    param([string]$Kind)
    $i = Get-GlossaryEntry $glossary.install_kinds $Kind
    if ($i) { return $i }
    return ([pscustomobject]@{
            label        = $Kind
            auto         = $false
            plain        = $glossary.fallback.install
            manual_steps = @('공식 문서의 설치 절차를 따르세요.')
            verify       = '실제 호출까지 확인하세요.'
        })
}

# ---------------------------------------------------------------------------
# 항목 목록 — 런타임(공용) 먼저, 그다음 MCP, 그다음 Skill
# ---------------------------------------------------------------------------
$items = [System.Collections.Generic.List[object]]::new()

foreach ($e in $mcpCat.entries) {
    $items.Add([pscustomobject]@{
            kind         = 'mcp'
            id           = $e.id
            name         = if ($e.name) { $e.name } else { $e.id }
            domains      = @($e.domains)
            capabilities = @($e.capabilities)
            risk         = if ($e.risk) { $e.risk } else { 'high' }
            status       = $e.status
            install_kind = $e.install.kind
            package      = $e.install.package
            runtime_id   = $e.install.runtime_id
            publisher    = $e.publisher
            official     = [bool]$e.official
            note         = $e.note
            source       = $null
        })
}

foreach ($e in $skillCat.entries) {
    $items.Add([pscustomobject]@{
            kind         = 'skill'
            id           = $e.id
            name         = $e.id
            domains      = @($e.domains)
            capabilities = @($e.capabilities)
            risk         = 'low'
            status       = $e.status
            install_kind = 'skill'
            package      = $null
            runtime_id   = $null
            publisher    = $e.source
            official     = [bool]$e.official
            note         = $null
            source       = $e.source
        })
}

$sorted = @($items | Sort-Object kind, { $_.domains[0] }, id)
for ($i = 0; $i -lt $sorted.Count; $i++) {
    $sorted[$i] | Add-Member -NotePropertyName 'no' -NotePropertyValue ($i + 1) -Force
}

function Find-Item {
    param([string]$Token)
    if (-not $Token) { return $null }
    $n = 0
    if ([int]::TryParse($Token, [ref]$n)) {
        if (($n -ge 1) -and ($n -le $sorted.Count)) { return $sorted[$n - 1] }
        return $null
    }
    $hit = @($sorted | Where-Object { $_.id -eq $Token })
    if ($hit.Count -eq 1) { return $hit[0] }
    return $null
}

# ---------------------------------------------------------------------------
# 표시
# ---------------------------------------------------------------------------
function Show-ItemLine {
    param($Item)
    $riskInfo = Get-GlossaryEntry $glossary.risk $Item.risk
    $riskLabel = if ($riskInfo) { $riskInfo.label } else { $Item.risk }
    $tag = if ($Item.kind -eq 'skill') { '스킬' } else { 'MCP ' }
    $flag = if ($Item.status -eq 'discovery_only') { '?' } else { ' ' }
    Write-Output ("  {0,3}{1} [{2}] {3,-24} 위험 {4,-6} {5}" -f `
            $Item.no, $flag, $tag, $Item.id, $riskLabel, (($Item.domains | ForEach-Object { Get-DomainLabel $_ }) -join '·'))
}

function Show-Detail {
    param($Item)
    $riskInfo = Get-GlossaryEntry $glossary.risk $Item.risk
    $statusInfo = Get-GlossaryEntry $glossary.status $Item.status
    $installInfo = Get-InstallInfo $Item.install_kind

    Write-Head "$($Item.no). $($Item.name)   ($($Item.id))"

    Write-Output '  ■ 어떤 분야'
    foreach ($d in $Item.domains) { Write-Wrapped (Get-DomainPlain $d) }

    Write-Output ''
    Write-Output '  ■ 뭘 할 수 있나'
    if ($Item.capabilities.Count -eq 0) { Write-Wrapped '카탈로그에 능력 목록이 없습니다. 공식 문서를 보세요.' }
    foreach ($c in $Item.capabilities) { Write-Wrapped ('- ' + (Get-CapabilityPlain $c)) }

    Write-Output ''
    Write-Output "  ■ 위험도 : $(if ($riskInfo) { $riskInfo.label } else { $Item.risk })"
    if ($riskInfo) { Write-Wrapped $riskInfo.plain }

    Write-Output ''
    Write-Output "  ■ 출처 : $(if ($Item.publisher) { $Item.publisher } else { '미상' })$(if ($Item.official) { ' (공식)' } else { '' })"
    if ($statusInfo) { Write-Wrapped $statusInfo.plain }

    Write-Output ''
    Write-Output "  ■ 설치 방식 : $($installInfo.label)"
    Write-Wrapped $installInfo.plain
    if ($installInfo.requires) {
        Write-Wrapped ('먼저 있어야 하는 것: ' + (@($installInfo.requires) -join ', '))
    }

    Write-Output ''
    Write-Output '  ■ 어떻게 확인하나'
    Write-Wrapped $installInfo.verify

    if ($Item.note) {
        Write-Output ''
        Write-Output '  ■ 메모'
        Write-Wrapped $Item.note
    }
    Write-Output ''
}

function Show-ManualGuide {
    param($Item)
    $installInfo = Get-InstallInfo $Item.install_kind
    Write-Output ''
    Write-Output "  === 직접 설치 가이드 : $($Item.id) ==="
    Write-Output ''
    $n = 1
    foreach ($s in @($installInfo.manual_steps)) {
        $text = $s
        if ($Item.package) { $text = $text -replace '\{package\}', $Item.package }
        if ($Item.runtime_id) { $text = $text -replace '\{runtime_id\}', $Item.runtime_id }
        if ($Item.source) { $text = $text -replace '\{source\}', $Item.source }
        $text = $text -replace '\{id\}', $Item.id
        # 아직 정해지지 않은 값은 빈칸으로 두지 않고, 사용자가 채워야 할 자리임을 보이게 한다.
        $text = $text -replace '\{version\}', '<정확한버전>'
        $text = $text -replace '\{tag\}', '<태그>'
        $text = $text -replace '\{image\}', '<이미지>'
        Write-Output ("   {0}) {1}" -f $n, $text)
        $n++
    }
    Write-Output ''
    Write-Output '   확인:'
    Write-Wrapped $installInfo.verify '     '
    Write-Output ''
    Write-Output '   되돌리려면: 설치한 것을 지우기 전에 무엇이 그걸 쓰고 있는지 먼저 확인하세요.'
    Write-Output '   AI CLI 등록을 뺄 때는 Disconnect-HarnessRuntime.ps1 이 순서를 지켜 줍니다.'
    Write-Output ''
}

function Show-Tips {
    Write-Head '카탈로그 보는 법'
    Write-Output '  이 목록은 "설치된 것"이 아니라 "이런 게 있다"는 지도입니다.'
    Write-Output ''
    Write-Output '  줄 읽는 법'
    Write-Output '    12  [MCP ] playwright    위험 보통   웹·테스트'
    Write-Output '    │    │      │             │          └ 어떤 분야에 쓰나'
    Write-Output '    │    │      │             └ 깔면 무엇을 감수하나'
    Write-Output '    │    │      └ 이름 (이 이름으로 검색하세요)'
    Write-Output '    │    └ MCP(도구) 인지 스킬(절차 문서) 인지'
    Write-Output '    └ 번호. 이 번호를 입력하면 쉬운 말로 자세히 설명합니다.'
    Write-Output ''
    Write-Output '  이름 뒤에 ? 가 붙은 것'
    Write-Output '    "이름만 아는 것"입니다. 어디서 받는지가 아직 확정돼 있지 않아요.'
    Write-Output '    이름이 같아도 만든 사람이 다른 가짜가 있을 수 있어서 자동 설치를 막아둡니다.'
    Write-Output ''
    Write-Output '  MCP 와 스킬의 차이'
    Write-Output '    MCP  = 실제로 무언가를 하는 도구 (파일을 고치고, DB에 묻고, 브라우저를 조종)'
    Write-Output '    스킬 = "이럴 땐 이렇게 해라"는 절차 문서. 위험이 거의 없습니다.'
    Write-Output ''
    Write-Output '  기억할 것'
    foreach ($t in @($profiles.closing_tips)) { Write-Wrapped ('- ' + $t) '    ' }
    Write-Output ''
}

# ---------------------------------------------------------------------------
# 비대화 모드
# ---------------------------------------------------------------------------
if ($Tips) { Show-Tips; exit 0 }

if ($Explain) {
    $target = Find-Item $Explain
    if (-not $target) {
        Write-Output "'$Explain' 을(를) 찾지 못했습니다. 번호 또는 정확한 id 로 지정하세요."
        Write-Output "  전체 목록: .\scripts\Invoke-HarnessEscort.ps1 -List"
        exit 1
    }
    Show-Detail $target
    exit 0
}

if ($List) {
    Write-Head "전체 카탈로그  (MCP $($mcpCat.entries.Count)개 · 스킬 $($skillCat.entries.Count)개)"
    $lastKind = ''
    foreach ($it in $sorted) {
        if ($it.kind -ne $lastKind) {
            Write-Output ''
            Write-Output ("  == {0} ==" -f $(if ($it.kind -eq 'skill') { '스킬 (절차 문서)' } else { 'MCP (도구)' }))
            $lastKind = $it.kind
        }
        Show-ItemLine $it
    }
    Write-Output ''
    Write-Output '  자세히: -Explain <번호 또는 id>     보는 법: -Tips'
    exit 0
}

# ---------------------------------------------------------------------------
# 대화형 — 0단계 : 인사
# ---------------------------------------------------------------------------
$picked = [System.Collections.Generic.List[object]]::new()

Write-Head 'AI Harness 설치 에스코트'
Write-Output '  도구를 하나씩 설명하고, 깔지 말지 직접 고르시게 도와드립니다.'
Write-Output '  이 스크립트는 아무것도 설치하지 않습니다. 결정을 모아 계획 파일로만 만들어요.'
Write-Output '  실제 적용은 마지막에 안내하는 Install-Harness.ps1 이 다시 확인을 받고 합니다.'
Write-Output ''
Write-Output "  프로젝트 : $ProjectRoot"
Write-Output "  하네스   : $root"
Write-Output "  목록     : MCP $($mcpCat.entries.Count)개 · 스킬 $($skillCat.entries.Count)개"
Write-Output ''
Write-Output '  아무것도 안 깔고 나가도 괜찮습니다. 도구는 미리 까는 것보다 막혔을 때 까는 게 낫습니다.'

# ---------------------------------------------------------------------------
# 1단계 : 뭘 하려고 하는지
# ---------------------------------------------------------------------------
$chosenProfiles = [System.Collections.Generic.List[object]]::new()

if ($ProfileId) {
    $p = @($profiles.profiles | Where-Object { $_.id -eq $ProfileId })
    if ($p.Count -eq 1) { $chosenProfiles.Add($p[0]) }
    else { Write-Output "프로필 '$ProfileId' 을(를) 찾지 못했습니다. 질문으로 진행합니다." }
}

if ($chosenProfiles.Count -eq 0) {
    Write-Head $profiles.question
    $pn = 1
    foreach ($p in $profiles.profiles) {
        Write-Output ("  {0}. {1}" -f $pn, $p.label)
        Write-Wrapped $p.plain '      '
        $pn++
    }
    Write-Output ''
    Write-Output "  $($profiles.hint)"
    Write-Output ''
    $answer = Read-EscortLine '번호'
    foreach ($tok in ($answer -split '[,\s]+')) {
        $n = 0
        if ([int]::TryParse($tok, [ref]$n)) {
            if (($n -ge 1) -and ($n -le $profiles.profiles.Count)) {
                $chosenProfiles.Add($profiles.profiles[$n - 1])
            }
        }
    }
    if ($chosenProfiles.Count -eq 0) {
        Write-Output '  고르지 않으셨네요. 둘러보기로 진행합니다.'
        $fallbackProfile = @($profiles.profiles | Where-Object { $_.id -eq 'unsure' })
        if ($fallbackProfile.Count -eq 1) { $chosenProfiles.Add($fallbackProfile[0]) }
    }
}

# ---------------------------------------------------------------------------
# 2단계 : 추천 세트
# ---------------------------------------------------------------------------
$recommendIds = [System.Collections.Generic.List[string]]::new()
foreach ($id in @($profiles.always.recommend)) { if (-not $recommendIds.Contains($id)) { $recommendIds.Add($id) } }
foreach ($p in $chosenProfiles) {
    foreach ($id in @($p.recommend)) { if (-not $recommendIds.Contains($id)) { $recommendIds.Add($id) } }
}

$considerIds = [System.Collections.Generic.List[string]]::new()
foreach ($p in $chosenProfiles) {
    foreach ($id in @($p.consider)) {
        if ((-not $recommendIds.Contains($id)) -and (-not $considerIds.Contains($id))) { $considerIds.Add($id) }
    }
}

Write-Head '이 선택에 맞는 추천'
Write-Output '  왜 이걸 권하는지부터 말씀드릴게요.'
Write-Output ''
Write-Wrapped $profiles.always.why '    '
foreach ($p in $chosenProfiles) {
    Write-Output ''
    Write-Output "  [$($p.label)]"
    Write-Wrapped $p.why '    '
}

Write-Output ''
Write-Output '  ● 먼저 권하는 것'
if ($recommendIds.Count -eq 0) { Write-Output '    (없음 — 지금은 아무것도 안 깔아도 됩니다)' }
foreach ($id in $recommendIds) {
    $it = Find-Item $id
    if ($it) { Show-ItemLine $it } else { Write-Output "    $id  (카탈로그에서 찾지 못함)" }
}

if ($considerIds.Count -gt 0) {
    Write-Output ''
    Write-Output '  ○ 필요해지면 볼 것'
    foreach ($id in $considerIds) {
        $it = Find-Item $id
        if ($it) { Show-ItemLine $it }
    }
}

Write-Output ''
Write-Output '  번호를 입력하면 그 도구를 쉬운 말로 자세히 설명하고, 깔지 말지 여쭤봅니다.'

# ---------------------------------------------------------------------------
# 3·4단계 : 열람과 결정
# ---------------------------------------------------------------------------
function Invoke-Decision {
    param($Item)

    if (@($picked | Where-Object { $_.item.id -eq $Item.id }).Count -gt 0) {
        Write-Output '  이미 담긴 항목입니다.'
        return
    }

    $installInfo = Get-InstallInfo $Item.install_kind
    $ans = Read-YesNo "  설치할까요?  [y] 예  [n] 아니오  [l] 나중에  (기본 n)"
    if ($ans -eq 'n') { Write-Output '  넘어갑니다.'; return }
    if ($ans -eq 'l') { Write-Output '  나중에 다시 이 에스코트를 부르시면 됩니다.'; return }

    $autoAllowed = [bool]$installInfo.auto
    $blockReason = ''
    if ($Item.status -eq 'discovery_only') {
        $autoAllowed = $false
        $blockReason = '어디서 받는지가 아직 확정돼 있지 않아서 자동 설치를 막아둡니다. 이름이 같아도 만든 사람이 다를 수 있어요.'
    }

    Write-Output ''
    if ($autoAllowed) {
        Write-Output '  어떻게 설치할까요?'
        Write-Output '    1) 자동  — 하네스가 계획에 담고, 마지막에 Install-Harness.ps1 이 확인받고 실행합니다'
        Write-Output '    2) 직접  — 명령을 직접 치시겠다면, 순서대로 자세히 안내해 드립니다'
        $how = Read-EscortLine '  번호 (기본 2)'
    }
    else {
        Write-Output '  이 항목은 자동 설치를 지원하지 않습니다.'
        Write-Wrapped $(if ($blockReason) { $blockReason } else { $installInfo.plain })
        Write-Output '  직접 설치 절차로 안내해 드릴게요.'
        $how = '2'
    }

    if ($how -eq '1') {
        # $args 는 자동 변수다. 같은 이름을 쓰면 조용히 덮인다.
        $scriptArgs = @()
        $scriptName = ''
        switch ($Item.install_kind) {
            'shared_runtime' {
                $scriptName = 'Install-HarnessRuntime.ps1'
                $scriptArgs = @('-RuntimeId', $Item.runtime_id)
            }
            'skill' {
                $scriptName = 'Install-ProjectSkill.ps1'
                $scriptArgs = @('-Id', $Item.id, '-ProjectRoot', $ProjectRoot)
            }
            default {
                Write-Output ''
                Write-Output '  이 방식은 버전을 정확히 고정해야 합니다. latest 는 쓰지 않습니다.'
                Write-Output '  공식 문서에서 확인한 버전을 적어 주세요. 모르면 그냥 엔터 — 직접 설치로 넘어갑니다.'
                $ver = Read-EscortLine '  버전 (예: 1.2.3)'
                if ((-not $ver) -or ($ver -eq 'latest') -or ($ver -match '[\*\^~]')) {
                    Write-Output '  정확한 버전이 없어 직접 설치로 전환합니다.'
                    $how = '2'
                }
                else {
                    $scriptName = 'Install-ProjectMcp.ps1'
                    $scriptArgs = @('-Id', $Item.id, '-ProjectRoot', $ProjectRoot, '-Version', $ver)
                }
            }
        }

        if ($how -eq '1') {
            $exec = New-HarnessScriptExec -HarnessRoot $root -ScriptName $scriptName -ScriptArgs $scriptArgs
            $step = New-HarnessPlanStep -StepId "escort.install:$($Item.kind):$($Item.id)" -Kind 'exec' `
                -Action "설치 ($($installInfo.label))" -Target $Item.id `
                -Current '없음' -Proposed '설치됨' -Risk $Item.risk `
                -Note "에스코트에서 사용자가 자동 설치를 선택했습니다." `
                -Optional $false -Payload $exec -CommandLine $exec.command_line
            $picked.Add([pscustomobject]@{ item = $Item; mode = '자동'; step = $step })
            Write-Output ''
            Write-Output '  계획에 담았습니다. 지금 실행되지는 않습니다.'
            Write-Output "    $($exec.command_line)"
            return
        }
    }

    Show-ManualGuide $Item
    $step = New-HarnessPlanStep -StepId "escort.manual:$($Item.kind):$($Item.id)" -Kind 'manual' `
        -Action "직접 설치 ($($installInfo.label))" -Target $Item.id `
        -Current '없음' -Proposed '사용자가 직접 설치' -Risk $Item.risk `
        -Note '에스코트에서 사용자가 직접 설치를 선택했습니다. 적용자는 이 단계를 실행하지 않습니다.' `
        -Optional $false -Payload ([pscustomobject]@{ steps = @($installInfo.manual_steps); verify = $installInfo.verify })
    $picked.Add([pscustomobject]@{ item = $Item; mode = '직접'; step = $step })
    Write-Output '  기록에 남겼습니다. 적용자는 이 단계를 실행하지 않습니다.'
}

function Show-Filtered {
    param([string]$Mode, [string]$Term)
    $list = switch ($Mode) {
        'domain' { @($sorted | Where-Object { $_.domains -contains $Term }) }
        'search' { @($sorted | Where-Object { ($_.id -like "*$Term*") -or (@($_.capabilities) -join ' ') -like "*$Term*" }) }
        default { @($sorted) }
    }
    if ($list.Count -eq 0) { Write-Output '  해당하는 항목이 없습니다.'; return }
    Write-Output ''
    foreach ($it in $list) { Show-ItemLine $it }
    Write-Output ''
    Write-Output "  $($list.Count)개. 번호를 입력하면 자세히 봅니다."
}

Write-Head '무엇을 보시겠어요?'
Write-Output '  번호       그 도구를 자세히 보고, 깔지 말지 결정'
Write-Output '  a          전체 카탈로그'
Write-Output '  d <분야>   분야별로 보기 (예: d web)'
Write-Output '  s <검색어> 이름·기능으로 찾기 (예: s browser)'
Write-Output '  ?          카탈로그 보는 법'
Write-Output '  p          지금까지 담은 것 보기'
Write-Output '  q          마치기'

while ($true) {
    Write-Output ''
    $cmd = Read-EscortLine '>'
    if (-not $cmd) { continue }

    $verb = ($cmd -split '\s+')[0].ToLower()
    $rest = ($cmd -replace '^\S+\s*', '').Trim()

    if ($verb -eq 'q') { break }
    elseif ($verb -eq '?') { Show-Tips }
    elseif ($verb -eq 'a') { Show-Filtered 'all' '' }
    elseif ($verb -eq 'd') {
        if (-not $rest) {
            Write-Output ('  분야: ' + (($glossary.domains.PSObject.Properties.Name) -join ', '))
        }
        else { Show-Filtered 'domain' $rest }
    }
    elseif ($verb -eq 's') {
        if (-not $rest) { Write-Output '  s 뒤에 찾을 말을 적어 주세요.' }
        else { Show-Filtered 'search' $rest }
    }
    elseif ($verb -eq 'p') {
        if ($picked.Count -eq 0) { Write-Output '  아직 담은 게 없습니다.' }
        foreach ($p in $picked) {
            Write-Output ("  [{0}] {1,-24} {2}" -f $p.mode, $p.item.id, $p.step.action)
        }
    }
    else {
        $target = Find-Item $verb
        if (-not $target) { Write-Output '  번호나 id 로 골라 주세요. 목록은 a, 도움말은 ?.' }
        else {
            Show-Detail $target
            $more = Read-YesNo '  더 궁금한 게 있으신가요? [y] 예 / [n] 아니오 (기본 n)'
            if ($more -eq 'y') {
                Write-Output ''
                Write-Output '  이 항목에 대해 하네스가 아는 것은 위가 전부입니다.'
                Write-Output '  더 자세한 것은 만든 곳의 공식 문서에 있어요:'
                Write-Output "    출처 : $(if ($target.publisher) { $target.publisher } else { '미상' })"
                if ($target.package) { Write-Output "    패키지 : $($target.package)" }
                if ($target.source) { Write-Output "    소스 : $($target.source)" }
                Write-Output '  카탈로그에 설명을 보태고 싶으면 catalogs/escort-glossary.json 을 고치면 됩니다.'
                Write-Output ''
            }
            Invoke-Decision $target
        }
    }
}

# ---------------------------------------------------------------------------
# 5단계 : 마무리
# ---------------------------------------------------------------------------
Write-Head '정리'

if ($picked.Count -eq 0) {
    Write-Output '  아무것도 담지 않으셨습니다. 그것도 괜찮은 결과입니다.'
    Write-Output '  필요해졌을 때 다시 부르세요:'
    Write-Output '    .\scripts\Invoke-HarnessEscort.ps1'
    exit 0
}

Write-Output '  담긴 것:'
foreach ($p in $picked) {
    $ri = Get-GlossaryEntry $glossary.risk $p.item.risk
    $rl = if ($ri) { $ri.label } else { $p.item.risk }
    Write-Output ("    [{0}] {1,-24} 위험 {2}" -f $p.mode, $p.item.id, $rl)
}

$autoCount = @($picked | Where-Object { $_.mode -eq '자동' }).Count
$manualCount = @($picked | Where-Object { $_.mode -eq '직접' }).Count
Write-Output ''
Write-Output "  자동 $autoCount 건 · 직접 $manualCount 건"

Write-Output ''
foreach ($t in @($profiles.closing_tips)) { Write-Wrapped ('- ' + $t) '  ' }

if (-not $SavePlan) {
    Write-Output ''
    Write-Output '  계획 파일을 저장하지 않았습니다 (-SavePlan 미지정).'
    Write-Output '  다음에 이렇게 부르면 결정이 파일로 남습니다:'
    Write-Output '    .\scripts\Invoke-HarnessEscort.ps1 -SavePlan .\escort.json'
    exit 0
}

$toolsRoot = Get-HarnessToolsRoot
$plan = New-HarnessChangePlan -HarnessRoot $root -ToolsRoot $toolsRoot -Overall 'READY' `
    -Steps (@($picked | ForEach-Object { $_.step })) `
    -Findings @([pscustomobject]@{
        area = 'escort'; item = '선택'; value = "자동 $autoCount / 직접 $manualCount"
        status = 'OK'; note = "프로필: $((@($chosenProfiles | ForEach-Object { $_.id })) -join ',')"
    })

Write-HarnessJson -Path $SavePlan -InputObject $plan -Depth 10

Write-Output ''
Write-Output "  계획 파일을 저장했습니다: $SavePlan"
Write-Output ''
Write-Output '  다음 순서 — 바꾸는 문은 하나입니다:'
Write-Output "    1) 열어서 확인하고, 원하지 않는 단계는 enabled 를 false 로"
Write-Output "       notepad '$SavePlan'"
Write-Output "    2) 실행될 명령만 미리 보기"
Write-Output "       .\scripts\Install-Harness.ps1 -Plan '$SavePlan' -DryRun"
Write-Output "    3) 확인 후 적용"
Write-Output "       .\scripts\Install-Harness.ps1 -Plan '$SavePlan'"
Write-Output ''
Write-Output "  '직접' 으로 고른 단계는 적용자가 실행하지 않습니다. 기록으로만 남습니다."
exit 0
