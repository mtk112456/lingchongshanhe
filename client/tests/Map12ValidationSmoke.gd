extends Node

## 《青竹文房·灵宠山河》13 节点主场景 Live 自动化验收套件

var sv: SubViewport
var scene: Control
var frames := 0
var total_frames := 0
var step := -1

const ALL_13_NODES := [
	"liangzhou", "hanzhong", "xiangyang",
	"yecheng", "taiyuan", "luoyang",
	"chengdu", "jiangling", "changsha",
	"jianye", "kuaiji", "shouchun",
	"changan"
]

const CHANGAN_NEIGHBORS := ["hanzhong", "luoyang", "jiangling", "jianye"]

func _ready() -> void:
	print("MAP12_VALIDATION start (Dual-Landscape Mode)")
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
	total_frames += 1
	if total_frames > 1200:
		_fail("Timeout at step %d (login_status=%s, action_status=%s)" % [step, str(scene.login_status.text), str(scene.action_status.text)])
		return

	if step == -1:
		if frames > 10:
			scene.url_edit.text = "http://127.0.0.1:8080"
			scene.name_edit.text = "青竹一"
			scene.pass_edit.text = "slice2026"
			scene._on_login(false)
			print("MAP12 [INFO] Login requested for 青竹一...")
			step = 0
			frames = 0

	# 等待登录拉取到 MAP12_TEST 战局
	elif step == 0:
		if scene.game_layer.visible and not scene.state.is_empty() and frames > 25:
			var nodes: Array = scene.state.get("map", {}).get("nodes", [])
			var edges: Array = scene.state.get("map", {}).get("edges", [])
			print("MAP12 [STEP 1] Login success! nodes count: %d, edges count: %d" % [nodes.size(), edges.size()])
			if nodes.size() != 13:
				_fail("Expected 13 nodes, got %d" % nodes.size())
				return
			if edges.size() != 19:
				_fail("Expected 19 edges, got %d" % edges.size())
				return
			
			var map_script_path: String = scene.map.get_script().resource_path
			print("MAP12 [PASS] Map script instantiated: %s" % map_script_path)
			if not "Map12Map" in map_script_path:
				_fail("Expected Map12Map script, got %s" % map_script_path)
				return

			step = 1
			frames = 0

	# 验收 1：13 城全部可点，每个城都能成功获取信息并打开抽屉
	elif step == 1:
		for code in ALL_13_NODES:
			if not scene.node_buttons.has(code):
				_fail("Missing node button for %s" % code)
				return
			var b: Button = scene.node_buttons[code]
			if not is_instance_valid(b):
				_fail("Invalid node button for %s" % code)
				return
			var btn_pos: Vector2 = scene.map.node_position(code)
			if btn_pos == Vector2.ZERO:
				_fail("Node %s has zero position" % code)
				return
			# 模拟点击节点打开抽屉
			scene._on_node_pressed(code)
			if not scene.city_drawer.visible or scene.selected_code != code:
				_fail("Clicking node %s failed to open city drawer" % code)
				return
			var nd: Dictionary = scene.map.node_by_code(code)
			if str(nd.get("name", "")) == "":
				_fail("Node %s missing name" % code)
				return
		
		print("MAP12 [PASS] 13 cities all clickable and correctly bound to city drawer!")
		step = 2
		frames = 0

	# 验收 2：第 1 周长安锁定验证 (cur_week = 1 < 3)
	elif step == 2:
		scene._open_city_drawer("changan")
		var is_btn_disabled: bool = bool(scene.city_action_advance_btn.disabled)
		var btn_text: String = str(scene.city_action_advance_btn.text)
		print("MAP12 [CHECK] Week 1 Changan advance button: text='%s', disabled=%s" % [btn_text, str(is_btn_disabled)])
		if not is_btn_disabled or not "第 3 周开放" in btn_text:
			_fail("Week 1 Changan should be locked with '第 3 周开放', got '%s' disabled=%s" % [btn_text, str(is_btn_disabled)])
			return
		print("MAP12 [PASS] Changan locked in Week 1-2 ('%s')!" % btn_text)
		step = 21
		frames = 0

	elif step == 21:
		if scene.toast_panel != null:
			scene.toast_panel.visible = false
		if frames > 10:
			_capture("screenshot_tablet_map12_changan_locked.png")
			step = 3
			frames = 0

	# 验收 3：模拟第 3 周长安开放验证 (turn_no = 15, cur_week = 3)
	elif step == 3:
		var turn_dict: Dictionary = scene.state.get("turn", {}).duplicate()
		turn_dict["turn_no"] = 15
		scene.state["turn"] = turn_dict
		scene._open_city_drawer("changan")
		var btn_text_w3: String = str(scene.city_action_advance_btn.text)
		print("MAP12 [CHECK] Week 3 Changan advance button text='%s'" % btn_text_w3)
		if "第 3 周开放" in btn_text_w3:
			_fail("Week 3 Changan should be open, but still says '%s'" % btn_text_w3)
			return
		print("MAP12 [PASS] Week 3 Changan unlocked and open!")
		step = 4
		frames = 0

	# 验收 4：模拟第 4 周决战周限制验证 (turn_no = 22, cur_week = 4)
	elif step == 4:
		var turn_dict: Dictionary = scene.state.get("turn", {}).duplicate()
		turn_dict["turn_no"] = 22
		scene.state["turn"] = turn_dict
		
		var non_neighbors := ["liangzhou", "taiyuan", "chengdu", "changsha"]
		for code in non_neighbors:
			scene._open_city_drawer(code)
			var txt: String = str(scene.city_action_advance_btn.text)
			var dis: bool = bool(scene.city_action_advance_btn.disabled)
			if not dis or not "决战周限长安及邻城" in txt:
				_fail("Week 4 non-neighbor city %s should have '决战周限长安及邻城', got '%s' disabled=%s" % [code, txt, str(dis)])
				return
		
		for code in CHANGAN_NEIGHBORS:
			scene._open_city_drawer(code)
			var txt: String = str(scene.city_action_advance_btn.text)
			if "决战周限长安及邻城" in txt:
				_fail("Week 4 Changan neighbor %s should NOT be blocked by final week rule" % code)
				return
		scene._open_city_drawer("changan")
		if "决战周限长安及邻城" in str(scene.city_action_advance_btn.text):
			_fail("Week 4 Changan itself should NOT be blocked by final week rule")
			return

		print("MAP12 [PASS] Week 4 final week rule verified: only Changan and its 4 neighbors are targetable!")
		step = 5
		frames = 0

	# 验收 5：拍照双横屏分辨率实测产物
	elif step == 5:
		var turn_dict: Dictionary = scene.state.get("turn", {}).duplicate()
		turn_dict["turn_no"] = 1
		scene.state["turn"] = turn_dict
		scene._toggle_city_drawer(false)
		scene.is_drawer_open = false
		scene.city_drawer.visible = false
		scene.selected_code = ""
		if scene.map != null and scene.map.has_method("set_selected"):
			scene.map.set_selected("")
		scene._render_hand_cards(false)
		if scene.toast_panel != null:
			scene.toast_panel.visible = false
		scene._navigate_to("S01_MAP")
		scene.reset_view()
		step = 6
		frames = 0

	elif step == 6:
		if frames > 35:
			_capture("screenshot_tablet_map12_live.png")
			_set_viewport_size(720, 514)
			step = 7
			frames = 0

	elif step == 7:
		if frames > 25:
			_capture("screenshot_phone_landscape_map12_live.png")
			print("==========================================")
			print("ALL MAP12 VERIFICATIONS PASSED SUCCESSFULLY!")
			print("==========================================")
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

func _fail(msg: String) -> void:
	printerr("MAP12_FAIL: ", msg)
	print("MAP12_FAIL: ", msg)
	get_tree().quit(1)
