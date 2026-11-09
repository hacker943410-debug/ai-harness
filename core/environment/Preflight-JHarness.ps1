# Native Windows discovery, works without installed Node. No writes, installs or authentication.
[CmdletBinding()]
param(
 [ValidateSet('codex','claude','agy')][string]$Client='codex',
 [ValidateSet('general','roblox')][string]$Profile='general'
)
$ErrorActionPreference='Stop'
function FindTool([string]$name){
 $result=Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
 if($result){return [string]$result.Source};return $null
}
$node=FindTool 'node'
$cli=FindTool $Client
$git=FindTool 'git'
$optional=@()
if($Profile -eq 'roblox'){$optional=@('rojo','stylua','selene')}
$tools=@(foreach($item in $optional){$found=FindTool $item;[ordered]@{
 component=$item;path=$found;state=$(if($found){'DISCOVERED_UNVERIFIED'}else{'MISSING_OPTIONAL'})
}})
[ordered]@{
 product='J Harness Environment Bootstrap'
 stage='PHASE_1_CANDIDATE'
 state=$(if($node -and $cli){'DISCOVERED_UNVERIFIED'}else{'SETUP_REQUIRED'})
 platform=[System.Runtime.InteropServices.RuntimeInformation]::OSDescription
 client=$Client
 profile=$Profile
 node=@{path=$node;state=$(if($node){'FOUND_VERSION_NOT_VERIFIED'}else{'MISSING'})}
 selectedCLI=@{path=$cli;state=$(if($cli){'FOUND_NOT_EXECUTED'}else{'MISSING'})}
 git=@{path=$git;required=$false}
 optionalTools=$tools
 hostChanged=$false
 authChanged=$false
 installPerformed=$false
 next='Owner-approved, pinned package installer is not implemented in this phase.'
} | ConvertTo-Json -Depth 6
