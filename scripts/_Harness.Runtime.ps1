#Requires -Version 5.1
<#
    AI Harness — 공용 런타임 계층 헬퍼

    Layer A(매니페스트) 와 Layer B(runtimes.json / clients.json) 사이의 계약을 담는다.
    런타임별 특수 코드를 두지 않는다. 새 런타임 추가는 runtimes/<id>.runtime.json 하나면 된다.

    사용:
        . (Join-Path $PSScriptRoot '_Harness.Runtime.ps1')
#>

. (Join-Path $PSScriptRoot '_Harness.Common.ps1')

$script:HarnessRuntimeIndexSchema = '2.0'
$script:HarnessClientRegistrySchema = '2.0'

# ---------------------------------------------------------------------------
# Layer A — 매니페스트 / 디스크립터
# ---------------------------------------------------------------------------

function Get-HarnessRuntimeManifestPath {
    param([Parameter(Mandatory = $true)][string]$HarnessRoot, [Parameter(Mandatory = $true)][string]$RuntimeId)
    return (Join-HarnessPath $HarnessRoot 'runtimes' "$RuntimeId.runtime.json")
}

function Get-HarnessRuntimeManifest {
    param([Parameter(Mandatory = $true)][string]$HarnessRoot, [Parameter(Mandatory = $true)][string]$RuntimeId)
    $p = Get-HarnessRuntimeManifestPath -HarnessRoot $HarnessRoot -RuntimeId $RuntimeId
    if (-not (Test-Path -LiteralPath $p)) { throw "런타임 매니페스트가 없습니다: $p" }
    $m = Read-HarnessJson -Path $p
    if ($m.runtime_id -ne $RuntimeId) {
        throw "매니페스트의 runtime_id('$($m.runtime_id)')가 파일명('$RuntimeId')과 다릅니다."
    }
    return $m
}

function Get-HarnessRuntimeIds {
    param([Parameter(Mandatory = $true)][string]$HarnessRoot)
    $dir = Join-HarnessPath $HarnessRoot 'runtimes'
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    return @(Get-ChildItem $dir -Filter '*.runtime.json' -File |
        Where-Object { -not $_.Name.StartsWith('_') } |
        ForEach-Object { $_.Name -replace '\.runtime\.json$', '' })
}

function Get-HarnessClientDescriptor {
    param([Parameter(Mandatory = $true)][string]$HarnessRoot, [Parameter(Mandatory = $true)][string]$ClientId)
    $p = Join-HarnessPath $HarnessRoot 'settings' 'clients' "$ClientId.client.json"
    if (-not (Test-Path -LiteralPath $p)) { throw "클라이언트 디스크립터가 없습니다: $p" }
    return (Read-HarnessJson -Path $p)
}

function Get-HarnessClientIds {
    param([Parameter(Mandatory = $true)][string]$HarnessRoot)
    $dir = Join-HarnessPath $HarnessRoot 'settings' 'clients'
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    return @(Get-ChildItem $dir -Filter '*.client.json' -File | ForEach-Object { $_.Name -replace '\.client\.json$', '' })
}

# ---------------------------------------------------------------------------
# 보간 — 닫힌 집합만 허용한다
# ---------------------------------------------------------------------------

<#
    매니페스트에는 절대경로를 쓸 수 없다. 대신 ${...} 로만 표현하고
    여기서 이 머신의 실제 값으로 바꾼다.
    허용 키: HOME, CONFIG_HOME, TOOLS_ROOT, RUNTIME_DIR + 선언된 parameters 키.
    알 수 없는 키가 남아 있으면 조용히 통과시키지 않고 예외를 던진다.
#>
function Resolve-HarnessInterpolation {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value,
        [Parameter(Mandatory = $true)][hashtable]$Context
    )
    if ([string]::IsNullOrEmpty($Value)) { return $Value }
    $out = $Value
    foreach ($k in $Context.Keys) {
        $out = $out.Replace('${' + $k + '}', [string]$Context[$k])
    }
    if ($out -match '\$\{([^}]+)\}') {
        throw "매니페스트에 해석할 수 없는 보간 키가 있습니다: `${$($Matches[1])}"
    }
    return $out
}

function Get-HarnessRuntimeParameters {
    param([Parameter(Mandatory = $true)]$Manifest, [hashtable]$Override)
    $params = @{}
    if ($Manifest.PSObject.Properties.Name -contains 'parameters' -and $Manifest.parameters) {
        foreach ($p in $Manifest.parameters.PSObject.Properties) {
            $params[$p.Name] = $p.Value.default
        }
    }
    if ($Override) { foreach ($k in $Override.Keys) { $params[$k] = $Override[$k] } }
    return $params
}

function New-HarnessInterpolationContext {
    param([Parameter(Mandatory = $true)][string]$ToolsRoot, [string]$RuntimeDir, [hashtable]$Parameters)
    $ctx = @{
        HOME        = (Get-HarnessHome)
        CONFIG_HOME = (Get-HarnessConfigHome)
        TOOLS_ROOT  = $ToolsRoot
        RUNTIME_DIR = $RuntimeDir
    }
    if ($Parameters) { foreach ($k in $Parameters.Keys) { $ctx[$k] = $Parameters[$k] } }
    return $ctx
}

function Resolve-HarnessServerEnv {
    param([Parameter(Mandatory = $true)]$Manifest, [Parameter(Mandatory = $true)][hashtable]$Context)
    $env = [ordered]@{}
    if ($Manifest.server -and $Manifest.server.PSObject.Properties.Name -contains 'env' -and $Manifest.server.env) {
        foreach ($p in $Manifest.server.env.PSObject.Properties) {
            $env[$p.Name] = Resolve-HarnessInterpolation -Value ([string]$p.Value) -Context $Context
        }
    }
    return $env
}

# ---------------------------------------------------------------------------
# Layer B — runtimes.json / clients.json
# ---------------------------------------------------------------------------

function Get-HarnessRuntimeIndexPath { param([Parameter(Mandatory = $true)][string]$ToolsRoot); return (Join-HarnessPath $ToolsRoot 'runtimes.json') }
function Get-HarnessClientRegistryPath { param([Parameter(Mandatory = $true)][string]$ToolsRoot); return (Join-HarnessPath $ToolsRoot 'clients.json') }

function Read-HarnessRuntimeIndex {
    param([Parameter(Mandatory = $true)][string]$ToolsRoot)
    $p = Get-HarnessRuntimeIndexPath -ToolsRoot $ToolsRoot
    if (-not (Test-Path -LiteralPath $p)) {
        return [pscustomobject]@{
            schema_version = $script:HarnessRuntimeIndexSchema
            tools_root     = $ToolsRoot
            updated_at     = $null
            runtimes       = [pscustomobject]@{}
        }
    }
    $idx = Read-HarnessJson -Path $p
    if ($idx.schema_version -ne $script:HarnessRuntimeIndexSchema) {
        throw "runtimes.json 스키마 버전이 호환되지 않습니다: $($idx.schema_version) (기대: $script:HarnessRuntimeIndexSchema). 부트스트랩을 다시 실행하세요."
    }
    return $idx
}

function Write-HarnessRuntimeIndex {
    param([Parameter(Mandatory = $true)][string]$ToolsRoot, [Parameter(Mandatory = $true)]$Index)
    $Index.updated_at = Get-HarnessUtcStamp
    Write-HarnessJson -Path (Get-HarnessRuntimeIndexPath -ToolsRoot $ToolsRoot) -InputObject $Index -Depth 12
}

function Get-HarnessIndexEntry {
    param([Parameter(Mandatory = $true)]$Index, [Parameter(Mandatory = $true)][string]$RuntimeId)
    if (-not $Index.runtimes) { return $null }
    $prop = $Index.runtimes.PSObject.Properties | Where-Object Name -eq $RuntimeId
    if (-not $prop) { return $null }
    return $prop.Value
}

function Set-HarnessIndexEntry {
    param([Parameter(Mandatory = $true)]$Index, [Parameter(Mandatory = $true)][string]$RuntimeId, [Parameter(Mandatory = $true)]$Entry)
    if (-not $Index.runtimes) { $Index | Add-Member -NotePropertyName runtimes -NotePropertyValue ([pscustomobject]@{}) -Force }
    if ($Index.runtimes.PSObject.Properties.Name -contains $RuntimeId) {
        $Index.runtimes.$RuntimeId = $Entry
    } else {
        $Index.runtimes | Add-Member -NotePropertyName $RuntimeId -NotePropertyValue $Entry
    }
}

function Read-HarnessClientRegistry {
    param([Parameter(Mandatory = $true)][string]$ToolsRoot)
    $p = Get-HarnessClientRegistryPath -ToolsRoot $ToolsRoot
    if (-not (Test-Path -LiteralPath $p)) {
        return [pscustomobject]@{ schema_version = $script:HarnessClientRegistrySchema; updated_at = $null; registrations = @() }
    }
    return (Read-HarnessJson -Path $p)
}

function Write-HarnessClientRegistry {
    param([Parameter(Mandatory = $true)][string]$ToolsRoot, [Parameter(Mandatory = $true)]$Registry)
    $Registry.updated_at = Get-HarnessUtcStamp
    Write-HarnessJson -Path (Get-HarnessClientRegistryPath -ToolsRoot $ToolsRoot) -InputObject $Registry -Depth 12
}

# ---------------------------------------------------------------------------
# 지문
# ---------------------------------------------------------------------------

<#
    등록 상태가 바뀌었는지 판정하는 값.
    env 의 "값"도 포함해야 한다. GOOGLE_WORKSPACE_MCP_PROFILE 의 값은
    어떤 Google 계정으로 동작할지를 결정하는 인가 결정 그 자체이기 때문이다.
    다만 값을 평문으로 남기면 원장이 비밀을 흘릴 수 있으므로,
    머신 고유 키로 HMAC 을 걸어 저장한다. 키는 이 PC 를 떠나지 않는다.
#>
function Get-HarnessCommandFingerprint {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @(),
        $Env = $null,
        [string]$MachineKey = ''
    )
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append(([IO.Path]::GetFullPath($Command)).ToLowerInvariant())
    foreach ($a in $Arguments) { [void]$sb.Append("`0"); [void]$sb.Append($a) }
    if ($Env) {
        $names = @()
        if ($Env -is [hashtable] -or $Env -is [System.Collections.Specialized.OrderedDictionary]) { $names = @($Env.Keys) }
        else { $names = @($Env.PSObject.Properties.Name) }
        foreach ($k in ($names | Sort-Object)) {
            $v = if ($Env -is [hashtable] -or $Env -is [System.Collections.Specialized.OrderedDictionary]) { $Env[$k] } else { $Env.$k }
            [void]$sb.Append("`0"); [void]$sb.Append($k); [void]$sb.Append('='); [void]$sb.Append([string]$v)
        }
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes($sb.ToString())
    if ($MachineKey) {
        $h = New-Object System.Security.Cryptography.HMACSHA256
        $h.Key = [Text.Encoding]::UTF8.GetBytes($MachineKey)
        return 'hmac-sha256:' + ([BitConverter]::ToString($h.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant()
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return 'sha256:' + ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant()
}

function Get-HarnessToolsRootId {
    param([Parameter(Mandatory = $true)][string]$ToolsRoot)
    $p = Join-HarnessPath $ToolsRoot 'tools-root.id'
    if (Test-Path -LiteralPath $p) { return (Read-HarnessText -Path $p).Trim() }
    $id = [guid]::NewGuid().ToString()
    Write-HarnessText -Path $p -Text $id
    return $id
}

# ---------------------------------------------------------------------------
# argv 템플릿 전개
# ---------------------------------------------------------------------------

<#
    디스크립터의 argv 템플릿을 실제 인자 배열로 만든다.
    치환 토큰:
      {server_name} {command} {scope}
      {args}       -> 런타임 args 배열로 펼쳐짐 (없으면 토큰 자체가 사라짐)
      {env_flags}  -> env_flag_template 을 쌍마다 반복 (없으면 토큰 자체가 사라짐)
#>
function Expand-HarnessArgv {
    param(
        [Parameter(Mandatory = $true)][string[]]$Template,
        [Parameter(Mandatory = $true)][hashtable]$Values,
        [string[]]$RuntimeArgs = @(),
        $EnvPairs = $null,
        [string[]]$EnvFlagTemplate = @()
    )
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($tok in $Template) {
        switch ($tok) {
            '{args}' {
                foreach ($a in $RuntimeArgs) { $out.Add([string]$a) }
                continue
            }
            '{env_flags}' {
                if ($EnvPairs -and $EnvFlagTemplate.Count -gt 0) {
                    $names = if ($EnvPairs -is [hashtable] -or $EnvPairs -is [System.Collections.Specialized.OrderedDictionary]) { @($EnvPairs.Keys) } else { @($EnvPairs.PSObject.Properties.Name) }
                    foreach ($k in $names) {
                        $v = if ($EnvPairs -is [hashtable] -or $EnvPairs -is [System.Collections.Specialized.OrderedDictionary]) { $EnvPairs[$k] } else { $EnvPairs.$k }
                        foreach ($ft in $EnvFlagTemplate) {
                            $out.Add($ft.Replace('{key}', $k).Replace('{value}', [string]$v))
                        }
                    }
                }
                continue
            }
            default {
                $s = $tok
                foreach ($k in $Values.Keys) { $s = $s.Replace('{' + $k + '}', [string]$Values[$k]) }
                if ($s -match '^\{[a-z_]+\}$') { continue }   # 값이 없는 토큰은 버린다
                $out.Add($s)
            }
        }
    }
    return $out.ToArray()
}
