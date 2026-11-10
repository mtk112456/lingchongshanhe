extends Node

## 12 城大地图 · 13 节点叠层原型专用自动化全分辨率截图套件
## 覆盖规格：
## 1. 平板 1400×1000:
##    - screenshot_tablet_map12_zoom_035.png (0.35x 全图未选态，数清 12 外围城 + 长安王城，16 条驰道基底)
##    - screenshot_tablet_map12_selected_changan.png (选中长安，4 条通往各大书院主干道三层金色流光高亮)
## 2. 手机横屏 720×514:
##    - screenshot_phone_landscape_map12_zoom_050.png (0.50x 视野居中，精简单行城名纸签，不重叠)
##    - screenshot_phone_landscape_map12_water.png (手机横屏聚焦东南水网建业/会稽/寿春，三城不混，最低城不被遮挡)

var sv: SubViewport
var proto: Control
var frames := 0
var step := 0

func _ready() -> void:
	print("RUN_MAP12_CAPTURE start (SubViewport Mode)")
	sv = SubViewport.new()
	sv.size = Vector2i(1400, 1000)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)

	var scene_res = load("res://tests/Map12Prototype.tscn")
	proto = scene_res.instantiate()
	sv.add_child(proto)
	proto.size = Vector2(1400, 1000)
	proto._layout_responsive()
	proto.map_zoom = 0.35
	proto._select_city("")
	proto._apply_view()

func _process(_delta: float) -> void:
	frames += 1

	# -----------------------------------------------------------------------
	# 阶段一：平板 1400×1000 下 0.35x 全景 (数清 12 外围城 + 1 长安王城)
	# 初始未选任何城池，16 条拓扑驰道呈深墨暗褐基底，全图纯净开阔
	# -----------------------------------------------------------------------
	if step == 0:
		if frames > 25:
			_capture("screenshot_tablet_map12_zoom_035.png")
			# 切换到阶段二：选中长安
			proto._select_city("changan")
			step = 1
			frames = 0
	# -----------------------------------------------------------------------
	# 阶段二：平板 1400×1000 选中长安，4 条主干道三层金色流光高亮
	# -----------------------------------------------------------------------
	elif step == 1:
		if frames > 25:
			_capture("screenshot_tablet_map12_selected_changan.png")
			# 切换到手机横屏 720×514，0.50x 视野居中展示
			_set_viewport_size(720, 514)
			proto.focus_center(0.50)
			step = 2
			frames = 0
	# -----------------------------------------------------------------------
	# 阶段三：手机横屏 720×514 下 0.50x 视野 (精简单行城名纸签，居中视野)
	# -----------------------------------------------------------------------
	elif step == 2:
		if frames > 25:
			_capture("screenshot_phone_landscape_map12_zoom_050.png")
			# 聚焦东南水网建业/会稽/寿春，选中建业
			proto.focus_region("southeast")
			step = 3
			frames = 0
	# -----------------------------------------------------------------------
	# 阶段四：手机横屏 720×514 聚焦东南水网 (三城不混，路线不被水面吞，最低城寿春不被挡)
	# -----------------------------------------------------------------------
	elif step == 3:
		if frames > 25:
			_capture("screenshot_phone_landscape_map12_water.png")
			print("RUN_MAP12_CAPTURE COMPLETE (ALL 4 REQUIRED SCREENSHOTS GENERATED)")
			get_tree().quit(0)

func _set_viewport_size(w: int, h: int) -> void:
	sv.size = Vector2i(w, h)
	proto.size = Vector2(w, h)
	proto._layout_responsive()

func _capture(filename: String) -> void:
	var tex := sv.get_texture()
	if tex != null:
		var img := tex.get_image()
		if img != null:
			img.save_png("res://tests/" + filename)
			print("CAPTURED: %s (%dx%d)" % [filename, img.get_width(), img.get_height()])
