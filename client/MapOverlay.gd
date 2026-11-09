extends Control

func _c(hex: String, alpha: float) -> Color:
	var c := Color(hex)
	c.a = alpha
	return c

var canvas: Control
var province_data: Dictionary = {}
var selected_code: String = ""
var pulse := 0.0

func setup(map_canvas: Control, data: Dictionary) -> void:
	canvas = map_canvas
	province_data = data
	set_process(true)

func set_selected(code: String) -> void:
	selected_code = code
	queue_redraw()

func _process(delta: float) -> void:
	if selected_code != "":
		pulse += delta
		queue_redraw()

func _draw() -> void:
	if canvas == null or selected_code == "":
		return
	var pos: Vector2 = canvas.city_pos(selected_code)
	var r := 27.0 + sin(pulse * 3.0) * 3.0
	draw_circle(pos, r, _c("#cf8325", 0.16))
	draw_arc(pos, r, 0.0, TAU, 48, _c("#cf8325", 0.95), 3.0, true)
	draw_arc(pos, r + 6.0, 0.0, TAU, 48, _c("#b83b32", 0.35), 1.2, true)

	for conn in province_data.get("connections", []):
		if typeof(conn) != TYPE_ARRAY or conn.size() < 2:
			continue
		if str(conn[0]) != selected_code and str(conn[1]) != selected_code:
			continue
		var a: Vector2 = canvas.city_pos(str(conn[0]))
		var b: Vector2 = canvas.city_pos(str(conn[1]))
		draw_line(a, b, _c("#b83b32", 0.85), 3.0, true)
		draw_circle(b, 4.0, Color("#cf8325"))
