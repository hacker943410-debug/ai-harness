# J Harness v8 - read-only Windows OS boundary inventory (NOT enforcement)
# Does not create accounts, change ACLs, write files, run CLIs or request elevation.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PolicyRoot,
    [Parameter(Mandatory=$true)][string]$ToggleRoot,
    [Parameter(Mandatory=$true)][string]$WorkspaceRoot,
    [string]$AgentIdentity = ''
)
$ErrorActionPreference = 'Stop'
function Resolve-SafeExistingFolder ([string]$folder) {
    $full = [IO.Path]::GetFullPath($folder)
    if (-not (Test-Path -LiteralPath $full -PathType Container)) { throw "FOLDER_MISSING: $full" }
    $cursor = $full
    while ($true) {
        $item = Get-Item -LiteralPath $cursor -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "REPARSE_POINT_REFUSED: $cursor" }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if (-not $parent -or $parent -eq $cursor) { break }
        $cursor = $parent
    }
    return $full.TrimEnd('\')
}
function Child-Or-Same ([string]$parent,[string]$child) {
    return ($child.Equals($parent,[StringComparison]::OrdinalIgnoreCase) -or
        $child.StartsWith($parent + '\',[StringComparison]::OrdinalIgnoreCase))
}
$result = [ordered]@{
    product = 'J Harness'
    kind = 'READ_ONLY_WINDOWS_BOUNDARY_INVENTORY'
    state = 'BLOCKED'
    trusted = $false
    enforcement = 'NOT_ATTESTED'
    osSettingsChanged = $false
    accountOrAclChanged = $false
    liveCliExecution = 'NOT_RUN'
    interactiveToggleAuthenticated = $false
    reason = ''
    report = @{}
}
try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'WINDOWS_REQUIRED' }
    $policy = Resolve-SafeExistingFolder $PolicyRoot
    $toggle = Resolve-SafeExistingFolder $ToggleRoot
    $work = Resolve-SafeExistingFolder $WorkspaceRoot
    foreach ($protected in @($policy,$toggle)) {
        if ((Child-Or-Same $work $protected) -or (Child-Or-Same $protected $work)) { throw 'WORKSPACE_OVERLAPS_PROTECTED_PATH' }
    }
    if ((Child-Or-Same $policy $toggle) -or (Child-Or-Same $toggle $policy)) { throw 'PROTECTED_ROOTS_MUST_BE_DISTINCT' }
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $result.report = @{
        currentProcessIdentity = $user
        agentIdentityClaim = $AgentIdentity
        policyOwner = (Get-Acl -LiteralPath $policy).Owner
        toggleOwner = (Get-Acl -LiteralPath $toggle).Owner
        workspaceOwner = (Get-Acl -LiteralPath $work).Owner
        policyRoot = $policy
        toggleRoot = $toggle
        workspaceRoot = $work
    }
    if (-not $AgentIdentity) { throw 'AGENT_OS_IDENTITY_UNKNOWN' }
    if ($user.Equals($AgentIdentity,[StringComparison]::OrdinalIgnoreCase)) { throw 'SAME_WINDOWS_PRINCIPAL_CANNOT_ATTEST_SEPARATION' }
    # Different names are not proof of tokens, ACL denial, sandbox or authentication.
    $result.state = 'OBSERVED_NOT_VERIFIED'
    $result.reason = 'REQUIRE_UNPRIVILEGED_AGENT_ACCESS_DENIAL_AND_TRUSTED_UI_E2E'
} catch {
    $result.state = 'BLOCKED'
    $result.reason = $_.Exception.Message
}
$result | ConvertTo-Json -Depth 6
