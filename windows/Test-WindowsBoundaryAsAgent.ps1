# Must be executed as the ALREADY EXISTING restricted worker Windows user.
# Writes temporary probe files only inside the explicit J Harness phase1 test fixture.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$LabRoot,
  [Parameter(Mandatory=$true)][string]$ExpectedAgentSid,
  [switch]$WriteProbe
)
$ErrorActionPreference='Stop'
if (-not [Environment]::OSVersion.Platform.Equals([PlatformID]::Win32NT)) { throw 'WINDOWS_REQUIRED' }
$full=[IO.Path]::GetFullPath($LabRoot)
# Separate account TEMP may differ; authorize a path only if the caller explicitly provides one.
if (-not (Split-Path -Leaf $full).StartsWith('jh-phase1-lab-')) { throw 'NOT_A_PHASE1_LAB_PATH' }
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$result=[ordered]@{product='J Harness';kind='RESTRICTED_WORKER_PROBE';actualSid=$identity.User.Value;expectedSid=$ExpectedAgentSid;identityVerified=$false;writeProbe=$WriteProbe.IsPresent;protectedRead='NOT_RUN';protectedWrite='NOT_RUN';workspaceWrite='NOT_RUN';result='NOT_RUN';limitations=@('NO_SUPERVISOR_WINDOWS_SERVICE_E2E','NO_CLI_OR_NETWORK_SANDBOX','NO_OWNER_UI_AUTH')}
if ($identity.User.Value -ne $ExpectedAgentSid) { throw 'WRONG_OS_IDENTITY_NO_TEST_EXECUTED' }
if ((New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'AGENT_ADMINISTRATOR_TOKEN_REFUSED' }
$result.identityVerified=$true
# Never claim success from ACL names or inherited group assumptions; exercise access with actual token.
function Attempt([scriptblock]$block) {
  try { & $block | Out-Null; return 'ALLOWED' }
  catch [System.UnauthorizedAccessException] { return 'ACCESS_DENIED' }
  catch { return 'ERROR_' + $_.Exception.GetType().Name }
}
$result.protectedRead=Attempt { [IO.File]::ReadAllText((Join-Path $full 'protected\policy.json')) }
if ($WriteProbe) {
  $stamp=[guid]::NewGuid().ToString('N')
  $protectedFile=Join-Path $full "protected\probe-$stamp.txt"
  $workspaceFile=Join-Path $full "workspace\probe-$stamp.txt"
  $result.protectedWrite=Attempt { [IO.File]::WriteAllText($protectedFile,'NO PROTECTED WRITE SHOULD SUCCEED') }
  $result.workspaceWrite=Attempt { [IO.File]::WriteAllText($workspaceFile,'WORKSPACE_WRITABLE') }
  # Delete only newly generated test files if they were created.
  foreach($file in @($protectedFile,$workspaceFile)) {
    try { if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force } } catch { }
  }
  $result.result=if($result.protectedRead -eq 'ACCESS_DENIED' -and $result.protectedWrite -eq 'ACCESS_DENIED' -and $result.workspaceWrite -eq 'ALLOWED'){'OBSERVED_OS_ACL_DENIAL_ONLY'}else{'FAIL_OR_INCONCLUSIVE'}
} else { $result.result='READONLY_OBSERVATION_ONLY' }
$result | ConvertTo-Json -Depth 5
