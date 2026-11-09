# 第一批概念稿交接

**图像生成能力：可用，生成已完成。** 使用内置 imagegen 分别生成三张原创概念图。无输入参考图。各提示词文件保存实际投喂内容。

| 方向 | 图稿 | 提示词 |
|---|---|---|
| A 纸雕绘本 | [style_a.png](style_a.png) | [prompt_style_a.md](prompt_style_a.md) |
| B 明亮 Q 版纸雕 | [style_b.png](style_b.png) | [prompt_style_b.md](prompt_style_b.md) |
| C 手绘水彩纸雕 | [style_c.png](style_c.png) | [prompt_style_c.md](prompt_style_c.md) |

交付还包括 [README.md](README.md)（风格对照）和本文件 HANDOFF.md，共 8 份文件。

三张 PNG 均从 imagegen 的 1586×992 原图四边各裁 1 像素，交付尺寸为 1584×990，严格 16:10。目视检查均有五个节点、右侧留白面板及两只向导，未发现可读文字、水印或标识。三稿使用同一构图和色板指令，实际节点轮廓、色值与道具位置有生成偏差。三稿面板均出现两排各三个空位，B 还多出两条外侧路线。画面用于对照质感，后续正式布局和路线需按切片规则还原。仅做画幅裁切，未调色或拆分透明资产。

建议先用 A 做小屏可读性基准，B 用于比较轮廓简化，C 用于比较地貌氛围。待产品方选定后，在固定拓扑上制作 2560×1600 主视觉，再分离地图、面板、城标和班宠。Godot 接入由 Antigravity 负责。未进行真机验收。
