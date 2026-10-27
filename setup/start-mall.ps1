#Requires -Version 5.1
[CmdletBinding()]
param([switch]$NoBrowser, [int]$UserPort = 81, [switch]$WithAdmin, [int]$AdminPort = 0)
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Stop'
$Root = Get-PetMallRoot
$Config = Get-PetMallConfig -Root $Root

function Ensure-Dependency {
    param([string]$Label, [string]$HostName, [int]$Port, [string]$TaskName, [string]$ServicePattern)
    if (Test-TcpPort -HostName $HostName -Port $Port) { Write-Ok "$Label ready"; return }
    if ($HostName -notin @('127.0.0.1', 'localhost')) { throw "$Label unavailable at ${HostName}:$Port" }
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    $service = Get-Service -Name $ServicePattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($task) { Start-ScheduledTask -TaskName $TaskName }
    elseif ($service) { Start-Service -Name $service.Name }
    else { throw "$Label is not running. Start the installed service first, then retry. See RUNBOOK.md." }
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        if (Test-TcpPort -HostName $HostName -Port $Port) { Write-Ok "$Label ready"; return }
        Start-Sleep -Milliseconds 500
    }
    throw "$Label did not start. Check its service logs."
}

try {
    Ensure-Dependency 'MySQL' (Get-ConfigValue $Config 'DB_HOST' '127.0.0.1') ([int](Get-ConfigValue $Config 'DB_PORT' '3306')) 'PetMall-MySQL80' 'MySQL*'
    Ensure-Dependency 'Redis' (Get-ConfigValue $Config 'REDIS_HOST' '127.0.0.1') ([int](Get-ConfigValue $Config 'REDIS_PORT' '6379')) 'PetMall-Redis' '*Redis*'
    $backendPort = [int](Get-ConfigValue $Config 'SERVER_PORT' '8080')
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'start-backend.ps1') -Port $backendPort
    if ($LASTEXITCODE -ne 0) { throw 'Backend startup failed. See logs/console.log.' }
    $ready = Invoke-RestMethod -Uri "http://127.0.0.1:$backendPort/api/health" -TimeoutSec 15
    if ($ready.code -ne 200) { throw 'Backend dependencies are not ready.' }
    $node = Get-Command node.exe -ErrorAction Stop
    Write-Step '用户端：构建检查（与 setup/build-ui.ps1 共用构建器）'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build-ui.ps1') -Target User
    if ($LASTEXITCODE -ne 0) { throw 'User UI build failed. See setup/build-ui.ps1 output.' }
    if (-not (Test-TcpPort -Port $UserPort)) {
        $env:MALL_UI_MODE = 'user'
        $env:USER_UI_PORT = [string]$UserPort
        $env:USER_UI_API_TARGET = "http://127.0.0.1:$backendPort"
        $serverFile = Join-Path $PSScriptRoot 'serve-user-ui.mjs'
        $process = Start-Process -FilePath $node.Source -ArgumentList @("`"$serverFile`"") -WorkingDirectory $Root -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $Root 'logs\user-ui.log') -RedirectStandardError (Join-Path $Root 'logs\user-ui.err.log')
        $process.Id | Set-Content -LiteralPath (Join-Path $Root 'run\user-ui.pid') -Encoding ASCII
    }
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        if (Test-TcpPort -Port $UserPort) { break }
        Start-Sleep -Milliseconds 250
    }
    $uiHealth = Invoke-RestMethod -Uri "http://127.0.0.1:$UserPort/api/health" -TimeoutSec 15
    if ($uiHealth.code -ne 200) { throw 'User UI proxy is not connected to the backend.' }
    Write-Ok "Mall ready: http://127.0.0.1:$UserPort/"
    if (-not $NoBrowser) { Start-Process "http://127.0.0.1:$UserPort/" }
    if ($WithAdmin) {
        Write-Step '管理端：构建并托管'
        $adminArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'start-admin.ps1'), '-NoBrowser', '-StartBackend')
        if ($AdminPort -gt 0) { $adminArgs += @('-AdminPort', "$AdminPort") }
        & powershell.exe @adminArgs
        if ($LASTEXITCODE -ne 0) { throw 'Admin UI startup failed.' }
    }
} catch {
    Write-Bad $_.Exception.Message
    exit 1
}
