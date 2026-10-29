[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string]$Id,
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [string]$Reason = 'capability_gap',
    [string]$HarnessRoot,
    [string]$Client = 'AllNative',
    [switch]$AllowDiscoveryOnly,
    [switch]$Force,
    [string]$ReviewedSourceDirectory,
    [string]$ExpectedTreeHash
)
if (-not $HarnessRoot) { $HarnessRoot = Split-Path -Parent $PSScriptRoot }
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Harness.Common.ps1')
. (Join-Path $PSScriptRoot '_Harness.Skill.ps1')

$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$harness = (Resolve-Path -LiteralPath $HarnessRoot).Path
if ($Id -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]*$') { throw 'Invalid Skill id.' }
$catalog = Read-HarnessJson -Path (Join-HarnessPath $harness 'catalogs' 'skill-catalog.json')
$entries = @($catalog.entries | Where-Object id -eq $Id)
if ($entries.Count -ne 1) { throw "Skill '$Id' was not found uniquely in the catalog." }
$entry = $entries[0]
if ($entry.status -eq 'discovery_only' -and -not $AllowDiscoveryOnly) { throw "Skill '$Id' requires source verification before installation." }
if (-not $entry.source) { throw "Skill '$Id' has no verified source." }
$lockPath = Get-HarnessProjectPath $project '.ai/capability-lock.json'
if (Test-Path -LiteralPath $lockPath) {
    try { $lock = Read-HarnessJson -Path $lockPath } catch { throw 'Existing capability lock cannot be parsed; installation stopped.' }
    if ($lock.schema_version -ne '1.0' -or $lock.PSObject.Properties.Name -notcontains 'capabilities') { throw 'Existing capability lock has an unsupported format.' }
} else { $lock = [pscustomobject]@{ schema_version = '1.0'; capabilities = @() } }

$record = [pscustomobject]@{
    type = 'skill'; id = $Id; source = $entry.source; version = $null; content_hash = $null
    scope = 'project'; reason = $Reason; status = 'installed'; config_path = $null
    recorded_at = (Get-HarnessUtcStamp)
}
# External Skill acquisition/review is separate from installation (no npx or network).
$isBundled = ($entry.PSObject.Properties.Name -contains 'bundled_path') -and [bool]$entry.bundled_path
if ($isBundled) {
    if ($ReviewedSourceDirectory -or $ExpectedTreeHash) { throw 'BUNDLED_SKILL_REVIEW_OVERRIDE_NOT_ALLOWED' }
    $source = Get-HarnessProjectPath $harness $entry.bundled_path
} else {
    if (-not $ReviewedSourceDirectory -or -not $ExpectedTreeHash) {
        throw 'EXTERNAL_SKILL_REVIEW_REQUIRED: supply -ReviewedSourceDirectory and -ExpectedTreeHash.'
    }
    if ($ExpectedTreeHash -notmatch '^[a-fA-F0-9]{64}$') { throw 'EXTERNAL_SKILL_HASH_INVALID' }
    $source = (Resolve-Path -LiteralPath $ReviewedSourceDirectory -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw 'EXTERNAL_SKILL_SOURCE_NOT_DIRECTORY' }
    $sourceFull = [IO.Path]::GetFullPath($source).TrimEnd([char[]]'\\/')
    $projectFull = [IO.Path]::GetFullPath($project).TrimEnd([char[]]'\\/')
    $comparison = if ($script:HarnessIsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if ($sourceFull.Equals($projectFull, $comparison) -or
        $sourceFull.StartsWith($projectFull + [IO.Path]::DirectorySeparatorChar, $comparison)) {
        throw 'EXTERNAL_SKILL_SOURCE_INSIDE_PROJECT'
    }
}
$manifest = Get-HarnessSkillManifest $source
if (-not $isBundled -and $manifest.Hash -cne $ExpectedTreeHash.ToLowerInvariant()) {
    throw 'EXTERNAL_SKILL_HASH_MISMATCH'
}
    $clientDir = Join-HarnessPath $harness 'settings' 'clients'
    $descriptors = @()
    if ($Client -eq 'AllNative') {
        foreach ($file in @(Get-ChildItem -LiteralPath $clientDir -Filter '*.client.json' -File)) {
            $descriptor = Read-HarnessJson -Path $file.FullName
            if ($descriptor.skill_support.native -and $descriptor.skill_support.project_path_template) { $descriptors += $descriptor }
        }
    } else {
        if ($Client -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid client id.' }
        $descriptor = Read-HarnessJson -Path (Join-HarnessPath $clientDir ("{0}.client.json" -f $Client.ToLowerInvariant()))
        if (-not ($descriptor.skill_support.native -and $descriptor.skill_support.project_path_template)) { throw "Client '$Client' does not support native project Skills." }
        $descriptors += $descriptor
    }
    $prior = @($lock.capabilities | Where-Object { $_.type -eq 'skill' -and $_.id -eq $Id })
    if ($prior.Count -gt 1) { throw 'Existing capability lock has duplicate Skill records.' }
    $installations = @()
    if ($prior.Count -eq 1) {
        $installations = @(Get-HarnessSkillInstallations $prior[0])
        $seenPaths = @{}
        foreach ($installation in $installations) {
            $storedPath = Get-HarnessProjectPath $project $installation.config_path
            $installation.config_path = $storedPath.Substring($project.TrimEnd([char[]]'\/').Length + 1).Replace('\', '/')
            if ($seenPaths.ContainsKey($installation.config_path)) { throw 'Existing capability lock has duplicate Skill paths.' }
            $seenPaths[$installation.config_path] = $true
        }
    }
    $targets = @()
    foreach ($descriptor in $descriptors) {
        $relative = ([string]$descriptor.skill_support.project_path_template).Replace('{skill_id}', $Id).Replace('\', '/')
        $path = Get-HarnessProjectPath $project $relative
        $comparison = if ($script:HarnessIsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
        if ($lockPath.Equals($path, $comparison) -or $lockPath.StartsWith($path + [IO.Path]::DirectorySeparatorChar, $comparison)) {
            throw 'Skill destination overlaps the capability lock or transaction directory.'
        }
        if (@($targets | Where-Object path -eq $path).Count -gt 0) { continue }
        foreach ($target in $targets) {
            if ($path.StartsWith($target.path + [IO.Path]::DirectorySeparatorChar, $comparison) -or $target.path.StartsWith($path + [IO.Path]::DirectorySeparatorChar, $comparison)) {
                throw 'Native Skill destinations must not overlap.'
            }
        }
        if (Test-Path -LiteralPath $path) {
            $existing = Get-HarnessSkillManifest $path
            if ($existing.Hash -ne $manifest.Hash -and -not $Force) { throw "Existing Skill differs at '$relative'. Review it, then use -Force to replace it." }
        }
        $targets += [pscustomobject]@{ path = $path; relative = $relative; client_id = $descriptor.client_id; installed = $false; backupTaken = $false; backupRelative = $null }
    }
    if ($targets.Count -eq 0) { throw 'No native Skill-capable client descriptors were found.' }
    if (-not $PSCmdlet.ShouldProcess($project, ("Install verified Skill '{0}' into {1}" -f $Id, (($targets | ForEach-Object { $_.relative }) -join ', ')))) { return }
    foreach ($target in $targets) {
        $installations = @($installations | Where-Object config_path -ne $target.relative)
        $installations += [pscustomobject]@{
            client_id = $target.client_id; config_path = $target.relative; content_hash = $manifest.SkillHash
            bundle_hash = $manifest.Hash; hash_algorithm = 'sha256-tree-v1'; files = @($manifest.Files)
            status = 'installed'; recorded_at = $record.recorded_at
        }
    }
    $installations = @($installations | Sort-Object config_path)
    $record.config_path = ($installations | ForEach-Object { $_.config_path }) -join ';'
    $record | Add-Member -NotePropertyName installations -NotePropertyValue $installations
    # Preserve the v6 aggregate only when every recorded installation agrees.
    $different = @($installations | Where-Object { $_.bundle_hash -ne $manifest.Hash -or $_.hash_algorithm -ne 'sha256-tree-v1' -or $_.content_hash -ne $manifest.SkillHash })
    if ($different.Count -eq 0) {
        $record.content_hash = $manifest.SkillHash
        $record | Add-Member -NotePropertyName bundle_hash -NotePropertyValue $manifest.Hash
        $record | Add-Member -NotePropertyName hash_algorithm -NotePropertyValue 'sha256-tree-v1'
        $record | Add-Member -NotePropertyName files -NotePropertyValue @($manifest.Files)
    }
    $lock.capabilities = @(@($lock.capabilities | Where-Object { -not ($_.type -eq 'skill' -and $_.id -eq $Id) }) + $record)
    $transactionRelative = '.ai/.skill-install-' + [Guid]::NewGuid().ToString('N')
    $transaction = Get-HarnessProjectPath $project $transactionRelative
    New-Item -ItemType Directory -Path $transaction -Force | Out-Null
    try {
        # Prepare every copy and the lock before touching any installed Skill.
        for ($index = 0; $index -lt $targets.Count; $index++) {
            $stage = Get-HarnessProjectPath $project ($transactionRelative + '/stage-' + $index)
            Copy-Item -LiteralPath $source -Destination $stage -Recurse -Force
            if ((Get-HarnessSkillManifest $stage).Hash -ne $manifest.Hash) { throw 'Staged Skill integrity mismatch.' }
        }
        $newLock = Get-HarnessProjectPath $project ($transactionRelative + '/capability-lock.json')
        Write-HarnessJson -Path $newLock -InputObject $lock -Depth 12
        $null = Read-HarnessJson -Path $newLock
        for ($index = 0; $index -lt $targets.Count; $index++) {
            $target = $targets[$index]
            $destination = Get-HarnessProjectPath $project $target.relative
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            $target.backupRelative = $transactionRelative + '/backup-' + $index
            if (Test-Path -LiteralPath $destination) {
                $backup = Get-HarnessProjectPath $project $target.backupRelative
                Move-Item -LiteralPath $destination -Destination $backup
                $target.backupTaken = $true
            }
            $stage = Get-HarnessProjectPath $project ($transactionRelative + '/stage-' + $index)
            Move-Item -LiteralPath $stage -Destination $destination
            $target.installed = $true
            if ((Get-HarnessSkillManifest $destination).Hash -ne $manifest.Hash) { throw 'Installed Skill integrity mismatch.' }
        }
        $lockPath = Get-HarnessProjectPath $project '.ai/capability-lock.json'
        if (Test-Path -LiteralPath $lockPath) { [IO.File]::Replace($newLock, $lockPath, [Management.Automation.Language.NullString]::Value) }
        else { Move-Item -LiteralPath $newLock -Destination $lockPath }
    } catch {
        $recoveryFailed = $false
        for ($index = $targets.Count - 1; $index -ge 0; $index--) {
            $target = $targets[$index]
            try {
                if ($target.installed) { Remove-HarnessSkillWorkPath $project $target.relative }
                if ($target.backupTaken) {
                    $backup = Get-HarnessProjectPath $project $target.backupRelative
                    $destination = Get-HarnessProjectPath $project $target.relative
                    Move-Item -LiteralPath $backup -Destination $destination
                }
            } catch { $recoveryFailed = $true }
        }
        if (-not $recoveryFailed) {
            try { Remove-HarnessSkillWorkPath $project $transactionRelative } catch { $recoveryFailed = $true }
        }
        if ($recoveryFailed) { throw "Skill installation failed. Recovery data remains at '$transactionRelative'; inspect it before retrying." }
        throw 'Skill installation failed; installed Skills and the existing capability lock were preserved.'
    }
    try { Remove-HarnessSkillWorkPath $project $transactionRelative }
    catch { Write-Warning "Installation committed; backup cleanup is pending at '$transactionRelative'." }
Write-Output "Installed project skill '$Id' for $Client. Restart the agent session if the client requires rediscovery."
