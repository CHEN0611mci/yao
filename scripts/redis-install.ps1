#Requires -Version 5.1
<#
    Redis (Windows) 一键安装为系统服务
    ------------------------------------------------------------------
    做什么：选择 Redis 目录 -> 搬到可写路径 -> 生成 redis.conf
            -> 注册 Windows 服务 -> 启动 -> 开机自启 -> 验证 PONG
    怎么用：双击同目录的「Redis安装.bat」（自动请求管理员权限）
    说明：重复运行安全；改配置会先备份 redis.conf
#>
[CmdletBinding()]
param(
    [string]$RedisSrc,                       # 解压出来、含 redis-server.exe 的目录
    [string]$RedisHome = 'C:\dev\redis',     # 安装（运行）目录
    [int]$Port = 6379,
    [string]$ServiceName = 'Redis',
    [switch]$AllowLan,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$script:StepNo = 0

function Init-Console {
    try { chcp 65001 | Out-Null } catch { }
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
}
Init-Console

function Say  { param($m) Write-Host "  $m" }
function Ok   { param($m) Write-Host "[ OK ] $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Bad  { param($m) Write-Host "[FAIL] $m" -ForegroundColor Red }
function Step { param($m) $script:StepNo++; Write-Host "`n[$($script:StepNo)] $m" -ForegroundColor Cyan }
function Finish {
    param([int]$Code = 0)
    Write-Host ""
    Write-Host "按回车键关闭窗口..." -ForegroundColor DarkGray
    try { [void](Read-Host) } catch { Start-Sleep -Seconds 8 }
    exit $Code
}
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Read-Choice {
    param([string]$Prompt, [string]$Default)
    $shown = if ([string]::IsNullOrEmpty($Default)) { '' } else { " [$Default]" }
    while ($true) {
        $v = Read-Host "$Prompt$shown"
        if ([string]::IsNullOrWhiteSpace($v)) {
            if (-not [string]::IsNullOrEmpty($Default)) { return $Default }
            Write-Host "  必须输入一个值。" -ForegroundColor Yellow
            continue
        }
        return $v.Trim()
    }
}
function Test-RedisDir {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $p = $Path.Trim('"').TrimEnd('\')
    return (Test-Path (Join-Path $p 'redis-server.exe'))
}
function Find-RedisDirs {
    $found = @()
    foreach ($base in @('C:\Program Files', 'C:\Program Files (x86)', 'C:\dev', 'C:\', 'D:\dev', 'D:\', "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop")) {
        if (Test-Path $base) {
            $found += Get-ChildItem -Path (Join-Path $base 'Redis*') -Directory -ErrorAction SilentlyContinue
            $found += Get-ChildItem -Path (Join-Path $base 'redis*') -Directory -ErrorAction SilentlyContinue
        }
    }
    return ($found | Where-Object { Test-Path (Join-Path $_.FullName 'redis-server.exe') } | Sort-Object FullName -Unique)
}

# ==================================================================== 主流程
Clear-Host
Write-Host "==============================================" -ForegroundColor White
Write-Host "  Redis (Windows) 一键安装为系统服务" -ForegroundColor White
Write-Host "==============================================" -ForegroundColor White

Step "检查管理员权限"
if (-not (Test-Admin)) {
    Bad "未获得管理员权限。"
    Say "请改双击【Redis安装.bat】，它会自动弹出 UAC 提权。"
    Finish 1
}
Ok "当前为管理员"

Step "选择 Redis 目录"
if (-not (Test-RedisDir $RedisSrc)) {
    $cands = @(Find-RedisDirs)
    if ($cands.Count -ge 1) {
        if ($cands.Count -eq 1) {
            Write-Host "  自动探测到：" -ForegroundColor DarkGray
            Write-Host "    $($cands[0].FullName)" -ForegroundColor DarkGray
            $ans = Read-Choice "  使用这个目录吗？(Y=是 / n=自己选 / q=退出)" "Y"
            if ($ans -match '^[Qq]$') { Finish 0 }
            if ($ans -match '^[Nn]$') { $RedisSrc = $null } else { $RedisSrc = $cands[0].FullName }
        }
        else {
            Write-Host "  检测到多个 Redis 目录：" -ForegroundColor DarkGray
            for ($i = 0; $i -lt $cands.Count; $i++) {
                Write-Host ("   [{0}] {1}" -f ($i + 1), $cands[$i].FullName) -ForegroundColor DarkGray
            }
            $sel = Read-Choice "  请输入编号（回车默认 [1]）" "1"
            $idx = 1
            if (-not [int]::TryParse($sel, [ref]$idx) -or $idx -lt 1 -or $idx -gt $cands.Count) { $idx = 1 }
            $RedisSrc = $cands[$idx - 1].FullName
        }
    }
    if (-not (Test-RedisDir $RedisSrc)) {
        Write-Host "  请手动输入含 redis-server.exe 的目录" -ForegroundColor DarkGray
        for ($t = 1; $t -le 6; $t++) {
            $raw = Read-Choice "  Redis 目录（输入 q 退出）" ""
            if ($raw -match '^[Qq]$') { Finish 0 }
            if (Test-RedisDir $raw) { $RedisSrc = $raw.Trim('"').TrimEnd('\'); break }
            Bad "该目录下找不到 redis-server.exe：$raw"
        }
    }
}
if (-not (Test-RedisDir $RedisSrc)) { Bad "未选择有效的 Redis 目录，已退出。"; Finish 1 }
$RedisSrc = $RedisSrc.Trim('"').TrimEnd('\')
Ok "源目录：$RedisSrc"

$srcVer = (& (Join-Path $RedisSrc 'redis-server.exe') --version 2>&1 | Out-String).Trim()
if ($srcVer) { Say "版本：$srcVer" } else { Warn "无法读取版本号（cygwin 版在受限环境下可能报错，不影响安装）" }

if ((Test-Path (Join-Path $RedisSrc 'cygwin1.dll'))) {
    Warn "这是 cygwin 移植版。若启动后立刻退出，请改用 Docker(redis:7.4-alpine) 或 tporadowski 的 5.0.14.1。"
}

if (-not $NonInteractive) {
    Write-Host ""
    Write-Host "  请确认参数（直接回车 = 采用方括号内默认值）：" -ForegroundColor DarkGray
    $RedisHome = Read-Choice "  安装目录（建议无空格、无中文）" $RedisHome
    $p = Read-Choice "  端口" "$Port"
    $Port = [int]$p
    $ServiceName = Read-Choice "  Windows 服务名" $ServiceName
    $lan = Read-Choice "  允许局域网连接? (y/N)" "n"
    $AllowLan = ($lan -match '^[Yy]')
}

if ($RedisHome -match '[^\x00-\x7F]') { Bad "安装目录含中文：$RedisHome，请换成纯英文路径"; Finish 1 }
if ($RedisHome -match '\s') { Warn "安装目录含空格，部分配置需加引号，建议换成 $env:SystemDrive\dev\redis" }

# ---------------------------------------------------------------- 1. 拷贝
Step "复制程序到可写目录"
$sameDir = ($RedisSrc.TrimEnd('\') -ieq $RedisHome.TrimEnd('\'))
if ($sameDir) {
    Ok "源目录即安装目录，跳过复制"
} else {
    if (-not (Test-Path $RedisHome)) { New-Item -ItemType Directory -Force -Path $RedisHome | Out-Null }
    # 若目标已有 redis-server.exe，说明之前装过：只补文件，不覆盖配置
    Get-ChildItem $RedisSrc -File | ForEach-Object {
        $dest = Join-Path $RedisHome $_.Name
        if ($_.Name -ieq 'redis.conf' -or $_.Name -ieq 'start.bat' -or $_.Name -ieq 'sentinel.conf') { return }
        Copy-Item $_.FullName $dest -Force
    }
    Ok "已复制到 $RedisHome"
}

$exe = Join-Path $RedisHome 'redis-server.exe'
$cli = Join-Path $RedisHome 'redis-cli.exe'
if (-not (Test-Path $exe)) { Bad "复制失败，找不到 $exe"; Finish 1 }
if (-not (Test-Path $cli)) { Warn "找不到 redis-cli.exe，验证步骤可能失败" }

if (Test-Path (Join-Path $RedisSrc 'cygwin1.dll')) {
    Ok "已连同 cygwin1.dll 等依赖一起复制"
}

# ---------------------------------------------------------------- 2. data 目录
Step "准备数据目录"
$dataDir = Join-Path $RedisHome 'data'
$logDir  = Join-Path $RedisHome 'log'
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir  | Out-Null
Ok "data = $dataDir"
Ok "log  = $logDir"

# ---------------------------------------------------------------- 3. redis.conf
Step "生成 redis.conf"
$confPath = Join-Path $RedisHome 'redis.conf'
if (Test-Path $confPath) {
    $bak = "$confPath.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $confPath $bak -Force
    Say "已备份原 redis.conf -> $(Split-Path $bak -Leaf)"
}
$bindAddr = if ($AllowLan) { '0.0.0.0' } else { '127.0.0.1' }
$fData = ($dataDir -replace '\\', '/')
$fLog  = (Join-Path $logDir 'redis.log') -replace '\\', '/'

$conf = @"
# ---- 由 Redis安装.bat 生成 ----
bind $bindAddr
protected-mode yes
port $Port
timeout 0
tcp-keepalive 300

# 后台运行：Windows 服务模式下必须为 no
daemonize no
loglevel notice
logfile "$fLog"
databases 16

# 持久化（校园项目够用；若依只做缓存可把 save 全注释掉提性能）
save 900 1
save 300 10
save 60 10000
dbfilename dump.rdb
dir "$fData"
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec

# 内存上限（可按队友机器内存调整；超出后按 LRU 淘汰）
maxmemory 256mb
maxmemory-policy allkeys-lru

# 注意：这里【不设】 requirepass。
# 若依 application.yml 里 redis.password 默认为空；如要设密码，
# 必须同步改 application.yml，否则若依连不上。
# requirepass YourPasswordHere
"@
[System.IO.File]::WriteAllText($confPath, $conf, (New-Object System.Text.UTF8Encoding($false)))
Ok "已写入 $confPath"
Say "bind = $bindAddr    port = $Port    dir = $fData"

# ---------------------------------------------------------------- 4. 注册服务
Step "注册 Windows 服务：$ServiceName"
$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing) {
    Warn "服务 $ServiceName 已存在，先停止并删除以便按新配置重建"
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & sc.exe stop $ServiceName | Out-Null
    Start-Sleep -Seconds 2
    & sc.exe delete $ServiceName | Out-Null
    $ErrorActionPreference = $prev
    Start-Sleep -Seconds 2
}
$binPath = "`"$exe`" `"$confPath`""
$prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& sc.exe create $ServiceName binPath= $binPath start= auto DisplayName= "Redis Server ($Port)" 2>&1 |
    ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
& sc.exe description $ServiceName "Redis in-memory data store (installed by Redis安装.bat)" | Out-Null
$ErrorActionPreference = $prev
if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
    Bad "服务注册失败"
    Finish 1
}
Ok "服务已注册"

# ---------------------------------------------------------------- 5. 启动
Step "启动服务"
$prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& net start $ServiceName 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
$ErrorActionPreference = $prev
Start-Sleep -Seconds 3

$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
$listening = [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
if ($svc.Status -ne 'Running' -or -not $listening) {
    Bad "服务未正常启动（Status=$($svc.Status)，端口监听=$listening）"
    $logFile = Join-Path $logDir 'redis.log'
    if (Test-Path $logFile) {
        Write-Host "`n--- redis.log 末尾 25 行 ---" -ForegroundColor Yellow
        Get-Content $logFile -Tail 25 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
    }
    Say "cygwin 移植版若报 'couldn't create signal pipe' 一类错误，属于该移植版的兼容问题，"
    Say "建议改用 Docker：docker run -d --name redis -p 6379:6379 redis:7.4-alpine"
    Finish 1
}
Ok "服务已启动，端口 $Port 正在监听"

# ---------------------------------------------------------------- 6. 验证
Step "验证 PONG"
$pong = $null
if (Test-Path $cli) {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $pong = (& $cli -h 127.0.0.1 -p $Port ping 2>&1 | Out-String).Trim()
    $ErrorActionPreference = $prev
}
if ($pong -eq 'PONG') { Ok "redis-cli ping -> PONG" } else { Warn "ping 返回：$pong" }

if (-not $NonInteractive) {
    $ans = Read-Choice "  是否把 Redis 目录加入系统 PATH？(Y/n)" "Y"
    if ($ans -notmatch '^[Nn]$') {
        $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        if ([string]::IsNullOrEmpty($machinePath)) { $machinePath = '' }
        if ($machinePath -split ';' -notcontains $RedisHome) {
            [Environment]::SetEnvironmentVariable('Path', ($machinePath.TrimEnd(';') + ';' + $RedisHome), 'Machine')
            Ok "已加入系统 PATH（新开终端生效）"
        } else { Ok "PATH 中已包含 $RedisHome" }
    }
}

Write-Host ""
Write-Host "=============== Redis 安装完成 ===============" -ForegroundColor Green
Write-Host @"
  安装目录 : $RedisHome
  服务名   : $ServiceName（开机自启）
  端口     : $Port    bind = $bindAddr
  配置     : $confPath
  数据/AOF : $fData
  日志     : $(Join-Path $logDir 'redis.log')
  密码     : 未设置（与若依默认配置一致）

若依 application.yml 里对应填写：
  spring:
    redis:
      host: 127.0.0.1
      port: $Port
      database: 0
      password:      # 留空

验证命令：
  redis-cli ping                      -> PONG
  redis-cli keys "login_tokens:*"     -> 若依后台登录成功后可看到登录 Token

$(if ($AllowLan) { "⚠ 已开启局域网可见：记得放行防火墙`n  New-NetFirewallRule -DisplayName 'Redis-6379-LAN' -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Profile Private" })
"@ -ForegroundColor Gray

Finish 0
