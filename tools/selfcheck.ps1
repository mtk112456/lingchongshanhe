param(
    [string]$BaseUrl = "http://127.0.0.1:8081",
    [string]$LogDir = ""
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
if ($LogDir -eq "") {
    $LogDir = Join-Path $root "selfcheck"
}
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$log = Join-Path $LogDir ("selfcheck_" + (Get-Date -Format "yyyyMMdd") + ".log")
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$ok = $true
$lines = @()

# 1. API health
try {
    $h = Invoke-RestMethod "$BaseUrl/api/health" -TimeoutSec 5
    if ($h.ok -eq $true) {
        $lines += "api_health=OK"
    } else {
        $lines += "api_health=FAIL"
        $ok = $false
    }
} catch {
    $lines += "api_health=DOWN ($($_.Exception.Message))"
    $ok = $false
}

# 2. Teacher status (read-only)
try {
    $teacher = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "tools/trial_teacher.ps1") -BaseUrl $BaseUrl -Action status 2>&1
    $turnLine = ($teacher | Select-String -Pattern "^turn:" | Select-Object -First 1).Line
    if ($turnLine) {
        $lines += "teacher=$turnLine"
    } else {
        $lines += "teacher=NO_TURN"
        $ok = $false
    }
} catch {
    $lines += "teacher=FAIL ($($_.Exception.Message))"
    $ok = $false
}

# 3. APK
$apk = Join-Path $root "client/build/android/qingzhu_slice.apk"
if (Test-Path $apk) {
    $item = Get-Item $apk
    $lines += ("apk=OK size={0} time={1}" -f $item.Length, $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm"))
} else {
    $lines += "apk=MISSING"
    $ok = $false
}

# 4. Git state (read-only)
$status = @(git -C $root status --short 2>$null)
$lines += ("git_dirty={0}" -f $status.Count)
$head = (git -C $root log -1 --oneline 2>$null)
$lines += ("git_head={0}" -f $head)

# 5. PHP syntax on key files
$php = "C:\Users\MTK\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe"
$phpFiles = @(
    "server/slice/public/index.php",
    "server/slice/src/CardSettlementService.php",
    "server/slice/src/SeasonService.php",
    "server/slice/scripts/export_trial.php"
)
$syntaxOk = $true
foreach ($f in $phpFiles) {
    $out = & $php -l (Join-Path $root $f) 2>&1
    if ($LASTEXITCODE -ne 0) {
        $syntaxOk = $false
    }
}
if ($syntaxOk) {
    $lines += "php_syntax=OK"
} else {
    $lines += "php_syntax=FAIL"
    $ok = $false
}

$lines += ("result=" + $(if ($ok) { "PASS" } else { "FAIL" }))
Add-Content -Path $log -Value ("[" + $stamp + "] " + ($lines -join " | "))

if ($ok) {
    Write-Host ("SELFCHECK PASS " + $stamp)
    exit 0
}
Write-Host ("SELFCHECK FAIL " + $stamp)
exit 1
