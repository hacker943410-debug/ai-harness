@echo off
setlocal
cd /d "%~dp0"
echo =====================================================
echo   J Harness - Windows x64 integrated setup CANDIDATE
 echo =====================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0core\product\Install-JHarnessProduct.ps1" -Action Plan
if errorlevel 1 (
  echo Environment inspection failed. Nothing has been installed.
  pause
  exit /b 2
)
echo.
echo Installs app-local Node and if necessary official pinned Codex.
echo Adds a managed block to the existing Codex instructions only.
echo Does not edit account login, global PATH, registry or other CLIs.
echo This beta does NOT enforce OS-level agent isolation.
echo.
set /p JH_CONSENT=Type INSTALL to approve, otherwise press Enter: 
if /I not "%JH_CONSENT%"=="INSTALL" (
  echo Cancelled without changes.
  exit /b 0
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0core\product\Install-JHarnessProduct.ps1" -Action Install -ApproveInstall
set "JH_EXIT=%ERRORLEVEL%"
if not "%JH_EXIT%"=="0" (
 echo Installation failed; inspect error and rollback details.
 pause
)
exit /b %JH_EXIT%
