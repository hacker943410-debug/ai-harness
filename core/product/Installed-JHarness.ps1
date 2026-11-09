# Installed J Harness user launcher. This is not an independently authenticated supervisor.
[CmdletBinding()]
param([ValidateSet('Start','Doctor','Verify','Uninstall')][string]$Action='Start',[switch]$ApproveUninstall)
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
$coreCli=Join-Path $codexHome 'j-harness-core\runtime\core\cli.mjs'
$sha='ae1a50511be58e987483fdbc12125407443926d2d394669ade2352776e920dd3'
if($node -ne (Join-Path $root 'node-v22.22.2\node.exe')){throw 'J_HARNESS_NODE_OUTSIDE_OWN_ROOT'}
function Assert-NoReparse([string]$p){
 $q=[IO.Path]::GetFullPath($p)
 while($q){if(Test-Path -LiteralPath $q){if(((Get-Item -LiteralPath $q -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'REPARSE_REFUSED'}};$parent=[IO.Path]::GetDirectoryName($q);if(-not $parent -or $parent -eq $q){break};$q=$parent}
}
function Remove-OwnedRuntimeFile([string]$LiteralPath,[string]$ExpectedSha256){
 if($ExpectedSha256 -notmatch '^[a-f0-9]{64}$'){throw 'OWNED_RUNTIME_EXPECTED_HASH_REQUIRED'}
 # A just-exited executable can remain locked briefly on Windows. Retry only
 # this owned file, rechecking its path and digest before every delete attempt.
 for($attempt=0;$attempt -le 10;$attempt++){
  Assert-NoReparse $LiteralPath
  if(-not(Test-Path -LiteralPath $LiteralPath -PathType Leaf)){return $false}
  if((Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $ExpectedSha256){throw 'OWNED_RUNTIME_CHANGED_PRESERVED'}
  try{Remove-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop;return $true}
  catch{
   if($attempt -eq 10 -or (-not($_.Exception -is [IO.IOException]) -and -not($_.Exception -is [UnauthorizedAccessException]))){throw}
   Start-Sleep -Milliseconds 200
  }
 }
}
foreach($p in @($root,$receiptFile,$node,$cli,$codexHome,$coreCli)){Assert-NoReparse $p}
if(-not(Test-Path -LiteralPath $node -PathType Leaf) -or (Get-FileHash -LiteralPath $node -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sha){throw 'J_HARNESS_RUNTIME_NODE_HASH_INVALID'}
if([string]$receipt.cliSha256 -match '^[a-f0-9]{64}$'){
 if(-not(Test-Path -LiteralPath $cli -PathType Leaf) -or (Get-FileHash -LiteralPath $cli -Algorithm SHA256).Hash.ToLowerInvariant() -ne [string]$receipt.cliSha256){throw 'J_HARNESS_PRIVATE_CLI_HASH_INVALID'}
} elseif(-not(Test-Path -LiteralPath $cli -PathType Leaf)){throw 'EXISTING_CLI_MISSING'}
$envPathBefore=$env:Path;$homeBefore=$env:CODEX_HOME
try {
 $env:Path=(Split-Path -Parent $node)+[IO.Path]::PathSeparator+(Split-Path -Parent $cli)+[IO.Path]::PathSeparator+$env:Path
 $env:CODEX_HOME=$codexHome
 if($Action -eq 'Doctor'){
  if(-not(Test-Path -LiteralPath $coreCli -PathType Leaf)){throw 'J_HARNESS_CORE_MISSING'}
  & $node $coreCli doctor
  if($LASTEXITCODE -ne 0){throw 'J_HARNESS_DOCTOR_FAILED'}
  return
 }
 if($Action -eq 'Verify'){
  # Read-only first-use readiness. Never inspect auth.json content or call models.
  if(-not(Test-Path -LiteralPath $coreCli -PathType Leaf)){throw 'J_HARNESS_CORE_MISSING'}
  $rawDoctor=& $node $coreCli doctor
  if($LASTEXITCODE -ne 0){throw 'J_HARNESS_CORE_DOCTOR_FAILED'}
  try{$observed=($rawDoctor|Out-String)|ConvertFrom-Json}catch{throw 'J_HARNESS_CORE_DOCTOR_INVALID'}
  $version=& $cli --version
  if($LASTEXITCODE -ne 0 -or -not($version -match 'codex')){throw 'CODEX_VERSION_PROBE_FAILED'}
  $savedPreference=$ErrorActionPreference
  try {
    # Login status returns nonzero when user must sign in. Do not print account metadata.
    $ErrorActionPreference='Continue'
    & $cli login status *> $null
    $loginExit=$LASTEXITCODE
  } finally {$ErrorActionPreference=$savedPreference}
  $coreReady=($observed.effective -eq 'CONNECTED_FOR_NEW_SESSIONS' -and $observed.backupStatus -eq 'MATCH')
  [ordered]@{
    product='J Harness';mode='ADVISORY_NOT_OS_ENFORCED';
    readiness=$(if($coreReady){'READY_FOR_FIRST_INTERACTIVE_START'}else{'BLOCKED_CORE_NEEDS_REVIEW'});
    effective=[string]$observed.effective;backupStatus=[string]$observed.backupStatus;
    codexVersion=($version|Out-String).Trim();
    authentication=$(if($loginExit -eq 0){'LOGGED_IN'}else{'SIGN_IN_REQUIRED_IN_CODEX'});
    next=$(if(-not $coreReady){'Inspect J Harness Core diagnostics'}else{'Launch J_Harness_Start.cmd; Codex manages its own login'});
    modelCalls=0;tokenContentRead=$false;osSecurityEnforced=$false
  } | ConvertTo-Json -Depth 6
  return
 }
 if($Action -eq 'Start'){
  if(-not(Test-Path -LiteralPath $coreCli -PathType Leaf)){throw 'J_HARNESS_CORE_MISSING'}
  $doctor=& $node $coreCli doctor
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
  if(-not(Test-Path -LiteralPath $coreCli -PathType Leaf)){throw 'CORE_MISSING_MANUAL_RECOVERY_REQUIRED'}
  $result=& $node (Join-Path $PSScriptRoot 'Core-Uninstall.mjs')
  if($LASTEXITCODE -ne 0){throw 'J_HARNESS_CORE_UNINSTALL_FAILED_KEEP_RECEIPT'}
  # Preserve all original Codex credentials, config and MCP. Only unlink the managed guidance block.
  $removed=New-Object System.Collections.Generic.List[string]
  if($receipt.privateCliCreated -eq $true) {
   $privateExpected=Join-Path $root 'cli\codex-v0.166.0\codex.exe'
   if($cli -ne $privateExpected){throw 'UNINSTALL_PRIVATE_CLI_PATH_INVALID'}
   if(Remove-OwnedRuntimeFile $cli ([string]$receipt.cliSha256)){$removed.Add('owned_private_codex')}
  }
  if($receipt.nodeOwned -eq $true -and (Test-Path -LiteralPath $node)){
   if(Remove-OwnedRuntimeFile $node $sha){$removed.Add('owned_private_node')}
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
  foreach($name in @('Core-Uninstall.mjs','Installed-JHarness.ps1')) {
    $program=Join-Path $PSScriptRoot $name
    try{Remove-Item -LiteralPath $program -Force -ErrorAction Stop}catch{$removed.Add(('app_script_retained:'+ $name))}
  }
  # Remove the owned app directory only when empty; preserve unexpected user data.
  if((Test-Path -LiteralPath $PSScriptRoot -PathType Container) -and
      @(Get-ChildItem -LiteralPath $PSScriptRoot -Force).Count -eq 0) {
    Remove-Item -LiteralPath $PSScriptRoot -Force -ErrorAction Stop
    $removed.Add('empty_owned_app_directory')
  }else{$removed.Add('nonempty_app_directory_preserved')}
  [ordered]@{result='UNLINKED_AND_ORIGINAL_GUIDANCE_RESTORED';archivesPreserved=$true;removed=$removed.ToArray();credentialsChanged=$false;globalPathChanged=$false} | ConvertTo-Json -Depth 7
 }
} finally {$env:Path=$envPathBefore;$env:CODEX_HOME=$homeBefore}
