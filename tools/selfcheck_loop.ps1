param(
    [int]$EveryMinutes = 30,
    [int]$Runs = 8
)

$ErrorActionPreference = "Continue"
for ($i = 0; $i -lt $Runs; $i++) {
    & (Join-Path $PSScriptRoot "selfcheck.ps1")
    if ($i -lt ($Runs - 1)) {
        Start-Sleep -Seconds ($EveryMinutes * 60)
    }
}
