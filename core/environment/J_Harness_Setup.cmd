@echo off
setlocal
cd /d "%~dp0"
echo J Harness v8 portable setup candidate - Windows x64
powershell.exe -NoProfile -File "%~dp0bootstrap\Bootstrap-JHarness.ps1" -Action Plan -Client codex
if errorlevel 1 (
  echo Environment preflight failed. No install attempted.
  pause
  exit /b 2
)
echo.
echo This program will copy pinned Node to your private application folder
echo and add one managed block to the existing Codex global instructions.
echo It will not change system PATH, credentials or Windows accounts.
echo This unsigned candidate DOES NOT provide OS security enforcement.
set /p JH_OK=Type INSTALL to approve, or press Enter to cancel: 
if /I not "%JH_OK%"=="INSTALL" (
  echo Cancelled. No changes made.
  exit /b 0
)
powershell.exe -NoProfile -File "%~dp0bootstrap\Bootstrap-JHarness.ps1" -Action Install -Client codex -ApproveInstall
set "JH_EXIT=%ERRORLEVEL%"
if not "%JH_EXIT%"=="0" echo Installation failed. Review the printed rollback status.
exit /b %JH_EXIT%
