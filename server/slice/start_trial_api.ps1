param(
    [string]$Bind = "127.0.0.1",
    [int]$Port = 8081
)

$ErrorActionPreference = "Stop"
$env:SLICE_CONFIG = Join-Path $PSScriptRoot "config.trial.php"
$php = (Get-Command php).Source
$phpDir = Split-Path $php -Parent
$extDir = Join-Path $phpDir "ext"
$root = $PSScriptRoot

Write-Host "Trial config: $env:SLICE_CONFIG"
Write-Host "Trial API: http://${Bind}:${Port}/api/health"

& $php -d "extension_dir=$extDir" -d extension=pdo_mysql -S "${Bind}:${Port}" -t (Join-Path $root "public") (Join-Path $root "public\index.php")
