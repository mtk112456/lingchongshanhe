# 布局复核任务（Antigravity / GPT 各自独立判断）

> 不要先改代码。先判断，再给修改建议。  
> 用户质疑：“你确定布局一样吗？” 之前的说法是“主结构学率土/三战”，需要核实是不是过度声称。

## 1. 先看这些文件

布局标注：

```text
tools/watch/layout_flow.jpg
tools/watch/layout_map_annotated.jpg
tools/watch/layout_login_annotated.jpg
```

页面截图：

```text
client/tests/screenshot_login_keyart.png
client/tests/screenshot_tablet_s01_map.png
client/tests/screenshot_tablet_s02_drawer.png
client/tests/screenshot_tablet_s03_order_confirm.png
client/tests/screenshot_tablet_s04_war_report.png
client/tests/screenshot_tablet_s05_battle_replay.png
client/tests/screenshot_tablet_s06_faction.png
client/tests/screenshot_tablet_s10_season.png
client/tests/screenshot_phone_portrait_s01_map.png
client/tests/screenshot_phone_landscape_s01_map.png
```

参考结构文档：

```text
PAGE_DESIGN.md
UI_STRUCTURE.md
ACCEPTANCE_STANDARD.md
```

## 2. 核心问题

请逐页回答，不要只说“像/不像”：

1. **主地图**：当前“纸卷地图 + 左右深色侧栏 + 居中浮动底栏”的案台布局，和率土/三战“全屏地图 + 半透明 HUD + 贴边导航”相比，哪些是真同构，哪些只是信息层级相似、视觉完全不同？
2. **登录页**：当前“全屏 C 主视觉 + 居中奶油纸卡 + 姓名密码 + 单主按钮”，和江南百景图/主流手游登录页相比，像到什么程度？哪些地方还是“开发工具页”？
3. **城池抽屉**：当前底部纸卡 + 两列信息 + 5 个动作按钮，和率土/三战点地块后的底部面板相比，差在哪？
4. **军令确认**：当前居中纸卡 + 两个按钮，是否足够像主流 SLG 的下令确认？还缺什么信息？
5. **战报/回放**：当前三张纸卡 + 全屏回放，和率土/三战战报相比，信息密度/层级差在哪？
6. **阵营/赛季**：当前四张卡 + 三张赛季卡，是否只是“卡片列表”，缺少主流 SLG 的页签/地图/排行榜结构？
7. **手机竖屏**：左右栏收成悬浮图标、底部导航保留、地图 9:16，这个适配是否成立？有没有挡住地图或操作？

## 3. 输出要求

- **Antigravity** 写到 `client/LAYOUT_REVIEW_ANTIGRAVITY.md`
- **GPT** 写到 `art_src/gpt/LAYOUT_REVIEW_GPT.md`

格式：

```markdown
# 布局复核
## 结论
- 哪些是真同构：
- 哪些只是信息层级像：
- 哪些明显不像：
## 逐页判断
| 页面 | 像的程度 1-5 | 像在哪 | 不像在哪 | 最值得改的 1 件事 |
## 最优先的 5 个修改
1. ...
## 不要做什么
- 不要复制商业游戏 UI/素材/文案
- 不要为了“像”牺牲学生可读性
```

不要改 `client/` 或 `server/` 代码；先只写复核文档。
