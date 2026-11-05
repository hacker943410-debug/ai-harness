# Creates only an explicit test fixture; NEVER installs a service, creates users or modifies system policy.
# Requires an ALREADY EXISTING, distinct, non-administrator restricted Agent SID.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$LabRoot,
  [Parameter(Mandatory=$true)][string]$AgentSid,
  [switch]$CreateFixture
)
$ErrorActionPreference='Stop'
if (-not [Environment]::OSVersion.Platform.Equals([PlatformID]::Win32NT)) { throw 'WINDOWS_REQUIRED' }
$full=[IO.Path]::GetFullPath($LabRoot)
$common=[IO.Path]::GetFullPath([Environment]::GetFolderPath('CommonDocuments')).TrimEnd('\')
# Use a shared test parent so a separate restricted account can traverse to its workspace.
if (-not $full.StartsWith($common+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'COMMON_DOCUMENTS_LAB_ROOT_ONLY' }
$relative=$full.Substring($common.Length+1)
if ($relative.Contains('\') -or -not $relative.StartsWith('jh-phase1-lab-',[StringComparison]::OrdinalIgnoreCase)) { throw 'LAB_MUST_BE_DIRECT_COMMON_DOCUMENTS_CHILD' }
if (Test-Path -LiteralPath $full) { throw 'EXISTING_PATH_REFUSED' }
$sid=New-Object Security.Principal.SecurityIdentifier($AgentSid)
$owner=[Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $owner.User -or $owner.User.Value -eq $sid.Value) { throw 'DISTINCT_AGENT_OS_IDENTITY_REQUIRED' }
if ($sid.Value -in @('S-1-5-18','S-1-5-19','S-1-5-20','S-1-5-32-544','S-1-5-11','S-1-1-0')) { throw 'SYSTEM_OR_BROAD_GROUP_CANNOT_BE_AGENT_SID' }
$result=[ordered]@{product='J Harness';kind='WINDOWS_BOUNDARY_LAB_PLAN';root=$full;ownerSid=$owner.User.Value;agentSid=$sid.Value;osChanges='NONE';serviceInstall='NOT_RUN';accountCreation='NOT_RUN';enforcement='NOT_ATTESTED';status='PLAN_ONLY'}
if (-not $CreateFixture) { $result | ConvertTo-Json -Depth 4; return }
# No silent creation; -CreateFixture explicitly authorizes changes ONLY inside named test root.
$system=New-Object Security.Principal.SecurityIdentifier('S-1-5-18')
$admins=New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
$inherit=[Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
$propagate=[Security.AccessControl.PropagationFlags]::None
function Set-TrustAcl([string]$item,[bool]$agentCanModify,[bool]$agentCanRead) {
  $acl=New-Object System.Security.AccessControl.DirectorySecurity
  $acl.SetAccessRuleProtection($true,$false)
  foreach ($trusted in @($owner.User,$system,$admins)) {
    $rule=New-Object Security.AccessControl.FileSystemAccessRule($trusted,[Security.AccessControl.FileSystemRights]::FullControl,$inherit,$propagate,[Security.AccessControl.AccessControlType]::Allow)
    $acl.AddAccessRule($rule)
  }
  if ($agentCanModify -or $agentCanRead) {
    $right=if ($agentCanModify) {[Security.AccessControl.FileSystemRights]::Modify} else {[Security.AccessControl.FileSystemRights]::ReadAndExecute}
    $rule=New-Object Security.AccessControl.FileSystemAccessRule($sid,$right,$inherit,$propagate,[Security.AccessControl.AccessControlType]::Allow)
    $acl.AddAccessRule($rule)
  }
  Set-Acl -LiteralPath $item -AclObject $acl
}
$created=$false
try {
  [IO.Directory]::CreateDirectory($full) | Out-Null
  $created=$true
  # Parent: read/traverse only for agent. Protected directory: no agent ACE.
  Set-TrustAcl $full $false $true
  $protected=Join-Path $full 'protected';$public=Join-Path $full 'public';$workspace=Join-Path $full 'workspace'
  foreach($p in @($protected,$public,$workspace)) { [IO.Directory]::CreateDirectory($p) | Out-Null }
  Set-TrustAcl $protected $false $false
  Set-TrustAcl $public $false $true
  Set-TrustAcl $workspace $true $false
  $policy='{ "schema": 1, "id": "J_HARNESS_PHASE1_WINDOWS_LAB_ONLY" }' + [Environment]::NewLine
  [IO.File]::WriteAllText((Join-Path $protected 'policy.json'),$policy,[Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $protected 'state.json'),'{ "desired": "ON", "enforcement": "NOT_ATTESTED" }' + [Environment]::NewLine,[Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $full '.lab-marker'),'J_HARNESS_WINDOWS_PHASE1_TEST_ONLY',[Text.UTF8Encoding]::new($false))
  $result.status='CREATED_TEST_FIXTURE_NOT_ENFORCED'
  $result.osChanges='TEST_ROOT_FILES_AND_ACLS_ONLY'
  $result.protectedRoot=$protected
  $result.workspaceRoot=$workspace
  $result.agentProbe='Run Test-WindowsBoundaryAsAgent.ps1 from the existing restricted Agent OS identity.'
  $result | ConvertTo-Json -Depth 4
} catch {
  # Do not auto-delete partial fixtures or loosen permissions: manual review needed.
  if ($created) { Write-Warning "PARTIAL_TEST_FIXTURE_PRESERVED: $full" }
  throw
}
