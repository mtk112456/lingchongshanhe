# 精简 awesome-gamedev-agent-skills 的自动展示范围
#
# 用途：77 个技能全部保留（可按 ID 显式加载），但把非 Godot 引擎从
#       “每轮自动广告”里摘掉，减少上下文噪音。
#
# 用法：
#   powershell -File tools/prune_gamedev_skills.ps1 -Find
#   powershell -File tools/prune_gamedev_skills.ps1 -Root "C:\Users\MTK\.agents\skills"
#   powershell -File tools/prune_gamedev_skills.ps1 -Root "..." -Undo
#   powershell -File tools/prune_gamedev_skills.ps1 -Root "..." -WhatIf

param(
    [string]$Root,
    [switch]$Undo,
    [switch]$WhatIf,
    [switch]$Find,
    [string[]]$Drives = @("C:", "D:")
)

$ErrorActionPreference = "Stop"

# 本机不用的引擎技能：保留文件，只关自动展示。
$hideNames = @(
    # Unity 8
    "unity-csharp-scripting", "unity-input-system", "unity-physics", "unity-animation",
    "unity-scriptableobjects", "unity-tilemap-2d", "unity-navmesh", "unity-build-pipeline",
    # Unreal 6
    "unreal-blueprints", "unreal-cpp-gameplay", "unreal-enhanced-input",
    "unreal-behavior-trees", "unreal-niagara", "unreal-packaging",
    # Ebitengine 1
    "ebitengine-game",
    # Web engines 6
    "phaser-core", "phaser-arcade-physics", "pixijs-rendering",
    "threejs-scene-setup", "threejs-gltf-loading", "threejs-materials-lighting",
    # 其他引擎 12
    "bevy-ecs", "pygame-core", "love2d-core", "defold-core",
    "roblox-luau", "roblox-datastores", "roblox-ui", "roblox-networking",
    "roblox-characters", "roblox-physics", "roblox-studio-workflow", "roblox-simulator-economy"
)

if ($Find) {
    Write-Host "扫描 gamedev skills 安装位置（原生 dir，较慢但覆盖全盘）..."
    foreach ($d in $Drives) {
        Write-Host "=== $d ==="
        $out = cmd /c "dir /s /b /ad $d\godot-2d-movement 2>nul"
        if ($LASTEXITCODE -eq 0 -and $out) {
            foreach ($line in $out) {
                $dir = Split-Path $line -Parent          # .../skills/godot
                $skillsRoot = Split-Path $dir -Parent    # .../skills
                Write-Host ("命中：{0}" -f $line)
                Write-Host ("技能根：{0}" -f $skillsRoot)
            }
        } else {
            Write-Host "未命中"
        }
    }
    return
}

if (-not $Root) {
    throw "需要 -Root，或先用 -Find 定位。"
}
if (-not (Test-Path $Root)) {
    throw "技能目录不存在：$Root"
}

function Get-FrontmatterEnd {
    param([string[]]$Lines)
    if ($Lines.Count -lt 3 -or $Lines[0].Trim() -ne "---") { return -1 }
    for ($i = 1; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim() -eq "---") { return $i }
    }
    return -1
}

$changed = 0
$skipped = 0

Get-ChildItem $Root -Recurse -Filter "SKILL.md" -File | ForEach-Object {
    $id = $_.Directory.Name
    if ($hideNames -notcontains $id) { return }

    $file = $_.FullName
    $lines = [System.IO.File]::ReadAllLines($file)
    $end = Get-FrontmatterEnd -Lines $lines
    if ($end -lt 0) {
        Write-Warning "跳过（frontmatter 异常）：$file"
        $skipped++
        return
    }

    $head = $lines[0..$end]
    $hasFlag = ($head -match '^\s*opencode/autoinvoke:\s*false\s*$').Count -gt 0

    if ($Undo) {
        if (-not $hasFlag) { return }
        $out = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '^\s*opencode/autoinvoke:\s*false\s*$') { continue }
            if ($line -match '^\s*metadata:\s*$') {
                # metadata 下若只剩空行/无缩进键，就整块删掉
                $next = if ($i + 1 -lt $lines.Count) { $lines[$i + 1] } else { "" }
                if ($next -notmatch '^\s+\S') { continue }
            }
            $out.Add($line)
        }
        $new = $out.ToArray()
    } else {
        if ($hasFlag) { return }
        $out = New-Object System.Collections.Generic.List[string]
        $out.AddRange([string[]]$lines[0..($end - 1)])
        if (($head -match '^\s*metadata:\s*$').Count -gt 0) {
            $out.Add("  opencode/autoinvoke: false")
        } else {
            $out.Add("metadata:")
            $out.Add("  opencode/autoinvoke: false")
        }
        $out.AddRange([string[]]$lines[$end..($lines.Count - 1)])
        $new = $out.ToArray()
    }

    if ($WhatIf) {
        Write-Host ("[WhatIf] {0}" -f $id)
    } else {
        $enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllLines($file, $new, $enc)
        Write-Host ("[OK] {0}" -f $id)
    }
    $changed++
}

Write-Host ""
Write-Host ("目录：{0}" -f $Root)
Write-Host ("模式：{0}" -f $(if ($Undo) { "恢复自动展示" } else { "关闭自动展示" }))
Write-Host ("处理：{0} 个，跳过：{1} 个" -f $changed, $skipped)
