@echo off
node "%~dp0core\setup.mjs" uninstall %*
exit /b %ERRORLEVEL%
