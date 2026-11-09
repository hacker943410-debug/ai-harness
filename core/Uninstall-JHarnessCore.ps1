[CmdletBinding()]
param([string]$CodexHome)
$ErrorActionPreference='Stop'
if(-not $CodexHome){$CodexHome=if($env:CODEX_HOME){$env:CODEX_HOME}else{[IO.Path]::Combine([Environment]::GetFolderPath('UserProfile'),'.codex')}}
$CodexHome=[IO.Path]::GetFullPath($CodexHome)
$registration=[IO.Path]::Combine($CodexHome,'j-harness-core','path-registration.json')
$record=if(Test-Path -LiteralPath $registration){Get-Content -LiteralPath $registration -Encoding UTF8 | ConvertFrom-Json}else{$null}
$sessionFile=[IO.Path]::Combine($CodexHome,'j-harness-core','session-path.json')
$session=if(Test-Path -LiteralPath $sessionFile){Get-Content -LiteralPath $sessionFile -Encoding UTF8 | ConvertFrom-Json}else{$null}
& node ([IO.Path]::Combine($PSScriptRoot,'cli.mjs')) uninstall --codex-home $CodexHome
if($LASTEXITCODE -ne 0){throw 'Unlink failed; PATH was not changed.'}
if($record){$current=[Environment]::GetEnvironmentVariable('Path','User');$kept=@($current -split ';' | Where-Object {$_ -and $_ -ne $record.addedEntry});$new=$kept -join ';';if($record.previousWasMissing -and -not $new){$new=$null};[Environment]::SetEnvironmentVariable('Path',$new,'User')}
if($session -and $session.processId -eq $PID){$removed=$false;$kept=New-Object 'Collections.Generic.List[string]';foreach($entry in ($env:Path -split ';')){if(-not $removed -and $entry -eq $session.addedEntry){$removed=$true;continue};$kept.Add($entry)};$env:Path=$kept -join ';'}
Write-Output 'Only J Harness guidance/PATH entry was unlinked. CLI settings/auth were preserved; private runtime archived.'
