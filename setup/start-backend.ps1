#Requires -Version 5.1
<#
    萌宠优选 · 启动后端
    ------------------------------------------------------------------
    优先运行 dist\ruoyi-admin.jar；没有 jar 时自动用 Maven 构建源码。
    配置来自 config\backend.env，数据库密码为空/CHANGE_ME 时会提示输入。
    常用：
      powershell -ExecutionPolicy Bypass -File .\setup\start-backend.ps1
      powershell -ExecutionPolicy Bypass -File .\setup\start-backend.ps1 -Port 8081
      powershell -ExecutionPolicy Bypass -File .\setup\start-backend.ps1 -SkipBuild
      powershell -ExecutionPolicy Bypass -File .\setup\start-backend.ps1 -Foreground
#>
[CmdletBinding()]
param(
    [int]$Port = 0,
    [string]$MySqlPassword,
    [switch]$SkipBuild,
    [switch]$Rebuild,
    [switch]$Foreground,
    [switch]$NoWait
)

. (Join-Path $PSScriptRoot 'common.ps1')
$Root = Get-PetMallRoot
$Config = Get-PetMallConfig -Root $Root
if ($Port -le 0) { $Port = [int](Get-ConfigValue $Config 'SERVER_PORT' '8080') }
$DbPassword = if ($MySqlPassword) { $MySqlPassword } else { Get-ConfigValue $Config 'DB_PASSWORD' '' }
if (-not $DbPassword -or $DbPassword -eq 'CHANGE_ME') {
    $sec = Read-Host "请输入 MySQL root 密码（用户 $(Get-ConfigValue $Config 'DB_USERNAME' 'root')）" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { $DbPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$java = Resolve-Java -Root $Root -Config $Config
if (-not $java) {
    Write-Bad '未找到 JDK 17 或更高版本。'
    Write-Info '请安装 JDK 17/21，并在 config\backend.env 设置 JAVA_HOME（JDK 根目录）。'
    exit 1
}
Write-Ok "JDK：$($java.Home)"
Write-Info $java.Version.Split("`n")[0]

$jarCandidates = @(
    (Join-Path $Root 'dist\ruoyi-admin.jar'),
    (Join-Path $Root 'backend\ruoyi-admin\target\ruoyi-admin.jar')
)
$jar = $jarCandidates | Where-Object { Test-Path -LiteralPath $_ } | Sort-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc } -Descending | Select-Object -First 1
if ($jar) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = $null
    try {
        $archive = [IO.Compression.ZipFile]::OpenRead($jar)
        if (-not $archive.GetEntry('BOOT-INF/classes/application.yml')) { $Rebuild = $true }
    } catch { $Rebuild = $true }
    finally { if ($archive) { $archive.Dispose() } }
}
if (-not $SkipBuild -and $jar -and (Test-Path -LiteralPath (Join-Path $Root 'backend\pom.xml'))) {
    $jarTime = (Get-Item -LiteralPath $jar).LastWriteTimeUtc
    $newerSource = Get-ChildItem -LiteralPath (Join-Path $Root 'backend') -Recurse -File -Include *.java,*.xml,*.yml,*.properties |
        Where-Object { $_.FullName -notmatch '\\target\\' -and $_.LastWriteTimeUtc -gt $jarTime } | Select-Object -First 1
    if ($newerSource) { $Rebuild = $true }
}
if (-not $jar -or $Rebuild) {
    if ($SkipBuild) {
        Write-Bad '未找到 ruoyi-admin.jar，且指定了 -SkipBuild。'
        exit 1
    }
    $mvn = Resolve-Maven -Config $Config
    if (-not $mvn) {
        Write-Bad '未找到 Maven，无法从源码构建。'
        Write-Info '请安装 Maven 3.9+，或把已构建好的 ruoyi-admin.jar 放到 dist\ 目录。'
        exit 1
    }
    Write-Step "从源码构建（$mvn）"
    # Windows locks a running executable JAR; stop only this project's recorded process first.
    if (Test-Path -LiteralPath (Join-Path $Root 'run\backend.pid')) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'stop-backend.ps1') -Port $Port
        if ($LASTEXITCODE -ne 0) { exit 1 }
    }
    $oldJavaHome = $env:JAVA_HOME
    $env:JAVA_HOME = $java.Home
    Push-Location (Join-Path $Root 'backend')
    try {
        & $mvn -pl ruoyi-admin -am -DskipTests package
        $buildCode = $LASTEXITCODE
    } finally {
        Pop-Location
        if ($oldJavaHome) { $env:JAVA_HOME = $oldJavaHome } else { Remove-Item Env:JAVA_HOME -ErrorAction SilentlyContinue }
    }
    if ($buildCode -ne 0) { Write-Bad "Maven 构建失败（exit=$buildCode）。"; exit 1 }
    $jar = $jarCandidates | Where-Object { Test-Path -LiteralPath $_ } | Sort-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc } -Descending | Select-Object -First 1
    if (-not $jar) { Write-Bad '构建完成但未找到 ruoyi-admin.jar。'; exit 1 }
}
$jar = (Resolve-Path -LiteralPath $jar).Path

$runDir = Join-Path $Root 'run'
$logDir = Resolve-FullPath $Root (Get-ConfigValue $Config 'LOG_PATH' 'logs')
$uploadDir = Resolve-FullPath $Root (Get-ConfigValue $Config 'RUOYI_PROFILE' 'data/uploadPath')
New-Item -ItemType Directory -Path $runDir, $logDir, $uploadDir -Force | Out-Null
$pidFile = Join-Path $runDir 'backend.pid'
$portFile = Join-Path $runDir 'backend.port'

if (Test-Path -LiteralPath $pidFile) {
    $oldPid = 0
    [void][int]::TryParse((Get-Content -LiteralPath $pidFile -Raw).Trim(), [ref]$oldPid)
    if ($oldPid -gt 0) {
        $old = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if ($old) {
            $oldCommand = (Get-CimInstance Win32_Process -Filter "ProcessId=$oldPid" -ErrorAction SilentlyContinue).CommandLine
            if ($oldCommand -match 'ruoyi-admin\.jar') {
                if ($Rebuild -or $old.StartTime.ToUniversalTime() -lt (Get-Item -LiteralPath $jar).LastWriteTimeUtc) {
                    Write-Step '检测到新构建，重启本项目后端'
                    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'stop-backend.ps1') -Port $Port
                    if ($LASTEXITCODE -ne 0) { exit 1 }
                } else {
                Write-Warn "后端已在运行（PID=$oldPid）。如需重启，先运行 stop-backend.bat。"
                exit 0
                }
            }
        }
    }
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}
if (Test-TcpPort -Port $Port) {
    Write-Bad "端口 $Port 已被占用，无法启动。"
    Write-Info '可换端口：-Port 8081，或先关闭占用进程。'
    exit 1
}

$env:SERVER_PORT = [string]$Port
$env:DB_HOST = Get-ConfigValue $Config 'DB_HOST' '127.0.0.1'
$env:DB_PORT = Get-ConfigValue $Config 'DB_PORT' '3306'
$env:DB_NAME = Get-ConfigValue $Config 'DB_NAME' 'shop'
$env:DB_USERNAME = Get-ConfigValue $Config 'DB_USERNAME' 'root'
$env:DB_PASSWORD = $DbPassword
$env:DB_USE_SSL = Get-ConfigValue $Config 'DB_USE_SSL' 'false'
$env:DB_ALLOW_PUBLIC_KEY_RETRIEVAL = Get-ConfigValue $Config 'DB_ALLOW_PUBLIC_KEY_RETRIEVAL' 'true'
$env:REDIS_HOST = Get-ConfigValue $Config 'REDIS_HOST' '127.0.0.1'
$env:REDIS_PORT = Get-ConfigValue $Config 'REDIS_PORT' '6379'
$env:REDIS_DATABASE = Get-ConfigValue $Config 'REDIS_DATABASE' '0'
$env:REDIS_PASSWORD = Get-ConfigValue $Config 'REDIS_PASSWORD' ''
$env:RUOYI_PROFILE = $uploadDir
$env:LOG_PATH = $logDir
$env:LOG_LEVEL = Get-ConfigValue $Config 'LOG_LEVEL' 'info'
$env:DEVTOOLS_RESTART = Get-ConfigValue $Config 'DEVTOOLS_RESTART' 'false'
$env:TOKEN_SECRET = Get-ConfigValue $Config 'TOKEN_SECRET' 'petmall-dev-token-secret-change-me'
$env:DRUID_USERNAME = Get-ConfigValue $Config 'DRUID_USERNAME' 'ruoyi'
$env:DRUID_PASSWORD = Get-ConfigValue $Config 'DRUID_PASSWORD' '123456'

$javaArgs = @(
    '-Dfile.encoding=UTF-8', '-Duser.timezone=Asia/Shanghai',
    '-Xms256m', '-Xmx1024m', '-jar', "`"$jar`"", "--server.port=$Port"
)
if ($Foreground) {
    Write-Step "前台启动：http://127.0.0.1:$Port"
    Push-Location $Root
    try { & $java.Path @javaArgs } finally { Pop-Location }
    exit $LASTEXITCODE
}

$outLog = Join-Path $logDir 'console.log'
$errLog = Join-Path $logDir 'console.err.log'
Write-Step "启动后端（端口 $Port）"
$p = Start-Process -FilePath $java.Path -ArgumentList $javaArgs -WorkingDirectory $Root `
    -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru -WindowStyle Hidden
$p.Id | Set-Content -LiteralPath $pidFile -Encoding ASCII
$Port | Set-Content -LiteralPath $portFile -Encoding ASCII
Write-Info "PID=$($p.Id)，日志：$outLog"

if ($NoWait) {
    Write-Ok '已启动（未等待就绪）。'
    exit 0
}

$ready = $false
$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
for ($i = 0; $i -lt 120; $i++) {
    Start-Sleep -Seconds 1
    if ($p.HasExited) { break }
    if (-not (Test-TcpPort -Port $Port -TimeoutMs 300)) { continue }
    if ($curl) {
        $code = (& $curl.Source -sS --noproxy '*' --max-time 3 -o NUL -w '%{http_code}' "http://127.0.0.1:$Port/api/health" 2>$null) -join ''
        if ($code.Trim() -eq '200') { $ready = $true; break }
    } else {
        try {
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/api/health" -TimeoutSec 3
            if ($health.code -eq 200) { $ready = $true; break }
        } catch { }
    }
}

if (-not $ready) {
    Write-Bad '后端启动失败或 120 秒内未就绪。'
    if (Test-Path -LiteralPath $outLog) {
        Write-Step 'console.log 最后 30 行'
        Get-Content -LiteralPath $outLog -Tail 30 -Encoding UTF8 | ForEach-Object { Write-Host $_ }
    }
    if (Test-Path -LiteralPath $errLog) {
        $errText = Get-Content -LiteralPath $errLog -Tail 20 -Encoding UTF8
        if ($errText) { Write-Step 'console.err.log'; $errText | ForEach-Object { Write-Host $_ } }
    }
    Write-Info '排查后重试；停止进程：stop-backend.bat'
    exit 1
}

Write-Ok "后端已就绪：http://127.0.0.1:$Port"
Write-Info "Swagger：http://127.0.0.1:$Port/swagger-ui.html"
Write-Info '账号：admin/admin123、merchant1/merchant123、reviewer/reviewer123、member1/member123'
Write-Info '验收：powershell -ExecutionPolicy Bypass -File .\setup\smoke-test.ps1'
exit 0

Write-Ok "JAR：$jar"
