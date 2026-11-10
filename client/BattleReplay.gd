extends Control

## 3路 x 2排 战术推演自动回放引擎 (Battle Replay Engine)
## 攻方左(阵后器械/后排/前排) vs 守方右(前排/后排/城墙城门)
## 60 tick 确定性播放、1x/2x/跳过、顶部城墙条、底部兵力条、朱砂印章 + 3 帧折页

signal replay_finished(result: Dictionary)
signal closed

const FONT_PATH := "res://fonts/NotoSerifCJKsc-Regular.otf"

# 风格水墨水彩纸雕色板
const C_XUANZHI := Color("#f6efe2")     # 宣纸底色
const C_WOOD_DESK := Color("#231c17")   # 深木色
const C_MOLAN := Color("#1e3a5f")       # 守方墨蓝
const C_ZHUSHA := Color("#b83b32")      # 攻方朱砂
const C_TENGHUANG := Color("#cf8325")   # 藤黄
const C_BORDER_GOLD := Color("#c9a227") # 烫金线条
const C_ZHUQING := Color("#276f57")     # 竹青

# 4 兵种视觉定义
const UNIT_STYLES := {
	"cav": {"name": "骑兵", "icon": "🐎", "color": Color("#b83b32")},
	"shield": {"name": "盾兵", "icon": "🛡️", "color": Color("#1e3a5f")},
	"arc": {"name": "弓兵", "icon": "🏹", "color": Color("#276f57")},
	"spear": {"name": "枪兵", "icon": "🗡️", "color": Color("#966324")},
	"SIEGE": {"name": "器械", "icon": "⚙️", "color": Color("#c9a227")}
}

const ASSET_TYPE_MAP := {
	"cav": "cavalry",
	"cavalry": "cavalry",
	"shield": "shield",
	"arc": "archer",
	"archer": "archer",
	"spear": "spear",
	"siege": "siege_ram",
	"SIEGE": "siege_ram"
}

# 回放核心数据
var replay_data: Dictionary = {}
var tick_max: int = 60
var wall_base: int = 1000
var current_wall: int = 1000
var units_data: Dictionary = {} # id -> Dictionary
var events_by_tick: Dictionary = {} # tick -> Array
var battle_result: Dictionary = {}

# 案台与战场画卷背景
var bg_texture: TextureRect
var current_city_ident: String = ""

# 播放状态机
var current_tick: int = 0
var is_playing: bool = true
var playback_speed: float = 1.0 # 1.0x 或 2.0x
var tick_timer: float = 0.0
const BASE_TICK_INTERVAL: float = 0.25 # 每 tick 0.25秒(60 tick约15秒基准，配合2x可快速放完，满足学生体验)

# UI 组件引用
var root_vbox: VBoxContainer
var top_panel: PanelContainer
var top_hbox: HBoxContainer
var title_lbl: Label
var wall_box: HBoxContainer
var wall_title: Label
var wall_bar: ProgressBar
var wall_label: Label
var tick_label: Label
var play_btn: Button
var speed_btn: Button
var skip_btn: Button
var close_btn: Button
var battlefield_rect: Control
var lane_guide: Control
var bot_panel: PanelContainer
var bot_hbox: HBoxContainer
var att_badge: Label
var att_troops_bar: ProgressBar
var troops_summary_label: Label
var def_troops_bar: ProgressBar
var def_badge: Label

# 战场单位视图容器
var unit_views: Dictionary = {} # id -> Control
var siege_view: Control
var wall_view: Control

# 结束折页与印章
var result_overlay: Control
var seal_label: Label
var page_frame_1: Control
var page_frame_2: Control
var page_frame_3: Control
var current_page_idx: int = 0

func _ready() -> void:
	_build_ui()
	# 如果没有外部数据，自动加载标准样例测试数据
	if replay_data.is_empty():
		load_sample_data()

func load_sample_data() -> void:
	var sample := {
		"tick_max": 60,
		"wall_base": 1000,
		"att_slots": {"1": {"front": "cav", "back": "arc"}, "2": {"front": "shield"}, "3": {"front": "spear"}},
		"def_slots": {"1": {"front": "shield", "back": "arc"}, "2": {"front": "spear"}, "3": {"front": "cav"}},
		"units": [
			{"id": "A1F", "side": "att", "lane": 1, "row": "front", "type": "cav", "troops": 363, "max_troops": 363},
			{"id": "A1B", "side": "att", "lane": 1, "row": "back", "type": "arc", "troops": 363, "max_troops": 363},
			{"id": "A2F", "side": "att", "lane": 2, "row": "front", "type": "shield", "troops": 363, "max_troops": 363},
			{"id": "A3F", "side": "att", "lane": 3, "row": "front", "type": "spear", "troops": 363, "max_troops": 363},
			{"id": "D1F", "side": "def", "lane": 1, "row": "front", "type": "shield", "troops": 400, "max_troops": 400},
			{"id": "D1B", "side": "def", "lane": 1, "row": "back", "type": "arc", "troops": 350, "max_troops": 350},
			{"id": "D2F", "side": "def", "lane": 2, "row": "front", "type": "spear", "troops": 380, "max_troops": 380},
			{"id": "D3F", "side": "def", "lane": 3, "row": "front", "type": "cav", "troops": 360, "max_troops": 360}
		],
		"events": [
			{"t": 4, "lane": 1, "unit": "A1F", "action": "attack", "target": "D1F", "damage": 45, "target_troops": 355, "killed": false},
			{"t": 6, "unit": "SIEGE", "action": "wall", "damage": 55, "wall": 945},
			{"t": 10, "lane": 1, "unit": "D1F", "action": "attack", "target": "A1F", "damage": 32, "target_troops": 331, "killed": false},
			{"t": 14, "lane": 1, "unit": "A1B", "action": "attack", "target": "D1F", "damage": 60, "target_troops": 295, "killed": false},
			{"t": 18, "unit": "SIEGE", "action": "wall", "damage": 65, "wall": 880},
			{"t": 24, "lane": 2, "unit": "A2F", "action": "attack", "target": "D2F", "damage": 40, "target_troops": 340, "killed": false},
			{"t": 30, "lane": 1, "unit": "A1F", "action": "attack", "target": "D1F", "damage": 295, "target_troops": 0, "killed": true},
			{"t": 36, "unit": "SIEGE", "action": "wall", "damage": 120, "wall": 760},
			{"t": 42, "lane": 1, "unit": "A1F", "action": "attack", "target": "D1B", "damage": 110, "target_troops": 240, "killed": false},
			{"t": 48, "unit": "SIEGE", "action": "wall", "damage": 260, "wall": 500},
			{"t": 54, "lane": 3, "unit": "A3F", "action": "attack", "target": "D3F", "damage": 120, "target_troops": 240, "killed": false},
			{"t": 58, "unit": "SIEGE", "action": "wall", "damage": 200, "wall": 300}
		],
		"result": {"wall": 300, "score": 1, "ticks": 60, "headline": "攻城先锋浴血破寨！落霞原民心推进 +1"}
	}
	play_data(sample)

func play_data(data: Dictionary) -> void:
	replay_data = data
	var node_id := str(data.get("node_code", data.get("node", data.get("city_type", ""))))
	set_battle_background_by_city(node_id)
	tick_max = int(data.get("tick_max", 0))
	if tick_max <= 0:
		tick_max = int(data.get("result", {}).get("ticks", data.get("ticks", 60)))
	if tick_max <= 0:
		tick_max = 60
	wall_base = int(data.get("wall_base", 1000))
	current_wall = wall_base
	battle_result = data.get("result", {})
	if battle_result.is_empty():
		battle_result = {
			"wall": data.get("wall", current_wall),
			"score": data.get("score", 1),
			"ticks": tick_max,
			"headline": "战斗推演"
		}
	
	# 初始化单位字典（兼容 Array 与 Dictionary）
	units_data.clear()
	var raw_units: Variant = data.get("units", [])
	var u_list: Array = []
	if typeof(raw_units) == TYPE_ARRAY:
		u_list = raw_units
	elif typeof(raw_units) == TYPE_DICTIONARY:
		u_list = raw_units.values()
	
	for u in u_list:
		if typeof(u) != TYPE_DICTIONARY:
			continue
		var uid := str(u.get("id", ""))
		units_data[uid] = u.duplicate(true)
		if not units_data[uid].has("max_troops"):
			units_data[uid]["max_troops"] = units_data[uid].get("troops", 300)
		units_data[uid]["is_alive"] = (float(units_data[uid]["troops"]) > 0.0)
	
	# 建立事件时间索引
	events_by_tick.clear()
	for e in data.get("events", []):
		var t := int(e.get("t", 0))
		if not events_by_tick.has(t):
			events_by_tick[t] = []
		events_by_tick[t].append(e)
	
	current_tick = 0
	is_playing = true
	tick_timer = 0.0
	
	_reset_views()
	_update_hud()
	if result_overlay:
		result_overlay.visible = false

func _process(delta: float) -> void:
	if not is_playing or current_tick >= tick_max:
		return
	
	tick_timer += delta * playback_speed
	var interval := BASE_TICK_INTERVAL
	while tick_timer >= interval and current_tick < tick_max:
		tick_timer -= interval
		_advance_one_tick()

func _advance_one_tick() -> void:
	current_tick += 1
	_apply_tick_events(current_tick)
	_update_hud()
	
	if current_tick >= tick_max:
		_finish_replay()

func _apply_tick_events(t: int) -> void:
	if not events_by_tick.has(t):
		return
	
	var ev_list: Array = events_by_tick[t]
	for e in ev_list:
		var action := str(e.get("action", ""))
		if action == "attack":
			var src_id := str(e.get("unit", ""))
			var tgt_id := str(e.get("target", ""))
			var dmg := float(e.get("damage", 0))
			var killed := bool(e.get("killed", false))
			
			if units_data.has(tgt_id):
				var tgt = units_data[tgt_id]
				if e.has("target_troops"):
					tgt["troops"] = float(e["target_troops"])
				else:
					tgt["troops"] = maxf(0.0, float(tgt["troops"]) - dmg)
				tgt["is_alive"] = not killed and (float(tgt["troops"]) > 0.0)
				_play_attack_anim(src_id, tgt_id, int(round(dmg)), killed)
		elif action == "wall":
			var dmg := float(e.get("damage", 0))
			if e.has("wall"):
				current_wall = int(round(float(e["wall"])))
			else:
				current_wall = max(0, current_wall - int(round(dmg)))
			_play_siege_anim(int(round(dmg)))
		elif action == "advance_row":
			var uid := str(e.get("unit", ""))
			var new_row := str(e.get("row", "front"))
			if units_data.has(uid):
				units_data[uid]["row"] = new_row
				_layout_battlefield()

func _set_unit_sprite_state(uid: String, state_suffix: String) -> void:
	var card: Control = unit_views.get(uid, null)
	if not card or not units_data.has(uid):
		return
	var sprite: TextureRect = card.find_child("UnitSprite", true, false)
	if not sprite:
		return
	var utype: String = str(units_data[uid].get("type", "cav"))
	var base_type: String = ASSET_TYPE_MAP.get(utype, "cavalry")
	var path := "res://assets/art/battle/%s_%s.png" % [base_type, state_suffix]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)

func _play_attack_anim(src_id: String, tgt_id: String, dmg: int, killed: bool) -> void:
	var src_view: Control = unit_views.get(src_id, null)
	var tgt_view: Control = unit_views.get(tgt_id, null)
	if src_view and tgt_view:
		# 切换为攻击与受击姿态
		_set_unit_sprite_state(src_id, "attack")
		_set_unit_sprite_state(tgt_id, "hit")

		# 攻击方微向前冲刺再回弹
		var orig_pos := src_view.position
		var dir := (tgt_view.position - src_view.position).normalized()
		var tw := create_tween()
		tw.tween_property(src_view, "position", orig_pos + dir * 14.0, 0.08)
		tw.tween_property(src_view, "position", orig_pos, 0.12)
		tw.finished.connect(func():
			_set_unit_sprite_state(src_id, "idle")
		)
		
		# 目标方受击震颤与掉血浮字
		_spawn_floating_text(tgt_view.position + Vector2(20, -10), "-%d" % dmg, Color("#ff5544"))
		_shake_node(tgt_view)
		_update_unit_card(tgt_id)
		
		get_tree().create_timer(0.22).timeout.connect(func():
			if units_data.has(tgt_id) and units_data[tgt_id].get("is_alive", true):
				_set_unit_sprite_state(tgt_id, "idle")
		)
		
		if killed:
			var fade_tw := create_tween()
			fade_tw.tween_property(tgt_view, "modulate:a", 0.35, 0.25)

func _play_siege_anim(dmg: int) -> void:
	if siege_view and wall_view:
		# 切换器械为攻墙撞击姿态
		var siege_sprite: TextureRect = siege_view.find_child("SiegeSprite", true, false)
		if siege_sprite and ResourceLoader.exists("res://assets/art/battle/siege_ram_wall_attack.png"):
			siege_sprite.texture = load("res://assets/art/battle/siege_ram_wall_attack.png")
		
		# 器械冲刺动画
		var tw := create_tween()
		tw.tween_property(siege_view, "position:x", siege_view.position.x + 16.0, 0.10)
		tw.tween_property(siege_view, "position:x", siege_view.position.x, 0.15)
		tw.finished.connect(func():
			if siege_sprite and ResourceLoader.exists("res://assets/art/battle/siege_ram_idle.png"):
				siege_sprite.texture = load("res://assets/art/battle/siege_ram_idle.png")
		)
		
		# 城墙受创爆裂与浮字
		_spawn_floating_text(wall_view.position + Vector2(10, 40), "轰! -%d" % dmg, Color("#ffaa33"))
		_shake_node(wall_view)

func _spawn_floating_text(pos: Vector2, text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.position = pos
	battlefield_rect.add_child(lbl)
	
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y - 24.0, 0.45)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.45)
	tw.finished.connect(func(): if is_instance_valid(lbl): lbl.queue_free())

func _shake_node(node: Control) -> void:
	if not node: return
	var orig := node.position
	var tw := create_tween()
	tw.tween_property(node, "position", orig + Vector2(randf_range(-3, 3), randf_range(-3, 3)), 0.05)
	tw.tween_property(node, "position", orig, 0.05)

func _finish_replay() -> void:
	is_playing = false
	current_tick = tick_max
	_update_hud()
	_show_result_overlay()
	replay_finished.emit(battle_result)

const CARD_NAMES: Dictionary = {
	"night_raid": "夜袭",
	"forced_march": "急行",
	"fire_attack": "火攻",
	"fortify": "坚壁",
	"mutual_support": "犄角",
	"empty_fort": "空城",
	"last_stand": "死守",
	"scout": "哨探",
	"counter_intel": "反间",
	"feint": "疑兵",
	"supply": "运粮",
	"cut_supply": "断粮",
}

const CARD_EFFECTS: Dictionary = {
	"night_raid": "攻击 +20%（本城未侦察）",
	"forced_march": "先手行动，免疫断粮",
	"fire_attack": "器械攻墙 +50%",
	"fortify": "防御 +20%",
	"mutual_support": "相邻路友军防御 +10%",
	"empty_fort": "敌全军攻击 -10%",
	"last_stand": "致命伤留 1 兵",
	"scout": "解锁情报并压制夜袭",
	"counter_intel": "敌全军攻击 -10%",
	"feint": "敌方情报显示集结兵力 1.5 倍",
	"supply": "每 15 候回复 5% 兵力",
	"cut_supply": "敌军每 15 候损失 3% 兵力",
}

func _show_result_overlay() -> void:
	if not result_overlay:
		return
	result_overlay.z_index = 35
	result_overlay.move_to_front()
	result_overlay.visible = true
	result_overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(result_overlay, "modulate:a", 1.0, 0.3)
	
	# 根据最终战果设定大印章
	var wall_remain_pct := float(current_wall) / float(wall_base)
	var score := int(battle_result.get("score", 0))
	var headline := str(battle_result.get("headline", ""))
	var seal_text := headline if headline != "" else "战斗推演"
	var seal_col := C_TENGHUANG
	
	if score == 2 or wall_remain_pct <= 0.0:
		seal_text = "破城大捷" if headline == "" else ("破城·" + headline)
		seal_col = C_ZHUSHA
	elif score == 1:
		seal_text = "撼城推进" if headline == "" else ("撼城·" + headline)
		seal_col = C_TENGHUANG
	elif score == 0:
		seal_text = "浴血对峙" if headline == "" else ("对峙·" + headline)
		seal_col = C_MOLAN
	elif score <= -1 or wall_remain_pct >= 0.8:
		seal_text = "雄关固守" if headline == "" else ("固守·" + headline)
		seal_col = C_ZHUQING
	
	seal_label.text = "【%s】" % seal_text
	seal_label.add_theme_color_override("font_color", seal_col)
	
	# 更新第一折战果信息
	if page_frame_1 and page_frame_1.get_child_count() >= 2:
		var desc1_node = page_frame_1.get_child(1)
		if desc1_node is Label:
			var w_val := float(battle_result.get("wall", current_wall))
			var t_val := int(battle_result.get("ticks", current_tick))
			desc1_node.text = "• 决战战况：%s (评分 %d)\n• 城池坚壁残余：%.1f / %d 点 (破损率 %.0f%%)\n• 推演时长：%d 候(tick) · 全军将士奋勇交锋" % [
				headline if headline != "" else seal_text,
				score,
				w_val,
				wall_base,
				clampf((1.0 - w_val / float(wall_base)) * 100.0, 0.0, 100.0),
				t_val
			]
	
	# 更新第二折诸队战术实效（Phase 1.5：逐队解释）
	if page_frame_2 and page_frame_2.get_child_count() >= 2:
		var desc2_node = page_frame_2.get_child(1)
		if desc2_node is Label:
			desc2_node.text = _format_team_tactics_lines()
	
	_show_page_frame(0)

func _format_team_tactics_lines() -> String:
	var lines: Array[String] = []
	var teams: Array = []
	
	# 1. 优先从 attacker.teams 读取
	var raw_att: Variant = replay_data.get("attacker", {})
	if typeof(raw_att) == TYPE_DICTIONARY and raw_att.has("teams"):
		var raw_teams: Variant = raw_att.get("teams", [])
		if typeof(raw_teams) == TYPE_ARRAY and not raw_teams.is_empty():
			teams = raw_teams
			
	# 2. 若未从 attacker.teams 读取，则从 units_data 中提取攻方单位
	if teams.is_empty():
		var att_units: Array = []
		for u in units_data.values():
			if typeof(u) == TYPE_DICTIONARY and str(u.get("side", "")) == "att":
				att_units.append(u)
		att_units.sort_custom(func(a, b): return int(a.get("lane", 1)) < int(b.get("lane", 1)))
		teams = att_units

	# 3. 兜底默认三队（严格覆盖战术生效与未佩战策样本）
	if teams.is_empty():
		lines.append("⚔️【战况交锋总揽】先锋夜袭突防，中军重盾破关，城防大幅瓦解！")
		lines.append("• ⚡夜袭生效 · 骑兵 · 1路前 · 攻击 +20%（本城未侦察）")
		lines.append("• ⚡坚壁生效 · 盾兵 · 2路前 · 防御 +20%（守备稳固）")
		lines.append("• 常规突进 · 弓兵 · 3路后 · (未佩战策)")
		return "\n".join(lines)

	lines.append("⚔️【战况交锋总揽】先锋夜袭突防，中军重盾破关，城防大幅瓦解！")
	var type_names := {"cav": "骑", "shield": "盾", "arc": "弓", "spear": "枪"}
	for t in teams:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var raw_type := str(t.get("type", "cav"))
		var t_name := str(type_names.get(raw_type, raw_type))
		var lane_num := int(t.get("lane", 1))
		var row_val := str(t.get("row", "front"))
		var row_str := "后" if row_val == "back" else "前"
		var card_code := str(t.get("card", "") if t.get("card") != null else "")
		
		if card_code != "" and card_code != "null":
			var card_title := str(CARD_NAMES.get(card_code, card_code))
			var effect_desc := str(CARD_EFFECTS.get(card_code, "战术生效"))
			lines.append("• ⚡%s生效 · %s兵 · %d路%s · %s" % [card_title, t_name, lane_num, row_str, effect_desc])
		else:
			lines.append("• 常规突进 · %s兵 · %d路%s · (未佩战策)" % [t_name, lane_num, row_str])

	return "\n".join(lines)

func _show_page_frame(page_idx: int) -> void:
	current_page_idx = page_idx
	if page_frame_1: page_frame_1.visible = (page_idx == 0)
	if page_frame_2: page_frame_2.visible = (page_idx == 1)
	if page_frame_3: page_frame_3.visible = (page_idx == 2)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout_responsive)
	
	# 案台深墨背景
	var bg := ColorRect.new()
	bg.color = C_WOOD_DESK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 宏伟水墨水彩战场画卷底图（平原/关隘/渡口 3 景动态自适应）
	bg_texture = TextureRect.new()
	bg_texture.name = "BattleBgTexture"
	bg_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg_texture)
	set_battle_background_by_city("plain")

	# 柔和半透明暗幕，确保沙盘上方信息高对比度清晰
	var bg_dim := ColorRect.new()
	bg_dim.color = Color(0.08, 0.06, 0.04, 0.28)
	bg_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg_dim)
	
	root_vbox = VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 2)
	add_child(root_vbox)
	
	# 1. 顶部控制与城墙耐久条
	top_panel = PanelContainer.new()
	top_panel.custom_minimum_size = Vector2(0, 48)
	top_panel.add_theme_stylebox_override("panel", _make_style(Color(0.12, 0.09, 0.07, 0.95), C_BORDER_GOLD, 1, 0, 6))
	root_vbox.add_child(top_panel)
	
	top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	top_panel.add_child(top_hbox)
	
	title_lbl = Label.new()
	title_lbl.text = "🏯 战斗回放 · 3路x2排"
	title_lbl.add_theme_color_override("font_color", Color("#fae19c"))
	title_lbl.add_theme_font_size_override("font_size", 14)
	top_hbox.add_child(title_lbl)
	
	# 顶部城墙耐久条
	wall_box = HBoxContainer.new()
	wall_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wall_box.add_theme_constant_override("separation", 6)
	top_hbox.add_child(wall_box)
	
	wall_title = Label.new()
	wall_title.text = "城墙耐久:"
	wall_title.add_theme_color_override("font_color", Color("#d5c4a1"))
	wall_title.add_theme_font_size_override("font_size", 12)
	wall_box.add_child(wall_title)
	
	wall_bar = ProgressBar.new()
	wall_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wall_bar.custom_minimum_size = Vector2(160, 16)
	wall_bar.show_percentage = false
	wall_bar.max_value = wall_base
	wall_bar.value = current_wall
	wall_box.add_child(wall_bar)
	
	wall_label = Label.new()
	wall_label.text = "1000/1000"
	wall_label.add_theme_color_override("font_color", Color("#fae19c"))
	wall_label.add_theme_font_size_override("font_size", 12)
	wall_box.add_child(wall_label)
	
	# 播放控制组件
	tick_label = Label.new()
	tick_label.text = "00 / 60 候"
	tick_label.add_theme_color_override("font_color", Color("#b5a489"))
	tick_label.add_theme_font_size_override("font_size", 12)
	top_hbox.add_child(tick_label)
	
	play_btn = Button.new()
	play_btn.text = "⏸ 暂停"
	play_btn.custom_minimum_size = Vector2(64, 28)
	play_btn.add_theme_font_size_override("font_size", 11)
	play_btn.pressed.connect(_on_play_toggle)
	top_hbox.add_child(play_btn)
	
	speed_btn = Button.new()
	speed_btn.text = "1x"
	speed_btn.custom_minimum_size = Vector2(40, 28)
	speed_btn.add_theme_font_size_override("font_size", 11)
	speed_btn.pressed.connect(_on_speed_toggle)
	top_hbox.add_child(speed_btn)
	
	skip_btn = Button.new()
	skip_btn.text = "⏭ 跳过"
	skip_btn.custom_minimum_size = Vector2(58, 28)
	skip_btn.add_theme_font_size_override("font_size", 11)
	skip_btn.pressed.connect(_on_skip_pressed)
	top_hbox.add_child(skip_btn)
	
	close_btn = Button.new()
	close_btn.text = "✕ 关闭"
	close_btn.custom_minimum_size = Vector2(58, 28)
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(func(): closed.emit(); visible = false)
	top_hbox.add_child(close_btn)
	
	# 2. 战场主体视口
	battlefield_rect = Control.new()
	battlefield_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battlefield_rect.clip_contents = true
	battlefield_rect.resized.connect(_layout_battlefield)
	root_vbox.add_child(battlefield_rect)
	
	# 宣纸沙盘铺底（半透明磨砂，透出宏伟战场画卷，同时保持战道与卡牌对比度）
	var paper_map := ColorRect.new()
	paper_map.color = Color(0.96, 0.92, 0.85, 0.22)
	paper_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battlefield_rect.add_child(paper_map)
	
	# 3条战道背景线
	lane_guide = Control.new()
	lane_guide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battlefield_rect.add_child(lane_guide)
	lane_guide.draw.connect(func():
		var h := lane_guide.size.y
		var w := lane_guide.size.x
		for i in range(1, 3):
			var ly := h * (float(i) / 3.0)
			lane_guide.draw_line(Vector2(0, ly), Vector2(w, ly), Color(0.65, 0.58, 0.48, 0.5), 1.0)
	)
	
	# 3. 底部攻守总兵力对比条
	bot_panel = PanelContainer.new()
	bot_panel.custom_minimum_size = Vector2(0, 42)
	bot_panel.add_theme_stylebox_override("panel", _make_style(Color(0.12, 0.09, 0.07, 0.95), C_BORDER_GOLD, 1, 0, 4))
	root_vbox.add_child(bot_panel)
	
	bot_hbox = HBoxContainer.new()
	bot_hbox.add_theme_constant_override("separation", 10)
	bot_panel.add_child(bot_hbox)
	
	att_badge = Label.new()
	att_badge.text = "🔴 攻方兵力"
	att_badge.add_theme_color_override("font_color", C_ZHUSHA.lightened(0.2))
	att_badge.add_theme_font_size_override("font_size", 12)
	bot_hbox.add_child(att_badge)
	
	att_troops_bar = ProgressBar.new()
	att_troops_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	att_troops_bar.custom_minimum_size = Vector2(100, 14)
	att_troops_bar.show_percentage = false
	bot_hbox.add_child(att_troops_bar)
	
	troops_summary_label = Label.new()
	troops_summary_label.text = "1452 vs 1490"
	troops_summary_label.add_theme_color_override("font_color", Color("#fae19c"))
	troops_summary_label.add_theme_font_size_override("font_size", 12)
	bot_hbox.add_child(troops_summary_label)
	
	def_troops_bar = ProgressBar.new()
	def_troops_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	def_troops_bar.custom_minimum_size = Vector2(100, 14)
	def_troops_bar.show_percentage = false
	bot_hbox.add_child(def_troops_bar)
	
	def_badge = Label.new()
	def_badge.text = "🔵 守方兵力"
	def_badge.add_theme_color_override("font_color", C_MOLAN.lightened(0.4))
	def_badge.add_theme_font_size_override("font_size", 12)
	bot_hbox.add_child(def_badge)
	
	# 4. 战役结算 3 帧折页与印章浮层
	_build_result_overlay()
	_layout_responsive()

func _layout_responsive() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var is_phone := w < 900.0 or h < 650.0
	
	if top_panel:
		top_panel.custom_minimum_size.y = 38 if is_phone else 48
	if top_hbox:
		top_hbox.add_theme_constant_override("separation", 4 if is_phone else 10)
	if title_lbl:
		title_lbl.text = "🏯 回放" if is_phone else "🏯 战斗回放 · 3路x2排"
		title_lbl.add_theme_font_size_override("font_size", 11 if is_phone else 14)
	if wall_box:
		wall_box.add_theme_constant_override("separation", 3 if is_phone else 6)
	if wall_title:
		wall_title.text = "城墙:" if is_phone else "城墙耐久:"
		wall_title.add_theme_font_size_override("font_size", 10 if is_phone else 12)
	if wall_bar:
		wall_bar.custom_minimum_size = Vector2(50 if is_phone else 140, 12 if is_phone else 16)
	if wall_label:
		wall_label.add_theme_font_size_override("font_size", 10 if is_phone else 12)
	if tick_label:
		tick_label.add_theme_font_size_override("font_size", 10 if is_phone else 12)
	if play_btn:
		play_btn.custom_minimum_size = Vector2(46 if is_phone else 64, 24 if is_phone else 28)
		play_btn.add_theme_font_size_override("font_size", 10 if is_phone else 11)
	if speed_btn:
		speed_btn.custom_minimum_size = Vector2(30 if is_phone else 40, 24 if is_phone else 28)
		speed_btn.add_theme_font_size_override("font_size", 10 if is_phone else 11)
	if skip_btn:
		skip_btn.custom_minimum_size = Vector2(46 if is_phone else 58, 24 if is_phone else 28)
		skip_btn.add_theme_font_size_override("font_size", 10 if is_phone else 11)
	if close_btn:
		close_btn.custom_minimum_size = Vector2(46 if is_phone else 58, 24 if is_phone else 28)
		close_btn.add_theme_font_size_override("font_size", 10 if is_phone else 11)
		
	if bot_panel:
		bot_panel.custom_minimum_size.y = 32 if is_phone else 42
	if bot_hbox:
		bot_hbox.add_theme_constant_override("separation", 4 if is_phone else 10)
	if att_badge:
		att_badge.text = "🔴 攻方" if is_phone else "🔴 攻方兵力"
		att_badge.add_theme_font_size_override("font_size", 10 if is_phone else 12)
	if def_badge:
		def_badge.text = "🔵 守方" if is_phone else "🔵 守方兵力"
		def_badge.add_theme_font_size_override("font_size", 10 if is_phone else 12)
	if troops_summary_label:
		troops_summary_label.add_theme_font_size_override("font_size", 10 if is_phone else 12)
	if att_troops_bar:
		att_troops_bar.custom_minimum_size = Vector2(60 if is_phone else 100, 10 if is_phone else 14)
	if def_troops_bar:
		def_troops_bar.custom_minimum_size = Vector2(60 if is_phone else 100, 10 if is_phone else 14)

	_layout_battlefield()

func _layout_battlefield() -> void:
	if not battlefield_rect:
		return
	var bw := battlefield_rect.size.x
	var bh := battlefield_rect.size.y
	if bw <= 0.0 or bh <= 0.0:
		return
	var is_phone := bw < 900.0 or bh < 500.0
	var lane_h := bh / 3.0
	
	if wall_view:
		var wall_w := bw * (0.13 if is_phone else 0.14)
		wall_view.position = Vector2(bw - wall_w, 0)
		wall_view.size = Vector2(wall_w, bh)
		
	if siege_view:
		var siege_w := bw * (0.11 if is_phone else 0.10)
		var siege_h := clampf(bh * 0.30, 56.0, 100.0)
		siege_view.position = Vector2(bw * 0.012, (bh - siege_h) / 2.0)
		siege_view.size = Vector2(siege_w, siege_h)
		
	var card_w := clampf(bw * 0.115, 76.0, 96.0) if is_phone else clampf(bw * 0.12, 115.0, 145.0)
	var card_h := clampf(lane_h * 0.88, 60.0, 78.0) if is_phone else clampf(lane_h * 0.85, 86.0, 118.0)
	
	for uid in unit_views.keys():
		var card: Control = unit_views[uid]
		if not is_instance_valid(card):
			continue
		var u: Dictionary = units_data.get(uid, {})
		var side := str(u.get("side", "att"))
		var lane := int(u.get("lane", 1))
		var row := str(u.get("row", "front"))
		
		var y_pos := (lane - 1) * lane_h + (lane_h - card_h) / 2.0
		var x_pos := 0.0
		if side == "att":
			# 攻方：后排靠左(0.14)，前排靠中(0.28)
			x_pos = bw * (0.14 if row == "back" else 0.28)
		else:
			# 守方：前排靠中(0.52)，后排靠右(0.66)
			x_pos = bw * (0.52 if row == "front" else 0.66)
			
		card.position = Vector2(x_pos, y_pos)
		card.size = Vector2(card_w, card_h)
		# 层级：前排遮挡后排
		card.z_index = lane * 10 + (2 if row == "front" else 1)

func _reset_views() -> void:
	# 立即彻底清理旧单位视图（避免跨分辨率复用残余）
	for child in battlefield_rect.get_children():
		if child.name.begins_with("Unit_") or child.name == "SiegeEngine" or child.name == "CityWall":
			battlefield_rect.remove_child(child)
			child.queue_free()
	unit_views.clear()
	
	var bw := battlefield_rect.size.x
	var bh := battlefield_rect.size.y
	if bw <= 0.0 or bh <= 0.0:
		bw = 720.0
		bh = 380.0
	
	var lane_h := bh / 3.0
	
	# 建立最右侧城门
	wall_view = _create_wall_view()
	wall_view.name = "CityWall"
	battlefield_rect.add_child(wall_view)
	
	# 建立攻方阵后器械 (最左侧)
	siege_view = _create_siege_view()
	siege_view.name = "SiegeEngine"
	battlefield_rect.add_child(siege_view)
	
	# 建立每个具体单位卡片
	for uid in units_data.keys():
		var u: Dictionary = units_data[uid]
		var card := _create_unit_card(uid, u)
		card.name = "Unit_" + uid
		battlefield_rect.add_child(card)
		unit_views[uid] = card
		
	_layout_battlefield()

func _create_unit_card(uid: String, udata: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var side := str(udata.get("side", "att"))
	var utype := str(udata.get("type", "cav"))
	var base_type: String = ASSET_TYPE_MAP.get(utype, "cavalry")
	var ustyle: Dictionary = UNIT_STYLES.get(utype, UNIT_STYLES["cav"])
	var is_att := (side == "att")
	var is_phone := (size.x < 900.0 and size.x > 0.0) or (size.y < 650.0 and size.y > 0.0)
	
	# 阵营色：只用于细边框、印章标签与光环，不整体着色
	var border_c := C_ZHUSHA if is_att else C_MOLAN
	var bg_c := Color("#fdfbf7") # 宣纸米白底
	card.add_theme_stylebox_override("panel", _make_style(bg_c, border_c, 2, 4 if is_phone else 6, 2 if is_phone else 3))
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	card.add_child(vbox)
	
	# 顶部小标头：阵营印章 + 兵种名 + 前后排
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 2)
	vbox.add_child(top_h)
	
	var tag_lbl := Label.new()
	var faction_mark := "朱" if is_att else "墨"
	var row_text := "前" if udata.get("row") == "front" else "后"
	tag_lbl.text = "【%s·%s %s】" % [faction_mark, ustyle.name, row_text]
	tag_lbl.add_theme_color_override("font_color", border_c)
	tag_lbl.add_theme_font_size_override("font_size", 9 if is_phone else 11)
	tag_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(tag_lbl)
	
	# 中间主体：兵种姿态图 TextureRect (带脚底微水墨投影)
	var sprite_wrap := Control.new()
	sprite_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite_wrap.custom_minimum_size = Vector2(0, 32 if is_phone else 46)
	vbox.add_child(sprite_wrap)
	
	# 脚底阴影椭圆
	var foot_shadow := ColorRect.new()
	foot_shadow.color = Color(0, 0, 0, 0.12)
	foot_shadow.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot_shadow.custom_minimum_size = Vector2(0, 4)
	sprite_wrap.add_child(foot_shadow)
	
	var tex_rect := TextureRect.new()
	tex_rect.name = "UnitSprite"
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_path := "res://assets/art/battle/%s_idle.png" % base_type
	if ResourceLoader.exists(tex_path):
		tex_rect.texture = load(tex_path)
	if not is_att:
		tex_rect.flip_h = true # 守方水平镜像迎敌
	sprite_wrap.add_child(tex_rect)
	
	# 底部：血条与兵力数
	var bar := ProgressBar.new()
	bar.name = "TroopBar"
	bar.custom_minimum_size = Vector2(0, 5 if is_phone else 7)
	bar.max_value = float(udata.get("max_troops", 363))
	bar.value = float(udata.get("troops", 363))
	bar.show_percentage = false
	vbox.add_child(bar)
	
	var pwr_lbl := Label.new()
	pwr_lbl.name = "TroopText"
	pwr_lbl.text = "%d" % int(round(float(udata.get("troops", 363))))
	pwr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pwr_lbl.add_theme_color_override("font_color", Color("#231c17"))
	pwr_lbl.add_theme_font_size_override("font_size", 9 if is_phone else 11)
	vbox.add_child(pwr_lbl)
	
	return card

func _update_unit_card(uid: String) -> void:
	var card: PanelContainer = unit_views.get(uid, null)
	if not card or not units_data.has(uid):
		return
	var udata: Dictionary = units_data[uid]
	var cur_troops: int = int(round(float(udata.get("troops", 0))))
	var bar: ProgressBar = card.find_child("TroopBar", true, false)
	if bar:
		bar.value = cur_troops
	var txt: Label = card.find_child("TroopText", true, false)
	if txt:
		txt.text = "%d" % cur_troops if cur_troops > 0 else "溃退"
		if cur_troops <= 0:
			txt.add_theme_color_override("font_color", Color("#a02020"))

func _create_siege_view() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _make_style(Color(0.18, 0.14, 0.10, 0.90), C_BORDER_GOLD, 2, 6, 4))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	
	var tag := Label.new()
	tag.text = "【攻城重械】"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", Color("#fae19c"))
	tag.add_theme_font_size_override("font_size", 10)
	v.add_child(tag)
	
	var sprite := TextureRect.new()
	sprite.name = "SiegeSprite"
	sprite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var s_path := "res://assets/art/battle/siege_ram_idle.png"
	if ResourceLoader.exists(s_path):
		sprite.texture = load(s_path)
	v.add_child(sprite)
	
	var tip := Label.new()
	tip.text = "阵后破关"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_color_override("font_color", Color("#c5b499"))
	tip.add_theme_font_size_override("font_size", 9)
	v.add_child(tip)
	return p

func _create_wall_view() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _make_style(Color(0.16, 0.14, 0.12, 0.95), C_BORDER_GOLD, 2, 0, 4))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	p.add_child(v)
	
	var title := Label.new()
	title.text = "守军雄关"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#fae19c"))
	title.add_theme_font_size_override("font_size", 11)
	v.add_child(title)
	
	var wall_tex := TextureRect.new()
	wall_tex.name = "GateWallTexture"
	wall_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wall_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var w_path := "res://assets/art/battle/castle_gate_wall.png"
	if ResourceLoader.exists(w_path):
		wall_tex.texture = load(w_path)
	v.add_child(wall_tex)
	
	var gate_tip := Label.new()
	gate_tip.text = "城防坚壁"
	gate_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gate_tip.add_theme_color_override("font_color", Color("#b5a489"))
	gate_tip.add_theme_font_size_override("font_size", 9)
	v.add_child(gate_tip)
	return p

func _update_hud() -> void:
	if wall_bar:
		wall_bar.value = current_wall
	if wall_label:
		var pct := (float(current_wall) / float(wall_base)) * 100.0
		wall_label.text = "%d/%d (%.1f%%)" % [current_wall, wall_base, pct]
	if tick_label:
		tick_label.text = "%02d / %02d 候" % [current_tick, tick_max]
	
	# 计算双方实时总兵力
	var att_total: int = 0
	var def_total: int = 0
	var att_max: int = 0
	var def_max: int = 0
	for u in units_data.values():
		var troops: int = int(u.get("troops", 0))
		var max_t: int = int(u.get("max_troops", 363))
		if u.get("side") == "att":
			att_total += troops
			att_max += max_t
		else:
			def_total += troops
			def_max += max_t
	
	if att_troops_bar:
		att_troops_bar.max_value = att_max
		att_troops_bar.value = att_total
	if def_troops_bar:
		def_troops_bar.max_value = def_max
		def_troops_bar.value = def_total
	if troops_summary_label:
		troops_summary_label.text = "%d vs %d" % [att_total, def_total]

func _on_play_toggle() -> void:
	is_playing = not is_playing
	play_btn.text = "▶ 播放" if not is_playing else "⏸ 暂停"

func _on_speed_toggle() -> void:
	playback_speed = 2.0 if playback_speed == 1.0 else 1.0
	speed_btn.text = "%.0fx" % playback_speed

func _on_skip_pressed() -> void:
	# 快进应用所有事件到最终状态
	while current_tick < tick_max:
		current_tick += 1
		_apply_tick_events(current_tick)
	_finish_replay()

func _build_result_overlay() -> void:
	result_overlay = Control.new()
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.z_index = 35
	result_overlay.visible = false
	add_child(result_overlay)
	
	# 半透明深色遮罩
	var mask := ColorRect.new()
	mask.color = Color(0.1, 0.08, 0.06, 0.75)
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(mask)
	
	# 中央水墨折页纸卡
	var card_center := PanelContainer.new()
	card_center.custom_minimum_size = Vector2(460, 320)
	card_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var patch_path := "res://assets/art/ui/card_frame_ninepatch.png"
	if ResourceLoader.exists(patch_path):
		var nine_sb := StyleBoxTexture.new()
		nine_sb.texture = load(patch_path)
		nine_sb.texture_margin_left = 32
		nine_sb.texture_margin_top = 32
		nine_sb.texture_margin_right = 32
		nine_sb.texture_margin_bottom = 32
		nine_sb.set_content_margin_all(16)
		card_center.add_theme_stylebox_override("panel", nine_sb)
	else:
		card_center.add_theme_stylebox_override("panel", _make_style(C_XUANZHI, C_BORDER_GOLD, 3, 10, 16))
	result_overlay.add_child(card_center)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card_center.add_child(vbox)
	
	# 朱砂大印章居中
	seal_label = Label.new()
	seal_label.text = "【大获全胜】"
	seal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(seal_label)
	
	# 3 帧折页内容容器
	var content_box := Control.new()
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_box)
	
	# 帧 1: 战况头条与民心变化
	page_frame_1 = VBoxContainer.new()
	page_frame_1.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_box.add_child(page_frame_1)
	
	var h1 := Label.new()
	h1.text = "📜 今日战局风云录 (第 1 帧/共 3 帧)"
	h1.add_theme_color_override("font_color", Color("#231c17"))
	h1.add_theme_font_size_override("font_size", 14)
	page_frame_1.add_child(h1)
	
	var desc1 := Label.new()
	desc1.text = "• 攻城重械持续轰击，城门破损度达到 70%！\n• 目标据点民心拉锯推进：攻方声势大振，民心 +1 格！\n• 守方坚壁清野，前排盾阵虽受重创但未全军覆没。"
	desc1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc1.add_theme_color_override("font_color", Color("#4a3e35"))
	desc1.add_theme_font_size_override("font_size", 12)
	page_frame_1.add_child(desc1)
	
	# 帧 2: 诸队战术实效与三路详表
	page_frame_2 = VBoxContainer.new()
	page_frame_2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_frame_2.visible = false
	content_box.add_child(page_frame_2)
	
	var h2 := Label.new()
	h2.text = "⚔️ 诸队战术与三路实效 (第 2 帧/共 3 帧)"
	h2.add_theme_color_override("font_color", Color("#231c17"))
	h2.add_theme_font_size_override("font_size", 14)
	page_frame_2.add_child(h2)
	
	var desc2 := Label.new()
	desc2.text = "• 骑 · 1 路前 · 夜袭 · 攻击 +20%（本城未侦察）\n• 盾 · 2 路前 · 坚壁 · 防御 +20%\n• 弓 · 3 路后 · 火攻 · 器械攻墙 +50%"
	desc2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc2.add_theme_color_override("font_color", Color("#4a3e35"))
	desc2.add_theme_font_size_override("font_size", 12)
	page_frame_2.add_child(desc2)
	
	# 帧 3: 班宠将军点评与名场面
	page_frame_3 = VBoxContainer.new()
	page_frame_3.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_frame_3.visible = false
	content_box.add_child(page_frame_3)
	
	var h3 := Label.new()
	h3.text = "🐾 灵宠将军点评 (第 3 帧/共 3 帧)"
	h3.add_theme_color_override("font_color", Color("#231c17"))
	h3.add_theme_font_size_override("font_size", 14)
	page_frame_3.add_child(h3)
	
	var desc3 := Label.new()
	desc3.text = "青竹将军摇了摇尾巴，赞道：\n「先锋骑兵夜袭得手，器械破关势如破竹！明日再施一令，定克此城！」\n荣誉定格：参与本次合围的同窗全员荣获【破壁之勋】！"
	desc3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc3.add_theme_color_override("font_color", Color("#231c17"))
	desc3.add_theme_font_size_override("font_size", 12)
	page_frame_3.add_child(desc3)
	
	# 底部翻折页按钮
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_hbox)
	
	var prev_btn := Button.new()
	prev_btn.text = "◀ 上一折"
	prev_btn.pressed.connect(func(): _show_page_frame(max(0, current_page_idx - 1)))
	btn_hbox.add_child(prev_btn)
	
	var next_btn := Button.new()
	next_btn.text = "下一折 ▶"
	next_btn.pressed.connect(func(): _show_page_frame(min(2, current_page_idx + 1)))
	btn_hbox.add_child(next_btn)
	
	var done_btn := Button.new()
	done_btn.text = "检视完毕"
	done_btn.add_theme_color_override("font_color", Color("#ffffff"))
	done_btn.add_theme_stylebox_override("normal", _make_style(C_ZHUQING, C_BORDER_GOLD, 1, 6, 4))
	done_btn.pressed.connect(func(): result_overlay.visible = false; closed.emit())
	btn_hbox.add_child(done_btn)

func _make_style(bg: Color, border: Color, border_w: int = 1, radius: int = 6, pad: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb

## 按城池类型与据点识别码动态切换 3 张战场画卷背景 (平原/关隘/渡口)
func set_battle_background_by_city(city_ident: String) -> void:
	current_city_ident = city_ident
	var path := "res://assets/art/battle/bg_battle_plain.png"
	var lower := city_ident.to_lower()
	if "ferry" in lower or "渡" in city_ident or "n1" in lower or "水" in city_ident or "建业" in city_ident or "襄阳" in city_ident or "river" in lower:
		path = "res://assets/art/battle/bg_battle_ferry.png"
	elif "pass" in lower or "关" in city_ident or "台" in city_ident or "start" in lower or "n3" in lower or "太原" in city_ident or "汉中" in city_ident or "江陵" in city_ident or "gate" in lower:
		path = "res://assets/art/battle/bg_battle_pass.png"
	else:
		path = "res://assets/art/battle/bg_battle_plain.png"
	
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex and is_instance_valid(bg_texture):
			bg_texture.texture = tex

