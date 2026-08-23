[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Query,
    [ValidateSet('all', 'mcp', 'skill')]
    [string]$Type = 'all',
    [string]$HarnessRoot,
    [switch]$IncludeDiscoveryOnly
)

# [CmdletBinding()] 가 있으면 PS 5.1 은 param 기본값 평가 시 $PSScriptRoot 를 비워 둔다.
if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Common.ps1')

$resolvedHarness = (Resolve-Path -LiteralPath $HarnessRoot).Path
$terms = $Query.ToLowerInvariant().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)

function Read-Catalog([string]$catalogFile, [string]$entryType) {
    $path = Join-HarnessPath $resolvedHarness 'catalogs' $catalogFile
    $catalog = Read-HarnessJson -Path $path
    foreach ($entry in $catalog.entries) {
        if (-not $IncludeDiscoveryOnly -and $entry.status -eq 'discovery_only') { continue }
        $searchParts = @($entry.id, $entry.name, $entry.source, $entry.publisher)
        $searchParts += @($entry.capabilities)
        $searchParts += @($entry.domains)
        $searchable = $searchParts -join ' '
        $normalized = $searchable.ToLowerInvariant().Replace('_', ' ').Replace('-', ' ')
        $score = 0
        foreach ($term in $terms) {
            if ($normalized.Contains($term)) { $score++ }
        }
        if ($score -eq $terms.Count) {
            [pscustomobject]@{
                type = $entryType
                id = $entry.id
                name = if ($entry.name) { $entry.name } else { $entry.id }
                status = $entry.status
                official = [bool]$entry.official
                risk = if ($entry.risk) { $entry.risk } else { 'unclassified' }
                source = if ($entry.source) { $entry.source } elseif ($entry.install.docs) { $entry.install.docs } else { $entry.publisher }
                capabilities = @($entry.capabilities) -join ', '
                score = $score
            }
        }
    }
}

$results = @()
if ($Type -in @('all', 'mcp')) { $results += Read-Catalog 'mcp-catalog.json' 'mcp' }
if ($Type -in @('all', 'skill')) { $results += Read-Catalog 'skill-catalog.json' 'skill' }

$results | Sort-Object @{Expression = 'score'; Descending = $true}, @{Expression = 'official'; Descending = $true}, type, id
