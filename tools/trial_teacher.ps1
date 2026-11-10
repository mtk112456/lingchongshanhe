# 教师试跑操作脚本
# 用法：
#   powershell -File tools/trial_teacher.ps1 -Action status
#   powershell -File tools/trial_teacher.ps1 -Action settle -TurnId 1
#   powershell -File tools/trial_teacher.ps1 -Action next -TurnId 1

param(
    [string]$BaseUrl = "http://127.0.0.1:8080",
    [ValidateSet("status", "settle", "next")]
    [string]$Action = "status",
    [int]$TurnId = 1
)

$ErrorActionPreference = "Stop"

$loginJson = @{ username = "teacher"; password = "teacher2026" } | ConvertTo-Json -Compress
$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/auth/admin-login" `
    -ContentType "application/json; charset=utf-8" `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($loginJson))
if (-not $login.ok) {
    throw "teacher login failed"
}
$headers = @{ Authorization = "Bearer $($login.data.token)" }

switch ($Action) {
    "settle" {
        $body = @{ turn_id = $TurnId } | ConvertTo-Json -Compress
        $r = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/slice/admin/card-settle" `
            -Headers $headers -ContentType "application/json" -Body $body
        Write-Host "== card settle =="
        Write-Host ("already_settled: {0}" -f $r.data.already_settled)
        foreach ($b in $r.data.battles) {
            if ($null -eq $b.battle_id) {
                Write-Host ("  {0}: {1}" -f $b.node_code, $b.reason)
            } else {
                Write-Host ("  {0}: score={1} wall={2} morale {3}->{4} captured={5}" -f `
                    $b.node_code, $b.score, $b.wall, $b.morale_before, $b.morale_after, $b.captured)
            }
        }
    }
    "next" {
        $body = @{ from_turn_id = $TurnId } | ConvertTo-Json -Compress
        $r = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/slice/admin/next-turn" `
            -Headers $headers -ContentType "application/json" -Body $body
        Write-Host ("next turn: {0} (id={1})" -f $r.data.turn.turn_no, $r.data.turn.id)
    }
    "status" {
        $r = Invoke-RestMethod -Uri "$BaseUrl/api/slice/state" -Headers $headers
        Write-Host ("game: {0}" -f $r.data.game.name)
        Write-Host ("turn: {0} ({1})" -f $r.data.turn.turn_no, $r.data.turn.status)
        $r.data.map.nodes | Select-Object code, name, morale, morale_cap, @{ n = "owner"; e = { $_.owner.code } } | Format-Table -AutoSize
        Write-Host ("orders confirmed: {0}" -f $r.data.orders_confirmed)
    }
}
