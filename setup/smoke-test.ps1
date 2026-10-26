#Requires -Version 5.1
<#
    萌宠优选 · 后端冒烟验收（只读，不修改业务数据）
    ------------------------------------------------------------------
    覆盖：公开接口、会员登录、后台登录、商家/审核员权限、双域 Token 隔离
    依赖：后端已启动；Redis 可读验证码；MySQL 已初始化
    用法：
      powershell -ExecutionPolicy Bypass -File .\setup\smoke-test.ps1
      powershell -ExecutionPolicy Bypass -File .\setup\smoke-test.ps1 -Port 8081
    输出：控制台 + verify\smoke-result.txt
#>
[CmdletBinding()]
param(
    [string]$BaseUrl,
    [int]$Port = 0,
    [string]$ResultFile
)

. (Join-Path $PSScriptRoot 'common.ps1')
$Root = Get-PetMallRoot
$Config = Get-PetMallConfig -Root $Root
if ($Port -le 0) { $Port = [int](Get-ConfigValue $Config 'SERVER_PORT' '8080') }
if (-not $BaseUrl) { $BaseUrl = "http://127.0.0.1:$Port" }
$BaseUrl = $BaseUrl.TrimEnd('/')
$redisHost = Get-ConfigValue $Config 'REDIS_HOST' '127.0.0.1'
$redisPort = [int](Get-ConfigValue $Config 'REDIS_PORT' '6379')
$redisPwd = Get-ConfigValue $Config 'REDIS_PASSWORD' ''
$redisDb = [int](Get-ConfigValue $Config 'REDIS_DATABASE' '0')

$tmp = Join-Path $env:TEMP ("petmall_smoke_{0}" -f [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$respFile = Join-Path $tmp 'resp.json'
$bodyFile = Join-Path $tmp 'body.json'
$lines = New-Object System.Collections.Generic.List[string]
$checks = New-Object System.Collections.Generic.List[object]

function Add-Log { param([string]$s) $lines.Add($s) }
function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    $checks.Add([pscustomobject]@{ Name = $Name; Ok = $Ok; Detail = $Detail })
    Add-Log (("[{0}] {1} | {2}" -f $(if ($Ok) { 'PASS' } else { 'FAIL' }), $Name, $Detail))
}
function Add-Skip { param([string]$Name, [string]$Detail)
    $checks.Add([pscustomobject]@{ Name = $Name; Ok = $null; Detail = $Detail })
    Add-Log ("[SKIP] {0} | {1}" -f $Name, $Detail)
}
function Show-Result {
    param([string]$Label, $r, [int]$Max = 240)
    $b = ($r.Body -replace '\s+', ' ')
    if ($b.Length -gt $Max) { $b = $b.Substring(0, $Max) + '...' }
    Add-Log ("{0} => HTTP {1} | {2}" -f $Label, $r.Status, $b)
}
function Get-Json { param($r) try { return ($r.Body | ConvertFrom-Json) } catch { return $null } }
function Get-BizCode {
    param($r)
    $j = Get-Json $r
    if ($j -and $null -ne $j.code) { return [int]$j.code }
    return -1
}
function Assert-Api {
    param([string]$Name, $r, [int]$Http, [int]$Biz)
    $code = Get-BizCode $r
    Add-Check $Name (($r.Status -eq $Http) -and ($code -eq $Biz)) ("HTTP={0} biz={1}" -f $r.Status, $code)
}

function Invoke-Api {
    param([string]$Method, [string]$Path, [string]$Body, [string]$Token)
    $curlArgs = @('-sS', '--noproxy', '*', '--max-time', '20', '-o', $respFile, '-w', '%{http_code}', '-X', $Method, "$BaseUrl$Path")
    if ($Body) {
        [System.IO.File]::WriteAllText($bodyFile, $Body, (New-Object System.Text.UTF8Encoding($false)))
        $curlArgs += @('-H', 'Content-Type: application/json', '--data-binary', "@$bodyFile")
    }
    if ($Token) { $curlArgs += @('-H', "Authorization: Bearer $Token") }
    $statusText = (& curl.exe @curlArgs 2>$null) -join ''
    $status = 0
    [void][int]::TryParse($statusText.Trim(), [ref]$status)
    $content = ''
    if (Test-Path -LiteralPath $respFile) {
        $content = [System.IO.File]::ReadAllText($respFile, [System.Text.Encoding]::UTF8)
    }
    return [pscustomobject]@{ Status = $status; Body = $content }
}

function Get-Captcha {
    $r = Invoke-Api -Method 'GET' -Path '/captchaImage'
    Show-Result 'GET /captchaImage' $r 120
    $j = Get-Json $r
    if (-not $j) { return [pscustomobject]@{ Enabled = $null; Uuid = $null } }
    return [pscustomobject]@{ Enabled = [bool]$j.captchaEnabled; Uuid = [string]$j.uuid }
}
function Get-CaptchaAnswer {
    param($Captcha)
    if (-not $Captcha.Enabled -or -not $Captcha.Uuid) { return $null }
    try {
        $answer = [string](Invoke-RedisCommand -HostName $redisHost -Port $redisPort -Password $redisPwd -Database $redisDb -Command @('GET', "captcha_codes:$($Captcha.Uuid)"))
        return $answer.Trim().Trim('"')
    } catch {
        Add-Log ("读取 Redis 验证码失败：{0}" -f $_.Exception.Message)
        return $null
    }
}
function Login-Admin {
    param([string]$User, [string]$Pass)
    $cap = Get-Captcha
    $payload = [ordered]@{ username = $User; password = $Pass }
    if ($cap.Enabled) {
        $answer = Get-CaptchaAnswer -Captcha $cap
        if (-not $answer) {
            Add-Check "$User-captcha" $false '无法从 Redis 读取验证码答案'
            return [pscustomobject]@{ Response = $null; Token = $null }
        }
        $payload['code'] = $answer
        $payload['uuid'] = $cap.Uuid
    }
    $r = Invoke-Api -Method 'POST' -Path '/login' -Body ($payload | ConvertTo-Json -Compress)
    Show-Result "POST /login ($User)" $r 220
    $j = Get-Json $r
    $token = if ($j -and $j.token) { [string]$j.token } else { $null }
    return [pscustomobject]@{ Response = $r; Token = $token }
}
function Login-Member {
    param([string]$User, [string]$Pass)
    $body = ([ordered]@{ username = $User; password = $Pass } | ConvertTo-Json -Compress)
    $r = Invoke-Api -Method 'POST' -Path '/api/member/login' -Body $body
    Show-Result "POST /api/member/login ($User)" $r 220
    $j = Get-Json $r
    $token = if ($j -and $j.data -and $j.data.token) { [string]$j.data.token } else { $null }
    return [pscustomobject]@{ Response = $r; Token = $token }
}

try {
    Add-Log '================ 萌宠优选后端冒烟验收 ================'
    Add-Log ("base={0} time={1}" -f $BaseUrl, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

    Add-Log '--- 1. 公开接口 ---'
    $r = Invoke-Api -Method 'GET' -Path '/api/home/categories'
    Show-Result 'GET /api/home/categories' $r 260
    Assert-Api 'public-home-categories' $r 200 200

    $r = Invoke-Api -Method 'GET' -Path '/api/home/recommend?limit=3'
    Show-Result 'GET /api/home/recommend' $r 260
    Assert-Api 'public-home-recommend' $r 200 200

    $r = Invoke-Api -Method 'GET' -Path '/api/items?pageNum=1&pageSize=5'
    Show-Result 'GET /api/items' $r 320
    Assert-Api 'public-item-list' $r 200 200
    $j = Get-Json $r
    $total = if ($j -and $j.data -and $null -ne $j.data.total) { [int]$j.data.total } else { -1 }
    Add-Check 'public-item-total' ($total -ge 1) ("total={0}（种子数据期望 10）" -f $total)

    Add-Log '--- 2. 会员接口 ---'
    $m1 = Login-Member -User 'member1' -Pass 'member123'
    if ($m1.Response) { Assert-Api 'member1-login' $m1.Response 200 200 }
    Add-Check 'member1-token' ([bool]$m1.Token) ("token={0}" -f $(if ($m1.Token) { 'yes' } else { 'no' }))
    if ($m1.Token) {
        $r = Invoke-Api -Method 'GET' -Path '/api/member/me' -Token $m1.Token
        Show-Result 'GET /api/member/me' $r 220
        Assert-Api 'member1-profile' $r 200 200
        $r = Invoke-Api -Method 'GET' -Path '/api/member/pets' -Token $m1.Token
        Show-Result 'GET /api/member/pets' $r 220
        Assert-Api 'member1-pets' $r 200 200
        $r = Invoke-Api -Method 'GET' -Path '/api/member/addresses' -Token $m1.Token
        Show-Result 'GET /api/member/addresses' $r 220
        Assert-Api 'member1-addresses' $r 200 200
        $r = Invoke-Api -Method 'GET' -Path '/api/orders?pageNum=1&pageSize=10' -Token $m1.Token
        Show-Result 'GET /api/orders' $r 260
        Assert-Api 'member1-orders' $r 200 200
        $r = Invoke-Api -Method 'GET' -Path '/api/cart' -Token $m1.Token
        Show-Result 'GET /api/cart' $r 220
        Assert-Api 'member1-cart' $r 200 200
    }
    $r = Invoke-Api -Method 'GET' -Path '/api/member/me'
    Show-Result 'GET /api/member/me (no token)' $r 160
    Assert-Api 'member-no-token-401' $r 401 2001

    Add-Log '--- 3. 后台管理员接口 ---'
    $admin = Login-Admin -User 'admin' -Pass 'admin123'
    if ($admin.Response) { Assert-Api 'admin-login' $admin.Response 200 200 }
    if ($admin.Token) {
        $r = Invoke-Api -Method 'GET' -Path '/getInfo' -Token $admin.Token
        Show-Result 'GET /getInfo' $r 220
        Assert-Api 'admin-getInfo' $r 200 200
        $r = Invoke-Api -Method 'GET' -Path '/api/admin/items?pageNum=1&pageSize=10' -Token $admin.Token
        Show-Result 'GET /api/admin/items' $r 260
        Assert-Api 'admin-item-list' $r 200 200
        $r = Invoke-Api -Method 'GET' -Path '/api/admin/categories?pageNum=1&pageSize=20' -Token $admin.Token
        Assert-Api 'admin-categories' $r 200 200
        $r = Invoke-Api -Method 'GET' -Path '/api/admin/members?pageNum=1&pageSize=10' -Token $admin.Token
        Assert-Api 'admin-members' $r 200 200
        $r = Invoke-Api -Method 'GET' -Path '/api/admin/orders?pageNum=1&pageSize=10' -Token $admin.Token
        Assert-Api 'admin-orders' $r 200 200
        $r = Invoke-Api -Method 'GET' -Path '/api/admin/stock' -Token $admin.Token
        Assert-Api 'admin-stock' $r 200 200
        $r = Invoke-Api -Method 'GET' -Path '/api/admin/dashboard/summary' -Token $admin.Token
        Assert-Api 'admin-dashboard' $r 200 200
    }
    if ($m1.Token) {
        $r = Invoke-Api -Method 'GET' -Path '/api/admin/items' -Token $m1.Token
        Show-Result 'GET /api/admin/items (member token)' $r 160
        Assert-Api 'member-token-rejected-by-admin' $r 200 401
    }
}
catch {
    Add-Log ("EXCEPTION: {0}" -f $_.Exception.Message)
    Add-Check 'smoke-script' $false $_.Exception.Message
}


Add-Log '--- 4. 商家接口与数据隔离 ---'
$merchant = Login-Admin -User 'merchant1' -Pass 'merchant123'
if ($merchant.Response) { Assert-Api 'merchant1-login' $merchant.Response 200 200 }
Add-Check 'merchant1-token' ([bool]$merchant.Token) ("token={0}" -f $(if ($merchant.Token) { 'yes' } else { 'no' }))
if ($merchant.Token) {
    $r = Invoke-Api -Method 'GET' -Path '/api/merchant/items?pageNum=1&pageSize=20' -Token $merchant.Token
    Show-Result 'GET /api/merchant/items' $r 260
    Assert-Api 'merchant-item-list' $r 200 200
    $r = Invoke-Api -Method 'GET' -Path '/api/admin/items' -Token $merchant.Token
    Show-Result 'GET /api/admin/items (merchant token)' $r 160
    Assert-Api 'merchant-cannot-admin' $r 200 403
}

Add-Log '--- 5. 审核员最小权限 ---'
$reviewer = Login-Admin -User 'reviewer' -Pass 'reviewer123'
if ($reviewer.Response) { Assert-Api 'reviewer-login' $reviewer.Response 200 200 }
Add-Check 'reviewer-token' ([bool]$reviewer.Token) ("token={0}" -f $(if ($reviewer.Token) { 'yes' } else { 'no' }))
if ($reviewer.Token) {
    $r = Invoke-Api -Method 'GET' -Path '/api/admin/items?auditStatus=0&pageNum=1&pageSize=10' -Token $reviewer.Token
    Show-Result 'GET /api/admin/items?auditStatus=0' $r 220
    Assert-Api 'reviewer-audit-queue' $r 200 200
    $r = Invoke-Api -Method 'GET' -Path '/api/admin/members' -Token $reviewer.Token
    Show-Result 'GET /api/admin/members (reviewer)' $r 160
    Assert-Api 'reviewer-members-forbidden' $r 200 403
    $r = Invoke-Api -Method 'GET' -Path '/api/admin/dashboard/summary' -Token $reviewer.Token
    Show-Result 'GET /api/admin/dashboard (reviewer)' $r 160
    Assert-Api 'reviewer-dashboard-forbidden' $r 200 403
}

$pass = @($checks | Where-Object { $_.Ok -eq $true }).Count
$fail = @($checks | Where-Object { $_.Ok -eq $false }).Count
$skip = @($checks | Where-Object { $null -eq $_.Ok }).Count
Add-Log '================ SUMMARY ================'
Add-Log ("PASS={0} FAIL={1} SKIP={2} TOTAL={3}" -f $pass, $fail, $skip, $checks.Count)
if ($fail -gt 0) {
    Add-Log 'Failed checks:'
    $checks | Where-Object { $_.Ok -eq $false } | ForEach-Object { Add-Log ("- {0} | {1}" -f $_.Name, $_.Detail) }
}

if (-not $ResultFile) { $ResultFile = Join-Path $Root 'verify\smoke-result.txt' }
elseif (-not [System.IO.Path]::IsPathRooted($ResultFile)) { $ResultFile = Join-Path $Root $ResultFile }
$resultDir = Split-Path -Parent $ResultFile
New-Item -ItemType Directory -Path $resultDir -Force | Out-Null
[System.IO.File]::WriteAllLines($ResultFile, $lines, (New-Object System.Text.UTF8Encoding($true)))
$lines | ForEach-Object { Write-Host $_ }
Write-Host ''
Write-Host ("结果已保存：{0}" -f $ResultFile) -ForegroundColor Green

Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
if ($fail -gt 0) { exit 1 } else { exit 0 }
