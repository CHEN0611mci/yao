@echo off
cd /d "%~dp0"
set MALL_UI_MODE=admin
set USER_UI_PORT=80
echo Admin UI: http://127.0.0.1:80/ . Start start-mall.bat first.
node setup/serve-user-ui.mjs
if errorlevel 1 pause
