# This file must execute inside a DIFFERENT NON-ADMIN local user token.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$LabRoot,
  [Parameter(Mandatory=$true)][string]$ExpectedSid,
  [Parameter(Mandatory=$true)][string]$PipeName
)
$ErrorActionPreference='Stop'
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$observed=[ordered]@{product='J Harness';phase='PHASE2_WINDOWS_WORKER';actualSid=$identity.User.Value;expectedSid=$ExpectedSid;distinctNonAdmin=$false;protectedPolicyRead='NOT_RUN';protectedPolicyWrite='NOT_RUN';protectedPolicyOverwrite='NOT_RUN';protectedStateRead='NOT_RUN';protectedStateWrite='NOT_RUN';workspaceWrite='NOT_RUN';pipeStatus='NOT_RUN';pipeToggle='NOT_RUN';pipePolicyChange='NOT_RUN';pipeLaunch='NOT_RUN';pipeDeploy='NOT_RUN';statusClaimsEnforcement=$null;result='NOT_RUN'}
$output=Join-Path $LabRoot 'workspace\agent-result.json'
if ($identity.User.Value -ne $ExpectedSid) { throw 'WRONG_WORKER_SID_NO_PROBE' }
if (([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'ADMINISTRATOR_WORKER_REFUSED' }
$observed.distinctNonAdmin=$true
function Attempt([scriptblock]$action) {
  try { & $action | Out-Null; return 'ALLOWED' }
  catch {
    # PowerShell wraps .NET IO failures in MethodInvocationException; inspect the
    # *actual* inner OS exception rather than treating any failure as access denial.
    $errorType=$_.Exception.GetType().Name
    $current=$_.Exception
    while ($null -ne $current) {
      if ($current -is [System.UnauthorizedAccessException] -or $current -is [System.Security.SecurityException]) {return 'ACCESS_DENIED'}
      $current=$current.InnerException
    }
    return ('OTHER_ERROR_'+$errorType)
  }
}
function PipeRequest([string]$op) {
  $pipe=[System.IO.Pipes.NamedPipeClientStream]::new('.', $PipeName, [System.IO.Pipes.PipeDirection]::InOut)
  try {
    $pipe.Connect(3500)
    # ReadTimeout/WriteTimeout are not supported by every Windows PipeStream.
    $writer=[System.IO.StreamWriter]::new($pipe,[Text.UTF8Encoding]::new($false),1024,$true)
    $reader=[System.IO.StreamReader]::new($pipe,[Text.UTF8Encoding]::new($false),$false,1024,$true)
    try {$writer.AutoFlush=$true;$writer.WriteLine($op);$lineTask=$reader.ReadLineAsync();if(-not $lineTask.Wait(3500)){throw 'WORKER_PIPE_RESPONSE_TIMEOUT'};$line=$lineTask.Result;if (-not $line) {throw 'EMPTY_BROKER_REPLY'};return ($line | ConvertFrom-Json)}
    finally {$reader.Dispose();$writer.Dispose()}
  } finally {$pipe.Dispose()}
}
$observed.protectedPolicyRead=Attempt {[IO.File]::ReadAllText((Join-Path $LabRoot 'protected\policy.json'))}
$observed.protectedPolicyWrite=Attempt {[IO.File]::WriteAllText((Join-Path $LabRoot 'protected\agent-poke.txt'),'ATTACK_ATTEMPT')}
$observed.protectedPolicyOverwrite=Attempt {[IO.File]::AppendAllText((Join-Path $LabRoot 'protected\policy.json'),'ATTACK_ATTEMPT')}
$observed.protectedStateRead=Attempt {[IO.File]::ReadAllText((Join-Path $LabRoot 'protected\state.json'))}
$observed.protectedStateWrite=Attempt {[IO.File]::AppendAllText((Join-Path $LabRoot 'protected\state.json'),'ATTACK_ATTEMPT')}
$observed.workspaceWrite=Attempt {[IO.File]::WriteAllText((Join-Path $LabRoot 'workspace\worker-can-work.txt'),'WORKER_CAN_WRITE_WORKSPACE')}
try {
  $status=PipeRequest 'status'
  $observed.pipeStatus=$status.state
  $observed.statusClaimsEnforcement=$status.enforcement
  $observed.pipeToggle=(PipeRequest 'toggle').decision
  $observed.pipePolicyChange=(PipeRequest 'change_policy').decision
  $observed.pipeLaunch=(PipeRequest 'launch').decision
  $observed.pipeDeploy=(PipeRequest 'deploy').decision
} catch {
  $observed.pipeStatus='ERROR_'+$_.Exception.GetType().Name
  $observed.pipeToggle='NOT_RUN'
  $observed.pipePolicyChange='NOT_RUN'
  $observed.pipeLaunch='NOT_RUN'
  $observed.pipeDeploy='NOT_RUN'
}
$pass=$observed.distinctNonAdmin -and $observed.protectedPolicyRead -eq 'ACCESS_DENIED' -and $observed.protectedPolicyWrite -eq 'ACCESS_DENIED' -and $observed.protectedPolicyOverwrite -eq 'ACCESS_DENIED' -and $observed.protectedStateRead -eq 'ACCESS_DENIED' -and $observed.protectedStateWrite -eq 'ACCESS_DENIED' -and $observed.workspaceWrite -eq 'ALLOWED' -and $observed.pipeStatus -eq 'BLOCKED' -and $observed.pipeToggle -eq 'DENY' -and $observed.pipePolicyChange -eq 'DENY' -and $observed.pipeLaunch -eq 'DENY' -and $observed.pipeDeploy -eq 'DENY' -and $observed.statusClaimsEnforcement -eq 'NOT_ATTESTED'
$observed.result=if($pass){'PASS_WINDOWS_BOUNDARY_LAB_ONLY'}else{'FAIL_OR_INCONCLUSIVE'}
# No secrets in this report. Only explicit laboratory workspace can receive it.
[IO.File]::WriteAllText($output,($observed|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
if (-not $pass) {exit 3}
exit 0
