# 自动验收巡检 · 每 30 分钟

> 目标：Agent 交付后不再靠“口头说完成”，机器先跑一遍硬检查。  
> 位置：`tools/watch_acceptance.ps1`  
> 报告：`tools/watch/STATUS.md`  
> 联系表：`tools/watch/contact_latest.jpg`

---

## 1. 它检查什么

| 检查 | 内容 |
|---|---|
| 后端 | PHP 14 项自动化验收 |
| 客户端 | Godot `ClientSmoke` |
| 回放 | Godot `ReplaySmoke` |
| 截图 | 平板 1400×1000、手机横屏 720×514（仅横屏） |
| 空面板 | S04 战报 / S05 回放内容量启发式 |
| 美术资产 | 5 城地标、6 班宠表情、UI Kit、横屏 `map_c.png`、竖屏 `map_c_portrait.png` |
| 交付 | APK 是否落后于客户端源码 |
| 工作区 | 未提交改动清单 |

它**不**替代：

- 视觉盲评；
- 真机 FPS / 冷启动；
- 触控手感；
- 12 城 / 4 周赛季内容验收。

---

## 2. 手动跑一次

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\watch_acceptance.ps1 -Once -Force
```

常用参数：

```text
-Once              只跑一轮
-Force             无视“无变化跳过”
-SkipCapture       不跑截图（快速查后端/冒烟）
-SkipResetDb       不重置测试库
-IntervalMinutes   循环模式间隔，默认 30
```

---

## 3. 安装 / 移除计划任务

安装：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\install_acceptance_watch.ps1
```

计划任务名：`QingzhuAcceptanceWatch`，每 30 分钟一次，只在当前用户登录时运行。

移除：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\install_acceptance_watch.ps1 -Remove
```

查看：

```powershell
Get-ScheduledTask -TaskName QingzhuAcceptanceWatch
Get-ScheduledTaskInfo -TaskName QingzhuAcceptanceWatch
```

---

## 4. 判定规则

- `PASS`：后端、冒烟、截图、资产全部通过，APK 不落后。
- `WARN`：硬检查通过，但 APK 过期或截图不新鲜。
- `FAIL`：任一硬检查失败，或截图缺失/空白，或资产规格不符。
- `UNSTABLE`：验收过程中源码发生变化（Agent 正在写），下一轮重跑。
- `NO_CHANGE`：源码/资产指纹没变，上一轮又是 PASS/WARN，跳过重跑。

只有 `PASS` / `WARN` 会跳过无变化轮次；`FAIL` 每轮都会重试。

---

## 5. 编码说明

- `watch_acceptance.ps1` 只输出 ASCII/英文控制台日志；
- 中文 `STATUS.md` 由 `tools/watch_report.py` 生成，固定 UTF-8 BOM；
- 避免 Windows PowerShell 5.1 直接写中文报告导致乱码。

---

## 6. 当前状态

- 计划任务已安装；
- 2026-11-10 00:54 全量验收：`PASS`；
- 后端 14/14，ClientSmoke / ReplaySmoke / 截图套件通过；
- APK 81.8 MB，已包含 C 横屏地图、C 竖屏地图、v2 地标。
