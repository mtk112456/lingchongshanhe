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

### 1.2 重建测试库

```powershell
php server/slice/scripts/setup_test_db.php
```

期望：

```text
完成：{"games":1,"players":9,"students":8,"pets":8,"nodes":5,"turns":1}
```

### 1.3 启动 API

新开一个 PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File server/slice/start_api.ps1
```

期望：

```text
API: http://0.0.0.0:8080/api/health
```

### 1.4 查教师 PC 的局域网 IP

```powershell
(Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
  Select-Object -First 1).IPAddress
```

假设得到 `192.168.1.3`。

### 1.5 防火墙放行 8080

```powershell
New-NetFirewallRule -DisplayName "QingzhuSlice8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
```

### 1.6 APK 指向教师 PC

`client/Api.gd` 默认：

```gdscript
var base_url := "http://10.0.2.2:8080"
```

真实手机不能用 `10.0.2.2`。两种做法：

1. 打包前改成教师 PC 的 IP：

```gdscript
var base_url := "http://192.168.1.3:8080"
```

2. 或让学生首次打开时在设置里填 `192.168.1.3:8080`。

### 1.7 手机自检

在手机浏览器打开：

```text
http://192.168.1.3:8080/api/health
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
4. 点手牌 → 分配给队 1/2/3
5. 点城池 → 选目标 → 出令
6. 21:00 前可以撤回
```

只讲三句话：

```text
你每天只有 3 张令。
兵种相克：骑 > 盾 > 弓 > 枪 > 骑。
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
powershell -NoProfile -ExecutionPolicy Bypass -File tools/trial_teacher.ps1 -Action settle -TurnId 1
```

### 4.2 下一回合

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/trial_teacher.ps1 -Action next -TurnId 1
```

### 4.3 查看状态

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/trial_teacher.ps1 -Action status
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
| 手机连不上 API | 检查同一 Wi-Fi、IP、防火墙 8080 |
| 登录 401 | 姓名用显示名（青竹一），密码 slice2026 |
| 手牌只有 3 张 | 刷新 state；服务端发 4 张 |
| 出令 400 `CARD_NOT_IN_HAND` | 刷新页面重新取手牌 |
| 结算后民心没变 | 看 `battles` 是否为空；可能双方令数并列 |
| 第二回合打自己城 | 正常，返回 `already_owned`，不产生战斗 |
| 教师看不到结算按钮 | 用 `tools/trial_teacher.ps1` |

---

## 7. 数据导出

试跑后导出：

```sql
SELECT * FROM slice_order_slots ORDER BY turn_id, player_id, slot;
SELECT * FROM slice_battles ORDER BY turn_id, id;
SELECT * FROM slice_node_changes ORDER BY turn_id, node_code;
SELECT * FROM slice_turns ORDER BY turn_no;
```

保存为：

```text
trial_results/YYYYMMDD/
  orders.csv
  battles.csv
  changes.csv
  turns.csv
  observation.md
```

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
