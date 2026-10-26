#Requires -Version 5.1
<#
    萌宠优选 · 宠物商城系统  数据库一键工具
    ------------------------------------------------------------------
    数据库：MySQL 8.0 单库 shop（与后端 application-druid.yml 一致）
    做什么：
      1 初始化/重建：执行 01_base.sql → 02_pet_mall.sql → 03_seed.sql
        （注意：会重建 sys_* 系统表；shop 已有若依表时请改用菜单 2 或手工执行 02）
      2 仅重置演示数据：执行 03_seed.sql
      3 自动校验：执行 verify.sql（只读）
      4 约束/防超卖实测：执行 verify_constraints.sql（预期报错，事务回滚）
      5 回滚业务表：执行 rollback.sql（仅删 pet_*，保留若依系统表）
      6 查看当前状态
    怎么用：
      双击同目录的「宠物商城数据库.bat」→ 按菜单选择；
      或命令行：powershell -NoProfile -ExecutionPolicy Bypass -File .\petmall-db.ps1 -Action Status
    说明：
      - 需要 MySQL 8.0 已启动，root 账号可连接；默认密码取本机演示环境值，可 -RootPassword 覆盖。
      - 所有脚本均带 --default-character-set=utf8mb4，避免中文乱码。
#>
[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Init', 'Reset', 'Verify', 'VerifyConstraints', 'Rollback', 'Status')]
    [string]$Action = 'Menu',
    [string]$MySqlHome,
    [string]$RootPassword = '',
    [string]$DbName = 'shop',
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Continue'
try { chcp 65001 | Out-Null } catch { }
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$script:StepNo = 0
$script:DbDir = (Resolve-Path (Join-Path $PSScriptRoot '..\db')).Path

function Say  { param([string]$m) Write-Host "  $m" }
function Ok   { param([string]$m) Write-Host "[ OK ] $m" -ForegroundColor Green }
function Warn { param([string]$m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Bad  { param([string]$m) Write-Host "[FAIL] $m" -ForegroundColor Red }
function Step { param([string]$m) $script:StepNo++; Write-Host "`n[$($script:StepNo)] $m" -ForegroundColor Cyan }
function Pause2 { if (-not $NonInteractive) { Write-Host ""; [void](Read-Host '按回车键继续') } }

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

function Test-Conn {
    param([string]$Exe, [string]$Pwd)
    $prev = $env:MYSQL_PWD
    $env:MYSQL_PWD = $Pwd
    try {
        $null = & $Exe -uroot --connect-timeout=5 -N -B -e "SELECT 1;" 2>&1
        return ($LASTEXITCODE -eq 0)
    } finally {
        if ($null -eq $prev) { Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue } else { $env:MYSQL_PWD = $prev }
    }
}

function Resolve-Password {
    param([string]$Exe)
    if (Test-Conn $Exe $RootPassword) { return $true }
    Warn "用密码 [$RootPassword] 连不上 MySQL root。"
    if ($NonInteractive) { Bad "非交互模式无法输入密码，请用 -RootPassword 指定。"; return $false }
    for ($t = 1; $t -le 4; $t++) {
        $sec = Read-Host "  请输入 MySQL root 密码（直接回车退出）" -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
        try { $pwdIn = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        if ([string]::IsNullOrWhiteSpace($pwdIn)) { return $false }
        if (Test-Conn $Exe $pwdIn) { $script:RootPassword = $pwdIn; Ok "连接成功"; return $true }
        Bad "密码错误"
    }
    return $false
}

function Invoke-SqlFile {
    param([string]$Exe, [string]$File, [switch]$Force)
    if (-not (Test-Path $File)) { Bad "脚本不存在：$File"; return 1 }
    $fwd = ($File -replace '\\', '/')
    $prevPwd = $env:MYSQL_PWD
    $env:MYSQL_PWD = $script:RootPassword
    $cliArgs = @('-uroot', '--default-character-set=utf8mb4')
    if ($Force) { $cliArgs += '--force' }
    $cliArgs += @('-e', "source $fwd")
    try {
        $out = & $Exe @cliArgs 2>&1
        $code = $LASTEXITCODE
    } finally {
        if ($null -eq $prevPwd) { Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue } else { $env:MYSQL_PWD = $prevPwd }
    }
    $real = @($out | Where-Object { "$_" -notmatch 'Using a password' -and "$_".Trim() -ne '' })
    return [pscustomobject]@{ Code = $code; Output = $real }
}

function Run-SqlQuery {
    param([string]$Exe, [string]$Sql)
    $prevPwd = $env:MYSQL_PWD
    $env:MYSQL_PWD = $script:RootPassword
    try {
        $out = & $Exe -uroot --default-character-set=utf8mb4 -t -e $Sql 2>&1
        $code = $LASTEXITCODE
    } finally {
        if ($null -eq $prevPwd) { Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue } else { $env:MYSQL_PWD = $prevPwd }
    }
    return [pscustomobject]@{ Code = $code; Output = @($out | Where-Object { "$_" -notmatch 'Using a password' }) }
}

# 通过 cmd 的 stdin 重定向执行脚本：--force 下可在报错后继续执行后续语句
# （mysql 客户端的 source 命令遇到错误会中断，因此校验类脚本用重定向方式）
function Invoke-SqlFileStream {
    param([string]$Exe, [string]$File, [switch]$Force)
    if (-not (Test-Path $File)) { return [pscustomobject]@{ Code = 1; Output = @("脚本不存在：$File") } }
    $cmdLine = '"' + $Exe + '" -uroot --default-character-set=utf8mb4'
    if ($Force) { $cmdLine += ' --force' }
    $cmdLine += ' -t < "' + $File + '"'
    $prevPwd = $env:MYSQL_PWD
    $env:MYSQL_PWD = $script:RootPassword
    try {
        $out = cmd /c $cmdLine 2>&1
        $code = $LASTEXITCODE
    } finally {
        if ($null -eq $prevPwd) { Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue } else { $env:MYSQL_PWD = $prevPwd }
    }
    return [pscustomobject]@{ Code = $code; Output = @($out | Where-Object { "$_".Trim() -ne '' }) }
}

function Confirm-Destructive {
    param([string]$Prompt)
    if ($NonInteractive) { return $true }
    $ans = Read-Host "$Prompt 输入 YES 继续（其他任意键取消）"
    return ($ans -eq 'YES')
}

function Invoke-Init {
    param([string]$Exe)
    Step "初始化/重建数据库 $DbName（01 → 02 → 03）"
    if (-not (Confirm-Destructive "将重建若依系统表并重置全部业务数据。")) { Warn "已取消"; return 1 }
    foreach ($name in @('01_base.sql', '02_pet_mall.sql', '03_seed.sql')) {
        Say "执行 $name ..."
        $r = Invoke-SqlFile -Exe $Exe -File (Join-Path $script:DbDir $name)
        if ($r.Code -ne 0 -or $r.Output.Count -gt 0) {
            Bad "$name 执行异常（exit=$($r.Code)）："
            $r.Output | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
            return 1
        }
        Ok "$name 完成"
    }
    return 0
}

function Invoke-Reset {
    param([string]$Exe)
    Step "仅重置演示数据（03_seed.sql）"
    if (-not (Confirm-Destructive "将清空并重置 pet_* 业务演示数据（不影响若依系统表）。")) { Warn "已取消"; return 1 }
    $r = Invoke-SqlFile -Exe $Exe -File (Join-Path $script:DbDir '03_seed.sql')
    if ($r.Code -ne 0 -or $r.Output.Count -gt 0) {
        Bad "03_seed.sql 执行异常（exit=$($r.Code)）："
        $r.Output | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
        return 1
    }
    Ok "演示数据已重置"
    return 0
}

function Invoke-Verify {
    param([string]$Exe)
    Step "自动校验（verify.sql：结构 + 数据量 + 对账）"
    $r = Invoke-SqlFileStream -Exe $Exe -File (Join-Path $script:DbDir 'verify.sql')
    $r.Output | ForEach-Object { Write-Host "$_" }
    if ($r.Code -ne 0) { Bad "verify.sql 执行失败（exit=$($r.Code)）"; return 1 }
    return 0
}

function Invoke-VerifyConstraints {
    param([string]$Exe)
    Step "约束与防超卖实测（verify_constraints.sql：报错为预期结果）"
    $r = Invoke-SqlFileStream -Exe $Exe -File (Join-Path $script:DbDir 'verify_constraints.sql') -Force
    $r.Output | ForEach-Object { Write-Host "$_" }
    Write-Host ""
    Say "判定：出现 5 个 ERROR 3819 + 3 个 ERROR 1062，且 T09=1、T10=0 即为通过。"
    return 0
}

function Invoke-Rollback {
    param([string]$Exe)
    Step "回滚业务表（rollback.sql：仅删除 14 张 pet_* 表）"
    if (-not (Confirm-Destructive "将删除全部业务表与业务数据，保留若依系统表。")) { Warn "已取消"; return 1 }
    $r = Invoke-SqlFile -Exe $Exe -File (Join-Path $script:DbDir 'rollback.sql')
    if ($r.Code -ne 0 -or $r.Output.Count -gt 0) {
        Bad "rollback.sql 执行异常（exit=$($r.Code)）："
        $r.Output | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
        return 1
    }
    Ok "业务表已回滚（如需恢复，执行「1 初始化/重建」或「2 重置演示数据」）"
    return 0
}

function Invoke-Status {
    param([string]$Exe)
    Step "当前状态（库 $DbName）"
    $sql = @"
SELECT COUNT(*) AS total_tables FROM information_schema.tables WHERE table_schema='$DbName';
SELECT COUNT(*) AS pet_tables FROM information_schema.tables WHERE table_schema='$DbName' AND LEFT(table_name,4)='pet_';
SELECT 'pet_member' AS t, COUNT(*) AS n FROM $DbName.pet_member
UNION ALL SELECT 'pet_member_pet', COUNT(*) FROM $DbName.pet_member_pet
UNION ALL SELECT 'pet_address', COUNT(*) FROM $DbName.pet_address
UNION ALL SELECT 'pet_category', COUNT(*) FROM $DbName.pet_category
UNION ALL SELECT 'pet_item', COUNT(*) FROM $DbName.pet_item
UNION ALL SELECT 'pet_item_sku', COUNT(*) FROM $DbName.pet_item_sku
UNION ALL SELECT 'pet_order', COUNT(*) FROM $DbName.pet_order
UNION ALL SELECT 'pet_payment', COUNT(*) FROM $DbName.pet_payment
UNION ALL SELECT 'pet_stock_log', COUNT(*) FROM $DbName.pet_stock_log;
SELECT user_name, nick_name FROM $DbName.sys_user ORDER BY user_id;
"@
    $r = Run-SqlQuery -Exe $Exe -Sql $sql
    if ($r.Code -ne 0) {
        Bad "查询失败：库 $DbName 可能尚未初始化。可执行「1 初始化/重建」。"
        $r.Output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
        return 1
    }
    $r.Output | ForEach-Object { Write-Host "$_" }
    Ok "状态读取完成"
    return 0
}

function Show-Menu {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor White
    Write-Host "  萌宠优选 · 数据库一键工具（shop）" -ForegroundColor White
    Write-Host "==============================================" -ForegroundColor White
    Write-Host "  1  初始化/重建（01 → 02 → 03；会重建若依系统表）"
    Write-Host "  2  仅重置演示数据（03_seed.sql）"
    Write-Host "  3  自动校验（verify.sql，只读）"
    Write-Host "  4  约束/防超卖实测（verify_constraints.sql）"
    Write-Host "  5  回滚业务表（rollback.sql）"
    Write-Host "  6  查看当前状态"
    Write-Host "  0  退出"
    Write-Host ""
}

# ============================ 主流程 ============================
Clear-Host
Write-Host "==============================================" -ForegroundColor White
Write-Host "  萌宠优选 · 宠物商城系统 数据库脚本工具" -ForegroundColor White
Write-Host "==============================================" -ForegroundColor White
Say "脚本目录：$($script:DbDir)"

Step "定位 mysql.exe"
$mysql = Find-MySqlExe
if (-not $mysql) {
    Bad "找不到 mysql.exe。请确认 MySQL 8.0 已安装，或用 -MySqlHome 指定安装目录。"
    Pause2
    exit 1
}
Ok "使用 $mysql"

Step "测试 root 连接"
$ok = Resolve-Password $mysql
if (-not $ok) {
    Bad "MySQL 连接失败，请检查服务是否启动（服务名 MySQL80）与 root 密码。"
    Pause2
    exit 1
}
Ok "root 连接正常"

if ($Action -eq 'Menu') {
    while ($true) {
        Show-Menu
        $choice = Read-Host "请选择 [0-6]"
        switch ($choice) {
            '1' { $null = Invoke-Init $mysql }
            '2' { $null = Invoke-Reset $mysql }
            '3' { $null = Invoke-Verify $mysql }
            '4' { $null = Invoke-VerifyConstraints $mysql }
            '5' { $null = Invoke-Rollback $mysql }
            '6' { $null = Invoke-Status $mysql }
            '0' { break }
            default { Warn "无效选项，请输入 0-6" }
        }
        if ($choice -eq '0') { break }
        Pause2
    }
    Write-Host ""
    Ok "已退出。"
    exit 0
}

$code = 0
switch ($Action) {
    'Init'              { $code = Invoke-Init $mysql }
    'Reset'             { $code = Invoke-Reset $mysql }
    'Verify'            { $code = Invoke-Verify $mysql }
    'VerifyConstraints' { $code = Invoke-VerifyConstraints $mysql }
    'Rollback'          { $code = Invoke-Rollback $mysql }
    'Status'            { $code = Invoke-Status $mysql }
}
if ($code -ne 0) { Bad "执行结束（exit=$code）"; Pause2; exit $code }
Ok "执行完成"
Pause2
exit 0
