#Requires -Version 5.1
<#
    萌宠优选 · 后端运行环境预检（只读）
    ------------------------------------------------------------------
    用法：
      powershell -ExecutionPolicy Bypass -File .\setup\env-check.ps1
      powershell -ExecutionPolicy Bypass -File .\setup\env-check.ps1 -RootPassword '<MySQL密码>'
    输出：控制台 + setup\env-report.txt
    说明：不修改数据库、文件或服务；未提供密码时跳过数据库连接检查。
#>
[CmdletBinding()]
param(
    [string]$RootPassword,
    [string]$MySqlExe
)

. (Join-Path $PSScriptRoot 'common.ps1')
$Root = Get-PetMallRoot
$Config = Get-PetMallConfig -Root $Root
$lines = New-Object System.Collections.Generic.List[string]
$issues = New-Object System.Collections.Generic.List[string]

function Add-Line {
    param([string]$Text = '')
    Write-Host $Text
    $lines.Add($Text)
}
function Add-Section { param([string]$Text) Add-Line ''; Add-Line ('=' * 72); Add-Line $Text; Add-Line ('=' * 72) }
function Add-Item { param([string]$Name, [string]$Value) Add-Line ("{0,-22}: {1}" -f $Name, $Value) }

Add-Section '0. 基本信息'
Add-Item '采集时间' (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Add-Item '计算机名' $env:COMPUTERNAME
Add-Item '包根目录' $Root

Add-Section '1. JDK'
$java = Resolve-Java -Root $Root -Config $Config
if ($java) {
    Add-Item 'JDK 路径' $java.Home
    Add-Item 'Java 版本' (($java.Version -split "`n")[0])
} else {
    Add-Item 'JDK' '未找到 17+'
    $issues.Add('未找到 JDK 17+：安装 JDK 17/21，并在 config\backend.env 设置 JAVA_HOME。')
}

Add-Section '2. Maven（源码构建才需要）'
$mvn = Resolve-Maven -Config $Config
if ($mvn) { Add-Item 'mvn' $mvn } else { Add-Item 'mvn' '未找到（已有 dist\ruoyi-admin.jar 时不影响运行）' }

Add-Section '3. MySQL'
$mysql = Resolve-MySql -Config $Config -ExplicitPath $MySqlExe
if ($mysql) { Add-Item 'mysql.exe' $mysql } else { Add-Item 'mysql.exe' '未找到'; $issues.Add('未找到 mysql.exe：安装 MySQL 8.0，或设置 MYSQL_HOME/MYSQL_EXE。') }
$dbHost = Get-ConfigValue $Config 'DB_HOST' '127.0.0.1'
$dbPort = [int](Get-ConfigValue $Config 'DB_PORT' '3306')
Add-Item '连接地址' "$dbHost`:$dbPort"
if (Test-TcpPort -HostName $dbHost -Port $dbPort) { Add-Item ([string]$dbPort) 'LISTEN' } else { Add-Item ([string]$dbPort) '未监听'; $issues.Add('MySQL 端口未监听：启动 MySQL80 服务。') }

$pwdToUse = if ($RootPassword) { $RootPassword } else { Get-ConfigValue $Config 'DB_PASSWORD' '' }
if ($mysql -and $pwdToUse -and $pwdToUse -ne 'CHANGE_ME') {
    $cnf = Join-Path $env:TEMP ("petmall_env_{0}.cnf" -f [guid]::NewGuid().ToString('N'))
    try {
        New-MySqlOptionFile -Path $cnf -User (Get-ConfigValue $Config 'DB_USERNAME' 'root') -Password $pwdToUse -HostName $dbHost -Port $dbPort
        $r = Invoke-MySqlScalar -MySqlExe $mysql -OptionFile $cnf -Sql "SELECT VERSION(); SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='shop'; SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='shop' AND LEFT(table_name,4)='pet_';"
        if ($r.Code -eq 0) {
            $vals = @($r.Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            Add-Item 'MySQL 版本' $vals[0]
            Add-Item 'shop 表数' $(if ($vals.Count -gt 1) { $vals[1] } else { '0（库可能未初始化）' })
            Add-Item 'pet_* 表数' $(if ($vals.Count -gt 2) { $vals[2] } else { '0' })
        } else {
            Add-Item '数据库连接' "失败：$($r.Text)"
            $issues.Add('MySQL 连接失败：检查 config\backend.env 的 DB_PASSWORD。')
        }
    } finally { Remove-Item -LiteralPath $cnf -Force -ErrorAction SilentlyContinue }
} else {
    Add-Item '数据库连接' '跳过（未提供密码）'
}

Add-Section '4. Redis'
$redisHost = Get-ConfigValue $Config 'REDIS_HOST' '127.0.0.1'
$redisPort = [int](Get-ConfigValue $Config 'REDIS_PORT' '6379')
$redisPwd = Get-ConfigValue $Config 'REDIS_PASSWORD' ''
$redisDb = [int](Get-ConfigValue $Config 'REDIS_DATABASE' '0')
if (Test-TcpPort -HostName $redisHost -Port $redisPort) {
    try {
        $pong = Invoke-RedisCommand -HostName $redisHost -Port $redisPort -Password $redisPwd -Database $redisDb -Command @('PING')
        Add-Item 'PING' $pong
        if ($pong -ne 'PONG') { $issues.Add('Redis PING 返回异常：检查 REDIS_PASSWORD。') }
    } catch {
        Add-Item 'PING' "失败：$($_.Exception.Message)"
        $issues.Add('Redis 连接失败：检查 REDIS_PASSWORD 或 Redis 服务。')
    }
} else {
    Add-Item ([string]$redisPort) '未监听'
    $issues.Add('Redis 端口未监听：启动 Redis 7（登录/Token 依赖）。')
}

Add-Section '5. 端口'
foreach ($port in @(8080, 3306, 6379)) {
    Add-Item ([string]$port) $(if (Test-TcpPort -Port $port) { 'LISTEN' } else { '空闲/未监听' })
}

Add-Section '6. 包内文件'
$checks = @(
    @('dist\ruoyi-admin.jar', (Join-Path $Root 'dist\ruoyi-admin.jar')),
    @('backend\pom.xml', (Join-Path $Root 'backend\pom.xml')),
    @('db\01_base.sql', (Join-Path $Root 'db\01_base.sql')),
    @('db\02_pet_mall.sql', (Join-Path $Root 'db\02_pet_mall.sql')),
    @('db\03_seed.sql', (Join-Path $Root 'db\03_seed.sql')),
    @('db\verify.sql', (Join-Path $Root 'db\verify.sql')),
    @('config\backend.env', (Join-Path $Root 'config\backend.env'))
)
foreach ($c in $checks) {
    $ok = Test-Path -LiteralPath $c[1]
    Add-Item $c[0] $(if ($ok) { 'OK' } else { '缺失' })
    if (-not $ok -and $c[0] -ne 'config\backend.env') { $issues.Add("缺少文件：$($c[0])") }
}
$jar = Join-Path $Root 'dist\ruoyi-admin.jar'
if (Test-Path -LiteralPath $jar) {
    $size = [math]::Round((Get-Item -LiteralPath $jar).Length / 1MB, 1)
    Add-Item 'JAR 大小' "$size MB"
}

Add-Section '7. 总结'
if ($issues.Count -eq 0) {
    Add-Line '未发现阻塞项。下一步：'
    Add-Line '  1) powershell -ExecutionPolicy Bypass -File .\setup\init-db.ps1'
    Add-Line '  2) start-backend.bat'
} else {
    Add-Line '待处理项：'
    $i = 0
    foreach ($it in $issues) { $i++; Add-Line ("  {0}. {1}" -f $i, $it) }
}

$report = Join-Path $PSScriptRoot 'env-report.txt'
try {
    [System.IO.File]::WriteAllLines($report, $lines, (New-Object System.Text.UTF8Encoding($true)))
    Write-Host ''
    Write-Host "报告已保存：$report" -ForegroundColor Green
} catch { Write-Host "报告写入失败：$($_.Exception.Message)" -ForegroundColor Red }

if ($java -and $mysql -and (Test-TcpPort -HostName $dbHost -Port $dbPort) -and (Test-TcpPort -HostName $redisHost -Port $redisPort)) { exit 0 } else { exit 1 }
