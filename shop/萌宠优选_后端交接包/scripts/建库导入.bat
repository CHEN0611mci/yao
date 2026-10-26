@echo off
rem ============================================================
rem  RuoYi database init launcher (create DB + import SQL)
rem  Double-click this file. It auto-elevates to Administrator.
rem  Wraps the import in SET FOREIGN_KEY_CHECKS=0, which the
rem  stock RuoYi SQL scripts do not do themselves.
rem
rem  NOTE: keep this file 100%% ASCII.
rem ============================================================
setlocal
title RuoYi DB Init

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo.
    echo   Requesting administrator privileges ...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo   Administrator OK, starting DB initializer ...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0init-ruoyi-db.ps1"

echo.
echo   Launcher finished.
echo.
pause
endlocal
