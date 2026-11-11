extends Node

## 商业级自动化全分辨率截图套件 (横屏-Only 专用版)
## 仅覆盖用户确定的横屏设备：平板 (1400×1000)、手机横屏 (720×514)
## 手机竖屏已正式下线，全套验收由手机横屏负责

var sv: SubViewport
var scene: Control
var frames := 0
var step := 0

func _ready() -> void:
	print("CAPTURE_SUITE start (Landscape-Only Mode)")
	var tut_cfg := ConfigFile.new()
	tut_cfg.set_value("tutorial", "completed", true)
	tut_cfg.save("user://tutorial_completed.cfg")
	sv = SubViewport.new()
	sv.size = Vector2i(1400, 1000)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)

	scene = load("res://Slice.tscn").instantiate()
	sv.add_child(scene)
	scene.size = Vector2(1400, 1000)
	scene._layout_responsive()

func _process(_delta: float) -> void:
	frames += 1

	# -----------------------------------------------------------------------
	# 阶段零：登录页双横屏分辨率验收 (平板 1400×1000 & 手机横屏 720×514)
	# -----------------------------------------------------------------------
	if step == 0:
		if frames > 15:
			_capture("screenshot_login_keyart.png")
			_set_viewport_size(720, 514)
			step = 100
			frames = 0
	elif step == 100:
		if frames > 15:
			_capture("screenshot_phone_landscape_login.png")
			_set_viewport_size(1400, 1000)
			scene.url_edit.text = "http://127.0.0.1:8080"
			scene.name_edit.text = "青竹一"
			scene.pass_edit.text = "slice2026"
			scene._on_login(false)
			step = 1
			frames = 0

	# -----------------------------------------------------------------------
	# 阶段一：平板 1400×1000 (S01 - S06, S10)
	# -----------------------------------------------------------------------
	elif step == 1:
		if scene.game_layer.visible and not scene.state.is_empty() and frames > 35:
			_capture("screenshot_tablet_s01_map.png")
			scene.map_zoom = 0.5
			scene._clamp_pan()
			step = 101
			frames = 0
	elif step == 101:
		if frames > 20:
			_capture("screenshot_tablet_s01_map_zoom_50.png")
			scene.map_zoom = 1.75
			scene.focus_city("A_START")
			step = 2
			frames = 0
	elif step == 2:
		if frames > 20:
			_capture("screenshot_tablet_s01_map_zoom_lod.png")
			scene.reset_view()
			scene._open_city_drawer("A_START")
			step = 3
			frames = 0
	elif step == 3:
		if frames > 25:
			_capture("screenshot_tablet_s02_drawer.png")
			scene._on_city_defend_pressed()
			step = 4
			frames = 0
	elif step == 4:
		if frames > 25:
			_capture("screenshot_tablet_s03_order_confirm.png")
			scene.order_confirm_overlay.visible = false
			# 平板阶段：截取 S03 军团编成
			scene._navigate_to("S03_ARMY")
			step = 41
			frames = 0
	elif step == 41:
		if frames > 25:
			_capture("screenshot_tablet_s03_army_composition.png")
			# 平板阶段：调起 3x2 战斗推演回放
			scene._open_battle_replay_demo()
			step = 42
			frames = 0
	elif step == 42:
		if frames > 30:
			_capture("screenshot_tablet_phase1_battle_replay.png")
			scene.battle_replay_overlay.visible = false
			scene._open_report()
			step = 5
			frames = 0
	elif step == 5:
		if frames > 30:
			_capture("screenshot_tablet_s04_war_report.png")
			scene._open_replay()
			step = 6
			frames = 0
	elif step == 6:
		if frames > 30:
			_capture("screenshot_tablet_s05_battle_replay.png")
			scene._navigate_to("S06_FACTION")
			step = 7
			frames = 0
	elif step == 7:
		if frames > 25:
			_capture("screenshot_tablet_s06_faction.png")
			scene._navigate_to("S10_SEASON")
			step = 8
			frames = 0
	elif step == 8:
		if frames > 25:
			_capture("screenshot_tablet_s10_season.png")
			scene._navigate_to("S11_SETTINGS")
			step = 81
			frames = 0
	elif step == 81:
		if frames > 25:
			_capture("screenshot_tablet_s11_settings.png")
			scene._navigate_to("S01_MAP")
			scene._start_tutorial()
			step = 82
			frames = 0
	elif step == 82:
		if frames > 25:
			_capture("screenshot_tablet_tutorial.png")
			scene._complete_tutorial()

			# 切换到手机横屏 720×514（彻底移除手机竖屏）
			_set_viewport_size(720, 514)
			scene.is_drawer_open = false
			scene.city_drawer.visible = false
			scene._navigate_to("S01_MAP")
			scene._layout_responsive()
			step = 9
			frames = 0

	# -----------------------------------------------------------------------
	# 阶段二：手机横屏 720×514 (唯一手机验收目标：S01 - S05 及最低节点 N1/B_START)
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
			# 手机横屏最低城池验收：松风渡 (N1)
			scene._open_city_drawer("N1")
			step = 11
			frames = 0
	elif step == 11:
		if frames > 30:
			_capture("screenshot_phone_landscape_lowest_n1.png")
			# 手机横屏最低城池验收：雁回关 (B_START)
			scene._open_city_drawer("B_START")
			step = 12
			frames = 0
	elif step == 12:
		if frames > 30:
			_capture("screenshot_phone_landscape_lowest_bstart.png")
			# 手机横屏军令确认浮层验收
			scene._on_city_defend_pressed()
			step = 13
			frames = 0
	elif step == 13:
		if frames > 25:
			_capture("screenshot_phone_landscape_s03_order_confirm.png")
			scene.order_confirm_overlay.visible = false
			scene._open_report()
			step = 14
			frames = 0
	elif step == 14:
		if frames > 30:
			_capture("screenshot_phone_landscape_s04_war_report.png")
			scene._open_replay()
			step = 15
			frames = 0
	elif step == 15:
		if frames > 30:
			_capture("screenshot_phone_landscape_s05_battle_replay.png")
			scene._navigate_to("S01_MAP")
			scene._toggle_city_drawer(false)
			step = 16
			frames = 0
	elif step == 16:
		if frames > 25:
			scene.is_drawer_open = false
			scene.city_drawer.visible = false
			scene._layout_responsive()
			step = 161
			frames = 0
	elif step == 161:
		if frames > 15:
			_capture("screenshot_phone_landscape_dock_restored.png")
			_capture("screenshot_phone_landscape_s01_hand_cards.png")
			scene._navigate_to("S03_ARMY")
			step = 17
			frames = 0
	elif step == 17:
		if frames > 25:
			_capture("screenshot_phone_landscape_s03_army_composition.png")
			scene._open_battle_replay_demo()
			step = 18
			frames = 0
	elif step == 18:
		if frames > 30:
			_capture("screenshot_phone_landscape_phase1_battle_replay.png")
			scene.battle_replay_overlay.visible = false
			scene._navigate_to("S11_SETTINGS")
			step = 19
			frames = 0
	elif step == 19:
		if frames > 25:
			_capture("screenshot_phone_landscape_s11_settings.png")
			scene._navigate_to("S01_MAP")
			scene._start_tutorial()
			step = 20
			frames = 0
	elif step == 20:
		if frames > 25:
			_capture("screenshot_phone_landscape_tutorial.png")
			scene._complete_tutorial()
			print("CAPTURE_SUITE COMPLETE (LANDSCAPE ONLY: TABLET 1400x1000 & PHONE 720x514)")
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
