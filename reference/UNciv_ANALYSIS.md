# Unciv 参考拆解（合法开源参考）

> 参考项目：https://github.com/yairm210/Unciv  
> 版本：4.22.18-patch1  
> 许可：Mozilla Public License 2.0（MPL-2.0）  
> 本文件只记录结构和思路，**没有复制 Unciv 的代码、美术、音频或文案**。

---

## 1. 为什么选 Unciv

- 开源、可读、长期维护；
- 回合制、地图、城市/阵营、战斗、通知、战局回放都齐全；
- 它是 LibGDX/Kotlin，不是 Godot，所以不能直接搬代码，只能借结构。

不选商业游戏做反编译的原因：

- 许可和著作权风险；
- 反编译代码不可维护；
- 无法直接接现有班级积分、班宠、教师后台；
- 换皮上线风险高。

---

## 2. 重点看的文件

| 文件 | 看什么 |
|---|---|
| `core/src/com/unciv/logic/civilization/managers/TurnManager.kt` | 回合开始/结束、每回合重置、通知生成 |
| `core/src/com/unciv/logic/battle/Battle.kt` | 战斗结算顺序、战后通知、城市攻陷 |
| `core/src/com/unciv/logic/civilization/Notification.kt` | 通知分类、文本、图标、可点击动作 |
| `core/src/com/unciv/ui/screens/victoryscreen/VictoryScreenReplay.kt` | 战局回放：按回合滑杆、播放/暂停、地图重绘 |
| `core/src/com/unciv/ui/screens/victoryscreen/ReplayMap.kt` | 回放地图如何按回合更新 |
| `core/src/com/unciv/ui/screens/worldscreen/bottombar/BattleTable.kt` | 战斗结果表、双方数值、战报展示 |
| `core/src/com/unciv/logic/map/TileMap.kt` | 地图/格子/归属的组织方式 |

---

## 3. 借了什么

### 3.1 战局回放

Unciv 的回放不是重新打一遍，而是保存每回合状态，按回合切换地图。

我们落地为：

- 服务端 `SliceService::getReplay()`：
  - 只读已结算回合；
  - 从初始归属开始，按 `node_changes` 逐回合应用；
  - 返回每回合的 `owners` 快照、变化列表、总分；
- 客户端 `ReplayMap.gd`：
  - 画 5 节点地图；
  - 按回合着色；
  - 变化节点金色高亮；
- 客户端 `Slice.gd`：
  - “战局回放”弹窗；
  - 回合下拉、上一回合/下一回合；
  - 战报文字 + 地图同步切换。

### 3.2 通知/战报的“可行动”

Unciv 的 Notification 不只显示文本，还带图标和动作，点击可以跳到城市/单位。

我们已有：

- 每条个人战报带 `next_hint`；
- 全局战报带 `reason_text`；
- 客户端战报里显示“下回合提示”。

没有照搬它的 Action 体系，因为我们的点击目标只有城池/军令，不需要通用动作框架。

### 3.3 回合阶段

Unciv 把 `startTurn`、城市回合、单位回合、通知生成分开。

我们保持更简单的切片：

- `open`：可下令；
- `locked`：快照只读；
- `settling`：结算中；
- `settled`：结果/战报已发布；
- `failed`：保留快照可重试。

这比 Unciv 轻很多，但足以支持 21:00 结算和失败补算。

---

## 4. 没有借什么

- 没有用 Civ 的六边形地图、单位、科技、政策、外交；
- 没有用它的战斗数值公式；
- 没有复制任何 Kotlin 代码；
- 没有复制美术/音频/文本；
- 没有引入 LibGDX；
- 没有把 12 城做成 4X，仍然是班级级轻 SLG。

---

## 5. 对我们代码的直接影响

新增：

```text
server/slice/src/SliceService.php::getReplay()
server/slice/public/index.php  GET /api/slice/replay
client/ReplayMap.gd
client/Slice.gd 战局回放弹窗
server/slice/tests/run.php  replay 用例
```

验收从 13 项增加到 **14 项通过**。

---

## 6. 下一步可参考但不急

| 参考 | 可借 | 不急的原因 |
|---|---|---|
| Battle for Wesnoth | 战斗日志、回合回放、单位状态 | 我们是 5 节点轻战斗，不需要完整战棋 |
| Pokemon Showdown | 回合事件流、技能日志 | 切片阶段关闭技能/法宝 |
| Freeciv | 服务端权威回合制、存档 | 我们已有 PHP 权威结算 |
| Travian/OGame 类 | 异步资源/建造队列 | 正式版 P2 再考虑 |

---

## 7. 结论

Unciv 适合做“回合制地图 + 战报 + 回放”的结构参考，不适合直接搬。

我们已经借它的**回放信息结构**，落地成自己的 PHP API + Godot UI；  
这比反编译商业游戏更安全，也更能接现有班级系统。
