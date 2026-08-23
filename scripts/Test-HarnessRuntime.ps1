#Requires -Version 5.1
<#
    AI Harness — 공용 런타임 검증

    state = "verified" 를 쓸 수 있는 유일한 스크립트다.
    파일 존재나 exit code 가 아니라 실제 read-only 호출 결과로 판정한다.

    이유: 서버의 자체 진단 도구는 문제 상황도 "성공한 도구 호출"로 반환할 수 있다.
    실제로 get_status 가 [ERROR] ... 를 isError:false 로 돌려주는 것을 관측했다.
    그래서 매니페스트의 verify.tool 로 진짜 API 를 호출하고,
    assert_contains 로 응답 내용까지 확인한다.

    사용:
        .\Test-HarnessRuntime.ps1 -RuntimeId google-workspace
        .\Test-HarnessRuntime.ps1 -All

    종료 코드: 0 검증 성공 / 1 검증 실패 / 4 런타임 없음
#>
[CmdletBinding()]
param(
    [string]$RuntimeId,
    [switch]$All,
    [string]$ToolsRoot,
    [string]$HarnessRoot,
    [int]$TimeoutMs = 90000,
    [switch]$TransportOnly,
    [switch]$Json
)

if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Runtime.ps1')
Initialize-HarnessConsole

if (-not $RuntimeId -and -not $All) { throw '-RuntimeId 또는 -All 중 하나가 필요합니다.' }

$root = (Resolve-Path -LiteralPath $HarnessRoot).Path
$tools = Get-HarnessToolsRoot -Override $ToolsRoot
$probeSource = Join-HarnessPath $PSScriptRoot 'harness-mcp-probe.mjs'
if (-not (Test-Path -LiteralPath $probeSource)) { throw "프로브 원본이 없습니다: $probeSource" }

function Test-One {
    param([string]$Id)

    $manifest = Get-HarnessRuntimeManifest -HarnessRoot $root -RuntimeId $Id
    $index = Read-HarnessRuntimeIndex -ToolsRoot $tools
    $entry = Get-HarnessIndexEntry -Index $index -RuntimeId $Id
    if (-not $entry) {
        return [pscustomobject]@{ runtime_id = $Id; verified = $false; stage = 'absent'; error = '인덱스에 없습니다. 먼저 설치하세요.' }
    }

    $command = Join-HarnessPath $tools $entry.command_rel
    if (-not (Test-Path -LiteralPath $command)) {
        return [pscustomobject]@{ runtime_id = $Id; verified = $false; stage = 'command_missing'; error = $command }
    }

    # 프로브를 런타임 디렉터리로 복사한다.
    # ESM 의 bare specifier 는 importing 파일 위치를 기준으로 해석되므로,
    # 그 런타임의 node_modules 안에서 실행돼야 SDK 가 잡힌다.
    $installAbs = Join-HarnessPath $tools $entry.install_dir
    $probeDest = Join-HarnessPath $installAbs '.harness-mcp-probe.mjs'
    Copy-Item -LiteralPath $probeSource -Destination $probeDest -Force

    $envMap = @{}
    if ($entry.env) { foreach ($p in $entry.env.PSObject.Properties) { $envMap[$p.Name] = [string]$p.Value } }

    $nodeExe = Get-HarnessNativeCommand 'node'
    $cfgPath = Join-HarnessPath $installAbs '.harness-probe-config.json'

    function Invoke-Probe {
        param($Tool, $ToolArgs)
        $cfg = [ordered]@{
            command = $command; args = @($entry.args); env = $envMap
            tool = $Tool; toolArgs = $(if ($ToolArgs) { $ToolArgs } else { @{} }); timeoutMs = $TimeoutMs
        }
        Write-HarnessJson -Path $cfgPath -InputObject $cfg -Depth 8
        $o = Join-HarnessPath $env:TEMP "harness-probe-$Id.out"
        $e = Join-HarnessPath $env:TEMP "harness-probe-$Id.err"
        $p = Start-Process -FilePath $nodeExe -ArgumentList @($probeDest, $cfgPath) `
            -NoNewWindow -Wait -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
        $so = if (Test-Path $o) { Read-HarnessText -Path $o } else { '' }
        $se = if (Test-Path $e) { Read-HarnessText -Path $e } else { '' }
        Remove-Item -LiteralPath $o, $e -Force -ErrorAction SilentlyContinue
        $parsed = $null
        try { $parsed = $so | ConvertFrom-Json } catch { }
        if (-not $parsed) { $parsed = [pscustomobject]@{ ok = $false; stage = 'probe_unparseable'; error = (("$se" -split "`r?`n")[0]) } }
        return $parsed
    }

    # ── 1단계: 전송 검증 (인증 불필요) ─────────────────────────────────────
    # 경로·인코딩·spawn·런타임이 정상인지 여기서 판정된다.
    # 신규 PC 에는 OAuth 토큰이 없으므로 이 단계만이 항상 실행 가능하다.
    $transport = Invoke-Probe -Tool $null -ToolArgs $null
    $transportOk = [bool]$transport.ok -and ($transport.tool_count -gt 0)

    # ── 2단계: 인증 검증 (자격증명이 있을 때만) ────────────────────────────
    $authState = 'not_attempted'
    $authProbe = $null
    $assert = if ($manifest.verify) { $manifest.verify.assert_contains } else { $null }
    $verifyTool = if ($manifest.verify) { $manifest.verify.tool } else { $null }

    $credsPresent = $true
    if ($manifest.credentials -and $manifest.credentials.storage) {
        $params = Get-HarnessRuntimeParameters -Manifest $manifest
        if ($entry.parameters) { foreach ($p in $entry.parameters.PSObject.Properties) { $params[$p.Name] = $p.Value } }
        $ctx = New-HarnessInterpolationContext -ToolsRoot $tools -RuntimeDir $installAbs -Parameters $params
        $store = (Resolve-HarnessInterpolation -Value $manifest.credentials.storage -Context $ctx).Replace('/', [string][IO.Path]::DirectorySeparatorChar)
        foreach ($n in (@($manifest.credentials.required_files) + @($manifest.credentials.auth_state_files))) {
            if (-not (Test-Path -LiteralPath (Join-HarnessPath $store $n))) { $credsPresent = $false }
        }
    }

    if ($transportOk -and $verifyTool -and -not $TransportOnly) {
        if (-not $credsPresent) {
            $authState = 'not_authorized'
        } else {
            $authProbe = Invoke-Probe -Tool $verifyTool -ToolArgs $(if ($manifest.verify.args) { $manifest.verify.args } else { @{} })
            $authOk = [bool]$authProbe.ok
            if ($authOk -and $assert -and -not ("$($authProbe.text)" -like "*$assert*")) { $authOk = $false }
            $authState = if ($authOk) { 'authorized' } else { 'auth_failed' }
        }
    }

    Remove-Item -LiteralPath $cfgPath, $probeDest -Force -ErrorAction SilentlyContinue

    # ── 상태 판정 ─────────────────────────────────────────────────────────
    #   installed  : 설치만 됨
    #   reachable  : 실제로 뜨고 도구를 노출함 (인증 여부와 무관)
    #   verified   : 실제 인증된 API 호출까지 성공
    $newState = if ($authState -eq 'authorized') { 'verified' }
                elseif ($transportOk) { 'reachable' }
                else { 'installed' }

    $entry.state = $newState
    $entry.last_verify_evidence = [pscustomobject]@{
        transport_ok = $transportOk
        tool_count   = $transport.tool_count
        auth_state   = $authState
        tool         = $verifyTool
        assert       = $assert
        at           = (Get-HarnessUtcStamp)
    }
    $entry.last_verified_at = if ($newState -eq 'verified') { Get-HarnessUtcStamp } else { $null }
    Set-HarnessIndexEntry -Index $index -RuntimeId $Id -Entry $entry
    Write-HarnessRuntimeIndex -ToolsRoot $tools -Index $index

    $hint = switch ($authState) {
        'not_authorized' { "설치·연결은 정상입니다. 아직 인증되지 않았습니다 -> $($manifest.credentials.setup_guide)" }
        'auth_failed'    { '연결은 되지만 인증 호출이 실패했습니다. 토큰이 만료·폐기됐을 수 있습니다.' }
        'authorized'     { $null }
        default          { $(if (-not $transportOk) { '서버가 뜨지 않습니다. 경로·Node 버전·설치 상태를 확인하세요.' } else { $null }) }
    }

    return [pscustomobject]@{
        runtime_id   = $Id
        state        = $newState
        transport_ok = $transportOk
        tool_count   = $transport.tool_count
        auth_state   = $authState
        verified     = ($newState -eq 'verified')
        excerpt      = $(if ($authProbe -and $authProbe.text) { ("$($authProbe.text)" -split "`n")[0] } else { $null })
        error        = $(if (-not $transportOk) { $transport.error } elseif ($authProbe) { $authProbe.error } else { $null })
        next         = $hint
    }
}

$ids = if ($All) { Get-HarnessRuntimeIds -HarnessRoot $root } else { @($RuntimeId) }
$results = @()
foreach ($id in $ids) { $results += Test-One -Id $id }

if ($Json) { $results | ConvertTo-Json -Depth 8 } else { $results }

# 종료 코드는 "설치가 깨졌는가"와 "아직 인증 안 됐는가"를 구분한다.
# 신규 PC 에서 인증 전 상태를 실패로 보고하면, 사용자는 멀쩡한 설치를 다시 지운다.
if (@($results | Where-Object { $_.state -eq 'absent' }).Count -eq $results.Count) { exit 4 }
if (@($results | Where-Object { -not $_.transport_ok }).Count -gt 0) { exit 1 }   # 진짜 실패
if (@($results | Where-Object { $_.auth_state -in @('not_authorized', 'auth_failed') }).Count -gt 0) { exit 2 }  # 연결됨, 인증 필요
exit 0
