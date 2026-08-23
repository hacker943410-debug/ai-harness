#Requires -Version 5.1
<#
    AI Harness — 공용 런타임 인증 연결

    installed 와 authenticated 는 다른 사건이다. 설치는 Install-HarnessRuntime 이,
    인증은 이 스크립트가, 검증은 Test-HarnessRuntime 이 한다.
    이 스크립트는 절대로 state=verified 를 쓰지 않는다. 브라우저 흐름이 끝났다는 것은
    "토큰 파일이 생겼다"까지만 증명한다. 실제 API 호출은 아직 해 보지 않았다.

    자격증명 원본(client_secret*.json)을 받아 자격증명 저장소로 옮길 때
    다음 위치에서 오는 것은 거부한다.
      - git 워크트리 안        : 실수로 커밋될 수 있다
      - 도구 루트 안           : 공용 실행 경로에 비밀값을 두는 것
      - 다른 주체가 쓸 수 있는 곳 : 우리가 읽기 전에 바꿔치기될 수 있다
    거부는 불편하라고 있는 게 아니라, 이 셋이 실제로 비밀값이 새는 경로이기 때문이다.

    사용:
        .\Connect-HarnessRuntimeAuth.ps1 -RuntimeId google-workspace -CredentialSource ~\Downloads\client_secret_xxx.json
        .\Connect-HarnessRuntimeAuth.ps1 -RuntimeId google-workspace              # 자격증명은 이미 있고 로그인만
        .\Connect-HarnessRuntimeAuth.ps1 -RuntimeId google-workspace -DryRun

    종료 코드: 0 성공 / 1 실패 / 2 사용자 취소 / 3 사전 조건 미충족
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RuntimeId,
    [string]$CredentialSource,
    [string]$ProfileName,
    [string]$ToolsRoot,
    [string]$HarnessRoot,
    [switch]$SkipAuth,
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

if (-not $manifest.credentials) { throw "이 런타임은 자격증명을 쓰지 않습니다: $RuntimeId" }

$index = Read-HarnessRuntimeIndex -ToolsRoot $tools
$entry = Get-HarnessIndexEntry -Index $index -RuntimeId $RuntimeId
if (-not $entry) {
    throw "런타임이 설치되어 있지 않습니다: $RuntimeId`n먼저: .\scripts\Install-HarnessRuntime.ps1 -RuntimeId $RuntimeId"
}

# --- 프로필 ----------------------------------------------------------------
$params = Get-HarnessRuntimeParameters -Manifest $manifest
if ($ProfileName) { $params['profile'] = $ProfileName }
$profileValue = [string]$params['profile']
$profileSpec = $manifest.parameters.profile
if ($profileSpec -and $profileSpec.pattern -and ($profileValue -notmatch $profileSpec.pattern)) {
    throw "프로필 이름이 규칙에 맞지 않습니다: '$profileValue' (허용: $($profileSpec.pattern))"
}

$runtimeDir = Join-HarnessPath $tools $entry.install_dir
$ctx = New-HarnessInterpolationContext -ToolsRoot $tools -RuntimeDir $runtimeDir -Parameters $params
$store = (Resolve-HarnessInterpolation -Value $manifest.credentials.storage -Context $ctx).Replace('/', [string][IO.Path]::DirectorySeparatorChar)

# ---------------------------------------------------------------------------
# 자격증명 원본 검사
# ---------------------------------------------------------------------------

function Test-InsideGitWorkTree {
    param([Parameter(Mandatory = $true)][string]$Path)
    $dir = if (Test-Path -LiteralPath $Path -PathType Container) { $Path } else { Split-Path -Parent $Path }
    $git = Get-HarnessNativeCommand 'git'
    if (-not $git) { return $false }
    $inside = $false
    Push-Location -LiteralPath $dir
    try {
        & $git rev-parse --is-inside-work-tree *> $null
        $inside = ($LASTEXITCODE -eq 0)
    } finally { Pop-Location }
    return $inside
}

function Test-PathIsUnder {
    param([string]$Path, [string]$Parent)
    if (-not $Path -or -not $Parent) { return $false }
    $p = ([IO.Path]::GetFullPath($Path)).TrimEnd([char]'\', [char]'/')
    $q = ([IO.Path]::GetFullPath($Parent)).TrimEnd([char]'\', [char]'/')
    return $p.StartsWith($q + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

$plannedCopy = $null
if ($CredentialSource) {
    if (-not (Test-Path -LiteralPath $CredentialSource -PathType Leaf)) {
        throw "자격증명 원본이 없습니다: $CredentialSource"
    }
    $src = (Resolve-Path -LiteralPath $CredentialSource).Path
    $refusals = @()

    if (Test-InsideGitWorkTree -Path $src) {
        $refusals += 'git 워크트리 안에 있습니다. 실수로 커밋될 수 있으므로 저장소 밖으로 옮긴 뒤 다시 실행하세요.'
    }
    if (Test-PathIsUnder -Path $src -Parent $tools) {
        $refusals += "도구 루트 안에 있습니다($tools). 공용 실행 경로에 비밀값을 두면 안 됩니다."
    }
    if (Test-PathIsUnder -Path $src -Parent $root) {
        $refusals += "하네스 저장소 안에 있습니다($root)."
    }
    $trust = Test-HarnessPathTrust -Path $src
    if ($trust.checked -and -not $trust.trusted) {
        $refusals += "다른 주체가 이 파일을 바꿀 수 있습니다: $($trust.offenders -join '; ')"
    }
    if ($refusals.Count) {
        Write-Output ''
        Write-Output "자격증명 원본을 받아들일 수 없습니다: $src"
        foreach ($r in $refusals) { Write-Output "  - $r" }
        Write-Output ''
        exit 3
    }

    # 원본이 실제로 이 런타임이 기대하는 모양인지 최소한만 본다.
    # 값은 읽지 않는다. 최상위 키만 확인한다.
    $shape = $null
    try { $shape = (Read-HarnessJson -Path $src).PSObject.Properties.Name } catch {
        throw "자격증명 원본을 JSON 으로 읽을 수 없습니다: $src"
    }
    $plannedCopy = [pscustomobject]@{
        source = $src
        target = (Join-HarnessPath $store $manifest.credentials.required_files[0])
        keys   = ($shape -join ', ')
    }
}

# ---------------------------------------------------------------------------
# 인증 명령 해석
# ---------------------------------------------------------------------------

$authPlan = $null
if (-not $SkipAuth) {
    if (-not $manifest.credentials.auth_command) { throw '매니페스트에 auth_command 가 없습니다.' }
    $binName = $manifest.credentials.auth_command.bin
    $binWin = Join-HarnessPath $runtimeDir 'node_modules' '.bin' "$binName.cmd"
    $binNix = Join-HarnessPath $runtimeDir 'node_modules' '.bin' $binName
    $authBin = if (Test-Path -LiteralPath $binWin) { $binWin } elseif (Test-Path -LiteralPath $binNix) { $binNix } else { $null }
    if (-not $authBin) { throw "인증 실행 파일을 찾을 수 없습니다: $binWin" }

    $authArgs = @()
    foreach ($a in @($manifest.credentials.auth_command.args)) {
        $authArgs += (Resolve-HarnessInterpolation -Value ([string]$a) -Context $ctx)
    }
    # 활성 서비스가 곧 요청되는 OAuth 스코프다. 인증 프로세스에 반드시 넘겨야 한다.
    # 넘기지 않으면 나중에 켠 서비스에서 조용히 권한 부족으로 실패한다.
    $authEnv = Resolve-HarnessServerEnv -Manifest $manifest -Context $ctx
    $authPlan = [pscustomobject]@{
        bin = $authBin; arguments = $authArgs; env = $authEnv
        command_line = "$authBin $($authArgs -join ' ')"
    }
}

# ---------------------------------------------------------------------------
# 변경 계획 렌더링
# ---------------------------------------------------------------------------

Write-Output ''
Write-Output "인증 연결 계획 — $($manifest.display_name)"
Write-Output "  런타임   : $RuntimeId (v$($entry.installed_version))"
Write-Output "  프로필   : $profileValue"
Write-Output "  저장소   : $store"
Write-Output ''
$n = 0
if (-not (Test-Path -LiteralPath $store)) {
    $n++; Write-Output "  $n. 자격증명 저장소 생성 + ACL 제한: $store"
}
if ($plannedCopy) {
    $n++
    Write-Output "  $n. 자격증명 복사"
    Write-Output "       원본: $($plannedCopy.source)"
    Write-Output "       대상: $($plannedCopy.target)"
    Write-Output "       원본 최상위 키: $($plannedCopy.keys)"
}
if ($authPlan) {
    $n++
    Write-Output "  $n. 인증 실행 (브라우저가 열립니다)"
    Write-Output "       $($authPlan.command_line)"
    Write-Output "       환경: $((@($authPlan.env.Keys | ForEach-Object { "$_=$($authPlan.env[$_])" })) -join '  ')"
    Write-Output '       활성 서비스가 곧 요청되는 OAuth 스코프다. 나중에 서비스를 늘리면 재인증이 필요하다.'
}
if ($n -eq 0) { Write-Output '  (할 일이 없습니다)'; Write-Output ''; exit 0 }
Write-Output ''
Write-Output "되돌리기: .\scripts\Disconnect-HarnessRuntime.ps1 -RuntimeId $RuntimeId"
Write-Output ''

if ($DryRun) { Write-Output '-DryRun 이므로 여기서 멈춥니다. 아무것도 적용되지 않았습니다.'; exit 0 }
if (-not $Yes) {
    if (-not [Environment]::UserInteractive) { Write-Output '비대화형 세션입니다. -Yes 를 명시하세요.'; exit 2 }
    $ans = Read-Host '진행하려면 CONNECT 를 입력하세요'
    if ($ans -ne 'CONNECT') { Write-Output '취소했습니다.'; exit 2 }
}

# ---------------------------------------------------------------------------
# 적용
# ---------------------------------------------------------------------------

Write-Output ''
if (-not (Test-Path -LiteralPath $store)) {
    New-Item -ItemType Directory -Force -Path $store | Out-Null
    if (-not (Test-Path -LiteralPath $store)) { throw "저장소를 만들지 못했습니다: $store" }
    Write-Output "저장소 생성: $store"
}

# 저장소는 소유자만 접근할 수 있어야 한다. 여기에는 refresh token 이 들어간다.
try {
    $acl = Get-Acl -LiteralPath $store
    $acl.SetAccessRuleProtection($true, $true)
    Set-Acl -LiteralPath $store -AclObject $acl
    $acl = Get-Acl -LiteralPath $store
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    foreach ($ace in @($acl.Access)) {
        if ($ace.IsInherited) { continue }
        $sid = $null
        try { $sid = $ace.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value } catch { }
        if ($sid -and ($sid -eq $me -or $sid -eq 'S-1-5-18' -or $sid -eq 'S-1-5-32-544')) { continue }
        [void]$acl.RemoveAccessRule($ace)
    }
    Set-Acl -LiteralPath $store -AclObject $acl
    Write-Output '저장소 ACL 제한 완료 (소유자 / SYSTEM / Administrators)'
} catch {
    Write-Warning "저장소 ACL 을 제한하지 못했습니다: $($_.Exception.Message)"
}

if ($plannedCopy) {
    [IO.File]::Copy($plannedCopy.source, $plannedCopy.target, $true)
    if (-not (Test-Path -LiteralPath $plannedCopy.target)) { throw "자격증명 복사에 실패했습니다: $($plannedCopy.target)" }
    Write-Output "자격증명 복사 완료: $($plannedCopy.target)"
    Write-Output "  원본은 이제 필요 없습니다. 직접 삭제하세요: $($plannedCopy.source)"
}

foreach ($req in @($manifest.credentials.required_files)) {
    if (-not (Test-Path -LiteralPath (Join-HarnessPath $store $req))) {
        throw ("필수 자격증명 파일이 없습니다: $(Join-HarnessPath $store $req)`n" +
               "받는 방법: $($manifest.credentials.setup_guide)")
    }
}

$authOk = $true
if ($authPlan) {
    Write-Output ''
    Write-Output '인증을 시작합니다. 브라우저에서 계정을 선택하고 권한을 허용하세요.'
    $saved = @{}
    foreach ($k in $authPlan.env.Keys) {
        $saved[$k] = [Environment]::GetEnvironmentVariable($k, 'Process')
        [Environment]::SetEnvironmentVariable($k, [string]$authPlan.env[$k], 'Process')
    }
    try {
        & $authPlan.bin @($authPlan.arguments)
        if ($LASTEXITCODE -ne 0) { $authOk = $false; Write-Warning "인증 명령이 exit $LASTEXITCODE 로 끝났습니다." }
    } finally {
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k], 'Process') }
    }
}

# ---------------------------------------------------------------------------
# 결과 — 파일이 생겼다는 것까지만 말한다
# ---------------------------------------------------------------------------

$missing = @()
foreach ($st in @($manifest.credentials.auth_state_files)) {
    if (-not (Test-Path -LiteralPath (Join-HarnessPath $store $st))) { $missing += $st }
}

Write-Output ''
if ($missing.Count -or -not $authOk) {
    Write-Output "인증이 끝나지 않았습니다. 없는 파일: $($missing -join ', ')"
    Write-Output "안내: $($manifest.credentials.setup_guide)"
    exit 1
}

# 인덱스에는 '인증 시도가 있었다'까지만 남긴다. verified 는 실제 호출이 증명한다.
$entry | Add-Member -NotePropertyName auth_connected_at -NotePropertyValue (Get-HarnessUtcStamp) -Force
$entry | Add-Member -NotePropertyName auth_profile -NotePropertyValue $profileValue -Force
if ($entry.state -eq 'verified') { $entry.state = 'installed' }   # 계정이 바뀌었을 수 있다
$entry.last_verified_at = $null
$entry.last_verify_evidence = $null
Set-HarnessIndexEntry -Index $index -RuntimeId $RuntimeId -Entry $entry
Write-HarnessRuntimeIndex -ToolsRoot $tools -Index $index

Write-Output '토큰 파일이 생성되었습니다.'
Write-Output '파일이 생겼다는 것은 인증됐다는 뜻이 아닙니다. 실제 호출로 확인하세요:'
Write-Output "  .\scripts\Test-HarnessRuntime.ps1 -RuntimeId $RuntimeId"
Write-Output ''
Write-Output '인증을 바꿨으므로 이 런타임을 쓰는 CLI 는 재시작해야 새 자격으로 동작합니다.'
exit 0
