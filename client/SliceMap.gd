extends Control

## 《青竹文房·灵宠山河》全屏国风沙盘地图
## 渲染：古木案台、仿宋绢布山河卷轴、城关浮雕、动态行军流光、旌旗战意

const FONT_PATH := "res://fonts/NotoSerifCJKsc-Regular.otf"

const INK_DARK := Color("#201a15")
const INK_LIGHT := Color("#4a3e35")
const CREAM := Color("#fff9ee")
const GOLD := Color("#d4af37")
const GOLD_LIGHT := Color("#fae19c")
const CORAL := Color("#b83b32")
const BAMBOO := Color("#276f57")
const NEUTRAL := Color("#7e7263")

var map_data: Dictionary = {}
var selected_code := ""
var my_order: Variant = null
var pulse := 0.0
var font: Font

# 地图主卷轴绘制区域（全屏自适应，留出顶部状态栏与底部操作区空间）
func _map_rect() -> Rect2:
	return Rect2(30, 84, size.x - 60, size.y - 120)

func _ready() -> void:
	font = load(FONT_PATH)
	set_process(true)

func setup(data: Dictionary) -> void:
	map_data = data
	queue_redraw()

func set_selected(code: String) -> void:
	selected_code = code
	queue_redraw()

func set_my_order(order: Variant) -> void:
	my_order = order
	queue_redraw()

func node_position(code: String) -> Vector2:
	var mr := _map_rect()
	for n in map_data.get("nodes", []):
		if str(n.get("code", "")) == code:
			var nx := clampf((float(n.get("x", 500)) - 100.0) / 800.0, 0.0, 1.0)
			var ny := clampf((float(n.get("y", 240)) - 100.0) / 300.0, 0.0, 1.0)
			# 更加舒展的黄金排布比例，居中向两翼延展
			var px := mr.position.x + 80.0 + nx * (mr.size.x - 160.0)
			var py := mr.position.y + 60.0 + ny * (mr.size.y - 190.0)
			return Vector2(px, py)
	return mr.get_center()

func node_by_code(code: String) -> Dictionary:
	for n in map_data.get("nodes", []):
		if str(n.get("code", "")) == code:
			return n
	return {}

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func _draw() -> void:
	var total_rect := Rect2(Vector2.ZERO, size)
	var mr := _map_rect()

	# 1. 外围案台底色（沉稳胡桃木质感）
	draw_rect(total_rect, Color("#1a1410"))

	# 2. 卷轴阴影与绢布本体
	var shadow_rect := mr.grow(10)
	shadow_rect.position += Vector2(0, 6)
	draw_rect(shadow_rect, Color(0, 0, 0, 0.45))
	
	# 仿宋绢纸底衬与质感外框
	draw_rect(mr, Color("#f2e9d4")) # 宣纸米黄
	draw_rect(mr.grow(-8), Color("#ebe0c7")) # 渐层内纸
	draw_rect(mr, Color("#5a4533"), false, 7.0) # 檀木封边
	draw_rect(mr.grow(5), GOLD, false, 2.0) # 烫金丝线
	draw_rect(mr.grow(-14), Color("#c8b89e"), false, 1.5) # 内边墨线

	# 3. 四角烫金云纹饰件
	_draw_corner_ornament(mr.position, 1, 1)
	_draw_corner_ornament(Vector2(mr.end.x, mr.position.y), -1, 1)
	_draw_corner_ornament(Vector2(mr.position.x, mr.end.y), 1, -1)
	_draw_corner_ornament(mr.end, -1, -1)

	# 4. 背景淡墨山水点缀
	_draw_landscape_accents(mr)

	# 5. 城际驰道连接线
	var edges: Array = map_data.get("edges", [])
	for e in edges:
		if typeof(e) != TYPE_ARRAY or e.size() < 2:
			continue
		var a := node_position(str(e[0]))
		var b := node_position(str(e[1]))
		var is_active := (selected_code != "" and (str(e[0]) == selected_code or str(e[1]) == selected_code))
		
		# 驰道路基（宽条石纹）
		draw_line(a, b, Color("#dfcfb4"), 10.0, true)
		draw_line(a, b, Color("#baa789"), 8.0, true)
		# 动态战意流光虚线
		var line_color := GOLD if is_active else Color("#8c7a65")
		var dash_offset := fmod(pulse * (22.0 if is_active else 8.0), 20.0)
		_draw_animated_path(a, b, line_color, 3.2 if is_active else 2.0, 10.0, 8.0, dash_offset)

	# 6. 如果有已下达的军令，绘制高光行军动效箭头
	_draw_order_trajectory()

	# 7. 绘制城池节点
	for n in map_data.get("nodes", []):
		_draw_node(n)

	# 8. 战局图例（极简右上角木签）
	_draw_mini_legend(mr)

# 绘制军令动态行军路线（金光流动的箭头指示）
func _draw_order_trajectory() -> void:
	if typeof(my_order) != TYPE_DICTIONARY or my_order.is_empty():
		return
	var action := str(my_order.get("action", ""))
	var origin_code := str(my_order.get("origin_node_code", ""))
	var target_code := str(my_order.get("target_node_code", ""))
	
	if action == "advance" and origin_code != "" and target_code != "":
		var a := node_position(origin_code)
		var b := node_position(target_code)
		
		# 曲线微弯拱起，更具军事沙盘推演感
		var mid := (a + b) / 2.0 + Vector2(0, -32.0)
		_draw_curved_march_arrow(a, mid, b)
	elif action == "defend" and origin_code != "":
		var pos := node_position(origin_code)
		# 坚守金钟护盾光环
		var r := 48.0 + sin(pulse * 3.0) * 4.0
		draw_arc(pos, r, 0.0, TAU, 36, Color(BAMBOO.r, BAMBOO.g, BAMBOO.b, 0.4), 3.0, true)
		draw_arc(pos, r - 5.0, 0.0, TAU, 36, Color(GOLD.r, GOLD.g, GOLD.b, 0.6), 1.5, true)

func _draw_curved_march_arrow(p0: Vector2, p1: Vector2, p2: Vector2) -> void:
	var points := PackedVector2Array()
	var count := 30
	for i in range(count + 1):
		var t := float(i) / float(count)
		var pt := (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * p1 + t * t * p2
		points.append(pt)
	
	# 发光底线
	draw_polyline(points, Color(GOLD.r, GOLD.g, GOLD.b, 0.35), 8.0, true)
	draw_polyline(points, GOLD, 3.5, true)
	
	# 顺着曲线行进的金光行军灵宠光标
	var head_t := fmod(pulse * 0.45, 1.0)
	var arrow_pos := (1.0 - head_t) * (1.0 - head_t) * p0 + 2.0 * (1.0 - head_t) * head_t * p1 + head_t * head_t * p2
	draw_circle(arrow_pos, 7.0, CORAL)
	draw_circle(arrow_pos, 10.0, GOLD, false, 2.0)
	
	# 终点箭头
	var end_dir := (p2 - p1).normalized()
	var normal := Vector2(-end_dir.y, end_dir.x)
	var arrow_head := PackedVector2Array([
		p2,
		p2 - end_dir * 18.0 + normal * 10.0,
		p2 - end_dir * 12.0,
		p2 - end_dir * 18.0 - normal * 10.0,
	])
	draw_colored_polygon(arrow_head, CORAL)
	draw_polyline(arrow_head, GOLD, 2.0, true)

func _draw_node(n: Dictionary) -> void:
	var code := str(n.get("code", ""))
	var pos := node_position(code)
	var is_start := bool(n.get("is_start", false))
	var owner: Variant = n.get("owner", null)
	var is_mine := bool(n.get("is_my_faction", false))
	
	var faction_color := NEUTRAL
	if typeof(owner) == TYPE_DICTIONARY:
		faction_color = Color(str(owner.get("color", "#7e7263")))

	# 1. 选中光圈与战术瞄准环
	if code == selected_code:
		var r1 := 48.0 + sin(pulse * 3.5) * 4.0
		# 八卦/阴阳阵纹虚光
		draw_circle(pos, r1, Color(GOLD.r, GOLD.g, GOLD.b, 0.14))
		draw_arc(pos, r1, 0.0, TAU, 48, GOLD, 3.5, true)
		draw_arc(pos, r1 + 8.0, 0.0, TAU, 48, Color(CORAL.r, CORAL.g, CORAL.b, 0.5), 1.5, true)

	# 2. 地面石阶台基（立体投影）
	draw_circle(pos + Vector2(0, 6), 34.0, Color(0, 0, 0, 0.22)) # 阴影
	draw_circle(pos, 32.0, Color("#e6dac4")) # 白玉基座
	draw_circle(pos, 32.0, Color("#6d5843"), false, 3.0) # 外基框
	
	# 起点主城尊贵金环
	if is_start:
		draw_arc(pos, 37.0, 0.0, TAU, 48, GOLD, 4.0, true)
		draw_arc(pos, 42.0, 0.0, TAU, 48, faction_color, 2.0, true)

	# 3. 城池建筑主体（国风纸雕城门楼剪影）
	_draw_castle_icon(pos, faction_color, is_start)

	# 4. 迎风猎猎旌旗
	var flag_pole_h := 68.0 if is_start else 56.0
	var pole_base := pos + Vector2(16, -14)
	var pole_top := pole_base + Vector2(0, -flag_pole_h)
	draw_line(pole_base, pole_top, Color("#3a2a1a"), 3.5, true) # 铜旗杆
	draw_circle(pole_top, 3.5, GOLD) # 枪头金顶
	
	# 旗面迎风飘扬曲线
	var wave := sin(pulse * 3.2 + pos.x * 0.05) * 4.0
	var flag := PackedVector2Array([
		pole_top,
		pole_top + Vector2(40, 8 + wave),
		pole_top + Vector2(28, 22),
		pole_top + Vector2(42, 34 - wave),
		pole_top + Vector2(0, 28),
	])
	draw_colored_polygon(flag, faction_color)
	draw_polyline(flag, Color("#2b1e13"), 2.0, true)

	# 5. 精致木质城池匾额
	var label := str(n.get("name", code))
	var fsize := 16
	var tw := 110.0
	if font != null:
		tw = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize).x + 30.0
	
	var tag_rect := Rect2(pos + Vector2(-tw / 2.0, 40), Vector2(tw, 28))
	draw_rect(tag_rect.grow(2), Color(0, 0, 0, 0.15)) # 阴影
	draw_rect(tag_rect, CREAM) # 白玉底
	draw_rect(tag_rect, faction_color, false, 2.5) # 阵营边
	draw_rect(tag_rect.grow(-3), Color("#cfbfa6"), false, 1.0)
	
	if font != null:
		draw_string(font, tag_rect.position + Vector2(0, 20), label, HORIZONTAL_ALIGNMENT_CENTER, tag_rect.size.x, fsize, INK_DARK)

	# 6. 阵营归属小印章（城名下方）
	if font != null:
		var owner_name := "中立关隘"
		if typeof(owner) == TYPE_DICTIONARY:
			owner_name = str(owner.get("name", "中立")) + "阵营"
		if is_start:
			owner_name += " [大营]"
		var sub_color := Color("#8c3a32") if is_mine else Color("#6b5a45")
		draw_string(font, pos + Vector2(-65, 84), owner_name, HORIZONTAL_ALIGNMENT_CENTER, 130, 12, sub_color)

# 绘制国风古城楼/关隘立体图形
func _draw_castle_icon(pos: Vector2, color: Color, is_capital: bool) -> void:
	# 城墙主垛口
	var wall := PackedVector2Array([
		pos + Vector2(-20, 14),
		pos + Vector2(20, 14),
		pos + Vector2(17, -10),
		pos + Vector2(-17, -10),
	])
	draw_colored_polygon(wall, Color("#dfd2ba"))
	draw_polyline(wall, Color("#4a3b2c"), 2.0, true)

	# 拱门
	draw_arc(pos + Vector2(0, 14), 8.0, PI, TAU, 16, Color("#3a2a1a"), 8.0, true)

	# 飞檐重楼（如果是大本营则双层重檐，中立关隘则单层敌楼）
	if is_capital:
		# 下层飞檐
		var roof1 := PackedVector2Array([
			pos + Vector2(-26, -10),
			pos + Vector2(26, -10),
			pos + Vector2(20, -16),
			pos + Vector2(-20, -16),
		])
		draw_colored_polygon(roof1, color.darkened(0.1))
		draw_polyline(roof1, Color("#2b1e13"), 2.0, true)
		# 上层飞阁
		var roof2 := PackedVector2Array([
			pos + Vector2(-20, -20),
			pos + Vector2(20, -20),
			pos + Vector2(0, -32),
		])
		draw_colored_polygon(roof2, color)
		draw_polyline(roof2, GOLD, 2.0, true)
	else:
		var roof := PackedVector2Array([
			pos + Vector2(-24, -10),
			pos + Vector2(24, -10),
			pos + Vector2(0, -24),
		])
		draw_colored_polygon(roof, color)
		draw_polyline(roof, Color("#3a2a1a"), 2.0, true)

# 绘制四角烫金云纹包角
func _draw_corner_ornament(origin: Vector2, dir_x: float, dir_y: float) -> void:
	var o := origin + Vector2(dir_x * 8, dir_y * 8)
	var pts := PackedVector2Array([
		o,
		o + Vector2(dir_x * 32, 0),
		o + Vector2(dir_x * 24, dir_y * 8),
		o + Vector2(dir_x * 8, dir_y * 8),
		o + Vector2(dir_x * 8, dir_y * 24),
		o + Vector2(0, dir_y * 32),
	])
	draw_colored_polygon(pts, Color("#9e7a3a"))
	draw_polyline(pts, GOLD, 2.0, true)

# 绘制淡墨山峦点缀
func _draw_landscape_accents(mr: Rect2) -> void:
	# 绘制几笔远山黛色线条
	var m_color := Color("#4a5e4d", 0.08)
	var pts1 := PackedVector2Array([
		mr.position + Vector2(100, 200),
		mr.position + Vector2(220, 130),
		mr.position + Vector2(340, 210),
	])
	draw_polyline(pts1, m_color, 4.0, true)
	var pts2 := PackedVector2Array([
		mr.end - Vector2(320, 160),
		mr.end - Vector2(200, 100),
		mr.end - Vector2(90, 180),
	])
	draw_polyline(pts2, m_color, 4.0, true)

# 右上方精致小图例
func _draw_mini_legend(mr: Rect2) -> void:
	if font == null:
		return
	var lx := mr.end.x - 220.0
	var ly := mr.position.y + 24.0
	var bg_rect := Rect2(lx - 12, ly - 8, 206, 36)
	draw_rect(bg_rect, Color(1, 1, 1, 0.65))
	draw_rect(bg_rect, Color("#baa789"), false, 1.0)
	
	draw_string(font, Vector2(lx, ly + 16), "阵营：", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK_DARK)
	var tags = [["青竹", CORAL], ["墨点", BAMBOO], ["中立", NEUTRAL]]
	var ox := lx + 44.0
	for t in tags:
		draw_circle(Vector2(ox, ly + 12), 5.5, t[1])
		draw_string(font, Vector2(ox + 8, ly + 16), str(t[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK_LIGHT)
		ox += 48.0

func _draw_animated_path(a: Vector2, b: Vector2, color: Color, width: float, dash: float, gap: float, offset: float) -> void:
	var total_len := a.distance_to(b)
	if total_len <= 0.01:
		return
	var dir := (b - a) / total_len
	var cur := -offset
	while cur < total_len:
		var s := maxf(0.0, cur)
		var e := minf(cur + dash, total_len)
		if e > s:
			draw_line(a + dir * s, a + dir * e, color, width, true)
		cur += dash + gap
