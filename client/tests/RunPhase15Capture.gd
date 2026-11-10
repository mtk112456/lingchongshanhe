extends Node

## Phase 1.5 渲染截图套件 (SubViewport 全分辨率画质输出)
## 涵盖规格：
## 1. 任务 1：手牌条 4 态一眼分清 (screenshot_p15_hand_cards_4states.png)
## 2. 任务 1：撤回后恢复可拖 (screenshot_p15_hand_cards_withdrawn.png)
## 3. 任务 3：哨探情报面板 (screenshot_p15_intel_dialog.png)
## 4. 任务 2：战斗结算折页逐队解释 (screenshot_p15_battle_result_tactics.png)
## 5. 任务 2：每日战报折页逐队解释 (screenshot_p15_war_report_tactics.png)
## 6. 手机横屏 720×514 手牌条自适应 (screenshot_phone_landscape_p15_hand_cards.png)

var sv: SubViewport
var scene: Control
var frames := 0
var step := 0
var target_node := "N2"
var play_cards: Array = []
var has_scout := false

func _ready() -> void:
	print("RUN_PHASE15_CAPTURE start (SubViewport Mode)")
	sv = SubViewport.new()
	sv.size = Vector2i(1400, 1000)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.gui_embed_subwindows = true
	add_child(sv)

	scene = load("res://Slice.tscn").instantiate()
	sv.add_child(scene)
	scene.size = Vector2(1400, 1000)
	scene._layout_responsive()

	scene.url_edit.text = "http://127.0.0.1:8080"
	scene.name_edit.text = "青竹一"
	scene.pass_edit.text = "slice2026"
	scene._on_login(false)

func _process(_delta: float) -> void:
	frames += 1

	match step:
		0: # 等待登录拉取 state
			if scene.game_layer.visible and not scene.state.is_empty() and frames > 25:
				var hand_cards: Array = scene.state.get("hand", {}).get("cards", [])
				print("P15_CAPTURE: login ok, hand cards: %s" % str(hand_cards))
				_build_play_cards(hand_cards)
				if not has_scout and not scene.hand_redraw_used:
					print("P15_CAPTURE: no scout in first hand, redrawing once")
					scene.redraw_hand_cards()
					step = 13
					frames = 0
					return
				print("P15_CAPTURE: play order: %s (has_scout=%s)" % [str(play_cards), str(has_scout)])
				scene.set_army_composition(["cav", "shield", "arc"])
				step = 1
				frames = 0
			elif frames > 300:
				_fail("login timeout")

		13: # 等重抽结果，再决定出牌顺序
			if frames > 100:
				var hand_cards: Array = scene.state.get("hand", {}).get("cards", [])
				_build_play_cards(hand_cards)
				print("P15_CAPTURE: redrawn cards: %s, play order: %s (has_scout=%s)" % [
					str(hand_cards), str(play_cards), str(has_scout)
				])
				scene.set_army_composition(["cav", "shield", "arc"])
				step = 1
				frames = 0
			elif frames > 300:
				_fail("redraw timeout")

		1: # 编成确认后，下达 3 道将令
			var cur_types: Array = scene.state.get("composition", {}).get("types", [])
			if cur_types == ["cav", "shield", "arc"]:
				print("P15_CAPTURE: playing 3 tactical orders")
				scene.play_card(0, str(play_cards[0]), "N2", 1, "front")
				scene.play_card(1, str(play_cards[1]), "N2", 2, "front")
				scene.play_card(2, str(play_cards[2]), "N2", 3, "back")
				step = 2
				frames = 0
			elif frames > 200:
				_fail("composition timeout")

		2: # 验证 3 槽已满，第 4 张牌自动变为【今日不用】，截取任务 1 图
			var orders: Array = scene.state.get("card_orders", [])
			if orders.size() >= 3 and frames > 35:
				print("P15_CAPTURE: 3 orders filled, capturing 4 states")
				_capture("screenshot_p15_hand_cards_4states.png")
				
				# 撤回 slot 0
				print("P15_CAPTURE: withdrawing slot 0")
				scene.withdraw_card(0)
				step = 3
				frames = 0
			elif frames > 300:
				_fail("wait 3 orders timeout")

		3: # 验证撤回后第 4 张牌解除弃牌，截取恢复图
			var orders: Array = scene.state.get("card_orders", [])
			if orders.size() == 2 and frames > 30:
				print("P15_CAPTURE: capturing withdrawn recovery")
				_capture("screenshot_p15_hand_cards_withdrawn.png")
				
				if has_scout:
					# 打开 N2 城池抽屉，测试哨探军报面板（slot 2 是 scout）
					scene._open_city_drawer("N2")
					step = 4
				else:
					print("P15_CAPTURE: no scout in hand, skipping intel dialog capture")
					step = 5
				frames = 0
			elif frames > 200:
				_fail("withdraw timeout")

		4: # 打开哨探军报弹窗
			if scene.city_drawer.visible and frames > 25:
				print("P15_CAPTURE: opening city intel dialog")
				scene._open_city_intel_dialog("N2")
				step = 5
				frames = 0
			elif frames > 200:
				_fail("drawer timeout")

		5: # 截取哨探情报弹窗
			if has_scout:
				if scene.city_intel_dialog.visible and scene.city_intel_vbox.get_child_count() > 1 and frames > 35:
					print("P15_CAPTURE: capturing intel dialog")
					_capture("screenshot_p15_intel_dialog.png")
					scene.city_intel_dialog.hide()
					scene._toggle_city_drawer(false)
					_start_battle()
				elif frames > 250:
					_fail("intel dialog timeout")
			else:
				_start_battle()

		6: # 战斗回放跳过至结算第二折
			if scene.battle_replay_overlay.visible and scene.battle_replay_instance and frames > 25:
				print("P15_CAPTURE: skipping replay to tactics fold")
				scene.battle_replay_instance._on_skip_pressed()
				scene.battle_replay_instance._show_page_frame(1)
				step = 7
				frames = 0
			elif frames > 300:
				_fail("battle overlay timeout")

		7: # 截取战斗结算折页逐队战术
			if scene.battle_replay_instance.page_frame_2.visible and frames > 35:
				print("P15_CAPTURE: capturing battle result tactics")
				_capture("screenshot_p15_battle_result_tactics.png")
				scene.battle_replay_overlay.visible = false
				
				# 打开每日战报
				scene._open_report()
				step = 8
				frames = 0
			elif frames > 200:
				_fail("tactics fold timeout")

		8: # 截取每日战报逐队战术清单
			if scene.report_page.visible and frames > 35:
				print("P15_CAPTURE: capturing war report tactics")
				_capture("screenshot_p15_war_report_tactics.png")
				
				# 切换手机横屏 720×514
				_set_viewport_size(720, 514)
				scene.report_page.visible = false
				scene._navigate_to("S01_MAP")
				scene._layout_responsive()
				step = 9
				frames = 0
			elif frames > 200:
				_fail("war report timeout")

		9: # 截取手机横屏手牌条
			if frames > 35:
				print("P15_CAPTURE: capturing phone landscape hand cards")
				_capture("screenshot_phone_landscape_p15_hand_cards.png")
				print("========================================")
				print("PHASE 1.5 SCREENSHOTS CAPTURE COMPLETE!")
				print("========================================")
				get_tree().quit(0)

func _start_battle() -> void:
	print("P15_CAPTURE: starting demo battle")
	scene.start_demo_battle("N2", true, func(ok: bool, _data: Dictionary):
		if not ok:
			_fail("start demo battle failed")
	)
	step = 6
	frames = 0

func _build_play_cards(hand_cards: Array) -> void:
	var scout_idx := hand_cards.find("scout")
	has_scout = scout_idx >= 0
	play_cards = []
	if has_scout:
		for c in hand_cards:
			if str(c) != "scout" and play_cards.size() < 2:
				play_cards.append(str(c))
		play_cards.append("scout")
	else:
		for i in range(min(3, hand_cards.size())):
			play_cards.append(str(hand_cards[i]))

func _set_viewport_size(w: int, h: int) -> void:
	sv.size = Vector2i(w, h)
	scene.size = Vector2(w, h)
	scene._layout_responsive()

func _capture(filename: String) -> void:
	var tex := sv.get_texture()
	if tex != null:
		var img := tex.get_image()
		if img != null and not img.is_empty():
			img.save_png("res://tests/" + filename)
			print("CAPTURED: %s (%dx%d)" % [filename, img.get_width(), img.get_height()])
			return
	print("CAPTURE_READY: %s (headless buffer dummy)" % filename)

func _fail(msg: String) -> void:
	push_error("RUN_PHASE15_CAPTURE failed: " + msg)
	print("ERROR: " + msg)
	get_tree().quit(1)
