#Requires -Version 5.1
<#
    AI Harness — 통합 적용 (진단이 낸 계획 파일을 소비한다)

    설계 전제 세 가지.

    1. -WhatIf 를 신뢰하지 않는다.
       [IO.File]::WriteAllText, [Environment]::SetEnvironmentVariable, 네이티브 exe 호출은
       ShouldProcess 를 거치지 않는다. 그래서 "무엇이 바뀌는가"를 PowerShell 에게 묻지 않고
       명시적 변경 계획 객체로 직접 만들어 보여준다.

    2. 재탐지하지 않는다.
       계획은 Get-HarnessEnvironment.ps1 -SavePlan 이 만들고, 사용자가 편집할 수 있다.
       여기서 다시 환경을 훑어 단계를 추가하면 사용자의 편집이 조용히 무시된다.
       이 스크립트가 하는 재확인은 "그 단계가 아직 필요한가"뿐이며, 필요 없으면 건너뛰기만 한다.

    3. 되돌릴 수 있어야 적용한다.
       변경 직전에 이전 상태를 append-only 저널에 기록한다.
       되돌릴 방법을 모르는 단계(undo 가 없는 exec)는 그 사실을 저널에 남긴다.
       모른다는 것을 안다고 말하지 않는다.

    사용:
        .\Get-HarnessEnvironment.ps1 -SavePlan .\plan.json
        .\Install-Harness.ps1 -Plan .\plan.json -DryRun        # 실행될 명령만 출력
        .\Install-Harness.ps1 -Plan .\plan.json                # 확인 후 적용
        .\Install-Harness.ps1 -Rollback <저널경로>              # 되돌리기

    종료 코드: 0 성공 / 1 실패(중단됨) / 2 사용자 취소 / 3 사전 조건 미충족
#>
[CmdletBinding()]
param(
    [string]$Plan,
    [string]$Rollback,
    [string]$HarnessRoot,
    [string[]]$Only,
    [string[]]$Skip,
    [switch]$IncludeOptional,
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$AllowRunningClients,
    [switch]$AllowStale,
    [switch]$IgnoreBlocks
)

# [CmdletBinding()] 가 있으면 5.1 은 param 기본값에서 $PSScriptRoot 를 비워 둔다.
if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Runtime.ps1')
Initialize-HarnessConsole

$root = (Resolve-Path -LiteralPath $HarnessRoot).Path
$PLAN_MAX_AGE_HOURS = 24

# ---------------------------------------------------------------------------
# 저널 — append-only. 여기에 없는 변경은 되돌릴 수 없다.
# ---------------------------------------------------------------------------

$script:JournalPath = $null
$script:JournalSeq = 0

function Get-HarnessFileStamp { return ([DateTimeOffset]::UtcNow.ToString('yyyyMMdd-HHmmss') + 'Z') }

function New-HarnessJournal {
    param([Parameter(Mandatory = $true)][string]$ToolsRoot)
    $dir = Join-HarnessPath $ToolsRoot 'journal'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (-not (Test-Path -LiteralPath $dir)) { throw "저널 디렉터리를 만들지 못했습니다: $dir" }
    $script:JournalPath = Join-HarnessPath $dir ("install-" + (Get-HarnessFileStamp) + '.jsonl')
    $script:JournalSeq = 0
    return $script:JournalPath
}

function Write-HarnessJournalRecord {
    param([Parameter(Mandatory = $true)][hashtable]$Record)
    if (-not $script:JournalPath) { return }
    $script:JournalSeq++
    $Record['seq'] = $script:JournalSeq
    $Record['at'] = (Get-HarnessUtcStamp)
    $line = ([pscustomobject]$Record | ConvertTo-Json -Depth 10 -Compress) + "`n"
    # append-only. 저널을 다시 쓰거나 자르지 않는다.
    [IO.File]::AppendAllText($script:JournalPath, $line, (Get-HarnessUtf8NoBom))
}

function Get-HarnessJournalBackupDir {
    param([Parameter(Mandatory = $true)][string]$JournalPath)
    return ($JournalPath -replace '\.jsonl$', '.backup')
}

# ---------------------------------------------------------------------------
# 변경 원시 연산 — 각각 before 상태를 반환한다
# ---------------------------------------------------------------------------

# ACL 조작은 _Harness.Common.ps1 의 DACL 전용 헬퍼를 쓴다.
# Get-Acl / Set-Acl 은 SACL 까지 다루려 해서 SeSecurityPrivilege 를 요구한다(관리자 승격 필요).
# 우리가 바꾸는 것은 DACL 뿐이므로 그 섹션만 읽고 쓴다.

function Invoke-HarnessExec {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [string[]]$Arguments = @()
    )
    $out = & $File @Arguments 2>&1
    return [pscustomobject]@{ exit = $LASTEXITCODE; text = ($out | Out-String).TrimEnd() }
}

# ---------------------------------------------------------------------------
# 롤백 모드
# ---------------------------------------------------------------------------

function Invoke-HarnessRollback {
    param([Parameter(Mandatory = $true)][string]$JournalPath)

    if (-not (Test-Path -LiteralPath $JournalPath)) { throw "저널이 없습니다: $JournalPath" }
    $records = @()
    foreach ($line in ((Read-HarnessText -Path $JournalPath) -split "`r?`n")) {
        if (-not $line.Trim()) { continue }
        $records += ($line | ConvertFrom-Json)
    }

    # begin 이 있어야 before 를 알고, end/applied 가 있어야 실제로 바뀐 것이다.
    $applied = @($records | Where-Object { $_.phase -eq 'end' -and $_.status -eq 'applied' })
    if ($applied.Count -eq 0) {
        Write-Output '되돌릴 변경이 없습니다 (applied 기록 없음).'
        return 0
    }
    $begins = @{}
    foreach ($r in ($records | Where-Object phase -eq 'begin')) { $begins[$r.step_id] = $r }

    Write-Output ''
    Write-Output "롤백 대상 ($($applied.Count)건, 적용의 역순):"
    foreach ($r in ($applied | Sort-Object seq -Descending)) {
        Write-Output ("  - {0}  ({1})" -f $r.step_id, $r.kind)
    }
    Write-Output ''
    if (-not $Yes) {
        $ans = Read-Host "되돌리려면 ROLLBACK 을 입력하세요"
        if ($ans -ne 'ROLLBACK') { Write-Output '취소했습니다.'; return 2 }
    }

    $failed = 0
    foreach ($r in ($applied | Sort-Object seq -Descending)) {
        $b = $begins[$r.step_id]
        $label = "$($r.step_id) [$($r.kind)]"
        try {
            switch ($r.kind) {
                'dir-create' {
                    if ($b.before.existed) { Write-Output "  건너뜀 $label — 원래 있던 디렉터리"; continue }
                    $p = $b.target
                    if (-not (Test-Path -LiteralPath $p)) { Write-Output "  건너뜀 $label — 이미 없음"; continue }
                    $items = @(Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue)
                    if ($items.Count) {
                        Write-Warning "  보류 $label — 비어 있지 않아 삭제하지 않았습니다: $p"
                        continue
                    }
                    Remove-Item -LiteralPath $p -Force -Confirm:$false
                    Write-Output "  되돌림 $label — 디렉터리 삭제"
                }
                'acl-set' {
                    if (-not $b.before.sddl) { Write-Warning "  보류 $label — 이전 SDDL 이 없습니다"; continue }
                    Restore-HarnessDaclSddl -Path $b.target -Sddl $b.before.sddl
                    Write-Output "  되돌림 $label — DACL 복원"
                }
                'env-set' {
                    $name = $b.before.name
                    $old = $b.before.value
                    [Environment]::SetEnvironmentVariable($name, $old, 'User')
                    Write-Output "  되돌림 $label — $name = $(if ($old) { $old } else { '(삭제)' })"
                }
                'file-write' {
                    if ($b.before.existed) {
                        $bak = $b.before.backup
                        if (-not (Test-Path -LiteralPath $bak)) { Write-Warning "  보류 $label — 백업이 없습니다: $bak"; continue }
                        [IO.File]::Copy($bak, $b.target, $true)
                        Write-Output "  되돌림 $label — 백업에서 복원"
                    } else {
                        if (Test-Path -LiteralPath $b.target) { Remove-Item -LiteralPath $b.target -Force -Confirm:$false }
                        Write-Output "  되돌림 $label — 새로 만든 파일 삭제"
                    }
                }
                'exec' {
                    if (-not $r.undo) {
                        Write-Warning ("  수동 확인 필요 $label — 되돌리는 방법이 계획에 없었습니다. " +
                                       "적용된 명령: $($b.intent.command_line)")
                        $failed++
                        continue
                    }
                    $res = Invoke-HarnessExec -File $r.undo.file -Arguments @($r.undo.arguments)
                    if ($res.exit -ne 0) { throw "undo 명령이 exit $($res.exit) 로 실패했습니다: $($res.text)" }
                    Write-Output "  되돌림 $label — $($r.undo.command_line)"
                }
                default { Write-Warning "  알 수 없는 kind: $($r.kind)" ; $failed++ }
            }
        } catch {
            Write-Warning "  실패 $label — $($_.Exception.Message)"
            $failed++
        }
    }
    Write-Output ''
    if ($failed) {
        Write-Output "롤백 완료(수동 확인 $failed 건). 위 경고를 확인하세요."
        return 1
    }
    Write-Output '롤백 완료.'
    return 0
}

if ($Rollback) { exit (Invoke-HarnessRollback -JournalPath $Rollback) }

# ---------------------------------------------------------------------------
# 계획 로드 + 검증
# ---------------------------------------------------------------------------

if (-not $Plan) {
    Write-Output ''
    Write-Output '적용할 계획 파일이 필요합니다. 진단이 계획을 만들고, 사람이 확인한 뒤에 적용합니다.'
    Write-Output ''
    Write-Output '  1) .\scripts\Get-HarnessEnvironment.ps1 -SavePlan .\plan.json'
    Write-Output '  2) plan.json 에서 빼고 싶은 단계의 enabled 를 false 로'
    Write-Output '  3) .\scripts\Install-Harness.ps1 -Plan .\plan.json -DryRun'
    Write-Output '  4) .\scripts\Install-Harness.ps1 -Plan .\plan.json'
    Write-Output ''
    exit 3
}
if (-not (Test-Path -LiteralPath $Plan)) { throw "계획 파일이 없습니다: $Plan" }
$planPath = (Resolve-Path -LiteralPath $Plan).Path
$doc = Read-HarnessJson -Path $planPath

if ($doc.kind -ne 'harness-change-plan') { throw "계획 파일이 아닙니다 (kind=$($doc.kind)): $planPath" }
if ($doc.schema_version -ne '1.0') { throw "계획 스키마 버전을 지원하지 않습니다: $($doc.schema_version)" }
if ($doc.harness_root -ne $root) {
    throw ("계획이 만들어진 하네스와 지금 실행 중인 하네스가 다릅니다.`n" +
           "  계획: $($doc.harness_root)`n  현재: $root")
}

$ageHours = ([DateTimeOffset]::UtcNow - [DateTimeOffset]::Parse($doc.checked_at)).TotalHours
if ($ageHours -gt $PLAN_MAX_AGE_HOURS -and -not $AllowStale) {
    throw ("계획이 오래됐습니다 ($([math]::Round($ageHours,1)) 시간 전). 그 사이 환경이 달라졌을 수 있습니다.`n" +
           '진단을 다시 돌려 계획을 새로 만드세요. 그대로 쓰려면 -AllowStale 을 붙이세요.')
}
if (@($doc.blocks).Count -and -not $IgnoreBlocks) {
    Write-Output '차단 요소가 있는 상태에서 만들어진 계획입니다:'
    foreach ($b in $doc.blocks) { Write-Output ("  - {0}: {1}" -f $b.item, $b.note) }
    Write-Output ''
    Write-Output '먼저 해결하거나, 그래도 진행하려면 -IgnoreBlocks 를 붙이세요.'
    exit 3
}

$toolsRoot = $doc.tools_root
$allSteps = @($doc.plan)
if ($allSteps.Count -eq 0) { Write-Output '계획에 단계가 없습니다. 적용할 것이 없습니다.'; exit 0 }

# ---------------------------------------------------------------------------
# 단계 선별 — 사용자 의사(enabled) -> 필터 -> 의존성
# ---------------------------------------------------------------------------

$dropped = [System.Collections.Generic.List[object]]::new()
function Add-DroppedStep { param($Step, [string]$Why) $dropped.Add([pscustomobject]@{ step_id = $Step.step_id; why = $Why }) }

$selected = [System.Collections.Generic.List[object]]::new()
foreach ($s in $allSteps) {
    if ($s.kind -eq 'manual') { Add-DroppedStep $s '수동 단계 — 스크립트가 실행하지 않는다'; continue }
    if (-not $s.enabled) { Add-DroppedStep $s '계획 파일에서 enabled=false 로 제외됨'; continue }
    if ($Skip -and ($Skip -contains $s.step_id)) { Add-DroppedStep $s '-Skip 으로 제외됨'; continue }
    if ($Only) {
        if ($Only -notcontains $s.step_id) { Add-DroppedStep $s '-Only 에 없음'; continue }
    } elseif ($s.optional -and -not $IncludeOptional) {
        Add-DroppedStep $s '선택 단계 — 넣으려면 -IncludeOptional 또는 -Only'
        continue
    }
    $selected.Add($s)
}

# 선행 단계를 거부했으면 그것에 의존하는 단계는 아예 제시하지 않는다.
# 계획에 아예 없는 id 는 "이미 충족됨"이므로 의존으로 치지 않는다.
$planIds = @($allSteps | ForEach-Object { $_.step_id })
$changed = $true
while ($changed) {
    $changed = $false
    $selIds = @($selected | ForEach-Object { $_.step_id })
    foreach ($s in @($selected)) {
        foreach ($dep in @($s.depends_on)) {
            if (-not $dep) { continue }
            if ($planIds -notcontains $dep) { continue }
            if ($selIds -contains $dep) { continue }
            [void]$selected.Remove($s)
            Add-DroppedStep $s "선행 단계가 빠졌다: $dep"
            $changed = $true
            break
        }
        if ($changed) { break }
    }
}

# ---------------------------------------------------------------------------
# 아직 필요한가 — 재확인 (재탐지가 아니라 각 단계의 사후 조건 확인)
# ---------------------------------------------------------------------------

$actions = [System.Collections.Generic.List[object]]::new()
$diffTables = [System.Collections.Generic.List[object]]::new()

foreach ($s in $selected) {
    $needed = $true
    $why = ''
    switch ($s.kind) {
        'dir-create' {
            if (Test-Path -LiteralPath $s.payload.path) { $needed = $false; $why = '이미 존재' }
        }
        'acl-set' {
            $t = Test-HarnessPathTrust -Path $s.payload.path
            if ($t.checked -and $t.trusted) { $needed = $false; $why = '이미 제한됨' }
            elseif (-not (Test-Path -LiteralPath $s.payload.path)) { $needed = $false; $why = '대상이 없음' }
        }
        'env-set' {
            $cur = [Environment]::GetEnvironmentVariable($s.payload.name, $s.payload.scope)
            if ($cur -eq $s.payload.value) { $needed = $false; $why = '이미 같은 값' }
        }
        'file-write' {
            if (Test-Path -LiteralPath $s.payload.path) {
                if ((Read-HarnessText -Path $s.payload.path) -eq [string]$s.payload.text) { $needed = $false; $why = '내용 동일' }
            }
        }
        'exec' {
            # exec 는 일반적으로 사후 조건을 알 수 없다. 다만 payload.diff 가 있으면
            # 선언/원장/실제를 지금 다시 대조해서, 정말 바꿀 것이 있는지 보여준다.
            if ($s.payload.PSObject.Properties.Name -contains 'diff' -and $s.payload.diff) {
                $d = $s.payload.diff
                if ($d.kind -eq 'registration') {
                    $dt = Get-HarnessRegistrationDiff -HarnessRoot $root -ToolsRoot $toolsRoot `
                        -RuntimeId $d.runtime_id -ClientId $d.client_id
                    $diffTables.Add([pscustomobject]@{ step_id = $s.step_id; diff = $dt })
                    if (-not $dt.client_installed) { $needed = $false; $why = '클라이언트가 설치돼 있지 않음' }
                    elseif ($dt.actual_readable -and -not $dt.has_change) { $needed = $false; $why = '이미 선언과 일치' }
                }
            }
        }
    }
    if ($needed) { $actions.Add($s) } else { Add-DroppedStep $s "불필요: $why" }
}

# ---------------------------------------------------------------------------
# 변경 계획 렌더링
# ---------------------------------------------------------------------------

Write-Output ''
Write-Output '변경 계획 (아직 아무것도 적용되지 않았습니다)'
Write-Output "  계획 파일 : $planPath  ($([math]::Round($ageHours,1)) 시간 전 생성)"
Write-Output "  하네스    : $root"
Write-Output "  도구 루트 : $toolsRoot"
Write-Output ''

if ($diffTables.Count) {
    Write-Output '3-way diff — 선언(Layer A) / 원장(Layer B) / 실제(클라이언트)'
    foreach ($dtw in $diffTables) {
        $dt = $dtw.diff
        Write-Output ("  [{0}]  client={1} runtime={2}" -f $dtw.step_id, $dt.client_id, $dt.runtime_id)
        if (-not $dt.actual_readable) {
            Write-Output '      실제 값을 읽을 수 없습니다. UNKNOWN 은 OK 가 아닙니다.'
        }
        foreach ($row in $dt.rows) {
            if ($row.verdict -eq 'SAME') { continue }
            Write-Output ("      {0,-7} {1}" -f $row.verdict, $row.field)
            Write-Output ("              선언: {0}" -f $(if ($null -eq $row.declared) { '(없음)' } else { $row.declared }))
            Write-Output ("              원장: {0}" -f $(if ($null -eq $row.recorded) { '(없음)' } else { $row.recorded }))
            Write-Output ("              실제: {0}" -f $(if ($null -eq $row.actual) { '(없음)' } else { $row.actual }))
        }
        foreach ($ld in @($dt.ledger_drift)) { Write-Output ("      원장 드리프트: {0}" -f $ld) }
    }
    Write-Output ''
}

$removeRows = @()
foreach ($dtw in $diffTables) { $removeRows += @($dtw.diff.rows | Where-Object verdict -eq 'REMOVE') }

if ($actions.Count -eq 0) {
    Write-Output '적용할 단계가 없습니다.'
} else {
    Write-Output "적용할 단계 $($actions.Count)건:"
    $i = 0
    foreach ($s in $actions) {
        $i++
        Write-Output ("  {0}. [{1}] {2}   ({3})" -f $i, $s.risk, $s.action, $s.step_id)
        Write-Output ("       kind   : {0}" -f $s.kind)
        Write-Output ("       대상   : {0}" -f $s.target)
        Write-Output ("       현재   : {0}" -f $s.current)
        Write-Output ("       적용후 : {0}" -f $s.proposed)
        switch ($s.kind) {
            'env-set' { Write-Output ("       변경   : {0} ({1}) = {2}" -f $s.payload.name, $s.payload.scope, $s.payload.value) }
            'file-write' { Write-Output ("       변경   : {0} 에 {1} 바이트 기록" -f $s.payload.path, ([string]$s.payload.text).Length) }
            'exec' { Write-Output ("       명령   : {0}" -f $s.command_line) }
        }
        if ($s.undo) { Write-Output ("       되돌리기: {0}" -f $s.undo.command_line) }
        elseif ($s.kind -eq 'exec') { Write-Output '       되돌리기: (없음 — 롤백 시 수동 확인이 필요합니다)' }
        if ($s.note) { Write-Output ("       {0}" -f $s.note) }
    }
}

if ($dropped.Count) {
    Write-Output ''
    Write-Output '제외된 단계:'
    foreach ($d in $dropped) { Write-Output ("  - {0}  ({1})" -f $d.step_id, $d.why) }
}

if ($removeRows.Count) {
    Write-Output ''
    Write-Output '주의 — 선언에 없는데 실제로 켜져 있는 값이 있습니다 (REMOVE):'
    foreach ($r in $removeRows) { Write-Output ("  {0} = {1}" -f $r.field, $r.actual) }
    Write-Output '  적용하면 이 값들은 사라집니다. 의도한 것인지 확인하세요.'
}

if ($actions.Count -eq 0) { Write-Output ''; exit 0 }

if ($DryRun) {
    Write-Output ''
    Write-Output '-DryRun 이므로 여기서 멈춥니다. 아무것도 적용되지 않았습니다.'
    exit 0
}

# ---------------------------------------------------------------------------
# 적용 직전 재확인 — 실행 중인 CLI 세션
# ---------------------------------------------------------------------------

$affectedClients = @()
foreach ($s in $actions) {
    if ($s.payload -and ($s.payload.PSObject.Properties.Name -contains 'diff') -and $s.payload.diff -and $s.payload.diff.client_id) {
        $affectedClients += [string]$s.payload.diff.client_id
    }
}
# 환경변수는 모든 클라이언트에 영향을 준다.
if (@($actions | Where-Object kind -eq 'env-set').Count) { $affectedClients = Get-HarnessClientIds -HarnessRoot $root }
$affectedClients = @($affectedClients | Select-Object -Unique)

if ($affectedClients.Count) {
    $running = Get-HarnessRunningClientProcess -HarnessRoot $root -ClientIds $affectedClients
    if ($running.Count) {
        Write-Output ''
        Write-Output '실행 중인 클라이언트 세션이 있습니다:'
        foreach ($p in $running) { Write-Output ("  {0}  pid={1} {2}" -f $p.client, $p.pid_, $p.command_line) }
        Write-Output '  이 세션들은 옛 등록으로 계속 동작합니다. 변경은 재시작 후에야 반영됩니다.'
        Write-Output '  (이 명령을 클라이언트 안에서 실행하고 있다면 그 세션도 여기 포함됩니다.)'
        if (-not $AllowRunningClients) {
            Write-Output ''
            Write-Output '세션을 종료한 뒤 다시 실행하거나, 알고도 진행하려면 -AllowRunningClients 를 붙이세요.'
            exit 3
        }
        Write-Output '  -AllowRunningClients 가 지정되어 계속 진행합니다.'
    }
}

# ---------------------------------------------------------------------------
# 확인
# ---------------------------------------------------------------------------

if (-not $Yes) {
    if (-not [Environment]::UserInteractive) {
        Write-Output ''
        Write-Output '비대화형 세션입니다. 확인을 받을 수 없으므로 적용하지 않습니다. -Yes 를 명시하세요.'
        exit 2
    }
    Write-Output ''
    if ($removeRows.Count) {
        $ans = Read-Host "선언에 없는 값 $($removeRows.Count)건이 사라집니다. 동의하면 REMOVE 를 입력하세요"
        if ($ans -ne 'REMOVE') { Write-Output '취소했습니다. 아무것도 적용되지 않았습니다.'; exit 2 }
    }
    $ans = Read-Host "위 $($actions.Count)건을 적용하려면 APPLY 를 입력하세요"
    if ($ans -ne 'APPLY') { Write-Output '취소했습니다. 아무것도 적용되지 않았습니다.'; exit 2 }
}

# ---------------------------------------------------------------------------
# 적용
# ---------------------------------------------------------------------------

$journal = New-HarnessJournal -ToolsRoot $toolsRoot
$backupDir = Get-HarnessJournalBackupDir -JournalPath $journal
Write-Output ''
Write-Output "저널: $journal"
Write-Output ''

Write-HarnessJournalRecord @{
    phase = 'plan'; plan_path = $planPath; harness_root = $root; tools_root = $toolsRoot
    steps = @($actions | ForEach-Object { $_.step_id })
}

$applied = 0
$failedStep = $null

foreach ($s in $actions) {
    $before = @{}
    $intent = @{ command_line = $s.command_line; proposed = $s.proposed }

    switch ($s.kind) {
        'dir-create' { $before = @{ existed = [bool](Test-Path -LiteralPath $s.payload.path) } }
        'acl-set' { $before = @{ sddl = (Get-HarnessDaclSddl -Path $s.payload.path) } }
        'env-set' {
            $before = @{
                name = $s.payload.name; scope = $s.payload.scope
                value = [Environment]::GetEnvironmentVariable($s.payload.name, $s.payload.scope)
            }
        }
        'file-write' {
            $exists = Test-Path -LiteralPath $s.payload.path
            $bak = $null
            if ($exists) {
                if (-not (Test-Path -LiteralPath $backupDir)) { New-Item -ItemType Directory -Force -Path $backupDir | Out-Null }
                $bak = Join-HarnessPath $backupDir ("{0:d3}-{1}" -f ($script:JournalSeq + 1), (Split-Path -Leaf $s.payload.path))
                [IO.File]::Copy($s.payload.path, $bak, $true)
            }
            $before = @{ existed = $exists; backup = $bak }
        }
        'exec' { $before = @{ note = 'exec 은 이전 상태를 일반적으로 포착할 수 없다' } }
    }

    Write-HarnessJournalRecord @{
        phase = 'begin'; step_id = $s.step_id; kind = $s.kind; target = $s.target
        before = $before; intent = $intent
    }

    Write-Output ("적용 중: {0}  ({1})" -f $s.action, $s.step_id)
    try {
        switch ($s.kind) {
            'dir-create' {
                New-Item -ItemType Directory -Force -Path $s.payload.path | Out-Null
                # New-Item 은 MAX_PATH 를 넘는 경로에서도 성공한 것처럼 보인다. 실제로 확인한다.
                if (-not (Test-Path -LiteralPath $s.payload.path)) { throw "디렉터리가 만들어지지 않았습니다: $($s.payload.path)" }
                if ($s.payload.restrict_acl) { Set-HarnessRestrictedDacl -Path $s.payload.path }
            }
            'acl-set' {
                Set-HarnessRestrictedDacl -Path $s.payload.path
                $t = Test-HarnessPathTrust -Path $s.payload.path
                if (-not $t.trusted) { throw "ACL 을 적용했지만 여전히 신뢰할 수 없습니다: $($t.offenders -join '; ')" }
            }
            'env-set' {
                [Environment]::SetEnvironmentVariable($s.payload.name, $s.payload.value, $s.payload.scope)
                $now = [Environment]::GetEnvironmentVariable($s.payload.name, $s.payload.scope)
                if ($now -ne $s.payload.value) { throw "환경변수가 기대한 값으로 설정되지 않았습니다: '$now'" }
            }
            'file-write' {
                Write-HarnessText -Path $s.payload.path -Text ([string]$s.payload.text)
                if (-not (Test-Path -LiteralPath $s.payload.path)) { throw "파일이 만들어지지 않았습니다: $($s.payload.path)" }
            }
            'exec' {
                $res = Invoke-HarnessExec -File $s.payload.file -Arguments @($s.payload.arguments)
                foreach ($line in ($res.text -split "`r?`n")) { if ($line.Trim()) { Write-Output ("    | " + $line) } }
                if ($res.exit -ne 0) { throw "명령이 exit $($res.exit) 로 실패했습니다" }
            }
        }
        Write-HarnessJournalRecord @{
            phase = 'end'; step_id = $s.step_id; kind = $s.kind; status = 'applied'
            undo = $s.undo
        }
        $applied++
        Write-Output '  완료'
    } catch {
        Write-HarnessJournalRecord @{
            phase = 'end'; step_id = $s.step_id; kind = $s.kind; status = 'failed'
            detail = $_.Exception.Message
        }
        Write-Warning "  실패: $($_.Exception.Message)"
        $failedStep = $s
        break
    }
}

# ---------------------------------------------------------------------------
# 결과
# ---------------------------------------------------------------------------

Write-Output ''
if ($failedStep) {
    Write-Output "중단됨. $applied 건 적용, '$($failedStep.step_id)' 에서 실패."
    Write-Output '남은 단계는 실행하지 않았습니다. 되돌리려면:'
    Write-Output "  .\scripts\Install-Harness.ps1 -Rollback '$journal'"
    exit 1
}

Write-Output "$applied 건을 적용했습니다."
Write-Output "되돌리려면: .\scripts\Install-Harness.ps1 -Rollback '$journal'"
Write-Output ''
Write-Output '다음으로 할 일:'
Write-Output '  - 등록을 바꿨다면 해당 CLI 를 재시작해야 반영됩니다.'
Write-Output '  - 런타임은 실제 호출까지 확인해야 verified 입니다:'
Write-Output '      .\scripts\Test-HarnessRuntime.ps1 -RuntimeId <id>'
exit 0
