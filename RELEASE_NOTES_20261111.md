# 交付说明 · 2026-11-11

## 安装包

```text
client/build/android/qingzhu_slice.apk
137,656,612 字节
2026-11-11 14:32
SHA256 CA8DD672AC3E0348716EB3B2D1F154513DA1F528B7D96B96BED99C79CFDFCFF2
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

### P0 流程

```text
每天首次登录晨报 + 邸报 2 选 1
底部 5 Tab：沙盘 / 编成 / 日报+回放 / 小院 / 赛季
占长安或第 28 回合后进入赛季颁奖/史书页
正式版 07:00 自动开下一回合，教师可手动补开
```

### 美术与音频

```text
P0 三图：小院主场景、晨报送达、首令引导
小院房间：书房/练兵场/望楼 + 空白旗
三座城专属立绘：邺城/建业/成都
UI Kit：宣纸面板 + 红/蓝/确认按钮 + 资源图标
App 图标 + 横屏启动图
BGM：map 80s / battle 60s / season 30s，无缝循环，-16 LUFS
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
1. 真实服务器 / Cloudflare 域名未提供，部署包已就绪但未上线
2. 没有真实 8–12 名学生试跑，只有 bot 与 100 人模拟
3. 教师端公网可达，上线前建议加 Cloudflare Access 限制 /teacher
4. 战前预估卡与赛季 keyart 已接后端/资产，但客户端仍需最终视觉复核
5. BGM 为离线采样渲染，旋律偏朴素，下一步可换 ACE-Step 权重生成
6. 并发结算已加锁，但“结算中出令”窗口仍需 status=settling 彻底封死
```

---

## 下一步

```text
1. 真实学生 3 回合试跑
2. 修并发 settling 窗口
3. 战前预估/赛季页最终视觉复核
4. 部署到真实服务器 + Cloudflare Tunnel
5. 根据试跑数据调平衡
```
