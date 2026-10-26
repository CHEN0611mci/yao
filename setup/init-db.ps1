#Requires -Version 5.1
<#
    萌宠优选 · 数据库初始化 / 校验
    ------------------------------------------------------------------
    目标库：MySQL 8.0，库名 shop，45 张表（31 若依 + 14 业务）
    常用：
      powershell -ExecutionPolicy Bypass -File .\setup\init-db.ps1
      powershell -ExecutionPolicy Bypass -File .\setup\init-db.ps1 -Action Status
      powershell -ExecutionPolicy Bypass -File .\setup\init-db.ps1 -Action Verify
      powershell -ExecutionPolicy Bypass -File .\setup\init-db.ps1 -Action Fresh -Force
    说明：
      - 默认 Auto：空库自动 01→02→03；已有 31 张若依表则 02→03；
        已有 45 张表则只检查，不覆盖数据。
      - Fresh/Business/Seed 会覆盖数据；未加 -Force 时拒绝执行。
      - 覆盖前默认用 mysqldump 备份到 backup\，可用 -NoBackup 关闭。
#>
[CmdletBinding()]
param(
    [ValidateSet('Auto', 'Fresh', 'Business', 'Seed', 'Verify', 'Status')]
    [string]$Action = 'Auto',
    [string]$RootPassword,
    [string]$MySqlExe,
    [switch]$Force,
    [switch]$NoBackup
)

. (Join-Path $PSScriptRoot 'common.ps1')
$Root = Get-PetMallRoot
$Config = Get-PetMallConfig -Root $Root
$DbHost = Get-ConfigValue $Config 'DB_HOST' '127.0.0.1'
$DbPort = [int](Get-ConfigValue $Config 'DB_PORT' '3306')
$DbUser = Get-ConfigValue $Config 'DB_USERNAME' 'root'
$DbName = 'shop'
$DbDir = Join-Path $Root 'db'

function Read-RootPassword {
    param([string]$Current)
    if ($Current -and $Current -ne 'CHANGE_ME') { return $Current }
    $sec = Read-Host '请输入 MySQL root 密码（输入为空表示无密码）' -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

if (-not $RootPassword) { $RootPassword = Get-ConfigValue $Config 'DB_PASSWORD' '' }
$RootPassword = Read-RootPassword -Current $RootPassword

$mysql = Resolve-MySql -Config $Config -ExplicitPath $MySqlExe
if (-not $mysql) {
    Write-Bad '未找到 mysql.exe。'
    Write-Info '请在 config\backend.env 设置 MYSQL_HOME 或 MYSQL_EXE，或加 -MySqlExe 参数。'
    exit 1
}
Write-Info "MySQL 客户端：$mysql"

$cnf = Join-Path $env:TEMP ("petmall_mysql_{0}.cnf" -f [guid]::NewGuid().ToString('N'))
try {
    New-MySqlOptionFile -Path $cnf -User $DbUser -Password $RootPassword -HostName $DbHost -Port $DbPort
    $ping = Invoke-MySqlScalar -MySqlExe $mysql -OptionFile $cnf -Sql 'SELECT VERSION();'
    if ($ping.Code -ne 0) {
        Write-Bad "MySQL 连接失败：$($ping.Text)"
        Write-Info '请确认 MySQL80 服务已启动、root 密码正确、端口 3306 可连。'
        exit 1
    }
    Write-Ok "MySQL 连接成功，版本 $($ping.Text)"

    function Get-DbState {
        $sql = "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DbName'; SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DbName' AND LEFT(table_name,4)='pet_';"
        $r = Invoke-MySqlScalar -MySqlExe $mysql -OptionFile $cnf -Sql $sql
        $parts = @($r.Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' })
        $tables = if ($parts.Count -ge 1) { [int]$parts[0] } else { 0 }
        $pet = if ($parts.Count -ge 2) { [int]$parts[1] } else { 0 }
        return [pscustomobject]@{ Tables = $tables; Pet = $pet }
    }

    function Show-State {
        param($State)
        Write-Info "shop 表数量：$($State.Tables)（期望 45；若依基座 31 + 业务 14）"
        Write-Info "pet_* 业务表：$($State.Pet)（期望 14）"
    }


    function Backup-Db {
        if ($NoBackup) { Write-Warn '已按 -NoBackup 跳过备份。'; return }
        $backupDir = Join-Path $Root 'backup'
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        $out = Join-Path $backupDir ("shop_{0}.sql" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        Write-Step "备份现有数据库到 $out"
        $b = Invoke-MySqlDump -MySqlExe $mysql -OptionFile $cnf -Database $DbName -OutFile $out
        if ($b.Code -ne 0) { throw "mysqldump 失败：$($b.Error)" }
        Write-Ok "备份完成：$out"
    }

    function Run-SqlFile {
        param([string]$Name)
        $file = Join-Path $DbDir $Name
        Write-Step "执行 db\$Name"
        # 01_base.sql 自己 CREATE DATABASE + USE shop，不能预先指定 --database=shop
        $dbArg = if ($Name -eq '01_base.sql') { '' } else { $DbName }
        $r = Invoke-MySqlFile -MySqlExe $mysql -OptionFile $cnf -File $file -Database $dbArg
        if ($r.Code -ne 0) {
            Write-Bad "$Name 执行失败（exit=$($r.Code)）"
            $r.Output | Select-Object -First 25 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
            throw "$Name 执行失败"
        }
        if ($r.Output.Count -gt 0) {
            Write-Info '输出（前 10 行）：'
            $r.Output | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        }
        Write-Ok "$Name 执行完成"
    }

    function Invoke-Verify {
        Write-Step '执行 db\verify.sql（只读校验）'
        $r = Invoke-MySqlFile -MySqlExe $mysql -OptionFile $cnf -File (Join-Path $DbDir 'verify.sql') -Database $DbName
        $pass = @($r.Output | Select-String -Pattern 'PASS' -SimpleMatch).Count
        $fail = @($r.Output | Select-String -Pattern 'FAIL' -SimpleMatch).Count
        $r.Output | ForEach-Object { Write-Host $_ }
        Write-Step '校验结果'
        Write-Info "PASS=$pass FAIL=$fail"
        if ($r.Code -ne 0) { Write-Bad "verify.sql 退出码：$($r.Code)" }
        if ($fail -gt 0) { Write-Warn '存在 FAIL。若只有 C08（超时订单时间相关），重新执行 03_seed.sql 即可重置演示时间。' }
        return ($fail -eq 0 -and $r.Code -eq 0)
    }

    $state = Get-DbState
    Write-Step '当前数据库状态'
    Show-State $state

    if ($Action -eq 'Status') {
        Write-Ok '仅查看状态，未修改数据库。'
        exit 0
    }
    if ($Action -eq 'Verify') {
        if (Invoke-Verify) { exit 0 } else { exit 1 }
    }

    if ($state.Tables -eq 0) {
        if ($Action -notin @('Auto', 'Fresh')) {
            Write-Bad "数据库 $DbName 不存在或为空，无法执行 $Action。请先执行 -Action Fresh。"
            exit 1
        }
        Write-Step '检测到全新数据库：执行 01 → 02 → 03'
        Run-SqlFile '01_base.sql'
        Run-SqlFile '02_pet_mall.sql'
        Run-SqlFile '03_seed.sql'
    }
    elseif ($state.Tables -eq 31 -and $state.Pet -eq 0) {
        if ($Action -notin @('Auto', 'Business', 'Fresh')) {
            Write-Bad '检测到若依基座但缺少商城业务表，请执行 -Action Business。'
            exit 1
        }
        if ($Action -eq 'Fresh') {
            if (-not $Force) { Write-Bad '已有 31 张若依表，Fresh 会重建系统表；如确认请加 -Force。'; exit 1 }
            Backup-Db
            Run-SqlFile '01_base.sql'
        }
        Write-Step '检测到若依基座：执行 02 → 03（保留系统表）'
        Run-SqlFile '02_pet_mall.sql'
        Run-SqlFile '03_seed.sql'
    }
    elseif ($state.Tables -eq 45 -and $state.Pet -eq 14) {
        if ($Action -eq 'Auto') {
            Write-Ok '数据库已初始化（45 张表，14 张业务表），跳过重建。'
            Write-Info '如需校验：-Action Verify；如需重置演示数据：-Action Seed -Force。'
            exit 0
        }
        if ($Action -eq 'Seed') {
            if (-not $Force) {
                $ans = Read-Host '将重置全部 pet_* 演示数据，输入 YES 继续'
                if ($ans -ne 'YES') { Write-Warn '已取消。'; exit 0 }
            }
            Backup-Db
            Run-SqlFile '03_seed.sql'
        }
        elseif ($Action -eq 'Business' -or $Action -eq 'Fresh') {
            if (-not $Force) { Write-Bad "$Action 会覆盖现有数据；如确认请加 -Force。"; exit 1 }
            Backup-Db
            if ($Action -eq 'Fresh') { Run-SqlFile '01_base.sql' }
            Run-SqlFile '02_pet_mall.sql'
            Run-SqlFile '03_seed.sql'
        }
    }
    else {
        Write-Bad "数据库结构未知：$($state.Tables) 张表，pet_*=$($state.Pet)。"
        Write-Info '为避免误删，脚本不会自动处理。请先备份，再由人工确认执行 Fresh。'
        exit 2
    }

    $final = Get-DbState
    Write-Step '初始化完成'
    Show-State $final
    if ($final.Tables -eq 45 -and $final.Pet -eq 14) {
        Write-Ok '数据库结构正确，可以启动后端。'
        Write-Info '下一步：检查 config\backend.env 的 DB_PASSWORD，然后运行 start-backend.bat。'
        exit 0
    }
    Write-Bad '表数量不符合预期，请检查上面的 SQL 输出。'
    exit 1
}
catch {
    Write-Bad $_.Exception.Message
    exit 1
}
finally {
    Remove-Item -LiteralPath $cnf -Force -ErrorAction SilentlyContinue
}
