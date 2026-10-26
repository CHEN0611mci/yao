#Requires -Version 5.1
<#
    若依(RuoYi) 数据库初始化 —— 一键版（第 1 阶段之后）
    ------------------------------------------------------------------
    做什么：定位 mysql.exe -> 建库 -> 关外键检查 -> 按顺序导入 sql\*.sql -> 校验表数量
    为什么：若依的 SQL 脚本没有 SET FOREIGN_KEY_CHECKS=0，直接导入会因外键依赖中途失败
    怎么用：双击同目录的「建库导入.bat」
    幂等：重复运行会重新建表（脚本内是 drop table if exists），数据会重置
#>
[CmdletBinding()]
param(
    [string]$MySqlHome,
    [string]$RootPassword = 'Ruoyi@2026',
    [string]$DbName = 'shop',
    [string]$SqlDir,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$script:StepNo = 0
try { chcp 65001 | Out-Null } catch { }
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

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
function Find-MySqlExe {
    $cmd = Get-Command mysql.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    if ($MySqlHome) {
        $p = Join-Path $MySqlHome 'bin\mysql.exe'
        if (Test-Path $p) { return $p }
    }
    foreach ($base in @('C:\dev', 'C:\', 'D:\dev', 'D:\', 'C:\Program Files')) {
        if (Test-Path $base) {
            $d = Get-ChildItem -Path (Join-Path $base 'mysql-*-winx64') -Directory -ErrorAction SilentlyContinue |
                 Where-Object { Test-Path (Join-Path $_.FullName 'bin\mysql.exe') } | Select-Object -First 1
            if ($d) { return (Join-Path $d.FullName 'bin\mysql.exe') }
        }
    }
    return $null
}
function Test-MySqlConn {
    param($Exe, $Pwd)
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & $Exe -uroot "-p$Pwd" --connect-timeout=5 -e "select 1;" 2>&1 | Out-Null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return ($code -eq 0)
}

Clear-Host
Write-Host "==============================================" -ForegroundColor White
Write-Host "  若依数据库初始化（建库 + 导入 SQL）" -ForegroundColor White
Write-Host "==============================================" -ForegroundColor White

Step "定位 mysql.exe"
$mysql = Find-MySqlExe
if (-not $mysql) { Bad "找不到 mysql.exe。请先运行 MySQL初始化.bat 安装 MySQL。"; Finish 1 }
Ok "使用 $mysql"

Step "测试 root 连接"
if (Test-MySqlConn $mysql $RootPassword) {
    Ok "root 连接正常"
} else {
    Warn "用默认密码 $RootPassword 连不上。"
    for ($t = 1; $t -le 4; $t++) {
        $pwdIn = Read-Choice "  请输入 MySQL root 密码（输入 q 退出）" ""
        if ($pwdIn -match '^[Qq]$') { Finish 1 }
        if (Test-MySqlConn $mysql $pwdIn) { $RootPassword = $pwdIn; Ok "连接成功"; break }
        Bad "密码错误"
        if ($t -eq 4) { Bad "连续 4 次失败，已退出。"; Finish 1 }
    }
}

if (-not $NonInteractive) {
    Write-Host ""
    Write-Host "  请确认参数（直接回车 = 采用方括号内默认值）：" -ForegroundColor DarkGray
    $DbName = Read-Choice "  业务库名" $DbName
}

Step "定位 SQL 脚本目录"
if (-not $SqlDir) {
    $cands = @()
    if ($MySqlHome) { }
    foreach ($base in @("$env:USERPROFILE\Documents", 'C:\dev', 'C:\', 'D:\', "$env:USERPROFILE\Downloads")) {
        if (Test-Path $base) {
            $cands += Get-ChildItem -Path $base -Recurse -Depth 6 -Directory -Filter 'sql' -ErrorAction SilentlyContinue
        }
    }
    # 优先含 ry_*.sql 的目录
    $cands = $cands | Where-Object { Get-ChildItem $_.FullName -Filter 'ry_*.sql' -ErrorAction SilentlyContinue } |
             Sort-Object FullName -Unique
    if ($cands.Count -ge 1) {
        Write-Host "  检测到含 ry_*.sql 的目录：" -ForegroundColor DarkGray
        for ($i = 0; $i -lt [Math]::Min($cands.Count, 5); $i++) {
            Write-Host ("   [{0}] {1}" -f ($i + 1), $cands[$i].FullName) -ForegroundColor DarkGray
        }
        $sel = Read-Choice "  请输入编号（回车默认 [1]）" "1"
        $idx = 1
        if (-not [int]::TryParse($sel, [ref]$idx) -or $idx -lt 1 -or $idx -gt $cands.Count) { $idx = 1 }
        $SqlDir = $cands[$idx - 1].FullName
    }
}
if (-not $SqlDir -or -not (Test-Path $SqlDir)) {
    Write-Host "  请手动输入若依项目里 sql 目录的完整路径" -ForegroundColor DarkGray
    Write-Host "  例如：C:\Users\LEGION\Documents\Aiwork5\shop\RuoYi-Vue-master\sql" -ForegroundColor DarkGray
    for ($t = 1; $t -le 6; $t++) {
        $raw = Read-Choice "  sql 目录（输入 q 退出）" ""
        if ($raw -match '^[Qq]$') { Finish 1 }
        if (Test-Path $raw) { $SqlDir = $raw.Trim('"').TrimEnd('\'); break }
        Bad "目录不存在：$raw"
    }
}

$sqlFiles = @(Get-ChildItem $SqlDir -Filter '*.sql' -File | Sort-Object Name)
if ($sqlFiles.Count -eq 0) { Bad "$SqlDir 下没有 .sql 文件"; Finish 1 }
Write-Host "  将按顺序导入：" -ForegroundColor DarkGray
$sqlFiles | ForEach-Object { Write-Host "    $($_.Name)  ($([Math]::Round($_.Length/1KB)) KB)" -ForegroundColor DarkGray }
Ok "共 $($sqlFiles.Count) 个脚本"

Step "创建数据库 $DbName"
$prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& $mysql -uroot "-p$RootPassword" -e "CREATE DATABASE IF NOT EXISTS ``$DbName`` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;" 2>&1 |
    ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
$rc = $LASTEXITCODE
$ErrorActionPreference = $prev
if ($rc -ne 0) { Bad "建库失败"; Finish 1 }
Ok "库已就绪：$DbName"

Step "导入 SQL（自动关闭外键检查）"
$failed = @()
foreach ($f in $sqlFiles) {
    Say "导入 $($f.Name) ..."
    # 关键：若依的 SQL 没有 SET FOREIGN_KEY_CHECKS=0，必须由外层包住，
    # 否则表间外键依赖会导致导入中途失败（典型现象：只建成了前一两张表）
    $wrapper = New-TemporaryFile
    $content = "SET NAMES utf8mb4;`nSET FOREIGN_KEY_CHECKS = 0;`nsource $($f.FullName -replace '\\','/')`nSET FOREIGN_KEY_CHECKS = 1;`n"
    [System.IO.File]::WriteAllText($wrapper.FullName, $content, (New-Object System.Text.UTF8Encoding($false)))

    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $mysql -uroot "-p$RootPassword" --default-character-set=utf8mb4 $DbName `
        -e "source $($wrapper.FullName -replace '\\','/')" 2>&1
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $prev
    Remove-Item $wrapper.FullName -Force -ErrorAction SilentlyContinue

    $real = @($out | Where-Object { $_ -notmatch 'Using a password' -and $_.Trim() -ne '' })
    if ($rc -ne 0 -or $real.Count -gt 0) {
        Warn "  $($f.Name) 有输出（可能含错误）："
        $real | Select-Object -First 12 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
        if ($rc -ne 0) { $failed += $f.Name }
    } else {
        Ok "  $($f.Name) 导入完成"
    }
}

Step "校验表数量"
$prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
$cntRaw = & $mysql -uroot "-p$RootPassword" -N -B -e "select count(*) from information_schema.tables where table_schema='$DbName';" 2>&1
$ErrorActionPreference = $prev
$cnt = @($cntRaw | Where-Object { $_ -match '^\d+$' })[0]
Say "库 $DbName 表数量：$cnt"

$expected = 31
if ([int]$cnt -ge $expected) { Ok "表数量达到预期（ry=20 + quartz=11）" }
elseif ([int]$cnt -ge 25) { Warn "表数量偏少（预期 $expected），可能有脚本导入失败" }
else { Bad "表数量明显不足（预期 $expected）。请检查上方错误输出。" }

Write-Output "`n=== 数据库/表明细 ==="
$prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& $mysql -uroot "-p$RootPassword" -N -B -e "select table_name from information_schema.tables where table_schema='$DbName' order by table_name;" 2>&1 |
    Where-Object { $_ -notmatch 'Using a password' -and $_.Trim() -ne '' } |
    ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
$ErrorActionPreference = $prev

Write-Host ""
Write-Host "=============== 数据库初始化完成 ===============" -ForegroundColor Green
Write-Host @"
  库名    : $DbName
  表数量  : $cnt
  SQL目录 : $SqlDir

【下一步：改若依配置】编辑
  ruoyi-admin\src\main\resources\application-druid.yml

  master:
      url: jdbc:mysql://localhost:3306/$DbName`?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true
      username: root
      password: $RootPassword

  注意：原文件里 password 的值是字面量 password，必须改掉；
        url 里的库名默认是 ry-vue，也要改成 $DbName。

  另外把 useSSL=true 改成 useSSL=false（本地无证书，保持 true 会遇到握手告警）。

【常见问题】
  Access denied for user 'root'   -> application-druid.yml 的 password 没改
  Unknown database 'ry-vue'       -> url 里的库名没改
  只建成了前 1~2 张表              -> 本脚本已用 SET FOREIGN_KEY_CHECKS=0 包裹解决
"@ -ForegroundColor Gray

if ($failed.Count -gt 0) { Warn "以下脚本报告了错误：$($failed -join ', ')" }
Finish 0
