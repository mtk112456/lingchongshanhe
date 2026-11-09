param(
    [Parameter(Mandatory = $true)][string]$MatchUrl,
    [Parameter(Mandatory = $true)][string]$ExpressionFile
)

$ErrorActionPreference = "Stop"
$targets = Invoke-RestMethod -Uri "http://127.0.0.1:16165/json/list" -TimeoutSec 5
$target = $targets | Where-Object { $_.url -like "*$MatchUrl*" } | Select-Object -First 1
if (-not $target) {
    throw "CDP target not found for: $MatchUrl"
}
$expression = Get-Content -Raw -LiteralPath $ExpressionFile
$payload = @{
    id = 1
    method = "Runtime.evaluate"
    params = @{
        expression = $expression
        returnByValue = $true
        awaitPromise = $true
    }
} | ConvertTo-Json -Depth 20 -Compress

$ws = [System.Net.WebSockets.ClientWebSocket]::new()
$ct = [System.Threading.CancellationToken]::None
$ws.ConnectAsync([Uri]$target.webSocketDebuggerUrl, $ct).Wait()
$bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
$ws.SendAsync([ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()

$buffer = New-Object byte[] 65536
$builder = New-Object System.Text.StringBuilder
do {
    $result = $ws.ReceiveAsync([ArraySegment[byte]]::new($buffer), $ct).Result
    [void]$builder.Append([System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count))
} while (-not $result.EndOfMessage)

$ws.Dispose()
$builder.ToString()
