# Compiles a read-only Windows service candidate, but NEVER registers or runs it.
[CmdletBinding()]
param([string]$OutputDirectory=(Join-Path $PSScriptRoot 'bin'))
$ErrorActionPreference='Stop'
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'WINDOWS_REQUIRED' }
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $csc -PathType Leaf)) { throw 'FRAMEWORK_COMPILER_UNAVAILABLE_NO_AUTO_INSTALL' }
$source=Join-Path $PSScriptRoot 'WindowsService-Lab.cs'
$dest=[IO.Path]::GetFullPath($OutputDirectory)
if (-not (Test-Path -LiteralPath $dest)) {[IO.Directory]::CreateDirectory($dest) | Out-Null}
$exe=Join-Path $dest 'JHarnessPhase1LabService.exe'
if(Test-Path -LiteralPath $exe){throw 'EXISTING_EXECUTABLE_PRESERVED'}
& $csc /nologo /target:exe /optimize+ ('/out:'+$exe) /r:System.ServiceProcess.dll $source
if($LASTEXITCODE -ne 0){ throw 'WINDOWS_LAB_SERVICE_COMPILATION_FAILED' }
@{product='J Harness';candidate=$exe;build='COMPILED_ONLY';serviceInstalled=$false;serviceStarted=$false;osEnforcement='NOT_ATTESTED';sha256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash} | ConvertTo-Json
