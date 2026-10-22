<#
.SYNOPSIS
  MySQL「第 2 层：业务库初始化」脚本（校园二手商城 / 若依基座）

.DESCRIPTION
  在第 1 层（实例已能连通）基础上完成：
    1. 建业务库（默认 shop），显式 utf8mb4 / utf8mb4_0900_ai_ci
    2. 建专用应用账号（默认 mall），不要让若依用 root
    3. 可选：允许局域网其他队友连接（用于"共享库/联调"模式）
    4. 导入 db\*.sql（若依 ry_*.sql、quartz.sql、你们的 second_* 表）
    5. 输出 application-druid.yml 模板与 .env 模板

  幂等：库/账号已存在不会报错；已有表就不会被覆盖（导入用 --force 只管继续，不删表）。

.PARAMETER DbName
  业务库名，默认 shop。

.PARAMETER AppUser
  应用账号，默认 mall。

.PARAMETER AppPassword
  应用账号密码，默认 Mall@2026。

.PARAMETER RootPassword
  root 密码，默认 Ruoyi@2026（与 Init-MySqlInstance.ps1 保持一致）。

.PARAMETER AllowLan
  允许该应用账号从局域网任意主机连接（'%'）。仅"共享库/联调"时开启。

.PARAMETER SqlDir
  要导入的 SQL 目录，默认脚本所在目录的 ..\db 。按文件名顺序导入。

.PARAMETER SkipImport
  只建库和账号，不导入 SQL。

.EXAMPLE
  .\Init-ShopDatabase.ps1
.EXAMPLE
  # 共享库模式：允许队友从局域网连
  .\Init-ShopDatabase.ps1 -AllowLan
#>

[CmdletBinding()]
param(
    [string]$DbName = 'shop',
    [string]$AppUser = 'mall',
    [string]$AppPassword = 'Mall@2026',
    [string]$RootPassword = 'Ruoyi@2026',
    [switch]$AllowLan,
    [string]$SqlDir,
    [switch]$SkipImport,
    [string]$MySqlHome,
    [switch]$Interactive
)

$ErrorActionPreference = 'Stop'
$script:StepNo = 0
function Say  { param($m) Write-Host "  $m" }
function Ok   { param($m) Write-Host "[ OK ] $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Die  { param($m) Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }
function Step { param($m) $script:StepNo++; Write-Host "`n[$($script:StepNo)] $m" -ForegroundColor Cyan }

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
    return ($found | Sort-Object FullName -Unique)
}

Write-Host "=== 业务库初始化脚本（第 2 层） ===" -ForegroundColor White
Write-Host "库: $DbName   应用账号: $AppUser   允许局域网: $(if($AllowLan){'是'}else{'否'})" -ForegroundColor DarkGray

# ---------------------------------------------------------------- 定位 mysql.exe
Step "定位 mysql.exe"
$mysql = $null

# 1) 优先 PATH
$mysqlCmd = Get-Command mysql.exe -ErrorAction SilentlyContinue
if ($mysqlCmd) { $mysql = $mysqlCmd.Source; Say "从 PATH 找到：$mysql" }

# 2) 再用 -MySqlHome
if (-not $mysql -and $MySqlHome) {
    $cand = Join-Path $MySqlHome 'bin\mysql.exe'
    if (Test-Path $cand) { $mysql = $cand; Say "从 -MySqlHome 找到：$mysql" }
}

# 3) 再自动探测
if (-not $mysql) {
    $guess = Get-MySqlCandidates | Where-Object { Test-Path (Join-Path $_.FullName 'bin\mysql.exe') } | Select-Object -First 1
    if ($guess) { $mysql = Join-Path $guess.FullName 'bin\mysql.exe'; Say "自动探测到：$mysql" }
}

# 4) 都没找到：问用户
if (-not $mysql) {
    Warn "未自动找到 mysql.exe。请输入 MySQL 解压目录（ZIP 根目录，含 bin\ lib\ share\）"
    $cands = @(Get-MySqlCandidates)
    if ($cands.Count -gt 0) {
        Write-Host "  检测到候选：" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $cands.Count; $i++) {
            Write-Host ("   [{0}] {1}" -f ($i + 1), $cands[$i].FullName) -ForegroundColor DarkGray
        }
    }
    $defaultPath = if ($cands.Count -gt 0) { $cands[0].FullName } else { 'C:\dev\mysql-8.0.46-winx64' }
    for ($t = 1; $t -le 5; $t++) {
        $p = (Read-Choice "  MySQL 目录（直接回车用默认，输入 q 退出）" $defaultPath).Trim('"').TrimEnd('\')
        if ($p -eq 'q') { Die "用户放弃。" }
        $cand = Join-Path $p 'bin\mysql.exe'
        if (Test-Path $cand) { $mysql = $cand; break }
        Warn "该目录下找不到 bin\mysql.exe：$p"
    }
}
if (-not $mysql -or -not (Test-Path $mysql)) {
    Die "找不到 mysql.exe。请先把 MySQL\bin 加入 PATH，或用 -MySqlHome 指定。"
}
Ok "使用 $mysql"

# 交互模式：确认关键参数
if ($Interactive) {
    Write-Host ""
    Write-Host "  当前参数（回车保留默认值）：" -ForegroundColor DarkGray
    $DbName        = Read-Choice "  业务库名" $DbName
    $AppUser       = Read-Choice "  应用账号" $AppUser
    $AppPassword   = Read-Choice "  应用账号密码" $AppPassword
    $RootPassword  = Read-Choice "  root 密码" $RootPassword
    $lan = Read-Choice "  允许局域网连接? (y/N)" "n"
    $AllowLan = ($lan -match '^[Yy]')
    Ok "参数确认：库=$DbName 账号=$AppUser@$(if($AllowLan){'%'}else{'localhost'})  局域网=$AllowLan"
}

# ---------------------------------------------------------------- 连通性
Step "验证 root 连接"
$prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
$probe = & $mysql -uroot "-p$RootPassword" --connect-timeout=5 -N -B -e "select version();" 2>&1
$code = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($code -ne 0) {
    Write-Host ($probe | Out-String) -ForegroundColor DarkYellow
    Die "root 连不上。请确认密码正确、服务已启动（sc query MySQL80）。"
}
$serverVer = @($probe | Where-Object { $_ -notmatch 'Warning|Using a password' })[0]
Ok "已连接，服务端版本 $serverVer"

# ---------------------------------------------------------------- 建库
Step "创建业务库 $DbName"
$sqlCreateDb = @"
CREATE DATABASE IF NOT EXISTS ``$DbName``
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;
"@
$prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& $mysql -uroot "-p$RootPassword" -e $sqlCreateDb 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
$code = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($code -ne 0) { Die "建库失败" }

$check = & $mysql -uroot "-p$RootPassword" -N -B -e "select default_character_set_name, default_collation_name from information_schema.schemata where schema_name='$DbName';" 2>&1
$checkVal = @($check | Where-Object { $_ -notmatch 'Warning|Using a password' })
Ok "库已就绪：$DbName  ($($checkVal -join ' / '))"

# ---------------------------------------------------------------- 应用账号
Step "创建应用账号 $AppUser"
$hostPattern = if ($AllowLan) { '%' } else { 'localhost' }
$sqlUser = @"
CREATE USER IF NOT EXISTS '$AppUser'@'$hostPattern' IDENTIFIED BY '$AppPassword';
ALTER USER '$AppUser'@'$hostPattern' IDENTIFIED BY '$AppPassword';
GRANT ALL PRIVILEGES ON ``$DbName``.* TO '$AppUser'@'$hostPattern';
FLUSH PRIVILEGES;
"@
$prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& $mysql -uroot "-p$RootPassword" -e $sqlUser 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
$code = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($code -ne 0) { Die "账号创建失败" }
Ok "账号 $AppUser@$hostPattern 已就绪，仅对 $DbName 有权限"

if ($AllowLan) {
    Warn "已允许局域网连接。别忘了在「服务器」那台机器上放行防火墙："
    Say  "New-NetFirewallRule -DisplayName 'MySQL-3306-LAN' -Direction Inbound -Protocol TCP -LocalPort 3306 -Action Allow -Profile Private"
    Say  "并在 my.ini 的 [mysqld] 加 bind-address=0.0.0.0 后重启服务。"
}

# ---------------------------------------------------------------- 导入 SQL
Step "导入 SQL 脚本"
if ($SkipImport) {
    Warn "已按 -SkipImport 跳过"
} else {
    if (-not $SqlDir) { $SqlDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'db' }
    if (-not (Test-Path $SqlDir)) {
        Warn "SQL 目录不存在：$SqlDir"
        Say  "把若依的 ry_20250417.sql、quartz.sql 和你们的建表脚本放到该目录后重跑本脚本。"
        Say  "（若依 ZIP 解压后自带 sql\ 目录，直接 -SqlDir 指向它即可；建议先拷进仓库 db\ 统一管理）"
    } else {
        $files = Get-ChildItem -Path $SqlDir -Filter '*.sql' -File | Sort-Object Name
        if ($files.Count -eq 0) { Warn "$SqlDir 下没有 .sql 文件" }
        foreach ($f in $files) {
            Say "导入 $($f.Name) ..."
            $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            # 关键：source 前先关闭外键检查，避免建表顺序依赖导致失败（等价于 DBeaver 的"禁用外键检查"）
            $script = "SET FOREIGN_KEY_CHECKS=0; source $($f.FullName -replace '\\','/'); SET FOREIGN_KEY_CHECKS=1;"
            & $mysql -uroot "-p$RootPassword" $DbName --default-character-set=utf8mb4 -e $script 2>&1 |
                ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
            $rc = $LASTEXITCODE
            $ErrorActionPreference = $prevEap
            if ($rc -ne 0) { Warn "$($f.Name) 导入出现错误（见上方输出），继续下一个" }
            else { Ok "$($f.Name) 导入完成" }
        }
    }
}

# ---------------------------------------------------------------- 结果
Step "核对表数量"
$prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
$tblCount = & $mysql -uroot "-p$RootPassword" -N -B -e "select count(*) from information_schema.tables where table_schema='$DbName';" 2>&1
$ErrorActionPreference = $prevEap
$cnt = @($tblCount | Where-Object { $_ -match '^\d+$' })[0]
Say "$DbName 库表数量：$cnt"
if ([int]$cnt -lt 20) { Warn "表数量偏少。若依基础表约 20+ 张，确认 ry_20250417.sql 与 quartz.sql 都导入成功。" }
else { Ok "表结构看起来完整" }

# ---------------------------------------------------------------- 生成配置模板
Step "生成连接配置模板"
$outDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'docs\05-部署手册'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$envTpl = @"
# ===== .env（禁止提交到 Git，已在 .gitignore 中忽略）=====
DB_HOST=localhost
DB_PORT=3306
DB_NAME=$DbName
DB_USER=$AppUser
DB_PASSWORD=$AppPassword
REDIS_HOST=localhost
REDIS_PORT=6379
"@
$envPath = Join-Path $outDir '.env.example'
[System.IO.File]::WriteAllText($envPath, $envTpl, (New-Object System.Text.UTF8Encoding($false)))

$ymlTpl = @"
# ===== application-druid.yml 主库数据源填写模板 =====
# 本地开发：DB_HOST 用 localhost；共享库/联调：改成持有数据库那台机器的局域网 IP
# 密码一律走环境变量，不要写死明文再提交
master:
  url: jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true&rewriteBatchedStatements=true
  username: ${DB_USER}
  password: ${DB_PASSWORD}

# ---- 团队统一的值（与 Init-ShopDatabase.ps1 参数一致即可）----
# DB_HOST      = localhost
# DB_PORT      = 3306
# DB_NAME      = $DbName
# DB_USER      = $AppUser
# DB_PASSWORD  = $AppPassword
"@
$ymlPath = Join-Path $outDir 'application-druid-模板.yml'
[System.IO.File]::WriteAllText($ymlPath, $ymlTpl, (New-Object System.Text.UTF8Encoding($false)))

Ok "已生成 $envPath"
Ok "已生成 $ymlPath"

Write-Host "`n=================== 第 2 层完成 ===================" -ForegroundColor Green
Write-Host @"
业务库已就绪：
  库名     : $DbName   （utf8mb4 / utf8mb4_0900_ai_ci）
  应用账号 : $AppUser@$hostPattern
  表数量   : $cnt
  连接串   : jdbc:mysql://localhost:$([char]0x24)DB_PORT/$DbName?...

下一步：
  1) 用 DBeaver 连一次验证：host=localhost port=3306 user=$AppUser db=$DbName
  2) 把 db\*.sql 纳入 Git（这是 4 人"共用一个逻辑库"的唯一真源）
  3) 每人本地按 README 执行「删库重建」自检：
       mysql -uroot -p -e "drop database if exists $DbName;"
       .\scripts\Init-ShopDatabase.ps1
  4) 演示周如需共享库：在有库的那台机器上 -AllowLan 重跑本脚本 + 放行 3306 防火墙
"@ -ForegroundColor Gray
