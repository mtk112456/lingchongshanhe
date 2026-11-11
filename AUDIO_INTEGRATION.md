# 客户端音频接入审计（AUDIO_INTEGRATION）

> 性质：**只读审计**。本文只新增，不改 `client/`、`server/`，未运行 Godot，未 commit。
> 文中所有「建议 / 应 / 目标」均为**未实装**；「现状 / 实测」才是当前事实。请勿把第 6–9 章当已交付。
> 审计日期：2026-11-11 · 范围：Godot 4.7.2 客户端（`client/`）
> 证据：静态读码 + `client/assets/audio/**/*.wav` 二进制头解析 + ffmpeg 9.0.2（ebur128 / astats）。可复现命令见 §7.4。

---

## 0. 一页结论

**现状一句话：音频「有资产、有播放器、没有演出」——BGM 一次都不会响，8 个音效名里 2 个是哑的，最终只用到 5 个 wav 文件。**

| 指标 | 数值 | 说明 |
|---|---:|---|
| 磁盘 wav | **10** | 2 BGM + 8 SFX，全部 22050 Hz / 16-bit / **单声道** |
| `play_bgm()` 调用点 | **0** | 全项目 0 处；`stop_bgm()` 也 0 处 |
| `play_sfx()` 调用点 | **17** | 其中 **2 处解析不到文件**（静默 return）→ 有效 15 处 |
| 实际会发声的 wav | **5 / 10** | click / hit / arrow / wall(别名) / victory(含 stamp 别名)；2 个 BGM 全程静音 |
| SFX 有文件但从未被调用 | **3** | `defeat` / `draw` / `play` |
| 代码要但磁盘没有 | **2** | `confirm` / `card_withdraw` |
| 按钮 `pressed.connect` | **84** | 只有 **9 处**带点击音（≈89% 无反馈） |
| 缺口（§10 编号） | **27** | P0 5 · P1 11 · P2 11 |

三条最重要判断：

1. **BGM 缺口不是资产问题，是接线问题。** `map.wav`(24 s) / `battle.wav`(20 s) 都在，`play_bgm()` 也写好了，但没有任何场景调用它；同时两个 `.import` 的 `edit/loop_mode` 都没开循环，即使接上，20 秒后也会静音停住。
2. **两处玩家动作是完全无声的**（小院升级确认 `EstateView.gd:1131`、撤回将令 `Slice.gd:5115`），而且**零新资产可修**——`play.wav` / `draw.wav` 就躺在磁盘上没被用过。
3. **手机扬声器上，最该听见的东西最听不见。** `wall.wav` 有 **99.7 %**、`battle.wav` 有 **99.3 %** 的能量压在 400 Hz 以下（高通 400 Hz 后分别掉 24.9 / 21.4 dB，见 §7.3）；在手机外放上，破墙声只剩"噗"的一下，而 UI 点击（低频仅 4 %）反而最清楚。

---

## 1. 审计范围与方法

| 对象 | 读法 | 结论落点 |
|---|---|---|
| `client/AudioManager.gd`（152 行，全量） | 逐行 | §2 |
| `client/Slice.gd`（6012 行，音频相关段全读） | 定位 + 上下文 | §3 §4 |
| `client/BattleReplay.gd`（约 1440 行，音效/VFX/结算段） | 定位 + 上下文 | §3 §4 |
| `client/MorningReportModal.gd`、`client/SeasonView.gd`、`client/CompositionPanel.gd`、`client/EstateView.gd` | 全文 grep + 关键函数 | §3 §4 |
| `client/assets/audio/**`（10 wav + 10 `.import`） | 头解析 + ffmpeg 测量 | §5 §7 |
| `client/project.godot` | 全量 | §2.4 |
| `ASSET_INTEGRATION.md` §2.7 / §3.1 | 对账 | §11 |

未做：未启动 Godot、未真机试听、未跑 `ClientSmoke` / `ReplaySmoke`（本次不产生运行时行为证据）。所有"听感"结论都来自文件级测量，不是耳朵。

---

## 2. `AudioManager.gd` 现状

### 2.1 API

| API | 签名 | 现状行为 | 问题 |
|---|---|---|---|
| `play_sfx` | `(name: String, pitch: float = 1.0)` | 8 路 `AudioStreamPlayer` 轮询（`:50`）；`pitch` clamp 0.6–1.6；文件缺失静默 `return`（`:48-49`） | 全项目 17 处调用**全是单参**，`pitch` 从未被使用 → 同一 `hit` 连打 20 次音色完全一致，听觉疲劳 |
| `play_bgm` | `(name: String, fade: float = 0.4)` | 同曲去重（`:59` 比对 `stream.resource_path` 后缀）；切歌先 tween 到 **-40 dB**（`:66`）→ 换流 → **瞬时回满**（`:69-70`）；无 BGM 时直接满音量起播（`:72-75`） | 无淡入（见 §6.3 坑 1）；不可重入（D2）；去重键取错（D4） |
| `stop_bgm` | `()` | `_music.stop()`（`:79`） | 无淡出；不 kill 进行中的 tween（D3）；**0 调用点** |
| `set_master_volume` | `(v: float)` | clamp 0–1 → `_linear_to_db` → `_apply_volumes` → `_save_settings`（`:81-84`） | 滑杆 `value_changed` 每次触发都写盘（D6） |
| `set_music_volume` | 同上 | 同上 | 同上 |
| `set_sfx_volume` | 同上 | 同上 | 同上 |
| `set_reduced_motion` | `(v: bool)` | 只存标志 + 落盘（`:96-98`） | **不碰音频**，这是对的（§9-B） |

内部：`_load_sfx` / `_load_bgm`（`:106-121`）各自带缓存字典，缺失即缓存 `null` 并静默；`_ensure_bus`（`:123-129`）在运行时创建 `Music` / `SFX` 两条总线，`send = Master`。

### 2.2 音量与总线

| 项 | 当前值 | 折算 | 备注 |
|---|---:|---:|---|
| `master_volume` | 1.0 | 0.0 dB | 默认全开 |
| `music_volume` | 0.7 | **-3.1 dB** | 直接叠在 BGM 源文件响度上（§7.2 关键） |
| `sfx_volume` | 0.9 | **-0.9 dB** | |
| 0 % 时 | `_linear_to_db(0)` → **-80 dB** | ≈静音 | 但 `_music` 仍在解码播放（耗电），没有 `stream_paused` |
| 总线 | 运行时建 `Music` / `SFX`（`:28-29`） | 均 → Master | **无 `default_bus_layout.tres`**（已确认目录下不存在） |
| 总线效果 | **无** | — | 无 limiter / 无 EQ / 无 reverb |
| 声部数 | 1 BGM + 8 SFX | — | 固定池，无优先级（§10-G27） |

> 意味着一件事：把 `music_volume` 从 0 拖到 100 的过程，**当前听不出任何变化**，因为根本没有 BGM 在播。用户会判定"音乐设置坏了"（G05）。

### 2.3 减少动效

- 全项目 `is_reduced_motion` 有 30+ 处消费者，全部是视觉：跳过视差（`MorningReportModal.gd:73`）、跳过页面淡入（`Slice.gd:760`）、跳过碎片粒子（`BattleReplay.gd:491`）、跳过卡背翻入（`Slice.gd:5125`）。
- 音频侧**没有任何**"低刺激"分支——这点本身合理（减少动效 ≠ 静音）。
- 但存在一处**反向 bug**：`BattleReplay.gd:639` 的 `if not AudioManager.is_reduced_motion:` 把结算印章的 `play_sfx("stamp")`（`:655`）一起包进去了 → **开启减少动效后，战斗结算完全静音**（G14）。

### 2.4 设置持久化

`_load_settings` / `_save_settings`（`:136-152`）读写 `user://settings.cfg`，键位 `audio.master` / `audio.music` / `audio.sfx` / `access.reduced_motion`。

- 跨启动保持 ✅；跨账号共享（同一个 App 用户），班级共用平板上会出现"上一个人把音效关了"——可接受，但要在验收里写明。
- `project.godot:24-25` **重复声明了两行 `AudioManager="*res://AudioManager.gd"`**。当前两行完全一致、Godot 取后者，所以不炸；但只要将来有人只改其中一行（比如换成带名字的实例），就会出现"配置写的和跑的不是一个"（G25）。

### 2.5 代码级缺陷（D 编号 → 对应 §10 缺口）

| D | 位置 | 缺陷 | → |
|---|---|---|---|
| D1 | `AudioManager.gd:72-75` | 起播无淡入，直接从 -80 跳到 -3.1 dB | G06 |
| D2 | `AudioManager.gd:56-75` | 切歌不可重入：0.4 s 内连点两次场景，两个 tween 并行，音量可能停在 -40 或新曲被旧回调覆盖 | G07 |
| D3 | `AudioManager.gd:77-79` | `stop_bgm` 无淡出、且不 kill 进行中的 tween → 淡出途中调用 stop，回调仍会把新曲播起来 | G08 |
| D4 | `AudioManager.gd:59` | 去重靠 `stream.resource_path`，而淡出期间 `stream` 仍是旧曲 → 对"目标曲"重复请求会再触发一次淡出 | G07 |
| D5 | `AudioManager.gd:115-121` + 两个 `.import` | BGM 无循环（`edit/loop_mode` 未设为 Forward） | G02 |
| D6 | `Slice.gd:4021-4024 / 4049-4053 / 4090-4094` | 滑杆 `value_changed` 每像素写一次 `ConfigFile.save`（拖动一次写盘数百次） | 工程性小问题，未计入 27 条 |
| D7 | `Slice.gd:4061 / 4102` | 取消静音固定恢复 **80 %**，不是静音前的值 | G09 |
| D8 | `AudioManager.gd:35-40` | 8 路池无优先级；同帧「破墙 + 命中 + 印章」会互相抢占（`wall.wav` 0.55 s 最容易被截断） | G27 |
| D9 | `AudioManager.gd:123-129` | 只建总线，无 limiter / 无 duck 接口 | G19 G23 G24 |
| D10 | 全项目 | 0 处 `NOTIFICATION_APPLICATION_PAUSED` / `NOTIFICATION_FOCUS_OUT`（grep 确认） | G10 |

---

## 3. 调用点全量清单（17 处 `play_sfx`，0 处 `play_bgm`）

| # | 文件:行 | 调用 | 解析到 | 结果 |
|---:|---|---|---|---|
| 1 | `Slice.gd:4108` | `play_sfx("click")` | `sfx/click.wav` | ✅ 音效滑杆松手 |
| 2 | `Slice.gd:5032` | `play_sfx("click")` | 同上 | ✅ 弃牌点击被拒 |
| 3 | `Slice.gd:5040` | 同上 | 同上 | ✅ 未选城就出牌 |
| 4 | `Slice.gd:5050` | 同上 | 同上 | ✅ 长安未开放 |
| 5 | `Slice.gd:5056` | 同上 | 同上 | ✅ 决战周限制 |
| 6 | `Slice.gd:5063` | 同上 | 同上 | ✅ 关河阻隔 |
| 7 | `Slice.gd:5079` | 同上 | 同上 | ✅ 三令已满 |
| 8 | `Slice.gd:5099` | `play_sfx("stamp")` | 别名 → `victory.wav` | ✅ 但用 1.0 s 胜利曲当"盖章" |
| 9 | `Slice.gd:5115` | `play_sfx("card_withdraw")` | **无此文件** | ❌ 静默（G04） |
| 10 | `Slice.gd:5745` | `play_sfx("click")` | `click.wav` | ✅ 点不可达城池 |
| 11 | `EstateView.gd:1068` | `play_sfx("victory")` | `victory.wav` | ✅ 小院升级 |
| 12 | `EstateView.gd:1131` | `play_sfx("confirm")` | **无此文件** | ❌ 静默（G03） |
| 13 | `EstateView.gd:1537` | `play_sfx("click")` | `click.wav` | ✅ 房间卡点选 |
| 14 | `BattleReplay.gd:308` | `play_sfx("hit")` | `hit.wav` | ✅ 每次命中 |
| 15 | `BattleReplay.gd:384` | `play_sfx("arrow")` | `arrow.wav` | ✅ 每次放箭（+ 命中时再叠一个 hit） |
| 16 | `BattleReplay.gd:414` | `play_sfx("wall_break")` | 别名 → `wall.wav` | ✅ 破墙 |
| 17 | `BattleReplay.gd:655` | `play_sfx("stamp")` | 别名 → `victory.wav` | ⚠️ 仅"未开减少动效"时响（G14） |

**`play_bgm` / `stop_bgm`：** grep `client/**/*.gd` 全部命中仅 `AudioManager.gd` 自身定义行（`:56`、`:77`）。**没有任何一处调用。**

**别名表**（`AudioManager.gd:22-25`）只有两条：`wall_break→wall`、`stamp→victory`。这两个别名是"一个文件顶两个音效名"的原因，也是同一段 `victory.wav` 既当"晋升凯歌"又当"盖章"的直接来源。

**未使用的 wav：** `defeat`（1.1 s）、`draw`（0.18 s）、`play`（0.24 s）——磁盘有、代码无。

---

## 4. 场景 × 音频矩阵

「当前是否调用」= 代码里有没有实际接上并按预期发声。

| 场景 | 入口（现状） | 应有 BGM | 应有 SFX | 当前调用 | 缺口 |
|---|---|---|---|---|---|
| **登录** S00 | `Slice.gd:1283 _build_login()` → `:5530 _transition_login_to_game()` | **无**（冷启动静音，见 §9-D） | 按钮 click、登录成功 `play`、失败 `defeat` | **0**（连按钮都无 click） | G01 G11 G13 G17 |
| **沙盘** S01_MAP | `Slice.gd:715 _navigate_to("S01_MAP")` | `map` 循环 | 点城 click、出令 `stamp`、撤回 `draw`、被拒 click | click×7 ✅、stamp ✅、card_withdraw ❌、其余 0 | G01 G02 G04 G12 G13 G17 G23 G24 |
| **编成** S03_ARMY | `CompositionPanel.gd`（`Slice.gd:4556` 创建、`:5816 _open_army_page`） | `map`（降 2 dB） | 选兵/换位 click、确认 `confirm`、禁选 click | **0（整个面板没有任何音频调用）** | G18（整场景）+ G03 |
| **晨报** | `Slice.gd:5958 _open_morning_report()` → `MorningReportModal.gd:341 open_modal()` | `map` **duck -8 dB** | 开页 `play`、选邸报 `confirm`、关闭 click | **0** | G20（+ 无 duck API，见 W3） |
| **战斗** | `Slice.gd:5157 _start_demo_battle()` → `:5173` 显示浮层 → `BattleReplay.gd:141 play_data()` | `battle` 循环 | arrow / hit / wall / stamp / 胜败 | hit ✅ arrow ✅ wall ✅ stamp ⚠️（减少动效时丢） | G01 G02 G14 G23 |
| **结算/战报** S04 | `Slice.gd:2912 _open_report()` → `:3186 _show_report()`；`:3457 _open_replay()` | `map`（或胜/败 8 s 短曲后回 `map`） | 开页 `play`、印章 `victory` / `defeat` | **0** | G22 G11 |
| **赛季** S10 | `Slice.gd:3782 _build_season_page()` → `:3792 _open_season_page()`；`SeasonView.gd:129/143` | `season`（**无此资产**）→ 暂用 `map` | 返回/刷新 click、颁奖 `victory` | **0** | G19 G21 |
| *附：小院* S02 | `Slice.gd:765 _open_estate_page()`；`EstateView.gd` | `map` | 点选 click ✅、升级 `confirm` ❌、晋升 `victory` ✅ | 3 处，1 处哑 | G03 |
| *附：设置* | `Slice.gd:4000-4148` | 随当前场景 | 滑杆松手 click ✅、mute 按钮 click ❌ | 1 处 | G05 G09 |

**读法：** 7 个正式场景里，只有「战斗」和「沙盘」有可听内容；「编成 / 晨报 / 赛季」是**完全静音的场景**，而这恰好是学生停留最久、最需要"操作被确认"的三页。

---

## 5. 现有 10 个 wav 的用途映射

### 5.1 实测属性（文件级，非听感）

| 文件 | 类 | 时长 | 采样 | 峰值 dBFS | 整体 RMS dBFS | 100 ms 最大 RMS | EBU I (LUFS) | <400 Hz 能量 |
|---|---|---:|---|---:|---:|---:|---:|---:|
| `bgm/map.wav` | BGM | 24.00 s | 22050/mono | -5.6 | -15.5 | -14.4 | **-17.3** | **98 %**（HP400 后 -16.5 dB） |
| `bgm/battle.wav` | BGM | 20.00 s | 22050/mono | -2.7 | -16.3 | -10.7 | **-18.9** | **99.3 %**（HP400 后 -21.4 dB） |
| `sfx/click.wav` | SFX | 0.08 s | 22050/mono | -5.4 | -14.1 | n/a（<100 ms） | n/a | 4 %（HP400 -0.2 dB） |
| `sfx/arrow.wav` | SFX | 0.14 s | 22050/mono | -3.5 | -16.3 | -15.1 | n/a | 11 %（HP400 -0.5 dB） |
| `sfx/hit.wav` | SFX | 0.16 s | 22050/mono | **-1.4** | -9.8 | -8.3 | n/a | **96 %**（HP400 -13.9 dB） |
| `sfx/draw.wav` | SFX | 0.18 s | 22050/mono | -7.1 | -21.3 | **-19.1** | n/a | 31 %（HP400 -1.6 dB） |
| `sfx/play.wav` | SFX | 0.24 s | 22050/mono | -3.5 | -12.8 | -10.7 | n/a | 31 %（HP400 -1.6 dB） |
| `sfx/wall.wav` | SFX | 0.55 s | 22050/mono | **-1.4** | -7.7 | **-5.9** | n/a | **99.7 %**（HP400 -24.9 dB） |
| `sfx/victory.wav` | SFX | 1.00 s | 22050/mono | -1.4 | -13.7 | -10.1 | -13.0 | 52 %（HP400 -3.2 dB） |
| `sfx/defeat.wav` | SFX | 1.10 s | 22050/mono | -1.4 | -13.3 | -9.6 | -12.9 | 88 %（HP400 -9.1 dB） |

> `<400 Hz 能量` 的算法：`highpass=f=400` 后的 RMS 相对全带 RMS 的落差（dB），按功率折算成占比；落差越大，低频占比越高。
> `EBU I` 一栏的 `n/a`：**BS.1770 的整体响度对 <400 ms 素材无定义**，ffmpeg 对短音效一律返回 -70.0 LUFS（=静音）。这不是文件坏了，是指标用错了——所以 §7 的 SFX 目标改用「100 ms 短时响度」，不要拿 -14 LUFS 去卡 0.08 s 的点击。

### 5.2 用途映射（现状 → 建议）

| 文件 | 现在被谁播 | 建议固定用途 | 备注 |
|---|---|---|---|
| `map` | **无人** | 沙盘 / 编成 / 晨报 / 战报 / 赛季（duck）基底 | 24 s 太短，见 §6.4 |
| `battle` | **无人** | 战斗回放专属 | 20 s 太短，且低频过量 |
| `click` | 9 处 | 通用 UI 点击 / 被拒 | 音色可用，是全场最"手机友好"的一个 |
| `arrow` | `BattleReplay.gd:384` | 弓兵放箭 | 可用 |
| `hit` | `BattleReplay.gd:308` | 近战命中 | 低频偏重、峰值 -1.4 偏高 |
| `wall` | `BattleReplay.gd:414` | 破墙 / 器械撞门 | **纯低频，手机上几乎听不见**，需重做或补 1–4 kHz 层 |
| `victory` | `EstateView.gd:1068` + `stamp` 别名（`Slice.gd:5099`、`BattleReplay.gd:655`） | 晋升 / 破城印章 | 一个 1 s 的胜利曲被当"盖章"用，语义与长度都不合 |
| `defeat` | **无人** | 战败 / 登录失败 / 守城失守 | 未接线（G11） |
| `draw` | **无人** | 抽牌 / 重抽 / 撤回将令 | 建议同时做 `card_withdraw` 别名源（G04 G12） |
| `play` | **无人** | 出牌 / 确认 / 开页 | 建议同时做 `confirm` 别名源（G03 G13） |

### 5.3 结论

- **10 个文件，5 个在响。** 三个未使用文件正好是"确认 / 抽牌 / 失败"这三类最高频反馈——这不是缺资产，是缺两张别名表。
- `victory` 一物三用（晋升、盖章、结算）导致音色语义漂移：**盖章不该是 1 秒的凯歌**。
- 全部 22050 Hz 单声道、QOA 压缩（`compress/mode=2`）。体积友好，但 22.05 kHz 的 Nyquist 只有 11 kHz，高频"纸感/金属感"损失明显——对「纸雕国风」尚可，对破墙、刀剑这类需要"脆"的音效不够。

---

## 6. BGM 循环 / 切换 / 淡入淡出（设计建议，**未实装**）

### 6.1 状态机（map ↔ battle ↔ season）

```text
S0 登录 ──登录成功──▶ S1 沙盘(map) ──▶ S2 编成(map, -2dB)
                         │  ▲                    │
              打开晨报 ◀──┘  └──── 关闭 ──────────┘
                 │(duck -8dB)
                 ▼
              S3 晨报(map duck)
                         │
              发起演武 ◀──┘
                 ▼
              S4 战斗(battle) ──印章 duck -6dB──▶ S5 结算(map, -2dB)
                                                     │
                                            进入赛季 ▼
                                              S6 赛季(season→缺，暂用 map)
S7 登出 ◀── 任意状态 ── 0.6 s 淡出后 stop
```

要点：**`_navigate_to()` 是唯一路由收口**（`Slice.gd:715`），BGM 只需要在这里按 `page_id` 决定"要不要换"，不必每个页面各写一遍。`S2/S5/S6` 都复用 `map`，靠 `play_bgm` 的同曲去重自动"续播不重启"——这也是现有实现里唯一值得保留的巧思。

### 6.2 参数表

| 转场 | 出 | 入 | 目标响度 | 理由 |
|---|---|---|---|---|
| 登录 → 沙盘（首次） | — | **1.2 s**，从 -24 dB 起 | -16 LUFS | 首次进入不吓人（§9-D） |
| 沙盘 ↔ 编成 / 战报 / 赛季 | 不切（同曲续播） | — | -18 LUFS（-2 dB） | 阅读页稍退，避免盖住文字注意力 |
| 沙盘 → 战斗 | 0.25 s | 0.35 s | -16 LUFS | 进战斗要"立刻"，出战斗可慢 |
| 战斗 → 沙盘 | 0.60 s | 0.50 s | -18 LUFS | 战斗后需要"落地"感 |
| 晨报打开 | duck -8 dB / 0.35 s | — | -24 LUFS | 弹层是"读"，不是"玩" |
| 晨报关闭 | — | 回升 1.2 s | -18 LUFS | |
| 登出 / 回登录 | 0.60 s → stop | — | 静音 | 不要把 BGM 带进登录页 |

### 6.3 现有 `play_bgm` 的 4 个坑（都在 `AudioManager.gd:56-79`）

| # | 坑 | 后果 | 修法方向 |
|---|---|---|---|
| 1 | **无淡入**：`else` 分支直接 `volume_db = 目标; play()`（`:72-75`） | 冷启动/首次进图时"啪"地一声起播 | 起播也从 -24 dB tween 到目标 |
| 2 | **不可重入**：不保存 tween 引用 | 连续切页 → 两个 tween 抢同一个 `volume_db`，可能停在 -40 dB（听感=没声） | 存档 `_bgm_tween`，切换前 `kill()` |
| 3 | **`-40 dB` 当静音**：`:66` tween 到 -40（=1 % 振幅），仍可闻 | 淡出尾巴有"漏音"，且 `:69` 回满是**跳变**，有爆音风险 | 淡化到 -60 dB 再换流 |
| 4 | **`stop_bgm` 不停 tween**：`:77-79` | 淡出途中 stop，回调照样把新曲播起来 | stop 里先 `kill()` 再 `stop()`，并清空"当前曲"记录 |

> 架构限制：只有 **1 个** `AudioStreamPlayer`（`:31`），所以做不出真正的交叉叠化（A/B 双 player）。场景级切换（有 0.25–0.6 s 淡出）用「淡出→换流→淡入」够用；若要做到"无缝"，需要再加一个 player，属于第二轮（§8 第二波）。

### 6.4 循环点与文件规格

- **现状：两个 `.import` 的 `edit/loop_mode` 均未开启循环**（当前值 0）。以现有文件长度，`map` 播 24 s、`battle` 播 20 s 后**静音停住**，且 `_music.playing` 变 `false` 后不会自恢复——只有下次切场景才会重播。这是 P0（G02）。
- 建议在 Godot 导入面板把 `Loop Mode` 显式设为 **Forward**（不要手填数字：4.3+ 的枚举首位是 `Detect From WAV`，编辑器 UI 选项为准），并勾选/确认 `loop_begin=0`、`loop_end=-1`。
- 循环缝：24.000 s @ 22050 = 529 200 采样、20.000 s = 441 000 采样，整数无余数，**必须做首尾零交叉**，否则每圈"咔"一下。做法：文件头尾各留 ≥5 ms 淡入淡出，或把尾部的残响裁到与首帧同电平。
- **长度不够用**：20–24 s 的循环在 3 回合切片里会被听 10 遍以上。目标 **45–60 s**，或在现有 24 s 上做"两段式"（A 段 24 s + 变奏 B 段）。这属于资产迭代，不是接线。
- 压缩：现为 QOA（`compress/mode=2`，有损）。BGM 建议改 **OGG Vorbis**（原生 `loop` 支持、接缝更干净、体积更小）；SFX 保留 WAV/QOA。

---

## 7. 音量与响度目标（建议，**未实装**）

### 7.1 目标

| 类 | 指标 | 目标 | 说明 |
|---|---|---|---|
| BGM | 整体响度 | **-16 LUFS**（±1） | 按交付要求（BGM -16 / SFX -14）；手机外放友好 |
| BGM | 真峰 | **≤ -1 dBTP** | 留 1 dB 余量给总线叠加 |
| BGM | 响度范围 LRA | ≤ 8 LU | 循环 BGM 不要大起大落 |
| SFX（单发） | 100 ms 短时响度 | **按类分档 -18…-9，组内中位 -14 ±2**；同类两两差 ≤3 dB | **不要用整体 LUFS**：<400 ms 无定义（ffmpeg 返回 -70） |
| SFX | 真峰 | **≤ -1 dBTP** | 现 `hit.wav` 为 **-0.4 dBTP**，已越线 |
| 全局 | Master | 挂 limiter，阈值 -1 dBTP | 8 路 SFX + BGM 叠加无保护（G23） |

### 7.2 实测 vs 目标

**BGM**

| 文件 | 实测 I | 目标 | 源文件增益 | 默认音量后（×0.7 = -3.1 dB） | 结论 |
|---|---:|---:|---:|---:|---|
| `map` | -17.3 | -16 | **+1.3 dB** | **-20.4 LUFS** | 偏低 4.4 LU |
| `battle` | -18.9 | -16 | **+2.9 dB** | **-22.0 LUFS** | 偏低 6 LU，且被低频吃掉 |

> 结论：**只改源文件不够。** 要么把源做到 -16 LUFS 并把 `music_volume` 默认改 1.0，要么把源做到 -12.9 LUFS 保留 0.7 默认（不推荐，会顶到峰值）。注意 `music_volume` 默认值改动**不影响老用户**——他们的 `settings.cfg` 里已经存了 0.7。

**SFX**（按"100 ms 短时响度"分档；`click` 80 ms，用 20 ms 值 -12.4 参考）

| 文件 | 实测 100 ms | 建议档位 | 建议增益 | 改后峰值 |
|---|---:|---:|---:|---:|
| `click` | n/a（20 ms -12.4） | **-18…-16**（每天点几百次，不能疲劳） | 0（保持） | -5.4 |
| `draw` | **-19.1** | -18…-16 | **+2.0** | -5.1 |
| `arrow` | -15.1 | -16…-14 | 0 | -3.5 |
| `play` | -10.7 | -16…-14 | **-4.0** | -7.5 |
| `victory` | -10.1 | -12…-10 | **-1.0** | -2.4 |
| `defeat` | -9.6 | -12…-10 | **-1.5** | -2.9 |
| `hit` | -8.3 | -13…-11 | **-3.5** | -4.9 |
| `wall` | **-5.9** | -11…-9 | **-4.0** | -5.4 |

改后组内跨度从 **13.2 dB 收窄到 ≈7 dB**（-17.1 … -9.9）。同组（如 `hit`/`arrow`/`wall` 三个战斗音）两两差值应 ≤3 dB，否则会出现"砍中没声、破墙吓一跳"。

### 7.3 手机扬声器可读性（这是本节最硬的发现）

手机外放通常在 **500 Hz–1 kHz 以下快速滚降**，400 Hz 以下基本靠壳体共振"糊"出来。实测：

| 文件 | <400 Hz 占比 | 手机外放表现（推断） |
|---|---:|---|
| `wall.wav` | **99.7 %**（HP400 后 -24.9 dB） | **几乎听不见**，只剩"噗"的一声气流感 → 破墙这个最重要的战斗反馈丢失 |
| `battle.wav` | 99.3 %（-21.4 dB） | 只剩低频"嗡"，旋律/节奏全丢 |
| `hit.wav` | 96 %（-13.9 dB） | 闷响，缺少"脆" |
| `defeat.wav` | 88 %（-9.1 dB） | 偏闷，情绪传达打折 |
| `map.wav` | 98 %（-16.5 dB） | 沙盘 BGM 在手机上"似有若无" |
| `arrow` / `click` / `draw` / `play` | 4–31 % | **最清楚的一批**，反而比战斗音效响 |

**行动建议（顺序很重要）：**

1. 先做 **EQ 再谈增益**。给 BGM 加 120–150 Hz 高通 + 2–5 kHz 轻微存在感提升；给 `wall` / `hit` 加 180–250 Hz 高通并叠一层 1–4 kHz 的"裂/脆"层。否则把 `battle` +2.9 dB 只是把"听不见的低频"变响。
2. 手机外放基线：22050 Hz 单声道可保留（省包体），但**不要**在 11 kHz 以上做文章——那部分在手机上本来就没有。
3. 主观验收：把手机放桌上、音量 50 %、播放 `wall`，**1 米外必须能明确听出"墙被撞裂"**；只听出"咚"即不通过。

### 7.4 复测命令（本次使用，可复现）

```bash
# 整体响度 + 真峰（BGM 适用；<400ms 的 SFX 会返回 -70，属正常）
ffmpeg -hide_banner -nostats -i <file>.wav -af "ebur128=peak=true" -f null -

# 100 ms 短时响度（SFX 适用，取 RMS level dB 最后一行）
ffmpeg -hide_banner -nostats -i <file>.wav -af "astats=metadata=1:reset=0" -f null -

# 低频占比（与全带 RMS 的差值）
ffmpeg -hide_banner -nostats -i <file>.wav -af "highpass=f=400:poles=2,astats=metadata=1:reset=0" -f null -
```

---

## 8. 最小改动清单（5 条，全部零新资产，**均未实装**）

> 目标：让 BGM 真正响起来 + 让两处"哑操作"出声，每条 ≤ 3 行。

| # | 函数 | 文件:行 | 建议调用时机 | 风险 / 注意 |
|---|---|---|---|---|
| **M1** | `play_bgm("map")` | `Slice.gd:5530` `_transition_login_to_game()` 末尾 | 登录成功、`game_layer.visible = true` 之后（`:5533` / `:5552` 两个分支都要覆盖） | 必须配合 M5 循环，否则 24 s 后静音；首次起播若同时修 §6.3 坑 1 会更柔 |
| **M2** | `_navigate_to()` 内新增一次"按页选曲" + `stop_bgm()` | `Slice.gd:715`（插入点建议在 `:757 _update_dock_highlight` 之前）；`stop_bgm` 放 `Slice.gd:5562 _logout_local()` 的 `:5578` 之前 | 每次页面切换；`page_id == "S10_SEASON"` → `season`（缺资产时回退 `map`），其余 → `map`；登出/超时 → `stop_bgm()` | 一处收口覆盖沙盘/编成/小院/战报/赛季；**不要**在 `S04_REPORT` 与 `S01_MAP` 之间换曲（同曲去重会兜住） |
| **M3** | `play_bgm("battle", 0.25)` + 关闭时 `play_bgm("map", 0.5)` | 进：`Slice.gd:5173`（`_start_demo_battle` 显示浮层处）；出：`Slice.gd:5306` 的 `closed` 回调 | 演武开始 / 回放关闭 | `closed` 是唯一出口（`BattleReplay.gd:861` 与 `:1436` 都 emit 它），放这里能覆盖"关闭"和"跳过→完成"两条路径；`_on_battle_replay_finished()`（`Slice.gd:5180`）只做结算，不要在这里切曲 |
| **M4** | `SFX_ALIASES` 加两条 | `AudioManager.gd:22-25` | 静态生效，改完即修 `EstateView.gd:1131` 与 `Slice.gd:5115` 两处无声 | `"confirm": "play"`、`"card_withdraw": "draw"`；两条源文件都短（0.24 s / 0.18 s），语义够用；若要更"确认感"再单独出 wav |
| **M5** | `_load_bgm()` 补循环（或改 `.import`） | `AudioManager.gd:115-121`；或 `client/assets/audio/bgm/{map,battle}.wav.import` 的 `[params] edit/loop_mode` | 加载时一次性设置 | 代码侧：对取到的 `AudioStreamWAV` 设「循环模式 = Forward、循环终点 = 末帧」；导入侧：编辑器里把 `Loop Mode` 选 **Forward**。**两条路选一条**，别同时改 |

**这 5 条做完的净效果：** BGM 从"永不响"变成"进图就响、循环、切战斗换曲"；小院升级与撤回将令从"静音"变成"有反馈"；玩家能听出 `click` 与 `confirm` 的区别。

### 第二波（明确不属于"最小改动"，此处只登记）

| # | 事项 | 位置 | 为什么必须做 |
|---|---|---|---|
| W1 | `play_bgm` 淡入 + 重入保护 + `stop_bgm` kill tween | `AudioManager.gd:56-79` | §6.3 的 4 个坑，M1–M3 接上后**立刻会暴露**（切页爆音、连点没声） |
| W2 | 一键全静音 + 记忆静音前音量 | `Slice.gd:4033-4106` + `AudioManager` 新 API | 课堂场景必需（G09） |
| W3 | `duck_music(db, secs)` | `AudioManager` 新增 | 晨报/结算/弹层通用（G20 G22） |
| W4 | 前后台暂停 | `AudioManager` 加 `_notification` | 手机切走还在响（G10） |
| W5 | Master limiter | `default_bus_layout.tres` 或 `_ensure_bus` 后 `add_bus_effect` | G23 |
| W6 | 统一按钮点击音钩子 | `_button()`（`Slice.gd:482` 一带）/ 各面板 | 84 个按钮只 9 个有声（G17） |
| W7 | 响度归一 + 低频重做 | 资产线 | §7.2 §7.3 |

---

## 9. 验收清单

> 每一项都写"怎么测 / 通过标准 / 现状"。**现状判定为「不通过」的，本轮不算缺陷回归，只作为验收门槛。**

### A. 静音开关

| 检查 | 方法 | 通过标准 | 现状 |
|---|---|---|---|
| A1 主音量 | 设置页拖到 0 | ≤100 ms 内完全无声，无爆音 | ✅ 对 SFX 生效（`Slice.gd:4023` → `-80 dB`）；BGM 侧无法验证（G01） |
| A2 音乐静音 | 点喇叭图标 | 立刻静音；图标切换 | ⚠️ 按钮可用，但**当前无 BGM**，等于空操作（G05） |
| A3 取消静音 | 再点一次 | 恢复**静音前**音量（±5 %） | ❌ 固定恢复 80 %（`Slice.gd:4061/4102`，G09） |
| A4 跨启动 | 关 App 重进 | 保持上次设置 | ✅ `settings.cfg`（`AudioManager.gd:136-152`） |
| A5 一键全静音 | — | 一次点击全部静音，且不丢各项原值 | ❌ 无此开关（G09） |
| A6 静音时不耗电 | 静音后看 profiler | BGM 应 `stream_paused` | ❌ 仍以 -80 dB 播放（§2.2） |

### B. 减少动效

| 检查 | 方法 | 通过标准 | 现状 |
|---|---|---|---|
| B1 音频不受影响 | 开关切换，听 click/BGM | 音量、曲目、时机**完全不变** | ✅ 逻辑上独立（`set_reduced_motion` 不碰音频） |
| B2 战斗音效不丢 | 开启后跑一场回放 | `hit` / `arrow` / `wall` 仍响 | ✅ 三处都在动效分支外（`:308/:384/:414`） |
| B3 印章音效不丢 | 开启后看结算 | `stamp` 仍响 | ❌ **被包进 `if not is_reduced_motion`**（`BattleReplay.gd:639-658`，G14） |
| B4 不误静音 | 开启后确认无 SFX 被整体关掉 | 无 | ✅ |

### C. 后台切换

| 检查 | 方法 | 通过标准 | 现状 |
|---|---|---|---|
| C1 Home 键 | 真机切后台 3 次 | **立即静音**（不是继续响） | ❌ 0 处处理（G10） |
| C2 回前台 | 切回 | ≤0.3 s 恢复，**从原位置续播**，不重头 | ❌ 无处理 |
| C3 来电/闹钟 | 模拟打断 | 同上 | ❌ 无处理 |
| C4 锁屏 | 锁屏 30 s | 静音 | ❌ 无处理（需真机确认，代码上无任何 `NOTIFICATION_APPLICATION_PAUSED`） |

> 注：`AudioManager.gd:42` 的 `process_mode = ALWAYS` 是为了切场景不中断，**不等于**前后台处理；两者经常被混淆，验收时分开测。

### D. 首次进入不吓人

| 检查 | 方法 | 通过标准 | 现状 |
|---|---|---|---|
| D1 冷启动 | 从桌面点图标到登录页 | **全程静音**，不播 BGM、不播 splash 音 | ✅ 因为还没有 BGM（"靠没做对而通过"） |
| D2 登录成功 | 首次进图 | BGM 淡入 ≥1 s，起播瞬间听不出"啪" | ❌ 无 BGM；接上后若不修 §6.3 坑 1，会立刻失败 |
| D3 默认音量 | 默认设置、手机 50 % 音量、1 m | BGM "可闻不打扰"；单发 SFX 不惊跳 | ⚠️ 需真机 SPL：建议 BGM ≤60 dB(A)、单发 ≤70 dB(A) @1 m |
| D4 课堂场景 | 安静教室（≈35 dB(A)）开一场演武 | 邻座能听见但不侧目；教师可一键静音 | ❌ 无一键静音（G09） |
| D5 首日引导 | 首次登录 3 步教学 | 教学期间无 BGM 突变、无印章重击 | ⚠️ `_check_and_trigger_tutorial()`（`Slice.gd:5536/5551`）与 M1 同帧触发，需排先后 |

---

## 10. 缺口总表（27 条）

### P0 — 阻断（5）

| ID | 现象 | 证据 | 修法 |
|---|---|---|---|
| **G01** | BGM 一次都不响 | `play_bgm` 全项目 0 调用（`AudioManager.gd:56` 定义，无消费者） | §8-M1 M2 M3 |
| **G02** | BGM 不循环，20/24 s 后静音停住 | 两个 `.import` 的 `edit/loop_mode` 未设 Forward；`_load_bgm` 不做兜底（`AudioManager.gd:115-121`） | §8-M5 |
| **G03** | 小院升级确认无声 | `EstateView.gd:1131` → `sfx/confirm.wav` 不存在，`_load_sfx` 静默返回（`AudioManager.gd:48-49`） | §8-M4 |
| **G04** | 撤回将令无声 | `Slice.gd:5115` → `sfx/card_withdraw.wav` 不存在 | §8-M4 |
| **G05** | 设置页"背景音乐"滑杆是空操作 | 无 BGM 在播 → 拖动无任何听感变化（`Slice.gd:4049-4065`） | §8-M1 后自动消失 |

### P1 — 明显损伤体验（11）

| ID | 现象 | 证据 | 修法 |
|---|---|---|---|
| **G06** | 起播无淡入，有"啪"声风险 | `AudioManager.gd:72-75` 直接满音量 `play()` | W1 |
| **G07** | 快速切页会切歌失败/卡 -40 dB | `AudioManager.gd:56-75` 无 tween 引用、无重入保护、去重键取 `stream` 而非"目标曲名" | W1 |
| **G08** | `stop_bgm` 无淡出，且淡出途中 stop 会被回调"复活" | `AudioManager.gd:77-79` | W1 |
| **G09** | 无一键全静音；取消静音固定 80 % | `Slice.gd:4061 / 4102` | W2 |
| **G10** | 切后台/锁屏/来电不静音 | 全项目 0 处 `NOTIFICATION_APPLICATION_PAUSED`/`FOCUS_OUT` | W4 |
| **G11** | 战败无任何声音 | `defeat.wav` 存在但 0 调用 | 接 S04 + 登录失败 |
| **G12** | 抽牌/重抽/撤回无音 | `draw.wav` 0 调用 | 接 `_on_hand_redraw_pressed`（`Slice.gd:5121`） |
| **G13** | 出牌/开页/确认类通用音缺失 | `play.wav` 0 调用 | 接 `_play_card_order` 成功分支 |
| **G14** | 开启减少动效后，战斗结算印章静音 | `BattleReplay.gd:639` 的动效判定包住了 `:655` 的 `play_sfx("stamp")` | 把音效移出 `if` |
| **G15** | SFX 源响度跨度 13.2 dB（`draw` -19.1 → `wall` -5.9） | §5.1 表 | §7.2 增益表 |
| **G16** | 低频过量：`wall` 99.7 %、`battle` 99.3 % 能量 <400 Hz | §5.1 / §7.3 | EQ 重做 + HPF |

### P2 — 覆盖率与工程性（11）

| ID | 现象 | 证据 | 修法 |
|---|---|---|---|
| **G17** | 84 个按钮只有 9 处点击音（≈89 % 无反馈），且无统一钩子 | `pressed.connect` 计数 vs `play_sfx("click")` 计数 | W6 |
| **G18** | 编成页 0 音效（选兵/换位/确认全静音） | `CompositionPanel.gd` grep `AudioManager` = 0 命中 | 3 处 `pressed.connect`（`:191/:228/:265`）各挂一条 |
| **G19** | 赛季页 0 音效（返回/刷新静音） | `SeasonView.gd` 0 命中；仅 `:129/:143` 两个按钮 | 2 条 click |
| **G20** | 晨报弹层 0 音效 | `MorningReportModal.gd` 0 命中；`open_modal:341`、`close_and_mark_read:484`、邸报按钮 `:478` 全静音 | 开页 `play` + 选择 `confirm` + duck |
| **G21** | 无 `season.wav`，赛季与沙盘共用一曲 | `client/assets/audio/bgm/` 只有 2 个文件 | 资产迭代（P2，可先复用 `map`） |
| **G22** | S04 战报/结算页无开页音、无胜负印章音 | `_show_report`（`Slice.gd:3186`）、`_open_replay`（`:3457`）无音频调用 | 开页 `play` + `victory`/`defeat` |
| **G23** | 无 Master limiter；`hit.wav` 真峰 -0.4 dBTP 已越 -1 线 | §5.1；`_ensure_bus` 只建总线不挂效果（`AudioManager.gd:123-129`） | W5 |
| **G24** | BGM 源响度低于目标（`map` -17.3 / `battle` -18.9 vs -16），叠加 0.7 默认后仅 -20.4 / -22.0 | §7.2 | 归一 + 默认音量二选一 |
| **G25** | `project.godot` 重复声明 autoload `AudioManager` | `project.godot:24-25` 两行完全相同 | 删一行 |
| **G26** | `client/tests/` 0 个音频断言 | 仅 `P0FlowVerify.gd:322/398` 改标志位，无任何播放/音量断言 | 加 1 条 smoke：`play_sfx` 不崩、总线存在、`settings.cfg` 往返 |
| **G27** | 8 路 SFX 池无优先级/抢占 | `AudioManager.gd:9,35-40,50-51` 纯轮询 | 战斗音设高优先级 / 给 `hit` 限并发 |

**合计 27 条：P0 5 · P1 11 · P2 11。**

---

## 11. 与 `ASSET_INTEGRATION.md` 对账

| 该文档结论 | 本次复核 | 处理 |
|---|---|---|
| §2.7「10 个 wav 齐全，目录存在」 | ✅ 成立（2 BGM + 8 SFX） | 保留 |
| §2.7「**BGM 全程不会响**，`play_bgm` 无调用点」 | ✅ 成立，且本次进一步确认 `stop_bgm` 也 0 调用 | 保留，升级为 G01 |
| §2.7「`confirm` / `card_withdraw` 缺失」 | ✅ 成立 | 保留，见 G03 G04 |
| §2.7「加 2 条别名 `confirm→play`、`card_withdraw→draw` 即可」 | ✅ 判断正确，源文件时长（0.24 s / 0.18 s）匹配 | 采纳为 §8-M4 |
| §2.7「`defeat`/`draw`/`play` 未接入 3 个」 | ✅ 成立 | 保留，见 G11 G12 G13 |
| §3.1 把 `confirm`/`card_withdraw` 列为「真实缺失资产 #12 #13」 | ⚠️ 与 §2.7 口径不一致：它俩是**接线问题**，不是资产问题 | 建议以 §2.7 为准，§3.1 降级为"缺文件名" |
| 行号 `Slice.gd:4962`（stamp） | ❌ 已漂移，实际 **5099** | 本文用现行行号 |
| 行号 `Slice.gd:4978`（card_withdraw） | ❌ 已漂移，实际 **5115** | 同上 |
| 行号 `Slice.gd:4063,4895..4942,5608`（click） | ❌ 已漂移，实际 **4108 / 5032 / 5040 / 5050 / 5056 / 5063 / 5079 / 5745** | 同上 |
| 行号 `Slice.gd:3821`（赛季 keyart） | ❌ 已漂移，实际 **3869-3875** | 同上 |
| 未覆盖：BGM 循环、响度、总线、前后台、按钮覆盖率 | — | **本文新增**（§6 §7 §9 §10） |

---

## 12. 未做与限制

1. **未跑 Godot、未真机试听。** 所有"手机上听不见"的结论来自频段能量测量 + 手机扬声器滚降规律的推断，**必须真机复核**（§7.3 第 3 条）。
2. **未测运行时音量链路。** `-16 LUFS + 0.7` 的算术是静态推算；`AudioStreamPlayer.volume_db` 与 Master 的实际叠加需在导出 APK 上用录音确认。
3. `Main.gd` / `Main.tscn` / `Map.gd` / `Map.tscn` 未被主场景引用（`project.godot:14` → `Slice.tscn`，且全项目无引用），其内部按钮（`Map.gd` 2 处 `pressed.connect`）未纳入按钮统计；若确认是死代码，建议另行清理（不在本审计范围）。
4. 未评估 3 回合切片之外的赛季/商店/图鉴（占位页）音频需求。
5. 未改任何文件；本文第 8 章 5 条改动均为**建议**，仓库当前仍处于 §0 描述的状态。

---

*审计者：OpenCode（只读）· 2026-11-11 · 交付物：本文件 · 未 commit*
