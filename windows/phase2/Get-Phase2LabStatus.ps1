# Read-only laboratory observer. Never authorizes launch or toggles.
# Unlike an AI-generated status message, this has an explicit fail-closed default.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PipeName,[int]$TimeoutMs=750)
$ErrorActionPreference='Stop'
$result=[ordered]@{product='J Harness';phase='PHASE2_WINDOWS_LAB_STATUS_CLIENT';state='BLOCKED';reason='SUPERVISOR_UNREACHABLE';enforcement='NOT_ATTESTED';launchAuthorized=$false;toggleAvailable=$false}
if ($PipeName -notmatch '^JHP2Status_[a-f0-9]{12}$' -or $TimeoutMs -lt 1 -or $TimeoutMs -gt 5000) {
  $result.reason='INVALID_LAB_PIPE_ARGUMENTS'
  return [pscustomobject]$result
}
$pipe=$null
try {
  $pipe=[IO.Pipes.NamedPipeClientStream]::new('.', $PipeName, [IO.Pipes.PipeDirection]::InOut)
  $pipe.Connect($TimeoutMs)
  # PipeStream timeout property setters may throw on Windows PowerShell 5.1.
  # Use a bounded asynchronous response wait instead.
  $writer=[IO.StreamWriter]::new($pipe,[Text.UTF8Encoding]::new($false),1024,$true)
  $reader=[IO.StreamReader]::new($pipe,[Text.UTF8Encoding]::new($false),$false,1024,$true)
  try {
    $writer.AutoFlush=$true;$writer.WriteLine('status')
    $lineTask=$reader.ReadLineAsync()
    if(-not $lineTask.Wait($TimeoutMs)){throw 'LAB_STATUS_RESPONSE_TIMEOUT'}
    $message=$lineTask.Result | ConvertFrom-Json
    if($message.state -eq 'BLOCKED' -and $message.enforcement -eq 'NOT_ATTESTED' -and $message.launchAuthorized -eq $false) {
      $result.reason='READ_ONLY_LAB_SERVICE_OBSERVED'
    } else {
      $result.reason='UNTRUSTED_SERVICE_REPLY_BLOCKED'
    }
  } finally {$reader.Dispose();$writer.Dispose()}
} catch {
  $result.reason='SUPERVISOR_UNREACHABLE'
  # Never serialize arbitrary exception messages or secret-bearing IPC payloads.
  $result['labErrorType']=$_.Exception.GetType().Name
} finally {if ($pipe) {$pipe.Dispose()}}
[pscustomobject]$result
