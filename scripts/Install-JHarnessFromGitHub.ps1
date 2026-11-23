# Default Windows product installer: v8 portable, without a global Codex profile.
[CmdletBinding()]
param(
  [ValidateSet('Plan','Install','Package','Recover')][string]$Action='Plan',
  [ValidateSet('Portable','Profile')][string]$Mode='Portable',
  [switch]$ApproveInstall,
  [switch]$Upgrade,
  [string]$ProjectPath,
  [string]$PackagePath,
  [string]$Destination,
  [string]$CodexHome,
  [string]$ManagedRoot
)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
# A pinned v8 product release is selected, never the legacy policy /releases/latest.
$productVersion='8.2.2'
$coreVersion='8.2.2'
$releaseTag='v8.2.2'
$assetName='J_Harness_v8.2.2_Windows_x64.zip'
$expectedZipSha='8070e9aa32cb60337bbbb6de2cf52bf09ccef1ca950d33a34b95d9a94f9891b4'
$assetUrl='https://github.com/hacker943410-debug/ai-harness/releases/download/'+$releaseTag+'/'+$assetName
if(-not $PSBoundParameters.ContainsKey('Mode') -and ($PSBoundParameters.ContainsKey('CodexHome') -or $PSBoundParameters.ContainsKey('ManagedRoot'))){$Mode='Profile'}
if($Mode -eq 'Profile'){
  if($Upgrade -or $Action -eq 'Recover'){throw 'PORTABLE_PROJECT_UPGRADE_REQUIRES_PORTABLE_MODE'}
  $legacy=Join-Path $PSScriptRoot 'Install-JHarnessProfileFromGitHub.ps1'
  if(-not(Test-Path -LiteralPath $legacy -PathType Leaf)){throw 'EXPLICIT_PROFILE_MODE_REQUIRES_SOURCE_CHECKOUT'}
  $forward=@{Action=$Action}
  if($ApproveInstall){$forward.ApproveInstall=$true}
  foreach($key in @('CodexHome','ManagedRoot','Destination')){if($PSBoundParameters.ContainsKey($key)){$forward[$key]=$PSBoundParameters[$key]}}
  & $legacy @forward
  return
}
if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64'){throw 'WINDOWS_X64_REQUIRED'}
if($Action -eq 'Recover' -and -not $Upgrade){throw 'RECOVER_REQUIRES_UPGRADE_SWITCH'}
if($Action -eq 'Package' -and $Upgrade){throw 'PACKAGE_ACTION_DOES_NOT_UPGRADE'}
if($Upgrade -and -not $ProjectPath){throw 'PROJECT_PATH_REQUIRED_FOR_UPGRADE'}
if(-not $ProjectPath){
  if(-not $env:LOCALAPPDATA){throw 'PROJECT_PATH_REQUIRED'}
  $ProjectPath=[IO.Path]::Combine($env:LOCALAPPDATA,'JHarness-Portable','workspace')
}
$project=[IO.Path]::GetFullPath($ProjectPath)
function Assert-Safe([string]$value){
  if(-not $value -or $value.StartsWith('\\') -or $value.StartsWith('//')){throw 'LOCAL_PATH_REQUIRED'}
  $full=[IO.Path]::GetFullPath($value)
  if($full -eq [IO.Path]::GetPathRoot($full)){throw 'DRIVE_ROOT_REFUSED'}
  for($cursor=$full;$cursor;){
    if((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'REPARSE_PATH_REFUSED'}
    $parent=[IO.Path]::GetDirectoryName($cursor)
    if(-not $parent -or $parent -eq $cursor){break};$cursor=$parent
  }
}
Assert-Safe $project
if($Upgrade -and -not(Test-Path -LiteralPath $project -PathType Container)){throw 'EXISTING_PROJECT_DIRECTORY_REQUIRED_FOR_UPGRADE'}
if($expectedZipSha -notmatch '^[a-f0-9]{64}$'){throw 'UNREVIEWED_V8_RELEASE_LOCK'}
$plan=[ordered]@{product='J Harness';productVersion=$productVersion;coreVersion=$coreVersion;releaseTag=$releaseTag;mode='PROJECT_PORTABLE';action=$Action;project=$project;globalConnectionRequired=$false;codexRequired=$false;systemNodeRequired=$false;systemGitRequired=$false;systemPathChanged=$false;credentialsChanged=$false;supervisorEnforced=$false;fallback='NONE';assetUrl=$assetUrl;sha256=$expectedZipSha;result='PLAN_ONLY_NOT_INSTALLED'}
if($Action -eq 'Plan' -and -not $Upgrade){$plan|ConvertTo-Json -Depth 6;return}
if($Action -eq 'Package' -and -not $Destination){throw 'PACKAGE_DESTINATION_REQUIRED'}
if($Action -in @('Install','Recover') -and -not $ApproveInstall){
  $confirmation=if($Action -eq 'Recover'){'RECOVER'}elseif($Upgrade){'UPGRADE'}else{'INSTALL'}
  $typed=Read-Host ($confirmation+' J Harness v8 portable in '+$project+'? Type '+$confirmation)
  if($typed -cne $confirmation){$plan.result='CANCELLED_NO_DOWNLOAD';$plan|ConvertTo-Json -Depth 6;return}
}
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$work=Join-Path $tempRoot ('JHarness-v8-download-'+[guid]::NewGuid().ToString('N'))
Assert-Safe $work
[IO.Directory]::CreateDirectory($work)|Out-Null
try{
  $archive=Join-Path $work $assetName
  if($PackagePath){
    $local=[IO.Path]::GetFullPath($PackagePath);Assert-Safe $local
    Copy-Item -LiteralPath $local -Destination $archive -ErrorAction Stop
  }else{
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $assetUrl -OutFile $archive -UseBasicParsing -MaximumRedirection 8 -ErrorAction Stop
  }
  if((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedZipSha){throw 'V8_PACKAGE_SHA256_MISMATCH_NO_FALLBACK'}
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $unpacked=Join-Path $work 'package';[IO.Directory]::CreateDirectory($unpacked)|Out-Null
  $zip=[IO.Compression.ZipFile]::OpenRead($archive)
  try{
    $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach($entry in $zip.Entries){
      $name=$entry.FullName.Replace('\','/')
      if(-not $name -or $name.StartsWith('/') -or $name.Contains(':') -or @($name.TrimEnd('/') -split '/'|Where-Object {$_ -eq '' -or $_ -eq '.' -or $_ -eq '..'}).Count){throw 'UNSAFE_RELEASE_ARCHIVE_PATH'}
      if(-not $seen.Add($name.TrimEnd('/'))){throw 'DUPLICATE_RELEASE_ARCHIVE_PATH'}
      $unixMode=([int64]$entry.ExternalAttributes -shr 16) -band 61440
      if($unixMode -eq 40960){throw 'RELEASE_ARCHIVE_LINK_REFUSED'}
      $target=[IO.Path]::GetFullPath((Join-Path $unpacked $name))
      if(-not $target.StartsWith($unpacked.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'RELEASE_ARCHIVE_ESCAPE'}
      Assert-Safe $target
      if($name.EndsWith('/')){[IO.Directory]::CreateDirectory($target)|Out-Null;continue}
      [IO.Directory]::CreateDirectory((Split-Path -Parent $target))|Out-Null
      $inputStream=$entry.Open();$outputStream=[IO.File]::Open($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
      try{$inputStream.CopyTo($outputStream)}finally{$outputStream.Dispose();$inputStream.Dispose()}
    }
  }finally{$zip.Dispose()}
  $installer=Join-Path $unpacked 'Install-JHarnessLocal.ps1'
  if(-not(Test-Path -LiteralPath $installer -PathType Leaf)){throw 'V8_LOCAL_INSTALLER_MISSING'}
  if($Action -eq 'Package'){
    $dest=[IO.Path]::GetFullPath($Destination);Assert-Safe $dest
    if(Test-Path -LiteralPath $dest){throw 'EXISTING_PACKAGE_DESTINATION_PRESERVED'}
    Copy-Item -LiteralPath $unpacked -Destination $dest -Recurse -ErrorAction Stop
    [ordered]@{result='V8_PORTABLE_PACKAGE_READY';productVersion=$productVersion;coreVersion=$coreVersion;destination=$dest;install=(Join-Path $dest 'Install-JHarness.cmd');globalConnectionRequired=$false;fallback='NONE'}|ConvertTo-Json -Depth 6
  }else{
    $arguments=@{Action=$Action;ProjectPath=$project}
    if($Upgrade){$arguments.Upgrade=$true}
    if($Action -ne 'Plan'){$arguments.ApproveInstall=$true}
    $global:LASTEXITCODE=0
    $observed=& $installer @arguments
    $installExit=$LASTEXITCODE
    if($installExit -ne 0){throw 'V8_LOCAL_INSTALLATION_FAILED_INSPECT_RECOVERY'}
    $installed=($observed|Out-String)|ConvertFrom-Json
    if($Action -eq 'Recover'){
      if($installed.result -notmatch '^(?:COMPLETED_UPGRADE_VERIFIED|[A-Z0-9_]+_(?:RESTORED_VERIFIED|PREPARATION_INTERRUPTED_ORIGINAL_VERIFIED))$' -or
        -not $installed.transaction -or -not $installed.recoveredUtc){throw 'V8_RECOVERY_RESULT_NOT_VERIFIED'}
    }else{
      $expectedResults=if(-not $Upgrade){@('V8_PROJECT_INSTALL_COMPLETE')}elseif($Action -eq 'Plan'){
        @('PLAN_ONLY_NOT_UPGRADED','ALREADY_CURRENT')
      }else{@('V8_PROJECT_UPGRADE_COMPLETE','ALREADY_CURRENT')}
      if($installed.result -notin $expectedResults -or $installed.coreVersion -ne $coreVersion -or $installed.productVersion -ne $productVersion -or
        ($installed.result -ne 'PLAN_ONLY_NOT_UPGRADED' -and $installed.effective -ne 'READY_LOCAL') -or
        (-not $Upgrade -and $installed.globalConnectionRequired -ne $false)){throw 'V8_INSTALLATION_RESULT_NOT_VERIFIED'}
    }
    $installed|ConvertTo-Json -Depth 6
  }
}catch{
  [Console]::Error.WriteLine((@{result='BLOCKED';productVersion=$productVersion;error=$_.Exception.Message;fallback='NONE';work=$work}|ConvertTo-Json -Compress))
  exit 2
}finally{
  # Only this newly-created download tree may be recursively removed.
  $resolved=[IO.Path]::GetFullPath($work)
  if((Split-Path -Parent $resolved) -eq $tempRoot.TrimEnd('\') -and (Split-Path -Leaf $resolved) -like 'JHarness-v8-download-*'){
    Assert-Safe $resolved
    if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
  }
}
