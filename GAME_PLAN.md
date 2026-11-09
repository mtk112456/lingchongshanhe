# 《青竹文房》独立游戏方案

> 面向初中学生的国风文房经营手游  
> 技术路线：Godot 4 独立 App（Android 优先，iOS 后续）  
> 积分对接：班级量化考核系统 `students.score` + `shop_orders` 可用积分账本  
> 版本：2026-11-09 调研稿

> **版本说明**：本文是 V1 经营模拟方案，仅保留作对比。  
> **引擎已改为 Godot 4.7.2，放弃 Cocos/微信小游戏。**  
> **总设计定稿是 [GAME_DESIGN_MASTER.md](GAME_DESIGN_MASTER.md)**：**中国地图 + 现有班宠 + 四阵营文脉战**，覆盖产品定位、核心循环、34 省地图、班宠接入、课堂模式、经济、内容、技术、MVP 与风险。  
> 策略层见 [GAME_DESIGN_STRATEGY.md](GAME_DESIGN_STRATEGY.md)：相邻/AP/姿态/防守队/侦察/奇观。  
> 经营层见 [GAME_DESIGN_MANAGEMENT.md](GAME_DESIGN_MANAGEMENT.md)：四坊专精/地区特产/相邻组合/订单/地盘政策/班级奇观。  
> **最新方向是 [GAME_DESIGN_WAR.md](GAME_DESIGN_WAR.md)**：**轻战争策略**——12 节点地图 + 四阵营 + 班宠将军 + 每日 3 军令 + 21:00 结算 + 4 周赛季。  
> **结构定稿是 [GAME_STRUCTURE_FINAL.md](GAME_STRUCTURE_FINAL.md)**：五层循环、系统结构、经济、界面、内容、留存、技术、美术外包 Brief。  
> **全套流程见 [GAME_FLOW_FULL.md](GAME_FLOW_FULL.md)**：赛季前 → 每日 → 每周 → 赛季末；课堂投票已取消，仅可选观赛。  
> **开发路线图见 [GAME_DEV_ROADMAP_GITHUB.md](GAME_DEV_ROADMAP_GITHUB.md)**：0–12 步，每步标注 GitHub 方案、自研部分和验收标准。  
> 地图+班宠详细版见 [GAME_DESIGN_MAP_PET.md](GAME_DESIGN_MAP_PET.md)；卡牌方案 [GAME_DESIGN_FINAL.md](GAME_DESIGN_FINAL.md) 保留作备选；技术路线见 [GAME_PLAN_V6.md](GAME_PLAN_V6.md)。

---

## 一、品牌与命名：青竹文房就是最好的游戏名

你已经有公众号和小程序「青竹文房」。如果游戏做的是“经营一家文房铺子”，这个名字不但能用，而且比另起一个名字更好：

- **学生一看就知道是做什么的**：文房四宝、笔墨纸砚、书房、国风；
- **家长和学校有信任感**：不像“游戏”，更像一个成长空间；
- **和现有品牌资产打通**：公众号、小程序、App 共用一个名字；
- **有画面感**：青竹、宣纸、墨香、窗棂、灯笼，天然适合做美术。

### 1. 建议的命名结构

| 层级 | 名称 | 用途 |
|---|---|---|
| 母品牌 | 青竹文房 | 公众号、小程序、家长认知、学校品牌 |
| 独立 App | 青竹文房 | 应用商店主名称 |
| App 副标题 | 文墨山河 | 应用商店副标题、启动页 |
| 游戏内标题 | 青竹文房 | 登录页、主界面 |
| 小程序 | 青竹文房（现有） | 查积分、看卡牌、每日签到，不做完整游戏 |

如果应用商店重名，可以用：

- `青竹文房·文墨山河`
- `青竹文房（游戏版）`
- `青竹文房：笔墨纸砚`

### 2. 为什么小程序和 App 要分开

- 小程序适合“轻”：查积分、看卡牌图鉴、每日签到、看班级排行；
- App 适合“重”：完整经营、制作动画、卡牌收集、店铺装饰；
- 小程序给 App 导流：签到领“文玉”，提示“去 App 看你的书院/铺子”；
- 避免小程序承担完整游戏包体和游戏类目/版号风险。

### 3. 要注意的事

1. 先查「青竹文房」商标注册情况，至少覆盖第 9 类（软件）、第 41 类（教育娱乐）、第 42 类（技术服务）；没有的话尽早申请。
2. 应用商店名称有长度限制，建议主标题「青竹文房」、副标题「文墨山河」。
3. 学生端文案不要写“充值”，写“兑换文玉”“注入文心”“领取文玉”；家长端明确写“不涉及任何真实货币支付”。
4. 如果未来要上微信小游戏，需要单独评估游戏类目、版号和支付合规；独立 App 先走 Android APK/应用商店，风险更小。

---

## 二、这类游戏在初中生中可玩性强吗

先说结论：**有可玩性，但不是“所有初中生一上手就停不下来”的类型。它更像“每天 3 分钟、越玩越有归属感”的养成游戏，而不是《蛋仔派对》《王者荣耀》那种即时刺激型游戏。**

### 1. 初中生现在喜欢什么

从近年校园和市场观察看，初中生群体里更强势的品类是：

- **强社交/竞技**：王者荣耀、和平精英、蛋仔派对、元梦之星；
- **开放世界/二次元**：原神、崩坏：星穹铁道；
- **沙盒/创造**：我的世界、迷你世界；
- **非对称/派对**：第五人格、蛋仔派对；
- **轻社交/美学**：光遇。

这些游戏的共同点是：**上手快、反馈快、能和朋友一起玩、有展示空间**。

### 2. 文房经营/卡牌收集的位置

「江南百景图」「忘川风华录」这类国风经营/收集游戏证明了这个品类有稳定受众，但它们的用户画像偏“喜欢国风、历史、美术、收集”的人群，不是所有初中生。它们的优势是：

- 美术好看，适合截图分享；
- 收集欲、养成感强；
- 每天收菜/升级，形成习惯；
- 有文化认同感。

劣势是：

- 前期节奏慢，容易“不知道干什么”；
- 内容消耗快，需要持续更新；
- 没有强社交时，容易变成单机种田；
- 对习惯快节奏竞技的学生，刺激不够。

### 3. 你的游戏靠什么赢

不要和商业大作比内容量。你的优势是**班级场景**，这是任何商业游戏都没有的：

| 商业游戏 | 你的游戏 |
|---|---|
| 全国玩家，陌生人社交 | 同班同学，真实关系 |
| 充值真钱 | 用课堂表现换积分 |
| 排行榜压力大 | 班级共同目标、互助 |
| 内容更新靠公司 | 老师可以结合课文/活动更新 |
| 玩完就忘 | 兑换真实奖励（文具、特权卡） |

所以，可玩性的关键不是“做得像江南百景图”，而是：

1. **3 分钟能完成一次有意义的事**：收材料、做一件文房、交付一个订单、抽一张卡，不要一上来让用户读大段文字；
2. **每天有可见变化**：铺子从空架子变成笔墨满墙，卡牌从 1 张变 10 张；
3. **有班级社交**：互访、点赞、共同完成班级大订单，让学生有“这是我们班”的感觉；
4. **有展示空间**：店铺一景、卡牌收藏、雅集作品，可以截图发朋友圈/班级群；
5. **有真实奖励**：和现有积分商城打通，游戏里的努力能换现实中的文具/特权；
6. **不逼氪、不逼肝**：没有真钱、没有体力限制、没有“不充值就落后”。

### 4. 建议先做一次小范围验证

在投入开发前，找 8–12 个学生做一次 30 分钟测试：

- 给他们看 3 张不同风格的文房铺概念图，问“最想点开哪张”；
- 用纸片/PPT 模拟“接订单→做笔墨→交付→解锁卡牌→装饰铺子”一轮，观察他们是否觉得无聊；
- 问“如果每天 3 分钟，你愿意连续玩一周吗？”；
- 问“你愿意用多少可用积分换一张卡/一个摆件？”；
- 记录：最喜欢哪个环节、哪里想跳过、会不会推荐给同学。

如果超过一半学生说“愿意每天玩”，再进入开发；如果大家只对抽卡感兴趣，说明需要加强经营和社交；如果大家觉得“像作业”，说明美术和反馈还不够“游戏”。

---

## 三、先给结论：做什么类型

**推荐：2D 国风文房经营 + 文人卡牌收集 + 轻社交/轻放置。**

一句话玩法：

> 你是江南小镇「青竹文房」的少年店主。课堂上挣来的可用积分可以兑换成“文玉”，用来采购笔墨纸砚、研制新配方、完成李白/苏轼/李清照等文人的订单，解锁他们的“文魂”卡牌与故事。你还可以装饰铺面、互访同学店铺、参加班级雅集。每一次背诵、阅读、听写，都会让青竹文房更有名气。

它不是“答题换皮”，而是把学习行为变成游戏里的生产力、收藏品和店铺成长。

### 1. 为什么是“文房铺子”，不是“书院”

| 维度 | 文房铺子 | 书院 |
|---|---|---|
| 品牌契合 | 「青竹文房」直接就是店名，天然一体 | 需要另起名字，品牌弱一点 |
| 核心循环 | 接单→制作→交付→升级，清楚、有成就感 | 建造→收菜→升级，偏慢 |
| 美术表现 | 笔墨纸砚、货架、灯笼、屏风，细节丰富 | 建筑和山水，偏大场景 |
| 学习结合 | 文人来订文房，顺手带出名句/课文 | 卡牌和建筑，结合稍间接 |
| 社交 | 互访店铺、班级大订单、雅集 | 互访书院、班级目标 |
| 扩展 | 新配方、新顾客、新文房、新季节 | 新建筑、新卡牌 |

**结论：文房铺子更适合「青竹文房」这个品牌，也更容易做出“每天想回来看看”的感觉。**

### 2. 不推荐的方向

| 方向 | 原因 |
|---|---|
| 卡牌对战 | 现有班宠已经是完整对战系统，重复建设 |
| 纯答题闯关 | 容易变成“作业 App”，缺乏美术与情感留存 |
| 开放世界 3D | 成本和性能风险过高，不适合个人/小团队 |
| 纯视觉小说 | 语文沉浸感强，但内容生产重、复玩率低，适合作为铺子里的“顾客故事”支线 |
| 抽卡赌博化 | 未成年学生 + 班级场景，必须避免真钱和赌博机制 |

---

## 四、GitHub 成熟方案调研

> 数据抓取时间：2026-11-09，星数为 GitHub API 返回值。许可证以仓库实际 LICENSE 为准，商用前必须复核。

### 1. 引擎/框架

| 项目 | Stars | License | 定位 | 建议 |
|---|---:|---|---|---|
| [godotengine/godot](https://github.com/godotengine/godot) | 119,833 | MIT | 完整 2D/3D 引擎，导出 Android/iOS | **首选** |
| [cocos/cocos-engine](https://github.com/cocos/cocos-engine) | 9,909 | NOASSERTION | 国产引擎，Cocos Creator 编辑器，微信小游戏生态强 | 备选；商用前核对条款 |
| [phaserjs/phaser](https://github.com/phaserjs/phaser) | 40,673 | MIT | HTML5 2D 游戏框架 | 备选；需 Capacitor 套壳 |
| [pixijs/pixijs](https://github.com/pixijs/pixijs) | 48,655 | MIT | WebGL 2D 渲染库 | 适合做渲染层，不是完整引擎 |
| [flame-engine/flame](https://github.com/flame-engine/flame) | 10,812 | MIT | Flutter 2D 游戏引擎 | 如果团队用 Flutter 可选 |
| [libgdx/libgdx](https://github.com/libgdx/libgdx) | 25,511 | Apache-2.0 | Java 跨平台游戏框架 | 老牌但开发效率不如 Godot |
| [defold/defold](https://github.com/defold/defold) | 6,458 | NOASSERTION | 轻量 2D/3D 引擎 | 可用，中文生态较小 |
| [renpy/renpy](https://github.com/renpy/renpy) | 6,998 | Ren'Py License | 视觉小说引擎 | 只适合剧情向支线 |

**推荐 Godot 4 的理由：**

1. **MIT 许可证**：免费、可商用、无分成，适合教育项目。
2. **文本化场景/脚本**：`.tscn` 和 `.gd` 都是文本，AI 可以直接生成、审查、改 diff，迭代效率高。
3. **2D 能力强**：TileMap、Parallax、Particles、Shader、AnimationPlayer、Spine/DragonBones 都能覆盖国风需求。
4. **导出独立 App**：Android 一键导出 APK/AAB；iOS 通过 Xcode 导出；不需要 WebView 套壳。
5. **包体小、性能稳**：2D 项目 APK 通常 30–60 MB，低端安卓也能跑 60fps。
6. **社区大**：119k stars，教程、插件、模板多，出问题容易搜到答案。

**Cocos Creator 什么时候更合适：**

- 你明确要同时发布**微信小游戏**；
- 你更习惯中文编辑器和 TypeScript；
- 你愿意接受编辑器工程文件对 AI 不够友好、商用条款需核对。

### 2. 可直接参考/复用的开源游戏模板

| 项目 | Stars | License | 能借鉴什么 | 注意 |
|---|---:|---|---|---|
| [godotengine/godot-demo-projects](https://github.com/godotengine/godot-demo-projects) | 9,763 | MIT | 官方 2D/3D/移动端示例 | 首选学习材料 |
| [db0/godot-card-game-framework](https://github.com/db0/godot-card-game-framework) | 1,415 | AGPL-3.0 | 卡牌手牌、拖拽、牌堆、规则脚本 | AGPL 有传染性，建议只参考思路，不直接复制代码 |
| [Kenny-Haworth/Harvest-Moon-2.0](https://github.com/Kenny-Haworth/Harvest-Moon-2.0) | 297 | MIT | 农场/生活模拟的种植、时间、体力、NPC | 像素风，可改国风 |
| [TinyTakinTeller/GodotProjectZero](https://github.com/TinyTakinTeller/GodotProjectZero) | 210 | NOASSERTION | 放置/增量游戏循环 | 先核对 LICENSE |
| [nathanhoad/godot_dialogue_manager](https://github.com/nathanhoad/godot_dialogue_manager) | 3,968 | MIT | 非线性对话、任务文本、分支 | 强烈推荐，做顾客故事/任务 |
| [peter-kish/gloot](https://github.com/peter-kish/gloot) | 992 | MIT | 背包、物品、格子 UI | 可选，做材料/道具 |
| [ChurchTao/Daoyou](https://github.com/ChurchTao/Daoyou) | 160 | GPL-3.0 | 国风修仙、水墨 UI、AIGC 内容管线 | 只做视觉/系统参考，不复制代码 |
| [ares5221/cocos-creator-game](https://github.com/ares5221/cocos-creator-game) | 306 | 未标注 | Cocos Creator 小游戏源码合集 | 若选 Cocos 可参考 |

### 3. 游戏后端（可选，第二阶段）

| 项目 | Stars | License | 用途 |
|---|---:|---|---|
| [heroiclabs/nakama](https://github.com/heroiclabs/nakama) | 13,689 | Apache-2.0 | 账号、钱包、排行榜、好友、聊天、锦标赛、云存档 |
| [colyseus/colyseus](https://github.com/colyseus/colyseus) | 7,523 | MIT | Node.js 多人房间/实时对战 |
| [pocketbase/pocketbase](https://github.com/pocketbase/pocketbase) | 61,603 | MIT | 单文件后端，适合快速原型 |

**建议：第一阶段不要上 Nakama。** 你的现有 PHP + MySQL 已经有人、班、积分、商城账本，直接加 `/api/game/*` 最省事。等做到班级互访、实时雅集、跨班排行榜，再评估 Nakama。

### 4. App 打包

| 方案 | 说明 |
|---|---|
| Godot Android 导出 | **推荐**。独立 APK/AAB，无 WebView，性能最好 |
| Godot iOS 导出 | 需要 Mac + Xcode + Apple Developer 账号（$99/年） |
| Capacitor 套壳 | 现有 App 已在用；适合 Phaser/PixiJS 路线，不适合作为 Godot 的替代 |
| 微信小游戏 | Godot 不支持；要小游戏就选 Cocos Creator |

---

## 五、积分对接：这是整个方案的关键

### 1. 现有系统的“可用积分”公式

已核对源码：`api/admin/shop/shop_helper.php` 的 `ShopHelper::calcStudentShopPoints()`：

```text
可用积分 = max(0, students.score - 100 - SUM(shop_orders.points_spent))
```

其中：

- `students.score` 是量化总分，基础 100 分；
- `shop_orders.points_spent` 是所有未取消订单的消费合计；
- 消费**不影响**量化总分和光荣榜排名，只减少“可用兑换分”；
- 现有商城、班宠结缘/道具都走这套账本。

### 2. 游戏充值怎么做才不破坏现有系统

**核心原则：游戏充值必须写进 `shop_orders`，不要直接改 `students.score`。**

流程：

1. 学生在 App 里选择兑换包，例如“10 可用积分 → 100 文玉”。
2. App 调用 `POST /api/game/recharge`。
3. 服务端在事务里：
   - 校验 Bearer Token；
   - `SELECT ... FOR UPDATE` 锁学生行；
   - 重新计算 `available_points`；
   - 校验每日上限、兑换包是否启用；
   - 插入 `shop_orders`：`type='game_recharge'`、`points_spent=10`、`status='completed'`；
   - 插入 `game_transactions`：`+100 文玉`；
   - 更新 `game_profiles.coins`；
   - 提交。
4. 因为 `shop_orders` 多了一条消费，现有商城和班宠页面会自动看到可用积分减少，**不需要改它们的代码**。
5. 学生端显示“可用积分 18 → 8，文玉 +100；不影响量化总分/排名”。

**注意：** `install.sql` 里 `shop_orders.type` 是 `enum('goods','blind_box')`，但班宠功能已经把它改成 `VARCHAR(50)`（见 `api/admin/pet_check_db.php`）。上线前必须先在测试库执行 `SHOW COLUMNS FROM shop_orders` 核实；如果仍是 enum，用与班宠相同的安全迁移改成 `VARCHAR(50)`，并先备份。

### 3. 登录/鉴权

现有学生登录是“姓名 + 密码”，成功后写 Session 和 90 天 Remember Cookie。独立 App 不适合依赖 Cookie，建议：

- 新增 `POST /api/game/auth/login`，复用现有 `students.password` 校验；
- 复用 `Auth::generateTokenHash($studentId, $passwordHash)` 生成 HMAC Token；
- App 用 `Authorization: Bearer <base64(studentId:hash)>` 调用游戏 API；
- 新增 `Auth::checkStudentToken()` 解析并校验 Token；
- 学生改密码后旧 Token 自动失效；
- App 把 Token 存 Android Keystore / iOS Keychain，不存明文密码。

### 4. 防作弊底线

- 所有“扣文玉/加文玉/制作/交付/抽卡/升级”必须服务端计算，客户端只发动作；
- 每个写操作带 `idempotency_key`，防重复提交；
- 事务 + 行锁，防并发双花；
- 每日兑换上限、教师总开关；
- 抽卡概率服务端随机，客户端只播动画；
- 游戏状态存服务端 `game_saves`，客户端本地只做缓存。

### 5. 学生端文案：不要叫“充值”

建议统一用：

- 兑换文玉
- 注入文心
- 领取文玉
- 文玉兑换

并在兑换页明确写：

> 本游戏不涉及任何真实货币支付，仅使用班级量化可用积分。  
> 兑换只减少“可用兑换分”，不影响你的量化总分、光荣榜排名和期末评价。

---

## 六、数据库设计（第一版）

> 新表全部以 `game_` 开头，不改现有业务表（`shop_orders.type` 迁移除外）。  
> 测试必须用独立测试班/测试库，禁止用真实学生积分做充值测试。

```sql
-- 游戏档案
CREATE TABLE game_profiles (
  student_id INT UNSIGNED PRIMARY KEY,
  season_id VARCHAR(20) NOT NULL DEFAULT '2026S1',
  level INT NOT NULL DEFAULT 1,
  exp INT NOT NULL DEFAULT 0,
  coins INT NOT NULL DEFAULT 0 COMMENT '文玉',
  prestige INT NOT NULL DEFAULT 0 COMMENT '文房声望',
  last_collect_at DATETIME NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_game_profile_student FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 游戏状态（铺面/工坊/卡牌/订单，JSON）
CREATE TABLE game_saves (
  student_id INT UNSIGNED PRIMARY KEY,
  version INT NOT NULL DEFAULT 1,
  state_json LONGTEXT NOT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_game_save_student FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 文玉流水（服务端权威）
CREATE TABLE game_transactions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  student_id INT UNSIGNED NOT NULL,
  type ENUM('recharge','reward','spend','refund','admin') NOT NULL,
  amount INT NOT NULL COMMENT '正负',
  balance_after INT NOT NULL,
  ref_type VARCHAR(30) NOT NULL DEFAULT '',
  ref_id VARCHAR(64) NOT NULL DEFAULT '',
  idempotency_key VARCHAR(64) NOT NULL DEFAULT '',
  note VARCHAR(200) NOT NULL DEFAULT '',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_idem (student_id, idempotency_key),
  KEY idx_student_time (student_id, created_at),
  CONSTRAINT fk_game_tx_student FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 兑换包配置
CREATE TABLE game_recharge_packs (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(30) NOT NULL UNIQUE,
  name VARCHAR(50) NOT NULL,
  points_cost INT NOT NULL,
  coin_amount INT NOT NULL,
  bonus_coin INT NOT NULL DEFAULT 0,
  daily_limit INT NOT NULL DEFAULT 0,
  enabled TINYINT NOT NULL DEFAULT 1,
  sort_order INT NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 游戏配置
CREATE TABLE game_config (
  config_key VARCHAR(50) PRIMARY KEY,
  config_value VARCHAR(500) NOT NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

第一版可以把铺面、工坊、卡牌、订单都放进 `game_saves.state_json`，由服务端读写和校验；等玩法稳定后再拆 `game_buildings`、`game_cards`。

---

## 七、API 设计（第一版）

```text
POST /api/game/auth/login
  body: { name, password }
  -> { token, student: { id, show_name, class_id, class_name } }

GET  /api/game/bootstrap
  header: Authorization: Bearer <token>
  -> { profile, wallet: { available_points, coins }, state, orders, tasks, config }

POST /api/game/recharge
  body: { pack_code, idempotency_key }
  -> { coins, available_points, tx_id }

POST /api/game/action
  body: { action: "craft|deliver|upgrade|summon|claim_task|decorate", payload, idempotency_key }
  -> { state, wallet, result }

GET  /api/game/tasks
  -> [ { code, title, progress, target, reward, status } ]

POST /api/game/tasks/claim
  body: { task_code, idempotency_key }
  -> { reward, wallet }

GET  /api/game/leaderboard?scope=class
  -> [ { rank, show_name, score, badge } ]
```

错误码建议：

```text
INVALID_TOKEN       登录失效
GAME_DISABLED       教师关闭了游戏
INSUFFICIENT_POINTS 可用积分不足
DAILY_LIMIT         超过每日兑换上限
VERSION_CONFLICT    存档版本冲突
INVALID_ACTION      非法动作
```

---

## 八、游戏内容设计（MVP）

### 1. 核心循环

```text
课堂表现/背诵/阅读/听写
        ↓
可用积分（现有系统）
        ↓ 兑换
      文玉
        ↓
采购材料 → 制作文房 → 交付订单
        ↓
解锁文人卡牌 / 新配方 / 新顾客
        ↓
装饰铺面 → 互访/雅集 → 班级共同订单
```

### 2. 铺面区域（首版 6 个）

| 区域 | 作用 | 升级产出 |
|---|---|---|
| 前厅 | 接待顾客、查看订单 | 订单数量/品质 |
| 制笔坊 | 制作毛笔 | 笔类配方/品质 |
| 墨坊 | 制作墨锭 | 墨类配方/品质 |
| 造纸坊 | 制作纸张 | 纸类配方/品质 |
| 砚台坊 | 制作砚台 | 砚类配方/品质 |
| 后院 | 装饰、互访、雅集 | 美观度、访客上限 |

> 首版可以只做“前厅 + 制笔坊 + 墨坊 + 后院”，纸/砚后续开放，降低美术量。

### 3. 文房四宝与配方

| 类别 | 示例 | 材料 |
|---|---|---|
| 笔 | 狼毫笔、兼毫笔、白云笔 | 竹杆、笔毛、丝线 |
| 墨 | 松烟墨、油烟墨、朱砂墨 | 松烟、桐油、胶、香料 |
| 纸 | 宣纸、澄心堂纸、梅花笺 | 檀皮、稻草、花汁 |
| 砚 | 歙砚、端砚、澄泥砚 | 砚石、刻刀、水 |

品质：普通 / 精良 / 稀有 / 传世。  
品质影响订单收益和卡牌碎片掉落，不影响学习进度。

### 4. 文人顾客与卡牌（首版 12 张）

建议首批：李白、杜甫、苏轼、李清照、辛弃疾、陶渊明、王维、曹操、鲁迅、朱自清、老舍、冰心。

每位文人包含：

- 立绘（国风半身/全身）；
- 名句；
- 一句话人物志；
- 一个“本命文房”（例如李白—酒壶笔洗、苏轼—东坡砚、李清照—梅花笺）；
- 一个“文心”被动（例如笔类订单收益 +5%、纸类订单 +5%、卡牌碎片 +2%）；
- 一条学习门槛（背完对应篇目/读完对应名著后才能升星）。

**订单示例：**

> 李白走进青竹文房：“我要一支能写尽山河的笔。”  
> 订单：交付「狼毫笔·精良」×1。  
> 奖励：文玉 +80，李白卡牌碎片 +5，解锁诗句“长风破浪会有时”。  
> 学习门槛：背诵《行路难》后，卡牌可升星。

### 5. 每日任务（读取现有数据）

| 任务 | 数据来源 | 奖励 |
|---|---|---|
| 今日背诵 1 篇 | `recite_pieces` / `recite_backfill_records` | 文玉 + 墨香 |
| 今日阅读 15 分钟 | `reading_quiz_records.session_status` / `reading_student_stats` | 文玉 + 卡牌碎片 |
| 今日听写满分/订正 | `dictation_scores.is_full_score` | 文玉 + 材料 |

> 注意：按 `AGENTS.md` 的提醒，阅读数据要用 `reading_quiz_records.session_status`、`reading_score_links.points`，不要照旧写 `passed/score`。任务完成必须服务端校验，不能信客户端。

### 6. 社交（第二阶段）

- 互访同学铺子，点赞“墨宝”；
- 每周“雅集”：全班共同目标，例如“本周全班完成 100 个订单 → 解锁班级限定匾额/竹林装饰”；
- 班级大订单：需要全班一起交付材料，完成后全班获得限定奖励；
- 排行榜用 `show_name`，默认只显示班级内，避免真实姓名外泄；
- 不做“付费冲榜”，排行榜按声望/收藏/订单完成度，不按兑换额。

### 7. 美术方向

- **关键词**：新国风、水墨、青绿山水、宣纸、卷轴、窗棂、灯笼、印章、鎏金描边；
- **主色**：墨蓝 `#1e3a5f`、青绿 `#276f57`、朱砂 `#b83b32`、琥珀 `#cf8325`、宣纸 `#f6efe2`；
- **字体**：思源宋体 / Noto Serif SC（OFL，可商用）做标题，系统黑体做正文；
- **场景**：2D 横向铺面，前景货架/柜台，中景工坊，远景江南街市/竹林，支持昼夜/雨雪；
- **卡牌**：512×768 竖版，稀有度描边+粒子，翻牌动画；
- **UI**：9-slice 卷轴/册页面板，印章按钮，竖排标题；
- **彩蛋**：现有班宠「小青竹」「墨点精」可以作为铺子吉祥物/助手，不用重做角色，学生有熟悉感；
- **音频**：古琴/竹笛环境音，毛笔/翻页/风铃音效；使用 CC0 或自制，保留授权记录。

### 8. 经济数值（示例，可配置）

| 项目 | 数值 |
|---|---|
| 兑换比例 | 1 可用积分 = 10 文玉 |
| 兑换包 | 10 分 → 100 文玉；30 分 → 330；60 分 → 720 |
| 每日兑换上限 | 20 分（教师可改） |
| 每日任务奖励 | 20–40 文玉 |
| 工坊升级 | 100–800 文玉 |
| 卡牌单抽 | 120 文玉；十连 1080（保底 1 张稀有） |
| 重复卡牌 | 转 10–30 碎片，用于升星 |

> 首版建议**直接卖卡包或明码标价**，不做复杂抽卡；如果做抽卡，必须在游戏内公示概率和保底规则。  
> 即使不花一分可用积分，靠每日任务也能在 1–2 周内解锁第一批卡牌和装饰，保证不花钱的学生也能玩。

---

## 九、开发路线图

### 阶段 0：垂直切片（1–2 周）

目标：让老师在手机上看到“美术方向 + 核心手感”，不接真实数据。

- Godot 4 项目骨架；
- 1 个文房铺场景（远景/中景/前景视差）；
- 前厅 + 制笔坊 + 墨坊 + 后院 4 个区域；
- 1 位顾客（李白）+ 1 个订单 + 1 次制作 + 1 张卡牌解锁；
- 中文 UI + 思源宋体；
- 本地假数据钱包/兑换；
- Android APK。

### 阶段 1：可玩 MVP（3–4 周）

- 登录 + Bearer Token；
- 真实可用积分读取；
- 兑换写 `shop_orders` + `game_transactions`；
- 6 区域、12 卡牌、3 每日任务；
- 服务端存档；
- 教师后台开关/上限/流水；
- 测试班试点。

### 阶段 2：班级社交（2–3 周）

- 互访/点赞；
- 班级大订单；
- 雅集排行榜；
- 季节活动；
- 美术扩展。

### 阶段 3：打磨与发布

- 低端安卓性能优化；
- iOS 打包；
- 新手引导；
- 无障碍/防沉迷/隐私说明；
- 班级正式上线。

---

## 十、红线与风险

### 必须坚持

1. **不接真钱**：只消耗班级可用积分，不接微信/支付宝/应用内购买。
2. **不影响总分**：游戏消费只动 `shop_orders` 可用分，不改 `students.score`，不影响光荣榜和期末评价。
3. **不赌博**：不诱导抽卡，公示概率，设置保底；最好首版直接明码兑换。
4. **每日上限**：教师可设每日/每周兑换上限，防止冲动消费。
5. **教师总开关**：一键关闭游戏，不影响现有教学系统。
6. **数据隔离**：测试用独立测试班/测试库；真实学生数据只读；上线前备份。
7. **不公开真实姓名**：排行榜用 `show_name`，默认班级内可见。
8. **不抄袭**：不复制《江南百景图》《忘川风华录》等商业游戏的素材/UI；开源代码先看 LICENSE（AGPL/GPL 慎用）。

### 主要风险

| 风险 | 应对 |
|---|---|
| 美术工作量大 | 先做垂直切片；AI 出图 + 人工统一风格；首版只做 4 区域/12 卡 |
| 学生作弊 | 服务端权威经济；不信任客户端；关键动作带幂等键 |
| 低端安卓卡顿 | 纹理图集、对象池、限制粒子、目标 60fps |
| 内容消耗快 | 季节活动 + 卡牌升星 + 班级共同订单；但不要用“体力”逼氪 |
| 家长/学校质疑 | 明确“零真钱、零广告、积分来自课堂表现、教师可控” |
| 版权/字体/音乐 | 只用 OFL/CC0/自制素材；保留授权记录 |
| 学生把积分花光后悔 | 兑换前二次确认；每日上限；教师后台可撤销/补偿；首版可加 10 分钟反悔期 |

---

## 十一、下一步建议

**先验证，再开发；先垂直切片，不要一上来做完整游戏。**

### 建议顺序

1. **出 3 个美术方向**：
   - 宋韵街市：暖宣纸、木柜台、灯笼、烟雨街市；
   - 青绿竹林：冷青绿、竹影、水墨远山、清雅；
   - 唐风重彩：朱砂、鎏金、华丽屏风、盛唐气象。
2. **找 8–12 个学生投票 + 纸片原型试玩**；
3. **选一个方向，做 Godot 垂直切片**（1–2 周）；
4. **切片通过后，再接测试班积分 API**；
5. **最后才是完整 MVP 和班级上线**。

### 垂直切片只需要回答三个问题

1. 这种文房铺子的美术，你和学生是否真的喜欢？
2. 手机上的接单/制作/交付/翻牌手感是否顺畅？
3. 积分兑换文玉的流程是否清楚、没有心理负担？

切片通过后，再投入做完整 MVP。

---

## 十二、参考资料

- 现有系统入口：`D:\DeskBox\班级量化考核系统\AGENTS.md`
- 班宠规则：`docs/handover/PET_SYSTEM.md`
- 积分计算：`api/admin/shop/shop_helper.php` → `calcStudentShopPoints()`
- 商城兑换：`api/student/shop/exchange.php`
- 学生登录：`api/student/login.php`
- 设计系统：`DESIGN.md`、`PRODUCT.md`
- Godot 官方：https://github.com/godotengine/godot
- Godot 示例：https://github.com/godotengine/godot-demo-projects
- Godot 对话系统：https://github.com/nathanhoad/godot_dialogue_manager
- 卡牌框架：https://github.com/db0/godot-card-game-framework
- 农场模拟参考：https://github.com/Kenny-Haworth/Harvest-Moon-2.0
- 游戏后端：https://github.com/heroiclabs/nakama
