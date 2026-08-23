#Requires -Version 5.1
<#
    AI Harness — 저장소 자체 검사

    목적: M6 에서 고친 버그 유형이 다시 들어오지 못하게 막는다.
    규칙은 문서가 아니라 검사로 강제한다.

    사용:
        .\scripts\Test-HarnessRepo.ps1
        .\scripts\Test-HarnessRepo.ps1 -Quick     # 소스 lint 만
        .\scripts\Test-HarnessRepo.ps1 -Json

    종료 코드: 0 = PASS / PASS_WITH_INFO,  1 = FAIL,  2 = 검사기 자체 오류

    주의: 이 파일 자신은 소스 lint 대상에서 제외한다.
          검사 패턴을 문자열로 담고 있어 스스로 걸리기 때문이다.
#>
[CmdletBinding()]
param(
    [string]$HarnessRoot,
    [switch]$Quick,
    [switch]$Json
)

# [CmdletBinding()] 가 있으면 Windows PowerShell 5.1 은 param 기본값을 평가할 때
# $PSScriptRoot 를 비워 둔다. 따라서 기본값은 param 이 아니라 본문에서 정한다.
if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Common.ps1')
Initialize-HarnessConsole

$root = (Resolve-Path -LiteralPath $HarnessRoot).Path
$issues = [System.Collections.Generic.List[object]]::new()
function Add-Issue([string]$severity, [string]$code, [string]$message) {
    $issues.Add([pscustomobject]@{ severity = $severity; code = $code; message = $message })
}

$selfName = 'Test-HarnessRepo.ps1'
$scriptFiles = Get-ChildItem (Join-HarnessPath $root 'scripts') -Filter '*.ps1' -File |
    Where-Object { $_.Name -ne $selfName }

# ---------------------------------------------------------------------------
# 1. .ps1 인코딩 — UTF-8 with BOM
# ---------------------------------------------------------------------------
# Windows PowerShell 5.1 은 BOM 이 없으면 소스를 ANSI 코드페이지로 디코딩한다.
# 이 PC 는 949 이므로 한글 문자열이 깨지거나 파서 오류가 난다.
foreach ($f in $scriptFiles) {
    $b = [IO.File]::ReadAllBytes($f.FullName)
    if ($b.Length -lt 3 -or $b[0] -ne 0xEF -or $b[1] -ne 0xBB -or $b[2] -ne 0xBF) {
        Add-Issue 'FAIL' 'PS1_NO_BOM' "$($f.Name) 에 UTF-8 BOM 이 없습니다."
    }
}

# ---------------------------------------------------------------------------
# 2. 소스 lint — 경로/인코딩/시각 관용구
# ---------------------------------------------------------------------------
$dq = [char]34
foreach ($f in $scriptFiles) {
    $text = Read-HarnessText -Path $f.FullName
    $lines = $text -split "`r?`n"
    $inBlockComment = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $no = $i + 1

        # 주석은 규칙을 "설명"하기 위해 금지 패턴을 그대로 인용한다. lint 대상이 아니다.
        # 한 줄 주석뿐 아니라 <# #> 블록 주석도 건너뛰어야 한다.
        if ($inBlockComment) {
            if ($line -match '#>') { $inBlockComment = $false }
            continue
        }
        if ($line -match '<#') {
            if ($line -notmatch '#>') { $inBlockComment = $true }
            continue
        }
        if ($line.TrimStart().StartsWith('#')) { continue }

        # Join-Path 의 2번째 인자에 구분자가 든 리터럴이 오면 재정규화되지 않는다.
        # 유닉스에서 '백슬래시가 든 파일명 하나'가 만들어진다.
        if ($line -match 'Join-Path' -and $line -match "('[^']*[\\/][^']*'|$dq[^$dq]*[\\/][^$dq]*$dq)") {
            Add-Issue 'FAIL' 'JOIN_PATH_LITERAL' "$($f.Name):$no  Join-Path 에 구분자가 든 리터럴. Join-HarnessPath 를 쓰세요."
        }
        # Get-Content 는 인코딩을 명시하지 않으면 5.1 에서 ANSI 로 디코딩한다.
        if ($line -match 'Get-Content' -and $line -notmatch '-Encoding') {
            Add-Issue 'FAIL' 'BARE_GET_CONTENT' "$($f.Name):$no  인코딩 미지정 Get-Content. Read-HarnessJson / Read-HarnessText 를 쓰세요."
        }
        # PS 5.1 의 -Encoding utf8 은 BOM 을 붙인다. JSON 소비자는 선행 BOM 을 거부한다.
        if ($line -match 'Set-Content' -and $line -match '-Encoding\s+utf8') {
            Add-Issue 'FAIL' 'SET_CONTENT_UTF8_BOM' "$($f.Name):$no  Set-Content -Encoding utf8 은 5.1 에서 BOM 을 붙입니다. Write-HarnessJson / Write-HarnessText 를 쓰세요."
        }
        # 로컬 오프셋은 커밋되는 lock 파일을 계속 흔든다.
        if ($line -match '\[DateTimeOffset\]::Now') {
            Add-Issue 'FAIL' 'LOCAL_TIMESTAMP' "$($f.Name):$no  로컬 시각. Get-HarnessUtcStamp 를 쓰세요."
        }
        # 구문 오류로 조용히 무력화되는 가드를 막는다.
        if ($line -match 'Test-Path[^\r\n]*\s-and\s' -and $line -notmatch '\)\s*-and') {
            Add-Issue 'FAIL' 'TEST_PATH_AND' "$($f.Name):$no  Test-Path 뒤의 -and 는 파라미터로 바인딩됩니다. 괄호로 묶으세요."
        }
    }

}

# ---------------------------------------------------------------------------
# 3. 구문 파싱
# ---------------------------------------------------------------------------
foreach ($f in $scriptFiles) {
    $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
    if ($errs -and $errs.Count) {
        Add-Issue 'FAIL' 'PARSE_ERROR' "$($f.Name) 구문 오류 $($errs.Count)건: $($errs[0].Message)"
        continue
    }

    # [CmdletBinding()] 가 있으면 Windows PowerShell 5.1 은 param 기본값을 평가할 때
    # $PSScriptRoot 를 비워 둔다. 구문 파싱만으로는 드러나지 않고 실행해야 터진다.
    # 2.1 부터 4개 스크립트에 있던 잠재 버그이며, AST 로 정확히 잡는다.
    if ($ast -and $ast.ParamBlock) {
        $pb = $ast.ParamBlock
        $hasBinding = @($pb.Attributes | Where-Object { "$($_.TypeName.Name)" -match 'CmdletBinding' }).Count -gt 0
        if ($hasBinding -and $pb.Extent.Text -match '\$PSScriptRoot') {
            Add-Issue 'FAIL' 'PSSCRIPTROOT_IN_PARAM' ("$($f.Name)  [CmdletBinding()] 스크립트의 param 기본값에서 " +
                '$PSScriptRoot 를 쓰면 5.1 에서 빈 문자열이 됩니다. 본문에서 기본값을 정하세요.')
        }
    }
}

if (-not $Quick) {

    # -----------------------------------------------------------------------
    # 4. POLICY_INDEX 와 policies/ 의 실제 일치
    # -----------------------------------------------------------------------
    # Fast Health Check 가 개수만 보고 HEALTHY 를 보고한 뒤,
    # 정작 정책을 열려는 순간 BLOCKED 가 되는 상황을 막는다.
    $indexPath = Join-HarnessPath $root 'POLICY_INDEX.yaml'
    if (-not (Test-Path -LiteralPath $indexPath)) {
        Add-Issue 'FAIL' 'INDEX_MISSING' 'POLICY_INDEX.yaml 이 없습니다.'
    } else {
        $indexText = Read-HarnessText -Path $indexPath
        $declared = if ($indexText -match 'policy_count:\s*(\d+)') { [int]$Matches[1] } else { -1 }
        $fileRefs = [regex]::Matches($indexText, '(?m)^\s*file:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
        $policyDir = Join-HarnessPath $root 'policies'
        $onDisk = @(Get-ChildItem $policyDir -Filter '*.md' -File -ErrorAction SilentlyContinue)

        if ($declared -ne $fileRefs.Count) {
            Add-Issue 'FAIL' 'INDEX_COUNT_MISMATCH' "policy_count=$declared 인데 file: 항목은 $($fileRefs.Count)개입니다."
        }
        if ($declared -ne $onDisk.Count) {
            Add-Issue 'FAIL' 'POLICY_COUNT_MISMATCH' "policy_count=$declared 인데 policies/ 의 .md 는 $($onDisk.Count)개입니다."
        }
        $missing = 0
        foreach ($ref in $fileRefs) {
            $p = Join-HarnessPath $policyDir $ref
            if (-not (Test-Path -LiteralPath $p)) {
                Add-Issue 'FAIL' 'POLICY_FILE_MISSING' "POLICY_INDEX 가 가리키는 파일이 없습니다: $ref"
                $missing++
            }
        }
        if ($missing -eq 0) {
            Add-Issue 'INFO' 'POLICY_INDEX_OK' "정책 $($fileRefs.Count)개가 모두 디스크에서 해석됩니다 (policy_count=$declared)."
        }
    }

    # -----------------------------------------------------------------------
    # 5. 카탈로그 파싱 / 중복 ID / 버전 핀
    # -----------------------------------------------------------------------
    foreach ($name in @('mcp-catalog.json', 'skill-catalog.json')) {
        $p = Join-HarnessPath $root 'catalogs' $name
        if (-not (Test-Path -LiteralPath $p)) { Add-Issue 'FAIL' 'CATALOG_MISSING' "$name 없음"; continue }
        try {
            $cat = Read-HarnessJson -Path $p
            $dups = @($cat.entries | Group-Object id | Where-Object Count -gt 1)
            foreach ($d in $dups) { Add-Issue 'FAIL' 'DUPLICATE_CATALOG_ID' "$name 에 중복 id: $($d.Name)" }
            Add-Issue 'INFO' 'CATALOG_OK' "$name : $(@($cat.entries).Count) 항목"
        } catch {
            Add-Issue 'FAIL' 'CATALOG_PARSE' "$name 파싱 실패: $($_.Exception.Message)"
        }
    }

    # 정확한 버전 고정만 허용한다. 자동으로 최신을 따라가지 않는다.
    foreach ($p in @(Get-ChildItem (Join-HarnessPath $root 'catalogs') -Filter '*.json' -File -ErrorAction SilentlyContinue) +
                   @(Get-ChildItem (Join-HarnessPath $root 'settings') -Recurse -Filter '*.json' -File -ErrorAction SilentlyContinue) +
                   @(Get-ChildItem (Join-HarnessPath $root 'runtimes') -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
        $t = Read-HarnessText -Path $p.FullName
        if ($t -match '"version"\s*:\s*"(latest|[^"]*[\*\^~][^"]*)"') {
            Add-Issue 'FAIL' 'UNPINNED_VERSION' "$($p.Name) 에 정확하지 않은 버전 핀: $($Matches[1])"
        }
        # 레지스트리의 "최신"이 곧 "설치해도 되는 것"은 아니다.
        # 프리릴리스가 핀돼 있으면 사람이 의도한 것인지 확인해야 한다. 막지는 않는다.
        foreach ($pm in [regex]::Matches($t, '"version"\s*:\s*"([^"]*-(?:alpha|beta|rc|preview|dev|next)[^"]*)"')) {
            Add-Issue 'WARN' 'PRERELEASE_VERSION' "$($p.Name) 에 프리릴리스 버전이 고정돼 있습니다: $($pm.Groups[1].Value). 의도한 것인지 확인하세요."
        }
    }

    # -----------------------------------------------------------------------
    # 5b. 런타임 매니페스트 / 공용 런타임 계약
    # -----------------------------------------------------------------------
    $runtimeDir = Join-HarnessPath $root 'runtimes'
    $manifests = @{}
    foreach ($f in @(Get-ChildItem $runtimeDir -Filter '*.runtime.json' -File -ErrorAction SilentlyContinue |
                     Where-Object { -not $_.Name.StartsWith('_') })) {
        $rid = $f.Name -replace '\.runtime\.json$', ''
        $m = $null
        try { $m = Read-HarnessJson -Path $f.FullName } catch {
            Add-Issue 'FAIL' 'MANIFEST_PARSE' "$($f.Name) 파싱 실패: $($_.Exception.Message)"; continue
        }
        $manifests[$rid] = $m

        foreach ($req in @('schema_version', 'runtime_id', 'capability_id', 'server_name', 'risk', 'install', 'server')) {
            if ($m.PSObject.Properties.Name -notcontains $req) {
                Add-Issue 'FAIL' 'MANIFEST_FIELD_MISSING' "$($f.Name) 에 필수 필드가 없습니다: $req"
            }
        }
        if ($m.runtime_id -ne $rid) {
            Add-Issue 'FAIL' 'MANIFEST_ID_MISMATCH' "$($f.Name) 의 runtime_id='$($m.runtime_id)' 가 파일명과 다릅니다."
        }

        # Layer A 에 절대경로가 들어가면 다른 모든 PC 에서 틀린 값이 된다.
        # 경로는 반드시 보간 토큰으로만 쓴다.
        $raw = Read-HarnessText -Path $f.FullName
        # 드라이브 문자는 앞에 다른 글자가 없어야 한다. 그렇지 않으면 "https:" 의 's:' 가 걸린다.
        foreach ($mt in [regex]::Matches($raw, '"[^"]*(?:(?<![A-Za-z])[A-Za-z]:[\\/]|\\\\\\\\|(?<![\w$}])/(?:home|Users|usr|opt|var)/)[^"]*"')) {
            Add-Issue 'FAIL' 'MANIFEST_ABSOLUTE_PATH' "$($f.Name) 에 절대경로: $($mt.Value)  (`${HOME} / `${TOOLS_ROOT} / `${RUNTIME_DIR} 를 쓰세요)"
        }

        # never_sync 는 매니페스트가 유일한 출처여야 한다.
        # 동기화 스크립트가 제외 목록을 따로 하드코딩하면 두 목록이 갈라지고,
        # 갈라지는 순간 비밀값이 올라간다.
        if ($m.credentials) {
            if (-not $m.credentials.never_sync) {
                Add-Issue 'FAIL' 'NEVER_SYNC_MISSING' "$($f.Name) 에 credentials.never_sync 가 없습니다."
            }
            foreach ($n in (@($m.credentials.required_files) + @($m.credentials.auth_state_files))) {
                if (@($m.credentials.never_sync) -notcontains $n) {
                    Add-Issue 'FAIL' 'NEVER_SYNC_INCOMPLETE' "$($f.Name): '$n' 이 never_sync 에 없습니다."
                }
            }
        }
    }

    # -----------------------------------------------------------------------
    # 5b2. 클라이언트 디스크립터 — 제약 고지 계약
    # -----------------------------------------------------------------------
    # 제약은 "있다"고 적는 것으로 끝나면 안 된다. 사용자가 고를 수 있어야 한다.
    # 선택지 없는 제약 고지는 통보이지 선택이 아니다.
    foreach ($cf in @(Get-ChildItem (Join-HarnessPath $root 'settings' 'clients') -Filter '*.client.json' -File -ErrorAction SilentlyContinue)) {
        $cid = $cf.Name -replace '\.client\.json$', ''
        $cd = $null
        try { $cd = Read-HarnessJson -Path $cf.FullName } catch {
            Add-Issue 'FAIL' 'CLIENT_PARSE' "$($cf.Name) 파싱 실패: $($_.Exception.Message)"; continue
        }
        if ($cd.PSObject.Properties.Name -notcontains 'limitations') { continue }
        foreach ($lim in @($cd.limitations)) {
            foreach ($req in @('id', 'severity', 'what', 'why', 'consequence')) {
                if (-not $lim.$req) { Add-Issue 'FAIL' 'LIMITATION_FIELD_MISSING' "$cid 제약 '$($lim.id)' 에 $req 가 없습니다." }
            }
            if ($lim.severity -notin @('low', 'medium', 'high')) {
                Add-Issue 'FAIL' 'LIMITATION_SEVERITY' "$cid 제약 '$($lim.id)' 의 severity 가 low/medium/high 가 아닙니다: $($lim.severity)"
            }
            $opts = @($lim.options)
            if ($opts.Count -lt 2) {
                Add-Issue 'FAIL' 'LIMITATION_NO_CHOICE' "$cid 제약 '$($lim.id)' 에 선택지가 $($opts.Count)개입니다. 선택지 없는 고지는 통보이지 선택이 아닙니다(최소 2개)."
            }
            foreach ($o in $opts) {
                if (-not $o.id -or -not $o.label) { Add-Issue 'FAIL' 'LIMITATION_OPTION_FIELD' "$cid 제약 '$($lim.id)' 의 선택지에 id 또는 label 이 없습니다." }
                if (-not $o.how) { Add-Issue 'FAIL' 'LIMITATION_OPTION_NO_HOW' "$cid 제약 '$($lim.id)' 의 선택지 '$($o.id)' 에 how 가 없습니다. 방법을 못 적으면 선택지가 아닙니다." }
            }
            if (@($opts | Where-Object { $_.recommended }).Count -ne 1) {
                Add-Issue 'FAIL' 'LIMITATION_NO_RECOMMENDED' "$cid 제약 '$($lim.id)' 에 recommended 선택지가 정확히 1개여야 합니다."
            }
        }
    }

    # -----------------------------------------------------------------------
    # 5b3. 스키마 계약 — 선언 파일이 schemas/ 와 실제로 일치하는가
    # -----------------------------------------------------------------------
    # 스키마는 문서가 아니라 검사다. 돌리지 않는 스키마는 며칠 만에 실제와 갈라지고,
    # 갈라진 스키마는 없는 것보다 나쁘다. 틀린 계약을 사실처럼 읽게 만들기 때문이다.
    # node 가 없으면 PASS 가 아니라 UNENFORCED 로 보고한다.
    $schemaDir = Join-HarnessPath $root 'schemas'
    $validator = Join-HarnessPath $root 'scripts' 'harness-schema-validate.mjs'
    $nodeExe = Get-HarnessNativeCommand 'node'

    if (-not (Test-Path -LiteralPath $schemaDir)) {
        Add-Issue 'WARN' 'SCHEMA_DIR_MISSING' 'schemas/ 가 없습니다. 기계가 읽는 계약이 없는 상태입니다.'
    } elseif (-not (Test-Path -LiteralPath $validator)) {
        Add-Issue 'FAIL' 'SCHEMA_VALIDATOR_MISSING' "검증기가 없습니다: $validator"
    } elseif (-not $nodeExe) {
        Add-Issue 'WARN' 'SCHEMA_UNCHECKED' 'node 가 없어 스키마 검증을 건너뜁니다 (UNENFORCED). 통과가 아닙니다.'
    } else {
        # 네이티브 명령의 stderr 를 합치면 5.1 은 각 줄을 ErrorRecord 로 감싸고,
        # ErrorActionPreference='Stop' 이면 그 자리에서 죽는다. 함수 스코프로 낮춘다.
        function Invoke-SchemaCheck {
            param([string]$Node, [string]$Validator, [string]$Schema, [string[]]$Targets)
            $ErrorActionPreference = 'Continue'
            $out = & $Node $Validator '--schema' $Schema @Targets 2>&1 | Out-String
            return [pscustomobject]@{ exit = $LASTEXITCODE; text = $out }
        }

        $schemaTargets = @(
            @{ schema = 'runtime-manifest.schema.json'
               files  = @(Get-ChildItem (Join-HarnessPath $root 'runtimes') -Filter '*.json' -File -ErrorAction SilentlyContinue) },
            @{ schema = 'client-descriptor.schema.json'
               files  = @(Get-ChildItem (Join-HarnessPath $root 'settings' 'clients') -Filter '*.client.json' -File -ErrorAction SilentlyContinue) }
        )

        $checked = 0
        foreach ($st in $schemaTargets) {
            $sp = Join-HarnessPath $schemaDir $st.schema
            if (-not (Test-Path -LiteralPath $sp)) {
                Add-Issue 'FAIL' 'SCHEMA_MISSING' "선언된 스키마가 없습니다: $($st.schema)"
                continue
            }
            $files = @($st.files)
            if (-not $files.Count) { continue }
            $res = Invoke-SchemaCheck -Node $nodeExe -Validator $validator -Schema $sp -Targets @($files | ForEach-Object { $_.FullName })
            if ($res.exit -ne 0) {
                foreach ($line in ($res.text -split "`r?`n")) {
                    if ($line.Trim()) { Add-Issue 'FAIL' 'SCHEMA_VIOLATION' "$($st.schema): $($line.Trim())" }
                }
            }
            $checked += $files.Count
        }

        # 스키마 파일 자체도 JSON 이어야 한다. 깨진 스키마는 조용히 아무것도 검사하지 않는다.
        foreach ($sf in @(Get-ChildItem $schemaDir -Filter '*.schema.json' -File -ErrorAction SilentlyContinue)) {
            try { $null = Read-HarnessJson -Path $sf.FullName } catch {
                Add-Issue 'FAIL' 'SCHEMA_PARSE' "$($sf.Name) 파싱 실패: $($_.Exception.Message)"
            }
        }
        Add-Issue 'INFO' 'SCHEMA_OK' "스키마 검증 $checked 개 파일 (schemas/ $(@(Get-ChildItem $schemaDir -Filter '*.schema.json' -File -ErrorAction SilentlyContinue).Count)개)"
    }

    # -----------------------------------------------------------------------
    # 5c. 카탈로그의 shared_runtime 계약
    # -----------------------------------------------------------------------
    $catPath = Join-HarnessPath $root 'catalogs' 'mcp-catalog.json'
    if (Test-Path -LiteralPath $catPath) {
        $cat = Read-HarnessJson -Path $catPath
        foreach ($e in @($cat.entries | Where-Object { $_.install.kind -eq 'shared_runtime' })) {
            if (-not $e.install.runtime_id) {
                Add-Issue 'FAIL' 'SHARED_RUNTIME_NO_ID' "$($e.id): shared_runtime 인데 runtime_id 가 없습니다."
                continue
            }
            if (-not $manifests.ContainsKey([string]$e.install.runtime_id)) {
                Add-Issue 'FAIL' 'SHARED_RUNTIME_NO_MANIFEST' "$($e.id): runtime_id='$($e.install.runtime_id)' 의 매니페스트가 없습니다."
                continue
            }
            # 버전을 두 곳에 적으면 갈라진다. 정본은 매니페스트다.
            foreach ($forbidden in @('package', 'version')) {
                if ($e.install.PSObject.Properties.Name -contains $forbidden) {
                    Add-Issue 'FAIL' 'SHARED_RUNTIME_DUP_PIN' "$($e.id): shared_runtime 항목에 install.$forbidden 이 있습니다. 정본은 매니페스트입니다."
                }
            }
            $man = $manifests[[string]$e.install.runtime_id]
            if ($man.capability_id -ne $e.id) {
                Add-Issue 'FAIL' 'SHARED_RUNTIME_CAP_MISMATCH' "$($e.id): 매니페스트의 capability_id='$($man.capability_id)' 와 카탈로그 id 가 다릅니다."
            }
            if ($e.install.manifest -and -not (Test-Path -LiteralPath (Join-HarnessPath $root $e.install.manifest))) {
                Add-Issue 'FAIL' 'SHARED_RUNTIME_MANIFEST_PATH' "$($e.id): install.manifest 가 가리키는 파일이 없습니다: $($e.install.manifest)"
            }
        }
        # 선언된 런타임은 반드시 카탈로그에서 발견될 수 있어야 한다.
        foreach ($rid in $manifests.Keys) {
            $capId = [string]$manifests[$rid].capability_id
            if (-not @($cat.entries | Where-Object { $_.id -eq $capId }).Count) {
                Add-Issue 'FAIL' 'RUNTIME_NOT_IN_CATALOG' "런타임 '$rid' 의 capability_id='$capId' 가 카탈로그에 없습니다. 검색으로 찾을 수 없습니다."
            }
        }
        Add-Issue 'INFO' 'SHARED_RUNTIME_OK' "공용 런타임 $($manifests.Count)개 / shared_runtime 카탈로그 항목 $(@($cat.entries | Where-Object { $_.install.kind -eq 'shared_runtime' }).Count)개"
    }

    # -----------------------------------------------------------------------
    # 6. git 기반 비밀값 검사
    # -----------------------------------------------------------------------
    # git 저장소가 아니면 PASS 가 아니라 UNENFORCED 다.
    # 강제할 수 없는 보장을 통과로 보고하면 안 된다.
    Push-Location -LiteralPath $root
    try {
        & git rev-parse --is-inside-work-tree *> $null
        if ($LASTEXITCODE -ne 0) {
            Add-Issue 'FAIL' 'SECRET_GUARD_UNENFORCED' 'git 저장소가 아니므로 비밀값 가드를 강제할 수 없습니다 (UNENFORCED).'
        } else {
            $tracked = & git ls-files
            $blocked = $tracked | Where-Object {
                $_ -match '(^|/)(credentials\.json|tokens\.json|runtimes\.json|clients\.json)$' -or
                $_ -match '(^|/)client_secret[^/]*\.json$' -or
                $_ -match '(^|/)service-account[^/]*\.json$' -or
                $_ -match '(^|/)\.env(\.|$)' -or
                $_ -match '\.(pem|p12|pfx|key)$' -or
                $_ -match '(^|/)node_modules/'
            }
            foreach ($b in $blocked) { Add-Issue 'FAIL' 'TRACKED_SECRET_PATH' "추적되면 안 되는 경로: $b" }

            $hookPath = & git config core.hooksPath
            if ($hookPath -ne '.githooks') {
                Add-Issue 'FAIL' 'HOOKS_NOT_ACTIVE' "core.hooksPath 가 .githooks 가 아닙니다 (현재: '$hookPath'). pre-commit 가드가 비활성입니다."
            }
            Add-Issue 'INFO' 'TRACKED_FILES' "추적 파일 $(@($tracked).Count)개"
        }
    } finally { Pop-Location }
}

# ---------------------------------------------------------------------------
# 판정
# ---------------------------------------------------------------------------
$failCount = @($issues | Where-Object severity -eq 'FAIL').Count
$overall = if ($failCount -gt 0) { 'FAIL' } elseif (@($issues | Where-Object severity -ne 'INFO').Count -gt 0) { 'PASS_WITH_WARNING' } else { 'PASS' }
$report = [pscustomobject]@{ overall = $overall; harness_root = $root; checked_at = (Get-HarnessUtcStamp); issues = @($issues) }

if ($Json) {
    $report | ConvertTo-Json -Depth 6
} else {
    Write-Output "AI Harness repo check: $overall"
    Write-Output "  root: $root"
    foreach ($i in $issues) { Write-Output ("  [{0,-4}] {1,-24} {2}" -f $i.severity, $i.code, $i.message) }
    if ($issues.Count -eq 0) { Write-Output '  (문제 없음)' }
}

if ($failCount -gt 0) { exit 1 }
exit 0
