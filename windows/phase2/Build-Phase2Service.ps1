# Compile only; no service registration or host configuration.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
if (-not [Environment]::OSVersion.Platform.Equals([PlatformID]::Win32NT)) { throw 'WINDOWS_REQUIRED' }
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $csc -PathType Leaf)) { throw 'FRAMEWORK_COMPILER_NOT_AVAILABLE' }
$dest=[IO.Path]::GetFullPath($OutputDirectory)
if (-not (Test-Path -LiteralPath $dest -PathType Container)) { throw 'PRECREATED_TEST_SERVICE_DIR_REQUIRED' }
$exe=Join-Path $dest 'JHarnessPhase2LabService.exe'
if (Test-Path -LiteralPath $exe) { throw 'EXISTING_BINARY_PRESERVED' }
& $csc /nologo /target:exe /optimize+ ('/out:'+$exe) /r:System.ServiceProcess.dll /r:System.Web.Extensions.dll /r:System.Core.dll (Join-Path $PSScriptRoot 'JHarnessPhase2LabService.cs')
if ($LASTEXITCODE -ne 0) { throw 'PHASE2_SERVICE_COMPILATION_FAILED' }
@{build='COMPILED_ONLY';serviceInstalled=$false;serviceStarted=$false;sha256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash} | ConvertTo-Json
