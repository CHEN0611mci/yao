#Requires -Version 5.1
[CmdletBinding()]
param([string]$OutputDirectory = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path (Split-Path -Parent $projectRoot) '交付包' }
$bundleName = 'pet-mall-v2.3.0-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$stage = Join-Path $OutputDirectory $bundleName
$jar = Join-Path $projectRoot 'backend\ruoyi-admin\target\ruoyi-admin.jar'
foreach ($required in @($jar, (Join-Path $projectRoot 'user-ui\dist\index.html'), (Join-Path $projectRoot 'admin-ui\dist\index.html'))) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Build first: $required" }
}
New-Item -ItemType Directory -Path $stage -ErrorAction Stop | Out-Null
function Copy-Tree([string]$relative) {
    $source = Join-Path $projectRoot $relative
    Get-ChildItem -LiteralPath $source -Recurse -File | Where-Object {
        $_.FullName -notmatch '\\(node_modules|target|\.git|\.vite|\.build-tmp)\\' -and
        ($_.Name -notlike '.env*' -or $_.Name -eq '.env.example') -and $_.Extension -notin @('.log', '.pid', '.tmp')
    } | ForEach-Object {
        $local = $_.FullName.Substring($projectRoot.Length + 1)
        $destination = Join-Path $stage $local
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $destination
    }
}
foreach ($tree in @('backend','user-ui','admin-ui','setup','db','verify\repair','verify\member-features','verify\multi-sku','verify\catalog-boundary','verify\session-index','verify\user-ui')) { Copy-Tree $tree }
New-Item -ItemType Directory -Path (Join-Path $stage 'dist'), (Join-Path $stage 'config'), (Join-Path $stage 'docs') -Force | Out-Null
Copy-Item -LiteralPath $jar -Destination (Join-Path $stage 'dist\ruoyi-admin.jar')
Copy-Item -LiteralPath (Join-Path $projectRoot 'config\backend.env.example') -Destination (Join-Path $stage 'config\backend.env.example')
foreach ($file in @('start-mall.bat','start-user-ui.bat','start-admin-runtime.bat','start-backend.bat','stop-backend.bat','init-db.bat','check-env.bat','smoke-test.bat','README.md','RUNBOOK.md','VERSION.txt')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination (Join-Path $stage $file)
}
foreach ($report in @('修复记录-v1.1.0.md','功能完善-v1.2.0.md','复查记录-v2.2.1.md','复查记录-v2.2.2.md','会话优化-v2.3.0.md')) { Copy-Item -LiteralPath (Join-Path $projectRoot ('docs\' + $report)) -Destination (Join-Path $stage ('docs\' + $report)) }
@'
# 修复版完整运行包

1. 本机已有数据库时，填写 config/backend.env，不要重置数据库。
2. 安装 Node 18+、JDK 17+、MySQL 8、Redis。新电脑首次初始化参阅 RUNBOOK。
3. 双击 start-mall.bat，访问 http://127.0.0.1:81/ 。管理端运行 start-admin-runtime.bat，访问 80 端口。
4. 包含后端 JAR、前后台生产构建和源码；不含本机密码、数据库副本、node_modules 或运行环境安装器。
5. 启动时自动增量升级三张表（收藏、偏好、支付幂等映射），保留旧数据。支付为沙箱。详细范围及验收见 docs/功能完善-v1.2.0.md。
6. v2.2.1 修复多规格下单、取消的并发死锁；本轮范围与验收见 docs/复查记录-v2.2.1.md。
7. v2.2.2 修复分类层级/空项校验、订单索引锁及消息连接池耗尽，复查见 docs/复查记录-v2.2.2.md。
8. v2.3.0 优化会员会话索引，启动自动迁移旧会话，正常运行不再全站扫描令牌，见 docs/会话优化-v2.3.0.md。
'@ | Set-Content -LiteralPath (Join-Path $stage 'README-先看这里.md') -Encoding UTF8
$manifest = Get-ChildItem -LiteralPath $stage -File -Recurse | ForEach-Object {
    [pscustomobject]@{ path = $_.FullName.Substring($stage.Length + 1).Replace('\','/'); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower() }
}
$manifest | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $stage 'manifest.json') -Encoding UTF8
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$zip = "$stage.zip"
$writer = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
try {
    Get-ChildItem -LiteralPath $stage -File -Recurse | ForEach-Object {
        $entryName = $_.FullName.Substring($stage.Length + 1).Replace('\','/')
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($writer, $_.FullName, $entryName, [IO.Compression.CompressionLevel]::Optimal)
    }
} finally { $writer.Dispose() }
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try {
    if ($archive.Entries.Count -ne @($manifest).Count + 1) { throw 'ZIP entry count mismatch' }
    foreach ($entry in $archive.Entries) {
        if ($entry.FullName -eq 'manifest.json') { continue }
        $record = $manifest | Where-Object path -eq $entry.FullName
        $stream = $entry.Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $actual = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLower() }
        finally { $stream.Dispose(); $sha.Dispose() }
        if (-not $record -or $actual -ne $record.sha256) { throw "ZIP hash mismatch: $($entry.FullName)" }
    }
} finally { $archive.Dispose() }
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
"$hash  $([IO.Path]::GetFileName($zip))" | Set-Content -LiteralPath "$zip.sha256" -Encoding ASCII
Write-Output "Verified ZIP: $zip"
Write-Output "Files: $(@($manifest).Count + 1); SHA256: $hash"
