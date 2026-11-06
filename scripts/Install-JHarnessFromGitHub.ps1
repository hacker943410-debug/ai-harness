# J Harness v8 alpha: Windows x64, PowerShell-only CLI installer.
# Unsigned and advisory. Owner consent required; no OS-enforced AI security.
[CmdletBinding()]
param(
 [ValidateSet('Plan','Install','Package')][string]$Action='Plan',
 [switch]$ApproveInstall,
 [string]$CodexHome,
 [string]$ManagedRoot,
 [string]$Destination
)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$sourceSha='a4f8e258d729f302e701d00a52610b778821fcaf'
$nodeSha='ae1a50511be58e987483fdbc12125407443926d2d394669ade2352776e920dd3'
$nodeUrl='https://nodejs.org/dist/v22.22.2/win-x64/node.exe'
$archiveUrl='https://github.com/hacker943410-debug/ai-harness/archive/'+$sourceSha+'.zip'
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or
 -not [Environment]::Is64BitOperatingSystem -or
 [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64') {throw 'WINDOWS_X64_REQUIRED'}
if ($PSVersionTable.PSVersion.Major -lt 5) {throw 'POWERSHELL_5_OR_LATER_REQUIRED'}
if (-not $env:TEMP -or -not $env:LOCALAPPDATA) {throw 'WINDOWS_USER_PROFILE_REQUIRED'}
if (-not $CodexHome) {$CodexHome=if($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $HOME '.codex'}}
if (-not $ManagedRoot) {$ManagedRoot=Join-Path $env:LOCALAPPDATA 'JHarness-Bootstrap'}
$CodexHome=[IO.Path]::GetFullPath($CodexHome)
$ManagedRoot=[IO.Path]::GetFullPath($ManagedRoot)
function Assert-SafePath([string]$p) {
 if(-not $p -or $p.StartsWith('\\') -or $p.StartsWith('//')){throw 'UNSAFE_OR_NETWORK_PATH_REFUSED'}
 $full=[IO.Path]::GetFullPath($p)
 if($full -eq [IO.Path]::GetPathRoot($full)){throw 'DRIVE_ROOT_REFUSED'}
 for($item=$full;$item;){
  if(Test-Path -LiteralPath $item){
   $entry=Get-Item -LiteralPath $item -Force
   if(($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'REPARSE_PATH_REFUSED'}
  }
  $parent=[IO.Path]::GetDirectoryName($item)
  if(-not $parent -or $parent -eq $item){break}
  $item=$parent
 }
}
Assert-SafePath $CodexHome
Assert-SafePath $ManagedRoot
$plan=[ordered]@{
 product='J Harness';channel='v8.0.0-alpha.1-pinned-cli-preview';action=$Action
 sourceRevision=$sourceSha;platform='Windows x64';client='codex'
 node='private pinned v22.22.2';codex='official pinned v0.166.0 if not installed'
 codexHome=$CodexHome;managedRoot=$ManagedRoot
 credentialsChanged=$false;systemPathChanged=$false;supervisorEnforced=$false
 modelCalls=0;result='PLAN_ONLY_NOT_INSTALLED'
}
if($Action -eq 'Plan'){$plan|ConvertTo-Json -Depth 6;return}
if($Action -eq 'Package' -and [string]::IsNullOrWhiteSpace($Destination)){throw 'PACKAGE_DESTINATION_REQUIRED'}
if($Action -eq 'Install' -and -not $ApproveInstall){
 Write-Host 'ALPHA TEST CANDIDATE: this does NOT enforce OS-level AI isolation.'
 Write-Host 'Uses app-private Node and Codex, preserves existing Codex login and settings.'
 $typed=Read-Host 'Type INSTALL to approve download and installation'
 if($typed -cne 'INSTALL'){$plan.result='CANCELLED_NO_DOWNLOAD';$plan|ConvertTo-Json -Depth 6;return}
}
$work=Join-Path ([IO.Path]::GetFullPath($env:TEMP)) ('JHAlphaCli_'+[Guid]::NewGuid().ToString('N'))
$created=$false
try{
 Assert-SafePath $work
 [IO.Directory]::CreateDirectory($work)|Out-Null
 $created=$true
 [IO.File]::WriteAllText((Join-Path $work '.jh-alpha-temp'),'JH_ALPHA_ONLY',[Text.Encoding]::ASCII)
 $zip=Join-Path $work 'source.zip'
 $unpacked=Join-Path $work 'source'
 $node=Join-Path $work 'node.exe'
 $package=Join-Path $work 'package'
 [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
 Write-Host ('Downloading pinned GitHub source commit '+$sourceSha)
 Invoke-WebRequest -Uri $archiveUrl -OutFile $zip -UseBasicParsing -MaximumRedirection 8 -ErrorAction Stop
 if((Get-Item -LiteralPath $zip).Length -lt 10000 -or (Get-Item -LiteralPath $zip).Length -gt 50000000){throw 'SOURCE_ARCHIVE_SIZE_INVALID'}
 [IO.Directory]::CreateDirectory($unpacked)|Out-Null
 Expand-Archive -LiteralPath $zip -DestinationPath $unpacked -ErrorAction Stop
 $roots=@(Get-ChildItem -LiteralPath $unpacked -Force)
 if($roots.Count -ne 1 -or -not $roots[0].PSIsContainer -or
    $roots[0].Name -notlike ('ai-harness-'+$sourceSha.Substring(0,7)+'*')){throw 'UNEXPECTED_SOURCE_ARCHIVE_LAYOUT'}
 $repo=$roots[0].FullName
 Assert-SafePath $repo
 foreach($required in @('core\build-integrated-product.mjs','core\product\Install-JHarnessProduct.ps1','core\environment\bootstrap-manifest.json','core\product\codex-lock.json')){
  if(-not(Test-Path -LiteralPath (Join-Path $repo $required) -PathType Leaf)){throw ('PINNED_SOURCE_FILE_MISSING: '+$required)}
 }
 Write-Host 'Downloading official pinned portable Node v22.22.2'
 Invoke-WebRequest -Uri $nodeUrl -OutFile $node -UseBasicParsing -MaximumRedirection 8 -ErrorAction Stop
 if((Get-FileHash -LiteralPath $node -Algorithm SHA256).Hash.ToLowerInvariant() -ne $nodeSha){throw 'NODE_BINARY_SHA256_MISMATCH'}
 $nodeVersion=& $node --version
 if($LASTEXITCODE -ne 0 -or ($nodeVersion|Out-String).Trim() -ne 'v22.22.2'){throw 'PINNED_NODE_EXECUTION_FAILED'}
 & $node (Join-Path $repo 'core\build-integrated-product.mjs') --out $package --node-binary $node
 if($LASTEXITCODE -ne 0){throw 'INTEGRATED_PACKAGE_BUILD_FAILED'}
 if(-not(Test-Path -LiteralPath (Join-Path $package 'SHA256_MANIFEST.json') -PathType Leaf)){throw 'PACKAGE_MANIFEST_MISSING'}
 $installer=Join-Path $package 'core\product\Install-JHarnessProduct.ps1'
 if(-not(Test-Path -LiteralPath $installer -PathType Leaf)){throw 'INSTALLER_ENTRY_MISSING'}
 if($Action -eq 'Package'){
  $dest=[IO.Path]::GetFullPath($Destination)
  Assert-SafePath $dest
  if(Test-Path -LiteralPath $dest){throw 'DESTINATION_ALREADY_EXISTS_PRESERVED'}
  Copy-Item -LiteralPath $package -Destination $dest -Recurse -ErrorAction Stop
  [ordered]@{result='UNSIGNED_PACKAGE_BUILT';path=$dest;run='J_Harness_Install.cmd';sourceRevision=$sourceSha;supervisorEnforced=$false}|ConvertTo-Json -Depth 6
 }else{
  & $installer -Action Plan -CodexHome $CodexHome -ManagedRoot $ManagedRoot
  if($LASTEXITCODE -ne 0){throw 'FINAL_PACKAGE_PREFLIGHT_FAILED'}
  & $installer -Action Install -ApproveInstall -CodexHome $CodexHome -ManagedRoot $ManagedRoot
  if($LASTEXITCODE -ne 0){throw 'INSTALL_FAILED_INSPECT_ROLLBACK_REPORT'}
  [ordered]@{result='CLI_INSTALL_COMPLETE';start=(Join-Path $ManagedRoot 'J_Harness_Start.cmd');doctor=(Join-Path $ManagedRoot 'J_Harness_Doctor.cmd');remove=(Join-Path $ManagedRoot 'J_Harness_Remove.cmd');sourceRevision=$sourceSha;supervisorEnforced=$false;modelCalls=0}|ConvertTo-Json -Depth 6
 }
}finally{
 if($created -and (Split-Path -Parent $work) -eq [IO.Path]::GetFullPath($env:TEMP) -and
    (Split-Path -Leaf $work) -like 'JHAlphaCli_*' -and
    (Test-Path -LiteralPath (Join-Path $work '.jh-alpha-temp') -PathType Leaf) -and
    [IO.File]::ReadAllText((Join-Path $work '.jh-alpha-temp')) -eq 'JH_ALPHA_ONLY'){
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
 }
}
