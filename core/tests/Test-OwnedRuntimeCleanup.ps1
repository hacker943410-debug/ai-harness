# Safe Windows PowerShell 5.1 regression: extract only the cleanup helpers.
# No installed launcher, profile, receipt, process or network is accessed.
$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot '..\product\Installed-JHarness.ps1'
$tokens=$null;$parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'LAUNCHER_PARSE_FAILED'}
foreach($name in @('Assert-NoReparse','Remove-OwnedRuntimeFile')){
 $definition=@($ast.FindAll({param($entry) $entry -is [Management.Automation.Language.FunctionDefinitionAst]},$true) | Where-Object {$_.Name -eq $name})
 if($definition.Count -ne 1){throw ('HELPER_NOT_FOUND_'+$name)}
 . ([scriptblock]::Create($definition[0].Extent.Text))
}
$fixture=[IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('jh-owned-cleanup-'+[guid]::NewGuid().ToString('N'))))
[void][IO.Directory]::CreateDirectory($fixture)
$binary=Join-Path $fixture 'owned-node.exe'
function Assert-True($condition,[string]$message){if(-not $condition){throw $message}}
function Reset-Fixture {
 [IO.File]::WriteAllText($binary,'owned fixture bytes')
 $script:attempts=0;$script:sleeps=0;$script:failures=0;$script:changeAfterFailure=$false
 return (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Remove-Item {
 param([string]$LiteralPath,[switch]$Force,[string]$ErrorAction)
 Assert-True ($LiteralPath -eq $binary) 'DELETE_PATH_WIDENED'
 $script:attempts++
 if($script:attempts -le $script:failures){
  if($script:changeAfterFailure){[IO.File]::WriteAllText($binary,'user replacement')}
  throw [IO.IOException]::new('simulated sharing violation')
 }
 Microsoft.PowerShell.Management\Remove-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
}
function Start-Sleep {param([int]$Milliseconds) $script:sleeps+=$Milliseconds}
try {
 $digest=Reset-Fixture;$script:failures=2
 Assert-True (Remove-OwnedRuntimeFile $binary $digest) 'TRANSIENT_LOCK_NOT_REMOVED'
 Assert-True ($script:attempts -eq 3 -and $script:sleeps -eq 400 -and -not(Test-Path -LiteralPath $binary)) 'TRANSIENT_RETRY_INVALID'

 $digest=Reset-Fixture;$script:failures=100;$caught=$false
 try{Remove-OwnedRuntimeFile $binary $digest | Out-Null}catch{$caught=$_.Exception -is [IO.IOException]}
 Assert-True ($caught -and $script:attempts -eq 11 -and $script:sleeps -eq 2000 -and (Test-Path -LiteralPath $binary)) 'PERSISTENT_LOCK_NOT_BOUNDED'

 $digest=Reset-Fixture;[IO.File]::WriteAllText($binary,'user replacement');$caught=$false
 try{Remove-OwnedRuntimeFile $binary $digest | Out-Null}catch{$caught=$_.Exception.Message -match 'OWNED_RUNTIME_CHANGED_PRESERVED'}
 Assert-True ($caught -and $script:attempts -eq 0 -and [IO.File]::ReadAllText($binary) -eq 'user replacement') 'CHANGED_DIGEST_NOT_PRESERVED'

 $digest=Reset-Fixture;$script:failures=1;$script:changeAfterFailure=$true;$caught=$false
 try{Remove-OwnedRuntimeFile $binary $digest | Out-Null}catch{$caught=$_.Exception.Message -match 'OWNED_RUNTIME_CHANGED_PRESERVED'}
 Assert-True ($caught -and $script:attempts -eq 1 -and [IO.File]::ReadAllText($binary) -eq 'user replacement') 'RETRY_DIGEST_NOT_RECHECKED'
 Write-Output 'PASS: transient lock, bounded persistent lock, changed digest and retry digest preservation'
} finally {
 $expectedParent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
 if([IO.Path]::GetDirectoryName($fixture) -ne $expectedParent -or [IO.Path]::GetFileName($fixture) -notlike 'jh-owned-cleanup-*'){throw 'FIXTURE_CLEANUP_PATH_INVALID'}
 Microsoft.PowerShell.Management\Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction Stop
}
