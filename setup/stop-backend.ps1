#Requires -Version 5.1
<#
    萌宠优选 · 停止后端
    只停止 run\backend.pid 记录、且命令行包含 ruoyi-admin.jar 的进程，避免误杀。
#>
[CmdletBinding()]
param([int]$Port = 0)

. (Join-Path $PSScriptRoot 'common.ps1')
$Root = Get-PetMallRoot
$runDir = Join-Path $Root 'run'
$pidFile = Join-Path $runDir 'backend.pid'
$portFile = Join-Path $runDir 'backend.port'
if ($Port -le 0 -and (Test-Path -LiteralPath $portFile)) {
    [void][int]::TryParse((Get-Content -LiteralPath $portFile -Raw).Trim(), [ref]$Port)
}

$pidToStop = 0
if (Test-Path -LiteralPath $pidFile) {
    [void][int]::TryParse((Get-Content -LiteralPath $pidFile -Raw).Trim(), [ref]$pidToStop)
}
if ($pidToStop -le 0 -and $Port -gt 0) {
    try {
        $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($conn) { $pidToStop = [int]$conn.OwningProcess }
    } catch { }
}

if ($pidToStop -le 0) {
    Write-Warn '未找到后端 PID，可能未启动。'
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    exit 0
}

$proc = Get-Process -Id $pidToStop -ErrorAction SilentlyContinue
if (-not $proc) {
    Write-Warn "进程 $pidToStop 已不存在。"
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    exit 0
}

$cmdLine = ''
try {
    $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$pidToStop" -ErrorAction SilentlyContinue
    if ($cim) { $cmdLine = [string]$cim.CommandLine }
} catch { }

if ($cmdLine -and $cmdLine -notmatch 'ruoyi-admin\.jar') {
    Write-Bad "进程 $pidToStop 不是本项目后端（$cmdLine），已拒绝停止。"
    exit 1
}

Write-Step "停止后端 PID=$pidToStop"
Stop-Process -Id $pidToStop -Force -ErrorAction SilentlyContinue
for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Milliseconds 300
    if (-not (Get-Process -Id $pidToStop -ErrorAction SilentlyContinue)) { break }
}
Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
if ($Port -gt 0 -and (Test-TcpPort -Port $Port -TimeoutMs 300)) {
    Write-Warn "进程已停止，但端口 $Port 仍在监听，请检查其他进程。"
    exit 1
}
Write-Ok '后端已停止。'
exit 0
