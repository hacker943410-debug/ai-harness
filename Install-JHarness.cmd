@echo off
node "%~dp0core\setup.mjs" install %*
exit /b %ERRORLEVEL%
