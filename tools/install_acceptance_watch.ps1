<#
.SYNOPSIS
  安装/移除“每 30 分钟自动验收”Windows 计划任务。

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\install_acceptance_watch.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\install_acceptance_watch.ps1 -Remove
#>
[CmdletBinding()]
param(
    [string]$Root = '',
    [int]$IntervalMinutes = 30,
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $Root = Split-Path -Parent $PSScriptRoot
    } else {
        $Root = (Get-Location).Path
    }
}
$Root = (Resolve-Path -LiteralPath $Root).Path

$taskName = 'QingzhuAcceptanceWatch'
$scriptPath = Join-Path $Root 'tools\watch_acceptance.ps1'

if ($Remove) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "已移除计划任务：$taskName"
    exit 0
}

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "找不到验收脚本：$scriptPath"
}

$powerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Once' -f $scriptPath

$action = New-ScheduledTaskAction -Execute $powerShellExe -Argument $arguments -WorkingDirectory $Root
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(1)) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 20) `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId ("{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME) `
    -LogonType Interactive -RunLevel Limited

try {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Force `
        -Description '灵宠山河：每 30 分钟跑一次自动验收，结果写入 tools/watch/STATUS.md' | Out-Null
    Write-Host "已安装计划任务：$taskName（每 $IntervalMinutes 分钟）"
    Write-Host "首次运行：约 1 分钟后；也可手动运行："
    Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Once"
} catch {
    Write-Host "计划任务安装失败：$($_.Exception.Message)"
    Write-Host ''
    Write-Host '可改用前台循环（关闭窗口即停止）：'
    Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -IntervalMinutes $IntervalMinutes"
    Write-Host ''
    Write-Host '或手动用 schtasks 安装：'
    $tr = '"{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}" -Once' -f $powerShellExe, $scriptPath
    Write-Host "  schtasks /Create /TN $taskName /SC MINUTE /MO $IntervalMinutes /TR '$tr' /IT /F"
    exit 1
}
