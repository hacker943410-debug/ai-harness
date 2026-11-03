[CmdletBinding()]
param(
    [ValidateSet('Plan','Install')][string]$Action = 'Plan',
    [ValidateSet('codex','claude','agy')][string]$Client = 'codex',
    [string]$CodexHome,
    [string]$ManagedRoot,
    [switch]$ApproveInstall,
    [switch]$AllowOfficialNodeDownload
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$manifestFile = Join-Path $PSScriptRoot 'bootstrap-manifest.json'
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.schema -ne 1 -or $manifest.node.version -ne '22.22.2' -or $manifest.node.sha256 -ne 'ae1a50511be58e987483fdbc12125407443926d2d394669ade2352776e920dd3') {
    throw 'UNTRUSTED_BOOTSTRAP_MANIFEST: missing pinned Node release contract'
}
if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64' -or -not [Environment]::Is64BitOperatingSystem) {
    throw 'WINDOWS_X64_ONLY'
}
if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') {
    throw 'WINDOWS_REQUIRED'
}
if (-not $CodexHome) {
    if ($env:CODEX_HOME) { $CodexHome=$env:CODEX_HOME } else { $CodexHome = Join-Path $HOME '.codex' }
}
if (-not $ManagedRoot) { $ManagedRoot = Join-Path $env:LOCALAPPDATA 'JHarness-Bootstrap' }
$CodexHome = [IO.Path]::GetFullPath($CodexHome)
$ManagedRoot = [IO.Path]::GetFullPath($ManagedRoot)
$nodeTarget = Join-Path $ManagedRoot 'node-v22.22.2\node.exe'
$bundledNode = Join-Path $packageRoot 'vendor\node.exe'
$targetCore = Join-Path $CodexHome 'j-harness-core'
function CheckPath ([string]$p) {
    if ($p.StartsWith('\\')) { throw "NETWORK_PATH_REFUSED: $p" }
    $item=[IO.Path]::GetFullPath($p)
    if ($item -eq [IO.Path]::GetPathRoot($item)) { throw 'ROOT_DIRECTORY_REFUSED' }
    while ($true) {
        if (Test-Path -LiteralPath $item) {
            $info=Get-Item -LiteralPath $item -Force
            if (($info.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "REPARSE_PATH_REFUSED: $item" }
        }
        $parent=[IO.Path]::GetDirectoryName($item)
        if (-not $parent -or $parent -eq $item) { break }
        $item=$parent
    }
}
function HashMatches ([string]$file,[string]$digest) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return $false }
    CheckPath $file
    return ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -eq $digest)
}
CheckPath $packageRoot
CheckPath $manifestFile
CheckPath $ManagedRoot
CheckPath $CodexHome
CheckPath $nodeTarget
CheckPath $bundledNode
# Distribution checksums detect damage but do not authenticate an unsigned publisher.
$inventoryFile=Join-Path $packageRoot 'SHA256_MANIFEST.json'
CheckPath $inventoryFile
if (-not (Test-Path -LiteralPath $inventoryFile -PathType Leaf)) { throw 'DISTRIBUTION_MANIFEST_MISSING' }
$inventory=Get-Content -LiteralPath $inventoryFile -Encoding UTF8 -Raw | ConvertFrom-Json
if ($inventory.product -ne 'J Harness Phase2 Portable Bootstrap' -or $inventory.trust -ne 'UNSIGNED_DRAFT_INTEGRATION_ARTIFACT' -or @($inventory.files).Count -lt 50) {
    throw 'DISTRIBUTION_MANIFEST_INVALID'
}
$seen=[System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($row in $inventory.files) {
    $rel=[string]$row.path
    if (-not $rel -or $rel.Contains('\') -or $rel.StartsWith('/') -or $rel -match '(^|/)\.\.(/|$)' -or $rel -match '(^|/)\.(/|$)' -or $rel.Contains(':') -or $row.sha256 -notmatch '^[a-fA-F0-9]{64}$') {
        throw 'DISTRIBUTION_PATH_OR_HASH_INVALID'
    }
    if (-not $seen.Add($rel)) { throw 'DUPLICATE_DISTRIBUTION_ENTRY' }
    $file=[IO.Path]::GetFullPath((Join-Path $packageRoot ($rel.Replace('/',[IO.Path]::DirectorySeparatorChar))))
    if (-not $file.StartsWith($packageRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'DISTRIBUTION_PATH_ESCAPE' }
    if (-not (HashMatches $file ([string]$row.sha256).ToLowerInvariant())) { throw ('DISTRIBUTION_SHA256_MISMATCH: '+$rel) }
}
$nodeSource = if (HashMatches $bundledNode $manifest.node.sha256) { 'BUNDLED_PINNED' }
    elseif (Test-Path -LiteralPath $bundledNode) { 'BUNDLED_HASH_MISMATCH' }
    elseif (HashMatches $nodeTarget $manifest.node.sha256) { 'CACHED_PINNED' }
    elseif (Test-Path -LiteralPath $nodeTarget) { 'CACHE_HASH_MISMATCH' }
    else { 'OFFICIAL_DOWNLOAD_REQUIRED' }
$cliCmd = Get-Command $Client -ErrorAction SilentlyContinue | Where-Object { $_.CommandType -eq 'Application' } | Select-Object -First 1
$foundCli = [bool]$cliCmd
$plan = [ordered]@{
    product = 'J Harness Phase 2 portable bootstrap'
    stage = 'INSTALLER_CANDIDATE_NOT_OWNER_SIGNED'
    action = $Action
    selectedClient = $Client
    codexHome = $CodexHome
    managedRoot = $ManagedRoot
    nodeVersion = $manifest.node.version
    nodeSource = $nodeSource
    nodeSha256 = $manifest.node.sha256
    cliDetected = $foundCli
    coreExisting = (Test-Path -LiteralPath $targetCore)
    downloaded = $false
    installed = $false
    hostSettingsChanged = $false
    requiresApproval = $true
    scope = 'APP_LOCAL_RUNTIME_AND_EXISTING_CODEX_PROFILE_ONLY'
    limitations = 'Claude/AGY Core adapters not implemented; this installer only links Codex Core.'
}
if ($Action -eq 'Plan') { $plan | ConvertTo-Json -Depth 8; exit 0 }
if ($Client -ne 'codex') { throw 'CLIENT_ADAPTER_NOT_IMPLEMENTED: Claude and AGY may be diagnosed but cannot yet be linked by v8 Core beta' }
if (-not $ApproveInstall) { throw 'USER_APPROVAL_REQUIRED: run the setup UI or pass explicit approval in controlled integration tests' }
if (-not $foundCli) { throw 'CODEX_CLI_REQUIRED: approved CLI installer adapter not yet available' }
if ($plan.coreExisting) { throw 'EXISTING_J_HARNESS_PRESERVED: use the verified updater, not the first-time installer' }
if ($nodeSource -match 'HASH_MISMATCH') { throw 'NODE_SHA256_MISMATCH: stop, preserve existing files for investigation' }
if ($nodeSource -eq 'OFFICIAL_DOWNLOAD_REQUIRED' -and -not $AllowOfficialNodeDownload) {
    throw 'PINNED_NODE_MISSING: use the bundled Windows distribution or explicitly allow official download'
}
# No registry, PATH persistence, service, ACL, credentials, GitHub access or global npm installs.
$createdNode=$false
$downloadTemp=$null
$envBeforePath=$env:Path
$envBeforeCodeXHome=$env:CODEX_HOME
$linked=$false
try {
    $preferred = if ($nodeSource -eq 'BUNDLED_PINNED') { $bundledNode }
        elseif ($nodeSource -eq 'CACHED_PINNED') { $nodeTarget }
        else { $null }
    if (-not (Test-Path -LiteralPath $nodeTarget)) {
        $dir=[IO.Path]::GetDirectoryName($nodeTarget)
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $downloadTemp=Join-Path $dir ('node.download-'+[Guid]::NewGuid().ToString('N')+'.tmp')
        if ($preferred) { Copy-Item -LiteralPath $preferred -Destination $downloadTemp -ErrorAction Stop }
        else {
            if ($manifest.node.url -ne 'https://nodejs.org/dist/v22.22.2/win-x64/node.exe') { throw 'NODE_ORIGIN_NOT_ALLOWLISTED' }
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $manifest.node.url -OutFile $downloadTemp -UseBasicParsing -MaximumRedirection 0
            $plan.downloaded=$true
        }
        if (-not (HashMatches $downloadTemp $manifest.node.sha256)) { throw 'DOWNLOADED_NODE_SHA256_MISMATCH' }
        Move-Item -LiteralPath $downloadTemp -Destination $nodeTarget -ErrorAction Stop
        $downloadTemp=$null
        $createdNode=$true
    }
    if (-not (HashMatches $nodeTarget $manifest.node.sha256)) { throw 'PINNED_NODE_CORRUPTED' }
    $version = & $nodeTarget --version
    if ($LASTEXITCODE -ne 0 -or $version.Trim() -ne 'v22.22.2') { throw 'PINNED_NODE_EXECUTION_FAILED' }
    $env:Path = (Split-Path $nodeTarget -Parent)+[IO.Path]::PathSeparator+$env:Path
    $env:CODEX_HOME = $CodexHome
    $entry = Join-Path $packageRoot 'core\setup.mjs'
    if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) { throw 'PACKAGED_CORE_ENTRY_MISSING' }
    # Windows PowerShell 5 treats native STDERR as an ErrorRecord when redirected.
    # Core setup prints an informational message to STDERR on success; don't mistake it for an install failure.
    $eapBefore=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        $installOutput = & $nodeTarget $entry install 2>&1
        $installExit = $LASTEXITCODE
    } finally { $ErrorActionPreference=$eapBefore }
    if ($installExit -ne 0) {
        $diagnostic=($installOutput | Out-String).Trim()
        if ($diagnostic.Length -gt 1200) { $diagnostic=$diagnostic.Substring(0,1200) }
        throw ('CORE_INSTALL_FAILED: '+$diagnostic)
    }
    $linked=$true
    $doctorOut = & $nodeTarget $entry run doctor 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'POST_INSTALL_DOCTOR_FAILED' }
    $doctor = ($doctorOut | Out-String) | ConvertFrom-Json
    if ($doctor.effective -ne 'CONNECTED_FOR_NEW_SESSIONS' -or $doctor.backupStatus -ne 'MATCH') { throw 'POST_INSTALL_CONNECTION_NOT_VERIFIED' }
    $plan.installed=$true
    $plan['connection']='CONNECTED_FOR_NEW_SESSIONS'
    $plan['modelPolicyFollowed']='NOT_ATTESTED_REQUIRES_REAL_CODEX_SESSION'
    $plan['nodePath']=$nodeTarget
    $plan | ConvertTo-Json -Depth 8
} catch {
    $failure=$_.Exception.Message
    $rollback='NOT_REQUIRED'
    # Core setup may have linked global guidance before its post-install doctor failed.
    # Detect the actual transaction state, not only the wrapper's $linked flag.
    $stateFile=Join-Path $targetCore 'install.json'
    if ($linked -or (Test-Path -LiteralPath $stateFile -PathType Leaf)) {
        try {
            $previous=$ErrorActionPreference
            try {
                $ErrorActionPreference='Continue'
                $rollbackResult=& $nodeTarget (Join-Path $packageRoot 'core\setup.mjs') uninstall 2>&1
                $rollbackExit=$LASTEXITCODE
            } finally { $ErrorActionPreference=$previous }
            if ($rollbackExit -ne 0) { throw 'UNINSTALL_NONZERO' }
            $rollback='CORE_UNLINKED_ARCHIVED'
        } catch { $rollback='MANUAL_RECOVERY_REQUIRED' }
    } elseif (Test-Path -LiteralPath $targetCore) { $rollback='PARTIAL_CORE_PRESERVED_MANUAL_REVIEW_REQUIRED' }
    # Do not break a preserved partial runtime by deleting the executable it may need.
    if ($createdNode -and $rollback -notmatch 'MANUAL|PARTIAL' -and (HashMatches $nodeTarget $manifest.node.sha256)) {
        Remove-Item -LiteralPath $nodeTarget -Force
        $rollback+='; NEW_PINNED_NODE_REMOVED'
    }
    if ($downloadTemp -and (Test-Path -LiteralPath $downloadTemp)) { Remove-Item -LiteralPath $downloadTemp -Force }
    [Console]::Error.WriteLine((@{result='BLOCKED';error=$failure;rollback=$rollback;existingCredentialsChanged=$false} | ConvertTo-Json -Compress))
    exit 2
} finally {
    $env:Path=$envBeforePath
    $env:CODEX_HOME=$envBeforeCodeXHome
}
