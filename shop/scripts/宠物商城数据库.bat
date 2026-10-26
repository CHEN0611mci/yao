@echo off
rem ============================================================
rem  Pet Mall database helper launcher (Windows)
rem  Double-click this file. Requires MySQL 8.0 running.
rem  Menu: init/rebuild, reset demo data, verify, constraint test,
rem        rollback, status.
rem  NOTE: keep this file 100%% ASCII.
rem ============================================================
setlocal
title Pet Mall DB Helper
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0petmall-db.ps1"
echo.
pause
endlocal
