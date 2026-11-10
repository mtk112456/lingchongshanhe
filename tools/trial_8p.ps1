# 8 人 × 3 回合模拟试跑
# 青竹一~四（bi） vs 墨点一~四（mo），5 节点
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/trial_8p.ps1
#   powershell ... -File tools/trial_8p.ps1 -Turns 3
#   powershell ... -File tools/trial_8p.ps1 -Reset
#
# -Reset  先重建测试库（推荐，避免上一轮残留）
# -Port   指定端口；默认自动选空闲端口

param(
    [string]$BaseUrl = "",
    [int]$Turns = 3,
    [int]$Port = 0,
    [switch]$Reset,
    [switch]$Trial
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$php = "C:\Users\MTK\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe"
$phpDir = Split-Path -Parent $php

if ($Trial) {
    $env:SLICE_CONFIG = Join-Path $root "server/slice/config.trial.php"
    Write-Host "== trial db =="
}

if ($Port -le 0) {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $Port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    $listener.Stop()
}
if ($BaseUrl -eq "") {
    $BaseUrl = "http://127.0.0.1:$Port"
}
if ($Reset) {
    Write-Host "== reset test db =="
    & $php -d "extension_dir=$phpDir\ext" -d extension=pdo_mysql (Join-Path $root "server/slice/scripts/setup_test_db.php") | Out-Host
}

$players = @(
    @{ name = "青竹一"; faction = "bi" },
    @{ name = "青竹二"; faction = "bi" },
    @{ name = "青竹三"; faction = "bi" },
    @{ name = "青竹四"; faction = "bi" },
    @{ name = "墨点一"; faction = "mo" },
    @{ name = "墨点二"; faction = "mo" },
    @{ name = "墨点三"; faction = "mo" },
    @{ name = "墨点四"; faction = "mo" }
)

function Login($name, $password) {
    $json = @{ name = $name; password = $password } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/auth/login" `
        -ContentType "application/json; charset=utf-8" `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($json))
}

$proc = $null
try {
    Write-Host "== start api =="
    $proc = Start-Process -FilePath $php `
        -ArgumentList @("-d", "extension_dir=$phpDir\ext", "-d", "extension=pdo_mysql", "-S", "127.0.0.1:$Port", "-t", "server/slice/public") `
        -WorkingDirectory $root -PassThru -WindowStyle Hidden

    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 300
        try {
            $h = Invoke-RestMethod "$BaseUrl/api/health" -TimeoutSec 2
            if ($h.ok) { $ready = $true; break }
        } catch { }
    }
    if (-not $ready) { throw "api not ready" }
    Write-Host "api ready"

    # 登录 8 个学生
    $sessions = @{}
    foreach ($p in $players) {
        $login = Login $p.name "slice2026"
        $sessions[$p.name] = @{ token = $login.data.token; faction = $p.faction }
        Write-Host "login $($p.name) / $($p.faction)"
    }

    # 教师
    $teacherJson = @{ username = "teacher"; password = "teacher2026" } | ConvertTo-Json -Compress
    $teacher = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/auth/admin-login" `
        -ContentType "application/json; charset=utf-8" `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($teacherJson))
    $teacherHeaders = @{ Authorization = "Bearer $($teacher.data.token)" }

    $firstHeaders = @{ Authorization = "Bearer $($sessions['青竹一'].token)" }
    $state = Invoke-RestMethod -Uri "$BaseUrl/api/slice/state" -Headers $firstHeaders
    $turnId = [int]$state.data.turn.id

    for ($turn = 1; $turn -le $Turns; $turn++) {
        Write-Host ""
        Write-Host "== Turn $turn (id=$turnId) =="

        # 主城固定 N2：4 笔 vs 3 墨；墨家第 4 人打 N1 侧城

        for ($pi = 0; $pi -lt $players.Count; $pi++) {
            $p = $players[$pi]
            $headers = @{ Authorization = "Bearer $($sessions[$p.name].token)" }
            $st = Invoke-RestMethod -Uri "$BaseUrl/api/slice/state" -Headers $headers
            $tid = [int]$st.data.turn.id

            # 第一回合设置编成，之后不再改
            if ($turn -eq 1) {
                $compTypes = @(
                    @("cav", "shield", "arc"),
                    @("shield", "spear", "arc"),
                    @("arc", "cav", "shield"),
                    @("spear", "arc", "cav")
                )[$pi % 4]
                $compJson = @{ week_no = 1; types = $compTypes } | ConvertTo-Json -Compress
                try {
                    Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/slice/composition" -Headers $headers `
                        -ContentType "application/json" -Body $compJson | Out-Null
                } catch { }
            }

            $cards = $st.data.hand.cards
            for ($i = 0; $i -lt 3; $i++) {
                # 每人 3 令分散到 3 座城；墨点四少出一令，制造 4v3 而不是全场平票
                if ($pi -eq 7 -and $i -eq 2) {
                    continue
                }
                $target = "N2"
                if ($p.faction -eq "mo" -and $pi -eq 7) {
                    $target = "N3"
                }
                $orderJson = @{
                    turn_id = $tid
                    slot = $i
                    card_code = $cards[$i]
                    target_node_code = $target
                    lane = ($i + 1)
                    row_pos = if ($i -eq 2) { "back" } else { "front" }
                    request_key = "t8_${turn}_${i}_" + [guid]::NewGuid().ToString("N").Substring(0, 12)
                } | ConvertTo-Json -Compress
                try {
                    Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/slice/order/play" -Headers $headers `
                        -ContentType "application/json" -Body $orderJson | Out-Null
                } catch {
                    Write-Host "  play failed: $($p.name) slot $i — $($_.Exception.Message)"
                }
            }
        }

        # 教师结算
        $settleJson = @{ turn_id = $turnId } | ConvertTo-Json -Compress
        $settle = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/slice/admin/card-settle" -Headers $teacherHeaders `
            -ContentType "application/json" -Body $settleJson
        Write-Host "battles: $($settle.data.battles.Count) already_settled: $($settle.data.already_settled)"
        foreach ($b in $settle.data.battles) {
            if ($null -eq $b.battle_id) {
                Write-Host ("  {0}: {1}" -f $b.node_code, $b.reason)
            } else {
                Write-Host ("  {0}: score={1} wall={2} morale {3}->{4} captured={5}" -f `
                    $b.node_code, $b.score, $b.wall, $b.morale_before, $b.morale_after, $b.captured)
                foreach ($team in @($b.teams)) {
                    if ($null -ne $team) {
                        Write-Host ("     {0,-6} lane {1} {2,-5} {3}" -f `
                            $team.type, $team.lane, $team.row, $team.card)
                    }
                }
            }
        }

        # 看地图
        $after = Invoke-RestMethod -Uri "$BaseUrl/api/slice/state" -Headers $firstHeaders
        $after.data.map.nodes | Select-Object code, name, morale, morale_cap, @{ n = "owner"; e = { $_.owner.code } } | Format-Table -AutoSize | Out-String | Write-Host

        # 下一回合
        if ($turn -lt $Turns) {
            $nextJson = @{ from_turn_id = $turnId } | ConvertTo-Json -Compress
            $next = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/slice/admin/next-turn" -Headers $teacherHeaders `
                -ContentType "application/json" -Body $nextJson
            $turnId = [int]$next.data.turn.id
        }
    }

    Write-Host ""
    Write-Host "TRIAL_8P PASS" -ForegroundColor Green
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        $conn | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
    }
}
