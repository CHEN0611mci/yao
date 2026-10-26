<#
.SYNOPSIS
  MySQL 8.0.x ZIP 版「第 1 层实例初始化」一键脚本（适用于校园二手商城小组项目）

.DESCRIPTION
  自动完成：
    1. 定位/校验 MySQL 解压目录与 mysqld.exe
    2. 生成 my.ini（若已存在则备份后重写）
    3. 初始化 data 目录（--initialize-insecure，root 初始空密码）
    4. 注册 Windows 服务（默认 MySQL80）
    5. 启动服务
    6. 设置 root 密码（utf8mb4 + 兼容认证插件）
    7. 验证版本/端口/字符集，并把 mysql 加入系统 PATH

  幂等：重复执行不会破坏已有实例；需要重建时必须显式加 -Force。

.PARAMETER MySqlHome
  MySQL 解压目录，默认自动探测 C:\dev\mysql-8.0.*

.PARAMETER RootPassword
  root 密码。默认 Ruoyi@2026。建议：团队 4 人统一，不要含 ! " ' ; 等特殊字符。

.PARAMETER Port
  端口，默认 3306。

.PARAMETER ServiceName
  Windows 服务名，默认 MySQL80（建议含 MySQL 8.0.46 的版本号信息，避免与 26.7 冲突时混淆）。

.PARAMETER Force
  已存在 data 目录时也强制重建（会先自动备份 data 到 data_backup_时间戳，不会静默删数据）。

.PARAMETER AddToPath
  把 <MySqlHome>\bin 写入系统 PATH（默认开启）。

.PARAMETER SkipPathUpdate
  不修改系统 PATH（与 -AddToPath 等价的反向开关，给不想改环境的人用）。

.EXAMPLE
  # 常规首次安装（以管理员身份运行 PowerShell）
  .\Init-MySqlInstance.ps1

.EXAMPLE
  # 指定路径与密码
  .\Init-MySqlInstance.ps1 -MySqlHome "C:\dev\mysql-8.0.46-winx64" -RootPassword "Team@Mall2026"

.EXAMPLE
  # 忘了密码 / 想彻底重来（会先备份 data 目录）
  .\Init-MySqlInstance.ps1 -Force
#>

[CmdletBinding()]
param(
    [string]$MySqlHome,
    [string]$RootPassword = 'Ruoyi@2026',
    [int]$Port = 3306,
    [string]$ServiceName = 'MySQL80',
    [switch]$Force,
    [switch]$AddToPath,
    [switch]$SkipPathUpdate,
    [switch]$Interactive
)

$ErrorActionPreference = 'Stop'
$script:StepNo = 0

function Say  { param($m) Write-Host "  $m" }
function Ok   { param($m) Write-Host "[ OK ] $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Die  { param($m) Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }
function Step { param($m) $script:StepNo++; Write-Host "`n[$($script:StepNo)] $m" -ForegroundColor Cyan }

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 交互式提问（回车取默认值）
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

# 探测候选 MySQL 目录
function Get-MySqlCandidates {
    $found = @()
    foreach ($base in @('C:\dev', 'C:\', 'C:\Program Files', 'C:\Program Files (x86)', 'D:\dev', 'D:\')) {
        if (Test-Path $base) {
            $found += Get-ChildItem -Path (Join-Path $base 'mysql-*-winx64') -Directory -ErrorAction SilentlyContinue
        }
    }
    return ($found | Sort-Object FullName -Unique)
}

# ---------------------------------------------------------------- 0. 前置检查
Write-Host "=== MySQL 实例初始化脚本（第 1 层） ===" -ForegroundColor White
Write-Host "服务名: $ServiceName   端口: $Port" -ForegroundColor DarkGray

Step "检查管理员权限"
if (-not (Test-Admin)) {
    Die "请以【管理员身份】重新打开 PowerShell 再运行本脚本（注册 Windows 服务需要管理员权限）。"
}
Ok "当前为管理员"

Step "选择 MySQL 解压目录"
if (-not $MySqlHome) {
    $cands = @(Get-MySqlCandidates)

    if ($cands.Count -eq 1 -and -not $Interactive) {
        $MySqlHome = $cands[0].FullName
        Say "自动探测到唯一候选：$MySqlHome"
    }
    elseif ($cands.Count -gt 1 -and -not $Interactive) {
        Write-Host "  检测到多个 MySQL 目录：" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $cands.Count; $i++) {
            Write-Host ("   [{0}] {1}" -f ($i + 1), $cands[$i].FullName) -ForegroundColor DarkGray
        }
        $sel = Read-Choice "  请选择编号（回车默认最后安装的 1 个）" "1"
        $idx = 1
        if ([int]::TryParse($sel, [ref]$idx) -and $idx -ge 1 -and $idx -le $cands.Count) {
            $MySqlHome = $cands[$idx - 1].FullName
        } else {
            $MySqlHome = $cands[0].FullName
        }
    }
    else {
        # 没有候选，或显式 -Interactive：让用户输入
        if ($cands.Count -gt 0) {
            Write-Host "  检测到以下候选（可直接回车采用第 1 个）：" -ForegroundColor DarkGray
            for ($i = 0; $i -lt $cands.Count; $i++) {
                Write-Host ("   [{0}] {1}" -f ($i + 1), $cands[$i].FullName) -ForegroundColor DarkGray
            }
        }
        $defaultPath = if ($cands.Count -gt 0) { $cands[0].FullName } else { 'C:\dev\mysql-8.0.46-winx64' }
        $inputPath = Read-Choice "  请输入 MySQL 解压目录（ZIP 解压后的根目录）" $defaultPath
        $MySqlHome = $inputPath.Trim('"').TrimEnd('\')

        # 若输入的是父目录，尝试自动下钻到 mysql-*-winx64
        if (-not (Test-Path (Join-Path $MySqlHome 'bin\mysqld.exe'))) {
            $sub = Get-ChildItem -Path (Join-Path $MySqlHome 'mysql-*-winx64') -Directory -ErrorAction SilentlyContinue |
                   Select-Object -First 1
            if ($sub) {
                Say "该目录下发现 $($sub.Name)，自动使用它"
                $MySqlHome = $sub.FullName
            }
        }

        # 还没找到就反复问，直到合法或用户放弃
        $tries = 0
        while (-not (Test-Path (Join-Path $MySqlHome 'bin\mysqld.exe'))) {
            $tries++
            Warn "该目录下找不到 bin\mysqld.exe：$MySqlHome"
            Say  "提示：要填 ZIP 解压后的【根目录】，里面应直接有 bin\ lib\ share\；"
            Say  "      例如 C:\dev\mysql-8.0.46-winx64（不要把 bin 目录本身填进来）"
            $again = Read-Choice "  重新输入目录（输入 q 退出）" ""
            if ($again -eq 'q') { Die "用户放弃。请确认 MySQL ZIP 已解压到 C:\dev\ 下。" }
            $MySqlHome = $again.Trim('"').TrimEnd('\')
            if ($tries -ge 5) { Die "连续 5 次未找到有效目录，已退出。" }
        }
    }
}
if (-not (Test-Path $MySqlHome)) { Die "目录不存在：$MySqlHome" }
if ($MySqlHome -match '[^\x00-\x7F]' -or $MySqlHome -match '\s') {
    Warn "路径含中文或空格（$MySqlHome），MySQL 服务可能启动失败，强烈建议移到 C:\dev\ 下。"
}

$mysqld  = Join-Path $MySqlHome 'bin\mysqld.exe'
$mysql   = Join-Path $MySqlHome 'bin\mysql.exe'
$mysqladmin = Join-Path $MySqlHome 'bin\mysqladmin.exe'
if (-not (Test-Path $mysqld)) { Die "找不到 $mysqld —— 确认这是 ZIP 解压后的根目录（里面应直接有 bin\ lib\ share\）" }

$verRaw = (& $mysqld --version 2>&1 | Out-String).Trim()
Say "发现：$verRaw"
if ($verRaw -notmatch '8\.0\.') {
    Warn "当前不是 MySQL 8.0.x。若你们团队统一用 8.0.46，请换回 8.0.x，避免与队友的 dump 不兼容。"
}
Ok "目录校验通过：$MySqlHome"

# 交互模式下顺带确认端口/密码（回车取默认）
if ($Interactive) {
    Write-Host ""
    $RootPassword = Read-Choice "root 密码（团队统一，建议不含特殊符号）" $RootPassword
    $p = Read-Choice "端口" "$Port"
    $Port = [int]$p
    $sn = Read-Choice "Windows 服务名" $ServiceName
    $ServiceName = $sn
    Ok "参数确认：端口=$Port  服务名=$ServiceName  root密码=$RootPassword"
}

# ---------------------------------------------------------------- 1. 生成 my.ini
Step "生成 my.ini"
$iniPath = Join-Path $MySqlHome 'my.ini'
$dataDir = Join-Path $MySqlHome 'data'
$forward = $MySqlHome -replace '\\', '/'

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
# 无 BOM 写入：MySQL 读带 BOM 的 ini 会出问题
[System.IO.File]::WriteAllText($iniPath, $ini, (New-Object System.Text.UTF8Encoding($false)))
Ok "已写入 $iniPath"
Say "basedir = $forward"
Say "datadir = $forward/data"

# ---------------------------------------------------------------- 2. data 目录处理
Step "处理 data 目录"
$dataExists = (Test-Path $dataDir) -and ((Get-ChildItem $dataDir -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)

if ($dataExists -and -not $Force) {
    Warn "data 目录已存在且非空 —— 说明本机实例可能已经初始化过了。"
    Say  "如果是同一实例，请不要重复初始化，直接启动服务即可：net start $ServiceName"
    Say  "如果确实要重建（会清空所有数据），请加 -Force 重新运行："
    Say  "    .\Init-MySqlInstance.ps1 -Force"
    exit 0
}

if ($dataExists -and $Force) {
    $bkDir = Join-Path $MySqlHome ("data_backup_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    Warn "-Force 已指定：把现有 data 目录整体改名备份（不删除数据）"
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Say "先停止并移除旧服务 $ServiceName"
        & sc.exe stop $ServiceName | Out-Null
        Start-Sleep -Seconds 3
        & sc.exe delete $ServiceName | Out-Null
        Start-Sleep -Seconds 3
    }
    # 服务刚停时 data 目录可能仍被文件句柄占用，重试几次再放弃
    $moved = $false
    for ($i = 1; $i -le 5; $i++) {
        try {
            Move-Item $dataDir $bkDir -Force -ErrorAction Stop
            $moved = $true
            break
        } catch {
            Say "第 $i 次移动 data 失败（可能仍被占用），2 秒后重试..."
            Start-Sleep -Seconds 2
        }
    }
    if (-not $moved) {
        Die "无法移动 data 目录（文件被占用）。请确认 mysqld 已退出：Get-Process mysqld -ErrorAction SilentlyContinue"
    }
    Say "旧数据已备份到：$bkDir"
    Ok "data 目录已腾空"
} else {
    Ok "data 目录不存在，符合初始化条件"
}

# ---------------------------------------------------------------- 3. 初始化
Step "初始化实例（mysqld --initialize-insecure）"
Say "root 将创建为【空密码】，下一步脚本会自动改密码"
& $mysqld --defaults-file="$iniPath" --initialize-insecure --console 2>&1 |
    ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

if (-not (Test-Path (Join-Path $dataDir 'mysql'))) {
    $errLog = Get-ChildItem $dataDir -Filter '*.err' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($errLog) {
        Write-Host "`n--- $($errLog.Name) 末尾 25 行 ---" -ForegroundColor Yellow
        Get-Content $errLog.FullName -Tail 25 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
    }
    Die "初始化失败：data\mysql 未生成。请对照上面日志排查（路径含中文/空格、my.ini 无效、磁盘权限）。"
}
Ok "初始化成功，系统库已生成"

# ---------------------------------------------------------------- 4. 注册服务
Step "注册 Windows 服务：$ServiceName"
$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing) {
    Warn "服务 $ServiceName 已存在，跳过注册（如需重建请先：sc.exe delete $ServiceName）"
} else {
    & $mysqld --install $ServiceName --defaults-file="$iniPath" 2>&1 |
        ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
        Die "服务注册失败（可尝试：& '$mysqld' --install $ServiceName --defaults-file='$iniPath'）"
    }
    Ok "服务已注册"
}

# ---------------------------------------------------------------- 5. 启动服务
Step "启动服务"
$svc = Get-Service -Name $ServiceName
if ($svc.Status -eq 'Running') {
    Ok "服务已在运行"
} else {
    try { Start-Service $ServiceName } catch {
        Warn "Start-Service 失败，改用 net start 重试"
        & net start $ServiceName 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    }
    Start-Sleep -Seconds 2
    $svc.Refresh()
    if ($svc.Status -ne 'Running') {
        Die "服务启动失败。请查看错误日志：Get-Content '$dataDir\*.err' -Tail 40"
    }
    Ok "服务已启动"
}

# 设为开机自启（ZIP 版没有图形勾选项）
& sc.exe config $ServiceName start= auto | Out-Null
Ok "已设为开机自启"

# ---------------------------------------------------------------- 6. 设置 root 密码
Step "设置 root 密码"
Start-Sleep -Seconds 2

# 注意：个别 mysqld 版本 --initialize-insecure 之后 root 仍是「认证插件要求密码」的状态，
# 此时 --skip-password 会报 "Access denied"。所以两种登录方式都要试。
$attempts = @(
    @{ Desc = 'root 已设过密码';  Args = @('-uroot', "-p$RootPassword") },
    @{ Desc = 'root 当前为空密码'; Args = @('-uroot', '--skip-password') }
)

$connArgs = $null
foreach ($a in $attempts) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # 避免 native stderr 被当成终止错误
    $probe = & $mysql @($a.Args) --connect-timeout=5 -e "select 1;" 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($code -eq 0) { $connArgs = $a; break }
}

if ($null -eq $connArgs) {
    Warn "两种方式都连不上。请手工排查：sc query $ServiceName ; 密码是否被你们改过"
    Say  "手工兜底：net stop $ServiceName ; & '$mysqld' --defaults-file='$iniPath' --skip-grant-tables --console"
    Die  "无法连接 MySQL，密码设置中止"
}

if ($connArgs.Desc -eq 'root 已设过密码') {
    Ok "root 密码已是目标值（跳过）"
} else {
    $sql = "ALTER USER 'root'@'localhost' IDENTIFIED BY '$RootPassword'; FLUSH PRIVILEGES;"
    $out = & $mysql -uroot --skip-password --connect-timeout=5 -e $sql 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host ($out | Out-String) -ForegroundColor DarkYellow
        Warn "空密码改密失败。可能是已初始化过且密码不是空，或密码含特殊字符被 shell 吞掉。"
        Say  "手工兜底：& '$mysql' -uroot --skip-password -e `"ALTER USER 'root'@'localhost' IDENTIFIED BY '$RootPassword';`""
    } else {
        Ok "root 密码已设置"
    }
}

# ---------------------------------------------------------------- 7. 加入 PATH
Step "配置系统 PATH"
if ($SkipPathUpdate) {
    Warn "已按 -SkipPathUpdate 跳过"
} else {
    $binDir = Join-Path $MySqlHome 'bin'
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    if ([string]::IsNullOrEmpty($machinePath)) { $machinePath = '' }
    if ($machinePath -split ';' -contains $binDir) {
        Ok "PATH 中已包含 $binDir"
    } else {
        [Environment]::SetEnvironmentVariable('Path', ($machinePath.TrimEnd(';') + ';' + $binDir), 'Machine')
        Ok "已加入系统 PATH：$binDir（新开终端生效）"
    }
}

# ---------------------------------------------------------------- 8. 验证
Step "验证实例"
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$showVar = & $mysql -uroot "-p$RootPassword" --connect-timeout=5 -N -B `
    -e "select version(); select @@port; select @@character_set_server; select @@collation_server;" 2>&1
$ErrorActionPreference = $prevEap
$vals = @($showVar | Where-Object { $_ -notmatch 'Warning|Using a password' })
Write-Host ""
Say "version              : $(if($vals.Count -gt 0){$vals[0]})"
Say "port                 : $(if($vals.Count -gt 1){$vals[1]})"
Say "character_set_server : $(if($vals.Count -gt 2){$vals[2]})"
Say "collation_server     : $(if($vals.Count -gt 3){$vals[3]})"
Say "data 目录            : $dataDir"

if ($vals.Count -gt 0 -and $vals[0] -match '^8\.0\.') { Ok "版本为 8.0.x，符合团队约定" }
else { Warn "版本不是 8.0.x，请与队友统一" }
if ($vals.Count -gt 2 -and $vals[2] -eq 'utf8mb4') { Ok "服务端字符集为 utf8mb4" }
else { Warn "服务端字符集不是 utf8mb4（中文/emoji 可能出问题）" }

# ---------------------------------------------------------------- 完成
Write-Host "`n=================== 第 1 层完成 ===================" -ForegroundColor Green
Write-Host @"
MySQL 实例已就绪：
  安装目录 : $MySqlHome
  服务名   : $ServiceName   (开机自启)
  端口     : $Port
  root     : $RootPassword
  错误日志 : $dataDir\*.err

下一步（第 2 层：业务库）：
  1) 运行同目录下的 Init-ShopDatabase.ps1 创建 shop 库与专用账号
  2) 导入若依基础表：
       mysql -uroot -p -e "source C:/.../ry_20250417.sql"  shop
       mysql -uroot -p -e "source C:/.../quartz.sql"       shop
  3) 修改 application-druid.yml 的连接信息（建议用 .env 占位符，勿提交密码）
  4) 把 mysql bin 目录加入 PATH 后，新开终端验证： mysql --version

常见错误速查：
  「data directory has files in it」 -> 已初始化过，直接 net start $ServiceName；要重建加 -Force
  「Can't find data directory」      -> my.ini 路径写错
  「Could not open required defaults file」 -> my.ini 实际是 my.ini.txt
  服务起不来                          -> Get-Content '$dataDir\*.err' -Tail 40
"@ -ForegroundColor Gray
