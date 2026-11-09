@echo off
setlocal
set "JH_MANAGED=%~dp0"
if not exist "%JH_MANAGED%\app\Installed-JHarness.ps1" (
 echo J Harness is not installed.
 exit /b 2
)
echo Uninstall only J Harness managed components and restore original Codex instructions.
set /p JH_CONSENT=Type UNINSTALL to confirm: 
if /I not "%JH_CONSENT%"=="UNINSTALL" exit /b 0
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%JH_MANAGED%\app\Installed-JHarness.ps1" -Action Uninstall -ApproveUninstall
set "JH_EXIT=%ERRORLEVEL%"
if not "%JH_EXIT%"=="0" pause
exit /b %JH_EXIT%
