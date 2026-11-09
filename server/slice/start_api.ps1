param(
    [string]$Bind = "0.0.0.0",
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"
$php = (Get-Command php).Source
$phpDir = Split-Path $php -Parent
$extDir = Join-Path $phpDir "ext"
$root = $PSScriptRoot

Write-Host "PHP: $php"
Write-Host "API: http://${Bind}:${Port}/api/health"
Write-Host "按 Ctrl+C 停止。"

& $php -d "extension_dir=$extDir" -d extension=pdo_mysql -S "${Bind}:${Port}" -t (Join-Path $root "public") (Join-Path $root "public\index.php")
