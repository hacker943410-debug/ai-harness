#Requires -Version 5.1
<#
    AI Harness — 설치 전 환경 진단 (읽기 전용)

    이 스크립트는 아무것도 바꾸지 않는다.
    이 PC 가 어떤 환경인지 확인하고, 그에 맞는 설정안을 제시한다.
    실제 적용은 Install-Harness.ps1 이 하며, 사용자 확인을 거친다.

    사용:
        .\Get-HarnessEnvironment.ps1
        .\Get-HarnessEnvironment.ps1 -Json > env.json
        .\Get-HarnessEnvironment.ps1 -SavePlan .\plan.json      # Install-Harness.ps1 이 소비할 계획 파일

    계획 파일의 각 단계는 사람이 읽는 설명(action/current/proposed)과
    기계가 실행하는 명세(kind/payload)를 함께 담는다.
    사용자는 이 파일을 열어 enabled 를 false 로 바꾸는 것만으로 단계를 뺄 수 있고,
    Install-Harness.ps1 은 재탐지하지 않고 이 파일만 소비한다.

    종료 코드: 0 진행 가능 / 2 제한적으로 가능 / 3 차단 요소 있음
#>
[CmdletBinding()]
param(
    [string]$HarnessRoot,
    [string]$ToolsRoot,
    [string]$SavePlan,
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
# 단계의 모양은 _Harness.Runtime.ps1 의 New-HarnessPlanStep 이 유일하게 정의한다.
# 여기서는 목록에 담기만 한다.
function Add-Plan { $plan.Add((New-HarnessPlanStep @args)) }
function Test-NonAscii { param([string]$s) return ($s -and ($s -match '[^\x00-\x7F]')) }
function New-ScriptExec {
    param([string]$ScriptName, [string[]]$ScriptArgs)
    return (New-HarnessScriptExec -HarnessRoot $root -ScriptName $ScriptName -ScriptArgs $ScriptArgs)
}

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
        Add-Plan -StepId "toolsroot.acl:$cr" -Kind 'acl-set' -Action 'ACL 제한' -Target $cr `
            -Current ($trust.offenders -join '; ') -Proposed '소유자 / SYSTEM / Administrators 만' -Risk 'medium' `
            -Note '다른 로컬 사용자가 MCP 실행 파일을 교체할 수 있는 상태를 없앤다.' `
            -Payload ([pscustomobject]@{ path = $cr; disable_inheritance = $true })
    }
    if ($isLegacy -and $resolvedTools -ne $cr) {
        # 삭제는 자동화하지 않는다. 모든 CLI 가 재시작됐는지는 스크립트가 판정할 수 없다.
        Add-Plan -StepId "legacy.cleanup:$cr" -Kind 'manual' -Action '레거시 정리' -Target $cr `
            -Current '존재' -Proposed '재등록 후 삭제 권장' -Risk 'low' -Optional $true `
            -Note 'AI 클라이언트를 모두 재시작한 뒤 사람이 삭제한다. 자동 삭제하지 않는다.' `
            -Payload ([pscustomobject]@{ instructions = "Remove-Item -Recurse -Force '$cr'" })
    }
}
if (-not (Test-Path -LiteralPath $resolvedTools)) {
    Add-Plan -StepId 'toolsroot.create' -Kind 'dir-create' -Action '도구 루트 생성' -Target $resolvedTools `
        -Current '없음' -Proposed '디렉터리 생성 + ACL 제한' -Risk 'low' `
        -Payload ([pscustomobject]@{ path = $resolvedTools; restrict_acl = $true })
}

# 도구 루트를 기본값이 아닌 곳으로 지정했다면, 그 선택이 다음 세션에도 남아야 한다.
# 사용자 환경변수가 유일하게 이 결정을 기억하는 자리다.
if ($ToolsRoot) {
    $envCurrent = [Environment]::GetEnvironmentVariable('AI_HARNESS_TOOLS_ROOT', 'User')
    if ($envCurrent -ne $resolvedTools) {
        Add-Plan -StepId 'toolsroot.env' -Kind 'env-set' -Action '도구 루트 환경변수 고정' -Target 'AI_HARNESS_TOOLS_ROOT (User)' `
            -Current $(if ($envCurrent) { $envCurrent } else { '(미설정)' }) -Proposed $resolvedTools -Risk 'medium' `
            -Note '사용자 환경변수를 바꾼다. 새로 여는 프로세스에만 반영되며, 이미 떠 있는 세션은 옛 값을 계속 쓴다.' `
            -DependsOn @('toolsroot.create') `
            -Payload ([pscustomobject]@{ name = 'AI_HARNESS_TOOLS_ROOT'; scope = 'User'; value = $resolvedTools })
    }
}

# ===========================================================================
# 6. 하네스 (Layer A)
# ===========================================================================
Add-Finding 'harness' 'HARNESS_ROOT' $root $(if (Test-Path -LiteralPath (Join-HarnessPath $root 'CORE.md')) { 'OK' } else { 'BLOCK' })

# 하네스 루트는 실행되는 .ps1 과 AI 가 따르는 정책이 들어 있는 곳이다.
# 도구 루트만 잠그고 여기를 열어 두면 잠근 의미가 없다. 여기를 바꿀 수 있으면
# 도구 루트를 어디로 볼지, 무엇을 설치할지를 바꿀 수 있다.
$rootTrust = Test-HarnessPathTrust -Path $root
Add-Finding 'harness' '저장소 권한' $(if ($rootTrust.trusted) { '권한 안전' } else { "위험: $($rootTrust.offenders -join '; ')" }) `
    $(if ($rootTrust.trusted) { 'OK' } else { 'WARN' }) `
    $(if ($rootTrust.trusted) { '' } else { '다른 로컬 사용자가 하네스 스크립트와 정책을 바꿀 수 있다. 실행되는 코드를 바꿀 수 있다는 뜻이다.' })
if ($rootTrust.checked -and -not $rootTrust.trusted) {
    Add-Plan -StepId "harness.acl:$root" -Kind 'acl-set' -Action '하네스 저장소 ACL 제한' -Target $root `
        -Current ($rootTrust.offenders -join '; ') -Proposed '소유자 / SYSTEM / Administrators 만' -Risk 'medium' `
        -Note 'C: 바로 아래 폴더는 Authenticated Users 쓰기 권한을 상속받는다. 하네스가 거기 있으면 실행되는 코드가 무방비다.' `
        -Payload ([pscustomobject]@{ path = $root; disable_inheritance = $true })
}
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
            $gitExe = Get-HarnessNativeCommand 'git'
            $setArgv = @('-C', $root, 'config', 'core.hooksPath', '.githooks')
            $undoArgv = if ($hooks) { @('-C', $root, 'config', 'core.hooksPath', $hooks) } else { @('-C', $root, 'config', '--unset', 'core.hooksPath') }
            Add-Plan -StepId 'harness.hookspath' -Kind 'exec' -Action 'git 설정' -Target "$root (core.hooksPath)" `
                -Current $(if ($hooks) { $hooks } else { '미설정' }) -Proposed '.githooks' -Risk 'low' `
                -Note '비밀값 pre-commit 가드를 활성화한다.' `
                -CommandLine "git $($setArgv -join ' ')" `
                -Payload ([pscustomobject]@{ file = $gitExe; arguments = $setArgv }) `
                -Undo ([pscustomobject]@{ kind = 'exec'; file = $gitExe; arguments = $undoArgv; command_line = "git $($undoArgv -join ' ')" })
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
            $x = New-ScriptExec 'Install-HarnessRuntime.ps1' @('-RuntimeId', $rid, '-ToolsRoot', $resolvedTools, '-Reinstall')
            Add-Plan -StepId "runtime.install:$rid" -Kind 'exec' -Action '런타임 재설치' -Target $rid `
                -Current "v$($e.installed_version)" -Proposed "v$($m.install.version)" -Risk 'medium' `
                -Note '버전별 디렉터리로 설치되므로 이전 버전은 남는다. 롤백은 재다운로드 없이 포인터 전환이다.' `
                -CommandLine $x.command_line -Payload ([pscustomobject]@{ file = $x.file; arguments = $x.arguments })
        }
    } else {
        Add-Finding 'runtime' "$rid" '미설치' 'INFO' "$($m.display_name)"
        $x = New-ScriptExec 'Install-HarnessRuntime.ps1' @('-RuntimeId', $rid, '-ToolsRoot', $resolvedTools, '-Adopt', '-EnsureOnly')
        Add-Plan -StepId "runtime.install:$rid" -Kind 'exec' -Action '런타임 설치' -Target $rid `
            -Current '미설치' -Proposed "v$($m.install.version) 를 $resolvedTools 에" -Risk 'low' -Optional $true `
            -DependsOn @('toolsroot.create') `
            -Note '이 능력이 필요할 때만 설치하면 된다. 설치하지 않아도 하네스는 정상 동작한다.' `
            -CommandLine $x.command_line -Payload ([pscustomobject]@{ file = $x.file; arguments = $x.arguments })
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
    # PATH 에서 먼저 잡히는 것은 .ps1 shim 이고, .ps1 은 ExecutionPolicy 의 지배를 받는다.
    # Restricted 인 PC 에서 진단 자체가 PSSecurityException 으로 죽지 않게 .cmd/.exe 로 해석한다.
    $exe = Get-HarnessNativeCommand $d.detect.command
    if (-not $exe) {
        Add-Finding 'client' $d.display_name '미설치' 'INFO' "$($d.detect.command) 을 PATH 에서 찾을 수 없다. 이 클라이언트는 건너뛴다."
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
    Add-Finding 'client' $d.display_name "설치됨 ($exe)" 'OK' `
        $(if ($names.Count) { "이미 등록된 하네스 서버: $($names -join ', ')" } else { '하네스 서버 미등록' })

    # 원장이 "등록됨"이라 기록했는데 클라이언트에는 없는 경우 = 등록이 지워졌다는 뜻이다.
    # 제3의 도구가 설정 파일을 소유하면 실제로 일어난다(아래 managed home 검사 참고).
    $ledger = Read-HarnessClientRegistry -ToolsRoot $resolvedTools
    foreach ($rid in $runtimeIds) {
        $m = Get-HarnessRuntimeManifest -HarnessRoot $root -RuntimeId $rid
        $recorded = @($ledger.registrations | Where-Object { $_.client -eq $cid -and $_.runtime_id -eq $rid }).Count -gt 0
        $actual = ($names -contains $m.server_name)

        $reason = $null      # $null 이면 제안할 것이 없다
        $current = '미등록'
        $stepRisk = 'medium'
        $isOptional = $true

        if ($recorded -and -not $actual) {
            Add-Finding 'client' "$($d.display_name) / $rid" '원장에는 등록, 실제로는 없음' 'WARN' `
                '등록이 외부 요인으로 사라졌다. 재등록이 필요하다.'
            $reason = '원장과 실제 상태가 갈라져 있다. 등록이 외부 요인으로 사라졌다.'
            $current = '없음(원장에는 있음)'
            $isOptional = $false
        } elseif (-not $actual) {
            $reason = "risk=$($m.risk) 런타임이다. 등록하면 이 클라이언트의 모든 프로젝트에서 도구가 보인다."
        } else {
            # 등록돼 있다는 사실만으로는 부족하다. 의도한 것이 등록됐는지까지 본다.
            $diff = Get-HarnessRegistrationDiff -HarnessRoot $root -ToolsRoot $resolvedTools -RuntimeId $rid -ClientId $cid
            $bad = @($diff.rows | Where-Object { $_.verdict -in @('ADD', 'CHANGE', 'REMOVE') })
            if ($bad.Count) {
                $summary = ($bad | ForEach-Object { "$($_.field):$($_.verdict)" }) -join ', '
                $extra = @($bad | Where-Object verdict -eq 'REMOVE' |
                    ForEach-Object { "선언하지 않은 값이 켜져 있다: $($_.field)=$($_.actual)" }) -join ' '
                Add-Finding 'client' "$($d.display_name) / $rid 등록 내용" $summary 'WARN' `
                    ('등록은 있으나 선언과 다르다. ' + $extra).Trim()
                $reason = "선언과 실제가 다르다 ($summary). 재등록하면 선언대로 맞춰진다."
                $current = '등록됨(내용 불일치)'
                $isOptional = $false
                if ($diff.has_remove) { $stepRisk = 'high' }
            }
            if ($diff.ledger_drift.Count) {
                Add-Finding 'client' "$($d.display_name) / $rid 원장" ($diff.ledger_drift -join '; ') 'WARN' `
                    '원장이 선언과 다르다. 매니페스트가 설치 이후에 바뀌었다는 뜻이며, 런타임 재설치가 필요하다.'
            }
        }

        if ($reason) {
            $regArgs = @('-RuntimeId', $rid, '-Client', $cid, '-ToolsRoot', $resolvedTools, '-Force')
            if ($m.risk -eq 'high') { $regArgs += '-IAcceptRisk' }
            $x = New-ScriptExec 'Register-HarnessRuntimeClient.ps1' $regArgs
            $scope = if ($d.supports.default_scope) { $d.supports.default_scope } else { '' }
            $rmArgv = Expand-HarnessArgv -Template @($d.argv.remove) -Values @{ server_name = $m.server_name; scope = $scope }
            $note = $reason
            if ($m.risk -eq 'high') {
                $note += "  [risk=high — 명령에 -IAcceptRisk 가 들어 있다. 차단 도구: $(@($m.tool_policy.deny) -join ', ')]"
            }
            Add-Plan -StepId "client.register:$cid`:$rid" -Kind 'exec' -Action '클라이언트 등록' -Target "$cid <- $rid" `
                -Current $current -Proposed "$($m.server_name) 를 scope=$scope 로 등록" -Risk $stepRisk `
                -Optional $isOptional -DependsOn @("runtime.install:$rid") -Note $note `
                -CommandLine $x.command_line `
                -Payload ([pscustomobject]@{
                    file = $x.file; arguments = $x.arguments
                    # 적용 직전에 선언/원장/실제를 다시 대조할 수 있게 하는 힌트.
                    # 적용자가 런타임별 코드를 갖지 않도록 데이터로 넘긴다.
                    diff = [pscustomobject]@{ kind = 'registration'; runtime_id = $rid; client_id = $cid }
                }) `
                -Undo ([pscustomobject]@{
                    kind = 'exec'; file = (Get-HarnessNativeCommand $d.detect.command); arguments = @($rmArgv)
                    command_line = "$($d.detect.command) $($rmArgv -join ' ')"
                })
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
    # 도구 통제는 "있다/없다"보다 "지금 무엇이 노출돼 있는가"가 중요하다.
    # 차단 수단이 없는 클라이언트에 risk=high 런타임을 올려 두면
    # 매니페스트의 deny 목록은 문서일 뿐 강제되지 않는다.
    $tps = $d.tool_policy_support
    $canDeny = [bool]($tps -and $tps.deny)
    $tpsStatus = if ($tps -and $tps.PSObject.Properties.Name -contains 'status') { [string]$tps.status } else { '' }
    if ($tpsStatus -eq 'unverified') {
        Add-Finding 'client' "$($d.display_name) 도구 통제" '미검증' 'WARN' '위험 도구 차단/승인 메커니즘이 확인되지 않았다.'
    } elseif (-not $canDeny) {
        $exposed = @()
        foreach ($rid in $runtimeIds) {
            $mm = Get-HarnessRuntimeManifest -HarnessRoot $root -RuntimeId $rid
            if ($mm.risk -ne 'high') { continue }
            if ($names -notcontains $mm.server_name) { continue }
            $exposed += "$rid(deny: $(@($mm.tool_policy.deny) -join ', '))"
        }
        if ($exposed.Count) {
            Add-Finding 'client' "$($d.display_name) 도구 통제" '도구 단위 차단 불가' 'WARN' `
                ("risk=high 런타임이 등록돼 있는데 이 클라이언트는 도구 단위로 막을 수 없다. " +
                 "매니페스트의 deny 목록이 강제되지 않는다: $($exposed -join '; '). " +
                 "통제 단위는 서버 전체 on/off 뿐이다.")
        } else {
            Add-Finding 'client' "$($d.display_name) 도구 통제" '도구 단위 차단 불가' 'INFO' `
                'risk=high 런타임이 등록돼 있지 않아 지금은 노출이 없다.'
        }
    }
}

# ===========================================================================
# 판정
# ===========================================================================
$blocks = @($findings | Where-Object status -eq 'BLOCK')
$warns = @($findings | Where-Object status -eq 'WARN')
$overall = if ($blocks.Count) { 'BLOCKED' } elseif ($warns.Count) { 'READY_WITH_WARNINGS' } else { 'READY' }

$report = [pscustomobject]@{
    schema_version = '1.0'
    kind           = 'harness-change-plan'
    overall        = $overall
    checked_at     = (Get-HarnessUtcStamp)
    harness_root   = $root
    tools_root     = $resolvedTools
    blocks         = @($blocks | ForEach-Object { [pscustomobject]@{ item = $_.item; note = $_.note } })
    findings       = @($findings)
    plan           = @($plan)
}

if ($SavePlan) {
    Write-HarnessJson -Path $SavePlan -InputObject $report -Depth 10
    Write-Output "계획 파일을 저장했습니다: $SavePlan"
    Write-Output '내용을 확인하고, 빼고 싶은 단계는 enabled 를 false 로 바꾼 뒤 적용하세요:'
    Write-Output "  .\scripts\Install-Harness.ps1 -Plan '$SavePlan' -DryRun"
    Write-Output ''
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
            $tag = if ($p.kind -eq 'manual') { '수동' } elseif ($p.optional) { '선택' } else { '권장' }
            Write-Output ("  {0}. [{1}/{2}] {3}   ({4})" -f $i, $p.risk, $tag, $p.action, $p.step_id)
            Write-Output ("       대상: {0}" -f $p.target)
            Write-Output ("       현재: {0}  ->  제안: {1}" -f $p.current, $p.proposed)
            if ($p.command_line) { Write-Output ("       명령: {0}" -f $p.command_line) }
            if ($p.note) { Write-Output ("       {0}" -f $p.note) }
        }
        Write-Output ''
        Write-Output '적용 절차 (진단 -> 계획 파일 -> 확인 -> 적용):'
        Write-Output '  1) .\scripts\Get-HarnessEnvironment.ps1 -SavePlan .\plan.json'
        Write-Output '  2) plan.json 을 열어 빼고 싶은 단계의 enabled 를 false 로'
        Write-Output '  3) .\scripts\Install-Harness.ps1 -Plan .\plan.json -DryRun   (실행될 명령만 출력)'
        Write-Output '  4) .\scripts\Install-Harness.ps1 -Plan .\plan.json'
    } else {
        Write-Output '제안할 변경이 없습니다. 이 PC 는 이미 구성되어 있습니다.'
    }
    Write-Output ''
}

if ($blocks.Count) { exit 3 }
if ($warns.Count) { exit 2 }
exit 0
