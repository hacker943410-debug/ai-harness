#Requires -Version 5.1
<#
    AI Harness — (런타임 x 클라이언트) 정합

    진단(Get-HarnessEnvironment)은 이 PC 전체를 넓게 훑는다.
    이 스크립트는 그 중 한 축만 깊게 본다: 선언된 런타임 각각이 클라이언트 각각에
    어떤 상태로 올라가 있는가. 한 화면에서 칸 단위로 볼 수 있어야
    "어디가 어긋났는지"가 아니라 "무엇이 어긋났는지"를 말할 수 있다.

    이 스크립트는 아무것도 바꾸지 않는다.
    -SavePlan 으로 변경 계획만 만들고, 적용은 Install-Harness.ps1 이 확인을 거쳐 한다.
    정합 스크립트가 스스로 고치기 시작하면 "확인 없이 살아있는 설정을 건드리는" 두 번째
    경로가 생긴다. 경로는 하나여야 한다.

    사용:
        .\Sync-HarnessClients.ps1
        .\Sync-HarnessClients.ps1 -SavePlan .\sync.json
        .\Sync-HarnessClients.ps1 -Json

    종료 코드: 0 모두 일치 / 2 불일치 있음 / 3 판정 불가(UNKNOWN) 포함
#>
[CmdletBinding()]
param(
    [string]$HarnessRoot,
    [string]$ToolsRoot,
    [string]$SavePlan,
    [string]$RuntimeId,
    [switch]$Json
)

if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Runtime.ps1')
Initialize-HarnessConsole

$root = (Resolve-Path -LiteralPath $HarnessRoot).Path
$tools = Get-HarnessToolsRoot -Override $ToolsRoot

$runtimeIds = @(Get-HarnessRuntimeIds -HarnessRoot $root)
if ($RuntimeId) { $runtimeIds = @($runtimeIds | Where-Object { $_ -eq $RuntimeId }) }
$clientIds = @(Get-HarnessClientIds -HarnessRoot $root)
$index = Read-HarnessRuntimeIndex -ToolsRoot $tools
$ledger = Read-HarnessClientRegistry -ToolsRoot $tools
$toolsRootId = Get-HarnessToolsRootId -ToolsRoot $tools

$cells = [System.Collections.Generic.List[object]]::new()
$steps = [System.Collections.Generic.List[object]]::new()

# ---------------------------------------------------------------------------
# 선언된 (런타임 x 클라이언트) 칸
# ---------------------------------------------------------------------------

foreach ($rid in $runtimeIds) {
    $m = Get-HarnessRuntimeManifest -HarnessRoot $root -RuntimeId $rid
    $entry = Get-HarnessIndexEntry -Index $index -RuntimeId $rid

    foreach ($cid in $clientIds) {
        $d = Get-HarnessClientDescriptor -HarnessRoot $root -ClientId $cid
        $recorded = @($ledger.registrations | Where-Object { $_.client -eq $cid -and $_.runtime_id -eq $rid })

        $cell = [ordered]@{
            runtime = $rid; client = $cid; server_name = $m.server_name
            status = 'unknown'; detail = ''; recorded = ($recorded.Count -gt 0)
        }

        if (-not (Get-HarnessNativeCommand $d.detect.command)) {
            $cell.status = 'client_absent'
            $cell.detail = "$($d.detect.command) 없음"
            $cells.Add([pscustomobject]$cell); continue
        }
        if (-not $entry) {
            # 런타임이 설치돼 있지 않으면 등록 자체가 불가능하다.
            # 그런데 원장이 등록됐다고 기억한다면 그건 원장이 낡은 것이다.
            $cell.status = 'runtime_absent'
            $cell.detail = if ($recorded.Count) { '런타임 미설치인데 원장에는 등록 기록이 있다' } else { '런타임 미설치' }
            $cells.Add([pscustomobject]$cell); continue
        }

        $diff = Get-HarnessRegistrationDiff -HarnessRoot $root -ToolsRoot $tools -RuntimeId $rid -ClientId $cid
        $present = @($diff.rows | Where-Object { $_.field -eq 'command' -and $_.actual }).Count -gt 0

        if (-not $present) {
            $cell.status = 'unregistered'
            $cell.detail = if ($recorded.Count) { '원장에는 있으나 클라이언트에는 없다' } else { '' }
            $steps.Add((New-HarnessRegistrationStep -HarnessRoot $root -ToolsRoot $tools -RuntimeId $rid -ClientId $cid `
                -Mode 'register' -Current '미등록' -Risk 'medium' -Optional ($recorded.Count -eq 0) `
                -Note $(if ($recorded.Count) { '원장과 실제가 갈라져 있다. 등록이 외부 요인으로 사라졌다.' }
                        else { "risk=$($m.risk) 런타임이다. 등록하면 이 클라이언트의 모든 프로젝트에서 보인다." })))
        } elseif (-not $diff.actual_readable) {
            # 읽을 수 없으면 OK 가 아니다. 재등록해서 우리가 아는 상태로 만든다.
            $cell.status = 'unknown'
            $cell.detail = 'probe 로 실제 등록 내용을 읽을 수 없다'
            $steps.Add((New-HarnessRegistrationStep -HarnessRoot $root -ToolsRoot $tools -RuntimeId $rid -ClientId $cid `
                -Mode 'register' -Current '등록됨(내용 불명)' -Risk 'medium' -Optional $true `
                -Note '실제 등록 내용을 확인할 수 없다. 재등록하면 선언과 같아진다.'))
        } elseif ($diff.has_change) {
            $bad = @($diff.rows | Where-Object { $_.verdict -in @('ADD', 'CHANGE', 'REMOVE') })
            $summary = ($bad | ForEach-Object { "$($_.field):$($_.verdict)" }) -join ', '
            $cell.status = 'drift'
            $cell.detail = $summary
            $steps.Add((New-HarnessRegistrationStep -HarnessRoot $root -ToolsRoot $tools -RuntimeId $rid -ClientId $cid `
                -Mode 'register' -Current '등록됨(내용 불일치)' -Optional $false `
                -Risk $(if ($diff.has_remove) { 'high' } else { 'medium' }) `
                -Note "선언과 실제가 다르다 ($summary). 재등록하면 선언대로 맞춰진다."))
        } else {
            $cell.status = 'ok'
            if (-not $recorded.Count) { $cell.detail = '일치하지만 원장에 기록이 없다 (재등록하면 기록된다)' }
        }

        if ($diff.ledger_drift.Count) {
            $cell.detail = ($cell.detail + ' | 원장 드리프트: ' + ($diff.ledger_drift -join '; ')).Trim(' ', '|')
        }
        $cells.Add([pscustomobject]$cell)
    }
}

# ---------------------------------------------------------------------------
# 고아 등록 — 원장에는 있는데 더 이상 선언되지 않은 런타임
# ---------------------------------------------------------------------------
# 하네스가 등록한 것만 대상으로 한다. 원장에 없는 서버는 남의 것이므로 건드리지 않는다.

$declaredIds = @(Get-HarnessRuntimeIds -HarnessRoot $root)
$orphans = @($ledger.registrations | Where-Object { $declaredIds -notcontains $_.runtime_id })
foreach ($o in $orphans) {
    $cells.Add([pscustomobject]@{
        runtime = $o.runtime_id; client = $o.client; server_name = $o.server_name
        status = 'orphan'; detail = '원장에 있으나 더 이상 선언되지 않은 런타임'; recorded = $true
    })
    # 매니페스트가 없으므로 공용 팩토리를 쓸 수 없다. 디스크립터만으로 해제 단계를 만든다.
    $d = $null
    try { $d = Get-HarnessClientDescriptor -HarnessRoot $root -ClientId $o.client } catch { continue }
    $scope = if ($d.supports.default_scope) { $d.supports.default_scope } else { '' }
    $rmArgv = Expand-HarnessArgv -Template @($d.argv.remove) -Values @{ server_name = $o.server_name; scope = $scope }
    $exe = Get-HarnessNativeCommand $d.detect.command
    if (-not $exe) { continue }
    $steps.Add((New-HarnessPlanStep -StepId "client.unregister:$($o.client)`:$($o.runtime_id)" -Kind 'exec' `
        -Action '고아 등록 해제' -Target "$($o.client) -> $($o.server_name)" `
        -Current '등록됨(선언 없음)' -Proposed '등록 제거' -Risk 'medium' -Optional $true `
        -Note '이 런타임은 더 이상 선언되지 않는다. 해제하면 이 클라이언트에서 도구가 사라진다.' `
        -CommandLine "$($d.detect.command) $($rmArgv -join ' ')" `
        -Payload ([pscustomobject]@{ file = $exe; arguments = @($rmArgv) })))
}

# 다른 도구 루트에서 만들어진 등록 기록은 이 PC 의 현재 구성이 아니다.
$foreign = @($ledger.registrations | Where-Object { $_.tools_root_id -and $_.tools_root_id -ne $toolsRootId })
foreach ($f in $foreign) {
    $cells.Add([pscustomobject]@{
        runtime = $f.runtime_id; client = $f.client; server_name = $f.server_name
        status = 'foreign_root'; detail = "다른 도구 루트에서 등록됨 (tools_root_id=$($f.tools_root_id))"; recorded = $true
    })
}

# ---------------------------------------------------------------------------
# 출력
# ---------------------------------------------------------------------------

$bad = @($cells | Where-Object { $_.status -in @('drift', 'unregistered', 'orphan', 'foreign_root') })
$unknownCells = @($cells | Where-Object status -eq 'unknown')
$overall = if ($unknownCells.Count) { 'UNKNOWN' } elseif ($bad.Count) { 'DRIFT' } else { 'IN_SYNC' }

$plan = New-HarnessChangePlan -HarnessRoot $root -ToolsRoot $tools -Overall $overall -Steps @($steps)
$plan | Add-Member -NotePropertyName matrix -NotePropertyValue @($cells) -Force

if ($SavePlan) {
    Write-HarnessJson -Path $SavePlan -InputObject $plan -Depth 10
}

if ($Json) {
    $plan | ConvertTo-Json -Depth 10
    if ($unknownCells.Count) { exit 3 }
    if ($bad.Count) { exit 2 }
    exit 0
}

Write-Output ''
Write-Output "클라이언트 정합: $overall"
Write-Output "  하네스    : $root"
Write-Output "  도구 루트 : $tools"
Write-Output ''
Write-Output ("  {0,-18} {1,-8} {2,-14} {3}" -f 'RUNTIME', 'CLIENT', 'STATUS', 'DETAIL')
foreach ($c in $cells) {
    Write-Output ("  {0,-18} {1,-8} {2,-14} {3}" -f $c.runtime, $c.client, $c.status, $c.detail)
}
Write-Output ''
Write-Output '  ok=선언과 일치  drift=내용 불일치  unregistered=미등록  unknown=읽을 수 없음'
Write-Output '  client_absent=CLI 없음  runtime_absent=런타임 미설치  orphan=선언 없는 등록'
Write-Output ''

if ($steps.Count) {
    Write-Output "제안하는 변경 $($steps.Count)건 (아직 아무것도 적용되지 않았습니다):"
    foreach ($s in $steps) {
        $tag = if ($s.optional) { '선택' } else { '권장' }
        Write-Output ("  [{0}/{1}] {2}  ({3})" -f $s.risk, $tag, $s.action, $s.step_id)
        Write-Output ("       {0}" -f $s.command_line)
        if ($s.note) { Write-Output ("       {0}" -f $s.note) }
    }
    Write-Output ''
    if ($SavePlan) {
        Write-Output "계획 파일: $SavePlan"
        Write-Output "적용: .\scripts\Install-Harness.ps1 -Plan '$SavePlan' -DryRun"
    } else {
        Write-Output '적용하려면 먼저 계획 파일을 만드세요:'
        Write-Output '  .\scripts\Sync-HarnessClients.ps1 -SavePlan .\sync.json'
    }
} else {
    Write-Output '제안할 변경이 없습니다.'
}
Write-Output ''

if ($unknownCells.Count) { exit 3 }
if ($bad.Count) { exit 2 }
exit 0
