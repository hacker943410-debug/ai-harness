@echo off
setlocal
cd /d "%~dp0"
echo J Harness portable uninstall - original guidance is restored and private Core archived.
set /p "JH_OK=Type UNINSTALL to detach J Harness, or press Enter to cancel: "
if /I not "%JH_OK%"=="UNINSTALL" exit /b 0
powershell.exe -NoProfile -File "%~dp0bootstrap\Uninstall-JHarness.ps1" -ApproveUninstall
exit /b %ERRORLEVEL%
