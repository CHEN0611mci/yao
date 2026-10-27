@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
echo Starting user UI (http://127.0.0.1:81/) and admin UI (http://127.0.0.1:80/) ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup\start-all.ps1" %*
set "RC=%errorlevel%"
echo.
if errorlevel 1 pause
exit /b %RC%
