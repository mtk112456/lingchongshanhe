extends Node

## P0 全流程决策专项验收套件（真机双分辨率渲染 + 真实后端联调）
## 覆盖：
## 1. 720x514 & 1400x1000 城池抽屉打开时手牌常显且互不遮挡 + 战前军议首层3项/展开/300ms去抖/己方城不预估
## 2. 底部 5 Tab（沙盘/编成/日报+四榜+回放子页/小院/赛季）均可到达真实页面
## 3. next-turn({from_turn_id}), recharge({points}+jade_balance), composition(changes_allowed)
## 4. 晨报仅在 last_report.turn_id > 已读 时自动轻弹一次 + 关掉去红点 + 顶栏按钮可回看 + 邸报2选1
## 5. S10_SEASON 真接口（无“第1周”假文案）+ 终局颁奖页渲染

var sv: SubViewport
var scene: Control
var frames := 0
var step := 0
var _shot_dir := ""
var _first_login_done := false
var _turn1_id := 0
var _saw_morning_once := false

func _ready() -> void:
	print("P0_FLOW_VERIFY start")
	_shot_dir = OS.get_environment("P0_SHOT_DIR").strip_edges()
	if _shot_dir == "":
		_shot_dir = "user://p0_screenshots"
	if not _shot_dir.ends_with("/"):
		_shot_dir += "/"
	DirAccess.make_dir_recursive_absolute(_shot_dir)

	# 预先清除已读记录 & 跳过首次3步教学干扰多回合晨报验证
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://morning_report_seen.cfg"))
	var tut_cfg := ConfigFile.new()
	tut_cfg.set_value("tutorial", "completed", true)
	tut_cfg.save("user://tutorial_completed.cfg")

	if not OS.has_feature("dedicated_server"):
		DisplayServer.window_set_size(Vector2i(720, 514))
	get_window().size = Vector2i(720, 514)
	get_viewport().size = Vector2i(720, 514)

	sv = SubViewport.new()
	sv.size = Vector2i(720, 514)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.gui_embed_subwindows = true
	add_child(sv)

	scene = load("res://Slice.tscn").instantiate()
	sv.add_child(scene)
	scene.size = Vector2(720, 514)
	scene._layout_responsive()

	scene.url_edit.text = "http://127.0.0.1:8080"
	scene.name_edit.text = "青竹一"
	scene.pass_edit.text = "slice2026"
	scene._on_login(false)

func _process(_delta: float) -> void:
	frames += 1

	match step:
		0: # 登录第1回合（无昨日战报），验证不乱弹晨报、5 Tab 结构正确
			if scene.game_layer.visible and not scene.state.is_empty() and frames > 25:
				_turn1_id = scene._turn_id()
				_assert(scene.DOCK_PAGES == ["S01_MAP", "S03_ARMY", "S04_REPORT", "S02_CITY_HUB", "S10_SEASON"], "Bottom dock has exact 5 new tabs")
				_assert(not scene.dock_tab_buttons.has("S05_REPLAY"), "Standalone S05_REPLAY tab removed")
				_assert(scene.morning_modal != null and not scene.morning_modal.visible, "Day 1 without last_report does not auto-popup morning modal")

				# 验证已无旧 1 令UI节点
				_assert(scene.get("order_confirm_overlay") == null, "Legacy order_confirm_overlay removed")
				_assert(scene.get("city_action_defend_btn") == null, "Legacy city_action_defend_btn removed")

				# 720x514 打开中立据点 N1 抽屉：验证手牌不隐藏 & 抽屉与手牌矩形不重叠
				scene._open_city_drawer("N1")
				step = 1
				frames = 0
			elif frames > 400:
				_fail("login timeout")

		1: # 等首轮 forecast 返回后，测试 play_card -> 300ms 去抖重算
			if frames > 35:
				_assert(scene.city_drawer.visible and scene.is_drawer_open, "720x514 city_drawer opened")
				_assert(scene.hand_cards_bar.visible, "720x514 hand_cards_bar stays VISIBLE when city_drawer is open")
				var drawer_rect := Rect2(scene.city_drawer.position, scene.city_drawer.size)
				var hand_rect := Rect2(scene.hand_cards_bar.position, scene.hand_cards_bar.size)
				print("720x514 GEO drawer=%s hand=%s" % [str(drawer_rect), str(hand_rect)])
				_assert(drawer_rect.position.y + drawer_rect.size.y <= hand_rect.position.y + 2.0,
					"720x514 drawer does not cover hand_cards_bar (drawer bottom=%.1f, hand top=%.1f)" % [drawer_rect.position.y + drawer_rect.size.y, hand_rect.position.y])
				_assert(hand_rect.position.y + hand_rect.size.y <= 514.0, "720x514 hand bar stays inside 514px viewport")

				# 出 1 张队伍卡触发 300ms 去抖预估
				var cards: Array = scene.state.get("hand", {}).get("cards", [])
				var team_card := ""
				for c in cards:
					var cs := str(c)
					if cs != "fire_attack" and cs != "scout" and cs != "feint":
						team_card = cs
						break
				if team_card == "" and not cards.is_empty():
					team_card = str(cards[0])
				scene.play_card(0, team_card, "N1", 1, "front")
				step = 2
				frames = 0
			elif frames > 300:
				_fail("wait initial forecast timeout")

		2: # 等去抖预估完成，验证首层3项 + 展开详情 + 截取 720x514 抽屉与手牌同屏图
			if scene.state.get("card_orders", []).size() >= 1 and frames > 45 and not scene._last_forecast_loading:
				_assert("本令做什么" in scene.city_forecast_summary_lbl.text, "Forecast first layer shows 本令做什么")
				_assert("最大风险" in scene.city_forecast_summary_lbl.text, "Forecast first layer shows 最大风险")
				_assert("结果方向" in scene.city_forecast_summary_lbl.text, "Forecast first layer shows 结果方向")
				_capture("p0_phone_720x514_drawer_hand.png")

				# 验证己方城 A_START 不出进攻预估
				scene._open_city_drawer("A_START")
				step = 3
				frames = 0
			elif frames > 400:
				_fail("forecast recalc timeout")

		3: # 己方城不显示进攻预估；随后切 1400x1000 测试平铺同屏 + 展开预估详情
			if frames > 30 and not scene._last_forecast_loading:
				_assert("这是己方城，出令 = 驻守" in scene.city_forecast_summary_lbl.text, "Own city does not show attack forecast")
				_assert(not scene.city_forecast_toggle_btn.visible, "Own city hides attack detail toggle")

				_set_viewport_size(1400, 1000)
				scene._open_city_drawer("N1")
				scene.city_forecast_expanded = true
				scene._apply_forecast_expand_state()
				scene._layout_responsive()
				step = 4
				frames = 0
			elif frames > 300:
				_fail("own city forecast timeout")

		4: # 1400x1000 截图与重叠检验（包括 city_drawer 实显 alpha==1 验证 + 方案B文案校验）
			if frames > 35 and not scene._last_forecast_loading:
				_assert(scene.city_drawer.visible and scene.city_drawer.modulate.a >= 0.99, "1400x1000 city_drawer fully visible (alpha=%.2f)" % scene.city_drawer.modulate.a)
				_assert(scene.hand_cards_bar.visible and scene.bottom_dock.visible, "1400x1000 drawer open preserves hand bar & dock")
				_assert("/ 1650" in scene.city_forecast_detail_lbl.text, "Forecast detail uses 1650 wall base: %s" % scene.city_forecast_detail_lbl.text)
				_assert(not ("30%" in scene.city_forecast_advice_lbl.text), "Forecast advice contains no stale 30%% copy: %s" % scene.city_forecast_advice_lbl.text)
				_assert(scene._normalize_balance_copy("支援 +30%") == "每人 +2%，上限 +15%", "Normalize 支援 +30%")
				_assert(scene._normalize_balance_copy("上限 +30%") == "每人 +2%，上限 +15%", "Normalize 上限 +30%")
				_assert(scene._normalize_balance_copy("叫同阵营支援，每人 +2%，上限 +30%。") == "叫同阵营支援，每人 +2%，上限 +15%。", "Normalize 每人 +2%，上限 +30%")
				_assert(scene._normalize_balance_copy("支援 30%") == "支援 15%", "Normalize 支援 30%")
				_assert(scene._normalize_balance_copy("带火攻可让器械攻墙 +50%。") == "带火攻可让器械攻墙 +60%。", "Normalize 火攻 +50% -> +60%")
				var d_rect := Rect2(scene.city_drawer.position, scene.city_drawer.size)
				var h_rect := Rect2(scene.hand_cards_bar.position, scene.hand_cards_bar.size)
				_assert(d_rect.position.y + d_rect.size.y <= h_rect.position.y + 2.0, "1400x1000 drawer clears hand_cards_bar")
				_capture("p0_tablet_1400x1000_drawer_hand.png")

				# 测试 5 Tab 全可到达 + 修复的 recharge({points}) + 编成 changes_allowed + 邸报
				scene._toggle_city_drawer(false)
				scene._open_army_page()
				step = 5
				frames = 0

		5: # S03_ARMY: 邸报2选1 + 编成 changes_allowed
			if scene.current_page == "S03_ARMY" and not scene.bulletin_data.is_empty() and frames > 25:
				var b_opts: Array = scene.bulletin_data.get("options", [])
				_assert(b_opts.size() == 2, "Bulletin loaded 2 options on S03_ARMY header")
				_assert("本周可改" in scene.army_header_sub_lbl.text, "S03_ARMY header displays dynamic changes_allowed")
				var first_b := str(b_opts[0].get("code", "grain"))
				scene._choose_bulletin_choice(first_b)

				# 测试 recharge 修复：发送 points=2
				var rech_ok := false
				scene.api.recharge(2, scene._new_key("p0rech"), func(ok: bool, data: Dictionary, err: Dictionary):
					_assert(ok, "recharge({points:2}) succeeds: %s" % str(err))
					var w_after: Dictionary = data.get("wallet", {})
					_assert(int(w_after.get("jade_balance", 0)) >= 20, "wallet.jade_balance updated >= 20")
				)
				step = 6
				frames = 0
			elif frames > 300:
				_fail("S03_ARMY bulletin load timeout")

		6: # 打开 S10_SEASON 真接口（无“第 1 周”假文案）并切换到教师结算第1回合 + next-turn(from_turn_id)
			if frames > 30:
				scene._open_season_page()
				step = 7
				frames = 0

		7: # 等 season + season_history 加载
			if scene.current_page == "S10_SEASON" and not scene.season_data.is_empty() and not scene.season_history_data.is_empty() and frames > 20:
				_assert("四候赛季" not in scene.season_page.header_sub_lbl.text, "Season header has real data")
				_assert("第 1 周 · 第 1 / 28 候" in scene.season_page.header_sub_lbl.text, "Season header displays real Turn/Week: %s" % scene.season_page.header_sub_lbl.text)
				_capture("p0_tablet_season_live.png")

				# 切换教师账号，完成锁令 -> 结算 -> next-turn({from_turn_id})
				scene._logout_local("教师结算")
				scene.name_edit.text = "teacher"
				scene.pass_edit.text = "teacher2026"
				scene._on_login(true)
				step = 8
				frames = 0
			elif frames > 300:
				_fail("S10_SEASON live load timeout")

		8: # 教师锁令
			if scene.game_layer.visible and str(scene.me.get("role", "")) == "teacher" and frames > 15:
				scene._teacher_lock()
				step = 9
				frames = 0
			elif frames > 300:
				_fail("teacher login timeout")

		9: # 教师结算（优先 card_settle 写战报与 last_report）
			if str(scene.state.get("turn", {}).get("status", "")) == "locked" and frames > 15:
				scene.api.card_settle(_turn1_id, func(ok: bool, _d: Dictionary, err: Dictionary):
					_assert(ok, "teacher card_settle succeeds: %s" % str(err))
					scene._refresh_state()
				)
				step = 10
				frames = 0
			elif frames > 300:
				_fail("teacher lock timeout")

		10: # 教师调用修复后的 _teacher_next() ({from_turn_id}) 开启第2回合
			if str(scene.state.get("turn", {}).get("status", "")) == "settled" and frames > 20:
				scene._teacher_next()
				step = 11
				frames = 0
			elif frames > 300:
				_fail("teacher settle timeout")

		11: # 验证开启了第 2 回合，切回学生账号验证“晨报只自动弹一次 + 红点消失 + 可回看”
			if int(scene.state.get("turn", {}).get("turn_no", 1)) == 2 and str(scene.state.get("turn", {}).get("status", "")) == "open" and frames > 15:
				print("P0 [PASS] next-turn({from_turn_id}) opened Turn 2 cleanly!")
				scene._logout_local("学生第2天上线")
				scene.name_edit.text = "青竹一"
				scene.pass_edit.text = "slice2026"
				scene._on_login(false)
				step = 12
				frames = 0
			elif frames > 300:
				_fail("teacher next-turn({from_turn_id}) timeout")

		12: # 验证第 2 天第一次登录自动弹出晨报 + 顶栏红点亮起 + 等 me_report 加载完再截图
			if scene.game_layer.visible and scene.morning_modal != null and scene.morning_modal.visible and not ("同步中" in scene.morning_modal._me_line_lbl.text) and frames > 30:
				_saw_morning_once = true
				_assert(scene.morning_red_dot != null and scene.morning_red_dot.visible, "Unread morning red dot visible while modal first opens")
				_assert(scene.morning_modal._hero_tex_rect != null and scene.morning_modal._hero_tex_rect.visible, "Morning modal upper hero art visible")
				if scene.morning_modal._hero_atlas != null and scene.morning_modal._hero_atlas.region.size.y > 0.0:
					var h_sz: Vector2 = scene.morning_modal._hero_tex_rect.size
					var h_reg: Rect2 = scene.morning_modal._hero_atlas.region
					_assert(absf((h_sz.x / maxf(1.0, h_sz.y)) - (h_reg.size.x / h_reg.size.y)) < 0.03, "Tablet morning modal hero preserves original aspect ratio (no stretching)")
				_capture("p0_tablet_morning_modal.png")
				_set_viewport_size(720, 514)
				step = 13
				frames = 0
			elif frames > 400:
				_fail("auto morning report did not pop on Turn 2 first login")

		13: # 720x514 下晨报截图 -> 关闭标记已读 -> 验证红点消失
			if frames > 15:
				if scene.morning_modal._hero_atlas != null and scene.morning_modal._hero_atlas.region.size.y > 0.0:
					var ph_sz: Vector2 = scene.morning_modal._hero_tex_rect.size
					var ph_reg: Rect2 = scene.morning_modal._hero_atlas.region
					_assert(absf((ph_sz.x / maxf(1.0, ph_sz.y)) - (ph_reg.size.x / ph_reg.size.y)) < 0.03, "Phone morning modal AtlasTexture region preserves original aspect ratio")
				_capture("p0_phone_morning_modal.png")
				scene.morning_modal.close_and_mark_read()
				_assert(not scene.morning_modal.visible, "morning modal dismissed")
				_assert(not scene.morning_red_dot.visible, "morning red dot cleared after dismiss")

				# 模拟当天再次重登：不应再次自动弹出！
				scene._logout_local("同日重登")
				scene.name_edit.text = "青竹一"
				scene.pass_edit.text = "slice2026"
				scene._on_login(false)
				step = 14
				frames = 0

		14: # 重登后确认晨报没有二次自动弹出，但点击顶部晨报按钮仍可手动回看
			if scene.game_layer.visible and not scene.state.is_empty() and frames > 35:
				_assert(not scene.morning_modal.visible, "Morning modal does NOT auto-popup a second time on same turn_id")
				_assert(not scene.morning_red_dot.visible, "Red dot stays hidden on re-login")
				scene._open_morning_report(true)
				_assert(scene.morning_modal.visible, "Top HUD morning button still re-opens morning report")
				scene.morning_modal.close_and_mark_read()

				# 验证 S04_REPORT 个人战报 + 四榜 + 嵌入回放子页
				_set_viewport_size(1400, 1000)
				scene._open_report()
				step = 15
				frames = 0
			elif frames > 300:
				_fail("re-login timeout")

		15: # S04_REPORT 含四榜 + 切换嵌入回放子页
			if scene.current_page == "S04_REPORT" and frames > 35:
				_assert("先锋榜" in scene.report_boards_text.text and "守城榜" in scene.report_boards_text.text, "S04_REPORT renders Four Boards")
				_capture("p0_tablet_report_four_boards.png")
				scene._open_replay()
				step = 16
				frames = 0
			elif frames > 300:
				_fail("S04_REPORT load timeout")

		16: # 验证嵌入回放子页 + 验证 S10 终局颁奖状态
			if scene.report_replay_box != null and scene.report_replay_box.visible and scene.replay_turn_select.item_count >= 1 and frames > 25:
				_assert(scene.current_page == "S04_REPORT", "Replay lives inside S04_REPORT sub-tab")
				_assert(scene.replay_dialog.visible, "replay_dialog compatible visibility holds")
				_capture("p0_tablet_report_replay_subtab.png")

				# 验证 S10 终局颁奖态渲染（直接切到 S10 并写入 season_over=true / changan winner，避免异步覆盖）
				scene._navigate_to("S10_SEASON")
				var mock_s: Dictionary = scene.season_data.duplicate(true)
				mock_s["week"] = 4
				mock_s["turn_no"] = 24
				mock_s["days_left"] = 4
				mock_s["season_over"] = true
				mock_s["changan"] = {"node_code": "changan", "name": "长安", "owner": "bi", "owner_name": "笔", "morale": 5, "morale_cap": 5}
				mock_s["factions"] = [
					{"code": "bi", "name": "笔", "cities": 6, "morale": 12},
					{"code": "mo", "name": "墨", "cities": 4, "morale": 6},
					{"code": "yan", "name": "砚", "cities": 2, "morale": 3},
					{"code": "zhi", "name": "纸", "cities": 1, "morale": 1},
				]
				mock_s["winner"] = {"code": "bi", "name": "笔", "reason": "changan", "cities": 6, "morale": 12}
				scene.season_page.set_season_data(mock_s, scene.season_history_data, {"total": 120, "rank": 1}, {"status": "finished"}, scene.me)
				step = 17
				frames = 0
			elif frames > 300:
				_fail("embedded replay load timeout")

		17:
			if scene.current_page == "S10_SEASON" and scene.season_page.award_card.visible and frames > 15:
				_capture("p0_tablet_season_award.png")
				# 进入新增三张 GPT 美术图实机验图（1400x1000 & 720x514）：先测首次第1步引导图卡
				AudioManager.is_reduced_motion = true
				scene._navigate_to("S01_MAP")
				scene._start_tutorial()
				step = 18
				frames = 0
			elif frames > 200:
				_fail("season award page timeout")

		18: # 1400x1000 验证首次3步教学第1步（first_order_city_card_guide + 先点城/再选牌 + 非全屏 + 减少动效无视差）
			if frames > 16 and scene.tutorial_overlay.visible and scene.tutorial_step == 1:
				print("1400x1000 tut box=", scene.tutorial_box.size, " img=", scene.tutorial_img.size, " reg=", scene.tutorial_atlas.region)
				_assert(scene.tutorial_img.visible and scene.tutorial_atlas != null and scene.tutorial_atlas.atlas != null, "1400x1000 step1 uses first_order_city_card_guide AtlasTexture")
				_assert(scene.tutorial_tag_city.visible and scene.tutorial_tag_card.visible, "1400x1000 step1 shows 先点城 & 再选牌 tags")
				_assert(scene.tutorial_box.size.x < 1400.0 * 0.60 and scene.tutorial_box.size.y < 1000.0 * 0.25, "1400x1000 step1 guide is compact non-fullscreen")
				_assert(scene.tutorial_tag_card.size.x < 100.0 and scene.tutorial_tag_city.size.x < 100.0, "1400x1000 step1 overlay stamps stay compact badges")
				_assert(absf(scene.tutorial_parallax_px) < 0.01, "Reduced motion disables tutorial parallax")
				var t_sz: Vector2 = scene.tutorial_img.size
				var t_reg: Rect2 = scene.tutorial_atlas.region
				_assert(absf((t_sz.x / maxf(1.0, t_sz.y)) - (t_reg.size.x / t_reg.size.y)) < 0.03, "1400x1000 tutorial art keeps aspect ratio")
				_capture("p0_tablet_tutorial_step1.png")
				_set_viewport_size(720, 514)
				step = 19
				frames = 0
			elif frames > 300:
				_fail("1400x1000 tutorial step1 timeout")

		19: # 720x514 验证首次3步教学第1步（手机端 AtlasTexture region 不拉伸、不挡沙盘与手牌）
			if frames > 16:
				print("720x514 tut box=", scene.tutorial_box.size, " img=", scene.tutorial_img.size, " reg=", scene.tutorial_atlas.region)
				_assert(scene.tutorial_box.size.x < 720.0 * 0.72 and scene.tutorial_box.size.y < 514.0 * 0.30, "720x514 step1 guide compact, does not dominate map")
				_assert(scene.tutorial_tag_city.visible and scene.tutorial_tag_card.visible, "720x514 step1 tags visible")
				var pt_sz: Vector2 = scene.tutorial_img.size
				var pt_reg: Rect2 = scene.tutorial_atlas.region
				_assert(absf((pt_sz.x / maxf(1.0, pt_sz.y)) - (pt_reg.size.x / pt_reg.size.y)) < 0.03, "720x514 tutorial AtlasTexture keeps aspect ratio")
				_capture("p0_phone_tutorial_step1.png")
				scene._complete_tutorial()
				scene._open_estate_page(false)
				step = 20
				frames = 0
			elif frames > 300:
				_fail("720x514 tutorial step1 timeout")

		20: # 720x514 验证文房小院 estate_home_base.png 裁切保门牌/书案/望楼 + 无拉伸 + 减少动效无视差
			if scene.current_page == "S02_CITY_HUB" and not scene.estate_page.estate_data.is_empty() and frames > 30:
				var ep = scene.estate_page
				var mock_gov: Dictionary = ep.estate_data.duplicate(true)
				mock_gov["level"] = 2
				mock_gov["governorships"] = [{"code": "A_START", "name": "云麓关", "merit": 48}]
				ep.set_estate_state(mock_gov, scene.me)
				step = 21
				frames = 0
			elif frames > 300:
				_fail("S02 estate load timeout")

		21:
			if frames > 14:
				var ph_c = scene.estate_page.ph_hero_canvas
				_assert(ph_c._tex != null and ph_c._art_rect.visible, "720x514 estate_home_base.png rendered")
				var ph_reg: Rect2 = ph_c._current_region
				_assert(ph_reg.position.x <= 24.0 and ph_reg.position.x + ph_reg.size.x >= 1350.0, "Phone estate region preserves left signboard, study, and watchtower")
				_assert(absf((ph_c._art_draw_size.x / maxf(1.0, ph_c._art_draw_size.y)) - (ph_reg.size.x / ph_reg.size.y)) < 0.02, "Phone estate art keeps aspect ratio")
				_assert(absf(ph_c._parallax_px) < 0.01, "Reduced motion disables phone estate parallax")
				_capture("p0_phone_estate_art.png")
				_set_viewport_size(1400, 1000)
				step = 22
				frames = 0

		22: # 1400x1000 验证平板文房小院主图完整保留+太守旗代码叠印
			if frames > 16:
				var tb_c = scene.estate_page.tb_hero_canvas
				_assert(tb_c._tex != null and tb_c._art_rect.visible, "1400x1000 estate_home_base.png rendered")
				var tb_reg: Rect2 = tb_c._current_region
				_assert(tb_reg.position.x <= 24.0 and tb_reg.position.x + tb_reg.size.x >= 1500.0, "Tablet estate region preserves full courtyard and flagpole")
				_assert(absf((tb_c._art_draw_size.x / maxf(1.0, tb_c._art_draw_size.y)) - (tb_reg.size.x / tb_reg.size.y)) < 0.02, "Tablet estate art keeps aspect ratio")
				_assert(absf(tb_c._parallax_px) < 0.01, "Reduced motion disables tablet estate parallax")
				_capture("p0_tablet_estate_art.png")
				AudioManager.is_reduced_motion = false
				print("ALL P0_FLOW_VERIFY CHECKS PASSED!")
				get_tree().quit(0)

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
	if sv != null:
		var tex := sv.get_texture()
		if tex != null:
			var img := tex.get_image()
			if img != null and not img.is_empty():
				img.save_png(_shot_dir + filename)
				print("CAPTURED: %s (%dx%d)" % [_shot_dir + filename, img.get_width(), img.get_height()])

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)
	else:
		print("P0 [PASS] " + msg)

func _fail(msg: String) -> void:
	push_error("P0_FLOW_VERIFY FAILED: " + msg)
	print("P0 [FAIL] " + msg)
	get_tree().quit(1)
