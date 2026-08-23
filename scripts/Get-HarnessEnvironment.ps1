#Requires -Version 5.1
<#
    AI Harness — 설치 전 환경 진단 (읽기 전용)

    이 스크립트는 아무것도 바꾸지 않는다.
    이 PC 가 어떤 환경인지 확인하고, 그에 맞는 설정안을 제시한다.
    실제 적용은 Install-Harness.ps1 이 하며, 사용자 확인을 거친다.

    사용:
        .\Get-HarnessEnvironment.ps1
        .\Get-HarnessEnvironment.ps1 -Json > env.json

    종료 코드: 0 진행 가능 / 2 제한적으로 가능 / 3 차단 요소 있음
#>
[CmdletBinding()]
param(
    [string]$HarnessRoot,
    [string]$ToolsRoot,
    [switch]$Json,
    [switch]$Detailed
)

if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '_Harness.Runtime.ps1')
Initialize-HarnessConsole

$root = (Resolve-Path -LiteralPath $HarnessRoot -ErrorAction SilentlyContinue).Path
if (-not $root) { $root = $HarnessRoot }

$findings = [System.Collections.Generic.List[object]]::new()
$plan = [System.Collections.Generic.List[object]]::new()

function Add-Finding {
    param([string]$Area, [string]$Item, $Value, [string]$Status = 'OK', [string]$Note = '')
    $findings.Add([pscustomobject]@{ area = $Area; item = $Item; value = $Value; status = $Status; note = $Note })
}
function Add-Plan {
    param([string]$Action, [string]$Target, $Current, $Proposed, [string]$Risk = 'low', [string]$Note = '')
    $plan.Add([pscustomobject]@{ action = $Action; target = $Target; current = $Current; proposed = $Proposed; risk = $Risk; note = $Note })
}
function Test-NonAscii { param([string]$s) return ($s -and ($s -match '[^\x00-\x7F]')) }

# ===========================================================================
# 1. 호스트
# ===========================================================================
# $PSEdition 은 읽기 전용 자동 변수다. 같은 이름을 쓰면 대입에서 실패한다.
$psVersion = $PSVersionTable.PSVersion.ToString()
$hostEdition = if ($PSVersionTable.PSEdition) { $PSVersionTable.PSEdition } else { 'Desktop' }
Add-Finding 'host' 'PowerShell' "$hostEdition $psVersion" 'OK'

$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
Add-Finding 'host' 'pwsh (PS7)' $(if ($pwsh) { $pwsh.Source } else { '없음' }) $(if ($pwsh) { 'OK' } else { 'INFO' }) `
    $(if ($pwsh) { '' } else { 'Windows 전용으로 동작한다. macOS/Linux 지원이 필요하면 PowerShell 7 이 있어야 한다.' })

Add-Finding 'host' 'LanguageMode' $ExecutionContext.SessionState.LanguageMode `
    $(if ("$($ExecutionContext.SessionState.LanguageMode)" -eq 'FullLanguage') { 'OK' } else { 'BLOCK' }) `
    $(if ("$($ExecutionContext.SessionState.LanguageMode)" -ne 'FullLanguage') { '제한 언어 모드에서는 설치 스크립트가 동작하지 않는다.' } else { '' })

$policies = @{}
foreach ($s in 'MachinePolicy', 'UserPolicy', 'Process', 'CurrentUser', 'LocalMachine') {
    try { $policies[$s] = (Get-ExecutionPolicy -Scope $s).ToString() } catch { $policies[$s] = 'n/a' }
}
$effective = (Get-ExecutionPolicy).ToString()
Add-Finding 'host' 'ExecutionPolicy(유효)' $effective $(if ($effective -in @('Restricted', 'AllSigned')) { 'WARN' } else { 'OK' }) `
    '설치 명령은 -ExecutionPolicy Bypass 로 실행하므로 정책을 영구 변경할 필요가 없다.'
if ($Detailed) { Add-Finding 'host' 'ExecutionPolicy(범위별)' ($policies.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ' 'INFO' }

$isAdmin = $false
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { }
Add-Finding 'host' '관리자 권한' $isAdmin 'INFO' '설치에 관리자 권한은 필요하지 않다.'

# ===========================================================================
# 2. 인코딩 — 경로 손상의 원인
# ===========================================================================
$acp = try { (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage' -Name ACP -ErrorAction Stop).ACP } catch { 'unknown' }
$oemcp = try { (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage' -Name OEMCP -ErrorAction Stop).OEMCP } catch { 'unknown' }
$nonUtf8Ansi = ($acp -ne '65001')
Add-Finding 'encoding' 'ANSI 코드페이지' $acp $(if ($nonUtf8Ansi) { 'WARN' } else { 'OK' }) `
    $(if ($nonUtf8Ansi) { 'BOM 없는 .ps1 은 이 코드페이지로 디코딩되어 비ASCII 문자가 깨진다. 하네스는 모든 .ps1 을 UTF-8 BOM 으로 관리한다.' } else { '' })
Add-Finding 'encoding' 'OEM 코드페이지' $oemcp 'INFO' '네이티브 CLI stdout 캡처 시 이 값이 적용된다.'

# ===========================================================================
# 3. 경로
# ===========================================================================
$home_ = Get-HarnessHome
$localApp = $env:LOCALAPPDATA
Add-Finding 'path' 'USERPROFILE' $home_ $(if (Test-NonAscii $home_) { 'WARN' } else { 'OK' }) `
    $(if (Test-NonAscii $home_) { '비ASCII 경로다. .cmd 런처 생성은 거부되고, 모든 경로 처리는 명시적 UTF-8 로 해야 한다.' } else { '' })
Add-Finding 'path' 'LOCALAPPDATA' $localApp $(if (Test-NonAscii $localApp) { 'WARN' } else { 'OK' })
if ($env:OneDrive -and $home_ -and $home_.StartsWith($env:OneDrive, [StringComparison]::OrdinalIgnoreCase)) {
    Add-Finding 'path' 'OneDrive 리디렉션' $env:OneDrive 'WARN' '홈이 클라우드 동기화 폴더 아래에 있다. 자격증명이 동기화될 위험이 있으므로 프로필 경로를 확인해야 한다.'
}
$longPaths = try { (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -ErrorAction Stop).LongPathsEnabled } catch { 0 }
Add-Finding 'path' '긴 경로 지원' ($longPaths -eq 1) $(if ($longPaths -eq 1) { 'OK' } else { 'INFO' }) `
    $(if ($longPaths -ne 1) { 'node_modules 는 경로가 깊다. 도구 루트를 짧은 경로에 두는 것이 안전하다.' } else { '' })

# ===========================================================================
# 4. 툴체인
# ===========================================================================
function Get-ToolInfo {
    param([string]$Name, [string[]]$VersionArgs = @('--version'))
    $c = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $c) { return [pscustomobject]@{ present = $false; path = $null; version = $null } }
    $v = $null
    try { $v = (& $Name @VersionArgs 2>&1 | Select-Object -First 1) -replace '^v', '' } catch { }
    return [pscustomobject]@{ present = $true; path = $c.Source; version = "$v".Trim() }
}

$node = Get-ToolInfo 'node'
$nodeMajor = if ($node.version) { [int]($node.version.Split('.')[0]) } else { 0 }
Add-Finding 'toolchain' 'Node.js' $(if ($node.present) { "$($node.version)  ($($node.path))" } else { '없음' }) `
    $(if (-not $node.present) { 'BLOCK' } elseif ($nodeMajor -lt 22) { 'BLOCK' } else { 'OK' }) `
    $(if ($nodeMajor -lt 22) { 'Node.js 22 이상이 필요하다.' } else { '' })

$npm = Get-ToolInfo 'npm'
Add-Finding 'toolchain' 'npm' $(if ($npm.present) { $npm.version } else { '없음' }) $(if ($npm.present) { 'OK' } else { 'BLOCK' })
if ($npm.present -and $Detailed) {
    $reg = try { (& npm config get registry 2>$null) } catch { '' }
    $proxy = try { (& npm config get proxy 2>$null) } catch { '' }
    Add-Finding 'toolchain' 'npm registry' "$reg".Trim() 'INFO'
    if ("$proxy".Trim() -notin @('', 'null')) { Add-Finding 'toolchain' 'npm proxy' "$proxy".Trim() 'INFO' '사내 프록시가 설정되어 있다.' }
}

$git = Get-ToolInfo 'git'
Add-Finding 'toolchain' 'git' $(if ($git.present) { $git.version } else { '없음' }) $(if ($git.present) { 'OK' } else { 'WARN' }) `
    $(if (-not $git.present) { 'git 이 없으면 하네스를 클론하거나 갱신할 수 없고 비밀값 가드도 강제할 수 없다.' } else { '' })

# ===========================================================================
# 5. 도구 루트 (Layer B)
# ===========================================================================
$resolvedTools = Get-HarnessToolsRoot -Override $ToolsRoot
Add-Finding 'tools_root' '해석된 위치' $resolvedTools 'OK'
Add-Finding 'tools_root' 'AI_HARNESS_TOOLS_ROOT (User)' $([Environment]::GetEnvironmentVariable('AI_HARNESS_TOOLS_ROOT', 'User')) 'INFO'

$candidateRoots = @()
if ($env:LOCALAPPDATA) { $candidateRoots += (Join-HarnessPath $env:LOCALAPPDATA 'AI-Tools') }
$candidateRoots += 'C:\AI-Tools'
foreach ($cr in ($candidateRoots | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $cr)) { continue }
    $trust = Test-HarnessPathTrust -Path $cr
    $isLegacy = $cr -eq 'C:\AI-Tools'
    Add-Finding 'tools_root' "기존 디렉터리: $cr" $(if ($trust.trusted) { '권한 안전' } else { "위험: $($trust.offenders -join '; ')" }) `
        $(if ($trust.trusted) { 'OK' } else { 'WARN' }) `
        $(if ($isLegacy -and -not $trust.trusted) { 'C:\ 바로 아래 폴더는 Authenticated Users 쓰기 권한을 상속받는다. 다른 로컬 사용자가 MCP 실행 파일을 교체할 수 있다.' } else { '' })
    if (-not $trust.trusted) {
        Add-Plan 'ACL 제한' $cr ($trust.offenders -join '; ') '소유자 / SYSTEM / Administrators 만' 'medium' `
            '다른 로컬 사용자가 MCP 실행 파일을 교체할 수 있는 상태를 없앤다.'
    }
    if ($isLegacy -and $resolvedTools -ne $cr) {
        Add-Plan '레거시 정리' $cr '존재' '재등록 후 삭제 권장' 'low' 'AI 클라이언트를 모두 재시작한 뒤 삭제한다.'
    }
}
if (-not (Test-Path -LiteralPath $resolvedTools)) {
    Add-Plan '생성' $resolvedTools '없음' '디렉터리 생성 + ACL 제한' 'low' ''
}

# ===========================================================================
# 6. 하네스 (Layer A)
# ===========================================================================
Add-Finding 'harness' 'HARNESS_ROOT' $root $(if (Test-Path -LiteralPath (Join-HarnessPath $root 'CORE.md')) { 'OK' } else { 'BLOCK' })
$isRepo = $false
Push-Location -LiteralPath $root -ErrorAction SilentlyContinue
try {
    & git rev-parse --is-inside-work-tree *> $null
    $isRepo = ($LASTEXITCODE -eq 0)
    if ($isRepo) {
        $hooks = (& git config core.hooksPath)
        Add-Finding 'harness' 'git 저장소' '예' 'OK'
        Add-Finding 'harness' 'core.hooksPath' $(if ($hooks) { $hooks } else { '(미설정)' }) $(if ($hooks -eq '.githooks') { 'OK' } else { 'WARN' })
        if ($hooks -ne '.githooks') {
            Add-Plan 'git 설정' "$root (core.hooksPath)" $(if ($hooks) { $hooks } else { '미설정' }) '.githooks' 'low' '비밀값 pre-commit 가드를 활성화한다.'
        }
    } else {
        Add-Finding 'harness' 'git 저장소' '아니오' 'WARN' 'git 저장소가 아니면 비밀값 가드를 강제할 수 없다 (UNENFORCED).'
    }
} finally { Pop-Location -ErrorAction SilentlyContinue }

# ===========================================================================
# 7. 런타임 (선언 vs 실체)
# ===========================================================================
$runtimeIds = Get-HarnessRuntimeIds -HarnessRoot $root
Add-Finding 'runtime' '선언된 공용 런타임' ($runtimeIds -join ', ') 'INFO'
foreach ($rid in $runtimeIds) {
    $m = Get-HarnessRuntimeManifest -HarnessRoot $root -RuntimeId $rid
    $idx = Read-HarnessRuntimeIndex -ToolsRoot $resolvedTools
    $e = Get-HarnessIndexEntry -Index $idx -RuntimeId $rid
    if ($e) {
        Add-Finding 'runtime' "$rid" "$($e.state) / v$($e.installed_version)" `
            $(if ($e.state -eq 'verified') { 'OK' } else { 'INFO' }) `
            $(if ($e.installed_version -ne $m.install.version) { "선언 v$($m.install.version) 과 불일치" } else { '' })
        if ($e.installed_version -ne $m.install.version) {
            Add-Plan '런타임 재설치' $rid "v$($e.installed_version)" "v$($m.install.version)" 'medium' ''
        }
    } else {
        Add-Finding 'runtime' "$rid" '미설치' 'INFO' "$($m.display_name)"
        Add-Plan '런타임 설치(선택)' $rid '미설치' "v$($m.install.version) 를 $resolvedTools 에" 'low' `
            '이 능력이 필요할 때만 설치하면 된다. 설치하지 않아도 하네스는 정상 동작한다.'
    }
    # 자격증명 — 존재 여부만. 내용은 절대 읽지 않는다.
    if ($m.credentials -and $m.credentials.storage) {
        $params = Get-HarnessRuntimeParameters -Manifest $m
        $ctx = New-HarnessInterpolationContext -ToolsRoot $resolvedTools -RuntimeDir $resolvedTools -Parameters $params
        $store = (Resolve-HarnessInterpolation -Value $m.credentials.storage -Context $ctx).Replace('/', [string][IO.Path]::DirectorySeparatorChar)
        $have = $true
        foreach ($n in (@($m.credentials.required_files) + @($m.credentials.auth_state_files))) {
            if (-not (Test-Path -LiteralPath (Join-HarnessPath $store $n))) { $have = $false }
        }
        Add-Finding 'runtime' "$rid 자격증명 파일" $(if ($have) { '있음' } else { '없음' }) 'INFO' `
            $(if (-not $have) { "최초 로그인이 필요하다: $($m.credentials.setup_guide)" } else { '존재는 인증을 뜻하지 않는다. 실제 호출로 검증해야 한다.' })
    }
}

# ===========================================================================
# 8. AI 클라이언트
# ===========================================================================
$clientIds = Get-HarnessClientIds -HarnessRoot $root
foreach ($cid in $clientIds) {
    $d = Get-HarnessClientDescriptor -HarnessRoot $root -ClientId $cid
    $exe = $d.detect.command
    $cmd = Get-Command $exe -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Add-Finding 'client' $d.display_name '미설치' 'INFO' "$exe 을 PATH 에서 찾을 수 없다. 이 클라이언트는 건너뛴다."
        continue
    }
    # 설정 파일 경로를 가정하지 않는다. CLI 에게 묻는다.
    $listArgs = @($d.argv.list)
    $out = try { (& $exe @listArgs 2>&1 | Out-String) } catch { '' }
    $names = @()
    foreach ($rid in $runtimeIds) {
        $m = Get-HarnessRuntimeManifest -HarnessRoot $root -RuntimeId $rid
        if ($out -match [regex]::Escape($m.server_name)) { $names += $m.server_name }
    }
    Add-Finding 'client' $d.display_name "설치됨 ($($cmd.Source))" 'OK' `
        $(if ($names.Count) { "이미 등록된 하네스 서버: $($names -join ', ')" } else { '하네스 서버 미등록' })

    # 원장이 "등록됨"이라 기록했는데 클라이언트에는 없는 경우 = 등록이 지워졌다는 뜻이다.
    # 제3의 도구가 설정 파일을 소유하면 실제로 일어난다(아래 managed home 검사 참고).
    $ledger = Read-HarnessClientRegistry -ToolsRoot $resolvedTools
    foreach ($rid in $runtimeIds) {
        $m = Get-HarnessRuntimeManifest -HarnessRoot $root -RuntimeId $rid
        $recorded = @($ledger.registrations | Where-Object { $_.client -eq $cid -and $_.runtime_id -eq $rid }).Count -gt 0
        $actual = ($names -contains $m.server_name)
        if ($recorded -and -not $actual) {
            Add-Finding 'client' "$($d.display_name) / $rid" '원장에는 등록, 실제로는 없음' 'WARN' `
                '등록이 외부 요인으로 사라졌다. 재등록이 필요하다.'
            Add-Plan '재등록' "$cid <- $rid" '없음' '등록' 'medium' '원장과 실제 상태가 갈라져 있다.'
        } elseif (-not $actual) {
            Add-Plan '등록(선택)' "$cid <- $rid" '미등록' '등록' 'medium' `
                "risk=$($m.risk) 런타임이다. 등록하면 이 클라이언트의 모든 프로젝트에서 도구가 보인다."
        }
    }

    if ($d.config_home_env) {
        $ov = [Environment]::GetEnvironmentVariable($d.config_home_env)
        if ($ov) {
            Add-Finding 'client' "$($d.display_name) $($d.config_home_env)" $ov 'WARN' `
                '설정 홈이 재정의되어 있다. 설정 파일 경로를 가정하는 검사는 이 환경에서 틀린 답을 준다.'
            # 제3의 래퍼가 설정 파일을 관리하면 하네스가 넣은 등록이 조용히 지워질 수 있다.
            # 이 PC 에서 실제로 관측된 현상이다(orca 가 config.toml 을 재작성하며 mcp_servers 블록 소실).
            $markers = @(Get-ChildItem -LiteralPath $ov -Force -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^\.(orca|managed)' -or $_.Name -like '*managed-home*' })
            if ($markers.Count) {
                Add-Finding 'client' "$($d.display_name) 관리형 설정 홈" ($markers.Name -join ', ') 'WARN' `
                    '외부 도구가 이 설정 파일을 소유한다. 하네스가 넣은 MCP 등록이 나중에 지워질 수 있으므로, 작업 시작 시 등록 상태를 다시 확인해야 한다.'
            }
        }
    }
    if ($d.tool_policy_support -and $d.tool_policy_support.status -eq 'unverified') {
        Add-Finding 'client' "$($d.display_name) 도구 통제" '미검증' 'WARN' '위험 도구 차단/승인 메커니즘이 확인되지 않았다.'
    }
}

# ===========================================================================
# 판정
# ===========================================================================
$blocks = @($findings | Where-Object status -eq 'BLOCK')
$warns = @($findings | Where-Object status -eq 'WARN')
$overall = if ($blocks.Count) { 'BLOCKED' } elseif ($warns.Count) { 'READY_WITH_WARNINGS' } else { 'READY' }

$report = [pscustomobject]@{
    overall      = $overall
    checked_at   = (Get-HarnessUtcStamp)
    harness_root = $root
    tools_root   = $resolvedTools
    findings     = @($findings)
    plan         = @($plan)
}

if ($Json) {
    $report | ConvertTo-Json -Depth 8
} else {
    Write-Output ''
    Write-Output "AI Harness 환경 진단: $overall"
    Write-Output "  하네스: $root"
    Write-Output "  도구 루트: $resolvedTools"
    Write-Output ''
    $lastArea = ''
    foreach ($f in $findings) {
        if ($f.area -ne $lastArea) { Write-Output "[$($f.area)]"; $lastArea = $f.area }
        $v = if ($f.value -is [array]) { $f.value -join ', ' } else { "$($f.value)" }
        Write-Output ("  {0,-5} {1,-28} {2}" -f $f.status, $f.item, $v)
        if ($f.note) { Write-Output ("        └ {0}" -f $f.note) }
    }
    Write-Output ''
    if ($plan.Count) {
        Write-Output '이 PC 에 제안하는 변경 (아직 아무것도 적용되지 않았습니다):'
        $i = 0
        foreach ($p in $plan) {
            $i++
            Write-Output ("  {0}. [{1}] {2}" -f $i, $p.risk, $p.action)
            Write-Output ("       대상: {0}" -f $p.target)
            Write-Output ("       현재: {0}  ->  제안: {1}" -f $p.current, $p.proposed)
            if ($p.note) { Write-Output ("       {0}" -f $p.note) }
        }
        Write-Output ''
        Write-Output '적용하려면: .\scripts\Install-Harness.ps1 -WhatIf   (먼저 실행될 명령을 확인)'
    } else {
        Write-Output '제안할 변경이 없습니다. 이 PC 는 이미 구성되어 있습니다.'
    }
    Write-Output ''
}

if ($blocks.Count) { exit 3 }
if ($warns.Count) { exit 2 }
exit 0
