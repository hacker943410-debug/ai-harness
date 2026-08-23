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

# ---------------------------------------------------------------------------
# 클라이언트 probe — 실제 상태를 읽는다
# ---------------------------------------------------------------------------

<#
    등록 여부만 보는 probe 는 쓸모가 없다.
    "등록돼 있다"와 "우리가 의도한 것이 등록돼 있다"는 다른 사건이고,
    이 PC 에서 실제로 갈라진 적이 있다(래퍼 .cmd 가 매니페스트에 없는 서비스를 켬).
    그래서 반드시 실제 command / args / env 를 읽어 온다.
    읽을 수 없으면 OK 가 아니라 parseable=$false 다.
#>
<#
    네이티브 명령의 stderr 를 2>&1 로 합치면 PS 5.1 은 각 줄을 ErrorRecord 로 감싼다
    (NativeCommandError). 호출자의 ErrorActionPreference 가 Stop 이면 그 순간 스크립트가 죽는다.

    "그런 서버 없다" 는 조회의 정상적인 답이지 예외가 아니다.
    실제로 이것 때문에 claude 에 서버가 없을 때 등록이 불가능했다.
    등록돼 있을 때만 동작하는 등록 스크립트였던 셈이다.
#>
function Invoke-HarnessClientCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Exe,
        [string[]]$Arguments = @()
    )
    $ErrorActionPreference = 'Continue'   # 함수 스코프. 호출자에게 영향 없다
    $out = & $Exe @Arguments 2>&1
    return [pscustomobject]@{ exit = $LASTEXITCODE; text = ($out | Out-String) }
}

<#
    표 형식 probe 는 "명령 + 인자"를 한 칸에 붙여서 준다.
      google-workspace  stdio  enabled  C:\...\google-workspace-mcp.cmd start
    공백으로 그냥 자르면 경로에 공백이 있는 PC 에서 틀린다.
    그래서 "실제로 존재하는 가장 긴 접두사"를 명령으로 본다.
    이것을 안 하면 command 에 ' start' 가 붙은 채로 비교되어 영원히 CHANGE 가 나고,
    정합 스크립트가 매번 재등록을 제안하게 된다.
#>
function Split-HarnessCommandAndArgs {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    $toks = @(($Text -split '\s+') | Where-Object { $_ })
    if ($toks.Count -eq 0) { return [pscustomobject]@{ command = $null; args = @() } }
    for ($n = $toks.Count; $n -ge 1; $n--) {
        $cand = ($toks[0..($n - 1)] -join ' ')
        if (Test-Path -LiteralPath $cand) {
            $rest = if ($n -lt $toks.Count) { @($toks[$n..($toks.Count - 1)]) } else { @() }
            return [pscustomobject]@{ command = $cand; args = $rest }
        }
    }
    $rest = if ($toks.Count -gt 1) { @($toks[1..($toks.Count - 1)]) } else { @() }
    return [pscustomobject]@{ command = $toks[0]; args = $rest }
}

function Read-HarnessClientRegistration {
    param(
        [Parameter(Mandatory = $true)]$Descriptor,
        [Parameter(Mandatory = $true)][string]$ServerName
    )
    $exe = Get-HarnessNativeCommand $Descriptor.detect.command
    # enabled 는 3상태다. $true / $false / $null(이 클라이언트로는 알 수 없음).
    # 알 수 없는 것을 "켜져 있음"으로 가정하면 없는 위험을 보고하거나 있는 위험을 놓친다.
    $res = [ordered]@{
        present = $false; command = $null; args = @()
        env = [ordered]@{}; env_parseable = $false; parseable = $false
        enabled = $null
    }
    if (-not $exe) { return [pscustomobject]$res }

    $sem = $Descriptor.probe_semantics
    switch ($sem.parse.kind) {
        'json_list' {
            $r = Invoke-HarnessClientCommand -Exe $exe -Arguments @($sem.parse.list_argv)
            if ($r.exit -ne 0) { return [pscustomobject]$res }
            $list = $null
            try { $list = $r.text | ConvertFrom-Json } catch { return [pscustomobject]$res }
            $hit = @($list | Where-Object { $_.($sem.parse.name_field) -eq $ServerName })
            if ($hit.Count -eq 0) { return [pscustomobject]$res }
            $res.present = $true
            $res.parseable = $true
            $res.command = $hit[0].transport.command
            $res.args = @($hit[0].transport.args)
            if ($hit[0].transport.PSObject.Properties.Name -contains 'env' -and $hit[0].transport.env) {
                foreach ($p in $hit[0].transport.env.PSObject.Properties) { $res.env[$p.Name] = [string]$p.Value }
                $res.env_parseable = $true
            }
            if ($sem.parse.enabled_field -and ($hit[0].PSObject.Properties.Name -contains $sem.parse.enabled_field)) {
                $res.enabled = [bool]$hit[0].($sem.parse.enabled_field)
            }
        }
        'kv_text' {
            $probeArgs = @($Descriptor.argv.probe) | ForEach-Object { $_.Replace('{server_name}', $ServerName) }
            $r = Invoke-HarnessClientCommand -Exe $exe -Arguments $probeArgs
            if ($r.exit -ne $sem.present_exit_code) { return [pscustomobject]$res }
            $res.present = $true

            # 환경변수는 "Environment:" 줄 뒤에 들여쓴 KEY=value 로 이어진다.
            # 그 줄의 꼬리만 읽으면 항상 비어 보이고, 선언한 키가 전부 ADD 로 나온다.
            # 즉 아무리 올바르게 등록해도 드리프트가 사라지지 않는다.
            $inEnv = $false
            foreach ($line in ($r.text -split "`r?`n")) {
                if ($inEnv) {
                    if ($line -match '^\s+([^=\s]+)=(.*)$') { $res.env[$Matches[1]] = $Matches[2].Trim(); continue }
                    $inEnv = $false   # 들여쓰기 블록이 끝났다
                }
                if ($line -match ([regex]::Escape($sem.parse.command_key) + '\s*(.+)$')) {
                    $res.command = $Matches[1].Trim(); $res.parseable = $true
                } elseif ($line -match ([regex]::Escape($sem.parse.args_key) + '\s*(.*)$')) {
                    $a = $Matches[1].Trim()
                    if ($a) { $res.args = @($a -split '\s+') }
                } elseif ($sem.parse.env_key -and $line -match ([regex]::Escape($sem.parse.env_key) + '\s*(.*)$')) {
                    # 빈 값도 "환경변수가 없다"는 실제 답이다. 읽었다는 사실 자체를 기록한다.
                    $res.env_parseable = $true
                    $inEnv = $true
                    foreach ($kv in (($Matches[1].Trim()) -split '[,\s]+')) {
                        if ($kv -match '^([^=]+)=(.*)$') { $res.env[$Matches[1]] = $Matches[2] }
                    }
                }
            }
        }
        'table_text' {
            $r = Invoke-HarnessClientCommand -Exe $exe -Arguments @($Descriptor.argv.list)
            foreach ($line in ($r.text -split "`r?`n")) {
                if ($line -match "^\s*$([regex]::Escape($ServerName))\s+") {
                    $res.present = $true
                    $cols = $line -split '\s{2,}'
                    if ($cols.Count -ge 2) {
                        $split = Split-HarnessCommandAndArgs -Text $cols[-1].Trim()
                        $res.command = $split.command
                        $res.args = @($split.args)
                        $res.parseable = [bool]$split.command
                    }
                    # 어느 칸이 상태인지 위치로 정하지 않는다. 열 순서가 바뀌면 조용히 틀린다.
                    # 선언된 표식과 값이 같은 칸을 찾는다.
                    foreach ($c in $cols) {
                        $v = $c.Trim().ToLowerInvariant()
                        if (@($sem.parse.disabled_markers) -contains $v) { $res.enabled = $false }
                        elseif (@($sem.parse.enabled_markers) -contains $v) { $res.enabled = $true }
                    }
                }
            }
        }
        default { }
    }
    return [pscustomobject]$res
}

# ---------------------------------------------------------------------------
# 3-way diff — 선언(Layer A) / 원장(Layer B) / 실제(클라이언트)
# ---------------------------------------------------------------------------

<#
    세 출처가 모두 필요하다. 둘만 보면 원인을 못 짚는다.
      선언 = runtimes/<id>.runtime.json    "무엇이어야 하는가"
      원장 = <tools_root>/runtimes.json    "설치 시점에 무엇으로 확정됐는가"
      실제 = 클라이언트 probe              "지금 무엇이 실행되는가"
    선언 != 원장  -> 매니페스트가 설치 뒤에 바뀌었다. 재설치가 필요하다.
    선언 != 실제  -> 등록이 낡았거나 제3자가 바꿨다. 재등록이 필요하다.
    실제에만 있는 값 -> REMOVE. 우리가 선언하지 않은 것이 켜져 있다는 뜻이라 따로 확인받는다.
#>
function Get-HarnessRegistrationDiff {
    param(
        [Parameter(Mandatory = $true)][string]$HarnessRoot,
        [Parameter(Mandatory = $true)][string]$ToolsRoot,
        [Parameter(Mandatory = $true)][string]$RuntimeId,
        [Parameter(Mandatory = $true)][string]$ClientId
    )

    $manifest = Get-HarnessRuntimeManifest -HarnessRoot $HarnessRoot -RuntimeId $RuntimeId
    $descriptor = Get-HarnessClientDescriptor -HarnessRoot $HarnessRoot -ClientId $ClientId
    $index = Read-HarnessRuntimeIndex -ToolsRoot $ToolsRoot
    $entry = Get-HarnessIndexEntry -Index $index -RuntimeId $RuntimeId

    $rows = [System.Collections.Generic.List[object]]::new()
    $result = [ordered]@{
        runtime_id = $RuntimeId; client_id = $ClientId
        client_installed = [bool](Get-HarnessNativeCommand $descriptor.detect.command)
        installed = [bool]$entry
        actual_readable = $false
        # $true 켜짐 / $false 꺼짐 / $null 이 클라이언트로는 알 수 없음
        actual_enabled = $null
        rows = @(); has_remove = $false; has_change = $false; ledger_drift = @()
    }
    if (-not $result.client_installed) { $result.rows = @(); return [pscustomobject]$result }

    # --- 선언 ---------------------------------------------------------------
    $params = Get-HarnessRuntimeParameters -Manifest $manifest
    $runtimeDir = if ($entry) { Join-HarnessPath $ToolsRoot $entry.install_dir } else { Join-HarnessPath $ToolsRoot $RuntimeId $manifest.install.version }
    $ctx = New-HarnessInterpolationContext -ToolsRoot $ToolsRoot -RuntimeDir $runtimeDir -Parameters $params
    $declEnv = Resolve-HarnessServerEnv -Manifest $manifest -Context $ctx
    $declArgs = @($manifest.server.args)
    $declCommand = if ($entry) { Join-HarnessPath $ToolsRoot $entry.command_rel } else { $null }

    # --- 원장 ---------------------------------------------------------------
    $recCommand = if ($entry) { Join-HarnessPath $ToolsRoot $entry.command_rel } else { $null }
    $recArgs = if ($entry) { @($entry.args) } else { @() }
    $recEnv = [ordered]@{}
    if ($entry -and $entry.env) { foreach ($p in $entry.env.PSObject.Properties) { $recEnv[$p.Name] = [string]$p.Value } }
    if ($entry -and $entry.installed_version -ne $manifest.install.version) {
        $result.ledger_drift += "installed_version=$($entry.installed_version) / 선언=$($manifest.install.version)"
    }
    foreach ($k in $declEnv.Keys) {
        if ($recEnv.Contains($k) -and $recEnv[$k] -ne $declEnv[$k]) {
            $result.ledger_drift += "env.$k 원장='$($recEnv[$k])' / 선언='$($declEnv[$k])'"
        }
    }

    # --- 실제 ---------------------------------------------------------------
    $actual = Read-HarnessClientRegistration -Descriptor $descriptor -ServerName $manifest.server_name
    $result.actual_readable = [bool]$actual.parseable
    $result.actual_enabled = $actual.enabled

    # 표시는 있는 그대로, 판정은 정규화한 값으로 한다.
    # 둘을 섞으면 "왜 다른지" 를 사람이 못 읽거나(정규화된 값만 보임),
    # 대소문자 차이만으로 영구 CHANGE 가 난다(원본만 비교함).
    function New-DiffRow {
        param([string]$Field, $Declared, $Recorded, $Actual, [bool]$ActualKnown, $DeclaredKey, $ActualKey)
        $d = if ($null -eq $Declared) { $null } else { [string]$Declared }
        $a = if ($null -eq $Actual) { $null } else { [string]$Actual }
        $dk = if ($null -ne $DeclaredKey) { [string]$DeclaredKey } else { $d }
        $ak = if ($null -ne $ActualKey) { [string]$ActualKey } else { $a }
        $verdict =
            if (-not $ActualKnown) { 'UNKNOWN' }
            elseif ([string]::IsNullOrEmpty($dk) -and -not [string]::IsNullOrEmpty($ak)) { 'REMOVE' }
            elseif (-not [string]::IsNullOrEmpty($dk) -and [string]::IsNullOrEmpty($ak)) { 'ADD' }
            elseif ($dk -eq $ak) { 'SAME' }
            else { 'CHANGE' }
        return [pscustomobject]@{
            field = $Field; declared = $d
            recorded = $(if ($null -eq $Recorded) { $null } else { [string]$Recorded })
            actual = $a; verdict = $verdict
        }
    }

    # 경로 비교는 대소문자·구분자 차이를 흡수해야 한다. 그렇지 않으면 영구 CHANGE 가 된다.
    $normDecl = if ($declCommand) { ([IO.Path]::GetFullPath($declCommand)).ToLowerInvariant() } else { $null }
    $normAct = $null
    if ($actual.command) {
        try { $normAct = ([IO.Path]::GetFullPath($actual.command)).ToLowerInvariant() } catch { $normAct = $actual.command.ToLowerInvariant() }
    }
    $rows.Add((New-DiffRow -Field 'command' -Declared $declCommand -Recorded $recCommand -Actual $actual.command `
        -ActualKnown $actual.parseable -DeclaredKey $normDecl -ActualKey $normAct))
    $rows.Add((New-DiffRow -Field 'args' -Declared ($declArgs -join ' ') -Recorded ($recArgs -join ' ') -Actual (@($actual.args) -join ' ') -ActualKnown $actual.parseable))

    $envKeys = @($declEnv.Keys) + @($actual.env.Keys) | Select-Object -Unique
    foreach ($k in $envKeys) {
        $dv = if ($declEnv.Contains($k)) { $declEnv[$k] } else { $null }
        $rv = if ($recEnv.Contains($k)) { $recEnv[$k] } else { $null }
        $av = if ($actual.env.Contains($k)) { $actual.env[$k] } else { $null }
        $rows.Add((New-DiffRow -Field "env.$k" -Declared $dv -Recorded $rv -Actual $av -ActualKnown $actual.env_parseable))
    }

    $result.rows = @($rows)
    $result.has_remove = @($rows | Where-Object verdict -eq 'REMOVE').Count -gt 0
    $result.has_change = @($rows | Where-Object { $_.verdict -in @('ADD', 'CHANGE', 'REMOVE') }).Count -gt 0
    return [pscustomobject]$result
}

# ---------------------------------------------------------------------------
# 실행 중인 클라이언트 세션
# ---------------------------------------------------------------------------

<#
    살아있는 CLI 세션이 있는 동안 등록을 바꾸면, 그 세션은 옛 등록으로 계속 돈다.
    "적용했다"와 "적용됐다"가 갈라지는 전형적인 지점이다.
    프로세스 이름만으로는 못 잡는다. claude / codex 는 node.exe 로 뜨기 때문에
    CommandLine 을 봐야 한다. 디스크립터가 process_match 를 주면 그것을 쓴다.
#>
function Get-HarnessRunningClientProcess {
    param(
        [Parameter(Mandatory = $true)][string]$HarnessRoot,
        [string[]]$ClientIds
    )
    if (-not $ClientIds) { $ClientIds = Get-HarnessClientIds -HarnessRoot $HarnessRoot }
    $procs = @()
    try { $procs = @(Get-CimInstance Win32_Process -ErrorAction Stop | Select-Object ProcessId, Name, CommandLine) }
    catch { return @() }

    $hits = [System.Collections.Generic.List[object]]::new()
    foreach ($cid in $ClientIds) {
        $d = $null
        try { $d = Get-HarnessClientDescriptor -HarnessRoot $HarnessRoot -ClientId $cid } catch { continue }
        $pattern = if ($d.detect.PSObject.Properties.Name -contains 'process_match' -and $d.detect.process_match) {
            [string]$d.detect.process_match
        } else {
            '[\\/]' + [regex]::Escape($d.detect.command) + '(\.exe|\.cmd|\.js|\.ps1)?("|\s|$)'
        }
        foreach ($p in $procs) {
            if (-not $p.CommandLine) { continue }
            if ($p.CommandLine -match $pattern) {
                $hits.Add([pscustomobject]@{
                    client = $cid; pid_ = $p.ProcessId; name = $p.Name
                    command_line = $p.CommandLine.Substring(0, [Math]::Min(160, $p.CommandLine.Length))
                })
            }
        }
    }
    return @($hits)
}

# ---------------------------------------------------------------------------
# 변경 계획 — 스키마의 단일 정의
# ---------------------------------------------------------------------------

<#
    계획을 만드는 스크립트가 여럿이므로(진단, 클라이언트 정합, 앞으로 추가될 것들)
    단계의 모양은 반드시 한 곳에서만 정의한다.
    스키마가 두 벌이 되면 적용자가 어느 한쪽을 조용히 무시하게 된다.

      step_id    안정적인 식별자. 사용자가 계획 파일에서 단계를 지목하는 열쇠다.
      kind       dir-create | acl-set | env-set | file-write | exec | manual
                 manual 은 적용자가 절대 실행하지 않는다(사람이 판단해야 하는 것).
      enabled    사용자가 false 로 바꾸면 그 단계와 그것에 의존하는 단계가 모두 빠진다.
      depends_on 계획 안에 없는 id 는 "이미 충족됨"으로 본다.
      payload    kind 별 실행 명세. 적용자가 문자열을 다시 파싱하지 않도록 구조화한다.
      undo       exec 는 되돌리는 방법을 스스로 알 수 없다. 여기에 없으면
                 롤백 시 "수동 확인 필요"로 남는다. 모르는 것을 안다고 하지 않는다.
#>
$script:HarnessPlanSchema = '1.0'

# ---------------------------------------------------------------------------
# 제약 고지 — 기술적으로 불가능한 것을 미리 말한다
# ---------------------------------------------------------------------------

<#
    어떤 클라이언트는 우리가 선언한 통제를 강제할 수단 자체가 없다.
    그것을 등록한 뒤에 경고하면, 사용자는 이미 노출된 상태에서 그 경고를 읽는다.
    설치 시점에 "이건 안 된다, 대신 이런 선택지가 있다"를 제시하고 사용자가 고르게 한다.

    제약은 코드가 아니라 클라이언트 디스크립터의 limitations 배열에 데이터로 선언한다.
    새 클라이언트의 새 제약을 추가하는 데 스크립트를 고쳐야 하면 설계가 틀린 것이다.

    applies_when.runtime_risk 가 있으면 그 위험도의 런타임에만 적용된다.
    없으면 항상 적용된다.
#>
function Get-HarnessClientLimitation {
    param(
        [Parameter(Mandatory = $true)][string]$HarnessRoot,
        [Parameter(Mandatory = $true)][string]$ClientId,
        [string]$RuntimeId,
        [string]$RuntimeRisk,
        [string]$ServerName
    )
    $d = $null
    try { $d = Get-HarnessClientDescriptor -HarnessRoot $HarnessRoot -ClientId $ClientId } catch { return @() }
    if ($d.PSObject.Properties.Name -notcontains 'limitations' -or -not $d.limitations) { return @() }

    $tokens = @{
        '{server_name}' = $ServerName
        '{client_id}'   = $ClientId
        '{runtime_id}'  = $RuntimeId
    }
    function Expand-Tokens { param([string]$s)
        if (-not $s) { return $s }
        foreach ($k in $tokens.Keys) { $s = $s.Replace($k, [string]$tokens[$k]) }
        return $s
    }

    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($lim in @($d.limitations)) {
        $aw = $lim.applies_when
        if ($aw -and ($aw.PSObject.Properties.Name -contains 'runtime_risk') -and @($aw.runtime_risk).Count) {
            if (-not $RuntimeRisk) { continue }
            if (@($aw.runtime_risk) -notcontains $RuntimeRisk) { continue }
        }
        $opts = @()
        foreach ($o in @($lim.options)) {
            $opts += [pscustomobject]@{
                id          = $o.id
                recommended = [bool]$o.recommended
                label       = Expand-Tokens ([string]$o.label)
                how         = Expand-Tokens ([string]$o.how)
                effect      = Expand-Tokens ([string]$o.effect)
            }
        }
        $out.Add([pscustomobject]@{
            client      = $ClientId
            runtime_id  = $RuntimeId
            id          = $lim.id
            severity    = [string]$lim.severity
            what        = Expand-Tokens ([string]$lim.what)
            why         = Expand-Tokens ([string]$lim.why)
            consequence = Expand-Tokens ([string]$lim.consequence)
            options     = @($opts)
        })
    }
    return @($out)
}

function Write-HarnessLimitationBlock {
    param([Parameter(Mandatory = $true)]$Limitations, [string]$Indent = '  ')
    foreach ($l in @($Limitations)) {
        Write-Output ("{0}[{1}] {2} — {3}" -f $Indent, $l.severity, $l.client, $l.what)
        Write-Output ("{0}    왜   : {1}" -f $Indent, $l.why)
        Write-Output ("{0}    결과 : {1}" -f $Indent, $l.consequence)
        Write-Output ("{0}    선택지:" -f $Indent)
        foreach ($o in @($l.options)) {
            # 표시 폭이 다른 문자를 앞에 두면 정렬이 깨진다. 표식은 뒤에 붙인다.
            $mark = if ($o.recommended) { '   <- 권장' } else { '' }
            Write-Output ("{0}      - {1}{2}" -f $Indent, $o.label, $mark)
            if ($o.how) { Write-Output ("{0}          {1}" -f $Indent, $o.how) }
            if ($o.effect) { Write-Output ("{0}          => {1}" -f $Indent, $o.effect) }
        }
        Write-Output ''
    }
}

function New-HarnessPlanStep {
    param(
        [Parameter(Mandatory = $true)][string]$StepId,
        [Parameter(Mandatory = $true)][ValidateSet('dir-create', 'acl-set', 'env-set', 'file-write', 'exec', 'manual')][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$Target,
        $Current, $Proposed,
        [string]$Risk = 'low',
        [string]$Note = '',
        [bool]$Optional = $false,
        [string[]]$DependsOn = @(),
        $Payload = $null,
        $Undo = $null,
        [string]$CommandLine = '',
        $Limitations = @()
    )
    return [pscustomobject]@{
        step_id      = $StepId
        kind         = $Kind
        action       = $Action
        target       = $Target
        current      = $Current
        proposed     = $Proposed
        risk         = $Risk
        note         = $Note
        optional     = $Optional
        enabled      = $true
        depends_on   = @($DependsOn)
        command_line = $CommandLine
        payload      = $Payload
        undo         = $Undo
        # 이 단계를 적용하면 사용자가 감수하게 되는 것. 적용자가 별도 동의를 받는다.
        limitations  = @($Limitations)
    }
}

function New-HarnessChangePlan {
    param(
        [Parameter(Mandatory = $true)][string]$HarnessRoot,
        [Parameter(Mandatory = $true)][string]$ToolsRoot,
        [string]$Overall = 'READY',
        $Blocks = @(),
        $Findings = @(),
        $Steps = @(),
        $Limitations = @()
    )
    # 계획 파일의 모양도 정의가 하나여야 한다. 생산자마다 따로 조립하면
    # 필드가 조용히 갈라지고, 소비자와 스키마는 어느 쪽이 정본인지 알 수 없게 된다.
    return [pscustomobject]@{
        schema_version = $script:HarnessPlanSchema
        kind           = 'harness-change-plan'
        overall        = $Overall
        checked_at     = (Get-HarnessUtcStamp)
        harness_root   = $HarnessRoot
        tools_root     = $ToolsRoot
        blocks         = @($Blocks)
        findings       = @($Findings)
        limitations    = @($Limitations)
        plan           = @($Steps)
    }
}

<#
    exec 단계는 자식 powershell 로 돌린다.
    인프로세스 호출은 하위 스크립트의 exit 와 ErrorActionPreference 가 적용자에게 새어 들어오고,
    사용자가 본 명령줄과 실제로 일어난 일이 달라진다.
#>
function New-HarnessScriptExec {
    param(
        [Parameter(Mandatory = $true)][string]$HarnessRoot,
        [Parameter(Mandatory = $true)][string]$ScriptName,
        [string[]]$ScriptArgs = @()
    )
    $psExe = (Get-Process -Id $PID).Path
    if (-not $psExe) { $psExe = 'powershell.exe' }
    $script = Join-HarnessPath $HarnessRoot 'scripts' $ScriptName
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script) + @($ScriptArgs)
    $quoted = $argv | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
    return [pscustomobject]@{
        file         = $psExe
        arguments    = @($argv)
        command_line = "$psExe $($quoted -join ' ')"
    }
}

<#
    (런타임 x 클라이언트) 한 칸에 대한 등록/해제 단계.
    진단과 클라이언트 정합이 같은 단계를 만들어야 하므로 여기서 한 번만 정의한다.
#>
function New-HarnessRegistrationStep {
    param(
        [Parameter(Mandatory = $true)][string]$HarnessRoot,
        [Parameter(Mandatory = $true)][string]$ToolsRoot,
        [Parameter(Mandatory = $true)][string]$RuntimeId,
        [Parameter(Mandatory = $true)][string]$ClientId,
        [Parameter(Mandatory = $true)][ValidateSet('register', 'unregister')][string]$Mode,
        [string]$Current = '',
        [string]$Note = '',
        [string]$Risk = 'medium',
        [bool]$Optional = $true
    )
    $m = Get-HarnessRuntimeManifest -HarnessRoot $HarnessRoot -RuntimeId $RuntimeId
    $d = Get-HarnessClientDescriptor -HarnessRoot $HarnessRoot -ClientId $ClientId
    $scope = if ($d.supports.default_scope) { $d.supports.default_scope } else { '' }
    $values = @{ server_name = $m.server_name; scope = $scope }
    $clientExe = Get-HarnessNativeCommand $d.detect.command
    $rmArgv = Expand-HarnessArgv -Template @($d.argv.remove) -Values $values

    $regArgs = @('-RuntimeId', $RuntimeId, '-Client', $ClientId, '-ToolsRoot', $ToolsRoot, '-Force')
    if ($m.risk -eq 'high') { $regArgs += '-IAcceptRisk' }
    $regExec = New-HarnessScriptExec -HarnessRoot $HarnessRoot -ScriptName 'Register-HarnessRuntimeClient.ps1' -ScriptArgs $regArgs
    $rmExec = [pscustomobject]@{
        kind = 'exec'; file = $clientExe; arguments = @($rmArgv)
        command_line = "$($d.detect.command) $($rmArgv -join ' ')"
    }

    $limits = @(Get-HarnessClientLimitation -HarnessRoot $HarnessRoot -ClientId $ClientId `
        -RuntimeId $RuntimeId -RuntimeRisk ([string]$m.risk) -ServerName $m.server_name)

    if ($Mode -eq 'register') {
        $note = $Note
        if ($m.risk -eq 'high') {
            $note += "  [risk=high — 명령에 -IAcceptRisk 가 들어 있다. 차단 도구: $(@($m.tool_policy.deny) -join ', ')]"
        }
        $hardLimits = @($limits | Where-Object severity -eq 'high')
        if ($hardLimits.Count) {
            $note += "  [제약: $(($hardLimits | ForEach-Object { $_.what }) -join '; ') — 적용 시 별도 동의를 받는다]"
        }
        return New-HarnessPlanStep -StepId "client.register:$ClientId`:$RuntimeId" -Kind 'exec' -Limitations $limits `
            -Action '클라이언트 등록' -Target "$ClientId <- $RuntimeId" `
            -Current $Current -Proposed "$($m.server_name) 를 scope=$scope 로 등록" `
            -Risk $Risk -Optional $Optional -DependsOn @("runtime.install:$RuntimeId") -Note $note.Trim() `
            -CommandLine $regExec.command_line `
            -Payload ([pscustomobject]@{
                file = $regExec.file; arguments = $regExec.arguments
                # 적용 직전에 선언/원장/실제를 다시 대조하게 하는 힌트.
                # 적용자가 런타임별 코드를 갖지 않도록 데이터로 넘긴다.
                diff = [pscustomobject]@{ kind = 'registration'; runtime_id = $RuntimeId; client_id = $ClientId }
            }) `
            -Undo $rmExec
    }

    return New-HarnessPlanStep -StepId "client.unregister:$ClientId`:$RuntimeId" -Kind 'exec' `
        -Action '클라이언트 등록 해제' -Target "$ClientId -> $($m.server_name)" `
        -Current $Current -Proposed '등록 제거' -Risk $Risk -Optional $Optional -Note $Note `
        -CommandLine $rmExec.command_line `
        -Payload ([pscustomobject]@{ file = $clientExe; arguments = @($rmArgv) }) `
        -Undo ([pscustomobject]@{
            kind = 'exec'; file = $regExec.file; arguments = $regExec.arguments; command_line = $regExec.command_line
        })
}
