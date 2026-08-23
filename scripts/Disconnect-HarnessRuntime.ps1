#Requires -Version 5.1
<#
    AI Harness — 공용 런타임 연결 해제

    순서가 중요하다. 이 순서가 아니면 조용히 살아 있는 것이 남는다.

      1. Google 권한 취소   토큰을 먼저 지우면 취소할 수단이 사라진다.
                            토큰 파일 삭제는 "이 PC 가 잊는 것"이지 "끊는 것"이 아니다.
                            부여(grant)는 Google 쪽에 그대로 남는다.
      2. 토큰 삭제
      3. 클라이언트 등록 제거  등록이 남아 있으면 CLI 는 계속 서버를 띄우려 하고
                            사용자는 "인증 오류"만 보게 된다.
      4. 인덱스 state 되돌림   verified 는 실제 호출로 증명된 것이었다. 이제 거짓이다.

    설치 자체는 지우지 않는다(재로그인만 하면 다시 쓸 수 있다).
    설치까지 지우려면 도구 루트의 런타임 디렉터리를 사람이 직접 삭제한다.

    사용:
        .\Disconnect-HarnessRuntime.ps1 -RuntimeId google-workspace -DryRun
        .\Disconnect-HarnessRuntime.ps1 -RuntimeId google-workspace
        .\Disconnect-HarnessRuntime.ps1 -RuntimeId google-workspace -RemoveCredentials

    종료 코드: 0 성공 / 1 일부 실패 / 2 사용자 취소 / 3 사전 조건 미충족
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RuntimeId,
    [string]$ProfileName,
    [string]$ToolsRoot,
    [string]$HarnessRoot,
    [switch]$RemoveCredentials,
    [switch]$KeepRegistrations,
    [switch]$ForceWithoutRevoke,
    [switch]$DryRun,
    [switch]$Yes
)

if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Runtime.ps1')
Initialize-HarnessConsole

$root = (Resolve-Path -LiteralPath $HarnessRoot).Path
$tools = Get-HarnessToolsRoot -Override $ToolsRoot
$manifest = Get-HarnessRuntimeManifest -HarnessRoot $root -RuntimeId $RuntimeId
$index = Read-HarnessRuntimeIndex -ToolsRoot $tools
$entry = Get-HarnessIndexEntry -Index $index -RuntimeId $RuntimeId
$ledger = Read-HarnessClientRegistry -ToolsRoot $tools

$params = Get-HarnessRuntimeParameters -Manifest $manifest
if ($ProfileName) { $params['profile'] = $ProfileName }
elseif ($entry -and $entry.PSObject.Properties.Name -contains 'auth_profile' -and $entry.auth_profile) {
    $params['profile'] = $entry.auth_profile
}
$profileValue = [string]$params['profile']

$runtimeDir = if ($entry) { Join-HarnessPath $tools $entry.install_dir } else { Join-HarnessPath $tools $RuntimeId }
$ctx = New-HarnessInterpolationContext -ToolsRoot $tools -RuntimeDir $runtimeDir -Parameters $params
$store = $null
if ($manifest.credentials -and $manifest.credentials.storage) {
    $store = (Resolve-HarnessInterpolation -Value $manifest.credentials.storage -Context $ctx).Replace('/', [string][IO.Path]::DirectorySeparatorChar)
}

# ---------------------------------------------------------------------------
# 무엇을 할지 확정한다
# ---------------------------------------------------------------------------

$tokenFiles = @()
if ($store) {
    foreach ($n in @($manifest.credentials.auth_state_files)) {
        $p = Join-HarnessPath $store $n
        if (Test-Path -LiteralPath $p) { $tokenFiles += $p }
    }
}
$credFiles = @()
if ($store -and $RemoveCredentials) {
    foreach ($n in @($manifest.credentials.required_files)) {
        $p = Join-HarnessPath $store $n
        if (Test-Path -LiteralPath $p) { $credFiles += $p }
    }
}

$revoke = $null
if ($manifest.credentials -and $manifest.credentials.revoke) { $revoke = $manifest.credentials.revoke }

$registered = @()
if (-not $KeepRegistrations) {
    foreach ($cid in (Get-HarnessClientIds -HarnessRoot $root)) {
        $d = $null
        try { $d = Get-HarnessClientDescriptor -HarnessRoot $root -ClientId $cid } catch { continue }
        if (-not (Get-HarnessNativeCommand $d.detect.command)) { continue }
        $reg = Read-HarnessClientRegistration -Descriptor $d -ServerName $manifest.server_name
        if (-not $reg.present) { continue }
        $scope = if ($d.supports.default_scope) { $d.supports.default_scope } else { '' }
        $rmArgv = Expand-HarnessArgv -Template @($d.argv.remove) -Values @{ server_name = $manifest.server_name; scope = $scope }
        $registered += [pscustomobject]@{
            client = $cid; descriptor = $d
            exe = (Get-HarnessNativeCommand $d.detect.command)
            arguments = @($rmArgv)
            command_line = "$($d.detect.command) $($rmArgv -join ' ')"
        }
    }
}

Write-Output ''
Write-Output "연결 해제 계획 — $($manifest.display_name)"
Write-Output "  런타임 : $RuntimeId"
Write-Output "  프로필 : $profileValue"
Write-Output "  저장소 : $store"
Write-Output ''
Write-Output '  1. Google 권한 취소'
if ($revoke) {
    $tokenPath = Join-HarnessPath $store $revoke.token_file
    if (Test-Path -LiteralPath $tokenPath) {
        Write-Output "       POST $($revoke.endpoint)  ($($revoke.token_file) 의 $($revoke.token_field))"
        Write-Output '       부여(grant) 전체가 취소됩니다. 다시 쓰려면 재로그인해야 합니다.'
    } else {
        Write-Output "       건너뜀 — 토큰 파일이 없습니다 ($tokenPath)"
    }
    Write-Output "       실패 시 직접 취소: $($revoke.manual_url)"
} else {
    Write-Output '       매니페스트에 취소 방법이 선언되어 있지 않습니다. 자동으로 취소할 수 없습니다.'
}
Write-Output '  2. 토큰 삭제'
if ($tokenFiles.Count) { foreach ($f in $tokenFiles) { Write-Output "       $f" } } else { Write-Output '       (없음)' }
Write-Output '  3. 클라이언트 등록 제거'
if ($KeepRegistrations) { Write-Output '       건너뜀 (-KeepRegistrations)' }
elseif ($registered.Count) { foreach ($r in $registered) { Write-Output "       $($r.command_line)" } }
else { Write-Output '       (등록 없음)' }
Write-Output '  4. 인덱스 state 되돌림'
Write-Output ("       {0} -> installed, last_verified_at / evidence 초기화" -f $(if ($entry) { $entry.state } else { '(없음)' }))
if ($credFiles.Count) {
    Write-Output '  5. 자격증명 삭제 (-RemoveCredentials)'
    foreach ($f in $credFiles) { Write-Output "       $f" }
    Write-Output '       다시 쓰려면 Google Cloud 콘솔에서 OAuth 클라이언트를 다시 받아야 합니다.'
}
Write-Output ''
Write-Output '설치 자체는 지우지 않습니다. 재로그인만 하면 다시 쓸 수 있습니다.'
Write-Output ''

if ($DryRun) { Write-Output '-DryRun 이므로 여기서 멈춥니다. 아무것도 적용되지 않았습니다.'; exit 0 }
if (-not $Yes) {
    if (-not [Environment]::UserInteractive) { Write-Output '비대화형 세션입니다. -Yes 를 명시하세요.'; exit 2 }
    $ans = Read-Host '진행하려면 DISCONNECT 를 입력하세요'
    if ($ans -ne 'DISCONNECT') { Write-Output '취소했습니다.'; exit 2 }
}

# ---------------------------------------------------------------------------
# 1. 권한 취소
# ---------------------------------------------------------------------------

$failures = 0
$revoked = $false
if ($revoke -and $revoke.kind -eq 'oauth2_http') {
    $tokenPath = Join-HarnessPath $store $revoke.token_file
    if (Test-Path -LiteralPath $tokenPath) {
        try {
            # PS 5.1 의 기본 SecurityProtocol 은 TLS 1.0 을 포함한다. Google 은 거부한다.
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $tok = Read-HarnessJson -Path $tokenPath
            $value = $tok.($revoke.token_field)
            if (-not $value) { throw "$($revoke.token_file) 에 $($revoke.token_field) 가 없습니다." }
            Invoke-RestMethod -Method Post -Uri $revoke.endpoint -Body @{ token = $value } `
                -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 30 | Out-Null
            $revoked = $true
            Write-Output '권한 취소 완료.'
        } catch {
            Write-Warning "권한 취소에 실패했습니다: $($_.Exception.Message)"
            Write-Output "  직접 취소하세요: $($revoke.manual_url)"
            if (-not $ForceWithoutRevoke) {
                Write-Output ''
                Write-Output '토큰을 지우면 취소할 수단이 없어지므로 여기서 멈춥니다.'
                Write-Output "위 URL 에서 직접 취소한 뒤 -ForceWithoutRevoke 를 붙여 다시 실행하세요."
                exit 1
            }
            Write-Output '  -ForceWithoutRevoke 가 지정되어 계속 진행합니다.'
        }
    } else {
        Write-Output '토큰 파일이 없어 취소를 건너뜁니다.'
    }
} elseif (-not $ForceWithoutRevoke -and $tokenFiles.Count) {
    Write-Output '자동 취소 방법이 선언되어 있지 않습니다.'
    Write-Output '토큰만 지우면 Google 쪽 부여는 살아남습니다. 직접 취소한 뒤 -ForceWithoutRevoke 로 다시 실행하세요.'
    exit 3
}

# ---------------------------------------------------------------------------
# 2. 토큰 삭제
# ---------------------------------------------------------------------------

foreach ($f in $tokenFiles) {
    try { Remove-Item -LiteralPath $f -Force -Confirm:$false; Write-Output "삭제: $f" }
    catch { Write-Warning "삭제 실패: $f — $($_.Exception.Message)"; $failures++ }
}
foreach ($f in $credFiles) {
    try { Remove-Item -LiteralPath $f -Force -Confirm:$false; Write-Output "삭제: $f" }
    catch { Write-Warning "삭제 실패: $f — $($_.Exception.Message)"; $failures++ }
}

# ---------------------------------------------------------------------------
# 3. 클라이언트 등록 제거 — 실행했다가 아니라 사라졌음을 확인한다
# ---------------------------------------------------------------------------

$removedClients = @()
foreach ($r in $registered) {
    $res = Invoke-HarnessClientCommand -Exe $r.exe -Arguments $r.arguments
    $after = Read-HarnessClientRegistration -Descriptor $r.descriptor -ServerName $manifest.server_name
    if ($after.present) {
        Write-Warning "등록이 남아 있습니다: $($r.client) — $(($res.text -split "`r?`n" | Select-Object -First 2) -join ' ')"
        $failures++
    } else {
        Write-Output "등록 제거: $($r.client)"
        $removedClients += $r.client
    }
}
if ($removedClients.Count) {
    $keep = @($ledger.registrations | Where-Object { -not ($_.runtime_id -eq $RuntimeId -and $removedClients -contains $_.client) })
    $ledger.registrations = @($keep)
    Write-HarnessClientRegistry -ToolsRoot $tools -Registry $ledger
}

# ---------------------------------------------------------------------------
# 4. 인덱스 state 되돌림
# ---------------------------------------------------------------------------

if ($entry) {
    $entry.state = 'installed'
    $entry.last_verified_at = $null
    $entry.last_verify_evidence = $null
    $entry | Add-Member -NotePropertyName disconnected_at -NotePropertyValue (Get-HarnessUtcStamp) -Force
    $entry | Add-Member -NotePropertyName revoked -NotePropertyValue $revoked -Force
    Set-HarnessIndexEntry -Index $index -RuntimeId $RuntimeId -Entry $entry
    Write-HarnessRuntimeIndex -ToolsRoot $tools -Index $index
    Write-Output "인덱스: state=installed 로 되돌림 (revoked=$revoked)"
}

Write-Output ''
if (-not $revoked -and $tokenFiles.Count) {
    Write-Output "주의: Google 쪽 부여가 취소되지 않았습니다. 직접 확인하세요: $($revoke.manual_url)"
}
Write-Output '등록을 바꿨으므로 해당 CLI 를 재시작해야 반영됩니다.'
if ($failures) { Write-Output "일부 단계가 실패했습니다 ($failures 건). 위 경고를 확인하세요."; exit 1 }
Write-Output '연결 해제 완료.'
exit 0
