extends Node

## 商业级自动化全分辨率截图套件
## 覆盖：平板 (1400×1000)、手机竖屏 (720×1280)、手机横屏 (720×514)
## 验证页面：S01 主沙盘、S02 城池抽屉、S03 军令浮层、S04 战报全屏、S05 沙盘复盘、S06 阵营大势

var sv: SubViewport
var scene: Control
var frames := 0
var step := 0

func _ready() -> void:
	print("CAPTURE_SUITE start (SubViewport Mode)")
	sv = SubViewport.new()
	sv.size = Vector2i(1400, 1000)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)

	scene = load("res://Slice.tscn").instantiate()
	sv.add_child(scene)
	scene.size = Vector2(1400, 1000)

	scene.url_edit.text = "http://127.0.0.1:8080"
	scene.name_edit.text = "青竹一"
	scene.pass_edit.text = "slice2026"
	scene._on_login(false)

func _process(_delta: float) -> void:
	frames += 1
	
	# -----------------------------------------------------------------------
	# 阶段一：平板 1400×1000 (S01 - S06)
	# -----------------------------------------------------------------------
	if step == 0:
		if scene.game_layer.visible and not scene.state.is_empty() and frames > 40:
			_capture("screenshot_tablet_s01_map.png")
			scene.map_zoom = 1.75
			scene.focus_city("A_START")
			step = 1
			frames = 0
	elif step == 1:
		if frames > 20:
			_capture("screenshot_tablet_s01_map_zoom_lod.png")
			scene.reset_view()
			scene._open_city_drawer("A_START")
			step = 2
			frames = 0
	elif step == 2:
		if frames > 25:
			_capture("screenshot_tablet_s02_drawer.png")
			scene._on_city_defend_pressed()
			step = 3
			frames = 0
	elif step == 3:
		if frames > 25:
			_capture("screenshot_tablet_s03_order_confirm.png")
			scene.order_confirm_overlay.visible = false
			scene._open_report()
			step = 4
			frames = 0
	elif step == 4:
		if frames > 30:
			_capture("screenshot_tablet_s04_war_report.png")
			scene._open_replay()
			step = 5
			frames = 0
	elif step == 5:
		if frames > 30:
			_capture("screenshot_tablet_s05_battle_replay.png")
			scene._navigate_to("S06_FACTION")
			step = 6
			frames = 0
	elif step == 6:
		if frames > 25:
			_capture("screenshot_tablet_s06_faction.png")
			
			# 切换到手机竖屏 720×1280
			_set_viewport_size(720, 1280)
			scene._navigate_to("S01_MAP")
			scene.city_drawer.visible = false
			step = 7
			frames = 0

	# -----------------------------------------------------------------------
	# 阶段二：手机竖屏 720×1280 (S01, S02)
	# -----------------------------------------------------------------------
	elif step == 7:
		if frames > 35:
			_capture("screenshot_phone_portrait_s01_map.png")
			_capture("screenshot_phone_s01_map.png") # 兼容旧命名
			scene._open_city_drawer("A_START")
			step = 8
			frames = 0
	elif step == 8:
		if frames > 30:
			_capture("screenshot_phone_portrait_s02_drawer.png")
			_capture("screenshot_phone_s02_drawer.png") # 兼容旧命名
			
			# 切换到手机横屏 720×514
			_set_viewport_size(720, 514)
			scene._navigate_to("S01_MAP")
			scene.city_drawer.visible = false
			step = 9
			frames = 0

	# -----------------------------------------------------------------------
	# 阶段三：手机横屏 720×514 (S01, S02)
	# -----------------------------------------------------------------------
	elif step == 9:
		if frames > 35:
			_capture("screenshot_phone_landscape_s01_map.png")
			scene._open_city_drawer("A_START")
			step = 10
			frames = 0
	elif step == 10:
		if frames > 30:
			_capture("screenshot_phone_landscape_s02_drawer.png")
			print("CAPTURE_SUITE COMPLETE (ALL RESOLUTIONS)")
			get_tree().quit(0)

func _set_viewport_size(w: int, h: int) -> void:
	sv.size = Vector2i(w, h)
	scene.size = Vector2(w, h)
	scene._layout_responsive()

func _capture(filename: String) -> void:
	var tex := sv.get_texture()
	if tex != null:
		var img := tex.get_image()
		if img != null:
			img.save_png("res://tests/" + filename)
			print("CAPTURED: %s (%dx%d)" % [filename, img.get_width(), img.get_height()])
