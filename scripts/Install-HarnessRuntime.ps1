#Requires -Version 5.1
<#
    AI Harness — 공용 런타임 설치 (PC 당 1회)

    Layer B 에 실체를 만들고 runtimes.json 에 기록한다.
    이 스크립트는 절대로 state=verified 를 쓰지 않는다. 설치와 검증은 다른 사건이다.

    사용:
        .\Install-HarnessRuntime.ps1 -RuntimeId google-workspace
        .\Install-HarnessRuntime.ps1 -RuntimeId google-workspace -Adopt      # 기존 설치를 재다운로드 없이 채택
        .\Install-HarnessRuntime.ps1 -RuntimeId google-workspace -EnsureOnly # 이미 있으면 아무것도 하지 않음

    설치 경로는 <tools_root>/<runtime_id>/<version> 이다.
    버전별로 분리해야 롤백이 재다운로드 없이 포인터 전환으로 끝난다.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string]$RuntimeId,
    [string]$ToolsRoot,
    [string]$HarnessRoot,
    [switch]$Adopt,
    [switch]$EnsureOnly,
    [switch]$Reinstall,
    [switch]$AllowUnverifiedPlatform
)

if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Runtime.ps1')
Initialize-HarnessConsole

$root = (Resolve-Path -LiteralPath $HarnessRoot).Path
$tools = Get-HarnessToolsRoot -Override $ToolsRoot
$manifest = Get-HarnessRuntimeManifest -HarnessRoot $root -RuntimeId $RuntimeId

# --- 플랫폼 정직성 ---------------------------------------------------------
# 검증한 플랫폼만 선언한다. 다만 증거를 만들 방법이 없으면 영구 차단이 되므로
# 명시적 스위치로 시도할 수 있게 하고 결과를 기록한다.
$platform = if ($script:HarnessIsWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } else { 'linux' }
if (@($manifest.platforms) -notcontains $platform -and -not $AllowUnverifiedPlatform) {
    throw ("이 런타임은 $($manifest.platforms -join ', ') 에서만 검증됐습니다 (현재: $platform).`n" +
           '시도하려면 -AllowUnverifiedPlatform 을 사용하고, 성공하면 매니페스트의 platforms 와 platforms_verified_on 을 갱신하세요.')
}

# --- 사전 조건 -------------------------------------------------------------
$nodeExe = Get-HarnessNativeCommand 'node'
$npmExe = Get-HarnessNativeCommand 'npm'
if (-not $nodeExe) { throw 'Node.js 가 필요합니다.' }
if (-not $npmExe) { throw 'npm 이 필요합니다.' }
# npm 은 .ps1 로 해석되면 Restricted 정책에서 PSSecurityException 으로 죽는다. .cmd 를 쓴다.
if ($npmExe.EndsWith('.ps1', [StringComparison]::OrdinalIgnoreCase)) {
    Write-Warning "npm 이 .ps1 로만 해석됩니다($npmExe). ExecutionPolicy 가 제한적이면 실패할 수 있습니다."
}
$nodeMajor = [int]((& $nodeExe --version).TrimStart('v').Split('.')[0])
if ($nodeMajor -lt 22) { throw "Node.js 22 이상이 필요합니다. 현재 major: $nodeMajor" }

if ($manifest.install.kind -ne 'npm_pinned') { throw "지원하지 않는 install.kind: $($manifest.install.kind)" }
$version = [string]$manifest.install.version
if ($version -eq 'latest' -or $version -match '[\*\^~]') {
    throw "버전은 정확해야 합니다. latest / 와일드카드 / caret / tilde 는 허용되지 않습니다: $version"
}

$pathTrust = Test-HarnessPathTrust -Path (Split-Path -Parent $tools)
if ($pathTrust.checked -and -not $pathTrust.trusted) {
    Write-Warning "도구 루트의 상위 경로에 다른 주체의 쓰기 권한이 있습니다: $($pathTrust.offenders -join '; ')"
}

$index = Read-HarnessRuntimeIndex -ToolsRoot $tools
$existing = Get-HarnessIndexEntry -Index $index -RuntimeId $RuntimeId
if ($existing -and $EnsureOnly -and -not $Reinstall) {
    Write-Output "이미 등록되어 있습니다: $RuntimeId ($($existing.installed_version)). 아무것도 하지 않습니다."
    return
}

$params = Get-HarnessRuntimeParameters -Manifest $manifest
$installDirRel = Join-HarnessPath $RuntimeId $version
$installDirAbs = Join-HarnessPath $tools $installDirRel
$binName = $manifest.install.bin_name
$binRelWin = Join-HarnessPath $installDirRel 'node_modules' '.bin' "$binName.cmd"
$binRelNix = Join-HarnessPath $installDirRel 'node_modules' '.bin' $binName
$commandRel = if ($script:HarnessIsWindows) { $binRelWin } else { $binRelNix }

# --- 기존 설치 채택 --------------------------------------------------------
# 마이그레이션은 runtime_id 가 아니라 실제 디렉터리 이름으로 탐색해야 한다.
# 옛 매니페스트의 runtime_subdirectory 가 runtime_id 와 다른 경우가 실제로 있었다.
$adopted = $null
if ($Adopt -and -not $Reinstall) {
    $candidates = @()
    $candidates += $installDirRel
    foreach ($legacy in @($manifest.legacy_install_dirs)) { if ($legacy) { $candidates += $legacy } }
    $candidates += $RuntimeId

    foreach ($cand in ($candidates | Select-Object -Unique)) {
        $pkgJson = Join-HarnessPath $tools $cand 'node_modules' $manifest.install.package 'package.json'
        if (-not (Test-Path -LiteralPath $pkgJson)) { continue }
        $onDisk = (Read-HarnessJson -Path $pkgJson).version
        $binWin = Join-HarnessPath $tools $cand 'node_modules' '.bin' "$binName.cmd"
        $binNix = Join-HarnessPath $tools $cand 'node_modules' '.bin' $binName
        $bin = if (Test-Path -LiteralPath $binWin) { $binWin } elseif (Test-Path -LiteralPath $binNix) { $binNix } else { $null }
        if (-not $bin) { continue }
        $adopted = [pscustomobject]@{
            install_dir = $cand
            version     = $onDisk
            command_rel = $bin.Substring($tools.Length).TrimStart([char]'\', [char]'/')
        }
        break
    }
    if ($adopted) {
        Write-Output "기존 설치를 채택합니다: $($adopted.install_dir) (v$($adopted.version)) — 재다운로드 없음"
        $installDirRel = $adopted.install_dir
        $commandRel = $adopted.command_rel
    }
}

# --- 설치 -----------------------------------------------------------------
if (-not $adopted) {
    $needInstall = $Reinstall -or -not (Test-Path -LiteralPath (Join-HarnessPath $tools $commandRel))
    if ($needInstall) {
        $spec = "$($manifest.install.package)@$version"
        if (-not $PSCmdlet.ShouldProcess($installDirAbs, "npm install $spec")) { return }

        New-Item -ItemType Directory -Force -Path $installDirAbs | Out-Null
        Write-HarnessJson -Path (Join-HarnessPath $installDirAbs 'package.json') -Depth 4 -InputObject @{
            name         = "harness-runtime-$RuntimeId"
            private      = $true
            version      = '1.0.0'
            dependencies = @{ "$($manifest.install.package)" = $version }
        }
        $npmArgs = @('install') + @($manifest.install.npm_args)
        Push-Location -LiteralPath $installDirAbs
        try { & $npmExe @npmArgs } finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) { throw "npm install 실패 (exit $LASTEXITCODE)" }

        # New-Item 은 MAX_PATH 를 넘는 경로에서도 예외 없이 성공한 것처럼 보인다.
        # 실제로 만들어졌는지 반드시 확인한다.
        if (-not (Test-Path -LiteralPath (Join-HarnessPath $installDirAbs 'node_modules'))) {
            throw ("npm install 후 node_modules 를 찾을 수 없습니다: $installDirAbs`n" +
                   '경로가 너무 길거나(MAX_PATH) 디스크/권한 문제일 수 있습니다.')
        }
    }
}

$commandAbs = Join-HarnessPath $tools $commandRel
if (-not (Test-Path -LiteralPath $commandAbs)) { throw "설치 후에도 실행 파일을 찾을 수 없습니다: $commandAbs" }

$pkgJsonFinal = Join-HarnessPath $tools $installDirRel 'node_modules' $manifest.install.package 'package.json'
$installedVersion = if (Test-Path -LiteralPath $pkgJsonFinal) { (Read-HarnessJson -Path $pkgJsonFinal).version } else { $null }

# --- 인덱스 기록 -----------------------------------------------------------
$ctx = New-HarnessInterpolationContext -ToolsRoot $tools -RuntimeDir (Join-HarnessPath $tools $installDirRel) -Parameters $params
$serverEnv = Resolve-HarnessServerEnv -Manifest $manifest -Context $ctx

$entry = [pscustomobject]@{
    runtime_id        = $RuntimeId
    capability_id     = $manifest.capability_id
    server_name       = $manifest.server_name
    package           = $manifest.install.package
    declared_version  = $version
    installed_version = $installedVersion
    install_dir       = ($installDirRel -replace '\\', '/')
    command_rel       = ($commandRel -replace '\\', '/')
    args              = @($manifest.server.args)
    env               = $serverEnv
    parameters        = [pscustomobject]$params
    platform          = $platform
    risk              = $manifest.risk
    state             = 'installed'
    installed_at      = (Get-HarnessUtcStamp)
    last_verified_at  = $null
    verify_ttl_hours  = 168
    last_verify_evidence = $null
    adopted_from      = $(if ($adopted) { $adopted.install_dir } else { $null })
}
Set-HarnessIndexEntry -Index $index -RuntimeId $RuntimeId -Entry $entry
Write-HarnessRuntimeIndex -ToolsRoot $tools -Index $index

[pscustomobject]@{
    runtime_id        = $RuntimeId
    command           = $commandAbs
    installed_version = $installedVersion
    declared_version  = $version
    state             = 'installed'
    note              = "installed 는 '설치됨' 일 뿐입니다. 실제 호출까지 확인해야 verified 입니다. Test-HarnessRuntime.ps1 을 실행하세요."
}
