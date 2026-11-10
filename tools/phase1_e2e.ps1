# Phase 1 端到端验收：登录 → state → 编成 → 出 3 令 → 战斗 → 结算 → state
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/phase1_e2e.ps1
#   powershell ... -File tools/phase1_e2e.ps1 -Node N1 -Name "青竹一"

param(
    [string]$BaseUrl = "http://127.0.0.1:8080",
    [string]$Name = "青竹一",
    [string]$Password = "slice2026",
    [string]$Node = "N2",
    [int]$TurnId = 1
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$php = "C:\Users\MTK\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe"
$phpDir = Split-Path -Parent $php

$failed = 0
function Check($name, $ok, $detail = "") {
    if ($ok) {
        Write-Host "[PASS] $name" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $name $detail" -ForegroundColor Red
        $script:failed++
    }
}

$proc = $null
try {
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
    Check "api ready" $ready
    if (-not $ready) { throw "api not ready" }

    # 登录（中文名必须 UTF-8 bytes）
    $loginJson = @{ name = $Name; password = $Password } | ConvertTo-Json -Compress
    $login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/auth/login" `
        -ContentType "application/json; charset=utf-8" `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($loginJson))
    Check "login" ($login.ok -eq $true)
    $headers = @{ Authorization = "Bearer $($login.data.token)" }

    # state
    $state = Invoke-RestMethod -Uri "$BaseUrl/api/slice/state" -Headers $headers
    Check "state has map" ($state.data.map.nodes.Count -ge 5)
    Check "state has hand" ($state.data.hand.cards.Count -eq 4)
    Check "state has composition" ($state.data.composition.types.Count -eq 3)
    $nodesWithMorale = @($state.data.map.nodes | Where-Object { $null -ne $_.morale -and $null -ne $_.morale_cap })
    Check "nodes have morale" ($nodesWithMorale.Count -eq $state.data.map.nodes.Count)

    # composition
    $compJson = '{"week_no":1,"types":["cav","cav","shield"]}'
    $comp = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/slice/composition" -Headers $headers `
        -ContentType "application/json" -Body $compJson
    Check "set composition" (($comp.data.types -join ',') -eq 'cav,cav,shield')

    # play 3 cards
    $cards = $state.data.hand.cards
    $rows = @("front", "front", "back")
    for ($i = 0; $i -lt 3; $i++) {
        $orderJson = @{
            turn_id = $TurnId
            slot = $i
            card_code = $cards[$i]
            target_node_code = $Node
            lane = ($i + 1)
            row_pos = $rows[$i]
            request_key = "e2e_${TurnId}_${i}_$([guid]::NewGuid().ToString('N').Substring(0,8))"
        } | ConvertTo-Json -Compress
        $play = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/slice/order/play" -Headers $headers `
            -ContentType "application/json" -Body $orderJson
        Check "play slot $i" ($play.data.card_code -eq $cards[$i])
    }

    $state2 = Invoke-RestMethod -Uri "$BaseUrl/api/slice/state" -Headers $headers
    Check "3 card orders" ($state2.data.card_orders.Count -eq 3)

    # battle
    $battleJson = @{ turn_id = $TurnId; node_code = $Node; fire = $true } | ConvertTo-Json -Compress
    $battle = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/slice/battle/demo" -Headers $headers `
        -ContentType "application/json" -Body $battleJson
    Check "battle created" ($battle.data.battle_id -gt 0)
    Check "battle has units" ($battle.data.log.units.Count -ge 3)
    Check "battle has events" ($battle.data.log.events.Count -gt 0)
    Check "battle has result" ($null -ne $battle.data.log.result.score)

    # settle
    $settleJson = @{ battle_id = $battle.data.battle_id } | ConvertTo-Json -Compress
    $settle = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/slice/battle/settle" -Headers $headers `
        -ContentType "application/json" -Body $settleJson
    Check "settle returns morale" ($null -ne $settle.data.morale_after)
    Check "settle node matches" ($settle.data.node_code -eq $Node)

    # state after
    $state3 = Invoke-RestMethod -Uri "$BaseUrl/api/slice/state" -Headers $headers
    $node = $state3.data.map.nodes | Where-Object { $_.code -eq $Node }
    Check "node still exists" ($null -ne $node)
    $morale = [int]$node.morale
    $cap = [int]$node.morale_cap
    Check "morale in range" ($morale -ge 0 -and $morale -le $cap) "morale=$morale cap=$cap"

    # battle read back
    $read = Invoke-RestMethod -Uri "$BaseUrl/api/slice/battle?id=$($battle.data.battle_id)" -Headers $headers
    Check "battle read back" ($read.data.id -eq $battle.data.battle_id)
    Check "battle log replayable" ($read.data.log.events.Count -gt 0)

    Write-Host ""
    if ($failed -gt 0) {
        Write-Host "PHASE1_E2E FAIL ($failed)" -ForegroundColor Red
        exit 1
    }
    Write-Host "PHASE1_E2E PASS" -ForegroundColor Green
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
