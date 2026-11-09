[CmdletBinding()]
param([string]$CodexHome,[string]$ManagedRoot,[switch]$ApproveUninstall)
$ErrorActionPreference='Stop'
if(-not $ApproveUninstall){throw 'EXPLICIT_UNINSTALL_APPROVAL_REQUIRED'}
if(-not $CodexHome){$CodexHome=if($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $HOME '.codex'}}
if(-not $ManagedRoot){$ManagedRoot=Join-Path $env:LOCALAPPDATA 'JHarness-Bootstrap'}
$node=Join-Path $ManagedRoot 'node-v22.22.2\node.exe'
$sha='ae1a50511be58e987483fdbc12125407443926d2d394669ade2352776e920dd3'
if(-not(Test-Path -LiteralPath $node -PathType Leaf)){throw 'MANAGED_NODE_NOT_FOUND'}
if((Get-FileHash -LiteralPath $node -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sha){throw 'MANAGED_NODE_HASH_CHANGED'}
$entry=Join-Path $PSScriptRoot '..\core\setup.mjs'
$original=$env:CODEX_HOME
try {
 $env:CODEX_HOME=[IO.Path]::GetFullPath($CodexHome)
 $result=& $node $entry uninstall 2>&1
 if($LASTEXITCODE -ne 0){throw ('CORE_UNINSTALL_FAILED: '+($result|Out-String))}
 [ordered]@{result='CORE_UNLINKED_ARCHIVED';nodeCache='PRESERVED';authChanged=$false;globalPathChanged=$false;detail=($result|Out-String)} | ConvertTo-Json -Depth 6
}finally{$env:CODEX_HOME=$original}
