#Requires -Version 5.1
# Only additive, repeatable migrations. Never seeds or resets existing data.
param([AllowEmptyString()][string]$DatabasePassword)
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Stop'
$rootDir = Get-PetMallRoot
$configuration = Get-PetMallConfig -Root $rootDir
$mysql = Resolve-MySql -Config $configuration
if (-not $mysql) { throw 'mysql.exe not found; configure MYSQL_EXE in config/backend.env.' }
$password = if ($PSBoundParameters.ContainsKey('DatabasePassword')) { $DatabasePassword } else { Get-ConfigValue $configuration 'DB_PASSWORD' '' }
if ($password -eq 'CHANGE_ME') { throw 'Set DB_PASSWORD in config/backend.env before starting.' }
$optionFile = Join-Path $env:TEMP ('petmall_upgrade_' + [guid]::NewGuid().ToString('N') + '.cnf')
try {
    New-MySqlOptionFile -Path $optionFile -User (Get-ConfigValue $configuration 'DB_USERNAME' 'root') -Password $password -HostName (Get-ConfigValue $configuration 'DB_HOST' '127.0.0.1') -Port ([int](Get-ConfigValue $configuration 'DB_PORT' '3306'))
    $result = Invoke-MySqlFile -MySqlExe $mysql -OptionFile $optionFile -File (Join-Path $rootDir 'db/05_member_features.sql') -Database (Get-ConfigValue $configuration 'DB_NAME' 'shop')
    if ($result.Code -ne 0) { throw ($result.Output -join "`n") }
    Write-Ok 'Member feature schema ready; existing data preserved.'
} finally {
    Remove-Item -LiteralPath $optionFile -Force -ErrorAction SilentlyContinue
}
