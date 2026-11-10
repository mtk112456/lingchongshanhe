# 8–12 人三回合试跑手册

> 目标：用 5 节点切片验证“3 张将令 + 4 兵种 + 3×2 战斗 + 民心易主”。
> 对象：8–12 名学生，1 名教师。
> 时间：技术准备 30 分钟 + 学生上手 5 分钟 + 3 回合 × 10 分钟 + 复盘 10 分钟。

---

## 0. 试跑目标

```text
1. 第三回合 ≥ 60% 学生主动下令
2. ≥ 70% 学生能解释上一条战斗结果
3. ≥ 50% 学生想再来一回合
4. 教师每天操作 < 5 分钟
```

---

## 1. 试跑前 30 分钟（技术）

### 1.1 启动 MariaDB

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File server/slice/start_mariadb.ps1
```

保持这个窗口不要关。

### 1.2 重建试跑库（独立于冒烟测试）

```powershell
$env:SLICE_CONFIG = "$PWD\server\slice\config.trial.php"
php server/slice/scripts/setup_test_db.php
```

期望：

```text
完成：{"games":1,"players":9,"students":8,"pets":8,"nodes":5,"turns":1}
```

试跑用 `qingzhu_slice_trial`，不会和客户端 smoke / E2E 的 `qingzhu_slice_test` 互相重置。

### 1.3 启动试跑 API

新开一个 PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File server/slice/start_trial_api.ps1 -Bind 0.0.0.0 -Port 8081
```

期望：

```text
Trial config: ...\config.trial.php
Trial API: http://0.0.0.0:8081/api/health
```

### 1.4 查教师 PC 的局域网 IP

```powershell
(Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
  Select-Object -First 1).IPAddress
```

假设得到 `192.168.1.3`。

### 1.5 防火墙放行 8081

```powershell
New-NetFirewallRule -DisplayName "QingzhuSlice8081" -Direction Inbound -Protocol TCP -LocalPort 8081 -Action Allow
```

### 1.6 APK 指向教师 PC

`client/Api.gd` 默认：

```gdscript
var base_url := "http://10.0.2.2:8081"
```

真实手机不能用 `10.0.2.2`。两种做法：

1. 打包前改成教师 PC 的 IP：

```gdscript
var base_url := "http://192.168.1.3:8081"
```

2. 或让学生首次打开时在设置里填 `192.168.1.3:8081`。

### 1.7 手机自检

在手机浏览器打开：

```text
http://192.168.1.3:8081/api/health
```

看到：

```json
{"ok":true,...}
```

再进 App。手机和 PC 必须在同一个 Wi-Fi。

---

## 2. 学生 3 分钟上手

```text
1. 打开 App，输入姓名 + 密码
   青竹一~四、墨点一~四 / slice2026
2. 进 S03 编成，选 3 个兵种，确认
3. 回地图，看底部 4 张手牌
4. 点手牌 → 选队 1/2/3 → 选路 1/2/3 → 选前/后
5. 点城池 → 选目标 → 出令
6. 想再看一眼敌情：先出「哨探」，再点情报
7. 21:00 前可以撤回
```

只讲四句话：

```text
你每天只有 3 张令，一张令就是一支队伍。
兵种相克：骑 > 盾 > 弓 > 枪 > 骑。
牌会真的改战斗：坚壁加防、火攻加攻城、夜袭怕哨探。
打不下来不是输了，是民心还没推满。
```

---

## 3. 三回合流程

### 回合 1（10 分钟）

```text
学生：编成 → 抽牌 → 出 3 令
教师：确认所有人都出了令
教师：POST /api/slice/admin/card-settle
学生：看回放/战报
```

观察：

- 有没有人选 3 个相同兵种；
- 有没有人问“为什么打不下来”；
- 有没有人不会拖牌。

### 回合 2（10 分钟）

```text
学生：看昨日战报 → 调整编成/目标 → 出 3 令
教师：settle
学生：看民心变化
```

观察：

- 是否有人因为战报改目标；
- 是否有人主动说“今天打哪”。

### 回合 3（10 分钟）

```text
学生：互打对方已占城
教师：settle
```

观察：

- 主动下令率；
- 能否解释“为什么没打下来”；
- 是否想再来。

---

## 4. 教师操作

### 4.1 卡牌结算

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/trial_teacher.ps1 -BaseUrl http://127.0.0.1:8081 -Action settle -TurnId 1
```

### 4.2 下一回合

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/trial_teacher.ps1 -BaseUrl http://127.0.0.1:8081 -Action next -TurnId 1
```

### 4.3 查看状态

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/trial_teacher.ps1 -BaseUrl http://127.0.0.1:8081 -Action status
```

---

## 5. 观察表

每个学生一行：

| 学生 | 回合 1 出令 | 回合 2 出令 | 回合 3 出令 | 能解释结果 | 想再来 | 备注 |
|---|---|---|---|---|---|---|
| 青竹一 |  |  |  |  |  |  |
| 青竹二 |  |  |  |  |  |  |
| 青竹三 |  |  |  |  |  |  |
| 青竹四 |  |  |  |  |  |  |
| 墨点一 |  |  |  |  |  |  |
| 墨点二 |  |  |  |  |  |  |
| 墨点三 |  |  |  |  |  |  |
| 墨点四 |  |  |  |  |  |  |

教师记录：

```text
学生总时长：
教师总时长：
最常问的问题：
最卡的一步：
有没有人中途放弃：
```

---

## 6. 常见问题

| 问题 | 处理 |
|---|---|
| 手机连不上 API | 检查同一 Wi-Fi、IP、防火墙 8081 |
| 登录 401 | 姓名用显示名（青竹一），密码 slice2026 |
| 手牌只有 3 张 | 刷新 state；服务端发 4 张 |
| 出令 400 `CARD_NOT_IN_HAND` | 刷新页面重新取手牌 |
| 结算后民心没变 | 看 `battles` 是否为空；可能双方令数并列 |
| 打自己城 | 变成驻守：该城守方用你的队伍；没有敌军时不产生进攻战斗 |
| 教师看不到结算按钮 | 用 `tools/trial_teacher.ps1` |
| 出了令但没战斗 | 看回执：`standoff`（平票）、`already_owned`（己方城）、`no_vanguard`（无先锋） |
| 牌好像没生效 | 看战报逐队那一行；确认客户端已接 P1.5（手牌有去向、战报有牌名） |
| 哨探打不开情报 | 先对这座城打出「哨探」；没哨探接口返回 403 |
| 第 2 周编成没变 | 服务端按回合推导周次（7 回合一周），确认回合号已推进 |

---

## 7. 数据导出

试跑后一条命令：

```powershell
$env:SLICE_CONFIG = "$PWD\server\slice\config.trial.php"
php server/slice/scripts/export_trial.php
```

输出：

```text
trial_results/YYYYMMDD_HHMMSS/
  orders.csv
  battles.csv
  changes.csv
  turns.csv
  nodes.csv
  compositions.csv
  summary.json
  observation.md
```

`summary.json` 含场次、战斗数、易主数、学生数；
`observation.md` 已带 8 人观察表，可直接打印或填写。

---

## 8. 通过 / 失败标准

通过：

```text
第三回合主动下令 ≥ 60%
能解释结果 ≥ 70%
想再来 ≥ 50%
教师 < 5 分钟
无阻断性 bug
```

失败先改：

```text
出令太复杂 → 简化手牌分配
看不懂战报 → 改折页
打不下来 → 调城墙/民心
教师操作多 → 加一键结算
```

不达标不扩 12 城美术。
