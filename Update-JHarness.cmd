@echo off
node "%~dp0core\setup.mjs" update %*
exit /b %ERRORLEVEL%
