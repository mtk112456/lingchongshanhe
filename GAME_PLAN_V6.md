# 《青竹文房》V6：Cocos Creator 跨平台游戏（已作废）

> 目标：一款游戏，独立 App，最后能转微信小游戏；课堂模式不打印、学生不带手机  
> 一套代码，三个构建：Android/iOS App + 微信小游戏 + Web 课堂大屏  
> 技术路线：Cocos Creator 3.8 LTS + TypeScript + 现有 PHP/MySQL  
> 积分对接：沿用 `ShopHelper::calcStudentShopPoints()` + `shop_orders` 账本

> **已作废**：引擎已改为 **Godot 4.7.2**，不做微信小游戏。  
> 本文仅作历史参考，不再作为开发依据。  
> **最终定稿**：玩法、卡牌规则、班级层、课堂模式、首版内容量已收敛到 [GAME_DESIGN_FINAL.md](GAME_DESIGN_FINAL.md)。

---

## 一、先说结论：引擎必须换

你要同时满足：

1. 独立 App（Android/iOS）；
2. 以后转微信小游戏；
3. 老师电脑上的 Web 课堂大屏；
4. 一套代码，不要做三遍。

**Godot 不满足第 2 点。** Godot 没有官方微信小游戏导出，社区方案不成熟，后面会踩大坑。

**推荐：Cocos Creator 3.8 LTS。**

| 能力 | Cocos Creator | Godot | LayaAir | Phaser/PixiJS |
|---|---|---|---|---|
| Android/iOS App | ✅ 官方 | ✅ | ✅ | 需 Capacitor |
| 微信小游戏 | ✅ 官方 | ❌ 无官方 | ✅ | 需适配层 |
| Web 课堂大屏 | ✅ | ✅ | ✅ | ✅ |
| TypeScript | ✅ | ❌ GDScript | ✅ | ✅ |
| 2D 卡牌/UI | ✅ 强 | ✅ 强 | ✅ | ✅ |
| 中文生态/文档 | ✅ 强 | 一般 | 强 | 一般 |
| AI 改代码 | ✅ TS 易改 | ✅ 文本场景 | ✅ | ✅ |

> Cocos Creator 引擎开源、编辑器免费；商用前核对 Cocos 许可条款。  
> 不要用 Godot 做微信小游戏，也不要用普通小程序硬塞完整游戏。

---

## 二、微信“小程序”还是“小游戏”？

你说“转为小程序”，这里要分清：

| 形态 | 能不能跑完整游戏 | 建议 |
|---|---|---|
| **微信小游戏** | ✅ 可以，Cocos 直接导出 | **游戏本体用这个** |
| **微信小程序** | 只能放轻量 H5/Canvas，包体和性能受限 | 做“查积分/看卡牌/进游戏”的入口 |
| 小程序 `web-view` 套 H5 | 受域名/类目限制，游戏容易被拒 | 不推荐 |

**建议结构：**

```text
青竹文房（现有小程序）
   ├─ 查积分 / 看卡牌 / 每日签到
   └─ 按钮：进入「青竹文房」小游戏
          ↓
   微信小游戏（Cocos 导出）
          ↓
   和独立 App 共用同一套后端/账号/进度
```

- 游戏本体：**微信小游戏**；
- 现有小程序：**入口 + 工具**，不塞完整游戏；
- 独立 App：**主游戏**，体验最好；
- 三者共用 PHP/MySQL 后端。

> 微信小游戏需要单独 AppID/类目，可能涉及版号/合规；以微信官方最新要求为准，先做 Android App + Web，小游戏作为第二阶段。

---

## 三、一套代码，三个构建

```text
Cocos Creator 项目
├─ assets/
│  ├─ core/            战斗、卡牌、经济、任务（纯 TS，跨端）
│  ├─ scenes/
│  │  ├─ Home.scene        主城/青竹文房
│  │  ├─ CardRun.scene     卡牌 Roguelike
│  │  ├─ Shop.scene        店铺/装饰
│  │  ├─ Classroom.scene   老师大屏课堂模式
│  │  └─ Login.scene
│  ├─ platform/
│  │  ├─ app.ts            Android/iOS 适配
│  │  ├─ wechat.ts         微信小游戏适配
│  │  └─ web.ts            Web 课堂适配
│  └─ data/                卡牌/敌人/事件 JSON
├─ build/
│  ├─ android/             APK/AAB
│  ├─ ios/                 Xcode 工程
│  ├─ wechatgame/          微信小游戏
│  └─ web-desktop/         老师电脑浏览器
```

### 三个构建分别怎么用

| 构建 | 谁用 | 场景 |
|---|---|---|
| Android/iOS App | 学生 | 回家玩卡牌、店铺、每日任务 |
| 微信小游戏 | 学生/家长 | 不想装 App，微信里直接玩轻量版 |
| Web Desktop | 老师 | 教室电脑/投影，5 分钟课堂模式 |

**核心逻辑只写一遍**，平台差异用 adapter 隔离：

- 登录：App 用姓名+密码；微信小游戏用 `wx.login` + 绑定；Web 用老师账号；
- 存储：App 用本地文件/安全存储；微信小游戏用 `wx.setStorageSync`；Web 用 localStorage；
- 分享：App 用系统分享；微信小游戏用 `wx.shareAppMessage`；Web 不需要；
- 支付：全部不接真钱，所以不用适配支付。

---

## 四、游戏本体：卡牌 Roguelike + 班级世界

### 家庭端（App/小游戏）

- 5–8 分钟一局卡牌 Roguelike；
- 3 场战斗 + 1 精英 + 1 Boss；
- 20 张卡、6 种敌人、1 个 Boss（首版）；
- 店铺养成、卡牌收集、每日任务；
- 每日同卷、每周文魔、班级进度；
- 积分兑换文玉（只买好看，不买战力）。

### 课堂端（Web 大屏）

- 5 分钟，不打印，不发卡，不装学生端；
- 大屏出事件，三个选项；
- 学生举手/站立/小组讨论投票；
- 老师点选，结算班级进度；
- 和家庭端共用同一个班级目标。

```text
课堂投票 → 本周班级方向
   ↓
家庭卡牌/店铺 → 贡献文心/材料/美观
   ↓
同一个班级进度条 / 同一个文魔
```

### 为什么这个组合能全员参与

- 课堂：举手/站立/讨论，人人能参与，不需要手机；
- 家庭：想深入的学生玩卡牌，不想玩的学生不强制；
- 班级目标：需要多种贡献，不是只靠核心玩家；
- 老师：5 分钟、三个按钮、零打印；
- 小程序：降低安装门槛，家长也能看到。

---

## 五、微信小游戏的硬约束

| 约束 | 影响 | 应对 |
|---|---|---|
| 包体限制（主包约 4MB，总包约 20MB，以官方最新为准） | 不能把所有卡图/音频塞进包 | 远程资源/CDN + Asset Bundle + 分包 |
| 性能低于原生 App | 粒子/Shader 要克制 | 2D、图集、对象池、限制同屏特效 |
| 不能实时联机 | 课堂不能靠学生手机 | 课堂用老师大屏；家庭异步 |
| 登录体系不同 | 不能直接用 App 的账号 | `wx.login` + 后端绑定学生 |
| 类目/版号/审核 | 可能被拒 | 先做 App/Web，小游戏第二阶段；不接真钱 |
| 分享/裂变限制 | 不能诱导分享 | 只做正常班级邀请/卡牌分享 |

**首版小游戏只做：**

- 登录/绑定；
- 卡牌单局；
- 每日任务；
- 班级进度；
- 卡牌图鉴。

**暂不做：**

- 店铺 3D；
- 实时联机；
- 复杂社交；
- 真钱支付/广告。

---

## 六、登录与积分

### 登录

- **App**：姓名 + 密码 → `POST /api/game/auth/login` → Bearer Token；
- **微信小游戏**：`wx.login` → code → 后端 `jscode2session` → openid → 绑定学生（姓名+密码/班级码）；
- **Web 课堂**：老师账号登录，选择班级；
- Token 存平台安全存储，不存明文密码。

### 积分

```text
可用积分 = max(0, students.score - 100 - SUM(shop_orders.points_spent))
```

- 游戏兑换写 `shop_orders`（`type='game_recharge'`）；
- 写 `game_transactions` 文玉流水；
- 不改 `students.score`；
- 不影响光荣榜/期末评价；
- 每日上限、教师总开关；
- 学生端写“兑换文玉”，不写“充值”。

---

## 七、GitHub 参考

| 项目 | Stars | License | 用途 |
|---|---:|---|---|
| [cocos/cocos-engine](https://github.com/cocos/cocos-engine) | 9,909 | 需核对 Cocos 许可 | 引擎 |
| [cocos/example-projects](https://github.com/cocos/example-projects) | 1,321 | 需核对 | 官方示例 |
| [zhitaie/mini-game-workflow](https://github.com/zhitaie/mini-game-workflow) | 198 | Apache-2.0 | Cocos + 微信小游戏 TypeScript 工作流 |
| [caochao/cocos-creator-h5-wxapi](https://github.com/caochao/cocos-creator-h5-wxapi) | 67 | 未标注 | Cocos/H5 接微信 API |
| [oscargzh/wechat-minigame-publisher-skill](https://github.com/oscargzh/wechat-minigame-publisher-skill) | 59 | 未标注 | 微信小游戏发布流程参考 |
| [guladam/deck_builder_tutorial](https://github.com/guladam/deck_builder_tutorial) | 455 | MIT | 卡牌 Roguelike 设计参考（Godot 代码不能直接用） |
| [DesirePathGames/Slay-The-Robot](https://github.com/DesirePathGames/Slay-The-Robot) | 293 | MIT | 卡牌框架设计参考 |
| [VladoCC/Map-Generator-Godot-Tutorial](https://github.com/VladoCC/Map-Generator-Godot-Tutorial) | 22 | CC0-1.0 | 地图生成算法参考 |
| [nathanhoad/godot_dialogue_manager](https://github.com/nathanhoad/godot_dialogue_manager) | 3,968 | MIT | 剧情/事件设计参考 |

> Cocos 生态的卡牌/ Roguelike 成品项目普遍较小（几十星），不如 Godot 的卡牌教程成熟；  
> 但“App + 微信小游戏 + Web”三端一套代码，只有 Cocos 最稳。  
> 卡牌玩法设计可以参考 Godot 教程，代码用 TypeScript 重写。

---

## 八、MVP：先验证管线，再做内容

### 阶段 0（1 周）：三端管线验证

先不要做卡牌，先证明这套东西能跑：

- 安装 Cocos Creator 3.8 LTS；
- 建一个空场景 + 一个按钮 + 一个中文 Label；
- 导出 Android APK；
- 导出 Web Desktop；
- 导出微信小游戏，微信开发者工具能打开；
- 记录包体大小、首屏时间、真机帧率。

**这一步不过，后面都是空谈。**

### 阶段 1（3–4 周）：卡牌垂直切片 + 课堂模式

- 20 张卡、6 敌人、1 Boss；
- 1 张分支地图；
- 1 个主城/店铺界面；
- 1 个 5 分钟课堂大屏；
- 登录 + 假钱包；
- Android APK + Web 可玩。

### 阶段 2：微信小游戏

- 远程资源/分包；
- 微信登录/绑定；
- 小游戏包体优化；
- 低端安卓真机测试；
- 小游戏审核/类目。

### 阶段 3：内容与社交

- 新画卷、新卡牌、季节活动；
- 班级目标/每周文魔；
- 互访/点赞/分享；
- 小程序入口。

---

## 九、风险与红线

| 风险 | 应对 |
|---|---|
| Cocos 编辑器学习成本 | 先做 1 周管线验证；只做 2D，不碰 3D |
| 微信小游戏包体/性能 | 远程资源、分包、图集、2D、限制粒子 |
| 小游戏类目/版号 | 先 App/Web，小游戏第二阶段；咨询微信官方 |
| 登录绑定复杂 | 首版姓名+密码；微信 openid 第二阶段 |
| 三端差异 | core 纯 TS，platform adapter 隔离 |
| 内容量太大 | 首版 20 卡/6 敌/1 Boss，不贪多 |
| 课堂模式变重 | 5 分钟、三个按钮、零打印 |
| 家长质疑 | 零真钱、零广告、教师总开关、每日上限 |

**底线不变：**

1. 不接真钱；
2. 不改 `students.score`；
3. 不影响光荣榜/期末评价；
4. 不赌博、不逼氪；
5. 教师可一键关闭；
6. 测试用独立测试班/测试库。

---

## 十、结论

- **独立 App + 微信小游戏 + Web 课堂**，一套代码只有 Cocos Creator 最稳；
- 游戏本体：卡牌 Roguelike + 班级世界；
- 课堂模式：5 分钟、老师大屏、举手投票、零打印、零学生手机；
- 家庭模式：App/小游戏，学生回家玩深度内容；
- 第一步不是写卡牌，而是 **1 周三端管线验证**。

如果你认可，下一步我建议直接做“阶段 0”：在你电脑上装 Cocos Creator，建一个最小项目，分别导出 Android APK、Web、微信小游戏，确认三端都能跑，再开始做卡牌。
