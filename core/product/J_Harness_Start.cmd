@echo off
setlocal
set "JH_MANAGED=%~dp0"
if not exist "%JH_MANAGED%\app\Installed-JHarness.ps1" (
 echo J Harness is not installed. Run J_Harness_Install.cmd first.
 pause
 exit /b 2
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%JH_MANAGED%\app\Installed-JHarness.ps1" -Action Start
exit /b %ERRORLEVEL%
