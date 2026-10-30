[CmdletBinding()]
param([string]$CodexHome,[switch]$PlanOnly,[switch]$RegisterUserPath)
$ErrorActionPreference='Stop'
if(-not $CodexHome){$CodexHome=if($env:CODEX_HOME){$env:CODEX_HOME}else{[IO.Path]::Combine([Environment]::GetFolderPath('UserProfile'),'.codex')}}
$CodexHome=[IO.Path]::GetFullPath($CodexHome)
$bin=[IO.Path]::Combine($CodexHome,'j-harness-core','bin')
if($PlanOnly){[ordered]@{product='J Harness Core';codexHome=$CodexHome;installRoot=[IO.Path]::Combine($CodexHome,'j-harness-core');globalGuidance='Selected AGENTS.override.md or AGENTS.md; managed block only';configTomlChanged=$false;credentialsTouched=$false;servicesAccountsAclChanged=$false;registerUserPath=[bool]$RegisterUserPath} | ConvertTo-Json;return}
& node ([IO.Path]::Combine($PSScriptRoot,'cli.mjs')) install --codex-home $CodexHome
if($LASTEXITCODE -ne 0){throw 'Core installation failed; see the JSON error above.'}
# Current terminal only. Persisting PATH requires the explicitly named install switch.
if(@($env:Path -split ';') -notcontains $bin){$env:Path=$bin+[IO.Path]::PathSeparator+$env:Path;[IO.File]::WriteAllText([IO.Path]::Combine($CodexHome,'j-harness-core','session-path.json'),(@{addedEntry=$bin;processId=$PID} | ConvertTo-Json))}
if($RegisterUserPath){$old=[Environment]::GetEnvironmentVariable('Path','User');$entries=@($old -split ';' | Where-Object {$_});if($entries -notcontains $bin){[Environment]::SetEnvironmentVariable('Path',(($entries+$bin) -join ';'),'User');[IO.File]::WriteAllText([IO.Path]::Combine($CodexHome,'j-harness-core','path-registration.json'),(@{addedEntry=$bin;scope='User';previousWasMissing=($null -eq $old)} | ConvertTo-Json))}}
Write-Output 'J Harness Core linked. Start a NEW Codex session. Readonly installation diagnosis follows.'
$diagnosisText=(& ([IO.Path]::Combine($bin,'jh.ps1')) doctor | Out-String)
if($LASTEXITCODE -ne 0){throw 'Installed, but doctor failed. Keep the backup and review the diagnosis.'}
$diagnosis=$diagnosisText | ConvertFrom-Json
Write-Output $diagnosisText
if($diagnosis.effective -ne 'CONNECTED_FOR_NEW_SESSIONS' -or $diagnosis.backupStatus -ne 'MATCH'){throw 'Files were installed but connection or backup verification failed. Review doctor before using Codex.'}
if($diagnosis.profileMismatch){Write-Warning 'The selected Codex home differs from this terminal profile. Use that CODEX_HOME for the intended Codex session; no existing authentication was copied.'}
