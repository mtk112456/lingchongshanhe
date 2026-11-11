extends Control

## 《青竹文房·灵宠山河》12 城大地图 · 13 节点沙盘地图组件 (生产版)
## 背景：2560×1920 map12_concept_v2.png
## 节点：西北笔 3 城、东北墨 3 城、西南砚 3 城、东南纸 3 城、中央中立王城长安（共 13 节点）
## 拓扑：4 区三角 12 条 + 4 主城通长安 4 条 + 3 条跨区边 = 19 条驰道

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
		"tex": "res://assets/art/city_yecheng_trim.png", "tag": "【台】铜雀赋韵",
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
		"tex": "res://assets/art/city_chengdu_trim.png", "tag": "【庐】草堂春晓",
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
		"tex": "res://assets/art/city_jianye_trim.png", "tag": "【台】六朝繁华",
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
var faction_flags: Dictionary = {}

var map_data: Dictionary = {}
var selected_node: String = ""
var my_order: Variant = null
var pulse: float = 0.0
var zoom_level: float = 1.0
var show_labels: bool = true
var hud_safe_mode: bool = false
var scouted_nodes: Array = []
var reachable_targets: Array = []

# ---------------------------------------------------------------------------
# Slice 标准地图接口契约
# ---------------------------------------------------------------------------

func setup(data: Dictionary) -> void:
	map_data = data
	queue_redraw()

func set_selected(code: String) -> void:
	selected_node = code
	queue_redraw()

func select_node(code: String) -> void:
	set_selected(code)

func set_my_order(order: Variant) -> void:
	my_order = order
	queue_redraw()

func set_zoom_level(z: float) -> void:
	zoom_level = z
	queue_redraw()

func set_fog_data(scouted: Array, reachable: Array) -> void:
	scouted_nodes = scouted
	reachable_targets = reachable
	queue_redraw()

func node_position(code: String) -> Vector2:
	if NODES_DATA.has(code):
		var norm: Vector2 = NODES_DATA[code]["pos"]
		return Vector2(norm.x * size.x, norm.y * size.y)
	return size / 2.0

func node_screen_position(code: String) -> Vector2:
	return node_position(code)

func node_by_code(code: String) -> Dictionary:
	var base_data: Dictionary = {}
	if NODES_DATA.has(code):
		base_data = NODES_DATA[code].duplicate()
	else:
		base_data = {
			"name": code,
			"region": "未知要冲",
			"faction": "neutral",
			"color": NEUTRAL_GRAY,
			"pos": Vector2(0.5, 0.5),
		}

	# 从实时服务端数据中合并动态字段（owner, is_my_faction, morale, defense, node_type 等）
	for n in map_data.get("nodes", []):
		if str(n.get("code", "")) == code:
			for k in n.keys():
				base_data[k] = n[k]
			break
	return base_data

# ---------------------------------------------------------------------------
# 节点生命周期与贴图装载
# ---------------------------------------------------------------------------

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

	# 缓存 4 面正式水墨阵营旗 (bi / mo / yan / zhi)
	var flag_map := {
		"bi": "res://assets/art/ui/flag_faction_bi.png",
		"mo": "res://assets/art/ui/flag_faction_mo.png",
		"yan": "res://assets/art/ui/flag_faction_yan.png",
		"zhi": "res://assets/art/ui/flag_faction_zhi.png",
	}
	for f_code in flag_map:
		var f_tex := _load_tex(flag_map[f_code])
		if f_tex != null:
			faction_flags[f_code] = f_tex
			
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

func _map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)

func _art_dest_rect() -> Rect2:
	return _map_rect()

# ---------------------------------------------------------------------------
# 绘图流水线
# ---------------------------------------------------------------------------

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

	# 4. 19 条拓扑驰道（数据驱动，深墨外晕 + 金色能量 + 动态虚线流光）
	_draw_edges()

	# 5. 13 个城池节点（包含独立 Trim Sprite、阵营战旗、地基光环、LOD 纸签）
	for code in NODES_DATA.keys():
		_draw_city_node(code)

	# 6. 当前下达军令的行军流光路线（如有）
	_draw_order_march_line()

func _draw_edges() -> void:
	var edges_to_draw: Array = map_data.get("edges", EDGES)
	if edges_to_draw.is_empty():
		edges_to_draw = EDGES

	for e in edges_to_draw:
		if typeof(e) != TYPE_ARRAY or e.size() < 2:
			continue
		var code_a: String = str(e[0])
		var code_b: String = str(e[1])
		var pa := node_position(code_a)
		var pb := node_position(code_b)
		var is_active := (selected_node != "" and (code_a == selected_node or code_b == selected_node))

		if is_active:
			# 高亮三层金色流光（选中状态）
			draw_line(pa, pb, Color(0.12, 0.08, 0.04, 0.65), 10.0, true)
			draw_line(pa, pb, Color(0.96, 0.72, 0.18, 0.90), 6.0, true)
			var dash_offset := fmod(pulse * 26.0, 24.0)
			_draw_animated_path(pa, pb, Color(1.0, 0.98, 0.86), 3.5, 16.0, 8.0, dash_offset)
		else:
			# 默认状态：暗墨褐条石路基 + 暖白条石中线 + 细墨纹
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

func _draw_order_march_line() -> void:
	if typeof(my_order) != TYPE_DICTIONARY:
		return
	var orig := str(my_order.get("origin_code", ""))
	var targ := str(my_order.get("target_code", ""))
	if orig == "" or targ == "" or orig == targ:
		return
	var pa := node_position(orig)
	var pb := node_position(targ)
	# 醒目红金行军箭头流光
	draw_line(pa, pb, Color(0.72, 0.18, 0.12, 0.85), 7.0, true)
	var dash_offset := fmod(pulse * 36.0, 24.0)
	_draw_animated_path(pa, pb, Color("#fae19c"), 4.0, 14.0, 6.0, dash_offset)

func _draw_city_node(code: String) -> void:
	var data: Dictionary = NODES_DATA.get(code, {})
	var pos := node_position(code)
	var is_changan: bool = data.get("is_changan", false)
	var is_capital: bool = data.get("is_capital", false)
	var is_selected := (code == selected_node)

	# 迷雾状态判定
	var is_reachable: bool = reachable_targets.is_empty() or reachable_targets.has(code)
	var is_scouted: bool = scouted_nodes.has(code)

	# 阵营色彩：优先采用实时归属阵营
	var faction_color: Color = data.get("color", NEUTRAL_GRAY)
	var f_code: String = data.get("faction", "")
	var gov_data: Variant = null
	for n in map_data.get("nodes", []):
		if str(n.get("code", "")) == code:
			gov_data = n.get("governor", null)
			var owner_val: Variant = n.get("owner", null)
			if typeof(owner_val) == TYPE_DICTIONARY:
				var oc := str(owner_val.get("code", ""))
				if oc == "bi": faction_color = C_ZHUSHA; f_code = "bi"
				elif oc == "mo": faction_color = C_MOLAN; f_code = "mo"
				elif oc == "yan": faction_color = C_ZHUQING; f_code = "yan"
				elif oc == "zhi": faction_color = C_TENGHUANG; f_code = "zhi"
			break

	# 1. 建筑尺寸（小屏如 720x514 自动缩放防止 13 城重叠，大屏与原型 1000px+ 保持原尺寸 1.0）
	var scale_f := clampf(size.y / 1000.0, 0.54, 1.0)
	var target_h := (136.0 if is_changan else (106.0 if is_capital else 92.0)) * scale_f
	if code == "liangzhou":
		target_h = 78.0 * scale_f
	var target_w := target_h * 1.35

	# 0. 暗色自然地基衬底
	_draw_natural_ground_shadow(code, pos, target_w)

	# 2. 独立 Trim Sprite 绘制（迷雾不可达时适度降低对比度与饱和度）
	if textures_cache.has(code) and textures_cache[code] != null:
		var tex: Texture2D = textures_cache[code]
		var tex_sz := tex.get_size()
		if tex_sz.y > 0.0:
			target_w = target_h * (tex_sz.x / tex_sz.y)
			var sprite_rect := Rect2(pos.x - target_w / 2.0, pos.y - target_h, target_w, target_h)
			if not is_reachable:
				draw_texture_rect(tex, sprite_rect, false, Color(0.55, 0.55, 0.58, 0.65))
			else:
				draw_texture_rect(tex, sprite_rect, false)

	# 3. 阵营地基光环与选中动效
	if is_changan:
		# 长安王城：帝王双金环
		var r_ca := 54.0 * scale_f
		var r_pulse := r_ca + sin(pulse * 3.5) * 4.0
		var ring_col := Color(C_CHANGAN_GOLD.r, C_CHANGAN_GOLD.g, C_CHANGAN_GOLD.b, 0.22 if is_reachable else 0.12)
		draw_circle(pos, r_pulse, ring_col)
		draw_arc(pos, r_pulse, 0.0, TAU, 64, C_CHANGAN_GOLD if is_reachable else Color("#857662"), 4.0, true)
		draw_arc(pos, r_pulse + 6.0, 0.0, TAU, 64, GOLD_LIGHT if is_reachable else Color("#a89b88"), 2.0, true)
		draw_arc(pos, r_pulse - 8.0, 0.0, TAU, 64, Color("#80241d") if is_reachable else Color("#4a3e35"), 1.8, true)
	elif is_selected:
		var r_sel := 42.0 * scale_f + sin(pulse * 3.5) * 3.5
		draw_circle(pos, r_sel, Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 0.18))
		draw_arc(pos, r_sel, 0.0, TAU, 48, GOLD_LIGHT, 3.5, true)
		draw_arc(pos, r_sel + 6.0, 0.0, TAU, 48, faction_color, 2.0, true)
	else:
		var r_base := (32.0 if is_capital else 26.0) * scale_f
		if zoom_level < 0.45:
			r_base = 28.0 * scale_f
		var alpha_c := 0.14 if is_reachable else 0.06
		draw_circle(pos, r_base, Color(faction_color.r, faction_color.g, faction_color.b, alpha_c))
		draw_arc(pos, r_base, 0.0, TAU, 36, faction_color if is_reachable else Color("#7a7065"), 2.5, true)
		draw_arc(pos, r_base + 3.0, 0.0, TAU, 36, Color(C_XUANZHI.r, C_XUANZHI.g, C_XUANZHI.b, 0.75 if is_reachable else 0.40), 1.2, true)

	# 4. 旌旗
	if not is_changan and faction_flags.has(f_code) and faction_flags[f_code] != null:
		var f_tex: Texture2D = faction_flags[f_code]
		var f_sz: Vector2 = f_tex.get_size()
		var flag_h := (38.0 if is_capital else 30.0) * scale_f
		var flag_w := flag_h * (f_sz.x / maxf(f_sz.y, 1.0))
		var flag_pos := pos + Vector2(target_w * 0.28, -target_h * 0.78)
		draw_line(flag_pos + Vector2(2, flag_h * 0.9), flag_pos + Vector2(2, 0), Color("#2a1e14"), 2.5, true)
		draw_circle(flag_pos + Vector2(2, 0), 2.5, GOLD_LIGHT)
		var f_mod := Color.WHITE if is_reachable else Color(0.65, 0.65, 0.68, 0.70)
		draw_texture_rect(f_tex, Rect2(flag_pos.x, flag_pos.y, flag_w, flag_h), false, f_mod)
	else:
		var flag_pole_h := (46.0 if is_changan else (38.0 if is_capital else 32.0)) * scale_f
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
		draw_colored_polygon(flag, faction_color if is_reachable else Color("#7a7065"))
		draw_polyline(flag, Color("#2b1e13"), 1.5, true)

	# 5. LOD 文字纸签渲染
	if not show_labels or zoom_level < 0.45:
		return

	var display_name: String = data.get("name", code)
	if is_scouted:
		display_name = "👁 " + display_name

	# 手机紧凑视口 (720×514) 下也自动采用精简单行城名（>=12px），避免两行副签遮挡山河
	var is_compact_vp := (zoom_level < 0.75) or (size.x < 900.0 or size.y < 600.0)
	# 游戏主场景 HUD 模式下，最南端城池纸签微抬以避开底部手牌条
	var y_lift := 0.0
	if hud_safe_mode and size.y >= 700.0:
		if code == "shouchun":
			y_lift = -50.0
		elif code == "changsha":
			y_lift = -26.0

	var gov_top := (-target_h * 0.84) if is_compact_vp else (-target_h - (6.0 * scale_f))
	_draw_governor_badge(pos, gov_top, gov_data, is_compact_vp)

	if is_compact_vp:
		_draw_compact_city_label(pos + Vector2(0, y_lift), display_name, faction_color, is_changan, is_selected, is_reachable)
		return

	var region_str: String = data.get("region", "")
	if not is_reachable and is_selected:
		region_str = "[不与己方领土相邻]"
	elif is_scouted:
		region_str += " · 👁 已侦察"
	_draw_full_city_label(pos + Vector2(0, y_lift), display_name, region_str, faction_color, is_changan, is_reachable)

	if zoom_level >= 1.30:
		_draw_cultural_tag(pos, data.get("tag", ""), data.get("verse", ""))

func _draw_natural_ground_shadow(code: String, pos: Vector2, target_w: float) -> void:
	var hw := target_w * 0.55
	if code in ["jianye", "kuaiji", "shouchun"]:
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

func _draw_compact_city_label(pos: Vector2, city_name: String, faction_color: Color, is_changan: bool, is_selected: bool, is_reachable: bool = true) -> void:
	if font == null:
		return
	
	var screen_font_size := 13.0
	var screen_w := 78.0 if not is_changan else 92.0
	var screen_h := 22.0
	
	var z := maxf(zoom_level, 0.1)
	var world_font_size := int(round(screen_font_size / z))
	var tw := screen_w / z
	var th := screen_h / z
	var y_gap := 10.0 / z
	var border_w := (2.5 if is_selected else 1.8) / z
	var shadow_pad := 1.8 / z
	
	var rect := Rect2(pos + Vector2(-tw / 2.0, y_gap), Vector2(tw, th))
	
	draw_rect(rect.grow(shadow_pad), Color(0, 0, 0, 0.28 if is_reachable else 0.15))
	
	var bg_color := (Color("#fffef7") if is_selected else C_XUANZHI) if is_reachable else Color("#ece4d8")
	draw_rect(rect, bg_color)
	
	var b_col := faction_color if is_reachable else Color("#8c8072")
	if is_selected:
		draw_rect(rect, GOLD_LIGHT, false, border_w)
		draw_rect(rect.grow(-border_w * 0.7), b_col, false, 1.2 / z)
	else:
		draw_rect(rect, b_col, false, border_w)
		
	var text_col := Color("#801b12") if (is_selected or is_changan) else Color("#1a110a")
	if not is_reachable:
		text_col = Color("#756a5d")
	var text_y := rect.position.y + th - (5.0 / z)
	draw_string(font, Vector2(rect.position.x, text_y), city_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, world_font_size, text_col)

func _draw_full_city_label(pos: Vector2, city_name: String, region: String, faction_color: Color, is_changan: bool, is_reachable: bool = true) -> void:
	if font == null:
		return
	var tw := 80.0 if not is_changan else 96.0
	var th := 22.0
	var rect := Rect2(pos + Vector2(-tw / 2.0, 8.0), Vector2(tw, th))
	draw_rect(rect.grow(2.0), Color(0, 0, 0, 0.18))
	draw_rect(rect, C_XUANZHI if is_reachable else Color("#ece4d8"))
	draw_rect(rect, faction_color if is_reachable else Color("#8c8072"), false, 2.0)
	draw_rect(rect.grow(-3), Color("#cfbfa6"), false, 1.0)
	draw_string(font, rect.position + Vector2(0, th - 5.0), city_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, C_WOOD_DESK if is_reachable else Color("#756a5d"))

	var sub_w := 116.0 if not is_reachable else 94.0
	var sub_h := 16.0
	var sub_rect := Rect2(pos + Vector2(-sub_w / 2.0, 32.0), Vector2(sub_w, sub_h))
	draw_rect(sub_rect, Color(C_XUANZHI.r, C_XUANZHI.g, C_XUANZHI.b, 0.90 if is_reachable else 0.70))
	draw_rect(sub_rect, Color(faction_color.r, faction_color.g, faction_color.b, 0.45 if is_reachable else 0.25), false, 1.0)
	draw_string(font, sub_rect.position + Vector2(0, sub_h - 3.5), region, HORIZONTAL_ALIGNMENT_CENTER, sub_rect.size.x, 10, Color("#554433") if is_reachable else Color("#7e7264"))

func _draw_cultural_tag(pos: Vector2, tag_text: String, _verse: String) -> void:
	if font == null or tag_text == "":
		return
	var rect := Rect2(pos + Vector2(-54.0, 52.0), Vector2(108.0, 20.0))
	draw_rect(rect.grow(1.0), Color(0, 0, 0, 0.18))
	draw_rect(rect, Color("#261c16"))
	draw_rect(rect, GOLD_LIGHT, false, 1.0)
	draw_string(font, rect.position + Vector2(0, 15.0), tag_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, GOLD_LIGHT)

func _draw_governor_badge(pos: Vector2, top_offset_y: float, gov: Variant, is_compact: bool) -> void:
	if font == null or typeof(gov) != TYPE_DICTIONARY:
		return
	var nick := str(gov.get("nickname", "")).strip_edges()
	if nick == "":
		return
	var label := "⚑ 太守·%s" % nick.substr(0, 4)
	var fsize := 9 if is_compact else 11
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize).x + 10.0
	var th := 14.0 if is_compact else 18.0
	# 避开右上角阵营战旗与相邻城池标签
	var shift_x := (-tw * 0.45) if is_compact else (-tw * 0.60)
	var rect := Rect2(pos + Vector2(shift_x, top_offset_y - th), Vector2(tw, th))
	draw_rect(rect.grow(1.2), Color(0, 0, 0, 0.28))
	draw_rect(rect, Color("#7c2419", 0.94))
	draw_rect(rect, GOLD_LIGHT, false, 1.3)
	draw_string(font, rect.position + Vector2(0, th - 4.0), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fsize, GOLD_LIGHT)
