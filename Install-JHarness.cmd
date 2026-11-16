@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Install-JHarnessFromGitHub.ps1" -Action Install %*
exit /b %ERRORLEVEL%
