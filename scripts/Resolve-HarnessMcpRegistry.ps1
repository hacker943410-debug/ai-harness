#Requires -Version 5.1
<#
    AI Harness — 카탈로그의 registry_lookup 항목을 MCP 공식 레지스트리로 해석

    왜 자동 확정을 하지 않는가.

    레지스트리 검색은 이름으로 찾는다. 그리고 이름은 누구나 붙일 수 있다.
    "Chrome DevTools MCP" 를 검색하면 진짜(io.github.ChromeDevTools/chrome-devtools-mcp)보다
    최근에 올라온 다른 사람의 동명 서버가 먼저 나온다. 실측으로 확인한 사실이다.
    검색 1등을 그대로 핀하면 그것이 곧 공급망 사고다.

    그래서 이 스크립트는 "발행자가 일치하는 후보"만 해석으로 인정한다.
    카탈로그가 publisher 를 선언하고, 레지스트리 이름의 소유자 구간이 그것과 같아야 한다.
      카탈로그 publisher : ChromeDevTools
      레지스트리 name    : io.github.ChromeDevTools/chrome-devtools-mcp
                                    ^^^^^^^^^^^^^^ 이 구간
    같지 않으면 not_verified 로 남긴다. 사람이 보고 판단할 문제이지
    스크립트가 "아마 이거겠지" 하고 넘길 문제가 아니다.

    사용:
        .\Resolve-HarnessMcpRegistry.ps1                       # 전체 보고
        .\Resolve-HarnessMcpRegistry.ps1 -Id chrome-devtools
        .\Resolve-HarnessMcpRegistry.ps1 -SaveResolved .\resolved.json
        .\Resolve-HarnessMcpRegistry.ps1 -UpdateCatalog        # 명확히 해석된 것만 카탈로그에 반영

    종료 코드: 0 전부 해석됨 / 2 해석 못한 항목 있음 / 3 네트워크 등 실패
#>
[CmdletBinding()]
param(
    [string]$HarnessRoot,
    [string]$Id,
    [string]$SaveResolved,
    [switch]$UpdateCatalog,
    [switch]$IncludeDiscoveryOnly,
    [switch]$Yes,
    [int]$Limit = 20,
    [string]$RegistryBase = 'https://registry.modelcontextprotocol.io/v0'
)

if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Common.ps1')
Initialize-HarnessConsole

# PS 5.1 의 기본 SecurityProtocol 은 TLS 1.0 을 포함한다. 현대 엔드포인트는 거부한다.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = (Resolve-Path -LiteralPath $HarnessRoot).Path
$catalogPath = Join-HarnessPath $root 'catalogs' 'mcp-catalog.json'
$catalog = Read-HarnessJson -Path $catalogPath

$targets = @($catalog.entries | Where-Object { $_.install.kind -eq 'registry_lookup' })

# discovery_only 는 정책상 설치할 수 없는 항목이다(discovery_only_is_not_installable).
# publisher 도 대부분 비어 있어 발행자 대조가 불가능하다. 좌표를 확정할 이유가 없다.
# 승격하려는 항목이 생기면 그때 -IncludeDiscoveryOnly 로 하나씩 본다.
$skippedDiscovery = 0
if (-not $IncludeDiscoveryOnly -and -not $Id) {
    $before = $targets.Count
    $targets = @($targets | Where-Object { $_.status -ne 'discovery_only' })
    $skippedDiscovery = $before - $targets.Count
}
if ($Id) { $targets = @($catalog.entries | Where-Object { $_.id -eq $Id }) }
if ($targets.Count -eq 0) { Write-Output '해석할 항목이 없습니다.'; exit 0 }

# ---------------------------------------------------------------------------
# 레지스트리 조회
# ---------------------------------------------------------------------------

function Get-RegistryOwner {
    param([string]$RegistryName)
    # io.github.ChromeDevTools/chrome-devtools-mcp -> ChromeDevTools
    if ($RegistryName -notmatch '^([^/]+)/(.+)$') { return $null }
    $ns = $Matches[1]
    return ($ns -split '\.')[-1]
}

function Search-Registry {
    param([string]$Query)
    $uri = "$RegistryBase/servers?search=$([uri]::EscapeDataString($Query))&limit=$Limit"
    return (Invoke-RestMethod -Uri $uri -TimeoutSec 30)
}

$results = [System.Collections.Generic.List[object]]::new()

foreach ($e in $targets) {
    $query = if ($e.install.query) { [string]$e.install.query } else { [string]$e.name }
    $row = [ordered]@{
        id = $e.id; name = $e.name; publisher = $e.publisher; query = $query
        status = 'not_found'; registry_name = $null; version = $null
        package_registry = $null; package = $null; transport = $null
        candidates = @(); note = ''
    }

    $resp = $null
    try { $resp = Search-Registry -Query $query }
    catch {
        $row.status = 'lookup_failed'
        $row.note = $_.Exception.Message
        $results.Add([pscustomobject]$row)
        continue
    }

    $cands = @()
    foreach ($s in @($resp.servers)) {
        $meta = $s._meta.'io.modelcontextprotocol.registry/official'
        $owner = Get-RegistryOwner -RegistryName $s.server.name
        $pkg = @($s.server.packages) | Select-Object -First 1
        $cands += [pscustomobject]@{
            registry_name = $s.server.name
            owner         = $owner
            version       = $s.server.version
            is_latest     = [bool]$meta.isLatest
            status        = [string]$meta.status
            published_at  = [string]$meta.publishedAt
            package       = $(if ($pkg) { $pkg.identifier } else { $null })
            package_registry = $(if ($pkg) { $pkg.registryType } else { $null })
            transport     = $(if ($pkg -and $pkg.transport) { $pkg.transport.type } else { $null })
            publisher_match = ($owner -and $e.publisher -and ($owner -eq [string]$e.publisher))
        }
    }
    $row.candidates = @($cands | Select-Object registry_name, owner, version, is_latest, status, publisher_match)

    if ($cands.Count -eq 0) {
        $row.status = 'not_found'
        $row.note = '레지스트리에 이 이름으로 등록된 서버가 없습니다.'
        $results.Add([pscustomobject]$row); continue
    }

    $good = @($cands | Where-Object { $_.publisher_match -and $_.is_latest -and $_.status -eq 'active' })
    if ($good.Count -eq 1) {
        $g = $good[0]
        $row.status = if ($g.package) { 'resolved' } else { 'resolved_no_package' }
        $row.registry_name = $g.registry_name
        $row.version = $g.version
        $row.package = $g.package
        $row.package_registry = $g.package_registry
        $row.transport = $g.transport
        if (-not $g.package) { $row.note = '레지스트리 항목에 설치 가능한 패키지가 없습니다(원격 서버이거나 소스 빌드).' }
    } elseif ($good.Count -gt 1) {
        $row.status = 'ambiguous'
        $row.note = "발행자가 일치하는 후보가 $($good.Count)개입니다. 사람이 골라야 합니다."
    } else {
        $row.status = 'publisher_mismatch'
        $imp = @($cands | Where-Object { -not $_.publisher_match }) | Select-Object -First 3
        $row.note = ("카탈로그 publisher='$($e.publisher)' 와 일치하는 발행자가 없습니다. " +
                     "이름만 같은 다른 발행자: " + (($imp | ForEach-Object { "$($_.registry_name)@$($_.version)" }) -join ', '))
    }
    $results.Add([pscustomobject]$row)
}

# ---------------------------------------------------------------------------
# 보고
# ---------------------------------------------------------------------------

$byStatus = $results | Group-Object status | Sort-Object Name
Write-Output ''
Write-Output "MCP 레지스트리 해석 — 대상 $($results.Count)건"
Write-Output "  레지스트리: $RegistryBase"
if ($skippedDiscovery) {
    Write-Output "  건너뜀    : discovery_only $skippedDiscovery 건 (정책상 설치 불가. 보려면 -IncludeDiscoveryOnly)"
}
Write-Output ''
foreach ($g in $byStatus) { Write-Output ("  {0,-20} {1}" -f $g.Name, $g.Count) }
Write-Output ''
Write-Output ("  {0,-28} {1,-20} {2}" -f 'ID', 'STATUS', 'RESOLVED')
foreach ($r in $results) {
    $res = if ($r.registry_name) { "$($r.registry_name)  $($r.package)@$($r.version)" } else { '' }
    Write-Output ("  {0,-28} {1,-20} {2}" -f $r.id, $r.status, $res)
    if ($r.note) { Write-Output ("        └ {0}" -f $r.note) }
}
Write-Output ''

$resolved = @($results | Where-Object status -eq 'resolved')
$unresolved = @($results | Where-Object status -ne 'resolved')

if ($SaveResolved) {
    Write-HarnessJson -Path $SaveResolved -Depth 10 -InputObject ([pscustomobject]@{
        schema_version = '1.0'
        kind           = 'mcp-registry-resolution'
        resolved_at    = (Get-HarnessUtcStamp)
        registry_base  = $RegistryBase
        results        = @($results)
    })
    Write-Output "해석 결과를 저장했습니다: $SaveResolved"
    Write-Output ''
}

# ---------------------------------------------------------------------------
# 카탈로그 반영 — 명확히 해석된 것만
# ---------------------------------------------------------------------------

if ($UpdateCatalog) {
    if ($resolved.Count -eq 0) { Write-Output '카탈로그에 반영할 확정 해석이 없습니다.'; exit 2 }
    Write-Output "카탈로그에 반영할 항목 $($resolved.Count)건 (발행자 일치 + isLatest + active 만):"
    foreach ($r in $resolved) {
        Write-Output ("  {0}  registry_lookup -> {1}  {2}@{3}" -f $r.id, $r.package_registry, $r.package, $r.version)
    }
    Write-Output ''
    Write-Output '카탈로그는 Layer A 다. 이 변경은 커밋되어 모든 PC 에 퍼진다.'
    if (-not $Yes) {
        if (-not [Environment]::UserInteractive) { Write-Output '비대화형 세션입니다. -Yes 를 명시하세요.'; exit 2 }
        $ans = Read-Host '반영하려면 UPDATE 를 입력하세요'
        if ($ans -ne 'UPDATE') { Write-Output '취소했습니다.'; exit 2 }
    }
    foreach ($r in $resolved) {
        $e = @($catalog.entries | Where-Object id -eq $r.id)[0]
        $e.install = [pscustomobject]@{
            kind     = $(if ($r.package_registry -eq 'npm') { 'npm' } else { [string]$r.package_registry })
            package  = $r.package
            version  = $r.version
            docs     = $(if ($e.install.docs) { $e.install.docs } else { $null })
            registry = [pscustomobject]@{
                name        = $r.registry_name
                base        = $RegistryBase
                resolved_at = (Get-HarnessUtcStamp)
                publisher_verified = $true
            }
        }
    }
    $catalog.updated_at = (Get-HarnessUtcStamp)
    Write-HarnessJson -Path $catalogPath -InputObject $catalog -Depth 12
    Write-Output "카탈로그를 갱신했습니다: $catalogPath"
    Write-Output '커밋 전에 .\scripts\Test-HarnessRepo.ps1 을 돌리세요.'
}

if (@($results | Where-Object status -eq 'lookup_failed').Count) { exit 3 }
if ($unresolved.Count) { exit 2 }
exit 0
