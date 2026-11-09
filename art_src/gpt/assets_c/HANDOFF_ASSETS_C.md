# C 方向五节点资产交接

以已通过的 keyart_c.png 为风格参考，用内置 imagegen 分别生成地标图集、表情图集和 UI Kit 板。两张图集按网格切出单张，保留模型生成的透明通道。班宠从 512×512 切片重采样到 1024×1024。

| 文件 | 内容 | 规格 |
|---|---|---|
| city_yunlu.png | 云麓关，关隘与烽火台 | 512×512 RGBA |
| city_songfeng.png | 松风渡，渡口与乌篷船 | 512×512 RGBA |
| city_luoxia.png | 落霞原，草庐与田野 | 512×512 RGBA |
| city_tingyu.png | 听雨台，亭台与竹林 | 512×512 RGBA |
| city_yanhui.png | 雁回关，关楼与雁塔 | 512×512 RGBA |
| mascot_bamboo_normal.png / mascot_bamboo_happy.png / mascot_bamboo_nervous.png | 小青竹，普通、开心、紧张 | 各 1024×1024 RGBA |
| mascot_inkdrop_normal.png / mascot_inkdrop_proud.png / mascot_inkdrop_sad.png | 墨点精，普通、得意、委屈 | 各 1024×1024 RGBA |
| ui_kit_c.png | 奶油纸卡、三个军令槽、朱砂和墨蓝按钮、粮木铁玉图标 | 1586×992 概念板 |

11 张透明 PNG 均验证尺寸、RGBA 和四角 alpha=0。部分图的低透明度残留可触及画布边缘，接入前宜在实际地图底色复核。生成图目视未发现文字、字母、数字或伪文字。UI 板为整图，后续由人工切分。尚未做 64px 真机可读性验收。

下一步由 Antigravity 按 MAP_SPEC 接入五节点，低缩放显示归属和路线，高缩放再展示地标。确认班宠切换时锚点稳定，UI 切分后再测小屏对比度。
