extends Control

const PROVINCES_PATH := "res://data/provinces.json"
const FONT_PATH := "res://fonts/NotoSerifCJKsc-Regular.otf"
const MapCanvasScript = preload("res://MapCanvas.gd")
const MapOverlayScript = preload("res://MapOverlay.gd")

const FACTION_COLORS := {
	"bi": "#b83b32",
	"mo": "#1e3a5f",
	"zhi": "#cf8325",
	"yan": "#276f57"
}
const FACTION_NAMES := {
	"bi": "笔",
	"mo": "墨",
	"zhi": "纸",
	"yan": "砚"
}

var province_data: Dictionary = {}
var provinces: Array = []
var buttons: Dictionary = {}
var selected_code: String = ""
var map_canvas: Control
var map_overlay: Control

var info_title: Label
var info_body: Label
var resource_label: Label
var order_target_labels: Array = []
var order_options: Array = []
var order_log: Label

func _ready() -> void:
	_setup_theme()
	_load_data()
	_build_map()
	_build_ui()
	_create_province_buttons()
	if provinces.size() > 0:
		_select_province(str(provinces[0]["code"]))

func _setup_theme() -> void:
	var t := Theme.new()
	var f = load(FONT_PATH)
	if f != null:
		t.default_font = f
	t.default_font_size = 18
	theme = t

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("无法读取: " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON 格式错误: " + path)
		return {}
	return parsed

func _load_data() -> void:
	province_data = _load_json(PROVINCES_PATH)
	provinces = province_data.get("provinces", [])

func _build_map() -> void:
	map_canvas = MapCanvasScript.new()
	map_canvas.position = Vector2.ZERO
	map_canvas.size = Vector2(1280, 720)
	add_child(map_canvas)
	map_canvas.setup(province_data)

	map_overlay = MapOverlayScript.new()
	map_overlay.position = Vector2.ZERO
	map_overlay.size = Vector2(1280, 720)
	add_child(map_overlay)
	map_overlay.setup(map_canvas, province_data)

func _faction_color(code: String) -> Color:
	if FACTION_COLORS.has(code):
		return Color(FACTION_COLORS[code])
	return Color("#8b7d68")

func _style(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 1, radius: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	return s

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _build_ui() -> void:
	var top := Panel.new()
	top.position = Vector2(0, 0)
	top.size = Vector2(1280, 70)
	top.add_theme_stylebox_override("panel", _style(Color("#1e3a5f"), Color("#cf8325"), 0, 0))
	add_child(top)

	var gold := ColorRect.new()
	gold.color = Color("#cf8325")
	gold.position = Vector2(0, 68)
	gold.size = Vector2(1280, 2)
	top.add_child(gold)

	var seal := Panel.new()
	seal.position = Vector2(22, 14)
	seal.size = Vector2(42, 42)
	seal.add_theme_stylebox_override("panel", _style(Color("#b83b32"), Color("#8f2a24"), 1, 6))
	top.add_child(seal)
	var seal_label := _label("青", 22, Color("#fff8e8"))
	seal_label.position = Vector2(0, 0)
	seal_label.size = Vector2(42, 42)
	seal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_child(seal_label)

	var title := _label("青竹文房·灵宠山河", 27, Color("#f6efe2"))
	title.position = Vector2(78, 8)
	top.add_child(title)

	var season = province_data.get("season", {})
	var sub := _label("%s · 第 %d 周 · 真实中国地图示意" % [str(season.get("name", "S1 九州争霸")), int(season.get("week", 1))], 13, Color("#d9c9a8"))
	sub.position = Vector2(80, 44)
	top.add_child(sub)

	resource_label = _label("笔阵营｜粮 500　木 500　铁 500｜军令 3/3", 14, Color("#f6efe2"))
	resource_label.position = Vector2(780, 24)
	top.add_child(resource_label)

	# 右侧面板
	var panel := Panel.new()
	panel.position = Vector2(940, 90)
	panel.size = Vector2(310, 560)
	panel.add_theme_stylebox_override("panel", _style(Color("#fffaf0"), Color("#c9b99a"), 1, 10))
	add_child(panel)

	var panel_top := ColorRect.new()
	panel_top.color = Color("#cf8325")
	panel_top.position = Vector2(1, 1)
	panel_top.size = Vector2(308, 3)
	panel.add_child(panel_top)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(14, 14)
	vbox.size = Vector2(282, 532)
	vbox.add_theme_constant_override("separation", 7)
	panel.add_child(vbox)

	vbox.add_child(_label("省份信息", 21, Color("#1e3a5f")))
	info_title = _label("长安", 23, Color("#b83b32"))
	vbox.add_child(info_title)
	info_body = _label("", 14, Color("#1f2937"))
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_body.custom_minimum_size = Vector2(0, 148)
	vbox.add_child(info_body)

	var sep := HSeparator.new()
	vbox.add_child(sep)
	vbox.add_child(_label("今日军令（3 道）", 17, Color("#1e3a5f")))

	var order_types := ["征兵", "进军", "驻守", "筑城", "侦察", "运粮"]
	for i in range(3):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		vbox.add_child(row)
		row.add_child(_label(str(i + 1) + ".", 15, Color("#6b7280")))
		var opt := OptionButton.new()
		opt.custom_minimum_size = Vector2(106, 34)
		for t in order_types:
			opt.add_item(t)
		opt.selected = 0
		opt.add_theme_stylebox_override("normal", _style(Color("#fff8e8"), Color("#c9b99a"), 1, 6))
		opt.add_theme_color_override("font_color", Color("#1f2937"))
		row.add_child(opt)
		order_options.append(opt)
		var target := _label("目标：长安", 13, Color("#4b5563"))
		row.add_child(target)
		order_target_labels.append(target)

	var submit := Button.new()
	submit.text = "提交军令（本地）"
	submit.custom_minimum_size = Vector2(0, 40)
	submit.add_theme_stylebox_override("normal", _style(Color("#b83b32"), Color("#8f2a24"), 1, 7))
	submit.add_theme_stylebox_override("hover", _style(Color("#cf483e"), Color("#8f2a24"), 1, 7))
	submit.add_theme_stylebox_override("pressed", _style(Color("#8f2a24"), Color("#6d1f1a"), 1, 7))
	submit.add_theme_color_override("font_color", Color("#ffffff"))
	submit.pressed.connect(_on_submit_pressed)
	vbox.add_child(submit)

	order_log = _label("点击地图上的城池查看信息。", 12, Color("#6b7280"))
	order_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	order_log.custom_minimum_size = Vector2(0, 62)
	vbox.add_child(order_log)

	# 图例
	var legend := HBoxContainer.new()
	legend.position = Vector2(30, 646)
	legend.add_theme_constant_override("separation", 14)
	add_child(legend)
	for code in ["bi", "mo", "zhi", "yan"]:
		var dot := ColorRect.new()
		dot.color = _faction_color(code)
		dot.custom_minimum_size = Vector2(12, 12)
		legend.add_child(dot)
		legend.add_child(_label(str(FACTION_NAMES[code]), 13, Color("#4b5563")))

	var note := _label("真实中国地图示意；正式版替换为自然资源部标准地图并标注审图号。", 12, Color("#6b7280"))
	note.position = Vector2(30, 676)
	add_child(note)

func _create_province_buttons() -> void:
	for p in provinces:
		var code := str(p.get("code", ""))
		if code == "":
			continue
		var base_pos: Vector2 = map_canvas.city_pos(code)
		var offset := Vector2(float(p.get("label_dx", 0)), float(p.get("label_dy", 0)))
		var pos: Vector2 = base_pos + offset
		var owner := str(p.get("owner", ""))
		var col := _faction_color(owner)
		var b := Button.new()
		var star := "★" if bool(p.get("capital", false)) else ""
		b.text = "%s %s" % [str(p.get("name", code)), star]
		var label_size := Vector2(84, 30)
		b.position = pos - label_size * 0.5
		b.size = label_size
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", col)
		b.add_theme_stylebox_override("normal", _style(Color("#fff8e8"), col, 2, 4))
		b.add_theme_stylebox_override("hover", _style(Color("#fffdf5"), Color("#cf8325"), 2, 4))
		b.add_theme_stylebox_override("pressed", _style(Color("#f1e4c8"), Color("#cf8325"), 2, 4))
		b.tooltip_text = "%s · %s · 胜利点 %d" % [str(p.get("name", code)), str(FACTION_NAMES.get(owner, "中立")), int(p.get("vp", 0))]
		b.pressed.connect(_on_province_pressed.bind(code))
		add_child(b)
		buttons[code] = b

func _province_by_code(code: String) -> Dictionary:
	for p in provinces:
		if str(p.get("code", "")) == code:
			return p
	return {}

func _on_province_pressed(code: String) -> void:
	_select_province(code)

func _select_province(code: String) -> void:
	var p := _province_by_code(code)
	if p.is_empty():
		return
	selected_code = code
	if map_overlay != null:
		map_overlay.set_selected(code)

	var owner := str(p.get("owner", ""))
	var owner_name := str(FACTION_NAMES.get(owner, "中立"))
	var capital := "是" if bool(p.get("capital", false)) else "否"
	info_title.text = "%s · %s" % [str(p.get("name", code)), owner_name]
	info_title.add_theme_color_override("font_color", _faction_color(owner))
	info_body.text = "地形：%s\n资源：%s\n胜利点：%d\n首都：%s\n城墙：Lv.%d\n守军：%d\n相邻：%s" % [
		str(p.get("terrain", "")),
		str(p.get("resource", "")),
		int(p.get("vp", 0)),
		capital,
		int(p.get("wall", 1)),
		int(p.get("garrison", 0)),
		"、".join(p.get("adjacency", []))
	]
	for t in order_target_labels:
		t.text = "目标：" + str(p.get("name", code))

	for c in buttons.keys():
		var b: Button = buttons[c]
		var bp := _province_by_code(str(c))
		var col := _faction_color(str(bp.get("owner", "")))
		if str(c) == selected_code:
			b.add_theme_stylebox_override("normal", _style(Color("#fff8e8"), Color("#cf8325"), 3, 4))
		else:
			b.add_theme_stylebox_override("normal", _style(Color("#fff8e8"), col, 2, 4))

func _on_submit_pressed() -> void:
	var orders: Array = []
	for i in range(order_options.size()):
		var opt: OptionButton = order_options[i]
		var order_type := opt.get_item_text(opt.selected)
		orders.append({
			"slot": i + 1,
			"type": order_type,
			"target": selected_code
		})
	var txt := JSON.stringify(orders)
	print("LOCAL_ORDERS=" + txt)
	order_log.text = "已记录 3 道军令（本地）：\n" + txt + "\n下一步接 PHP API。"
