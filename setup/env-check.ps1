#Requires -Version 5.1
<#
    萌宠优选 · 宠物商城系统  交接包环境预检（只读）
    ------------------------------------------------------------------
    作用：探测当前 Windows 机器上的 JDK/Maven/MySQL/Redis/Node/端口/项目文件，
          输出机器事实与缺口，供 AI 或人类据此配置。
    用法：
      powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\env-check.ps1 -RootPassword '<MySQL root 密码>'
    输出：
      控制台 + setup\env-report.txt（UTF-8）
    说明：
      - 本脚本不修改任何数据库、文件或服务；
      - 未提供 -RootPassword 时跳过数据库连接检查；
      - 兼容 PS 5.1。
#>
[CmdletBinding()]
param(
    [string]$RootPassword = $env:MYSQL_ROOT_PASSWORD,
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Continue'
try { chcp 65001 | Out-Null } catch { }
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

if ($ProjectRoot) {
    $script:Root = (Resolve-Path $ProjectRoot).Path
} else {
    $script:Root = (Split-Path -Parent $PSScriptRoot)
}
$script:Lines = New-Object System.Collections.Generic.List[string]

function Add-Line {
    param([string]$Text = '')
    Write-Host $Text
    $script:Lines.Add($Text)
}
function Section {
    param([string]$Title)
    Add-Line ''
    Add-Line ('=' * 72)
    Add-Line $Title
    Add-Line ('=' * 72)
}
function Get-ExePath {
    param([string]$Name)
    $c = Get-Command $Name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}
function Get-VersionText {
    param([string]$Exe, [string[]]$Arguments)
    if (-not $Exe -or -not (Test-Path $Exe)) { return '' }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $Exe @Arguments 2>&1
        $text = ($out | ForEach-Object { "$_" }) -join "`n"
        return $text.Trim()
    } catch { return '' }
    finally { $ErrorActionPreference = $prev }
}
function Test-ListenPort {
    param([int]$Port)
    try {
        $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($conn) { return $true }
    } catch { }
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne(300)
        if ($ok -and $client.Connected) { $client.Close(); return $true }
        $client.Close()
    } catch { }
    return $false
}
function Find-ToolDirs {
    param([string]$ExeName, [string[]]$BaseDirs, [string]$Child)
    $found = New-Object System.Collections.Generic.List[string]
    foreach ($base in $BaseDirs) {
        if (-not $base -or -not (Test-Path $base)) { continue }
        $direct = Join-Path $base $Child
        if (Test-Path $direct) { $found.Add($direct) }
        try {
            Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $candidate = Join-Path $_.FullName $Child
                if (Test-Path $candidate) { $found.Add($candidate) }
            }
        } catch { }
    }
    return ($found | Select-Object -Unique)
}

# ============================ 基本信息 ============================
Section '0. 基本信息'
Add-Line ("采集时间        : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Add-Line ("计算机名        : {0}" -f $env:COMPUTERNAME)
Add-Line ("当前用户        : {0}" -f $env:USERNAME)
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os -and $os.Caption) { Add-Line ("操作系统        : {0} (Build {1})" -f $os.Caption, $os.BuildNumber) }
    else { Add-Line ("操作系统        : {0}" -f [System.Environment]::OSVersion.VersionString) }
} catch { Add-Line ("操作系统        : {0}" -f [System.Environment]::OSVersion.VersionString) }
Add-Line ("PowerShell      : {0}" -f $PSVersionTable.PSVersion)
Add-Line ("项目根目录      : {0}" -f $script:Root)

# ============================ JDK ============================
Section '1. JDK'
$jdkCandidates = New-Object System.Collections.Generic.List[string]
if ($env:JAVA_HOME) { $jdkCandidates.Add($env:JAVA_HOME) }
$javaCmd = Get-ExePath 'java.exe'
if ($javaCmd) { $jdkCandidates.Add((Split-Path -Parent (Split-Path -Parent $javaCmd))) }
$jdkBases = @("$env:USERPROFILE\.jdks", 'C:\Program Files\Java', 'C:\Program Files\Eclipse Adoptium',
              'C:\Program Files\Microsoft', 'C:\Program Files\Zulu', 'C:\dev', 'D:\dev')
foreach ($d in (Find-ToolDirs -ExeName 'java.exe' -BaseDirs $jdkBases -Child 'bin\java.exe')) {
    $jdkCandidates.Add((Split-Path -Parent (Split-Path -Parent $d)))
}
$jdkCandidates = @($jdkCandidates | Where-Object { $_ -and (Test-Path (Join-Path $_ 'bin\java.exe')) } | Select-Object -Unique)
$jdk17 = $null
if ($jdkCandidates.Count -eq 0) {
    Add-Line '[缺失] 未找到任何 JDK（java.exe）'
} else {
    foreach ($homeDir in $jdkCandidates) {
        $exe = Join-Path $homeDir 'bin\java.exe'
        $ver = Get-VersionText -Exe $exe -Arguments @('-version')
        $first = ($ver -split "`n")[0]
        $is17 = ($ver -match 'version\s+"17[\.\s"]')
        if ($is17 -and -not $jdk17) { $jdk17 = $homeDir }
        $mark = if ($is17) { '[OK]' } else { '[--]' }
        Add-Line ("{0} {1}" -f $mark, $homeDir)
        Add-Line ("     {0}" -f $first)
    }
}
Add-Line ("JAVA_HOME       : {0}" -f $(if ($env:JAVA_HOME) { $env:JAVA_HOME } else { '(未设置)' }))
if ($jdk17) { Add-Line ("推荐 JDK17      : {0}" -f $jdk17) } else { Add-Line '[缺失] 未找到 JDK 17，请先安装或指定已有 17 目录' }

# ============================ Maven ============================
Section '2. Maven'
$mvn = Get-ExePath 'mvn.cmd'
if (-not $mvn) { $mvn = Get-ExePath 'mvn' }
$mvnCandidates = New-Object System.Collections.Generic.List[string]
if ($mvn) { $mvnCandidates.Add($mvn) }
$mvnBases = @('C:\dev', 'C:\', 'D:\dev', 'D:\', 'C:\Program Files')
foreach ($p in (Find-ToolDirs -ExeName 'mvn.cmd' -BaseDirs $mvnBases -Child 'bin\mvn.cmd')) { $mvnCandidates.Add($p) }
$mvnCandidates = @($mvnCandidates | Select-Object -Unique)
if ($mvnCandidates.Count -eq 0) {
    Add-Line '[缺失] 未找到 Maven（mvn.cmd），需安装 3.9.x'
} else {
    foreach ($m in $mvnCandidates) {
        Add-Line ("[OK] {0}" -f $m)
        $mv = Get-VersionText -Exe $m -Arguments @('-v')
        ($mv -split "`n" | Select-Object -First 3) | ForEach-Object { Add-Line ("     {0}" -f $_) }
    }
}
Add-Line ("MAVEN_HOME      : {0}" -f $(if ($env:MAVEN_HOME) { $env:MAVEN_HOME } else { '(未设置)' }))

# ============================ MySQL ============================
Section '3. MySQL'
$mysql = Get-ExePath 'mysql.exe'
$mysqlCandidates = New-Object System.Collections.Generic.List[string]
if ($mysql) { $mysqlCandidates.Add($mysql) }
$mysqlBases = @('C:\Program Files\MySQL', 'C:\dev', 'D:\dev', 'C:\xampp\mysql',
                'C:\Program Files\MariaDB*', 'C:\Program Files')
foreach ($p in (Find-ToolDirs -ExeName 'mysql.exe' -BaseDirs $mysqlBases -Child 'bin\mysql.exe')) { $mysqlCandidates.Add($p) }
$mysqlCandidates = @($mysqlCandidates | Select-Object -Unique)
if ($mysqlCandidates.Count -eq 0) {
    Add-Line '[缺失] 未找到 mysql 客户端'
    $mysql = $null
} else {
    foreach ($m in $mysqlCandidates) { Add-Line ("[OK] {0}" -f $m) }
    $mysql = $mysqlCandidates[0]
    Add-Line ("mysql 客户端    : {0}" -f (Get-VersionText -Exe $mysql -Arguments @('--version')))
}
$svc = @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'mysql|maria' })
if ($svc.Count -eq 0) { Add-Line 'MySQL 服务       : (未发现 MySQL 服务)' }
else { $svc | ForEach-Object { Add-Line ("MySQL 服务       : {0} = {1}" -f $_.Name, $_.Status) } }
Add-Line ("端口 3306        : {0}" -f $(if (Test-ListenPort 3306) { 'LISTEN' } else { '未监听' }))

# 数据库连接检查
if (-not $RootPassword) {
    Add-Line '[跳过] 未提供 -RootPassword / MYSQL_ROOT_PASSWORD，无法检查数据库内容'
} elseif (-not $mysql) {
    Add-Line '[跳过] 无 mysql 客户端，无法检查数据库内容'
} else {
    $prevPwd = $env:MYSQL_PWD
    $env:MYSQL_PWD = $RootPassword
    try {
        $out = & $mysql -uroot --connect-timeout=5 -N -B -e "SELECT VERSION();" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Add-Line '[失败] MySQL root 连接失败，请检查密码/服务'
            ($out | Select-Object -First 3) | ForEach-Object { Add-Line ("     {0}" -f $_) }
        } else {
            Add-Line ("MySQL 版本      : {0}" -f (($out | Where-Object { $_ -match '^\d' }) -join ' '))
            $exists = & $mysql -uroot -N -B -e "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='shop';" 2>&1
            $exists = ($exists | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1)
            Add-Line ("shop 库存在     : {0}" -f $(if ($exists -eq '1') { '是' } else { '否' }))
            if ($exists -eq '1') {
                $total = & $mysql -uroot -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='shop';" 2>&1
                $total = ($total | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1)
                $pet = & $mysql -uroot -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='shop' AND LEFT(table_name,4)='pet_';" 2>&1
                $pet = ($pet | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1)
                Add-Line ("shop 表总数     : {0}" -f $total)
                Add-Line ("pet_* 表数      : {0}" -f $pet)
                if ($pet -and [int]$pet -gt 0) {
                    foreach ($t in @('pet_member','pet_item','pet_item_sku','pet_order')) {
                        $n = & $mysql -uroot -N -B -e "SELECT COUNT(*) FROM shop.$t;" 2>&1
                        $n = ($n | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1)
                        Add-Line ("  {0,-16}: {1} 行" -f $t, $n)
                    }
                }
            }
        }
    } finally {
        if ($null -eq $prevPwd) { Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue } else { $env:MYSQL_PWD = $prevPwd }
    }
}

# ============================ Redis ============================
Section '4. Redis'
$redisCli = Get-ExePath 'redis-cli.exe'
$redisCandidates = New-Object System.Collections.Generic.List[string]
if ($redisCli) { $redisCandidates.Add($redisCli) }
$redisBases = @('C:\Program Files\Redis', 'C:\Redis', 'C:\dev', 'D:\dev', 'C:\Program Files', 'D:\', (Join-Path $script:Root 'dev-redis'))
foreach ($p in (Find-ToolDirs -ExeName 'redis-cli.exe' -BaseDirs $redisBases -Child 'redis-cli.exe')) { $redisCandidates.Add($p) }
$redisCandidates = @($redisCandidates | Select-Object -Unique)
if ($redisCandidates.Count -gt 0) {
    $redisCli = $redisCandidates[0]
    Add-Line ("[OK] {0}" -f $redisCli)
    $ping = Get-VersionText -Exe $redisCli -Arguments @('-p', '6379', 'ping')
    if ($ping -match 'PONG') {
        Add-Line ("PING 6379       : PONG（Redis 正常）")
    } else {
        Add-Line ("PING 6379       : 未成功（{0}）" -f (($ping -split "`n" | Select-Object -First 1)))
        Add-Line ("端口 6379        : {0}" -f $(if (Test-ListenPort 6379) { 'LISTEN（端口已监听，Redis 可能正常）' } else { '未监听' }))
    }
} else {
    Add-Line 'redis-cli       : (未找到，改用端口探测)'
    Add-Line ("端口 6379        : {0}" -f $(if (Test-ListenPort 6379) { 'LISTEN' } else { '未监听' }))
}

# ============================ Node / Git ============================
Section '5. Node.js / Git'
$node = Get-ExePath 'node.exe'
$npm = Get-ExePath 'npm.cmd'
if (-not $npm) { $npm = Get-ExePath 'npm' }
Add-Line ("node            : {0}" -f $(if ($node) { (Get-VersionText -Exe $node -Arguments @('-v')) } else { '(未找到)' }))
Add-Line ("npm             : {0}" -f $(if ($npm) { (Get-VersionText -Exe $npm -Arguments @('-v')) } else { '(未找到)' }))
$git = Get-ExePath 'git.exe'
Add-Line ("git             : {0}" -f $(if ($git) { (Get-VersionText -Exe $git -Arguments @('--version')) } else { '(未找到)' }))

# ============================ 端口 ============================
Section '6. 关键端口'
foreach ($port in @(3306, 6379, 8080, 80, 81)) {
    Add-Line ("{0,-5} : {1}" -f $port, $(if (Test-ListenPort $port) { 'LISTEN（被占用）' } else { '空闲/未监听' }))
}

# ============================ 项目文件 ============================
Section '7. 项目文件检查'
$backend = Join-Path $script:Root 'backend'
if (-not (Test-Path (Join-Path $backend 'pom.xml'))) {
    $legacy = Join-Path $script:Root 'shop\RuoYi-Vue-master'
    if (Test-Path (Join-Path $legacy 'pom.xml')) { $backend = $legacy }
}
$adminUi = Join-Path $script:Root 'admin-ui'
if (-not (Test-Path (Join-Path $adminUi 'package.json'))) {
    $legacy = Join-Path $script:Root 'shop\RuoYi-Vue3-master'
    if (Test-Path (Join-Path $legacy 'package.json')) { $adminUi = $legacy }
}
$checks = @(
    @('后端 pom.xml', (Join-Path $backend 'pom.xml')),
    @('后端启动类', (Join-Path $backend 'ruoyi-admin\src\main\java\com\ruoyi\RuoYiApplication.java')),
    @('数据源配置', (Join-Path $backend 'ruoyi-admin\src\main\resources\application-druid.yml')),
    @('管理前端 package.json', (Join-Path $adminUi 'package.json')),
    @('db/01_base.sql', (Join-Path $script:Root 'db\01_base.sql')),
    @('db/02_pet_mall.sql', (Join-Path $script:Root 'db\02_pet_mall.sql')),
    @('db/03_seed.sql', (Join-Path $script:Root 'db\03_seed.sql')),
    @('db/verify.sql', (Join-Path $script:Root 'db\verify.sql')),
    @('交接说明文档', (Join-Path $script:Root 'docs\02-设计文档\后端开发交接说明_v1.0.md'))
)
foreach ($c in $checks) {
    Add-Line ("{0} {1}" -f $(if (Test-Path $c[1]) { '[OK]' } else { '[缺失]' }), $c[0])
}
Add-Line ("后端目录        : {0}" -f $backend)
Add-Line ("管理前端目录    : {0}" -f $adminUi)

# ============================ 总结 ============================
Section '8. 总结与建议'
$issues = New-Object System.Collections.Generic.List[string]
if (-not $jdk17) { $issues.Add('未找到 JDK 17：安装 Temurin/Microsoft OpenJDK 17，或指定已有 17 目录') }
if ($mvnCandidates.Count -eq 0) { $issues.Add('未找到 Maven：安装 3.9.x 并配置 Path（或用 IDEA 内置 Maven 先跑，但交付需 CLI 可构建）') }
if (-not $mysql) { $issues.Add('未找到 mysql 客户端：安装 MySQL 8.0 或把 bin 加入 Path') }
if (-not (Test-ListenPort 3306)) { $issues.Add('3306 未监听：启动 MySQL 服务') }
if (-not (Test-ListenPort 6379)) { $issues.Add('6379 未监听：启动 Redis（否则后端登录/Token 会失败）') }
if (-not $node) { $issues.Add('未找到 Node.js：安装 Node 18+（建议 20/24）') }
if (-not (Test-Path (Join-Path $backend 'pom.xml'))) { $issues.Add('未找到后端源码：确认解压目录结构包含 backend/pom.xml') }

if ($issues.Count -eq 0) {
    Add-Line '未发现阻塞项，可以按 00-START-HERE-AI-环境配置说明.md 继续。'
} else {
    Add-Line '发现以下待处理项：'
    $i = 0
    foreach ($it in $issues) { $i++; Add-Line ("  {0}. {1}" -f $i, $it) }
}

# ============================ 写报告 ============================
$reportFile = Join-Path $PSScriptRoot 'env-report.txt'
try {
    [System.IO.File]::WriteAllLines($reportFile, $script:Lines, (New-Object System.Text.UTF8Encoding($true)))
    Write-Host ''
    Write-Host ("报告已保存：{0}" -f $reportFile) -ForegroundColor Green
} catch {
    Write-Host ("报告写入失败：{0}" -f $_) -ForegroundColor Red
}

if ($jdk17 -and $mysql -and (Test-Path (Join-Path $backend 'pom.xml'))) { exit 0 } else { exit 1 }
