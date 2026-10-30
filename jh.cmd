@echo off
node "%~dp0core\setup.mjs" run %*
exit /b %ERRORLEVEL%
