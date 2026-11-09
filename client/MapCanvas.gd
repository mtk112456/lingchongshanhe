extends Control

func _c(hex: String, alpha: float) -> Color:
	var c := Color(hex)
	c.a = alpha
	return c

const MAP_RECT := Rect2(30, 92, 880, 560)
const META_PATH := "res://data/map_meta.json"
const BASE_MAP_PATH := "res://data/map_base.png"
const FACTION_COLORS := {
	"bi": "#b83b32",
	"mo": "#1e3a5f",
	"zhi": "#cf8325",
	"yan": "#276f57"
}

var province_data: Dictionary = {}
var provinces: Array = []
var meta: Dictionary = {}
var map_texture: Texture2D

func setup(data: Dictionary) -> void:
	province_data = data
	provinces = data.get("provinces", [])
	meta = _load_json(META_PATH)
	map_texture = load(BASE_MAP_PATH)
	queue_redraw()

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func city_pos(code: String) -> Vector2:
	var cities = meta.get("cities", {})
	if cities.has(code):
		var n = cities[code]
		return MAP_RECT.position + Vector2(float(n[0]), float(n[1])) * MAP_RECT.size
	return MAP_RECT.get_center()

func faction_color(code: String) -> Color:
	if FACTION_COLORS.has(code):
		return Color(FACTION_COLORS[code])
	return Color("#8b7d68")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#f3ead8"))
	if map_texture != null:
		draw_texture_rect(map_texture, MAP_RECT, false)
	draw_rect(MAP_RECT, Color("#c9b99a"), false, 2.0)
	draw_rect(MAP_RECT.grow(-4), Color("#b9a98e"), false, 0.8)

	_draw_city_flags()

	for conn in province_data.get("connections", []):
		if typeof(conn) != TYPE_ARRAY or conn.size() < 2:
			continue
		var a := city_pos(str(conn[0]))
		var b := city_pos(str(conn[1]))
		_draw_dashed(a, b, _c("#8a7a63", 0.38), 1.4, 7.0, 5.0)

func _draw_city_flags() -> void:
	for p in provinces:
		var code := str(p.get("code", ""))
		var pos := city_pos(code)
		var owner := str(p.get("owner", ""))
		var col := faction_color(owner)
		# 城池到木牌的引线
		var off := Vector2(float(p.get("label_dx", 0)), float(p.get("label_dy", 0)))
		if off.length() > 8.0:
			draw_line(pos, pos + off, _c("#5f5143", 0.35), 1.0)
		# 旗杆
		draw_line(pos + Vector2(0, -6), pos + Vector2(0, -42), _c("#5f5143", 0.8), 2.0)
		# 旗帜
		var flag := PackedVector2Array([
			pos + Vector2(1, -40),
			pos + Vector2(26, -36),
			pos + Vector2(1, -28)
		])
		draw_colored_polygon(flag, col)
		# 底座
		draw_circle(pos + Vector2(0, 2), 5.0, Color("#f3ead8"))
		draw_arc(pos + Vector2(0, 2), 5.0, 0, TAU, 24, _c("#5f5143", 0.7), 1.2, true)

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
