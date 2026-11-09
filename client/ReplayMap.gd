extends Control

## 战局回放小地图：按回合显示 5 节点归属，变化节点金色高亮。
## 参考 Unciv 的 ReplayMap：只画每一回合的状态，不重算战斗。

const FONT_PATH := "res://fonts/NotoSerifCJKsc-Regular.otf"
const MAP_RECT := Rect2(24, 20, 820, 390)
const INK := Color("#3a2e24")
const CREAM := Color("#fff8e8")
const GOLD := Color("#cf8325")
const NEUTRAL := Color("#8b7d68")

var nodes: Array = []
var edges: Array = []
var owners: Dictionary = {}
var changed_codes: Dictionary = {}
var font: Font

func _ready() -> void:
	font = load(FONT_PATH)

func setup(p_nodes: Array, p_edges: Array, p_owners: Dictionary, p_changed: Dictionary) -> void:
	nodes = p_nodes
	edges = p_edges
	owners = p_owners
	changed_codes = p_changed
	queue_redraw()

func node_position(code: String) -> Vector2:
	for n in nodes:
		if str(n.get("code", "")) == code:
			var nx := clampf((float(n.get("x", 500)) - 100.0) / 800.0, 0.0, 1.0)
			var ny := clampf((float(n.get("y", 240)) - 100.0) / 300.0, 0.0, 1.0)
			return MAP_RECT.position + Vector2(nx * MAP_RECT.size.x, ny * MAP_RECT.size.y)
	return MAP_RECT.get_center()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2f2721"))
	draw_rect(MAP_RECT, Color("#f3ead8"))
	draw_rect(MAP_RECT, Color("#8a6a42"), false, 5.0)
	draw_rect(MAP_RECT.grow(5), Color("#c9a45c"), false, 2.0)
	if font != null:
		draw_string(font, MAP_RECT.position + Vector2(20, 34), "战局回放 · 5 节点", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)

	for e in edges:
		if typeof(e) != TYPE_ARRAY or e.size() < 2:
			continue
		var a := node_position(str(e[0]))
		var b := node_position(str(e[1]))
		_draw_dashed(a, b, Color("#8a7a63"), 2.0, 9.0, 7.0)

	for n in nodes:
		_draw_node(n)

func _draw_node(n: Dictionary) -> void:
	var code := str(n.get("code", ""))
	var pos := node_position(code)
	var owner: Variant = owners.get(code, null)
	var color := NEUTRAL
	if typeof(owner) == TYPE_DICTIONARY:
		color = Color(str(owner.get("color", "#8b7d68")))
	var changed := bool(changed_codes.get(code, false))
	if changed:
		draw_circle(pos, 38.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.20))
		draw_arc(pos, 38.0, 0.0, TAU, 48, GOLD, 3.0, true)

	if bool(n.get("is_start", false)) or str(n.get("type", "")) == "start":
		draw_arc(pos, 29.0, 0.0, TAU, 48, Color("#c9a45c"), 4.0, true)

	draw_line(pos + Vector2(0, -12), pos + Vector2(0, -50), Color("#4b3a2a"), 3.0)
	var flag := PackedVector2Array([
		pos + Vector2(1, -48),
		pos + Vector2(30, -43),
		pos + Vector2(1, -34),
	])
	draw_colored_polygon(flag, color)
	draw_polyline(flag, Color("#3a2e24"), 2.0, true)
	draw_circle(pos, 20.0, CREAM)
	draw_circle(pos, 20.0, color, false, 4.0)
	draw_circle(pos, 6.0, color)

	if font != null:
		var label := str(n.get("name", code))
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x + 22.0
		var box := Rect2(pos + Vector2(-tw / 2.0, 30), Vector2(tw, 26))
		draw_rect(box, CREAM)
		draw_rect(box, color if typeof(owner) == TYPE_DICTIONARY else Color("#9b8b73"), false, 2.0)
		draw_string(font, box.position + Vector2(0, 18), label, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 15, INK)

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
