#Requires -Version 5.1
<#
    AI Harness — 공용 런타임 해석 (읽기 전용)

    이 스크립트는 아무것도 설치하지 않고 아무것도 등록하지 않는다.
    PROJECT_INIT 의 fast health check 와 Doctor 가 호출하며, 둘 다 계약상 읽기 전용이다.
    "없으면 설치" 는 별도 동사(Install-HarnessRuntime)가 담당한다.

    사용:
        .\Resolve-HarnessRuntime.ps1 -RuntimeId google-workspace
        .\Resolve-HarnessRuntime.ps1 -All -Json

    종료 코드:
        0  발견, drift 없음
        2  발견, 비긴급 drift (매니페스트 문서 변경 등)
        3  발견, 조치 필요 drift (버전 불일치, command 없음, 레거시 루트)
        4  없음 (오류가 아니다)
        5  tools root / 인덱스를 읽을 수 없음
        1  스크립트 오류
#>
[CmdletBinding()]
param(
    [string]$RuntimeId,
    [switch]$All,
    [string]$ToolsRoot,
    [string]$HarnessRoot,
    [switch]$Json
)

if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Runtime.ps1')

if (-not $RuntimeId -and -not $All) { throw '-RuntimeId 또는 -All 중 하나가 필요합니다.' }

$root = (Resolve-Path -LiteralPath $HarnessRoot).Path
$tools = Get-HarnessToolsRoot -Override $ToolsRoot

$legacyRoots = @('C:\AI-Tools')

function Resolve-One {
    param([string]$Id)

    $result = [ordered]@{
        schema_version     = '2.0'
        runtime_id         = $Id
        found              = $false
        tools_root         = $tools
        command            = $null
        args               = @()
        env                = [ordered]@{}
        declared_version   = $null
        installed_version  = $null
        version_match      = $null
        auth_files_present = $false
        authenticated      = 'unknown'
        state              = 'absent'
        last_verified_at   = $null
        drift              = @()
    }

    # Layer A — 선언
    $manifest = Get-HarnessRuntimeManifest -HarnessRoot $root -RuntimeId $Id
    $result.declared_version = $manifest.install.version

    # Layer B — 실체
    $index = Read-HarnessRuntimeIndex -ToolsRoot $tools
    $entry = Get-HarnessIndexEntry -Index $index -RuntimeId $Id
    if (-not $entry) {
        $result.drift = @('absent')
        return [pscustomobject]$result
    }

    $result.found = $true
    $result.state = $entry.state
    $result.installed_version = $entry.installed_version
    $result.last_verified_at = $entry.last_verified_at
    $result.args = @($entry.args)
    $result.env = $entry.env

    $drift = New-Object System.Collections.Generic.List[string]

    # command 는 tools root 상대경로로 저장한다. 루트가 옮겨져도 해석된다.
    $command = Join-HarnessPath $tools $entry.command_rel
    $result.command = $command
    if (-not (Test-Path -LiteralPath $command)) { $drift.Add('command_missing') }

    foreach ($lr in $legacyRoots) {
        if ($tools.StartsWith($lr, [StringComparison]::OrdinalIgnoreCase)) { $drift.Add('legacy_tools_root'); break }
    }

    # 선언 버전과 실제 설치 버전 비교
    $result.version_match = ($entry.installed_version -eq $manifest.install.version)
    if (-not $result.version_match) { $drift.Add('version_drift') }

    # 실제 node_modules 의 package.json 을 읽어 인덱스 기록이 사실인지 확인한다.
    if ($entry.install_dir) {
        $pkg = Join-HarnessPath $tools $entry.install_dir 'node_modules' $manifest.install.package 'package.json'
        if (Test-Path -LiteralPath $pkg) {
            $onDisk = (Read-HarnessJson -Path $pkg).version
            if ($onDisk -ne $entry.installed_version) {
                $drift.Add('index_stale')
                $result.installed_version = $onDisk
            }
        }
    }

    # 자격증명 — 존재 여부만 본다. 존재는 인증이 아니다.
    $params = Get-HarnessRuntimeParameters -Manifest $manifest
    if ($entry.parameters) {
        foreach ($p in $entry.parameters.PSObject.Properties) { $params[$p.Name] = $p.Value }
    }
    if ($manifest.credentials -and $manifest.credentials.storage) {
        $ctx = New-HarnessInterpolationContext -ToolsRoot $tools -RuntimeDir (Join-HarnessPath $tools $entry.install_dir) -Parameters $params
        $store = Resolve-HarnessInterpolation -Value $manifest.credentials.storage -Context $ctx
        $store = $store.Replace('/', [string][IO.Path]::DirectorySeparatorChar)
        $need = @($manifest.credentials.required_files) + @($manifest.credentials.auth_state_files)
        $present = $true
        foreach ($n in $need) {
            if (-not (Test-Path -LiteralPath (Join-HarnessPath $store $n))) { $present = $false }
        }
        $result.auth_files_present = $present
    }

    # verified 는 TTL 이 지나면 감쇠한다. 몇 달 전 검증이 영원히 유효한 척하지 않는다.
    if ($entry.state -eq 'verified' -and $entry.last_verified_at) {
        $ttl = if ($entry.verify_ttl_hours) { [int]$entry.verify_ttl_hours } else { 168 }
        $age = ([DateTimeOffset]::UtcNow - [DateTimeOffset]::Parse($entry.last_verified_at)).TotalHours
        if ($age -gt $ttl) {
            $result.state = 'stale_verified'
            $drift.Add('verify_expired')
        }
    }

    $result.drift = @($drift)
    return [pscustomobject]$result
}

$ids = if ($All) { Get-HarnessRuntimeIds -HarnessRoot $root } else { @($RuntimeId) }
$results = @()
foreach ($id in $ids) { $results += Resolve-One -Id $id }

if ($Json) {
    if ($All) { $results | ConvertTo-Json -Depth 8 } else { $results[0] | ConvertTo-Json -Depth 8 }
} else {
    $results
}

# 종료 코드는 가장 심각한 상태를 따른다.
$exit = 0
foreach ($r in $results) {
    if (-not $r.found) { if ($exit -lt 4) { $exit = 4 }; continue }
    if ($r.drift -contains 'command_missing' -or $r.drift -contains 'version_drift' -or
        $r.drift -contains 'legacy_tools_root' -or $r.drift -contains 'index_stale') {
        if ($exit -lt 3) { $exit = 3 }
    } elseif ($r.drift.Count -gt 0) {
        if ($exit -lt 2) { $exit = 2 }
    }
}
exit $exit
