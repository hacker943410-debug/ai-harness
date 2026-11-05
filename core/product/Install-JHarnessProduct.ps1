# J Harness Windows x64 integrated candidate; no global installs or stored credentials.
# The release is intentionally UNSIGNED / NOT_FOR_PRODUCTION until publisher signing and E2E.
[CmdletBinding()]
param(
    [ValidateSet('Plan','Install')][string]$Action='Plan',
    [switch]$ApproveInstall,
    [string]$CodexHome,
    [string]$ManagedRoot
)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
if (-not [Environment]::Is64BitOperatingSystem -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64') {throw 'WINDOWS_X64_REQUIRED'}
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {throw 'WINDOWS_REQUIRED'}
if (-not $env:LOCALAPPDATA) {throw 'USER_LOCALAPPDATA_REQUIRED'}
if (-not $ManagedRoot) {$ManagedRoot=Join-Path $env:LOCALAPPDATA 'JHarness-Bootstrap'}
if (-not $CodexHome) {$CodexHome=if($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $HOME '.codex'}}
$ManagedRoot=[IO.Path]::GetFullPath($ManagedRoot)
$CodexHome=[IO.Path]::GetFullPath($CodexHome)
$packageRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$bootstrap=Join-Path $packageRoot 'bootstrap\Bootstrap-JHarness.ps1'
$lockFile=Join-Path $PSScriptRoot 'codex-lock.json'
$lock=Get-Content -LiteralPath $lockFile -Raw -Encoding UTF8 | ConvertFrom-Json
$expectedCodex='9d563ee4e0441ff9d59d612013e0460ddf8e5709735c2d9f6b98b7ef8ca4eb42'
$expectedUrl='https://github.com/openai/codex/releases/download/rust-v0.166.0/codex-x86_64-pc-windows-msvc.exe'
if($lock.schema -ne 1 -or $lock.sha256 -ne $expectedCodex -or $lock.url -ne $expectedUrl -or $lock.release -ne 'rust-v0.166.0' -or $lock.size -ne 371735856){throw 'PINNED_CODEX_RELEASE_LOCK_MISMATCH'}
$privateCliDir=Join-Path $ManagedRoot 'cli\codex-v0.166.0'
$privateCli=Join-Path $privateCliDir 'codex.exe'
$bundledCli=Join-Path $packageRoot 'vendor\codex.exe'
$appDir=Join-Path $ManagedRoot 'app'
$receipt=Join-Path $appDir 'receipt.json'
$node=Join-Path $ManagedRoot 'node-v22.22.2\node.exe'
$installed=Join-Path $CodexHome 'j-harness-core\runtime\core\setup.mjs'
function Check-SafePath([string]$value) {
 if($value.StartsWith('\\') -or $value.StartsWith('//')){throw 'UNC_PATH_REFUSED'}
 $current=[IO.Path]::GetFullPath($value)
 if($current -eq [IO.Path]::GetPathRoot($current)){throw 'ROOT_PATH_REFUSED'}
 while($current) {
   if(Test-Path -LiteralPath $current) {
      $item=Get-Item -LiteralPath $current -Force
      if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw ('REPARSE_POINT_REFUSED: '+$current)}
   }
   $parent=[IO.Path]::GetDirectoryName($current)
   if(-not $parent -or $parent -eq $current){break}
   $current=$parent
 }
}
function Match-Hash([string]$file,[string]$sha) {
 if(-not(Test-Path -LiteralPath $file -PathType Leaf)){return $false}
 Check-SafePath $file
 return ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -eq $sha)
}
foreach($p in @($packageRoot,$bootstrap,$lockFile,$ManagedRoot,$CodexHome,$privateCliDir,$privateCli,$bundledCli,$appDir,$receipt,$node)) {Check-SafePath $p}
if(-not(Test-Path -LiteralPath $bootstrap -PathType Leaf)){throw 'ORIGINAL_SAFE_BOOTSTRAP_MISSING'}
$hostCli=$null
foreach($name in @('codex.exe','codex')) {
  $cmd=Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if($cmd -and [IO.Path]::GetExtension($cmd.Source).ToLowerInvariant() -eq '.exe'){$hostCli=[string]$cmd.Source;break}
}
$privateExists=Test-Path -LiteralPath $privateCli
$bundledExists=Test-Path -LiteralPath $bundledCli
if($bundledExists -and ((Get-Item -LiteralPath $bundledCli).Length -ne 371735856 -or -not(Match-Hash $bundledCli $expectedCodex))){throw 'BUNDLED_CODEX_SHA256_MISMATCH'}
if($privateExists -and -not(Match-Hash $privateCli $expectedCodex)){throw 'PREVIOUS_PRIVATE_CODEX_HASH_MISMATCH_PRESERVE_FOR_REVIEW'}
if((Test-Path -LiteralPath $receipt) -or (Test-Path -LiteralPath $appDir)){throw 'PRODUCT_ALREADY_EXISTS_REVIEW_OR_UNINSTALL_FIRST'}
# Verify the packaged Node and all distribution files before any network or disk changes.
$psExe=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$preflight=& $psExe -NoProfile -ExecutionPolicy Bypass -File $bootstrap -Action Plan -Client codex -CodexHome $CodexHome -ManagedRoot $ManagedRoot
if($LASTEXITCODE -ne 0){throw 'PHASE2_PACKAGE_INTEGRITY_PREFLIGHT_FAILED'}
try{$preflightObj=($preflight | Out-String) | ConvertFrom-Json}catch{throw 'PHASE2_PACKAGE_PREFLIGHT_RESULT_INVALID'}
if($preflightObj.nodeSource -match 'HASH_MISMATCH'){throw 'EXISTING_NODE_CACHE_UNTRUSTED'}
$selection=if($hostCli){'REUSE_EXISTING_NATIVE_CODEX'}elseif($privateExists){'REUSE_PINNED_PRIVATE_CODEX'}elseif($bundledExists){'INSTALL_BUNDLED_PINNED_CODEX'}else{'DOWNLOAD_PINNED_PRIVATE_CODEX'}
$plan=[ordered]@{
 product='J Harness';channel='v8-integrated-installer-candidate';status='INSTALLABLE_BETA_NOT_OS_ENFORCED';action=$Action;
 supportedHost='Windows x64';codexHome=$CodexHome;managedRoot=$ManagedRoot;
 node=@{version='22.22.2';source=$preflightObj.nodeSource};
 cli=@{client='codex';mode=$selection;version='0.166.0';downloadBytes=$(if($selection -eq 'DOWNLOAD_PINNED_PRIVATE_CODEX'){371735856}else{0})};
 installs=@('private Node runtime','private Codex binary when absent','J Harness Core and managed global instruction block','private start/doctor/remove commands');
 preserves=@('existing Codex credentials','existing Codex config and MCP','existing CLI files','system PATH','registry','Windows accounts');
 guarantees='ADVISORY_CORE_ONLY_NOT_SUPERVISOR_ENFORCED';requiresApproval=$true
}
if($Action -eq 'Plan'){$plan | ConvertTo-Json -Depth 7;exit 0}
if(-not $ApproveInstall){throw 'EXPLICIT_INSTALL_APPROVAL_REQUIRED'}
if($preflightObj.coreExisting){throw 'EXISTING_CORE_REVIEW_REQUIRED_DO_NOT_REPLACE'}
$createdCli=$false;$createdProduct=$false;$linkedCore=$false;$tmpFile=$null
$copiedLaunchers=New-Object System.Collections.Generic.List[string]
$oldPath=$env:Path;$oldCodexHome=$env:CODEX_HOME
$nodeWasPresent=Test-Path -LiteralPath $node
try {
  $cliPath=$hostCli
  if(-not $cliPath) {
    if(-not $privateExists) {
      New-Item -ItemType Directory -Path $privateCliDir -Force | Out-Null
      $tmpFile=Join-Path $privateCliDir ('codex-download-'+[Guid]::NewGuid().ToString('N')+'.part')
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      if($bundledExists){Copy-Item -LiteralPath $bundledCli -Destination $tmpFile -ErrorAction Stop}
      else{Invoke-WebRequest -Uri $expectedUrl -OutFile $tmpFile -MaximumRedirection 8 -UseBasicParsing -ErrorAction Stop}
      if((Get-Item -LiteralPath $tmpFile).Length -ne 371735856 -or -not(Match-Hash $tmpFile $expectedCodex)){throw 'CODEX_DOWNLOAD_DIGEST_OR_SIZE_MISMATCH'}
      Move-Item -LiteralPath $tmpFile -Destination $privateCli -ErrorAction Stop
      $tmpFile=$null;$createdCli=$true
    }
    if(-not(Match-Hash $privateCli $expectedCodex)){throw 'PRIVATE_CODEX_INTEGRITY_FAILED'}
    $cliPath=$privateCli
  }
  if(-not(Test-Path -LiteralPath $cliPath -PathType Leaf)){throw 'CODEX_BINARY_NOT_FOUND'}
  $versionOut=& $cliPath --version
  if($LASTEXITCODE -ne 0 -or -not($versionOut -match 'codex')){throw 'CODEX_EXECUTION_PROBE_FAILED'}
  # Scope PATH and CODEX_HOME changes to this process and the child installer only.
  $env:Path=(Split-Path -Parent $cliPath)+[IO.Path]::PathSeparator+$env:Path
  $env:CODEX_HOME=$CodexHome
  $installOutput=& $psExe -NoProfile -ExecutionPolicy Bypass -File $bootstrap -Action Install -Client codex -ApproveInstall -CodexHome $CodexHome -ManagedRoot $ManagedRoot
  if($LASTEXITCODE -ne 0){throw 'CORE_BOOTSTRAP_FAILED_OR_ROLLED_BACK'}
  try{$coreResult=($installOutput|Out-String) | ConvertFrom-Json}catch{throw 'CORE_INSTALL_RESULT_INVALID'}
  if($coreResult.installed -ne $true -or $coreResult.connection -ne 'CONNECTED_FOR_NEW_SESSIONS'){throw 'CORE_INSTALL_NOT_VERIFIED'}
  $linkedCore=$true
  if(-not(Test-Path -LiteralPath $installed -PathType Leaf)){throw 'INSTALLED_CORE_ENTRY_MISSING'}
  New-Item -ItemType Directory -Path $appDir -ErrorAction Stop | Out-Null
  $createdProduct=$true
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Installed-JHarness.ps1') -Destination (Join-Path $appDir 'Installed-JHarness.ps1') -ErrorAction Stop
  foreach($name in @('J_Harness_Start.cmd','J_Harness_Doctor.cmd','J_Harness_Remove.cmd')){
    $from=Join-Path $PSScriptRoot $name;$to=Join-Path $ManagedRoot $name
    if(Test-Path -LiteralPath $to){throw ('EXISTING_LAUNCHER_PRESERVED: '+$name)}
    Copy-Item -LiteralPath $from -Destination $to -ErrorAction Stop
    $copiedLaunchers.Add($to)
  }
  $launcherHashes=[ordered]@{}
  foreach($p in $copiedLaunchers){$launcherHashes[(Split-Path -Leaf $p)]=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
  $receiptData=[ordered]@{
    schema=1;product='J Harness';channel='v8-integrated-installer-candidate';codexHome=$CodexHome;managedRoot=$ManagedRoot;
    cliPath=$cliPath;cliSha256=$(if($cliPath -eq $privateCli){$expectedCodex}else{'EXISTING_CLI_NOT_MANAGED'});
    privateCliCreated=$createdCli;nodeOwned=(-not $nodeWasPresent);
    nodePath=$node;nodeSha256='ae1a50511be58e987483fdbc12125407443926d2d394669ade2352776e920dd3';
    installedAtUtc=[DateTime]::UtcNow.ToString('o');securityMode='ADVISORY_NOT_OS_ENFORCED';launcherSha256=$launcherHashes
  }
  [IO.File]::WriteAllText($receipt,($receiptData | ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
  [ordered]@{result='INSTALLED_INTEGRATED_BETA';client='codex';cliMode=$selection;launch=(Join-Path $ManagedRoot 'J_Harness_Start.cmd');doctor=(Join-Path $ManagedRoot 'J_Harness_Doctor.cmd');uninstall=(Join-Path $ManagedRoot 'J_Harness_Remove.cmd');securityMode='ADVISORY_NOT_OS_ENFORCED';systemPathChanged=$false;authChanged=$false;needsInteractiveCodexLogin='IF_NOT_ALREADY_AUTHENTICATED'} | ConvertTo-Json -Depth 7
} catch {
  $failure=$_.Exception.Message
  $recovery='NOT_REQUIRED'
  if($linkedCore -or (Test-Path -LiteralPath (Join-Path $CodexHome 'j-harness-core\install.json'))) {
    try {
      $uninstall=& $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $packageRoot 'bootstrap\Uninstall-JHarness.ps1') -CodexHome $CodexHome -ManagedRoot $ManagedRoot -ApproveUninstall
      if($LASTEXITCODE -ne 0){throw 'CORE_UNINSTALL_FAILED'}
      $recovery='CORE_ARCHIVED_ORIGINAL_GUIDANCE_RESTORED'
    }catch{$recovery='MANUAL_CORE_RECOVERY_REQUIRED'}
  }
  if($createdProduct -and $recovery -notmatch '^MANUAL') {
    foreach($p in $copiedLaunchers){
      if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Force}
    }
    if(Test-Path -LiteralPath $appDir){Remove-Item -LiteralPath $appDir -Recurse -Force}
  }
  if($createdCli -and $recovery -notmatch '^MANUAL' -and (Match-Hash $privateCli $expectedCodex)) {Remove-Item -LiteralPath $privateCli -Force}
  if($tmpFile -and (Test-Path -LiteralPath $tmpFile)){Remove-Item -LiteralPath $tmpFile -Force}
  [Console]::Error.WriteLine((@{result='BLOCKED';error=$failure;recovery=$recovery;credentialsChanged=$false} | ConvertTo-Json -Compress))
  exit 2
} finally {$env:Path=$oldPath;$env:CODEX_HOME=$oldCodexHome}
