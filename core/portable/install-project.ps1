# J Harness v8: project-local installation. No Codex-home registration is required.
[CmdletBinding()]
param(
  [ValidateSet('Plan','Install')][string]$Action='Plan',
  [switch]$ApproveInstall,
  [string]$ProjectPath
)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$expectedNode='ae1a50511be58e987483fdbc12125407443926d2d394669ade2352776e920dd3'
$expectedProduct='8.0.0-alpha.3'
$packageRoot=[IO.Path]::GetFullPath($PSScriptRoot)
$sourceRuntime=Join-Path $packageRoot '.agents\j-harness'
if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or -not [Environment]::Is64BitOperatingSystem){throw 'WINDOWS_X64_REQUIRED'}
if([Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64'){throw 'WINDOWS_X64_REQUIRED'}
if(-not $ProjectPath){$ProjectPath=$packageRoot}
$project=[IO.Path]::GetFullPath($ProjectPath)
function Assert-Plain([string]$value){
  if(-not $value -or $value.StartsWith('\\') -or $value.StartsWith('//')){throw 'LOCAL_PROJECT_PATH_REQUIRED'}
  $full=[IO.Path]::GetFullPath($value)
  if($full -eq [IO.Path]::GetPathRoot($full)){throw 'DRIVE_ROOT_REFUSED'}
  for($cursor=$full;$cursor;){
    if(Test-Path -LiteralPath $cursor){
      if(((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw ('REPARSE_POINT_REFUSED: '+$cursor)}
    }
    $parent=[IO.Path]::GetDirectoryName($cursor)
    if(-not $parent -or $parent -eq $cursor){break};$cursor=$parent
  }
}
function Within([string]$root,[string]$relative){
  if(-not $relative -or [IO.Path]::IsPathRooted($relative) -or $relative.Contains(':') -or @($relative -split '[\\/]' | Where-Object {$_ -eq '' -or $_ -eq '.' -or $_ -eq '..'}).Count){throw 'UNSAFE_MANIFEST_PATH'}
  $full=[IO.Path]::GetFullPath((Join-Path $root $relative))
  if(-not $full.StartsWith(([IO.Path]::GetFullPath($root).TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase)){throw 'PATH_ESCAPE_REFUSED'}
  Assert-Plain $full;return $full
}
function Digest([string]$file){return (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
function Read-Json([string]$file){return (Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json)}
function Runtime-Files([string]$root){
  $queue=New-Object 'System.Collections.Generic.Queue[string]';$queue.Enqueue($root)
  while($queue.Count){
    $dir=$queue.Dequeue()
    foreach($entry in Get-ChildItem -LiteralPath $dir -Force){
      if(($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'LINK_IN_RUNTIME_REFUSED'}
      $rel=$entry.FullName.Substring($root.TrimEnd('\').Length+1).Replace('\','/')
      if($rel -eq 'tests' -or $rel -eq 'manifest.json' -or $rel -eq 'PORTABLE.md'){continue}
      if($entry.PSIsContainer){$queue.Enqueue($entry.FullName)}else{$rel}
    }
  }
}
function Check-Runtime([string]$root,[string]$manifestSha){
  Assert-Plain $root
  $file=Join-Path $root 'manifest.json';Assert-Plain $file
  if(-not(Test-Path -LiteralPath $file -PathType Leaf) -or (Digest $file) -ne $manifestSha){throw 'PORTABLE_MANIFEST_DIGEST_MISMATCH'}
  $m=Read-Json $file
  if($m.schema -ne 1 -or $m.product -ne 'J Harness Core' -or $m.mode -ne 'PROJECT_PORTABLE' -or $m.version -notlike '8.*' -or $m.distributionVersion -ne $expectedProduct){throw 'EXPECTED_V8_PORTABLE_PRODUCT_REQUIRED'}
  $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach($row in $m.files){
    $full=Within $root ([string]$row.path)
    if(-not $seen.Add(([string]$row.path).Replace('\','/'))){throw 'DUPLICATE_MANIFEST_PATH'}
    if($row.sha256 -notmatch '^[a-f0-9]{64}$' -or -not(Test-Path -LiteralPath $full -PathType Leaf) -or (Digest $full) -ne $row.sha256){throw ('RUNTIME_HASH_MISMATCH: '+$row.path)}
  }
  $files=@(Runtime-Files $root)
  if($files.Count -ne $seen.Count){throw 'INCOMPLETE_RUNTIME_MANIFEST'}
  foreach($rel in $files){if(-not $seen.Contains($rel)){throw 'UNLISTED_RUNTIME_FILE'}}
  $package=Read-Json (Join-Path $root 'runtime\core\package.json')
  if($package.version -ne $m.version){throw 'CORE_VERSION_MISMATCH'}
  if((Digest (Join-Path $root 'vendor\win-x64\node.exe')) -ne $expectedNode){throw 'NODE_RELEASE_DIGEST_MISMATCH'}
  return $m
}
function Invoke-Node([string]$runtime,[string]$entry,[string[]]$Arguments){
  $binary=Join-Path $runtime 'vendor\win-x64\node.exe'
  # Windows PowerShell 5.1 otherwise decodes native JSON with the active OEM codepage.
  # Quote each argv element using the Windows CommandLineToArgvW rules.
  $quoted=foreach($arg in @($entry)+$Arguments){
    '"'+[regex]::Replace([regex]::Replace($arg,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'
  }
  $info=New-Object Diagnostics.ProcessStartInfo
  $info.FileName=$binary;$info.Arguments=($quoted -join ' ')
  $info.UseShellExecute=$false;$info.CreateNoWindow=$true
  $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
  $info.StandardOutputEncoding=[Text.UTF8Encoding]::new($false)
  $info.StandardErrorEncoding=[Text.UTF8Encoding]::new($false)
  $process=New-Object Diagnostics.Process
  $process.StartInfo=$info
  try{
    if(-not $process.Start()){throw 'BUNDLED_NODE_START_FAILED'}
    $output=$process.StandardOutput.ReadToEndAsync();$errors=$process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $value=$output.GetAwaiter().GetResult();$message=$errors.GetAwaiter().GetResult()
    if($process.ExitCode -ne 0){throw ('INSTALLED_V8_CORE_COMMAND_FAILED: '+$message.Trim())}
    return $value
  }finally{$process.Dispose()}
}
function Invoke-Core([string]$runtime,[string[]]$Arguments){
  return ((Invoke-Node $runtime (Join-Path $runtime 'portable.mjs') (@('--project',$project)+$Arguments))|ConvertFrom-Json)
}
Assert-Plain $packageRoot;Assert-Plain $project;Assert-Plain $sourceRuntime
$sourceManifest=Join-Path $sourceRuntime 'manifest.json'
if(-not(Test-Path -LiteralPath $sourceManifest -PathType Leaf)){throw 'COMPLETE_V8_PACKAGE_REQUIRED_NO_V7_FALLBACK'}
$manifestSha=Digest $sourceManifest
$manifest=Check-Runtime $sourceRuntime $manifestSha
$targetRuntime=Within $project '.agents/j-harness'
$binding=Within $project '.ai/harness-project.json'
$guidance=Within $project 'AGENTS.md'
$existed=Test-Path -LiteralPath $project
if($existed -and -not(Test-Path -LiteralPath $project -PathType Container)){throw 'PROJECT_DIRECTORY_REQUIRED'}
$existing=$null
if(Test-Path -LiteralPath $binding){
  $existing=Read-Json $binding
  if($existing.harness.product -ne 'J Harness Core'){throw 'EXISTING_PROJECT_HARNESS_REQUIRES_EXPLICIT_MIGRATION'}
}
if(-not $existing){
  foreach($legacy in @('.ai/harness.yaml','.ai/HARNESS.md')){
    if(Test-Path -LiteralPath (Within $project $legacy)){throw 'EXISTING_PROJECT_HARNESS_REQUIRES_EXPLICIT_MIGRATION'}
  }
}
$already=Test-Path -LiteralPath $targetRuntime
if($already){$null=Check-Runtime $targetRuntime $manifestSha}
if($existing -and -not $already){throw 'PARTIAL_EXISTING_INSTALLATION_PRESERVED_REVIEW_REQUIRED'}
$launchers=@('JHarness.cmd','JHarness.ps1','JHarness-README.md')
foreach($name in $launchers){
  $from=Join-Path $packageRoot $name;$to=Within $project $name
  if(-not(Test-Path -LiteralPath $from -PathType Leaf)){throw ('PACKAGE_LAUNCHER_MISSING: '+$name)}
  if((Test-Path -LiteralPath $to) -and (Digest $to) -ne (Digest $from)){throw ('EXISTING_USER_FILE_PRESERVED: '+$name)}
}
$plan=[ordered]@{product='J Harness';productVersion=$expectedProduct;coreVersion=$manifest.version;mode='PROJECT_PORTABLE';action=$Action;project=$project;globalConnectionRequired=$false;nodeInstalledGlobally=$false;codexRequired=$false;systemPathChanged=$false;fallback='NONE';manifestSha256=$manifestSha;alreadyPresent=[bool]$already;result='PLAN_ONLY_NOT_INSTALLED'}
if($Action -eq 'Plan'){$plan|ConvertTo-Json -Depth 6;return}
if(-not $ApproveInstall){
  $typed=Read-Host ('Install J Harness v8 in '+$project+'? Type INSTALL')
  if($typed -cne 'INSTALL'){$plan.result='CANCELLED_NO_INSTALL';$plan|ConvertTo-Json -Depth 6;return}
}
$transaction=[guid]::NewGuid().ToString('N')
$recordRoot=Within $project ('.jh-artifacts/j-harness-core/installations/'+$transaction)
$prepared=Join-Path $recordRoot 'runtime.prepare'
$copied=New-Object 'System.Collections.Generic.List[string]'
$runtimeCreated=$false
$guidanceBefore=$null;$bindingBefore=$null;$guidanceAfter=$null;$bindingAfter=$null;$setupCompleted=$false
if(Test-Path -LiteralPath $guidance -PathType Leaf){$guidanceBefore=[IO.File]::ReadAllBytes($guidance)}
if(Test-Path -LiteralPath $binding -PathType Leaf){$bindingBefore=[IO.File]::ReadAllBytes($binding)}
function Restore-Control([string]$file,[byte[]]$before,[byte[]]$after){
  Assert-Plain $file
  if($null -eq $after){return}
  if(-not(Test-Path -LiteralPath $file -PathType Leaf)){throw 'CONTROL_CHANGED_DURING_RECOVERY'}
  $current=[IO.File]::ReadAllBytes($file)
  if([Convert]::ToBase64String($current) -cne [Convert]::ToBase64String($after)){throw 'USER_CONTROL_CHANGED_PRESERVED'}
  if($null -eq $before){Remove-Item -LiteralPath $file -Force}
  else{
    $restore=$file+'.restore-'+[guid]::NewGuid().ToString('N')+'.tmp'
    Assert-Plain $restore
    if(-not $restore.StartsWith($project.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'RESTORE_OUTSIDE_PROJECT_REFUSED'}
    [IO.File]::WriteAllBytes($restore,$before)
    Move-Item -LiteralPath $restore -Destination $file -Force -ErrorAction Stop
  }
}
try{
  [IO.Directory]::CreateDirectory($recordRoot)|Out-Null
  if(-not $already){
    [IO.Directory]::CreateDirectory((Split-Path -Parent $targetRuntime))|Out-Null
    Copy-Item -LiteralPath $sourceRuntime -Destination $prepared -Recurse -ErrorAction Stop
    $null=Check-Runtime $prepared $manifestSha
    if(Test-Path -LiteralPath $targetRuntime){throw 'DESTINATION_CHANGED_DURING_PREPARATION'}
    # Both final target and preparation are resolved inside this explicitly selected project.
    if(-not $prepared.StartsWith($project.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -or -not $targetRuntime.StartsWith($project.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'MOVE_OUTSIDE_PROJECT_REFUSED'}
    Move-Item -LiteralPath $prepared -Destination $targetRuntime -ErrorAction Stop
    $runtimeCreated=$true
  }
  foreach($name in $launchers){
    $to=Within $project $name
    if(-not(Test-Path -LiteralPath $to)){Copy-Item -LiteralPath (Join-Path $packageRoot $name) -Destination $to -ErrorAction Stop;$copied.Add($name)}
  }
  $setup=Invoke-Node $targetRuntime (Join-Path $targetRuntime 'setup.mjs') @('--project',$project)
  $guidanceAfter=[IO.File]::ReadAllBytes($guidance);$bindingAfter=[IO.File]::ReadAllBytes($binding);$setupCompleted=$true
  $setupResult=($setup|Out-String)|ConvertFrom-Json
  if($setupResult.status -ne 'READY_LOCAL' -or $setupResult.version -ne $manifest.version){throw 'PROJECT_SETUP_RESULT_INVALID'}
  $observed=Invoke-Core $targetRuntime @('doctor')
  if($observed.version -ne $manifest.version -or $observed.effective -ne 'READY_LOCAL' -or $observed.globalConnectionRequired -ne $false){throw 'V8_POST_INSTALL_VERIFICATION_FAILED'}
  $receipt=[ordered]@{result='V8_PROJECT_INSTALL_COMPLETE';productVersion=$expectedProduct;coreVersion=$observed.version;mode=$observed.mode;effective=$observed.effective;project=$project;globalConnectionRequired=$false;fallback='NONE';alreadyPresent=[bool]$already;guidanceChanged=[bool]$setupResult.changed;manifestSha256=$manifestSha;systemPathChanged=$false;credentialsChanged=$false;installedAtUtc=[DateTime]::UtcNow.ToString('o');launcher=(Join-Path $project 'JHarness.cmd')}
  [IO.File]::WriteAllText((Join-Path $recordRoot 'receipt.json'),($receipt|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
  $receipt|ConvertTo-Json -Depth 6
}catch{
  $message=$_.Exception.Message;$recovery='ORIGINAL_FILES_PRESERVED'
  try{
    if($setupCompleted){Restore-Control $guidance $guidanceBefore $guidanceAfter;Restore-Control $binding $bindingBefore $bindingAfter}
    if($runtimeCreated -and (Test-Path -LiteralPath $targetRuntime)){
      $null=Check-Runtime $targetRuntime $manifestSha
      $kept=Join-Path $recordRoot 'failed-runtime'
      Assert-Plain $kept
      if(-not $targetRuntime.StartsWith($project.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -or -not $kept.StartsWith($project.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'RECOVERY_MOVE_OUTSIDE_PROJECT_REFUSED'}
      Move-Item -LiteralPath $targetRuntime -Destination $kept -ErrorAction Stop
      $recovery='NEW_RUNTIME_ARCHIVED_ORIGINAL_FILES_PRESERVED'
    }
    foreach($name in $copied){
      $path=Within $project $name
      if((Test-Path -LiteralPath $path) -and (Digest $path) -eq (Digest (Join-Path $packageRoot $name))){Remove-Item -LiteralPath $path -Force}
    }
  }catch{$recovery='MANUAL_RECOVERY_REQUIRED_NO_USER_FILES_DELETED'}
  [Console]::Error.WriteLine((@{result='BLOCKED';productVersion=$expectedProduct;error=$message;recovery=$recovery;fallback='NONE'}|ConvertTo-Json -Compress))
  exit 2
}
