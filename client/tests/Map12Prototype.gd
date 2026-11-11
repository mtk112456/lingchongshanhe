extends Control

## 《青竹文房·灵宠山河》12 城大地图 · 13 节点沙盘叠层原型主控制器
## 仅用于原型验证与验收截图生成，100% 独立，不替换 5 节点主工程 Slice.tscn

const Map12MapScript = preload("res://Map12Map.gd")
const FONT_PATH := "res://fonts/NotoSerifCJKsc-Regular.otf"

const C_XUANZHI := Color("#f6efe2")
const C_WOOD_DESK := Color("#2f2721")
const GOLD := Color("#cf8325")
const GOLD_LIGHT := Color("#fae19c")
const C_ZHUSHA := Color("#b83b32")
const C_MOLAN := Color("#1e3a5f")
const C_ZHUQING := Color("#276f57")
const C_TENGHUANG := Color("#cf8325")

const MAP_W := 2560.0
const MAP_H := 1920.0

var map_view: Control
var map_world: Control
var map12: Control
var touch_buttons: Dictionary = {}

var top_hud: Panel
var bottom_bar: Panel
var title_label: Label
var zoom_label: Label
var tactical_info_label: Label
var tactical_desc_label: Label
var btn_035: Button
var btn_water: Button
var btn_ca: Button
var btn_reset: Button

var map_zoom: float = 0.35
var map_pan: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var pan_start: Vector2 = Vector2.ZERO

var auto_capture_mode: bool = false
var capture_step: int = 0
var capture_frames: int = 0
var sub_viewport: SubViewport = null

func _ready() -> void:
	# 检查是否传入命令行自动截图参数
	var args := OS.get_cmdline_args()
	for a in args:
		if a == "--capture-map12":
			auto_capture_mode = true

	_build_ui()
	_layout_responsive()
	reset_view()

	if auto_capture_mode:
		_setup_auto_capture()

func _style(bg: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 8, pad: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	if pad > 0:
		s.content_margin_left = pad
		s.content_margin_right = pad
		s.content_margin_top = pad
		s.content_margin_bottom = pad
	return s

func _label(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	var f = load(FONT_PATH)
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l

func _build_ui() -> void:
	# 0. 沉静红木案几底色
	var desk_bg := ColorRect.new()
	desk_bg.color = Color("#17110d")
	desk_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(desk_bg)

	# 1. MapView (剪裁容器)
	map_view = Control.new()
	map_view.clip_contents = true
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.gui_input.connect(_on_map_view_gui_input)
	add_child(map_view)

	# 2. MapWorld (缩放平移层)
	map_world = Control.new()
	map_world.size = Vector2(MAP_W, MAP_H)
	map_view.add_child(map_world)

	# 3. Map12 地图绘制
	map12 = Map12MapScript.new()
	map12.size = Vector2(MAP_W, MAP_H)
	map_world.add_child(map12)

	# 4. 节点触控按钮
	for code in map12.NODES_DATA.keys():
		var btn := Button.new()
		btn.text = ""
		btn.flat = true
		btn.size = Vector2(120, 120)
		var empty_sb := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_sb)
		btn.add_theme_stylebox_override("hover", empty_sb)
		btn.add_theme_stylebox_override("pressed", empty_sb)
		btn.add_theme_stylebox_override("focus", empty_sb)
		btn.pressed.connect(func(): _select_city(code))
		map_world.add_child(btn)
		touch_buttons[code] = btn

	_update_touch_buttons()

	# 5. 顶部 HUD
	top_hud = Panel.new()
	top_hud.add_theme_stylebox_override("panel", _style(Color("#1a1410", 0.94), GOLD, 1, 0))
	add_child(top_hud)

	var hud_row := HBoxContainer.new()
	hud_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_row.add_theme_constant_override("margin_left", 12)
	hud_row.add_theme_constant_override("margin_right", 12)
	hud_row.add_theme_constant_override("separation", 8)
	top_hud.add_child(hud_row)

	title_label = _label("📜 九州十二城 · 十三节点沙盘叠层原型", 16, GOLD_LIGHT)
	hud_row.add_child(title_label)

	zoom_label = _label("倍率：0.35x (全景)", 12, Color("#d5c4a1"))
	hud_row.add_child(zoom_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_row.add_child(spacer)

	# 快捷视角按钮
	btn_035 = _create_hud_btn("全图 0.35x", func(): set_zoom_level(0.35))
	hud_row.add_child(btn_035)

	btn_water = _create_hud_btn("东南水网 0.50x", func(): focus_region("southeast"))
	hud_row.add_child(btn_water)

	btn_ca = _create_hud_btn("👑 长安王城", func(): focus_city("changan", 1.0))
	hud_row.add_child(btn_ca)

	btn_reset = _create_hud_btn("重置视野", reset_view)
	hud_row.add_child(btn_reset)

	# 6. 底部战术信息条
	bottom_bar = Panel.new()
	bottom_bar.add_theme_stylebox_override("panel", _style(Color("#241c16", 0.95), GOLD, 1, 8, 8))
	add_child(bottom_bar)

	var bot_v := VBoxContainer.new()
	bot_v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bot_v.add_theme_constant_override("separation", 2)
	bottom_bar.add_child(bot_v)

	tactical_info_label = _label("【天下王城 · 长安】中原核心 · 天下枢纽", 14, GOLD_LIGHT)
	bot_v.add_child(tactical_info_label)

	tactical_desc_label = _label("连通驰道：汉中、洛阳、江陵、建业（四方来朝，万国衣冠）", 12, Color("#d5c4a1"))
	bot_v.add_child(tactical_desc_label)

	_select_city("changan")

func _create_hud_btn(txt: String, on_click: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(96, 32)
	var f = load(FONT_PATH)
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Color("#ffffff"))
	b.add_theme_stylebox_override("normal", _style(Color("#3a2d21"), GOLD, 1, 6, 4))
	b.add_theme_stylebox_override("hover", _style(Color("#4d3c2c"), GOLD_LIGHT, 1, 6, 4))
	b.add_theme_stylebox_override("pressed", _style(Color("#241c16"), GOLD, 1, 6, 4))
	b.pressed.connect(on_click)
	return b

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_responsive()

func _layout_responsive() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return

	var is_compact_h := h < 650.0
	var is_compact_w := w < 850.0

	# 接入 DisplayServer.get_display_safe_area() 避让刘海屏/挖孔屏
	var safe_top := 0.0
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var win_size: Vector2i = DisplayServer.window_get_size()
	if win_size.y > 0 and safe_rect.position.y > 0:
		safe_top = float(safe_rect.position.y) * (h / float(win_size.y))

	# 顶部 HUD：保证触控高度与刘海避让
	var top_h := (48.0 if is_compact_h else 54.0) + safe_top
	if top_hud != null:
		top_hud.position = Vector2(0, 0)
		top_hud.size = Vector2(w, top_h)
		if top_hud.has_theme_constant_override("margin_top"):
			top_hud.add_theme_constant_override("margin_top", int(safe_top))

	if is_compact_w:
		if title_label != null:
			title_label.text = "📜 九州十二城"
			title_label.add_theme_font_size_override("font_size", 13)
		if zoom_label != null:
			zoom_label.add_theme_font_size_override("font_size", 11)
		if btn_035 != null:
			btn_035.text = "全图"
			btn_035.custom_minimum_size = Vector2(64, 44)
			btn_035.add_theme_font_size_override("font_size", 11)
		if btn_water != null:
			btn_water.text = "水网"
			btn_water.custom_minimum_size = Vector2(64, 44)
			btn_water.add_theme_font_size_override("font_size", 11)
		if btn_ca != null:
			btn_ca.text = "长安"
			btn_ca.custom_minimum_size = Vector2(64, 44)
			btn_ca.add_theme_font_size_override("font_size", 11)
		if btn_reset != null:
			btn_reset.text = "重置"
			btn_reset.custom_minimum_size = Vector2(64, 44)
			btn_reset.add_theme_font_size_override("font_size", 11)
	else:
		if title_label != null:
			title_label.text = "📜 九州十二城 · 十三节点沙盘叠层原型"
			title_label.add_theme_font_size_override("font_size", 16)
		if zoom_label != null:
			zoom_label.add_theme_font_size_override("font_size", 12)
		if btn_035 != null:
			btn_035.text = "全图 0.35x"
			btn_035.custom_minimum_size = Vector2(96, 44)
			btn_035.add_theme_font_size_override("font_size", 12)
		if btn_water != null:
			btn_water.text = "东南水网 0.50x"
			btn_water.custom_minimum_size = Vector2(104, 44)
			btn_water.add_theme_font_size_override("font_size", 12)
		if btn_ca != null:
			btn_ca.text = "👑 长安王城"
			btn_ca.custom_minimum_size = Vector2(96, 44)
			btn_ca.add_theme_font_size_override("font_size", 12)
		if btn_reset != null:
			btn_reset.text = "重置视野"
			btn_reset.custom_minimum_size = Vector2(88, 44)
			btn_reset.add_theme_font_size_override("font_size", 12)

	# 底部战术信息条
	var bot_h := 44.0 if is_compact_h else 54.0
	var bot_w := minf(w - 24.0, 780.0)
	if bottom_bar != null:
		bottom_bar.size = Vector2(bot_w, bot_h)
		bottom_bar.position = Vector2((w - bot_w) / 2.0, h - bot_h - 6.0)

	_apply_view()

func _update_touch_buttons() -> void:
	if map12 == null:
		return
	for code in touch_buttons.keys():
		var btn: Button = touch_buttons[code]
		var pos: Vector2 = map12.node_screen_position(code)
		btn.position = pos - Vector2(60, 90)

func _select_city(code: String) -> void:
	if code == "" or map12 == null or not map12.NODES_DATA.has(code):
		if map12 != null:
			map12.select_node("")
		if tactical_info_label != null:
			tactical_info_label.text = "【九州十二城沙盘】青绿金碧水墨 · 十三节点沙盘叠层原型"
		if tactical_desc_label != null:
			tactical_desc_label.text = "四大学院分踞四方（笔墨砚纸），中央王城长安总揽天下文脉。"
		return
	map12.select_node(code)
	var data: Dictionary = map12.NODES_DATA[code]
	var c_name: String = data["name"]
	var reg: String = data["region"]
	var tag: String = data.get("tag", "")
	var verse: String = data.get("verse", "")

	tactical_info_label.text = "【%s】%s %s" % [c_name, reg, tag]
	
	# 收集相邻驰道
	var neighbors := []
	for e in map12.EDGES:
		if e[0] == code and map12.NODES_DATA.has(e[1]):
			neighbors.append(map12.NODES_DATA[e[1]]["name"])
		elif e[1] == code and map12.NODES_DATA.has(e[0]):
			neighbors.append(map12.NODES_DATA[e[0]]["name"])
	
	var neigh_str := "、".join(neighbors) if neighbors.size() > 0 else "无"
	tactical_desc_label.text = "连通据点：%s | 文脉：%s" % [neigh_str, verse]

func reset_view() -> void:
	set_full_bleed_view()

func set_full_bleed_view() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var scale_x := w / MAP_W
	var scale_y := h / MAP_H
	# Full-Bleed Cover: 填满视口长短边，有效面积 100%，0 深色留白画框
	map_zoom = maxf(scale_x, scale_y)
	map_pan = (Vector2(w, h) - Vector2(MAP_W, MAP_H) * map_zoom) / 2.0
	_apply_view()

func focus_center(target_zoom: float = 0.50) -> void:
	map_zoom = target_zoom
	var center_world := Vector2(MAP_W, MAP_H) / 2.0
	var viewport_center := size / 2.0
	map_pan = viewport_center - center_world * map_zoom
	_apply_view()

func set_zoom_level(z: float) -> void:
	var center := size / 2.0
	_zoom_at(center, z / map_zoom)

func focus_city(code: String, target_zoom: float = 1.0) -> void:
	if map12 == null or not map12.NODES_DATA.has(code):
		return
	_select_city(code)
	map_zoom = target_zoom
	var pos: Vector2 = map12.node_screen_position(code)
	var viewport_center := size / 2.0
	map_pan = viewport_center - pos * map_zoom
	_apply_view()

func focus_region(reg: String) -> void:
	map_zoom = 0.50
	var target_norm := Vector2(0.75, 0.745) # 东南水网中心
	if reg == "northwest":
		target_norm = Vector2(0.23, 0.23)
	elif reg == "northeast":
		target_norm = Vector2(0.74, 0.24)
	elif reg == "southwest":
		target_norm = Vector2(0.22, 0.70)
	var dest_pos := target_norm * Vector2(MAP_W, MAP_H)
	var viewport_center := size / 2.0
	map_pan = viewport_center - dest_pos * map_zoom
	_select_city("jianye")
	_apply_view()

func _zoom_at(focus_point: Vector2, factor: float) -> void:
	var old_zoom := map_zoom
	var min_cover := maxf(size.x / MAP_W, size.y / MAP_H) if (size.x > 0.0 and size.y > 0.0) else 0.35
	var min_limit := minf(min_cover * 0.96, 0.55)
	var new_zoom := clampf(map_zoom * factor, min_limit, 2.5)
	if is_equal_approx(old_zoom, new_zoom):
		return
	var world_pt := (focus_point - map_pan) / old_zoom
	map_zoom = new_zoom
	map_pan = focus_point - world_pt * map_zoom
	_apply_view()

func _clamp_pan() -> void:
	var scaled_size := Vector2(MAP_W, MAP_H) * map_zoom
	if scaled_size.x <= size.x:
		map_pan.x = (size.x - scaled_size.x) / 2.0
	else:
		map_pan.x = clampf(map_pan.x, size.x - scaled_size.x, 0.0)

	if scaled_size.y <= size.y:
		map_pan.y = (size.y - scaled_size.y) / 2.0
	else:
		map_pan.y = clampf(map_pan.y, size.y - scaled_size.y, 0.0)

func _apply_view() -> void:
	_clamp_pan()
	if map_world != null:
		map_world.scale = Vector2(map_zoom, map_zoom)
		map_world.position = map_pan
	if map12 != null:
		map12.set_zoom_level(map_zoom)
	if zoom_label != null:
		var lod_str := "全景" if map_zoom < 0.45 else ("区域精简" if map_zoom < 0.75 else "战术近景")
		zoom_label.text = "倍率：%.2fx (%s)" % [map_zoom, lod_str]

func _on_map_view_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.is_pressed():
			_zoom_at(mb.position, 1.15)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.is_pressed():
			_zoom_at(mb.position, 1.0 / 1.15)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.double_click and mb.is_pressed():
				_zoom_at(mb.position, 1.4 if map_zoom < 1.6 else 1.0 / (map_zoom / 0.35))
				get_viewport().set_input_as_handled()
			elif mb.is_pressed():
				is_dragging = true
				drag_start = mb.position
				pan_start = map_pan
			else:
				is_dragging = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if is_dragging:
			map_pan = pan_start + (mm.position - drag_start)
			_apply_view()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# 自动化验收截图生成状态机
# ---------------------------------------------------------------------------

func _setup_auto_capture() -> void:
	print("MAP12_AUTO_CAPTURE start")
	set_process(true)

func _process(_delta: float) -> void:
	if not auto_capture_mode:
		return
	capture_frames += 1

	# 阶段 1：平板 1400×1000 下 0.35x 全景截图
	if capture_step == 0:
		if capture_frames > 25:
			_capture("screenshot_tablet_map12_zoom_035.png")
			_select_city("changan")
			capture_step = 1
			capture_frames = 0
	# 阶段 2：平板 1400×1000 选中长安，4 条主干道高亮
	elif capture_step == 1:
		if capture_frames > 25:
			_capture("screenshot_tablet_map12_selected_changan.png")
			# 切换到手机横屏 720×514
			get_viewport().size = Vector2i(720, 514)
			size = Vector2(720, 514)
			_layout_responsive()
			map_zoom = 0.50
			_select_city("jianye")
			_clamp_pan()
			capture_step = 2
			capture_frames = 0
	# 阶段 3：手机横屏 720×514 下 0.50x 视野
	elif capture_step == 2:
		if capture_frames > 30:
			_capture("screenshot_phone_landscape_map12_zoom_050.png")
			# 聚焦东南水网（建业/会稽/寿春）
			focus_region("southeast")
			capture_step = 3
			capture_frames = 0
	# 阶段 4：手机横屏 720×514 聚焦东南水网三城与水面路线
	elif capture_step == 3:
		if capture_frames > 30:
			_capture("screenshot_phone_landscape_map12_water.png")
			print("MAP12_AUTO_CAPTURE COMPLETE (ALL 4 REQUIRED SCREENSHOTS GENERATED)")
			get_tree().quit(0)

func _capture(filename: String) -> void:
	var vp := get_viewport()
	var tex := vp.get_texture()
	if tex != null:
		var img := tex.get_image()
		if img != null:
			img.save_png("res://tests/" + filename)
			print("CAPTURED_MAP12: %s (%dx%d)" % [filename, img.get_width(), img.get_height()])
