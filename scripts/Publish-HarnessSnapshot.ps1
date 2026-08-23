#Requires -Version 5.1
<#
    AI Harness — Drive 스냅샷 발행

    정본은 GitHub 다. Drive 는 라벨이 붙은 불변 사본이다.
    "동기화"가 아니다. 한 라벨에 한 번 쓰고 끝낸다. 이미 있으면 거부한다.
    그래서 삭제 패스도, update->create 폴백도, "지금 Drive 에 있는 게 언제 것인가"라는
    답할 수 없는 질문도 생기지 않는다.

    올리는 것은 **git 이 추적하는 파일뿐**이다.
    작업 트리를 훑지 않는다. 훑으면 .gitignore 된 것, 빌드 산출물, 남겨 둔 임시 파일이
    함께 올라간다. 추적 파일로 한정하면 pre-commit 비밀값 가드가 이미 한 번 걸러 준 것만 나간다.
    그 위에 매니페스트의 never_sync 를 두 번째 관문으로 둔다.

    사용:
        .\Publish-HarnessSnapshot.ps1 -DryRun
        .\Publish-HarnessSnapshot.ps1 -Label v3.0.0
        .\Publish-HarnessSnapshot.ps1 -Ref v2.2.0 -Label v2.2.0

    종료 코드: 0 성공 / 1 실패 / 2 사용자 취소 / 3 사전 조건 미충족
#>
[CmdletBinding()]
param(
    [string]$HarnessRoot,
    [string]$ToolsRoot,
    [string]$RuntimeId = 'google-workspace',
    [string]$Ref = 'HEAD',
    [string]$Label,
    [string]$DriveRoot = '/AI-Harness-snapshots',
    [switch]$AllowDirty,
    [switch]$DryRun,
    [switch]$Yes
)

if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Runtime.ps1')
Initialize-HarnessConsole

$root = (Resolve-Path -LiteralPath $HarnessRoot).Path
$tools = Get-HarnessToolsRoot -Override $ToolsRoot
$gitExe = Get-HarnessNativeCommand 'git'
if (-not $gitExe) { throw 'git 이 필요합니다. 스냅샷은 추적 파일만 올립니다.' }

function Invoke-Git {
    param([string[]]$Arguments)
    $ErrorActionPreference = 'Continue'   # 함수 스코프. stderr 가 ErrorRecord 가 되어도 죽지 않는다
    $out = & $gitExe -C $root @Arguments 2>&1
    return [pscustomobject]@{ exit = $LASTEXITCODE; lines = @($out | ForEach-Object { "$_" }) }
}

# ---------------------------------------------------------------------------
# 무엇을 올릴지 확정한다
# ---------------------------------------------------------------------------

$isRepo = (Invoke-Git @('rev-parse', '--is-inside-work-tree')).exit -eq 0
if (-not $isRepo) { throw "git 저장소가 아닙니다: $root" }

$dirty = @((Invoke-Git @('status', '--porcelain')).lines | Where-Object { $_.Trim() })
if ($dirty.Count -and -not $AllowDirty) {
    Write-Output ''
    Write-Output "작업 트리가 깨끗하지 않습니다 ($($dirty.Count)건)."
    foreach ($l in ($dirty | Select-Object -First 10)) { Write-Output "  $l" }
    Write-Output ''
    Write-Output '스냅샷은 커밋된 상태를 가리켜야 합니다. 커밋하거나 -AllowDirty 를 쓰세요.'
    Write-Output '(-AllowDirty 를 쓰면 올라가는 것은 여전히 커밋된 내용이며, 작업 트리의 수정분은 포함되지 않습니다.)'
    exit 3
}

$commit = (Invoke-Git @('rev-parse', $Ref)).lines[0]
if (-not $commit) { throw "ref 를 해석할 수 없습니다: $Ref" }
$described = (Invoke-Git @('describe', '--tags', '--always', $Ref)).lines[0]

if (-not $Label) { $Label = "$described" }
# Drive 폴더 이름으로 쓸 수 없는 문자를 막는다. 라벨은 경로의 일부다.
if ($Label -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$') {
    throw "라벨이 규칙에 맞지 않습니다: '$Label' (허용: 영숫자로 시작, 영숫자 . _ - 최대 64자)"
}

$tracked = @((Invoke-Git @('ls-tree', '-r', '--name-only', $Ref)).lines | Where-Object { $_.Trim() })
if ($tracked.Count -eq 0) { throw "추적 파일이 없습니다: $Ref" }

# ---------------------------------------------------------------------------
# never_sync — 두 번째 관문. 목록은 매니페스트가 유일한 출처다
# ---------------------------------------------------------------------------

<#
    이 목록을 여기 하드코딩하면 매니페스트와 갈라진다.
    갈라지는 순간 한쪽에만 추가된 비밀값이 그대로 올라간다.
    그래서 선언된 모든 런타임의 credentials.never_sync 를 모아서 쓴다.
    아래 base 는 런타임과 무관하게 항상 막는 것들이다.
#>
$patterns = @('.env', '.env.*', '*.pem', '*.p12', '*.pfx', '*.key', 'runtimes.json', 'clients.json')
foreach ($rid in (Get-HarnessRuntimeIds -HarnessRoot $root)) {
    $m = Get-HarnessRuntimeManifest -HarnessRoot $root -RuntimeId $rid
    if ($m.credentials -and $m.credentials.never_sync) { $patterns += @($m.credentials.never_sync) }
}
$patterns = @($patterns | Select-Object -Unique)

function Test-NeverSync {
    param([string]$RelPath, [string[]]$Globs)
    $leaf = ($RelPath -split '/')[-1]
    foreach ($g in $Globs) {
        if ($leaf -like $g) { return $g }
        if ($RelPath -like $g) { return $g }
    }
    return $null
}

$violations = @()
foreach ($f in $tracked) {
    $hit = Test-NeverSync -RelPath $f -Globs $patterns
    if ($hit) { $violations += [pscustomobject]@{ path = $f; pattern = $hit } }
}
if ($violations.Count) {
    Write-Output ''
    Write-Output 'never_sync 에 걸리는 추적 파일이 있습니다. 스냅샷을 만들지 않습니다:'
    foreach ($v in $violations) { Write-Output ("  {0}   (패턴: {1})" -f $v.path, $v.pattern) }
    Write-Output ''
    Write-Output '이것은 스냅샷의 문제가 아니라 저장소의 문제입니다. 추적에서 빼고 이력을 정리하세요.'
    exit 3
}

# ---------------------------------------------------------------------------
# 런타임 좌표 — Layer B 에서 읽는다
# ---------------------------------------------------------------------------

<#
    래퍼 .cmd 를 가리키지 않는다.
    이전 동기화 스크립트는 자기 옆의 google-workspace-mcp.cmd 를 기본 실행 파일로 삼았고,
    그 래퍼가 매니페스트에 없는 서비스를 켜고 있었다. 좌표는 원장에서 읽어야 한다.
#>
$index = Read-HarnessRuntimeIndex -ToolsRoot $tools
$entry = Get-HarnessIndexEntry -Index $index -RuntimeId $RuntimeId
if (-not $entry) { throw "런타임이 설치되어 있지 않습니다: $RuntimeId" }
$command = Join-HarnessPath $tools $entry.command_rel
if (-not (Test-Path -LiteralPath $command)) { throw "실행 파일이 없습니다: $command" }
$runtimeDir = Join-HarnessPath $tools $entry.install_dir

$envMap = [ordered]@{}
if ($entry.env) { foreach ($p in $entry.env.PSObject.Properties) { $envMap[$p.Name] = [string]$p.Value } }

# ---------------------------------------------------------------------------
# 계획 렌더링
# ---------------------------------------------------------------------------

$totalBytes = 0
$binary = @()
foreach ($f in $tracked) {
    $abs = Join-HarnessPath $root ($f -replace '/', [string][IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $abs)) { continue }
    $bytes = [IO.File]::ReadAllBytes($abs)
    $totalBytes += $bytes.Length
    # 이진 파일은 문자열로 올릴 수 없다. 조용히 손상시키느니 빼고 알린다.
    if ($bytes -contains 0) { $binary += $f }
}

$snapshotRoot = "$DriveRoot/$Label"
Write-Output ''
Write-Output '스냅샷 발행 계획 (아직 아무것도 올라가지 않았습니다)'
Write-Output "  하네스   : $root"
Write-Output "  ref      : $Ref -> $commit  ($described)"
Write-Output "  라벨     : $Label"
Write-Output "  대상     : $snapshotRoot   (불변 — 이미 있으면 거부합니다)"
Write-Output "  런타임   : $RuntimeId  $command"
Write-Output "  파일     : $($tracked.Count)개  약 $([math]::Round($totalBytes/1KB)) KB  (+ SNAPSHOT.json)"
if ($binary.Count) {
    Write-Output "  제외     : 이진 파일 $($binary.Count)개 (문자열로 올릴 수 없음)"
    foreach ($b in ($binary | Select-Object -First 5)) { Write-Output "             $b" }
}
Write-Output "  never_sync 관문: $($patterns.Count)개 패턴, 위반 0건"
Write-Output ''
Write-Output '  올라가는 것은 커밋된 추적 파일뿐입니다. 작업 트리는 훑지 않습니다.'
Write-Output ''

if ($DryRun) { Write-Output '-DryRun 이므로 여기서 멈춥니다.'; exit 0 }
if (-not $Yes) {
    if (-not [Environment]::UserInteractive) { Write-Output '비대화형 세션입니다. -Yes 를 명시하세요.'; exit 2 }
    $ans = Read-Host '발행하려면 PUBLISH 를 입력하세요'
    if ($ans -ne 'PUBLISH') { Write-Output '취소했습니다.'; exit 2 }
}

# ---------------------------------------------------------------------------
# 실행 — .mjs 를 런타임 디렉터리로 복사해서 돌린다
# ---------------------------------------------------------------------------

# bare specifier '@modelcontextprotocol/sdk/...' 는 실행 파일 위치 기준으로 해석된다.
# 저장소에는 node_modules 가 없으므로 런타임 디렉터리에서 실행해야 한다.
$srcMjs = Join-HarnessPath $PSScriptRoot 'harness-drive-snapshot.mjs'
$dstMjs = Join-HarnessPath $runtimeDir '.harness-drive-snapshot.mjs'
[IO.File]::Copy($srcMjs, $dstMjs, $true)

$uploadable = @($tracked | Where-Object { $binary -notcontains $_ } | ForEach-Object { [pscustomobject]@{ rel = $_ } })

$manifest = [pscustomobject]@{
    kind         = 'ai-harness-snapshot'
    label        = $Label
    ref          = $Ref
    commit       = $commit
    described    = $described
    created_at   = (Get-HarnessUtcStamp)
    source       = 'https://github.com/hacker943410-debug/ai-harness'
    note         = '정본은 GitHub 이다. 이 폴더는 위 커밋의 불변 사본이며 갱신되지 않는다.'
    file_count   = $uploadable.Count
    excluded_binary = @($binary)
    never_sync_patterns = @($patterns)
}

$cfgPath = Join-HarnessPath $runtimeDir '.harness-drive-snapshot.config.json'
Write-HarnessJson -Path $cfgPath -Depth 8 -InputObject ([pscustomobject]@{
    command   = $command
    args      = @($entry.args)
    env       = $envMap
    localRoot = $root
    driveRoot = $DriveRoot
    label     = $Label
    files     = $uploadable
    snapshotManifest = ($manifest | ConvertTo-Json -Depth 8)
    timeoutMs = 900000
})

$nodeExe = Get-HarnessNativeCommand 'node'
if (-not $nodeExe) { throw 'node 를 찾을 수 없습니다.' }

Write-Output "발행 중... ($($uploadable.Count)개 파일)"
$raw = $null
try {
    $ErrorActionPreference = 'Continue'
    $raw = (& $nodeExe $dstMjs $cfgPath 2>&1 | Out-String).Trim()
} finally {
    $ErrorActionPreference = 'Stop'
    # 설정에는 실행 좌표가 들어 있다. 남겨 둘 이유가 없다.
    Remove-Item -LiteralPath $cfgPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $dstMjs -Force -ErrorAction SilentlyContinue
}

$result = $null
$lastLine = @($raw -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 1)[0]
try { $result = $lastLine | ConvertFrom-Json } catch { }

Write-Output ''
if (-not $result) {
    Write-Output '발행 결과를 해석할 수 없습니다. 원문:'
    Write-Output $raw
    exit 1
}

if (-not $result.ok) {
    Write-Output "발행 실패 (stage=$($result.stage)): $($result.error)"
    if ($result.failed) {
        foreach ($f in ($result.failed | Select-Object -First 10)) { Write-Output ("  FAIL {0} — {1}" -f $f.path, $f.error) }
    }
    Write-Output ''
    Write-Output '스냅샷은 덮어쓰지 않습니다. 다시 시도하려면 새 라벨을 쓰세요:'
    Write-Output "  .\scripts\Publish-HarnessSnapshot.ps1 -Label $Label-2"
    exit 1
}

Write-Output "발행 완료: $($result.drive_folder)"
Write-Output "  올린 파일: $($result.created)개 (SNAPSHOT.json 포함)"
if (@($result.skipped).Count) { Write-Output "  건너뜀: $(@($result.skipped).Count)개 (이진)" }
Write-Output ''
Write-Output '이 폴더는 갱신되지 않습니다. 다음 스냅샷은 새 라벨로 만듭니다.'
exit 0
