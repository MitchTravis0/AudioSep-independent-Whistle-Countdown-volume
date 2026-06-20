@echo off
REM Double-click uninstaller for AudioSep (MECCHA CHAMELEON).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\uninstall.ps1"
echo.
pause
