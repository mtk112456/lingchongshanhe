param(
    [string]$BaseUrl = "http://127.0.0.1:8080"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$php = "C:\Users\MTK\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe"
$phpDir = Split-Path -Parent $php
$godot = Join-Path $root "tools\Godot_v4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe"

$proc = $null
try {
    Write-Host "== reset dev db =="
    & $php -d "extension_dir=$phpDir\ext" -d extension=pdo_mysql "$root\tools\reset_dev_db.php"

    Write-Host "== start api =="
    $proc = Start-Process -FilePath $php `
        -ArgumentList @("-d", "extension_dir=$phpDir\ext", "-d", "extension=pdo_mysql", "-S", "127.0.0.1:8080", "-t", "server/slice/public") `
        -WorkingDirectory $root -PassThru -WindowStyle Hidden

    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 300
        try {
            $health = Invoke-RestMethod "$BaseUrl/api/health" -TimeoutSec 2
            if ($health.ok) { $ready = $true; break }
        } catch { }
    }
    if (-not $ready) { throw "api not ready" }

    Write-Host "== run Phase1ClientSmoke in Godot =="
    & $godot --headless --path "$root\client" res://tests/Phase1ClientSmoke.tscn
    if ($LASTEXITCODE -ne 0) {
        throw "Phase1ClientSmoke failed with exit code $LASTEXITCODE"
    }
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
    $conn = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        $conn | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
    }
}
