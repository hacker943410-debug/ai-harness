# CAUTION: ephemeral CI runner ONLY; creates/disposes a local user and an SCM service.
# Explicit opt-in; rejects execution on an ordinary Windows workstation.
[CmdletBinding()]
param(
  [switch]$IAmInDisposableGitHubWindowsRunner,
  [string]$EvidenceDirectory = (Join-Path $env:RUNNER_TEMP 'jh-phase2-evidence'),
  [ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedGithubSha
)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
if (-not $IAmInDisposableGitHubWindowsRunner -or $env:GITHUB_ACTIONS -ne 'true' -or -not $env:RUNNER_TEMP -or $env:RUNNER_OS -ne 'Windows' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
  throw 'DISPOSABLE_GITHUB_ACTIONS_WINDOWS_RUNNER_ONLY'
}
if (-not [Environment]::OSVersion.Platform.Equals([PlatformID]::Win32NT)) {throw 'WINDOWS_REQUIRED'}
if ($env:GITHUB_REPOSITORY -ne 'hacker943410-debug/ai-harness' -or $env:GITHUB_EVENT_NAME -ne 'pull_request') {throw 'REPOSITORY_AND_PR_EVENT_REQUIRED'}
if ($env:GITHUB_RUN_ID -notmatch '^[0-9]+$' -or $env:GITHUB_RUN_ATTEMPT -notmatch '^[0-9]+$') {throw 'GITHUB_RUN_ID_REQUIRED'}
if (-not $ExpectedGithubSha -or $ExpectedGithubSha -ne $env:GITHUB_SHA) {throw 'EXPECTED_GITHUB_SHA_MISMATCH'}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=[Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {throw 'EPHEMERAL_CI_ADMIN_REQUIRED'}
$common=[Environment]::GetFolderPath('CommonApplicationData')
if (-not $common -or -not (Test-Path -LiteralPath $common -PathType Container)) {throw 'PROGRAMDATA_MISSING'}
[IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($EvidenceDirectory)) | Out-Null
$short=[guid]::NewGuid().ToString('N').Substring(0,12)
$parent=Join-Path $common ('JHarnessPhase2LabParent_'+$short)
$root=Join-Path $parent ('jh-phase2-lab-'+$short)
$name='JHP2Lab_'+$short
$pipeName='JHP2Status_'+$short
$userName='jh2_'+$short
$agent=$null
$serviceCreated=$false
$parentCreated=$false
$cleanupErrors=New-Object 'System.Collections.Generic.List[string]'
$outcome=[ordered]@{product='J Harness';phase='PHASE2_WINDOWS_CI';runner='GITHUB_HOSTED_WINDOWS_EXPECTED';serviceName=$name;pipeName=$pipeName;serviceIdentity='NT AUTHORITY\LocalService';separateAgentSid='NOT_CREATED';windowsServiceStarted='NOT_RUN';workerResult='NOT_RUN';serviceStopFailClosed='NOT_RUN';originalPolicyUntouched='NOT_RUN';originalStateUntouched='NOT_RUN';cleanup='NOT_RUN';release='NO_GO';result='NOT_RUN';githubSha=$ExpectedGithubSha;aclEvidence='NOT_RUN';serviceBinarySha256='NOT_RUN'}
function WriteEvidence {
  [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'PHASE2_WINDOWS_CI_RESULT.json'),($outcome|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
}
function Stop-Phase2LabService([string]$serviceName) {
  $controller=$null
  try {
    $controller=Get-Service -Name $serviceName -ErrorAction Stop
    Stop-Service -Name $serviceName -ErrorAction Stop
    $controller.WaitForStatus([ServiceProcess.ServiceControllerStatus]::Stopped,[TimeSpan]::FromSeconds(10))
    $controller.Refresh()
    if($controller.Status -ne 'Stopped') {throw 'SERVICE_NOT_STOPPED'}
  } finally {
    # An open ServiceController handle can keep SCM deletion pending.
    if($null -ne $controller) {$controller.Dispose()}
  }
}
function Remove-Phase2LabService([string]$serviceName) {
  Stop-Phase2LabService $serviceName
  & sc.exe delete $serviceName | Out-Null
  $deleteExit=$LASTEXITCODE
  if($deleteExit -ne 0 -and $deleteExit -ne 1072) {throw 'SC_DELETE_FAILED'}
  # sc delete success can mean only "marked for deletion". Require absence,
  # and distinguish absence (1060) from access errors or pending deletion (1072).
  for($attempt=1;$attempt -le 20;$attempt++) {
    & sc.exe query $serviceName | Out-Null
    $queryExit=$LASTEXITCODE
    if($queryExit -eq 1060) {return}
    if($queryExit -ne 0 -and $queryExit -ne 1072) {throw 'SERVICE_REMOVAL_QUERY_FAILED'}
    if($attempt -lt 20) {Start-Sleep -Milliseconds 250}
  }
  throw 'SERVICE_REMOVAL_NOT_CONFIRMED'
}
function Set-LabAcl([string]$directory,[string]$agentSid,[string]$agentRights,[switch]$LocalServiceRead) {
  $acl=New-Object Security.AccessControl.DirectorySecurity
  $acl.SetAccessRuleProtection($true,$false)
  $inherit=[Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
  $none=[Security.AccessControl.PropagationFlags]::None
  $allow=[Security.AccessControl.AccessControlType]::Allow
  foreach ($sid in @($identity.User.Value,'S-1-5-18','S-1-5-32-544')) {
    $rule=[Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),[Security.AccessControl.FileSystemRights]::FullControl,$inherit,$none,$allow)
    $acl.AddAccessRule($rule)
  }
  if ($LocalServiceRead) {
    $rule=[Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-19'),[Security.AccessControl.FileSystemRights]::ReadAndExecute,$inherit,$none,$allow)
    $acl.AddAccessRule($rule)
  }
  if($agentSid) {
    $rights=if($agentRights -eq 'Modify'){[Security.AccessControl.FileSystemRights]::Modify}else{[Security.AccessControl.FileSystemRights]::ReadAndExecute}
    $rule=[Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($agentSid),$rights,$inherit,$none,$allow)
    $acl.AddAccessRule($rule)
  }
  Set-Acl -LiteralPath $directory -AclObject $acl
}
function Assert-TrustStoreAcl([string]$protectedPath,[string]$workspacePath,[string]$servicePath,[string]$sid) {
  # Per-directory DACL check by trusted runner, independent of worker self-report.
  foreach($record in @(
    @{path=$protectedPath; expected='NO_WORKER_RULE'},
    @{path=$workspacePath; expected='WORKER_MODIFY'},
    @{path=$servicePath; expected='NO_WORKER_RULE'}
  )) {
    $acl=Get-Acl -LiteralPath $record.path -ErrorAction Stop
    if (-not $acl.AreAccessRulesProtected) {throw 'LAB_DACL_INHERITANCE_NOT_PROTECTED'}
    $entries=@($acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]) | Where-Object {$_.IdentityReference.Value -eq $sid})
    if($record.expected -eq 'NO_WORKER_RULE' -and $entries.Count -ne 0) {throw 'WORKER_HAS_DIRECT_ACCESS_TO_PROTECTED_DIR'}
    if($record.expected -eq 'WORKER_MODIFY') {
      if ($entries.Count -ne 1 -or $entries[0].AccessControlType -ne 'Allow' -or
          (($entries[0].FileSystemRights -band [Security.AccessControl.FileSystemRights]::Modify) -ne [Security.AccessControl.FileSystemRights]::Modify)) {
        throw 'WORKER_WORKSPACE_WRITE_RULE_MISSING'
      }
    }
  }
  # All explicitly named protected directory trustees must be privileged or LocalService.
  $protectedAcl=Get-Acl -LiteralPath $protectedPath
  $allowed=@($identity.User.Value,'S-1-5-18','S-1-5-32-544','S-1-5-19')
  foreach($entry in $protectedAcl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
    if ($entry.AccessControlType -ne 'Allow' -or $entry.IdentityReference.Value -notin $allowed) {
      throw 'UNEXPECTED_PROTECTED_DACL_ENTRY'
    }
  }
}
try {
  # Dedicated local user, never a real account. No privilege escalation and no persistent login.
  $rand=[guid]::NewGuid().ToString('N')
  $secret=('Aa1!'+$rand+'zZ9@') | ConvertTo-SecureString -AsPlainText -Force
  $agent=New-LocalUser -Name $userName -Password $secret -Description 'J Harness disposable Phase2 CI test identity' -ErrorAction Stop
  $agentSid=$agent.SID.Value
  if($agentSid -eq $identity.User.Value) {throw 'AGENT_IDENTITY_NOT_DISTINCT'}
  $outcome.separateAgentSid=$agentSid
  [IO.Directory]::CreateDirectory($parent)|Out-Null;$parentCreated=$true
  Set-LabAcl $parent $agentSid 'Read' -LocalServiceRead
  [IO.File]::WriteAllText((Join-Path $parent '.lab-parent-marker'),'J_HARNESS_PHASE2_DISPOSABLE_PARENT',[Text.UTF8Encoding]::new($false))
  [IO.Directory]::CreateDirectory($root)|Out-Null
  $protected=Join-Path $root 'protected';$workspace=Join-Path $root 'workspace';$public=Join-Path $root 'public';$serviceDir=Join-Path $root 'service'
  foreach($p in @($protected,$workspace,$public,$serviceDir)) {[IO.Directory]::CreateDirectory($p)|Out-Null}
  # Root: allow limited traverse; protect source, policy and state independently.
  Set-LabAcl $root $agentSid 'Read' -LocalServiceRead
  Set-LabAcl $protected '' 'Read' -LocalServiceRead
  Set-LabAcl $workspace $agentSid 'Modify'
  Set-LabAcl $public $agentSid 'Read' -LocalServiceRead
  Set-LabAcl $serviceDir '' 'Read' -LocalServiceRead
  Assert-TrustStoreAcl $protected $workspace $serviceDir $agentSid
  $outcome.aclEvidence='PASS_TRUSTED_RUNNER_DACL_CHECK'
  [IO.File]::WriteAllText((Join-Path $root '.lab-marker'),'J_HARNESS_PHASE2_DISPOSABLE_WINDOWS_LAB',[Text.UTF8Encoding]::new($false))
  $policy='{ "schema": 1, "id": "WINDOWS_PHASE2_LAB_ONLY", "noCliLaunch": true }' + [Environment]::NewLine
  $policyFile=Join-Path $protected 'policy.json'
  [IO.File]::WriteAllText($policyFile,$policy,[Text.UTF8Encoding]::new($false))
  $policyHash=(Get-FileHash -LiteralPath $policyFile -Algorithm SHA256).Hash.ToLowerInvariant()
  $stateFile=Join-Path $protected 'state.json'
  [IO.File]::WriteAllText($stateFile,(@{schema=1;desired='ON';epoch=1;policySha256=$policyHash}|ConvertTo-Json -Compress)+"`n",[Text.UTF8Encoding]::new($false))
  $originalPolicy=(Get-FileHash $policyFile -Algorithm SHA256).Hash
  $originalState=(Get-FileHash $stateFile -Algorithm SHA256).Hash
  # Stage probe source in the public test directory, not the runner's private checkout.
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-Phase2WorkerProbe.ps1') -Destination (Join-Path $public 'Invoke-Phase2WorkerProbe.ps1') -ErrorAction Stop
  $build=& (Join-Path $PSScriptRoot 'Build-Phase2Service.ps1') -OutputDirectory $serviceDir | ConvertFrom-Json
  if($build.serviceInstalled -ne $false){throw 'BUILD_MUST_NOT_REGISTER_SERVICE'}
  $exe=Join-Path $serviceDir 'JHarnessPhase2LabService.exe'
  $outcome.serviceBinarySha256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
  $binPath=('"{0}" --service "{1}" {2} {3}' -f $exe,$root,$name,$pipeName)
  & sc.exe create $name 'type=' 'own' 'start=' 'demand' 'obj=' 'NT AUTHORITY\LocalService' 'binPath=' $binPath 'DisplayName=' ('J Harness P2 disposable lab '+$short) | Out-Null
  if($LASTEXITCODE -ne 0){throw 'SERVICE_CREATE_FAILED'}
  $serviceCreated=$true
  & sc.exe start $name | Out-Null
  if($LASTEXITCODE -ne 0){throw 'SERVICE_START_FAILED'}
  # An empty pipe connection previously consumed the single-client service slot.
  # Poll the real read-only protocol instead and fail closed on exhaustion.
  $liveStatus=$null
  $ready=$false
  for($statusAttempt=1;$statusAttempt -le 24;$statusAttempt++) {
    $liveStatus=& (Join-Path $PSScriptRoot 'Get-Phase2LabStatus.ps1') -PipeName $pipeName
    if($liveStatus.state -eq 'BLOCKED' -and $liveStatus.reason -eq 'READ_ONLY_LAB_SERVICE_OBSERVED' -and $liveStatus.launchAuthorized -eq $false) {
      $ready=$true
      break
    }
    if($statusAttempt -lt 24){Start-Sleep -Milliseconds 350}
  }
  $outcome['liveStatusDiagnostic']=@{attempts=$statusAttempt;reason=[string]$liveStatus.reason;state=[string]$liveStatus.state;launchAuthorized=[bool]$liveStatus.launchAuthorized;errorType=[string]$liveStatus.labErrorType}
  if(-not $ready) {throw ('LIVE_STATUS_CLIENT_FAIL_CLOSED_VERIFICATION_FAILED: '+$liveStatus.reason)}
  $svc=Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $name)
  if (-not $svc -or $svc.StartName -notlike '*LocalService*') {throw ('SERVICE_ACCOUNT_NOT_LOCALSERVICE: '+$svc.StartName)}
  $outcome.windowsServiceStarted='PASS_SCM_LOCALSERVICE'
  $password=$secret
  $cred=[System.Management.Automation.PSCredential]::new(('.\'+$userName),$password)
  $pwsh=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $probe=Join-Path $public 'Invoke-Phase2WorkerProbe.ps1'
  $argument='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -LabRoot "{1}" -ExpectedSid "{2}" -PipeName "{3}"' -f $probe,$root,$agentSid,$pipeName
  $process=Start-Process -FilePath $pwsh -Credential $cred -ArgumentList $argument -WorkingDirectory $workspace -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
  $observedFile=Join-Path $workspace 'agent-result.json'
  if(-not (Test-Path -LiteralPath $observedFile -PathType Leaf)) {throw ('AGENT_REPORT_MISSING_EXIT_'+$process.ExitCode)}
  $observed=Get-Content -LiteralPath $observedFile -Encoding UTF8 -Raw | ConvertFrom-Json
  Copy-Item -LiteralPath $observedFile -Destination (Join-Path $EvidenceDirectory 'AGENT_PROBE_RESULT.json')
  if($process.ExitCode -ne 0 -or $observed.result -ne 'PASS_WINDOWS_BOUNDARY_LAB_ONLY' -or $observed.actualSid -ne $agentSid -or
      $observed.protectedPolicyOverwrite -ne 'ACCESS_DENIED' -or $observed.protectedStateRead -ne 'ACCESS_DENIED' -or
      $observed.pipeLaunch -ne 'DENY' -or $observed.pipeDeploy -ne 'DENY') {throw 'ACTUAL_RESTRICTED_ACCOUNT_PROBE_FAILED'}
  $outcome.workerResult='PASS_DISTINCT_NON_ADMIN_OS_TOKEN'
  $outcome.originalPolicyUntouched=if((Get-FileHash $policyFile -Algorithm SHA256).Hash -eq $originalPolicy){'PASS'}else{'FAIL'}
  $outcome.originalStateUntouched=if((Get-FileHash $stateFile -Algorithm SHA256).Hash -eq $originalState){'PASS'}else{'FAIL'}
  if($outcome.originalPolicyUntouched -ne 'PASS' -or $outcome.originalStateUntouched -ne 'PASS') {throw 'TRUST_STORE_CHANGED'}
  Stop-Phase2LabService $name
  $unreachable=$true
  $client=[System.IO.Pipes.NamedPipeClientStream]::new('.', $pipeName, [IO.Pipes.PipeDirection]::InOut)
  try {try {$client.Connect(350);$unreachable=$false}catch [TimeoutException]{} }
  finally {$client.Dispose()}
  if(-not $unreachable) {throw 'STOPPED_SERVICE_PIPE_STILL_REACHABLE'}
  $offlineStatus=& (Join-Path $PSScriptRoot 'Get-Phase2LabStatus.ps1') -PipeName $pipeName
  if($offlineStatus.state -ne 'BLOCKED' -or $offlineStatus.reason -ne 'SUPERVISOR_UNREACHABLE' -or $offlineStatus.launchAuthorized -ne $false) {throw 'CLIENT_DID_NOT_FAIL_CLOSED_ON_STOP'}
  $outcome.serviceStopFailClosed='PASS_READONLY_CLIENT_BLOCKS_WHEN_SERVICE_UNREACHABLE'
  $outcome.result='PASS_WINDOWS_PHASE2_LIMITED_SCOPE_NO_CLI_ENFORCEMENT'
} catch {
  $outcome.result='FAIL_OR_INCONCLUSIVE'
  $outcome.failure=($_.Exception.GetType().Name+': '+$_.Exception.Message)
} finally {
  if($serviceCreated){
    try {Remove-Phase2LabService $name} catch {$cleanupErrors.Add('SERVICE_CLEANUP_FAILED')}
  }
  if($agent){try{Remove-LocalUser -Name $userName -ErrorAction Stop}catch{$cleanupErrors.Add('ACCOUNT_CLEANUP_FAILED')}}
  if($parentCreated){
    try{
      if ((Split-Path -Parent $parent) -ne $common -or -not (Split-Path -Leaf $parent).StartsWith('JHarnessPhase2LabParent_')){throw 'UNSAFE_CLEANUP_PARENT'}
      if ([IO.File]::ReadAllText((Join-Path $parent '.lab-parent-marker')) -ne 'J_HARNESS_PHASE2_DISPOSABLE_PARENT'){throw 'CLEANUP_PARENT_MARKER_MISSING'}
      if ((Get-Item -LiteralPath $parent -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'REPARSE_PARENT_CLEANUP_REFUSED'}
      if ((Get-ChildItem -LiteralPath $parent -Recurse -Force | Where-Object {($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0} | Measure-Object).Count -gt 0) {throw 'REPARSE_MEMBER_CLEANUP_REFUSED'}
      Remove-Item -LiteralPath $parent -Recurse -Force -ErrorAction Stop
    } catch {$cleanupErrors.Add('LAB_ROOT_CLEANUP_FAILED')}
  }
  $outcome.cleanup=if($cleanupErrors.Count -eq 0){'PASS'}else{$cleanupErrors -join ','}
  if($cleanupErrors.Count -ne 0) {$outcome.result='FAIL_CLEANUP_MANUAL_REVIEW_REQUIRED'}
  WriteEvidence
  $outcome | ConvertTo-Json -Depth 8
}
if($outcome.result -ne 'PASS_WINDOWS_PHASE2_LIMITED_SCOPE_NO_CLI_ENFORCEMENT') {exit 2}
# An expected sc query 1060 confirms deletion but must not escape as the
# successful lab's process status through the GitHub PowerShell wrapper.
exit 0
