@echo off
cd /d "%~dp0user-ui"
if not exist node_modules call npm.cmd ci
if errorlevel 1 exit /b %errorlevel%
echo User storefront: http://127.0.0.1:81/
call npm.cmd run dev
