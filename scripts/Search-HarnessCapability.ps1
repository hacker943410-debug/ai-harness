[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Query,
    [ValidateSet('all', 'mcp', 'skill')]
    [string]$Type = 'all',
    [string]$HarnessRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$IncludeDiscoveryOnly
)

$ErrorActionPreference = 'Stop'
$resolvedHarness = (Resolve-Path -LiteralPath $HarnessRoot).Path
$terms = $Query.ToLowerInvariant().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)

function Read-Catalog([string]$relativePath, [string]$entryType) {
    $path = Join-Path $resolvedHarness $relativePath
    $catalog = Get-Content -Raw -Encoding utf8 -LiteralPath $path | ConvertFrom-Json
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
if ($Type -in @('all', 'mcp')) { $results += Read-Catalog 'catalogs\mcp-catalog.json' 'mcp' }
if ($Type -in @('all', 'skill')) { $results += Read-Catalog 'catalogs\skill-catalog.json' 'skill' }

$results | Sort-Object @{Expression = 'score'; Descending = $true}, @{Expression = 'official'; Descending = $true}, type, id
