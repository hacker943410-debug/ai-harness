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
function Invoke-HarnessClientCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Exe,
        [string[]]$Arguments = @()
    )
    $out = & $Exe @Arguments 2>&1
    return [pscustomobject]@{ exit = $LASTEXITCODE; text = ($out | Out-String) }
}

function Read-HarnessClientRegistration {
    param(
        [Parameter(Mandatory = $true)]$Descriptor,
        [Parameter(Mandatory = $true)][string]$ServerName
    )
    $exe = Get-HarnessNativeCommand $Descriptor.detect.command
    $res = [ordered]@{
        present = $false; command = $null; args = @()
        env = [ordered]@{}; env_parseable = $false; parseable = $false
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
        }
        'kv_text' {
            $probeArgs = @($Descriptor.argv.probe) | ForEach-Object { $_.Replace('{server_name}', $ServerName) }
            $r = Invoke-HarnessClientCommand -Exe $exe -Arguments $probeArgs
            if ($r.exit -ne $sem.present_exit_code) { return [pscustomobject]$res }
            $res.present = $true
            foreach ($line in ($r.text -split "`r?`n")) {
                if ($line -match ([regex]::Escape($sem.parse.command_key) + '\s*(.+)$')) {
                    $res.command = $Matches[1].Trim(); $res.parseable = $true
                } elseif ($line -match ([regex]::Escape($sem.parse.args_key) + '\s*(.*)$')) {
                    $a = $Matches[1].Trim()
                    if ($a) { $res.args = @($a -split '\s+') }
                } elseif ($sem.parse.env_key -and $line -match ([regex]::Escape($sem.parse.env_key) + '\s*(.*)$')) {
                    # 빈 값도 "환경변수가 없다"는 실제 답이다. 읽었다는 사실 자체를 기록한다.
                    $res.env_parseable = $true
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
                    if ($cols.Count -ge 2) { $res.command = $cols[-1].Trim(); $res.parseable = $true }
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
