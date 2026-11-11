extends Node

## 文房小院 (S02_CITY_HUB) 与 P2 协同契约全量自动化测试 + 真机渲染截图套件
## 验证覆盖：
## 1. 修复 1-7：Dock 上移至 game_layer、去占位页/底栏/二次弹窗、顶栏 64px 无等级、Toast Y=72、切页收浮层
## 2. 720×514 手机横屏线框尺寸 + 52% 抽屉下滑同步 Dock
## 3. 1400×1000 平板双栏线框尺寸 + 太守条件显隐不重叠 + 3 态房间 CTA
## 4. hand.preview 明日预读小格、城池抽屉/5城/13城太守角标、S04_REPORT 首卡小院脚注直跳
## 5. 实测 /api/slice/estate、/api/slice/merit、/api/slice/estate/upgrade（含真错误与真成功）

var sv: SubViewport
var scene: Control
var frames := 0
var step := 0
var _shot_dir := ""
var _live_upgrade_mode := false
var _live_report_mode := false
var _live_me_report_ok := false

func _ready() -> void:
	print("S02_ESTATE_SUITE start")
	_shot_dir = OS.get_environment("S02_SHOT_DIR").strip_edges()
	if _shot_dir == "":
		_shot_dir = "user://s02_screenshots"
	if not _shot_dir.ends_with("/"):
		_shot_dir += "/"
	if _shot_dir.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_shot_dir))
	else:
		DirAccess.make_dir_recursive_absolute(_shot_dir)

	_live_upgrade_mode = OS.get_environment("S02_LIVE_UPGRADE") == "1"
	_live_report_mode = OS.get_environment("S02_LIVE_REPORT") == "1"

	var tut_cfg := ConfigFile.new()
	tut_cfg.set_value("tutorial", "completed", true)
	tut_cfg.save("user://tutorial_completed.cfg")

	var est_tut_cfg := ConfigFile.new()
	est_tut_cfg.set_value("estate_tutorial", "completed", true)
	est_tut_cfg.save("user://estate_tutorial.cfg")

	if not OS.has_feature("dedicated_server"):
		DisplayServer.window_set_size(Vector2i(1400, 1000))
	get_window().size = Vector2i(1400, 1000)
	get_viewport().size = Vector2i(1400, 1000)

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
		0: # 等待登录与 state 初始化
			if scene.game_layer.visible and not scene.state.is_empty() and frames > 25:
				_assert(scene.DOCK_PAGES.has("S02_CITY_HUB"), "DOCK_PAGES contains S02_CITY_HUB")
				_assert(scene.bottom_dock.get_parent() == scene.game_layer, "Fix 1: bottom_dock lives on game_layer")
				_assert(scene.bottom_dock.visible, "Fix 1: bottom_dock visible on map")

				if _live_report_mode:
					if not _assert(scene.hand_preview_codes.size() >= 2, "Live state.hand.preview returned from server: %s" % str(scene.hand_preview_codes)):
						return
					if not _assert(is_instance_valid(scene.hand_preview_panel) and scene.hand_preview_panel.visible, "Live hand.preview slot rendered without consuming cards"):
						return
					if not _assert(scene.hand_card_views.size() == 4, "Live 4 playable hand cards preserved alongside preview"):
						return
					var lr: Variant = scene.state.get("last_report", null)
					if not _assert(typeof(lr) == TYPE_DICTIONARY and int(lr.get("turn_id", 0)) > 0, "Live last_report present after turn settle"):
						return
					var tid := int(lr.get("turn_id", 1))
					scene.api.get_me_report(tid, func(ok: bool, mr: Dictionary, err: Dictionary):
						_assert(ok and mr.get("orders", []).size() == 2, "Live GET /api/slice/me/report returned 2 orders: err=%s" % str(err))
						_assert(int(mr.get("merit", {}).get("turn_total", 0)) > 0, "Live /api/slice/me/report turn_total > 0")
						_live_me_report_ok = true
					)
					scene._open_report()
					step = 20
					frames = 0
					return

				# 验证 S01_MAP hand.preview（若后端返回则直接验，再补 ["scout"] 兜底并渲染）
				if scene.hand_preview_codes.is_empty():
					scene.hand_preview_codes = ["scout"]
					scene._render_hand_cards()
				_assert(is_instance_valid(scene.hand_preview_panel) and scene.hand_preview_panel.visible, "hand.preview slot visible in hand bar")
				_assert(scene.hand_card_views.size() == 4, "4 playable hand_card_views preserved alongside preview slot")

				# 注入 5 城太守数据并打开 N2 城池抽屉验证太守显示
				var nodes: Array = scene.state.get("map", {}).get("nodes", [])
				for n in nodes:
					if str(n.get("code", "")) == "N2":
						n["governor"] = {"nickname": "青竹太守", "merit": 48}
				scene.map.setup(scene.state.get("map", {}))
				scene._open_city_drawer("N2")
				_assert(scene.city_governor_badge != null and scene.city_governor_badge.visible, "city_governor_badge visible for N2")
				_assert("太守：青竹太守" in scene.city_governor_badge.text, "city_governor_badge shows nickname")

				step = 1
				frames = 0
			elif frames > 360:
				_fail("login timeout")

		1: # 平板 S01 截图（hand.preview + 5城太守角标 + 抽屉太守）
			if frames == 12:
				_capture("screenshot_s01_tablet_map_gov.png")
				scene._toggle_city_drawer(false)
			elif frames >= 28:
				_set_viewport_size(720, 514)
				step = 2
				frames = 0

		2: # 手机 S01 截图（关抽屉以完整验收 4 手牌 + 明日预读 + 底栏 + 太守角标）
			if frames >= 10:
				_assert(is_instance_valid(scene.hand_preview_panel) and scene.hand_preview_panel.visible, "phone hand.preview slot visible")
				_assert(scene.hand_cards_bar.visible and scene.bottom_dock.visible, "phone hand bar and dock visible on S01_MAP")
				_assert(scene.bottom_dock.position.y < 514.0, "phone dock sits inside 514px viewport (y=%.1f)" % scene.bottom_dock.position.y)
				_capture("screenshot_s01_phone_hand_preview_gov.png")
				# 切到 720x514 下的 S02_CITY_HUB
				scene._open_estate_page(false)
				step = 3
				frames = 0

		3: # 等待 /api/slice/estate + /api/slice/merit 真数据返回（手机 720x514）
			if scene.current_page == "S02_CITY_HUB" and not scene.estate_page.estate_data.is_empty() and frames > 35:
				var ep = scene.estate_page
				_assert(ep.is_phone_mode, "720x514 switches EstateView to phone mode")
				_assert(absf(ep.header_bar.size.y - 64.0) <= 1.0, "Fix 3: header_bar height == 64 (got %.1f)" % ep.header_bar.size.y)
				# 确认顶栏不含 Lv. 字样（Lv 进了主卡）
				_assert(not _node_tree_contains_text(ep.header_bar, "Lv."), "Fix 3: no Lv. inside top header bar")
				# 打印实际几何便于精确诊断
				print("S02 DEBUG phone_root=%s min=%s hero=%s min=%s merit=%s min=%s room=%s min=%s" % [
					str(ep.phone_root.size), str(ep.phone_root.get_combined_minimum_size()),
					str(ep.ph_hero_panel.size), str(ep.ph_hero_panel.get_combined_minimum_size()),
					str(ep.ph_merit_card.size), str(ep.ph_merit_card.get_combined_minimum_size()),
					str(ep.ph_room_cards["study"]["panel"].size), str(ep.ph_room_cards["study"]["panel"].get_combined_minimum_size())
				])
				for k in ep.ph_room_cards["study"].keys():
					var node = ep.ph_room_cards["study"][k]
					if node is Control:
						print("  study.%s size=%s min=%s" % [k, str((node as Control).size), str((node as Control).get_combined_minimum_size())])
				_capture("screenshot_s02_phone_default.png")
				# 核对核准手机线框几何尺寸（±6px 容差兼容容器分配）
				_assert(absf(ep.ph_hero_panel.size.x - 410.0) <= 6.0 and absf(ep.ph_hero_panel.size.y - 182.0) <= 6.0,
					"Phone hero card ~410x182 (got %.1fx%.1f)" % [ep.ph_hero_panel.size.x, ep.ph_hero_panel.size.y])
				_assert(absf(ep.ph_merit_card.size.x - 276.0) <= 6.0 and absf(ep.ph_merit_card.size.y - 182.0) <= 6.0,
					"Phone merit card ~276x182 (got %.1fx%.1f)" % [ep.ph_merit_card.size.x, ep.ph_merit_card.size.y])
				_assert(ep.ph_room_cards.size() == 3, "Phone has 3 room cards")
				for rkey in ["study", "drill", "tower"]:
					var rpanel: PanelContainer = ep.ph_room_cards[rkey]["panel"]
					var sz: Vector2 = rpanel.size
					_assert(absf(sz.x - 225.0) <= 6.0 and absf(sz.y - 192.0) <= 6.0,
						"Phone room card %s ~225x192 (got %.1fx%.1f)" % [rkey, sz.x, sz.y])
				_assert(scene.bottom_dock.visible, "Fix 1: bottom_dock visible on S02_CITY_HUB")
				_assert(absf(scene.bottom_dock.size.y - 46.0) <= 1.0, "Phone dock height == 46")
				_assert(absf(scene.bottom_dock.position.y - 468.0) <= 2.0, "Phone dock sits at y=468 (got %.1f)" % scene.bottom_dock.position.y)

				# 触发真实后端升级请求（默认库军功<30触发不足报错，LIVE_UPGRADE模式则真实升级成功）
				ep.upgrade_requested.emit("study")
				step = 4
				frames = 0
			elif frames > 360:
				_fail("estate API load timeout")

		4: # 验证真实 POST /api/slice/estate/upgrade 返回 + Fix 4 Toast Y=72
			if frames >= 35:
				if not _live_upgrade_mode:
					_assert(scene.toast_panel.visible, "Insufficient merit shows toast")
					_assert(absf(scene.toast_panel.position.y - 72.0) <= 2.0,
						"Fix 4: toast baseline == 64+8=72 (got %.1f)" % scene.toast_panel.position.y)
					_assert("军功不足" in scene.toast_label.text or "军功不够" in scene.toast_label.text or "还差" in scene.toast_label.text,
						"Insufficient merit error translated: %s" % scene.toast_label.text)
					_capture("screenshot_s02_phone_toast.png")
				else:
					var rooms_live: Array = scene.estate_page.estate_data.get("rooms", [])
					var study_lvl := 0
					for rm in rooms_live:
						if str(rm.get("code", "")) == "study":
							study_lvl = int(rm.get("level", 0))
					if _assert(study_lvl >= 2, "Live POST /api/slice/estate/upgrade upgraded study to level %d" % study_lvl):
						print("LIVE_UPGRADE PASS: study_lvl=%d merit_balance=%s" % [study_lvl, str(scene.estate_page.estate_data.get("merit_balance", -1))])
						_capture("screenshot_s02_phone_live_upgraded.png")
						_finish_pass()
					return

				# 打开手机房间抽屉，验证 52% 高度 + Dock 同步下滑
				scene.estate_page.open_phone_drawer_for("study")
				step = 5
				frames = 0

		5: # 验证手机抽屉展开完成与 Fix 6 切页自动关闭浮层
			if frames >= 26:
				var ep = scene.estate_page
				_assert(ep.phone_drawer_open, "Phone room drawer opened")
				_assert(absf(ep.drawer_panel.size.y - 267.0) <= 4.0,
					"Phone drawer height ~267 (52%% of 514, got %.1f)" % ep.drawer_panel.size.y)
				_assert(scene.bottom_dock.position.y >= 512.0,
					"Bottom dock slid down out of view with drawer (y=%.1f)" % scene.bottom_dock.position.y)
				_capture("screenshot_s02_phone_drawer.png")

				# Fix 6：打开抽屉的状态下切去 S01_MAP，再切回，确认全部浮层强制关闭、Dock 归位
				scene._navigate_to("S01_MAP")
				_assert(not ep.phone_drawer_open, "Fix 6: leaving S02 force-closes phone room drawer")
				_assert(scene.bottom_dock.position.y < 512.0, "Dock restored immediately when leaving S02")
				scene._navigate_to("S02_CITY_HUB")
				step = 6
				frames = 0

		6: # 手机端军功榜浮层截图 + Fix 6 检查
			if frames == 5:
				scene.estate_page.open_leaderboard()
			elif frames >= 25:
				_assert(scene.estate_page.rank_overlay.visible, "Phone leaderboard overlay visible")
				_capture("screenshot_s02_phone_leaderboard.png")
				scene._navigate_to("S01_MAP")
				_assert(not scene.estate_page.rank_overlay.visible, "Fix 6: leaving S02 closes rank_overlay")
				scene._navigate_to("S02_CITY_HUB")
				_set_viewport_size(1400, 1000)
				step = 7
				frames = 0

		7: # 平板 1400x1000 默认态几何校验 + 太守隐藏态截图
			if frames >= 10:
				if scene.toast_panel != null:
					scene.toast_panel.visible = false
				var ep = scene.estate_page
				_assert(not ep.is_phone_mode, "1400x1000 switches EstateView to tablet mode")
				_assert(absf(ep.tb_hero_panel.size.x - 834.0) <= 12.0 and absf(ep.tb_hero_panel.size.y - 544.0) <= 12.0,
					"Tablet hero ~834x544 (got %.1fx%.1f)" % [ep.tb_hero_panel.size.x, ep.tb_hero_panel.size.y])
				_assert(ep.tb_room_cards.size() == 3, "Tablet has 3 room cards")
				for rkey in ["study", "drill", "tower"]:
					var rsz: Vector2 = ep.tb_room_cards[rkey]["panel"].size
					_assert(absf(rsz.x - 267.0) <= 10.0 and absf(rsz.y - 276.0) <= 10.0,
						"Tablet room card %s ~267x276 (got %.1fx%.1f)" % [rkey, rsz.x, rsz.y])
				_assert(not ep.tb_gov_card.visible, "Tablet governor card hidden when governorships empty")
				_assert(absf(scene.bottom_dock.position.y - 940.0) <= 2.0, "Tablet dock sits at bottom y=940 (got %.1f)" % scene.bottom_dock.position.y)
				_capture("screenshot_s02_tablet_default.png")

				# 注入富状态检验：Lv.2 小院 + 3态房间 CTA + 太守显隐不重叠 + 势力足迹 + 周榜名次
				var mock_estate := {
					"home_node": {"code": "A_START", "name": "青竹书院", "faction": "bi"},
					"level": 2,
					"banner": {"label": "文轩雅舍"},
					"merit_total": 120,
					"merit_spent": 85,
					"merit_balance": 35,
					"next_level_at": 150,
					"rooms": [
						{"code": "study", "name": "书房", "icon": "📜", "level": 1, "max_level": 3, "effect": "可查看明日预读 1 张", "next_effect": "可查看明日预读 2 张 + 情报摘要", "next_cost": 30},
						{"code": "drill", "name": "练兵场", "icon": "⚔", "level": 2, "max_level": 3, "effect": "解锁第 2 套编成预设", "next_effect": "解锁第 3 套编成预设 + 自动补齐", "next_cost": 80},
						{"code": "tower", "name": "望楼", "icon": "🔭", "level": 3, "max_level": 3, "effect": "守城警示与哨探标记全开", "next_effect": null, "next_cost": null},
					],
					"influence": [
						{"code": "A_START", "name": "青竹书院", "count": 4, "merit": 42},
						{"code": "N1", "name": "渡口前哨", "count": 2, "merit": 25},
					],
					"governorships": [
						{"code": "A_START", "name": "青竹书院", "merit": 42},
					],
				}
				var mock_merit := {
					"week_no": 1,
					"me": {"rank": 2, "week_rank": 1, "total": 120, "week": 67},
					"top": [
						{"rank": 1, "nickname": "墨池大师", "faction": "mo", "total": 145},
						{"rank": 2, "nickname": "青竹学子", "faction": "bi", "total": 120},
						{"rank": 3, "nickname": "砚台居士", "faction": "yan", "total": 98},
					],
					"week_top": [
						{"rank": 1, "nickname": "青竹学子", "faction": "bi", "total": 67},
						{"rank": 2, "nickname": "墨池大师", "faction": "mo", "total": 54},
					],
				}
				ep.set_estate_state(mock_estate, scene.state.get("me", {}), mock_merit)
				ep.set_merit_leaderboard(mock_merit)
				ep.tb_room_cards["study"]["cta_btn"].pressed.emit()
				step = 8
				frames = 0

		8: # 验证太守卡显示无重叠、3态 CTA 与升级动效，然后截图平板完整态 + 军功榜 + 教学
			if frames == 8:
				var ep = scene.estate_page
				_assert(ep.tb_gov_card.visible, "Tablet governor card visible when governorships populated")
				var gov_rect: Rect2 = ep.tb_gov_card.get_global_rect()
				var det_rect: Rect2 = ep.tb_detail_card.get_global_rect()
				_assert(gov_rect.end.y <= det_rect.position.y + 2.0,
					"Tablet governor card and detail card do not overlap (%.1f <= %.1f)" % [gov_rect.end.y, det_rect.position.y])
				_assert(det_rect.size.y >= 340.0, "Tablet detail card stays substantial when gov visible (h=%.1f)" % det_rect.size.y)
				_assert("升级 · 30" in ep.tb_room_cards["study"]["cta_btn"].text, "Room study affordable CTA shows cost 30")
				_assert("还差 45" in ep.tb_room_cards["drill"]["cta_btn"].text, "Room drill unaffordable CTA shows gap 45")
				_assert("已满级" in ep.tb_room_cards["tower"]["cta_btn"].text, "Room tower max CTA shows maxed")
				_assert(not ep.tb_detail_btn.disabled, "Tablet detail confirm button directly actionable (no second modal)")
				_capture("screenshot_s02_tablet_gov_states.png")

				# 模拟一次升级成功并验证军功滚字+闪光
				var after_upgrade := {
					"home_node": {"code": "A_START", "name": "青竹书院", "faction": "bi"},
					"level": 2,
					"banner": {"label": "文轩雅舍"},
					"merit_total": 120,
					"merit_spent": 115,
					"merit_balance": 5,
					"next_level_at": 150,
					"rooms": [
						{"code": "study", "name": "书房", "icon": "📜", "level": 2, "max_level": 3, "effect": "可查看明日预读 2 张 + 情报摘要", "next_effect": "预读+推演辅助提示", "next_cost": 80},
						{"code": "drill", "name": "练兵场", "icon": "⚔", "level": 2, "max_level": 3, "effect": "解锁第 2 套编成预设", "next_effect": "解锁第 3 套编成预设 + 自动补齐", "next_cost": 80},
						{"code": "tower", "name": "望楼", "icon": "🔭", "level": 3, "max_level": 3, "effect": "守城警示与哨探标记全开", "next_effect": null, "next_cost": null},
					],
					"influence": [
						{"code": "A_START", "name": "青竹书院", "count": 4, "merit": 42},
						{"code": "N1", "name": "渡口前哨", "count": 2, "merit": 25},
					],
					"governorships": [{"code": "A_START", "name": "青竹书院", "merit": 42}],
				}
				ep.on_upgrade_result(true, after_upgrade, {})
				ep.flash_merit_card()
			elif frames == 38:
				_assert(int(scene.estate_page.estate_data.get("merit_balance", -1)) == 5, "Upgrade result updated merit_balance to 5")
				scene.estate_page.open_leaderboard()
			elif frames == 46:
				if scene.toast_panel != null:
					scene.toast_panel.visible = false
				_capture("screenshot_s02_tablet_leaderboard.png")
				scene.estate_page.rank_overlay.visible = false
				scene.estate_page.show_tutorial(true)
			elif frames == 54:
				_assert(scene.estate_page.tut_overlay.visible, "Estate tutorial overlay opens on ? button")
				_capture("screenshot_s02_tablet_tutorial.png")
				scene.estate_page.open_leaderboard()
				_assert(scene.estate_page.tut_overlay.visible and scene.estate_page.rank_overlay.visible,
					"Both tutorial and leaderboard open before Fix 6 exit check")
				scene._navigate_to("S01_MAP")
				_assert(not scene.estate_page.tut_overlay.visible and not scene.estate_page.rank_overlay.visible,
					"Fix 6: leaving S02 closes both tutorial and leaderboard overlays")
				step = 9
				frames = 0

		9: # S04_REPORT 个人战报首卡（me_report 顺序 + 邸报 + 军功周榜 + 小院脚注 + [去看看]）
			if frames == 2:
				if scene.toast_panel != null:
					scene.toast_panel.visible = false
				var live_tid := int(scene.state.get("turn", {}).get("id", 1))
				scene.api.get_me_report(live_tid, func(ok: bool, _data: Dictionary, err: Dictionary):
					var err_code := str(err.get("code", ""))
					_assert(ok or err_code == "REPORT_NOT_READY", "Live GET /api/slice/me/report route responded: ok=%s code=%s" % [str(ok), err_code])
				)
				scene.merit_summary_data["week_rank"] = 5
				scene.state["bulletin"] = {"turn_id": 2, "choice": "ram"}
				scene._navigate_to("S04_REPORT")
				scene._show_report({
					"turn": {"id": 2, "turn_no": 2, "settled_at": "2026-11-11 21:00:00"},
					"report": {
						"headline": "【决战头条】第 2 候推演战局已定",
						"summary": {"occupied": []},
						"node_changes": [],
						"reports": [],
					},
					"me": {
						"nickname": "青竹学子",
						"pet_name": "青竹灵宠",
						"merit": {"turn_total": 65},
					},
					"me_report": {
						"turn_no": 2,
						"orders": [
							{"slot": 0, "card": "night_raid", "node_code": "N1", "node_name": "松风渡", "role": "vanguard", "damage": 300.6, "wall_damage": 120.0, "troops_lost": 80.0, "contribution": 0.33, "captured": true},
							{"slot": 1, "card": "fortify", "node_code": "N2", "node_name": "清溪营", "role": "support", "damage": 110.2, "wall_damage": 0.0, "troops_lost": 20.0, "contribution": 0.12, "captured": false},
							{"slot": 2, "card": "scout", "node_code": "N6", "node_name": "洛阳", "role": "scout", "damage": 0.0, "wall_damage": 0.0, "troops_lost": 0.0, "contribution": 0.0, "captured": false},
						],
						"damage": 410.8,
						"wall_damage": 120.0,
						"merit": {"turn_total": 65, "items": [{"kind": "capture", "label": "破城", "amount": 40}]},
						"highlight": "你的队伍参与了松风渡的破城，贡献 33%",
					},
				})
			elif frames == 12:
				var body: String = scene.report_my_text.text
				var i0 := body.find("我今天下了 3 令")
				var i1 := body.find("松风渡")
				var i2 := body.find("伤害 301 · 破墙 120")
				var i3 := body.find("洛阳")
				var i4 := body.find("邸报：器械")
				var i5 := body.find("军功 +65 · 本周第 5")
				_assert(i0 >= 0 and i1 > i0 and i2 > i1 and i3 > i2 and i4 > i3 and i5 > i4,
					"S04 Card #1 renders me_report lines in exact sequence: %s" % body)
				_assert("先锋" in body and "贡献 33%" in body and "侦察" in body,
					"S04 Card #1 displays role, contribution and scout label")
				_assert(not ("伤害 0" in body), "Non-combat scout order omits 0 damage line")
				_assert(scene.report_estate_row != null and scene.report_estate_row.visible, "S04_REPORT Card #1 footer estate row visible")
				_assert("+65" in scene.report_estate_lbl.text and "文房小院" in scene.report_estate_lbl.text,
					"S04_REPORT footer displays '+65 军功': %s" % scene.report_estate_lbl.text)
				_capture("screenshot_s04_tablet_report_footer.png")
				_set_viewport_size(720, 514)
			elif frames == 20:
				_capture("screenshot_s04_phone_report_footer.png")
				scene.report_estate_btn.pressed.emit()
				_assert(scene.current_page == "S02_CITY_HUB", "Clicking [去看看] jumps straight to S02_CITY_HUB")
				step = 10
				frames = 0

		10: # 验证 13 城 Map12Map 太守角标绘制（平板+手机渲染无异常）
			step = 11
			_verify_map12_governor()

		20: # 实测已结算回合的真实 GET /api/slice/report + /api/slice/me/report + state.hand.preview
			if _live_me_report_ok and scene.current_page == "S04_REPORT" and "我今天下了 2 令" in scene.report_my_text.text and frames > 20:
				var body: String = scene.report_my_text.text
				_assert("邸报：" in body, "Live report Card #1 renders bulletin line")
				_assert("军功 +" in body, "Live report Card #1 renders merit line")
				_assert("文房小院 +" in scene.report_estate_lbl.text, "Live report footer renders estate merit: %s" % scene.report_estate_lbl.text)
				_capture("screenshot_s04_live_settled.png")
				print("LIVE_REPORT PASS:\n%s" % body)
				_finish_pass()
			elif frames > 300:
				_fail("live report timeout (page=%s ok=%s text=%s)" % [scene.current_page, str(_live_me_report_ok), scene.report_my_text.text])


func _verify_map12_governor() -> void:
	var map12_script = load("res://Map12Map.gd")
	_assert(map12_script != null, "Map12Map.gd loads cleanly")
	var test_sv := SubViewport.new()
	test_sv.size = Vector2i(1400, 1000)
	test_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(test_sv)

	var bg := ColorRect.new()
	bg.color = Color("#ede2ce")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	test_sv.add_child(bg)

	var m12: Control = map12_script.new()
	m12.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	test_sv.add_child(m12)

	var fake_nodes: Array = [
		{"code": "luoyang", "name": "洛阳", "faction": "bi", "governor": {"nickname": "洛阳太守"}},
		{"code": "hanzhong", "name": "汉中", "faction": "mo", "governor": {"nickname": "汉中守将"}},
		{"code": "changan", "name": "长安", "faction": "neutral"},
	]
	m12.setup({"nodes": fake_nodes})
	var luo: Dictionary = m12.node_by_code("luoyang")
	_assert(str(luo.get("name", "")) != "", "Map12Map node_by_code returns valid entry")
	m12.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_sv(test_sv, "screenshot_map12_tablet_gov.png")
	test_sv.size = Vector2i(720, 514)
	m12.size = Vector2(720, 514)
	m12.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_sv(test_sv, "screenshot_map12_phone_gov.png")
	test_sv.queue_free()
	_finish_pass()


func _node_tree_contains_text(root: Node, needle: String) -> bool:
	if root == null:
		return false
	if root is Label and needle in (root as Label).text:
		return true
	if root is Button and needle in (root as Button).text:
		return true
	if root is RichTextLabel and needle in (root as RichTextLabel).text:
		return true
	for ch in root.get_children():
		if _node_tree_contains_text(ch, needle):
			return true
	return false


func _set_viewport_size(w: int, h: int) -> void:
	if not OS.has_feature("dedicated_server"):
		DisplayServer.window_set_size(Vector2i(w, h))
	get_window().size = Vector2i(w, h)
	get_viewport().size = Vector2i(w, h)
	if sv != null:
		sv.size = Vector2i(w, h)
	scene.size = Vector2(w, h)
	scene._layout_responsive()


func _capture(filename: String) -> void:
	_capture_sv(sv, filename)


func _capture_sv(viewport: SubViewport, filename: String) -> void:
	var tex := viewport.get_texture()
	if tex != null:
		var img := tex.get_image()
		if img != null and not img.is_empty():
			img.save_png(_shot_dir + filename)
			print("CAPTURED: %s (%dx%d)" % [_shot_dir + filename, img.get_width(), img.get_height()])
			return
	print("CAPTURE_READY: %s (headless buffer dummy)" % filename)


func _assert(cond: bool, label: String) -> bool:
	if not cond:
		_fail("ASSERTION FAILED: " + label)
		return false
	print("S02 [PASS] " + label)
	return true


func _fail(msg: String) -> void:
	step = 99
	push_error("S02_ESTATE_SUITE failed: " + msg)
	print("ERROR: " + msg)
	get_tree().quit(1)


func _finish_pass() -> void:
	print("S02_ESTATE_SUITE PASS")
	step = 99
	get_tree().quit(0)
