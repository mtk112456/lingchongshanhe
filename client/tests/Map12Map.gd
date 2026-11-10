extends Control

## 《青竹文房·灵宠山河》12 城大地图 · 13 节点沙盘叠层原型地图
## 背景：2560×1920 MAP12_LAYOUT_CONCEPT_V2.png
## 节点：西北笔 3 城、东北墨 3 城、西南砚 3 城、东南纸 3 城、中央中立王城长安（共 13 节点）
## 拓扑：四区内部三角互联 12 条 + 四大主城通向长安 4 条 = 16 条驰道

const FONT_PATH := "res://fonts/NotoSerifCJKsc-Regular.otf"
const ART_MAP_PATH := "res://assets/art/map12_concept_v2.png"

# Style C 水彩纸雕国风色板
const C_XUANZHI := Color("#f6efe2")
const C_WOOD_DESK := Color("#2f2721")
const C_ZHUSHA := Color("#b83b32")      # 笔阵营
const C_MOLAN := Color("#1e3a5f")       # 墨阵营
const C_ZHUQING := Color("#276f57")     # 砚阵营
const C_TENGHUANG := Color("#cf8325")   # 纸阵营
const C_CHANGAN_GOLD := Color("#e0992c") # 长安王城金
const GOLD_LIGHT := Color("#fae19c")
const NEUTRAL_GRAY := Color("#7e7263")

# 13 节点归一化锚点（严格依照 MAP12_ANCHORS_V2.md）
const NODES_DATA := {
	"liangzhou": {
		"name": "凉州", "region": "西北·笔", "faction": "bi", "color": C_ZHUSHA,
		"pos": Vector2(0.168, 0.150), "is_capital": false, "is_changan": false,
		"tex": "res://assets/art/city_liangzhou_trim.png", "tag": "【塞】大漠孤烟",
		"verse": "黄沙百战穿金甲，不破楼兰终不还"
	},
	"hanzhong": {
		"name": "汉中", "region": "西北·笔", "faction": "bi", "color": C_ZHUSHA,
		"pos": Vector2(0.300, 0.213), "is_capital": true, "is_changan": false,
		"tex": "res://assets/art/city_hanzhong_trim.png", "tag": "【隘】栈道连云",
		"verse": "长驱入蜀路，栈道出秦关"
	},
	"xiangyang": {
		"name": "襄阳", "region": "西北·笔", "faction": "bi", "color": C_ZHUSHA,
		"pos": Vector2(0.231, 0.338), "is_capital": false, "is_changan": false,
		"tex": "res://assets/art/city_xiangyang_trim.png", "tag": "【关】汉江锁钥",
		"verse": "江流天地外，山色有无中"
	},
	"yecheng": {
		"name": "邺城", "region": "东北·墨", "faction": "mo", "color": C_MOLAN,
		"pos": Vector2(0.654, 0.159), "is_capital": false, "is_changan": false,
		"tex": "res://assets/art/city_yanhui_trim.png", "tag": "【台】铜雀赋韵",
		"verse": "东临碣石，以观沧海"
	},
	"taiyuan": {
		"name": "太原", "region": "东北·墨", "faction": "mo", "color": C_MOLAN,
		"pos": Vector2(0.842, 0.223), "is_capital": false, "is_changan": false,
		"tex": "res://assets/art/city_taiyuan_trim.png", "tag": "【阁】晋祠古松",
		"verse": "白日依山尽，黄河入海流"
	},
	"luoyang": {
		"name": "洛阳", "region": "东北·墨", "faction": "mo", "color": C_MOLAN,
		"pos": Vector2(0.737, 0.336), "is_capital": true, "is_changan": false,
		"tex": "res://assets/art/city_luoyang_trim.png", "tag": "【都】伊洛文脉",
		"verse": "洛阳亲友如相问，一片冰心在玉壶"
	},
	"chengdu": {
		"name": "成都", "region": "西南·砚", "faction": "yan", "color": C_ZHUQING,
		"pos": Vector2(0.179, 0.621), "is_capital": false, "is_changan": false,
		"tex": "res://assets/art/city_tingyu_trim.png", "tag": "【庐】草堂春晓",
		"verse": "窗含西岭千秋雪，门泊东吴万里船"
	},
	"jiangling": {
		"name": "江陵", "region": "西南·砚", "faction": "yan", "color": C_ZHUQING,
		"pos": Vector2(0.267, 0.686), "is_capital": true, "is_changan": false,
		"tex": "res://assets/art/city_jiangling_trim.png", "tag": "【渚】楚泽清风",
		"verse": "千里江陵一日还，两岸猿声啼不住"
	},
	"changsha": {
		"name": "长沙", "region": "西南·砚", "faction": "yan", "color": C_ZHUQING,
		"pos": Vector2(0.221, 0.798), "is_capital": false, "is_changan": false,
		"tex": "res://assets/art/city_changsha_trim.png", "tag": "【院】岳麓青苍",
		"verse": "惟楚有材，于斯为盛"
	},
	"jianye": {
		"name": "建业", "region": "东南·纸", "faction": "zhi", "color": C_TENGHUANG,
		"pos": Vector2(0.802, 0.621), "is_capital": true, "is_changan": false,
		"tex": "res://assets/art/city_yanhui_trim.png", "tag": "【台】六朝繁华",
		"verse": "旧时王谢堂前燕，飞入寻常百姓家"
	},
	"kuaiji": {
		"name": "会稽", "region": "东南·纸", "faction": "zhi", "color": C_TENGHUANG,
		"pos": Vector2(0.747, 0.729), "is_capital": false, "is_changan": false,
		"tex": "res://assets/art/city_kuaiji_trim.png", "tag": "【亭】兰亭水曲",
		"verse": "群贤毕至，少长咸集，引以为流觞曲水"
	},
	"shouchun": {
		"name": "寿春", "region": "东南·纸", "faction": "zhi", "color": C_TENGHUANG,
		"pos": Vector2(0.704, 0.833), "is_capital": false, "is_changan": false,
		"tex": "res://assets/art/city_shouchun_trim.png", "tag": "【关】八公淮水",
		"verse": "八公山上，草木皆兵"
	},
	"changan": {
		"name": "长安", "region": "中原·天下王城", "faction": "neutral", "color": C_CHANGAN_GOLD,
		"pos": Vector2(0.500, 0.500), "is_capital": true, "is_changan": true,
		"tex": "res://assets/art/city_changan_trim.png", "tag": "【皇】盛唐极胜",
		"verse": "长安回望绣成堆，山顶千门次第开"
	},
}

# 19 条拓扑驰道（4 区三角 12 条 + 4 主城通长安 4 条 + 3 条跨区边）
const EDGES := [
	# 西北笔阵营内环 (3 条)
	["liangzhou", "hanzhong"],
	["hanzhong", "xiangyang"],
	["xiangyang", "liangzhou"],
	# 东北墨阵营内环 (3 条)
	["yecheng", "taiyuan"],
	["taiyuan", "luoyang"],
	["luoyang", "yecheng"],
	# 西南砚阵营内环 (3 条)
	["chengdu", "jiangling"],
	["jiangling", "changsha"],
	["changsha", "chengdu"],
	# 东南纸阵营内环 (3 条)
	["jianye", "kuaiji"],
	["kuaiji", "shouchun"],
	["shouchun", "jianye"],
	# 四大主城通向中央王城长安 (4 条核心枢纽干道)
	["hanzhong", "changan"],
	["luoyang", "changan"],
	["jiangling", "changan"],
	["jianye", "changan"],
	# 跨区边 (3 条，避免前两周无事可做)
	["liangzhou", "taiyuan"],
	["xiangyang", "luoyang"],
	["jiangling", "jianye"],
]

var art_texture: Texture2D = null
var font: Font = null
var textures_cache: Dictionary = {}

var zoom_level: float = 1.0
var selected_node: String = "changan"
var pulse: float = 0.0
var show_labels: bool = true

func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)
	art_texture = _load_tex(ART_MAP_PATH)
	
	# 缓存城池贴图
	for code in NODES_DATA.keys():
		var path: String = NODES_DATA[code].get("tex", "")
		var tex := _load_tex(path)
		if tex != null:
			textures_cache[code] = tex
			
	set_process(true)

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	var global_p := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_p):
		var img := Image.load_from_file(global_p)
		if img != null:
			return ImageTexture.create_from_image(img)
	return null

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func set_zoom_level(z: float) -> void:
	zoom_level = z
	queue_redraw()

func select_node(code: String) -> void:
	selected_node = code
	queue_redraw()

func _map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)

func _art_dest_rect() -> Rect2:
	return _map_rect()

func node_screen_position(code: String) -> Vector2:
	if not NODES_DATA.has(code):
		return size / 2.0
	var norm: Vector2 = NODES_DATA[code]["pos"]
	var dest := _art_dest_rect()
	return dest.position + Vector2(norm.x * dest.size.x, norm.y * dest.size.y)

func _draw() -> void:
	var total_rect := _map_rect()
	var dest := _art_dest_rect()

	# 1. 宣纸底衬
	draw_rect(total_rect, C_XUANZHI)

	# 2. 2560×1920 V2 高清青绿金碧水墨大地图底图
	if art_texture != null:
		draw_texture_rect(art_texture, dest, false)
		# 极轻暖宣纸泛光层，增进整体文房古典质感与文字对比度
		draw_rect(dest, Color(0.96, 0.91, 0.82, 0.03))

	# 3. 细金卷轴外边框
	draw_rect(dest, Color("#c8b89e"), false, 1.5)
	draw_rect(total_rect, Color(0.81, 0.51, 0.15, 0.45), false, 2.0)

	# 4. 16 条拓扑驰道（数据驱动，深墨外晕 + 金色能量 + 动态虚线流光）
	_draw_edges()

	# 5. 13 个城池节点（包含独立 Trim Sprite、阵营战旗、地基光环、LOD 纸签）
	for code in NODES_DATA.keys():
		_draw_city_node(code)

# 绘制 16 条驰道连接线
func _draw_edges() -> void:
	for e in EDGES:
		var code_a: String = e[0]
		var code_b: String = e[1]
		var pa := node_screen_position(code_a)
		var pb := node_screen_position(code_b)
		var is_active := (selected_node != "" and (code_a == selected_node or code_b == selected_node))

		if is_active:
			# 高亮三层金色流光（选中状态）
			# 层 1: 深墨色高对比外晕（宽 10px，确保在浅色麦浪、雪山及东南水网高光上轮廓分明）
			draw_line(pa, pb, Color(0.12, 0.08, 0.04, 0.65), 10.0, true)
			# 层 2: 烫金发光能量底晕（宽 6.0px）
			draw_line(pa, pb, Color(0.96, 0.72, 0.18, 0.90), 6.0, true)
			# 层 3: 亮白金动态虚线流光（宽 3.5px，顺驰道流动）
			var dash_offset := fmod(pulse * 26.0, 24.0)
			_draw_animated_path(pa, pb, Color(1.0, 0.98, 0.86), 3.5, 16.0, 8.0, dash_offset)
		else:
			# 默认状态：暗墨褐条石路基 + 深色细虚线（不抢底图，在东南水网中带深色防吞外晕）
			draw_line(pa, pb, Color(0.16, 0.12, 0.08, 0.45), 6.0, true)
			draw_line(pa, pb, Color("#dfcfb4", 0.75), 4.0, true)
			draw_line(pa, pb, Color("#5a4838", 0.85), 2.0, true)

func _draw_animated_path(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float, gap_len: float, offset: float) -> void:
	var total_len := (to - from).length()
	if total_len <= 0.0:
		return
	var dir := (to - from) / total_len
	var cur_dist := fmod(offset, dash_len + gap_len)
	if cur_dist > 0.0:
		cur_dist -= (dash_len + gap_len)
	while cur_dist < total_len:
		var start_d := maxf(cur_dist, 0.0)
		var end_d := minf(cur_dist + dash_len, total_len)
		if end_d > start_d:
			draw_line(from + dir * start_d, from + dir * end_d, color, width, true)
		cur_dist += (dash_len + gap_len)

# 绘制单个城池节点
func _draw_city_node(code: String) -> void:
	var data: Dictionary = NODES_DATA[code]
	var pos := node_screen_position(code)
	var faction_color: Color = data["color"]
	var is_changan: bool = data.get("is_changan", false)
	var is_capital: bool = data.get("is_capital", false)
	var is_selected := (code == selected_node)

	# 1. 城池建筑尺寸（长安为王城，设定显著更大尺寸，绝不缩小）
	var target_h := 136.0 if is_changan else (106.0 if is_capital else 92.0)
	if code == "liangzhou":
		target_h = 78.0 # 凉州为长横截关隘，适度缩减高度保持自然比例
	var target_w := target_h * 1.35

	# 0. 浅色落点与各城池的有机暗色自然衬底（柳荫、青石、松影、苔藓湿地，打破死板圆斑）
	_draw_natural_ground_shadow(code, pos, target_w)

	# 2. 独立 Trim Sprite 叠放（底边中点精确对齐锚点 pos，等比缩放不拉伸）
	if textures_cache.has(code) and textures_cache[code] != null:
		var tex: Texture2D = textures_cache[code]
		var tex_sz := tex.get_size()
		if tex_sz.y > 0.0:
			target_w = target_h * (tex_sz.x / tex_sz.y)
			var sprite_rect := Rect2(pos.x - target_w / 2.0, pos.y - target_h, target_w, target_h)
			draw_texture_rect(tex, sprite_rect, false)

	# 3. 阵营地基光环与选中动效
	if is_changan:
		# 长安天下王城：极度尊贵的帝王双金环 + 八宝光环脉冲（保持 54px 尊贵规格，绝不缩小成普通城）
		var r_ca := 54.0
		var r_pulse := r_ca + sin(pulse * 3.5) * 4.0
		draw_circle(pos, r_pulse, Color(C_CHANGAN_GOLD.r, C_CHANGAN_GOLD.g, C_CHANGAN_GOLD.b, 0.22))
		draw_arc(pos, r_pulse, 0.0, TAU, 64, C_CHANGAN_GOLD, 4.0, true)
		draw_arc(pos, r_pulse + 6.0, 0.0, TAU, 64, GOLD_LIGHT, 2.0, true)
		draw_arc(pos, r_pulse - 8.0, 0.0, TAU, 64, Color("#80241d"), 1.8, true)
	elif is_selected:
		var r_sel := 42.0 + sin(pulse * 3.5) * 3.5
		draw_circle(pos, r_sel, Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 0.18))
		draw_arc(pos, r_sel, 0.0, TAU, 48, GOLD_LIGHT, 3.5, true)
		draw_arc(pos, r_sel + 6.0, 0.0, TAU, 48, faction_color, 2.0, true)
	else:
		var r_base := 32.0 if is_capital else 26.0
		if zoom_level < 0.45:
			r_base = 28.0 # 远景下适当凸显光环，便于一眼数清
		draw_circle(pos, r_base, Color(faction_color.r, faction_color.g, faction_color.b, 0.14))
		draw_arc(pos, r_base, 0.0, TAU, 36, faction_color, 2.5, true)
		draw_arc(pos, r_base + 3.0, 0.0, TAU, 36, Color(C_XUANZHI.r, C_XUANZHI.g, C_XUANZHI.b, 0.75), 1.2, true)

	# 4. 战台迎风旌旗（立于城池右上方战台，不遮挡大门与地基标签）
	var flag_pole_h := 46.0 if is_changan else (38.0 if is_capital else 32.0)
	var pole_base := pos + Vector2(target_w * 0.32, -target_h * 0.60)
	var pole_top := pole_base + Vector2(0, -flag_pole_h)
	draw_line(pole_base, pole_top, Color("#3a2a1a"), 2.5, true)
	draw_circle(pole_top, 2.8, GOLD_LIGHT)
	var wave := sin(pulse * 3.2 + pos.x * 0.05) * 3.0
	var flag := PackedVector2Array([
		pole_top,
		pole_top + Vector2(26, 4 + wave),
		pole_top + Vector2(18, 14),
		pole_top + Vector2(28, 20 - wave),
		pole_top + Vector2(0, 16),
	])
	draw_polyline(flag, Color(C_XUANZHI.r, C_XUANZHI.g, C_XUANZHI.b, 0.95), 3.5, true)
	draw_colored_polygon(flag, faction_color)
	draw_polyline(flag, Color("#2b1e13"), 1.5, true)

	# 5. LOD 文字信息分级渲染
	# -----------------------------------------------------------------------
	# 若全局禁用标签或处于宏观全景态（LOD 0，全景全图）：彻底隐藏纸签，保证大局观清晰不拥挤
	if not show_labels or zoom_level < 0.45:
		return

	# LOD 1 (0.45x ~ 0.75x，如 0.50x 手机横屏/区域视野)：精简单行城名纸签，隐藏归属签
	if zoom_level < 0.75:
		_draw_compact_city_label(pos, data["name"], faction_color, is_changan, is_selected)
		return

	# LOD 2 (0.75x ~ 1.30x，战术常规近景)：完整城名纸签 + 阵营归属副签
	_draw_full_city_label(pos, data["name"], data["region"], faction_color, is_changan)

	# LOD 3 (>= 1.30x，文化特写)：文化地标与诗词文脉
	_draw_cultural_tag(pos, data.get("tag", ""), data.get("verse", ""))

# 自然有机暗色地基衬底（柳荫、青石、松影、苔藓湿地，打破机械圆斑）
func _draw_natural_ground_shadow(code: String, pos: Vector2, target_w: float) -> void:
	var hw := target_w * 0.55
	if code in ["jianye", "kuaiji", "shouchun"]:
		# 东南浅沙洲水网：江岸垂柳绿荫 + 渚头湿石倒影（墨绿色系，向下浸润向江面）
		var col_dark := Color(0.08, 0.16, 0.13, 0.38)
		var col_soft := Color(0.05, 0.12, 0.10, 0.20)
		var poly1 := PackedVector2Array([
			pos + Vector2(-hw * 0.95, 4.0),
			pos + Vector2(-hw * 0.50, -8.0),
			pos + Vector2(hw * 0.40, -10.0),
			pos + Vector2(hw * 1.10, 2.0),
			pos + Vector2(hw * 0.90, 16.0),
			pos + Vector2(hw * 0.30, 22.0),
			pos + Vector2(-hw * 0.40, 18.0),
			pos + Vector2(-hw * 0.85, 12.0),
		])
		draw_colored_polygon(poly1, col_dark)
		# 外围柳丝轻影羽化
		var poly2 := PackedVector2Array([
			pos + Vector2(-hw * 1.15, 6.0),
			pos + Vector2(-hw * 0.60, -14.0),
			pos + Vector2(hw * 0.55, -16.0),
			pos + Vector2(hw * 1.25, 4.0),
			pos + Vector2(hw * 1.05, 22.0),
			pos + Vector2(hw * 0.20, 28.0),
			pos + Vector2(-hw * 0.65, 24.0),
		])
		draw_colored_polygon(poly2, col_soft)
	elif code in ["taiyuan", "luoyang"]:
		# 东北浅麦田台地：古祠苍松影 + 晋祠伊洛青石基（墨褐色系，向右后侧斜向散布松影齿）
		var col_pine := Color(0.18, 0.12, 0.08, 0.42)
		var col_pine_soft := Color(0.12, 0.08, 0.05, 0.22)
		var poly1 := PackedVector2Array([
			pos + Vector2(-hw * 0.90, -4.0),
			pos + Vector2(-hw * 0.20, -12.0),
			pos + Vector2(hw * 0.70, -6.0),
			pos + Vector2(hw * 1.15, 10.0),
			pos + Vector2(hw * 0.75, 20.0),
			pos + Vector2(hw * 0.10, 16.0),
			pos + Vector2(-hw * 0.50, 14.0),
			pos + Vector2(-hw * 0.85, 6.0),
		])
		draw_colored_polygon(poly1, col_pine)
		var poly2 := PackedVector2Array([
			pos + Vector2(-hw * 1.05, -2.0),
			pos + Vector2(hw * 0.10, -18.0),
			pos + Vector2(hw * 1.30, 12.0),
			pos + Vector2(hw * 0.80, 26.0),
			pos + Vector2(-hw * 0.70, 20.0),
		])
		draw_colored_polygon(poly2, col_pine_soft)
	elif code == "changan":
		# 长安王城：九重宫阙紫金石基台影（恢弘沉着，深墨紫金）
		var col_ca := Color(0.16, 0.09, 0.04, 0.45)
		var poly_ca := PackedVector2Array([
			pos + Vector2(-hw * 1.05, -2.0),
			pos + Vector2(-hw * 0.60, -14.0),
			pos + Vector2(hw * 0.60, -14.0),
			pos + Vector2(hw * 1.05, -2.0),
			pos + Vector2(hw * 0.95, 18.0),
			pos + Vector2(0.0, 24.0),
			pos + Vector2(-hw * 0.95, 18.0),
		])
		draw_colored_polygon(poly_ca, col_ca)
	else:
		# 西北山地与西南竹林：水墨岩崖苍石影
		var col_std := Color(0.14, 0.12, 0.10, 0.32)
		var poly_std := PackedVector2Array([
			pos + Vector2(-hw * 0.85, 0.0),
			pos + Vector2(-hw * 0.30, -10.0),
			pos + Vector2(hw * 0.50, -8.0),
			pos + Vector2(hw * 0.95, 6.0),
			pos + Vector2(hw * 0.60, 16.0),
			pos + Vector2(-hw * 0.40, 14.0),
		])
		draw_colored_polygon(poly_std, col_std)

# 精简单行城名纸签（LOD 1）
# 采用逆向缩放补偿（Screen-Space Invariant），保证屏幕视觉字号严格 ≥12px (实测 13.0px)
func _draw_compact_city_label(pos: Vector2, city_name: String, faction_color: Color, is_changan: bool, is_selected: bool) -> void:
	if font == null:
		return
	
	# 屏幕基准尺寸 (Screen Pixels)
	var screen_font_size := 13.0
	var screen_w := 76.0 if not is_changan else 90.0
	var screen_h := 22.0
	
	# 逆向补偿到世界坐标系
	var z := maxf(zoom_level, 0.1)
	var world_font_size := int(round(screen_font_size / z))
	var tw := screen_w / z
	var th := screen_h / z
	var y_gap := 10.0 / z
	var border_w := (2.5 if is_selected else 1.8) / z
	var shadow_pad := 1.8 / z
	
	var rect := Rect2(pos + Vector2(-tw / 2.0, y_gap), Vector2(tw, th))
	
	# 1. 软宣纸暗部投影
	draw_rect(rect.grow(shadow_pad), Color(0, 0, 0, 0.28))
	
	# 2. 宣纸底衬 (选中时象牙微亮，未选中时温润宣纸色)
	var bg_color := Color("#fffef7") if is_selected else C_XUANZHI
	draw_rect(rect, bg_color)
	
	# 3. 描边体系 (选中时加粗烫金 + 阵营双线，未选中时阵营描边)
	if is_selected:
		draw_rect(rect, GOLD_LIGHT, false, border_w)
		draw_rect(rect.grow(-border_w * 0.7), faction_color, false, 1.2 / z)
	else:
		draw_rect(rect, faction_color, false, border_w)
		
	# 4. 苍劲书法城名 (严格居中，高对比)
	var text_col := Color("#801b12") if (is_selected or is_changan) else Color("#1a110a")
	var text_y := rect.position.y + th - (5.0 / z)
	draw_string(font, Vector2(rect.position.x, text_y), city_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, world_font_size, text_col)

# 完整城名纸签与归属副签（LOD 2）
func _draw_full_city_label(pos: Vector2, city_name: String, region: String, faction_color: Color, is_changan: bool) -> void:
	if font == null:
		return
	# 1. 城名主签
	var tw := 78.0 if not is_changan else 96.0
	var th := 22.0
	var rect := Rect2(pos + Vector2(-tw / 2.0, 8.0), Vector2(tw, th))
	draw_rect(rect.grow(2.0), Color(0, 0, 0, 0.18))
	draw_rect(rect, C_XUANZHI)
	draw_rect(rect, faction_color, false, 2.0)
	draw_rect(rect.grow(-3), Color("#cfbfa6"), false, 1.0)
	draw_string(font, rect.position + Vector2(0, th - 5.0), city_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, C_WOOD_DESK)

	# 2. 阵营归属副签
	var sub_w := 92.0
	var sub_h := 16.0
	var sub_rect := Rect2(pos + Vector2(-sub_w / 2.0, 32.0), Vector2(sub_w, sub_h))
	draw_rect(sub_rect, Color(C_XUANZHI.r, C_XUANZHI.g, C_XUANZHI.b, 0.90))
	draw_rect(sub_rect, Color(faction_color.r, faction_color.g, faction_color.b, 0.45), false, 1.0)
	draw_string(font, sub_rect.position + Vector2(0, sub_h - 3.5), region, HORIZONTAL_ALIGNMENT_CENTER, sub_rect.size.x, 10, Color("#554433"))

# 文化地标与诗句（LOD 3）
func _draw_cultural_tag(pos: Vector2, tag_text: String, _verse: String) -> void:
	if font == null or tag_text == "":
		return
	var rect := Rect2(pos + Vector2(-54.0, 52.0), Vector2(108.0, 20.0))
	draw_rect(rect.grow(1.0), Color(0, 0, 0, 0.18))
	draw_rect(rect, Color("#261c16"))
	draw_rect(rect, GOLD_LIGHT, false, 1.0)
	draw_string(font, rect.position + Vector2(0, 15.0), tag_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, GOLD_LIGHT)
