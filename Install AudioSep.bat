@echo off
REM Double-click installer for AudioSep (MECCHA CHAMELEON).
cd /d "%~dp0"
echo Installing AudioSep...
powershell -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1"
echo.
pause
