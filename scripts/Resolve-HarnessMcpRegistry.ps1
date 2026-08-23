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
    [switch]$Recheck,
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

<#
    카탈로그는 항목 1개가 1줄이다. 일부러 그렇게 두었다.
    65개 항목을 ConvertTo-Json 기본 서식으로 펼치면 한 항목만 바뀌어도
    diff 가 수백 줄이 되어 리뷰에서 무엇이 바뀌었는지 안 보이게 된다.
    그래서 헤더/policy 만 펼치고 entries 는 한 줄씩 압축해서 쓴다.
#>
function Write-HarnessCatalog {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Catalog)

    # PS 5.1 의 ConvertTo-Json 은 < > ' & 를 \u00xx 로 이스케이프한다.
    # JSON 문자열 안에서 이 넷은 그대로 써도 되고, 이스케이프되면 사람이 못 읽는다.
    function Restore-Readable { param([string]$s)
        $map = [ordered]@{ '3c' = '<'; '3e' = '>'; '27' = [string][char]39; '26' = '&' }
        foreach ($code in $map.Keys) { $s = $s.Replace(('\u00' + $code), [string]$map[$code]) }
        return $s
    }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('{')
    [void]$sb.AppendLine('  "schema_version": ' + (Restore-Readable ($Catalog.schema_version | ConvertTo-Json -Compress)) + ',')
    [void]$sb.AppendLine('  "updated_at": ' + (Restore-Readable ($Catalog.updated_at | ConvertTo-Json -Compress)) + ',')
    [void]$sb.AppendLine('  "discovery_sources": ' + (Restore-Readable (@($Catalog.discovery_sources) | ConvertTo-Json -Compress)) + ',')

    $policyLines = @((Restore-Readable ($Catalog.policy | ConvertTo-Json -Depth 6)) -split "`r?`n")
    for ($i = 0; $i -lt $policyLines.Count; $i++) {
        $prefix = if ($i -eq 0) { '  "policy": ' } else { '  ' }
        $suffix = if ($i -eq $policyLines.Count - 1) { ',' } else { '' }
        [void]$sb.AppendLine($prefix + $policyLines[$i].TrimEnd() + $suffix)
    }

    [void]$sb.AppendLine('  "entries": [')
    $items = @($Catalog.entries)
    for ($i = 0; $i -lt $items.Count; $i++) {
        $line = Restore-Readable ($items[$i] | ConvertTo-Json -Depth 8 -Compress)
        $comma = if ($i -lt $items.Count - 1) { ',' } else { '' }
        [void]$sb.AppendLine('    ' + $line + $comma)
    }
    [void]$sb.AppendLine('  ]')
    [void]$sb.AppendLine('}')

    $text = $sb.ToString()
    # 쓰기 전에 반드시 다시 파싱해 본다. 손으로 만든 JSON 은 손으로 깨진다.
    $null = $text | ConvertFrom-Json
    Write-HarnessText -Path $Path -Text $text
}

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

# 이미 "레지스트리에 없다"를 확인한 항목은 매번 다시 물어볼 이유가 없다.
# 계속 not_found 로 보고하면 진짜 문제가 그 안에 묻힌다.
# 다시 확인하려면 -Recheck.
$knownAbsent = @()
if (-not $Recheck -and -not $Id) {
    $knownAbsent = @($targets | Where-Object { $_.install.registry_absent })
    $targets = @($targets | Where-Object { -not $_.install.registry_absent })
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

<#
    검색어 하나로 끝내면 안 된다. 레지스트리 검색은 표시 이름과 잘 매칭되지 않는다.
    실측: "Chrome DevTools MCP" -> 0건, "chrome-devtools" -> 5건(진짜 항목 포함).
    카탈로그의 query 는 사람이 읽는 이름이고, 레지스트리 이름은 슬러그다.
    그래서 후보를 여러 개 던지고 결과를 합친다. 없는 것을 없다고 하려면
    찾을 수 있는 방법을 다 써 본 뒤여야 한다.
#>
<#
    이름을 확정한 뒤에는 검색 결과를 믿지 않고 정본을 다시 받는다.
    검색은 페이지가 잘리고 정렬도 보장되지 않아 isLatest 가 사실과 다를 수 있다.
    이름의 '/' 는 %2F 로 인코딩해야 한다.
#>
function Get-RegistryLatest {
    param([Parameter(Mandatory = $true)][string]$Name)
    $uri = "$RegistryBase/servers/$([uri]::EscapeDataString($Name))/versions/latest"
    return (Invoke-RestMethod -Uri $uri -TimeoutSec 30)
}

function Get-QueryCandidate {
    param($Entry)
    $c = @()
    if ($Entry.install.query) { $c += [string]$Entry.install.query }
    $c += [string]$Entry.id
    if ($Entry.id -notmatch '-mcp$') { $c += "$($Entry.id)-mcp" }
    if ($Entry.name) { $c += ([string]$Entry.name).ToLowerInvariant().Replace(' ', '-') }
    return @($c | Where-Object { $_ } | Select-Object -Unique)
}

$results = [System.Collections.Generic.List[object]]::new()

foreach ($e in $targets) {
    $query = if ($e.install.query) { [string]$e.install.query } else { [string]$e.name }
    $row = [ordered]@{
        id = $e.id; name = $e.name; publisher = $e.publisher; query = $query
        status = 'not_found'; registry_name = $null; version = $null
        package_registry = $null; package = $null; transport = $null; url = $null
        candidates = @(); note = ''
    }

    $queries = Get-QueryCandidate -Entry $e
    $row.query = ($queries -join ' | ')
    $servers = @()
    $failed = $null
    foreach ($q in $queries) {
        try { $servers += @((Search-Registry -Query $q).servers) }
        catch { $failed = $_.Exception.Message }
    }
    if ($servers.Count -eq 0 -and $failed) {
        $row.status = 'lookup_failed'
        $row.note = $failed
        $results.Add([pscustomobject]$row)
        continue
    }
    # 여러 질의의 결과를 합쳤으므로 같은 항목이 여러 번 들어온다.
    $servers = @($servers | Group-Object { "$($_.server.name)@$($_.server.version)" } | ForEach-Object { $_.Group[0] })

    $cands = @()
    foreach ($s in $servers) {
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

    # 검색 결과에서는 **이름만** 고른다. 버전과 패키지는 정본에서 다시 받는다.
    # 검색은 페이지가 잘리고 정렬도 보장되지 않아 isLatest 가 신뢰할 수 없다.
    # 실측: chrome-devtools 검색 20건에 ChromeDevTools 의 isLatest=true 버전이 아예 없었다.
    # 그대로 믿었으면 최신이 아닌 버전을 핀할 뻔했다.
    $names = @($cands | Where-Object { $_.publisher_match -and $_.status -eq 'active' } |
        ForEach-Object { $_.registry_name } | Select-Object -Unique)

    if ($names.Count -eq 1) {
        $latest = $null
        try { $latest = Get-RegistryLatest -Name $names[0] }
        catch {
            $row.status = 'lookup_failed'
            $row.note = "정본 조회 실패($($names[0])): $($_.Exception.Message)"
            $results.Add([pscustomobject]$row); continue
        }
        $lmeta = $latest._meta.'io.modelcontextprotocol.registry/official'
        # packages 배열이 있어도 identifier 가 비어 있을 수 있다. 존재가 아니라 값으로 판정한다.
        $lpkg = @($latest.server.packages) | Where-Object { $_.identifier } | Select-Object -First 1
        $lremote = @($latest.server.remotes) | Where-Object { $_.url } | Select-Object -First 1
        $row.registry_name = $latest.server.name
        $row.version = $latest.server.version
        $row.package = $(if ($lpkg) { $lpkg.identifier } else { $null })
        $row.package_registry = $(if ($lpkg) { $lpkg.registryType } else { $null })
        $row.transport = $(if ($lpkg -and $lpkg.transport) { $lpkg.transport.type } elseif ($lremote) { $lremote.type } else { $null })
        $row.url = $(if ($lremote) { [string]$lremote.url } else { $null })
        if ([string]$lmeta.status -ne 'active') {
            $row.status = 'not_active'
            $row.note = "정본의 상태가 active 가 아닙니다: $($lmeta.status)"
        } elseif ($lpkg) {
            $row.status = 'resolved'
        } elseif ($lremote) {
            # 설치할 패키지가 없는 것이 결함이 아니다. 원격 서버는 원래 그렇다.
            $row.status = 'resolved_remote'
            $row.note = "원격 서버다. 설치하지 않고 URL 로 연결한다: $($lremote.url)"
        } else {
            $row.status = 'resolved_no_package'
            $row.note = '레지스트리 항목에 설치 가능한 패키지도 원격 URL 도 없습니다(소스 빌드로 보인다).'
        }
    } elseif ($names.Count -gt 1) {
        $row.status = 'ambiguous'
        $row.note = "발행자가 일치하는 서버가 $($names.Count)개입니다. 사람이 골라야 합니다: $($names -join ', ')"
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
if ($knownAbsent.Count) {
    Write-Output "  건너뜀    : 레지스트리 부재 확인됨 $($knownAbsent.Count) 건 — $(($knownAbsent | ForEach-Object { $_.id }) -join ', ')"
    Write-Output '              (좌표를 확정하려면 레지스트리가 아닌 출처가 필요하다. 다시 확인하려면 -Recheck)'
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

# 카탈로그에 반영할 수 있는 것은 좌표가 확정된 것이다.
# 패키지든 원격 URL 이든 "어디에 연결하는가"가 정해졌으면 확정이다.
$resolved = @($results | Where-Object { $_.status -in @('resolved', 'resolved_remote') })
$unresolved = @($results | Where-Object { $_.status -notin @('resolved', 'resolved_remote') })

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
    Write-Output "카탈로그에 반영할 항목 $($resolved.Count)건 (발행자 일치 + 정본 active 만):"
    foreach ($r in $resolved) {
        if ($r.status -eq 'resolved_remote') {
            Write-Output ("  {0}  registry_lookup -> remote  {1}" -f $r.id, $r.url)
        } else {
            Write-Output ("  {0}  registry_lookup -> {1}  {2}@{3}" -f $r.id, $r.package_registry, $r.package, $r.version)
        }
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
        $install = [ordered]@{}
        if ($r.status -eq 'resolved_remote') {
            # 원격 서버는 설치하지 않는다. 버전은 레지스트리 항목의 버전일 뿐
            # 설치 좌표가 아니므로 provenance 안에만 남긴다.
            $install['kind'] = 'remote'
            $install['url'] = $r.url
            if ($r.transport) { $install['transport'] = $r.transport }
        } else {
            $install['kind'] = [string]$r.package_registry
            $install['package'] = $r.package
            $install['version'] = $r.version
        }
        # 없는 필드를 null 로 채우지 않는다. 카탈로그에 의미 없는 잡음이 쌓인다.
        if ($e.install.docs) { $install['docs'] = $e.install.docs }
        $install['registry'] = [ordered]@{
            name               = $r.registry_name
            version            = $r.version
            base               = $RegistryBase
            resolved_at        = (Get-HarnessUtcStamp)
            publisher_verified = $true
        }
        $e.install = [pscustomobject]$install
    }
    $catalog.updated_at = (Get-HarnessUtcStamp)
    Write-HarnessCatalog -Path $catalogPath -Catalog $catalog
    Write-Output "카탈로그를 갱신했습니다: $catalogPath"
    Write-Output '커밋 전에 .\scripts\Test-HarnessRepo.ps1 을 돌리세요.'
}

if (@($results | Where-Object status -eq 'lookup_failed').Count) { exit 3 }
if ($unresolved.Count) { exit 2 }
exit 0
