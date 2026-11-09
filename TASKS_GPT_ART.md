# GPT 美术首批任务

> 分支：`art/gpt-first-batch`  
> 规则：`ART_BRIEF_GPT.md`、`AGENTS.md`  
> 输出目录：`art_src/gpt/`（原图 + prompt），后处理后再进 `client/assets/art/`

---

## 任务 1：风格锁定 3 选 1

生成 3 张同构图、不同质感的概念图：

1. 纸雕绘本；
2. 纸雕 + 更明亮 Q 版；
3. 手绘水彩纸雕。

要求：

- 16:10；
- 5 节点地图 + 右侧 UI 面板；
- 无文字；
- 同一构图，便于比较。

验收：

- 3 张能看出明显差异；
- 选 1 张作为主风格，写进 `ART_BRIEF_GPT.md` 的“最终选择”。

---

## 任务 2：主视觉

基于选定风格，生成：

```text
art_src/gpt/keyart_main.png
```

要求：

- 2560×1600；
- 5 节点地图 + 右侧奶油纸卡面板；
- 小青竹/墨点精在角落；
- 无文字；
- 不直接用作游戏内 UI，只作为风格基准/宣传图。

---

## 任务 3：UI Kit

生成：

```text
ui_panel_main.9.png
ui_button_primary.png
ui_button_secondary.png
ui_button_confirm.png
ui_order_slot_empty.png
icon_resource_food.png
icon_resource_wood.png
icon_resource_iron.png
icon_resource_jade.png
```

要求：

- 无文字；
- 9-patch 面板四边留 12–16px；
- 图标 256×256 透明；
- 统一厚描边/纸片质感。

---

## 任务 4：5 个城池标记

```text
city_yunlu_{neutral,bi,mo,selected}.png
city_songfeng_{neutral,bi,mo,selected}.png
city_luoxia_{neutral,bi,mo,selected}.png
city_tingyu_{neutral,bi,mo,selected}.png
city_yanhui_{neutral,bi,mo,selected}.png
```

要求：

- 512×512 透明；
- 中立/笔/墨/选中四态；
- 无文字；
- 起点和普通城有结构差异。

---

## 任务 5：班宠向导

```text
mascot_bamboo_{normal,happy,nervous}.png
mascot_inkdrop_{normal,proud,sad}.png
```

要求：

- 1024×1024 透明；
- 同一角色三表情一致；
- 无文字/背景。

---

## 交付格式

```text
生成模型/工具：
Prompt 原文：
参考图：
输出文件：
后处理：
验收：
  - 无文字
  - 透明背景
  - 色板符合
  - 64px 可读
未处理/阻塞：
```

---

## 不要做

- 不要把图直接塞进 `client/assets/art/` 而不去背景；
- 不要让图里出现中文/英文/数字；
- 不要每个资产换一种画风；
- 不要复制 Unciv 或商业游戏素材；
- 不要用 GPT 生成的图直接替代最终人工精修（可以作为第一版）。
