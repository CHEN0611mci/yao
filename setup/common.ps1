#Requires -Version 5.1
<#
    萌宠优选 · 后端交接包公共函数
    - 由 setup 下的脚本 dot-source 使用，不单独执行
    - 兼容 Windows PowerShell 5.1
#>
$ErrorActionPreference = 'Continue'
try { chcp 65001 | Out-Null } catch { }
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

function Get-PetMallRoot { return (Split-Path -Parent $PSScriptRoot) }
function Write-Step { param([string]$Text) Write-Host "`n== $Text ==" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Text) Write-Host "[ OK ] $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "[WARN] $Text" -ForegroundColor Yellow }
function Write-Bad  { param([string]$Text) Write-Host "[FAIL] $Text" -ForegroundColor Red }
function Write-Info { param([string]$Text) Write-Host "       $Text" }

function Read-EnvFile {
    param([string]$Path)
    $map = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $map }
    foreach ($line in [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)) {
        $t = $line.Trim()
        if ($t.Length -eq 0 -or $t.StartsWith('#')) { continue }
        $i = $t.IndexOf('=')
        if ($i -lt 1) { continue }
        $k = $t.Substring(0, $i).Trim()
        $v = $t.Substring($i + 1).Trim()
        if ($v.Length -ge 2) {
            if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
                $v = $v.Substring(1, $v.Length - 2)
            }
        }
        $map[$k] = $v
    }
    return $map
}

function Get-PetMallConfig {
    param([string]$Root = (Get-PetMallRoot))
    $file = Join-Path $Root 'config\backend.env'
    $example = Join-Path $Root 'config\backend.env.example'
    if (-not (Test-Path -LiteralPath $file) -and (Test-Path -LiteralPath $example)) {
        Copy-Item -LiteralPath $example -Destination $file -Force
        Write-Warn '已从 backend.env.example 生成 config\backend.env，请填写数据库密码。'
    }
    return (Read-EnvFile -Path $file)
}

function Get-ConfigValue {
    param($Config, [string]$Key, [string]$Default = '')
    if ($null -ne $Config -and $Config.ContainsKey($Key)) {
        $v = [string]$Config[$Key]
        if ($v.Length -gt 0) { return $v }
    }
    return $Default
}

function Resolve-FullPath {
    param([string]$Root, [string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Test-TcpPort {
    param([string]$HostName = '127.0.0.1', [int]$Port, [int]$TimeoutMs = 500)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
        $client.EndConnect($iar)
        return $true
    } catch { return $false }
    finally { try { $client.Close() } catch { } }
}

function Get-JavaVersion {
    param([string]$JavaExe)
    if (-not $JavaExe -or -not (Test-Path -LiteralPath $JavaExe)) { return $null }
    $out = & $JavaExe -version 2>&1
    $text = ($out | ForEach-Object { "$_" }) -join "`n"
    if ($text -match 'version\s+"(\d+)(?:\.(\d+))?') {
        return [pscustomobject]@{ Major = [int]$matches[1]; Minor = [int]$matches[2]; Text = $text.Trim() }
    }
    return $null
}

function Resolve-Java {
    param([string]$Root = (Get-PetMallRoot), $Config = $null)
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($h in @((Get-ConfigValue $Config 'JAVA_HOME' ''), $env:JAVA_HOME)) {
        if ($h) {
            $j = Join-Path $h.Trim('"').Trim() 'bin\java.exe'
            if (Test-Path -LiteralPath $j) { $candidates.Add($j) }
        }
    }
    $cmd = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($cmd) { $candidates.Add($cmd.Source) }
    $searchRoots = @(
        (Join-Path $env:USERPROFILE '.jdks'), 'C:\Program Files\Java',
        'C:\Program Files\Eclipse Adoptium', 'C:\Program Files\Microsoft',
        'C:\Program Files\Zulu', 'D:\Java'
    )
    foreach ($base in $searchRoots) {
        if (-not (Test-Path -LiteralPath $base)) { continue }
        try {
            Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $j = Join-Path $_.FullName 'bin\java.exe'
                if (Test-Path -LiteralPath $j) { $candidates.Add($j) }
            }
        } catch { }
    }
    $valid = @()
    foreach ($j in ($candidates | Select-Object -Unique)) {
        $v = Get-JavaVersion -JavaExe $j
        if ($v) {
            $valid += [pscustomobject]@{
                Path = $j; Home = (Split-Path -Parent (Split-Path -Parent $j))
                Major = $v.Major; Version = $v.Text
            }
        }
    }
    $good = @($valid | Where-Object { $_.Major -ge 17 } | Sort-Object Major, Path)
    if ($good.Count -eq 0) { return $null }
    return $good[0]
}

function Resolve-Maven {
    param($Config = $null)
    $cmd = Get-Command mvn.cmd -ErrorAction SilentlyContinue
    if (-not $cmd) { $cmd = Get-Command mvn -ErrorAction SilentlyContinue }
    if ($cmd) { return $cmd.Source }
    $homes = @(
        (Get-ConfigValue $Config 'MAVEN_HOME' ''), $env:MAVEN_HOME,
        'C:\Program Files\Apache\maven', 'C:\dev\apache-maven-3.9.9', 'D:\dev\apache-maven-3.9.9'
    )
    foreach ($h in $homes) {
        if ($h) {
            $m = Join-Path $h 'bin\mvn.cmd'
            if (Test-Path -LiteralPath $m) { return $m }
        }
    }
    $ideaRoot = 'C:\Program Files\JetBrains'
    if (Test-Path -LiteralPath $ideaRoot) {
        try {
            $m = Get-ChildItem -LiteralPath $ideaRoot -Directory -ErrorAction SilentlyContinue |
                ForEach-Object { Join-Path $_.FullName 'plugins\maven-plugin\lib\maven3\bin\mvn.cmd' } |
                Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            if ($m) { return $m }
        } catch { }
    }
    return $null
}

function Resolve-MySql {
    param($Config = $null, [string]$ExplicitPath = '')
    if ($ExplicitPath -and (Test-Path -LiteralPath $ExplicitPath)) { return (Resolve-Path -LiteralPath $ExplicitPath).Path }
    $explicit = Get-ConfigValue $Config 'MYSQL_EXE' ''
    if ($explicit -and (Test-Path -LiteralPath $explicit)) { return (Resolve-Path -LiteralPath $explicit).Path }
    $cmd = Get-Command mysql.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $homes = @(
        (Get-ConfigValue $Config 'MYSQL_HOME' ''),
        'C:\Program Files\MySQL\MySQL Server 8.0', 'C:\Program Files\MySQL\MySQL Server 8.4',
        'C:\Program Files (x86)\MySQL\MySQL Server 8.0', 'C:\xampp\mysql', 'D:\xampp\mysql',
        'C:\dev\mysql-8.0.46-winx64', 'D:\dev\mysql-8.0.46-winx64'
    )
    foreach ($h in $homes) {
        if ($h) {
            $m = Join-Path $h 'bin\mysql.exe'
            if (Test-Path -LiteralPath $m) { return $m }
        }
    }
    $bases = @('C:\dev', 'D:\dev', 'C:\Program Files\MySQL', 'D:\Program Files\MySQL')
    $pkgRoot = Get-PetMallRoot
    $bases += @($pkgRoot, (Split-Path -Parent $pkgRoot))
    foreach ($base in $bases) {
        if (-not (Test-Path -LiteralPath $base)) { continue }
        try {
            $m = Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like 'mysql*' } |
                ForEach-Object { Join-Path $_.FullName 'bin\mysql.exe' } |
                Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            if ($m) { return $m }
        } catch { }
    }
    return $null
}

function New-MySqlOptionFile {
    param([string]$Path, [string]$User, [string]$Password, [string]$HostName, [int]$Port)
    if ($Password -match "[`r`n]") { throw 'MySQL 密码不能包含换行符。' }
    $escaped = $Password.Replace('\', '\\').Replace('"', '\"')
    $lines = @('[client]', "user=$User", "password=`"$escaped`"", "host=$HostName", "port=$Port", 'default-character-set=utf8mb4')
    [System.IO.File]::WriteAllLines($Path, $lines, [System.Text.Encoding]::ASCII)
}

function Invoke-MySqlScalar {
    param([string]$MySqlExe, [string]$OptionFile, [string]$Sql, [string]$Database = '')
    $args = @("--defaults-extra-file=$OptionFile", '--default-character-set=utf8mb4', '-N', '-B')
    if ($Database) { $args += "--database=$Database" }
    $args += @('-e', $Sql)
    $out = & $MySqlExe @args 2>&1
    $code = $LASTEXITCODE
    $text = (($out | ForEach-Object { "$_" }) -join "`n").Trim()
    return [pscustomobject]@{ Code = $code; Text = $text }
}


function Invoke-MySqlFile {
    param([string]$MySqlExe, [string]$OptionFile, [string]$File, [string]$Database = '')
    if (-not (Test-Path -LiteralPath $File)) {
        return [pscustomobject]@{ Code = 1; Output = @("脚本不存在：$File") }
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $MySqlExe
    $psi.Arguments = "--defaults-extra-file=`"$OptionFile`" --default-character-set=utf8mb4"
    if ($Database) { $psi.Arguments += " --database=$Database" }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $writer = New-Object System.IO.StreamWriter($p.StandardInput.BaseStream, (New-Object System.Text.UTF8Encoding($false)))
    try {
        $writer.Write([System.IO.File]::ReadAllText($File, [System.Text.Encoding]::UTF8))
    } finally {
        $writer.Close()
    }
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $lines = @()
    foreach ($chunk in @($stdout, $stderr)) {
        if ($chunk) { $lines += ($chunk -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 }) }
    }
    return [pscustomobject]@{ Code = $p.ExitCode; Output = $lines }
}

function Invoke-MySqlDump {
    param([string]$MySqlExe, [string]$OptionFile, [string]$Database, [string]$OutFile)
    $dump = Join-Path (Split-Path -Parent $MySqlExe) 'mysqldump.exe'
    if (-not (Test-Path -LiteralPath $dump)) { throw "未找到 mysqldump.exe：$dump" }
    $errFile = "$OutFile.err"
    $p = Start-Process -FilePath $dump -ArgumentList @(
        "--defaults-extra-file=`"$OptionFile`"", '--default-character-set=utf8mb4',
        '--single-transaction', '--routines', '--triggers', '--databases', $Database
    ) -RedirectStandardOutput $OutFile -RedirectStandardError $errFile -PassThru -WindowStyle Hidden -Wait
    $err = ''
    if (Test-Path -LiteralPath $errFile) {
        $err = ([System.IO.File]::ReadAllText($errFile, [System.Text.Encoding]::UTF8)).Trim()
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
    return [pscustomobject]@{ Code = $p.ExitCode; Error = $err }
}


function Read-RedisReply {
    param([System.IO.StreamReader]$Reader)
    $line = $Reader.ReadLine()
    if ($null -eq $line) { throw 'Redis 连接已关闭。' }
    if ($line.Length -eq 0) { return '' }
    $type = $line.Substring(0, 1)
    $rest = $line.Substring(1)
    switch ($type) {
        '+' { return $rest }
        '-' { throw "Redis 错误：$rest" }
        ':' { return [int]$rest }
        '$' {
            $len = [int]$rest
            if ($len -lt 0) { return $null }
            $buf = New-Object char[] $len
            $read = 0
            while ($read -lt $len) {
                $n = $Reader.Read($buf, $read, $len - $read)
                if ($n -le 0) { break }
                $read += $n
            }
            [void]$Reader.ReadLine()
            return (-join $buf).TrimEnd([char]0)
        }
        '*' {
            $count = [int]$rest
            if ($count -lt 0) { return $null }
            $arr = @()
            for ($i = 0; $i -lt $count; $i++) { $arr += ,(Read-RedisReply -Reader $Reader) }
            return $arr
        }
        default { return $line }
    }
}

function Invoke-RedisCommand {
    param(
        [string]$HostName = '127.0.0.1', [int]$Port = 6379,
        [string]$Password = '', [string[]]$Command = @('PING'), [int]$TimeoutMs = 2000,
        [int]$Database = -1
    )
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs)) { throw "Redis 连接超时：$HostName`:$Port" }
        $client.EndConnect($iar)
        $stream = $client.GetStream()
        $stream.ReadTimeout = $TimeoutMs
        $stream.WriteTimeout = $TimeoutMs
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $false, 1024, $true)
        $writer = New-Object System.IO.StreamWriter($stream, (New-Object System.Text.UTF8Encoding($false)), 1024, $true)
        $writer.NewLine = "`r`n"
        $writer.AutoFlush = $true
        if ($Password) {
            $auth = @('AUTH', $Password)
            $writer.WriteLine("*$($auth.Count)")
            foreach ($a in $auth) {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($a)
                $writer.WriteLine("`$$($bytes.Length)")
                $writer.Write($a)
                $writer.Write("`r`n")
            }
            [void](Read-RedisReply -Reader $reader)
        }
        if ($Database -gt 0) {
            $sel = @('SELECT', [string]$Database)
            $writer.WriteLine("*$($sel.Count)")
            foreach ($a in $sel) {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($a)
                $writer.WriteLine("`$$($bytes.Length)")
                $writer.Write($a)
                $writer.Write("`r`n")
            }
            [void](Read-RedisReply -Reader $reader)
        }
        $writer.WriteLine("*$($Command.Count)")
        foreach ($a in $Command) {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($a)
            $writer.WriteLine("`$$($bytes.Length)")
            $writer.Write($a)
            $writer.Write("`r`n")
        }
        return (Read-RedisReply -Reader $reader)
    } finally {
        try { $client.Close() } catch { }
    }
}


