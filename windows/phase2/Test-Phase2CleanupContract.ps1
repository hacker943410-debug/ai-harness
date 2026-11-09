# Safe local regression: parse ONLY the two cleanup functions, never run the lab.
# All service, native command and sleep operations below are in-process mocks.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.ServiceProcess
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Invoke-Phase2WindowsCILab.ps1'),[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count -ne 0) {throw 'LAB_PARSE_FAILED'}
foreach($name in @('Stop-Phase2LabService','Remove-Phase2LabService')) {
  $definitions=@($ast.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true))
  if($definitions.Count -ne 1) {throw 'CLEANUP_FUNCTION_NOT_UNIQUE'}
  . ([scriptblock]::Create($definitions[0].Extent.Text))
}
function Get-Service {
  param($Name,$ErrorAction)
  $mock=[pscustomobject]@{Status=$script:serviceStatus}
  $mock | Add-Member ScriptMethod WaitForStatus {param($status,$timeout) if($script:waitFails){throw 'MOCK_WAIT_FAILED'}}
  $mock | Add-Member ScriptMethod Refresh {}
  $mock | Add-Member ScriptMethod Dispose {$script:disposed++}
  return $mock
}
function Stop-Service {param($Name,$ErrorAction) if($script:stopFails){throw 'MOCK_STOP_FAILED'}}
function Start-Sleep {param($Milliseconds) $script:sleeps++}
function sc.exe {
  param($operation,$serviceName)
  if($serviceName -ne 'MockService') {throw 'UNEXPECTED_SERVICE_NAME'}
  if($operation -eq 'delete') {
    if($script:disposed -ne 1) {throw 'DELETE_WITH_OPEN_CONTROLLER'}
    $script:deletes++
    $global:LASTEXITCODE=$script:deleteExit
  } elseif($operation -eq 'query') {
    $script:queries++
    $index=[Math]::Min($script:queries-1,$script:queryExits.Count-1)
    $global:LASTEXITCODE=$script:queryExits[$index]
  } else {throw 'UNEXPECTED_SC_OPERATION'}
}
function Reset-Mocks {
  $script:disposed=0;$script:deletes=0;$script:queries=0;$script:sleeps=0
  $script:stopFails=$false;$script:waitFails=$false;$script:serviceStatus='Stopped'
  $script:deleteExit=0;$script:queryExits=@(1060)
}
function Assert-Equal($actual,$expected,[string]$label) {if($actual -ne $expected){throw ($label+': '+$actual+' != '+$expected)}}
function Assert-Fails([scriptblock]$action,[string]$expected) {
  $caught=$null
  try {& $action} catch {$caught=$_.Exception.Message}
  if(-not $caught -or $caught -notlike ('*'+$expected+'*')) {throw ('EXPECTED_FAILURE: '+$expected+'; observed: '+$caught)}
}
Reset-Mocks
$script:queryExits=@(0,1072,1060)
Remove-Phase2LabService 'MockService'
Assert-Equal $script:disposed 1 'controller disposed'
Assert-Equal $script:queries 3 'deferred deletion queried until absence'
Assert-Equal $script:sleeps 2 'bounded retry'
Reset-Mocks
$script:queryExits=@(1072)
Assert-Fails {Remove-Phase2LabService 'MockService'} 'SERVICE_REMOVAL_NOT_CONFIRMED'
Assert-Equal $script:queries 20 'pending deletion bounded'
Assert-Equal $script:sleeps 19 'no sleep after last attempt'
Reset-Mocks
$script:queryExits=@(5)
Assert-Fails {Remove-Phase2LabService 'MockService'} 'SERVICE_REMOVAL_QUERY_FAILED'
Assert-Equal $script:queries 1 'access error is not absence'
Reset-Mocks
$script:deleteExit=5
Assert-Fails {Remove-Phase2LabService 'MockService'} 'SC_DELETE_FAILED'
Assert-Equal $script:queries 0 'delete failure stops verification'
foreach($failure in @('stop','wait','status')) {
  Reset-Mocks
  if($failure -eq 'stop') {$script:stopFails=$true;$expected='MOCK_STOP_FAILED'}
  if($failure -eq 'wait') {$script:waitFails=$true;$expected='MOCK_WAIT_FAILED'}
  if($failure -eq 'status') {$script:serviceStatus='Running';$expected='SERVICE_NOT_STOPPED'}
  Assert-Fails {Remove-Phase2LabService 'MockService'} $expected
  Assert-Equal $script:disposed 1 ($failure+' failure disposes controller')
  Assert-Equal $script:deletes 0 ($failure+' failure prevents deletion')
}
Write-Output 'PASS: cleanup mock regression (7 cases); no real services or accounts accessed.'
