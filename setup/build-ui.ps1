#Requires -Version 5.1
<#
    萌宠优选 · 前端统一构建
    ------------------------------------------------------------------
    一次准备 user-ui（商城用户端）与 admin-ui（若依管理端）的依赖与产物：
      - 缺 node_modules 时自动 npm ci（有 package-lock.json）或 npm install
      - admin-ui 首次自动生成 .env.production（/prod-api）与 .env.development（/dev-api）
      - dist 缺失或源码更新时自动构建；默认增量，-Force 强制重装依赖并重建
    用法：
      powershell -ExecutionPolicy Bypass -File .\setup\build-ui.ps1
      powershell -ExecutionPolicy Bypass -File .\setup\build-ui.ps1 -Target Admin
      powershell -ExecutionPolicy Bypass -File .\setup\build-ui.ps1 -Target User -Force
#>
[CmdletBinding()]
param(
    [ValidateSet('Both', 'User', 'Admin')]
    [string]$Target = 'Both',
    [switch]$Force
)

. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Stop'
$Root = Get-PetMallRoot

function Ensure-ViteEnv {
    param([string]$UiDir)
    $example = Join-Path $UiDir '.env.example'
    if (-not (Test-Path -LiteralPath $example)) { Write-Warn "缺少 $example，跳过环境文件生成。"; return }
    $profiles = @(
        @{ File = '.env.production'; Env = 'production'; Api = '/prod-api' },
        @{ File = '.env.development'; Env = 'development'; Api = '/dev-api' }
    )
    foreach ($profile in $profiles) {
        $path = Join-Path $UiDir $profile.File
        if (Test-Path -LiteralPath $path) { Write-Info "$($profile.File) 已存在，保留自定义值"; continue }
        $lines = [System.IO.File]::ReadAllLines($example, [System.Text.Encoding]::UTF8) | ForEach-Object {
            if ($_ -match '^\s*VITE_APP_ENV\s*=') { "VITE_APP_ENV = '$($profile.Env)'" }
            elseif ($_ -match '^\s*VITE_APP_BASE_API\s*=') { "VITE_APP_BASE_API = '$($profile.Api)'" }
            else { $_ }
        }
        [System.IO.File]::WriteAllLines($path, [string[]]$lines, (New-Object System.Text.UTF8Encoding($false)))
        Write-Ok "已生成 $($profile.File)（VITE_APP_BASE_API=$($profile.Api)）"
    }
}

function Ensure-UiDependencies {
    param([string]$UiDir, [switch]$Force)
    $name = Split-Path -Leaf $UiDir
    if ($Force) {
        Write-Step "$name：清理 node_modules"
        Remove-Item -LiteralPath (Join-Path $UiDir 'node_modules') -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath (Join-Path $UiDir 'node_modules')) { Write-Ok "$name：依赖已安装"; return }
    Write-Step "$name：安装依赖（首次 1-3 分钟）"
    Push-Location $UiDir
    $previous = $ErrorActionPreference
    # vite/npm 会把进度写到 stderr；Stop 模式会把原生命令的 stderr 当成终止性错误
    $ErrorActionPreference = 'Continue'
    try {
        if (Test-Path -LiteralPath 'package-lock.json') { & npm.cmd ci --no-audit --no-fund }
        else { & npm.cmd install --no-audit --no-fund }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
        Pop-Location
    }
    if ($code -ne 0) {
        throw "$name 依赖安装失败（exit=$code）。可切换镜像：npm config set registry https://registry.npmmirror.com"
    }
}

function Test-UiBuildStale {
    param([string]$UiDir)
    $index = Join-Path $UiDir 'dist\index.html'
    if (-not (Test-Path -LiteralPath $index)) { return $true }
    $built = (Get-Item -LiteralPath $index).LastWriteTimeUtc
    $sources = @((Join-Path $UiDir 'src'), (Join-Path $UiDir 'public')) | Where-Object { Test-Path -LiteralPath $_ }
    foreach ($dir in $sources) {
        $newer = Get-ChildItem -LiteralPath $dir -Recurse -File |
            Where-Object { $_.LastWriteTimeUtc -gt $built } | Select-Object -First 1
        if ($newer) { return $true }
    }
    # 只有影响生产构建的环境文件才触发重建（.env.development 只作用于 npm run dev）
    $envFiles = @(
        (Join-Path $UiDir '.env'),
        (Join-Path $UiDir '.env.production'),
        (Join-Path $UiDir '.env.production.local')
    ) | Where-Object { (Test-Path -LiteralPath $_) -and (Get-Item -LiteralPath $_).LastWriteTimeUtc -gt $built }
    return [bool]$envFiles
}

function Invoke-UiBuild {
    param([string]$UiDir, [string]$Script)
    $name = Split-Path -Leaf $UiDir
    Write-Step "$name：npm run $Script"
    Push-Location $UiDir
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & npm.cmd run $Script
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
        Pop-Location
    }
    if ($code -ne 0) { throw "$name 构建失败（exit=$code）" }
    $sum = (Get-ChildItem -LiteralPath (Join-Path $UiDir 'dist') -Recurse -File |
        Measure-Object -Property Length -Sum).Sum
    Write-Ok ("{0}：构建完成，{1:N2} MB" -f $name, ($sum / 1MB))
}

$node = Get-Command node.exe -ErrorAction SilentlyContinue
if (-not $node) { Write-Bad '未找到 Node.js，请安装 18 或更高版本后重试。'; exit 1 }
Write-Ok ("Node " + (& $node.Source -v))

$jobs = @()
if ($Target -in @('Both', 'User')) { $jobs += @{ Dir = (Join-Path $Root 'user-ui'); Script = 'build' } }
if ($Target -in @('Both', 'Admin')) { $jobs += @{ Dir = (Join-Path $Root 'admin-ui'); Script = 'build:prod' } }

foreach ($job in $jobs) {
    $uiDir = $job.Dir
    if (-not (Test-Path -LiteralPath $uiDir)) { Write-Bad "缺少目录：$uiDir"; exit 1 }
    if ((Split-Path -Leaf $uiDir) -eq 'admin-ui') { Ensure-ViteEnv -UiDir $uiDir }
    Ensure-UiDependencies -UiDir $uiDir -Force:$Force
    if ($Force -or (Test-UiBuildStale -UiDir $uiDir)) {
        Invoke-UiBuild -UiDir $uiDir -Script $job.Script
    } else {
        Write-Ok ("{0}：dist 已是最新，跳过构建（需要强制重建请加 -Force）" -f (Split-Path -Leaf $uiDir))
    }
}
Write-Ok '前端已就绪。'
exit 0
