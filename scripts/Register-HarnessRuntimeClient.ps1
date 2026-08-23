#Requires -Version 5.1
<#
    AI Harness — 공용 런타임을 AI 클라이언트 1개에 등록

    원칙:
      1. 등록 후 반드시 되읽어 확인한다. "명령을 실행했다"와 "등록됐다"는 다른 사건이다.
      2. probe 는 존재 여부만이 아니라 실제 등록된 command 를 읽어야 한다.
         읽을 수 없으면 OK 가 아니라 UNKNOWN 이다. 원장이 기록한 값과
         클라이언트의 실제 값이 갈라져도 모르게 되면 원장은 의미가 없다.
      3. risk=high 런타임의 자동 등록은 명시적 동의를 요구한다.

    사용:
        .\Register-HarnessRuntimeClient.ps1 -RuntimeId google-workspace -Client claude
        .\Register-HarnessRuntimeClient.ps1 -RuntimeId google-workspace -Client all -IAcceptRisk
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string]$RuntimeId,
    [string]$Client = 'all',
    [string]$Scope,
    [string]$ToolsRoot,
    [string]$HarnessRoot,
    [switch]$Force,
    [switch]$IAcceptRisk
)

if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Runtime.ps1')
Initialize-HarnessConsole

$root = (Resolve-Path -LiteralPath $HarnessRoot).Path
$tools = Get-HarnessToolsRoot -Override $ToolsRoot
$machineKey = Get-HarnessToolsRootId -ToolsRoot $tools

$manifest = Get-HarnessRuntimeManifest -HarnessRoot $root -RuntimeId $RuntimeId
$index = Read-HarnessRuntimeIndex -ToolsRoot $tools
$entry = Get-HarnessIndexEntry -Index $index -RuntimeId $RuntimeId
if (-not $entry) { throw "런타임이 설치되어 있지 않습니다: $RuntimeId. 먼저 Install-HarnessRuntime.ps1 을 실행하세요." }

$command = Join-HarnessPath $tools $entry.command_rel
if (-not (Test-Path -LiteralPath $command)) { throw "실행 파일이 없습니다: $command" }

$desiredArgs = @($entry.args)
$desiredEnv = [ordered]@{}
if ($entry.env) { foreach ($p in $entry.env.PSObject.Properties) { $desiredEnv[$p.Name] = [string]$p.Value } }
$desiredFp = Get-HarnessCommandFingerprint -Command $command -Arguments $desiredArgs -Env $desiredEnv -MachineKey $machineKey

# risk=high 런타임은 전역 자동 등록을 기본으로 하지 않는다.
if ($manifest.risk -eq 'high' -and -not $IAcceptRisk -and -not $Force) {
    $registry0 = Read-HarnessClientRegistry -ToolsRoot $tools
    $consented = @($registry0.registrations | Where-Object { $_.runtime_id -eq $RuntimeId -and $_.risk_accepted }).Count -gt 0
    if (-not $consented) {
        throw ("'$RuntimeId' 은 risk=high 런타임입니다. 전역 등록은 명시적 동의가 필요합니다.`n" +
               "동의하려면 -IAcceptRisk 를 붙이세요. 위험 도구 목록은 매니페스트의 tool_policy 를 보세요:`n" +
               "  deny    : $(@($manifest.tool_policy.deny) -join ', ')`n" +
               "  approve : $(@($manifest.tool_policy.approve) -join ', ')")
    }
}

# probe / 실행 헬퍼는 _Harness.Runtime.ps1 에 있다.
# Install-Harness.ps1 의 3-way diff 와 같은 구현을 써야 한다.
# 두 벌로 두면 "적용 전에 본 상태"와 "적용 후에 확인한 상태"의 판정 기준이 갈라진다.

function Register-One {
    param([string]$ClientId)

    $d = Get-HarnessClientDescriptor -HarnessRoot $root -ClientId $ClientId
    $exe = Get-HarnessNativeCommand $d.detect.command
    if (-not $exe) {
        return [pscustomobject]@{ client = $ClientId; status = 'not_installed'; detail = "$($d.detect.command) 을 PATH 에서 찾을 수 없습니다." }
    }

    if ($d.adapter_kind -ne 'argv_cli') {
        # 설정 형식을 확인할 수 없는 클라이언트에는 임의 파일을 만들지 않는다.
        $pending = Join-HarnessPath $tools 'clients' 'pending' "$ClientId.mcp.json"
        Write-HarnessJson -Path $pending -Depth 8 -InputObject @{
            mcpServers = @{ "$($manifest.server_name)" = @{ command = $command; args = $desiredArgs; env = $desiredEnv } }
        }
        return [pscustomobject]@{ client = $ClientId; status = 'partial'; detail = "이식용 설정만 기록했습니다: $pending" }
    }

    $scope = if ($Scope) { $Scope } elseif ($d.supports.default_scope) { $d.supports.default_scope } else { '' }
    $values = @{ server_name = $manifest.server_name; command = $command; scope = $scope }

    $before = Read-HarnessClientRegistration -Descriptor $d -ServerName $manifest.server_name
    $actualFp = $null
    if ($before.present -and $before.parseable -and $before.command) {
        $actualFp = Get-HarnessCommandFingerprint -Command $before.command -Arguments @($before.args) -Env $null -MachineKey $machineKey
    }

    # 지문 비교는 클라이언트가 실제로 보고한 값으로만 한다. 원장의 기억으로 하지 않는다.
    $desiredFpNoEnv = Get-HarnessCommandFingerprint -Command $command -Arguments $desiredArgs -Env $null -MachineKey $machineKey
    $matches = ($actualFp -and $actualFp -eq $desiredFpNoEnv)

    if ($before.present -and $matches -and -not $Force) {
        return [pscustomobject]@{ client = $ClientId; status = 'already_registered'; detail = $before.command; drift = @() }
    }
    if ($before.present -and -not $before.parseable) {
        # 읽어올 수 없으면 OK 라고 말할 수 없다.
        if (-not $Force) {
            return [pscustomobject]@{ client = $ClientId; status = 'unknown'; detail = 'probe 로 실제 command 를 읽을 수 없습니다. -Force 로 재등록하세요.'; drift = @('fingerprint_unknown') }
        }
    }

    if (-not $PSCmdlet.ShouldProcess("$ClientId ($scope)", "register $($manifest.server_name)")) {
        return [pscustomobject]@{ client = $ClientId; status = 'skipped'; detail = 'ShouldProcess 거부' }
    }

    # upsert 가 아니면 먼저 제거한다. 경로만 다른 재등록은 remove+add 로 처리한다.
    # 그런데 add 가 실패하면 클라이언트에는 아무것도 남지 않는다.
    # 고치려던 등록을 아예 없애 버리는 것이고, 실제로 한 번 그렇게 됐다.
    # 그래서 지우기 전에 이전 등록을 복원할 수 있을 만큼 붙잡아 둔다.
    $removed = $false
    if ($before.present -and -not $d.register_is_upsert) {
        $rmArgs = Expand-HarnessArgv -Template @($d.argv.remove) -Values $values
        Invoke-HarnessClientCommand -Exe $exe -Arguments $rmArgs | Out-Null
        $removed = $true
    }

    $addArgs = Expand-HarnessArgv -Template @($d.argv.register) -Values $values `
        -RuntimeArgs $desiredArgs -EnvPairs $desiredEnv -EnvFlagTemplate @($d.env_flag_template)
    $add = Invoke-HarnessClientCommand -Exe $exe -Arguments $addArgs

    $after = Read-HarnessClientRegistration -Descriptor $d -ServerName $manifest.server_name
    if (-not $after.present) {
        $detail = ($add.text -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 2) -join ' '
        $restored = 'not_attempted'
        if ($removed -and $before.parseable -and $before.command) {
            # 원래대로 되돌린다. 실패한 채로 두면 사용자는 고치려다 잃는다.
            $restoreValues = @{ server_name = $manifest.server_name; command = $before.command; scope = $scope }
            $restoreArgs = Expand-HarnessArgv -Template @($d.argv.register) -Values $restoreValues `
                -RuntimeArgs @($before.args) -EnvPairs $before.env -EnvFlagTemplate @($d.env_flag_template)
            Invoke-HarnessClientCommand -Exe $exe -Arguments $restoreArgs | Out-Null
            $back = Read-HarnessClientRegistration -Descriptor $d -ServerName $manifest.server_name
            $restored = if ($back.present) { 'restored' } else { 'restore_failed' }
        }
        return [pscustomobject]@{
            client = $ClientId; status = 'failed'
            detail = "$detail  [이전 등록: $restored]"
            restored = $restored
        }
    }

    # 등록에 성공했다고 안전해진 것은 아니다.
    # 도구 단위 차단이 불가능한 클라이언트에서는 매니페스트의 deny 가 문서일 뿐이다.
    # 조용히 넘기면 사용자는 목록이 지켜지고 있다고 믿게 된다.
    if ($manifest.risk -eq 'high' -and -not ($d.tool_policy_support -and $d.tool_policy_support.deny)) {
        Write-Warning ("$ClientId 는 도구 단위 차단을 지원하지 않습니다. " +
                       "매니페스트의 deny 목록이 강제되지 않습니다: $(@($manifest.tool_policy.deny) -join ', '). " +
                       '통제 단위는 서버 전체 on/off 뿐입니다.')
    }

    return [pscustomobject]@{
        client = $ClientId
        status = 'registered'
        detail = $after.command
        drift  = @()
    }
}

$clientIds = if ($Client -eq 'all') { Get-HarnessClientIds -HarnessRoot $root } else { @($Client) }
$results = @()
foreach ($c in $clientIds) { $results += Register-One -ClientId $c }

# --- 원장 기록 -------------------------------------------------------------
$registry = Read-HarnessClientRegistry -ToolsRoot $tools
$keep = @($registry.registrations | Where-Object { -not ($_.runtime_id -eq $RuntimeId -and $clientIds -contains $_.client) })
foreach ($r in $results) {
    if ($r.status -in @('registered', 'already_registered')) {
        $rd = Get-HarnessClientDescriptor -HarnessRoot $root -ClientId $r.client
        $keep += [pscustomobject]@{
            runtime_id    = $RuntimeId
            server_name   = $manifest.server_name
            client        = $r.client
            fingerprint   = $desiredFp
            tools_root_id = $machineKey
            risk          = $manifest.risk
            risk_accepted = [bool]($IAcceptRisk -or $Force)
            # 원장이 "등록됨"만 기억하면, deny 목록이 지켜지는지는 아무도 모른다.
            tool_policy_enforceable = [bool]($rd.tool_policy_support -and $rd.tool_policy_support.deny)
            status        = $r.status
            recorded_at   = (Get-HarnessUtcStamp)
        }
    }
}
$registry.registrations = @($keep)
Write-HarnessClientRegistry -ToolsRoot $tools -Registry $registry

$results
if (@($results | Where-Object { $_.status -in @('failed', 'unknown') }).Count -gt 0) { exit 1 }
exit 0
