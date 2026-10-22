@echo off
rem ============================================================
rem  Redis (Windows) one-click install-as-service launcher
rem  Double-click this file. It auto-elevates to Administrator.
rem  Copies Redis to a writable dir, writes redis.conf, registers
rem  the Windows service, starts it, verifies PONG.
rem
rem  NOTE: keep this file 100%% ASCII.
rem ============================================================
setlocal
title Redis Install

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo.
    echo   Requesting administrator privileges ...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo   Administrator OK, starting Redis installer ...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0redis-install.ps1"

echo.
echo   Launcher finished.
echo.
pause
endlocal
