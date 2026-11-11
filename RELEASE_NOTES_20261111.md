# 交付说明 · 2026-11-11

## 安装包

```text
client/build/android/qingzhu_slice.apk
124,053,704 字节
2026-11-11 10:27
SHA256 21B278B9963CEFE47405A0AAF5B1D83BF1CE5EFE5DFF9B492C1D98E81334D6B2
```

安装后首次打开：

```text
API 地址填教师 PC 的局域网地址，例如 http://192.168.1.3:8081
学生只填姓名 + 密码
教师用浏览器打开 http://192.168.1.3:8081/teacher
```

试跑账号：

```text
青竹一 ~ 青竹六 / slice2026
墨点一 ~ 墨点六 / slice2026
教师 teacher / teacher2026
```

---

## 这一版包含

### 地图与赛季

```text
12+1 城、19 条边、4 阵营
长安第 3 周开放，第 4 周只能打长安/邻城
28 回合、4 周赛季
区域 +5%、大营 +5%、关隘 +10%
混编 +5%、同兵种 +8% 攻 / -8% 防
```

### 个人反馈

```text
个人军功：出令 / 先锋 / 支援 / 侦察 / 火攻 / 破城 / 守城 / 驻守
个人战报：每条令的角色、伤害、破墙、贡献%
本周角色榜：先锋 / 支援 / 侦察 / 守城 / 火攻
```

### 文房小院

```text
S02 页面：书房 / 练兵场 / 望楼
升级消耗军功，只给便利和外观
书房预读、练兵场额外改编成、望楼侦察范围
势力足迹、本周太守、城池小旗
```

### 战斗

```text
3 路 × 前后排、4 兵种循环克制
12 张战术牌、器械攻墙、民心/易主
战前预估：破墙、战果、民心、克制、建议
战斗回放：VFX、逐队战术、战报
```

### 教师端

```text
Web 控制台：自动识别回合、倒计时、出令进度
阵营排名、13 城列表、军功榜、赛季史书
锁定 / 结算 / 下一回合
```

---

## 验收

后端：

```text
17 项 PASS
run.php 14 项基线 PASS
forecast / merit / estate / bulletin / formation / settlement / scout
adjacency / city_buff / region_bonus / season_rules / season28 / season100 / season_history
```

客户端：

```text
CLIENT_SMOKE PASS
REPLAY_SMOKE PASS
PHASE1_CLIENT_SMOKE PASS
ALL P1.5 VERIFICATIONS PASSED
S02_ESTATE_SUITE PASS
```

性能：

```text
12 城 100 人 300 令
p50 150.6ms / p95 162.2ms / max 162.2ms
```

---

## 已知缺口

```text
1. 文房小院主插画和 3 张房间图仍是占位图形，等 GPT 资产
2. 真实服务器 / Cloudflare 域名未提供，部署包已就绪但未上线
3. 没有真实 8–12 名学生试跑，只有 bot 与 100 人模拟
4. 教师端公网可达，上线前建议加 Cloudflare Access 限制 /teacher
5. 部分 UI Kit PNG 缺失，代码有回退，不崩溃但观感有差距
```

---

## 下一步

```text
1. GPT 交付文房小院 7 张资产
2. Antigravity 接 S01 战前军议
3. 真实学生 3 回合试跑
4. 部署到真实服务器 + Cloudflare Tunnel
5. 根据试跑数据调平衡
```
