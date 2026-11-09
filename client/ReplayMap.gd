extends Control

## 战局回放小地图：按回合显示 5 节点归属，变化节点金色高亮。
## 参考 Unciv 的 ReplayMap：只画每一回合的状态，不重算战斗。

const FONT_PATH := "res://fonts/NotoSerifCJKsc-Regular.otf"

# ---------------------------------------------------------------------------
# Style C 水彩纸雕国风色板（严格对齐 ART_BRIEF_GPT.md）
# ---------------------------------------------------------------------------
const C_XUANZHI := Color("#f6efe2")     # 宣纸米黄（底衬与纸签）
const C_MOLAN := Color("#1e3a5f")       # 墨蓝（墨阵营）
const C_ZHUQING := Color("#276f57")     # 竹青（青竹书院）
const C_ZHUSHA := Color("#b83b32")      # 朱砂（笔阵营）
const C_TENGHUANG := Color("#cf8325")   # 藤黄（烫金线条与高亮光环）
const C_WOOD_DESK := Color("#2f2721")   # 深墨木桌（案台底色）

const INK := C_WOOD_DESK
const CREAM := C_XUANZHI
const GOLD := C_TENGHUANG
const GOLD_LIGHT := Color("#fae19c")
const CORAL := C_ZHUSHA
const BAMBOO := C_ZHUQING
const NEUTRAL := Color("#7e7263")

var nodes: Array = []
var edges: Array = []
var owners: Dictionary = {}
var changed_codes: Dictionary = {}
var font: Font

func _ready() -> void:
	font = load(FONT_PATH)

# 自适应绘制矩形（留出边距，适配平板与多种分辨率）
func _map_rect() -> Rect2:
	var pad_x := clampf(size.x * 0.03, 16.0, 32.0)
	var pad_y := clampf(size.y * 0.04, 16.0, 26.0)
	return Rect2(pad_x, pad_y, maxf(size.x - pad_x * 2.0, 200.0), maxf(size.y - pad_y * 2.0, 150.0))

func setup(p_nodes: Array, p_edges: Array, p_owners: Dictionary, p_changed: Dictionary) -> void:
	nodes = p_nodes
	edges = p_edges
	owners = p_owners
	changed_codes = p_changed
	queue_redraw()

func node_position(code: String) -> Vector2:
	var mr := _map_rect()
	for n in nodes:
		if str(n.get("code", "")) == code:
			var nx := clampf((float(n.get("x", 500)) - 100.0) / 800.0, 0.0, 1.0)
			var ny := clampf((float(n.get("y", 240)) - 100.0) / 300.0, 0.0, 1.0)
			var pad_inner_x := clampf(mr.size.x * 0.08, 36.0, 70.0)
			var pad_inner_y := clampf(mr.size.y * 0.12, 32.0, 60.0)
			var px := mr.position.x + pad_inner_x + nx * (mr.size.x - pad_inner_x * 2.0)
			var py := mr.position.y + pad_inner_y + ny * (mr.size.y - pad_inner_y * 2.0)
			return Vector2(px, py)
	return mr.get_center()

func _draw() -> void:
	var mr := _map_rect()
	# 案台底木
	draw_rect(Rect2(Vector2.ZERO, size), C_WOOD_DESK)
	
	# 绢布卷轴
	draw_rect(mr, C_XUANZHI)
	draw_rect(mr.grow(-6), Color("#efe5d2"))
	draw_rect(mr, Color("#5a4533"), false, 3.0)
	draw_rect(mr.grow(4), C_TENGHUANG, false, 1.5)
	_draw_corners(mr)

	if font != null:
		draw_string(font, mr.position + Vector2(20, 32), "沙盘战局复盘 · 节点归属演化", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
		# 阵营微型图例（对齐“笔 / 墨 / 中立”）
		var lx := mr.end.x - 210.0
		var ly := mr.position.y + 16.0
		draw_string(font, Vector2(lx, ly + 14), "阵营：", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
		var tags = [["笔", CORAL], ["墨", C_MOLAN], ["中立", NEUTRAL]]
		var ox := lx + 40.0
		for t in tags:
			draw_circle(Vector2(ox, ly + 10), 4.5, t[1])
			draw_string(font, Vector2(ox + 8, ly + 14), t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
			ox += 52.0

	for e in edges:
		if typeof(e) != TYPE_ARRAY or e.size() < 2:
			continue
		var a := node_position(str(e[0]))
		var b := node_position(str(e[1]))
		# 驰道虚线
		_draw_dashed(a, b, Color("#9b8870"), 2.5, 9.0, 7.0)

	for n in nodes:
		_draw_node(n)

func _draw_corners(r: Rect2) -> void:
	var clen := 14.0
	var ccol := C_TENGHUANG
	draw_line(r.position, r.position + Vector2(clen, 0), ccol, 2.0)
	draw_line(r.position, r.position + Vector2(0, clen), ccol, 2.0)
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x - clen, r.position.y), ccol, 2.0)
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + clen), ccol, 2.0)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x + clen, r.end.y), ccol, 2.0)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.end.y - clen), ccol, 2.0)
	draw_line(r.end, r.end - Vector2(clen, 0), ccol, 2.0)
	draw_line(r.end, r.end - Vector2(0, clen), ccol, 2.0)

func _draw_node(n: Dictionary) -> void:
	var code := str(n.get("code", ""))
	var pos := node_position(code)
	var owner: Variant = owners.get(code, null)
	var color := NEUTRAL
	if typeof(owner) == TYPE_DICTIONARY:
		color = Color(str(owner.get("color", "#7e7263")))
	var changed := bool(changed_codes.get(code, false))

	# 1. 变化城池高亮：双环柔和金色光芒，半径 32，醒目且不遮挡上方旗标（-44）与下方城名（+30）
	if changed:
		draw_circle(pos, 32.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.22))
		draw_arc(pos, 32.0, 0.0, TAU, 48, GOLD, 2.5, true)
		draw_arc(pos, 36.0, 0.0, TAU, 48, Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 0.7), 1.2, true)

	if bool(n.get("is_start", false)) or str(n.get("type", "")) == "start":
		draw_arc(pos, 25.0, 0.0, TAU, 48, Color("#c9a45c"), 3.5, true)

	# 2. 旗杆与旌旗（垂直向上，加米白描边避免糊成一团）
	draw_line(pos + Vector2(0, -10), pos + Vector2(0, -46), Color("#4b3a2a"), 3.0)
	var flag := PackedVector2Array([
		pos + Vector2(1, -44),
		pos + Vector2(28, -39),
		pos + Vector2(1, -30),
	])
	draw_polyline(flag, Color(CREAM.r, CREAM.g, CREAM.b, 0.92), 3.5, true)
	draw_colored_polygon(flag, color)
	draw_polyline(flag, Color("#3a2e24"), 1.8, true)

	# 3. 城池基座与圆台
	draw_circle(pos, 17.0, CREAM)
	draw_circle(pos, 17.0, color, false, 3.5)
	draw_circle(pos, 5.0, color)

	# 4. 城名底牌（位于圆心下方 30 像素处，高度 24，内含城名）
	if font != null:
		var label := str(n.get("name", code))
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x + 18.0
		var box := Rect2(pos + Vector2(-tw / 2.0, 30), Vector2(tw, 24))
		draw_rect(box, CREAM)
		draw_rect(box, color if typeof(owner) == TYPE_DICTIONARY else Color("#9b8b73"), false, 1.8)
		draw_string(font, box.position + Vector2(0, 17), label, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 14, INK)

func _draw_dashed(a: Vector2, b: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var length := a.distance_to(b)
	if length <= 0.01:
		return
	var dir := (b - a) / length
	var t := 0.0
	while t < length:
		var e: float = minf(t + dash, length)
		draw_line(a + dir * t, a + dir * e, color, width, true)
		t = e + gap
