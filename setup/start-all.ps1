#Requires -Version 5.1
<#
    萌宠优选 · 用户端 + 管理端一次启动
    ------------------------------------------------------------------
    编排顺序：MySQL/Redis 检查 → 后端 → 用户端构建与静态服务 → 管理端构建与静态服务
    用法：
      powershell -ExecutionPolicy Bypass -File .\setup\start-all.ps1
      powershell -ExecutionPolicy Bypass -File .\setup\start-all.ps1 -UserPort 81 -AdminPort 80
      powershell -ExecutionPolicy Bypass -File .\setup\start-all.ps1 -AdminOnly   # 只补起管理端
#>
[CmdletBinding()]
param(
    [int]$UserPort = 0,
    [int]$AdminPort = 0,
    [switch]$SkipBuild,
    [switch]$NoBrowser,
    [switch]$AdminOnly
)

. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Stop'
$Root = Get-PetMallRoot
$Config = Get-PetMallConfig -Root $Root
if ($UserPort -le 0) { $UserPort = 81 }
if ($AdminPort -le 0) { $AdminPort = [int](Get-ConfigValue $Config 'ADMIN_UI_PORT' '80') }

$commonArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File')

if (-not $AdminOnly) {
    Write-Step '用户端：检查依赖、启动后端、构建并托管'
    & powershell.exe @($commonArgs + @((Join-Path $PSScriptRoot 'start-mall.ps1'), '-NoBrowser', '-UserPort', "$UserPort"))
    if ($LASTEXITCODE -ne 0) { Write-Bad '用户端启动失败，已中止管理端。'; exit 1 }
}

Write-Step '管理端：构建并托管'
$adminArgs = @($commonArgs + @((Join-Path $PSScriptRoot 'start-admin.ps1'), '-NoBrowser', '-AdminPort', "$AdminPort", '-StartBackend'))
if ($SkipBuild) { $adminArgs += '-SkipBuild' }
& powershell.exe @adminArgs
if ($LASTEXITCODE -ne 0) { Write-Bad '管理端启动失败。'; exit 1 }

if (-not $AdminOnly) { Write-Ok "用户端：http://127.0.0.1:$UserPort/" }
Write-Ok "管理端：http://127.0.0.1:$AdminPort/"
Write-Info '演示账号：admin/admin123（管理端），member1/member123（用户端）'
if (-not $NoBrowser) {
    if (-not $AdminOnly) { Start-Process "http://127.0.0.1:$UserPort/" }
    Start-Process "http://127.0.0.1:$AdminPort/"
}
exit 0
