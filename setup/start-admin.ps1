#Requires -Version 5.1
<#
    萌宠优选 · 管理端一键启动
    ------------------------------------------------------------------
    行为：
      1. 检查后端 /api/health（未就绪时按 -StartBackend 决定是否拉起后端）
      2. 首次自动安装依赖、生成 admin-ui\.env.production（/prod-api）并构建
      3. 启动 setup\serve-user-ui.mjs 的 admin 模式（静态托管 admin-ui\dist，
         /prod-api 反向代理到后端并去掉前缀）
      4. 校验首页与 /prod-api 反代，然后打开浏览器
    用法：
      powershell -ExecutionPolicy Bypass -File .\setup\start-admin.ps1
      powershell -ExecutionPolicy Bypass -File .\setup\start-admin.ps1 -AdminPort 8081
      powershell -ExecutionPolicy Bypass -File .\setup\start-admin.ps1 -StartBackend
      powershell -ExecutionPolicy Bypass -File .\setup\start-admin.ps1 -SkipBuild -NoBrowser
#>
[CmdletBinding()]
param(
    [int]$AdminPort = 0,
    [int]$BackendPort = 0,
    [switch]$NoBrowser,
    [switch]$SkipBuild,
    [switch]$StartBackend
)

. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Stop'
$Root = Get-PetMallRoot
$Config = Get-PetMallConfig -Root $Root
if ($BackendPort -le 0) { $BackendPort = [int](Get-ConfigValue $Config 'SERVER_PORT' '8080') }
if ($AdminPort -le 0) { $AdminPort = [int](Get-ConfigValue $Config 'ADMIN_UI_PORT' '80') }

# ---------- 1. 后端 ----------
if (-not (Test-TcpPort -Port $BackendPort)) {
    if (-not $StartBackend) {
        Write-Bad "后端未就绪（端口 $BackendPort）。"
        Write-Info '先双击 start-mall.bat 启动后端，或加 -StartBackend 参数让本脚本拉起后端。'
        exit 1
    }
    Write-Step "启动后端（端口 $BackendPort）"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'start-backend.ps1') -Port $BackendPort
    if ($LASTEXITCODE -ne 0) { Write-Bad '后端启动失败，请查看 logs\console.log。'; exit 1 }
}
$health = $null
try { $health = Invoke-RestMethod -Uri "http://127.0.0.1:$BackendPort/api/health" -TimeoutSec 15 } catch { }
if (-not $health -or $health.code -ne 200) {
    Write-Bad "后端健康检查未通过：http://127.0.0.1:$BackendPort/api/health"
    exit 1
}
Write-Ok "后端就绪：http://127.0.0.1:$BackendPort"

# ---------- 2. 构建管理端 ----------
$distIndex = Join-Path $Root 'admin-ui\dist\index.html'
if (-not $SkipBuild) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build-ui.ps1') -Target Admin
    if ($LASTEXITCODE -ne 0) { Write-Bad '管理端构建失败，请查看上方 npm 输出。'; exit 1 }
}
if (-not (Test-Path -LiteralPath $distIndex)) {
    Write-Bad '未找到 admin-ui\dist\index.html。'
    Write-Info '运行：powershell -ExecutionPolicy Bypass -File .\setup\build-ui.ps1 -Target Admin'
    exit 1
}

# ---------- 3. 静态服务 ----------
$node = Get-Command node.exe -ErrorAction SilentlyContinue
if (-not $node) { Write-Bad '未找到 Node.js，请安装 18 或更高版本后重试。'; exit 1 }
$runDir = Join-Path $Root 'run'
$logDir = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force -Path $runDir, $logDir | Out-Null
$pidFile = Join-Path $runDir 'admin-ui.pid'

if (Test-Path -LiteralPath $pidFile) {
    $oldPid = 0
    [void][int]::TryParse((Get-Content -LiteralPath $pidFile -Raw).Trim(), [ref]$oldPid)
    if ($oldPid -gt 0) {
        $old = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if ($old) {
            $oldCommand = (Get-CimInstance Win32_Process -Filter "ProcessId=$oldPid" -ErrorAction SilentlyContinue).CommandLine
            if ($oldCommand -match 'serve-user-ui\.mjs') {
                Write-Warn "管理端静态服务已在运行（PID=$oldPid），沿用现有进程。"
                Write-Ok "管理端：http://127.0.0.1:$AdminPort/"
                if (-not $NoBrowser) { Start-Process "http://127.0.0.1:$AdminPort/" }
                exit 0
            }
        }
    }
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}
if (Test-TcpPort -Port $AdminPort) {
    Write-Bad "端口 $AdminPort 已被其他进程占用。"
    Write-Info '换端口：-AdminPort 8081，或先停止占用进程。'
    exit 1
}

$env:MALL_UI_MODE = 'admin'
$env:USER_UI_PORT = [string]$AdminPort
$env:USER_UI_API_TARGET = "http://127.0.0.1:$BackendPort"
$outLog = Join-Path $logDir 'admin-ui.log'
$errLog = Join-Path $logDir 'admin-ui.err.log'
$serverFile = Join-Path $PSScriptRoot 'serve-user-ui.mjs'
Write-Step "启动管理端静态服务（端口 $AdminPort）"
$process = Start-Process -FilePath $node.Source -ArgumentList @("`"$serverFile`"") -WorkingDirectory $Root `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput $outLog -RedirectStandardError $errLog
$process.Id | Set-Content -LiteralPath $pidFile -Encoding ASCII

for ($attempt = 0; $attempt -lt 40; $attempt++) {
    if (Test-TcpPort -Port $AdminPort) { break }
    Start-Sleep -Milliseconds 250
}
if (-not (Test-TcpPort -Port $AdminPort)) {
    Write-Bad "管理端未能在端口 $AdminPort 启动。"
    if (Test-Path -LiteralPath $errLog) { Get-Content -LiteralPath $errLog -Tail 20 -Encoding UTF8 | ForEach-Object { Write-Host $_ } }
    exit 1
}

# ---------- 4. 校验 ----------
try { $page = Invoke-WebRequest -Uri "http://127.0.0.1:$AdminPort/" -UseBasicParsing -TimeoutSec 15 } catch { $page = $null }
if (-not $page -or $page.StatusCode -ne 200) {
    Write-Bad "管理端首页不可用：http://127.0.0.1:$AdminPort/"
    exit 1
}
$proxyOk = $false
try {
    $proxied = Invoke-RestMethod -Uri "http://127.0.0.1:$AdminPort/prod-api/api/health" -TimeoutSec 15
    $proxyOk = ($proxied.code -eq 200)
} catch { $proxyOk = $false }
if ($proxyOk) { Write-Ok '/prod-api 反向代理正常' }
else { Write-Warn '/prod-api 反代健康检查未通过，请检查后端与 logs\admin-ui.err.log。' }

Write-Ok "管理端已就绪：http://127.0.0.1:$AdminPort/"
Write-Info '账号：admin/admin123（商家 merchant1/merchant123，审核 reviewer/reviewer123）'
Write-Info "日志：$outLog"
if (-not $NoBrowser) { Start-Process "http://127.0.0.1:$AdminPort/" }
exit 0
