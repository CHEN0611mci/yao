#Requires -Version 5.1
<#
    MySQL 8.0.x 实例初始化 —— 一键版（只做第 1 阶段）
    ------------------------------------------------------------------
    做什么：选择 MySQL 解压目录 -> 生成 my.ini -> 初始化 data
            -> 注册并启动 Windows 服务 -> 设置 root 密码 -> 验证
    怎么用：双击同目录的「MySQL初始化.bat」（自动请求管理员权限）
    安全性：重复运行不会破坏已有数据；重建需在提示中选 y，且会先备份
#>
[CmdletBinding()]
param(
    [string]$MySqlHome,
    [string]$RootPassword = 'Ruoyi@2026',
    [int]$Port = 3306,
    [string]$ServiceName = 'MySQL80',
    [switch]$Force,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$script:StepNo = 0

function Init-Console {
    try { chcp 65001 | Out-Null } catch { }
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
    try { $global:OutputEncoding = [Console]::OutputEncoding } catch { }
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

function Get-MySqlCandidates {
    $found = @()
    foreach ($base in @('C:\dev', 'C:\', 'C:\Program Files', 'C:\Program Files (x86)', 'D:\dev', 'D:\')) {
        if (Test-Path $base) {
            $found += Get-ChildItem -Path (Join-Path $base 'mysql-*-winx64') -Directory -ErrorAction SilentlyContinue
        }
    }
    return ($found | Where-Object { Test-Path (Join-Path $_.FullName 'bin\mysqld.exe') } |
            Sort-Object FullName -Unique)
}

function Resolve-MySqlHome {
    param([string]$InputPath)
    if ([string]::IsNullOrWhiteSpace($InputPath)) { return $null }
    $p = $InputPath.Trim('"').TrimEnd('\')
    if (Test-Path (Join-Path $p 'bin\mysqld.exe')) { return $p }
    if (Test-Path $p) {
        $sub = Get-ChildItem -Path (Join-Path $p 'mysql-*-winx64') -Directory -ErrorAction SilentlyContinue |
               Where-Object { Test-Path (Join-Path $_.FullName 'bin\mysqld.exe') } | Select-Object -First 1
        if ($sub) { return $sub.FullName }
    }
    return $null
}

function Select-MySqlHomeInteractively {
    for ($t = 1; $t -le 6; $t++) {
        $raw = Read-Choice "  MySQL 目录（输入 q 退出）" "C:\dev\mysql-8.0.46-winx64"
        if ($raw -match '^[Qq]$') { return $null }
        $resolved = Resolve-MySqlHome $raw
        if ($resolved) { return $resolved }
        Bad "该目录下找不到 bin\mysqld.exe：$raw"
        Say "正确示例：C:\dev\mysql-8.0.46-winx64  （该目录下应直接有 bin\ lib\ share\）"
    }
    return $null
}

# ==================================================================== 主流程
Clear-Host
Write-Host "==============================================" -ForegroundColor White
Write-Host "  MySQL 实例初始化（第 1 阶段 · 一键版）" -ForegroundColor White
Write-Host "  MySQL 8.0.x ZIP 免安装版专用" -ForegroundColor DarkGray
Write-Host "==============================================" -ForegroundColor White

Step "检查管理员权限"
if (-not (Test-Admin)) {
    Bad "未获得管理员权限。"
    Say "请改双击【MySQL初始化.bat】，它会自动弹出 UAC 提权。"
    Finish 1
}
Ok "当前为管理员"

Step "选择 MySQL 解压目录"
if (-not $MySqlHome) {
    $cands = @(Get-MySqlCandidates)
    if ($cands.Count -ge 1) {
        if ($cands.Count -eq 1) {
            Write-Host "  自动探测到 MySQL 目录：" -ForegroundColor DarkGray
            Write-Host "    $($cands[0].FullName)" -ForegroundColor DarkGray
            $ans = Read-Choice "  使用这个目录吗？(Y=是 / n=自己选 / q=退出)" "Y"
            if ($ans -match '^[Qq]$') { Finish 0 }
            if ($ans -match '^[Nn]$') { $MySqlHome = Select-MySqlHomeInteractively }
            else { $MySqlHome = $cands[0].FullName }
        }
        else {
            Write-Host "  检测到多个 MySQL 目录：" -ForegroundColor DarkGray
            for ($i = 0; $i -lt $cands.Count; $i++) {
                Write-Host ("   [{0}] {1}" -f ($i + 1), $cands[$i].FullName) -ForegroundColor DarkGray
            }
            $sel = Read-Choice "  请输入编号（回车默认 [1]）" "1"
            $idx = 1
            if (-not [int]::TryParse($sel, [ref]$idx) -or $idx -lt 1 -or $idx -gt $cands.Count) { $idx = 1 }
            $MySqlHome = $cands[$idx - 1].FullName
        }
    }
    else {
        Write-Host "  没有自动找到 MySQL，请手动输入 ZIP 解压后的根目录。" -ForegroundColor DarkGray
        Write-Host "  示例：C:\dev\mysql-8.0.46-winx64" -ForegroundColor DarkGray
        $MySqlHome = Select-MySqlHomeInteractively
    }
}
if (-not $MySqlHome) { Bad "未选择有效的 MySQL 目录，已退出。"; Finish 1 }
if (-not (Test-Path $MySqlHome)) { Bad "目录不存在：$MySqlHome"; Finish 1 }
if ($MySqlHome -match '[^\x00-\x7F]' -or $MySqlHome -match '\s') {
    Warn "路径含中文或空格（$MySqlHome），MySQL 服务可能启动失败，强烈建议移到 C:\dev\ 下。"
}

$mysqld = Join-Path $MySqlHome 'bin\mysqld.exe'
$mysql  = Join-Path $MySqlHome 'bin\mysql.exe'
if (-not (Test-Path $mysqld)) { Bad "找不到 $mysqld"; Finish 1 }

$verRaw = (& $mysqld --version 2>&1 | Out-String).Trim()
Say "版本：$verRaw"
if ($verRaw -notmatch '8\.0\.') {
    Warn "不是 MySQL 8.0.x，建议与队友统一为 8.0.x（避免 SQL dump 不兼容）。"
}
Ok "目录校验通过：$MySqlHome"

if (-not $NonInteractive) {
    Write-Host ""
    Write-Host "  请确认参数（直接回车 = 采用方括号内默认值）：" -ForegroundColor DarkGray
    $RootPassword = Read-Choice "  root 密码（团队统一，勿含特殊符号）" $RootPassword
    $p = Read-Choice "  端口" "$Port"
    $Port = [int]$p
    $ServiceName = Read-Choice "  Windows 服务名" $ServiceName
}

$iniPath = Join-Path $MySqlHome 'my.ini'
$dataDir = Join-Path $MySqlHome 'data'
$forward = $MySqlHome -replace '\\', '/'

Step "生成 my.ini"
if (Test-Path $iniPath) {
    $bak = "$iniPath.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $iniPath $bak -Force
    Say "已备份原 my.ini -> $(Split-Path $bak -Leaf)"
}
$ini = @"
[mysqld]
basedir=$forward
datadir=$forward/data
port=$Port
character-set-server=utf8mb4
collation-server=utf8mb4_0900_ai_ci
default-authentication-plugin=mysql_native_password
max_connections=200
max_allowed_packet=64M
default-time-zone=+08:00
explicit_defaults_for_timestamp=1

[client]
port=$Port
default-character-set=utf8mb4

[mysql]
default-character-set=utf8mb4
"@
[System.IO.File]::WriteAllText($iniPath, $ini, (New-Object System.Text.UTF8Encoding($false)))
Ok "已写入 $iniPath"
Say "basedir = $forward"
Say "datadir = $forward/data"

Step "处理 data 目录"
$dataExists = (Test-Path $dataDir) -and ((Get-ChildItem $dataDir -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)

if ($dataExists -and -not $Force) {
    Warn "data 目录已存在且非空 —— 本机实例可能已经初始化过了。"
    Say  "若只是要启动它：net start $ServiceName"
    if ($NonInteractive) { Say "非交互模式，已退出。"; Finish 0 }
    $ans = Read-Choice "  是否【重建】实例（会清空数据；会先自动备份）？(y/N)" "N"
    if ($ans -notmatch '^[Yy]$') { Say "已取消重建。"; Finish 0 }
    $Force = $true
}

if ($dataExists -and $Force) {
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Host "  正在停止并移除旧服务 $ServiceName ..." -ForegroundColor DarkGray
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        & sc.exe stop $ServiceName | Out-Null
        Start-Sleep -Seconds 3
        & sc.exe delete $ServiceName | Out-Null
        $ErrorActionPreference = $prev
        Start-Sleep -Seconds 3
    }
    $bkDir = Join-Path $MySqlHome ("data_backup_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $moved = $false
    for ($i = 1; $i -le 6; $i++) {
        try { Move-Item $dataDir $bkDir -Force -ErrorAction Stop; $moved = $true; break }
        catch { Say "第 $i 次移动 data 失败（可能仍被占用），2 秒后重试..."; Start-Sleep -Seconds 2 }
    }
    if (-not $moved) { Bad "无法移动 data 目录（被占用），请确认 mysqld 已退出。"; Finish 1 }
    Ok "旧数据已备份到：$bkDir"
} else {
    Ok "data 目录为空，符合初始化条件"
}

Step "初始化实例（mysqld --initialize-insecure）"
Say "root 先创建为【空密码】，随后自动设置密码"
$prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& $mysqld --defaults-file="$iniPath" --initialize-insecure --console 2>&1 |
    ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
$ErrorActionPreference = $prev

if (-not (Test-Path (Join-Path $dataDir 'mysql'))) {
    Bad "初始化失败：data\mysql 未生成。"
    $errLog = Get-ChildItem $dataDir -Filter '*.err' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($errLog) {
        Write-Host "`n--- $($errLog.Name) 末尾 25 行 ---" -ForegroundColor Yellow
        Get-Content $errLog.FullName -Tail 25 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
    } else {
        Say "没有 .err 日志，通常是路径含中文/空格，或 my.ini 无效。"
    }
    Finish 1
}
Ok "初始化成功，系统库已生成"

Step "注册 Windows 服务：$ServiceName"
if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
    Warn "服务 $ServiceName 已存在，跳过注册"
} else {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & $mysqld --install $ServiceName --defaults-file="$iniPath" 2>&1 |
        ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    $ErrorActionPreference = $prev
    if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) { Bad "服务注册失败"; Finish 1 }
    Ok "服务已注册"
}

Step "启动服务"
$svc = Get-Service -Name $ServiceName
if ($svc.Status -ne 'Running') {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & net start $ServiceName 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    $ErrorActionPreference = $prev
    Start-Sleep -Seconds 3
    $svc.Refresh()
    if ($svc.Status -ne 'Running') {
        Bad "服务启动失败。错误日志：Get-Content '$dataDir\*.err' -Tail 40"
        Finish 1
    }
}
Ok "服务已启动"
$prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& sc.exe config $ServiceName start= auto | Out-Null
$ErrorActionPreference = $prev
Ok "已设为开机自启"

Step "设置 root 密码"
Start-Sleep -Seconds 2
$connArgs = $null
foreach ($a in @(@{D='已设过密码';A=@('-uroot',"-p$RootPassword")}, @{D='当前为空密码';A=@('-uroot','--skip-password')})) {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & $mysql @($a.A) --connect-timeout=5 -e "select 1;" 2>&1 | Out-Null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -eq 0) { $connArgs = $a; break }
}
if ($null -eq $connArgs) { Bad "两种方式都连不上 MySQL，请检查服务状态与密码。"; Finish 1 }

if ($connArgs.D -eq '已设过密码') {
    Ok "root 密码已是目标值（跳过设置）"
} else {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $mysql -uroot --skip-password --connect-timeout=5 `
        -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$RootPassword'; FLUSH PRIVILEGES;" 2>&1
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($rc -ne 0) {
        Warn "设置密码失败："
        $out | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
    } else { Ok "root 密码已设置" }
}

Step "配置系统 PATH"
$binDir = Join-Path $MySqlHome 'bin'
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
if ([string]::IsNullOrEmpty($machinePath)) { $machinePath = '' }
if ($machinePath -split ';' -contains $binDir) {
    Ok "PATH 中已包含 $binDir"
} else {
    [Environment]::SetEnvironmentVariable('Path', ($machinePath.TrimEnd(';') + ';' + $binDir), 'Machine')
    Ok "已加入系统 PATH（新开终端生效）"
}

Step "验证实例"
$prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
$showVar = & $mysql -uroot "-p$RootPassword" --connect-timeout=5 -N -B `
    -e "select version(); select @@port; select @@character_set_server; select @@collation_server;" 2>&1
$ErrorActionPreference = $prev
$vals = @($showVar | Where-Object { $_ -notmatch 'Warning|Using a password' })

Write-Host ""
Say "version              : $(if($vals.Count -gt 0){$vals[0]})"
Say "port                 : $(if($vals.Count -gt 1){$vals[1]})"
Say "character_set_server : $(if($vals.Count -gt 2){$vals[2]})"
Say "collation_server     : $(if($vals.Count -gt 3){$vals[3]})"
Say "安装目录             : $MySqlHome"
Say "服务名               : $ServiceName"
Say "错误日志             : $dataDir\*.err"
if ($vals.Count -gt 0 -and $vals[0] -match '^8\.0\.') { Ok "版本 8.0.x，符合团队约定" } else { Warn "版本不是 8.0.x" }
if ($vals.Count -gt 2 -and $vals[2] -eq 'utf8mb4') { Ok "服务端字符集 utf8mb4" } else { Warn "服务端字符集不是 utf8mb4" }

Write-Host ""
Write-Host "=========== 第 1 阶段完成（MySQL 实例已就绪） ===========" -ForegroundColor Green
Write-Host @"
  安装目录 : $MySqlHome
  服务名   : $ServiceName（开机自启）
  端口     : $Port
  root     : $RootPassword

下一步（第 2 阶段：建业务库，本程序不做）：
  mysql -uroot -p -e "create database shop default character set utf8mb4 collate utf8mb4_0900_ai_ci;"

常见问题速查：
  data directory has files in it   -> 已初始化过；要重建就重跑本程序并选 y
  Can't find data directory        -> my.ini 里路径写错
  Could not open required defaults -> my.ini 实际是 my.ini.txt
  服务起不来                        -> Get-Content "$dataDir\*.err" -Tail 40
"@ -ForegroundColor Gray

Finish 0
