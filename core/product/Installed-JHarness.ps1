# Installed J Harness user launcher. This is not an independently authenticated supervisor.
[CmdletBinding()]
param([ValidateSet('Start','Doctor','Uninstall')][string]$Action='Start',[switch]$ApproveUninstall)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$receiptFile=Join-Path $PSScriptRoot 'receipt.json'
if(-not(Test-Path -LiteralPath $receiptFile -PathType Leaf)){throw 'J_HARNESS_INSTALL_RECEIPT_MISSING'}
$receipt=Get-Content -LiteralPath $receiptFile -Raw -Encoding UTF8 | ConvertFrom-Json
if($receipt.schema -ne 1 -or $receipt.product -ne 'J Harness' -or $receipt.securityMode -ne 'ADVISORY_NOT_OS_ENFORCED'){
 throw 'J_HARNESS_INSTALL_RECEIPT_INVALID'
}
if([IO.Path]::GetFullPath([string]$receipt.managedRoot) -ne $root){throw 'J_HARNESS_INSTALL_ROOT_MISMATCH'}
$node=[string]$receipt.nodePath
$cli=[string]$receipt.cliPath
$codexHome=[string]$receipt.codexHome
$setup=Join-Path $codexHome 'j-harness-core\runtime\core\setup.mjs'
$sha='ae1a50511be58e987483fdbc12125407443926d2d394669ade2352776e920dd3'
if($node -ne (Join-Path $root 'node-v22.22.2\node.exe')){throw 'J_HARNESS_NODE_OUTSIDE_OWN_ROOT'}
function Assert-NoReparse([string]$p){
 $q=[IO.Path]::GetFullPath($p)
 while($q){if(Test-Path -LiteralPath $q){if(((Get-Item -LiteralPath $q -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'REPARSE_REFUSED'}};$parent=[IO.Path]::GetDirectoryName($q);if(-not $parent -or $parent -eq $q){break};$q=$parent}
}
foreach($p in @($root,$receiptFile,$node,$cli,$codexHome,$setup)){Assert-NoReparse $p}
if(-not(Test-Path -LiteralPath $node -PathType Leaf) -or (Get-FileHash -LiteralPath $node -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sha){throw 'J_HARNESS_RUNTIME_NODE_HASH_INVALID'}
if([string]$receipt.cliSha256 -match '^[a-f0-9]{64}$'){
 if(-not(Test-Path -LiteralPath $cli -PathType Leaf) -or (Get-FileHash -LiteralPath $cli -Algorithm SHA256).Hash.ToLowerInvariant() -ne [string]$receipt.cliSha256){throw 'J_HARNESS_PRIVATE_CLI_HASH_INVALID'}
} elseif(-not(Test-Path -LiteralPath $cli -PathType Leaf)){throw 'EXISTING_CLI_MISSING'}
$envPathBefore=$env:Path;$homeBefore=$env:CODEX_HOME
try {
 $env:Path=(Split-Path -Parent $node)+[IO.Path]::PathSeparator+(Split-Path -Parent $cli)+[IO.Path]::PathSeparator+$env:Path
 $env:CODEX_HOME=$codexHome
 if($Action -eq 'Doctor'){
  if(-not(Test-Path -LiteralPath $setup -PathType Leaf)){throw 'J_HARNESS_CORE_MISSING'}
  & $node $setup run doctor
  if($LASTEXITCODE -ne 0){throw 'J_HARNESS_DOCTOR_FAILED'}
  return
 }
 if($Action -eq 'Start'){
  if(-not(Test-Path -LiteralPath $setup -PathType Leaf)){throw 'J_HARNESS_CORE_MISSING'}
  $doctor=& $node $setup run doctor
  if($LASTEXITCODE -ne 0){throw 'J_HARNESS_DOCTOR_FAILED_START_BLOCKED'}
  try{$state=($doctor | Out-String)|ConvertFrom-Json}catch{throw 'J_HARNESS_DOCTOR_OUTPUT_INVALID'}
  if($state.effective -ne 'CONNECTED_FOR_NEW_SESSIONS' -or $state.backupStatus -ne 'MATCH'){
   throw ('J_HARNESS_GUIDANCE_NOT_CONNECTED: '+$state.effective)
  }
  Write-Host 'J Harness advisory mode: Codex starts with existing profile; OS-level Supervisor NOT enforced.' -ForegroundColor Yellow
  Write-Host 'Codex first-time authentication, if required, is handled by Codex itself.'
  & $cli
  if($LASTEXITCODE -ne 0){throw ('CODEX_EXIT_'+$LASTEXITCODE)}
  return
 }
 if($Action -eq 'Uninstall'){
  if(-not $ApproveUninstall){throw 'EXPLICIT_UNINSTALL_APPROVAL_REQUIRED'}
  if(-not(Test-Path -LiteralPath $setup -PathType Leaf)){throw 'CORE_MISSING_MANUAL_RECOVERY_REQUIRED'}
  $result=& $node $setup uninstall
  if($LASTEXITCODE -ne 0){throw 'J_HARNESS_CORE_UNINSTALL_FAILED_KEEP_RECEIPT'}
  # Preserve all original Codex credentials, config and MCP. Only unlink the managed guidance block.
  $removed=New-Object System.Collections.Generic.List[string]
  if($receipt.privateCliCreated -eq $true) {
   $privateExpected=Join-Path $root 'cli\codex-v0.166.0\codex.exe'
   if($cli -ne $privateExpected){throw 'UNINSTALL_PRIVATE_CLI_PATH_INVALID'}
   if(Test-Path -LiteralPath $cli){Remove-Item -LiteralPath $cli -Force -ErrorAction Stop;$removed.Add('owned_private_codex')}
  }
  if($receipt.nodeOwned -eq $true -and (Test-Path -LiteralPath $node)){
   Remove-Item -LiteralPath $node -Force -ErrorAction Stop;$removed.Add('owned_private_node')
  }
  foreach($name in @('J_Harness_Start.cmd','J_Harness_Doctor.cmd','J_Harness_Remove.cmd')){
    $launcher=Join-Path $root $name
    if(Test-Path -LiteralPath $launcher){
      Assert-NoReparse $launcher
      $ownedDigest=[string]$receipt.launcherSha256.$name
      if($ownedDigest -match '^[a-f0-9]{64}$' -and (Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash.ToLowerInvariant() -eq $ownedDigest){
        Remove-Item -LiteralPath $launcher -Force -ErrorAction Stop;$removed.Add($name)
      }else{$removed.Add(('user_modified_launcher_preserved:'+ $name))}
    }
  }
  Remove-Item -LiteralPath $receiptFile -Force -ErrorAction Stop
  # Keep archived Core for audit/recovery. Remove only known owned app source.
  $program=Join-Path $PSScriptRoot 'Installed-JHarness.ps1'
  try{Remove-Item -LiteralPath $program -Force -ErrorAction Stop}catch{$removed.Add('app_script_retained_for_manual_cleanup')}
  [ordered]@{result='UNLINKED_AND_ORIGINAL_GUIDANCE_RESTORED';archivesPreserved=$true;removed=$removed.ToArray();credentialsChanged=$false;globalPathChanged=$false} | ConvertTo-Json -Depth 7
 }
} finally {$env:Path=$envPathBefore;$env:CODEX_HOME=$homeBefore}
