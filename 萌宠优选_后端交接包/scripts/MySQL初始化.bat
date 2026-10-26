@echo off
rem ============================================================
rem  MySQL 8.0.x Instance Initialization - one-click launcher
rem  Double-click this file. It auto-elevates to Administrator.
rem  Stage 1 only: my.ini -> data init -> service -> password.
rem
rem  NOTE: keep this file 100%% ASCII. Non-ASCII text here gets
rem  mangled by cmd.exe codepages and breaks self-elevation.
rem ============================================================
setlocal
title MySQL Init - Stage 1

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo.
    echo   Requesting administrator privileges ...
    echo   Qing qiu guan li yuan quan xian ...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo   Administrator OK, starting initializer ...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mysql-init-stage1.ps1"

echo.
echo   Launcher finished. If the window above closed too fast,
echo   run this .bat again and read the messages carefully.
echo.
pause
endlocal
