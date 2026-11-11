extends Control

## 文房小院主视图 (S02_CITY_HUB)
## 严格按 720×514 手机横屏 与 1400×1000 平板双栏线框实现

signal back_to_map_requested
signal focus_city_requested(city_code: String)
signal upgrade_requested(room_code: String)
signal merit_rank_requested
signal toast_requested(msg: String, is_error: bool)

const FONT_PATH := "res://fonts/NotoSerifCJKsc-Regular.otf"
const ESTATE_TUTORIAL_CFG := "user://estate_tutorial.cfg"

# Style C 宣纸墨韵色板
const C_BG_DESK := Color("#1f1914")
const C_XUANZHI := Color("#f6efe2")
const C_XUANZHI_SOFT := Color("#ede2ce")
const C_INK := Color("#2b2118")
const C_MUTED := Color("#6f5e4d")
const C_MOLAN := Color("#1e3a5f")
const C_ZHUQING := Color("#276f57")
const C_ZHUSHA := Color("#b83b32")
const C_TENGHUANG := Color("#cf8325")
const C_GOLD := Color("#c89333")
const C_GOLD_LIGHT := Color("#fae19c")
const C_BORDER := Color("#c9b593")

const FACTION_COLOR_MAP := {
	"bi": Color("#b83b32"),
	"mo": Color("#1e3a5f"),
	"yan": Color("#276f57"),
	"zhi": Color("#cf8325"),
}

const FACTION_NAME_MAP := {
	"bi": "笔",
	"mo": "墨",
	"yan": "砚",
	"zhi": "纸",
}

const ESTATE_TUTORIAL_STEPS := [
	{
		"title": "① 小院画卷与归属城",
		"desc": "小院随累计军功升至 1–3 级。轻点左下角城池名可直飞沙盘查看驻防；长按画卷可复制战绩分享给同窗。",
		"btn": "下一步 (1/3)",
	},
	{
		"title": "② 军功攒取与势力足迹",
		"desc": "出征攻城、驻守驰援都能积攒军功；点击“本周第 X”可看军功榜，点击下方城池足迹可定位对应战区。",
		"btn": "下一步 (2/3)",
	},
	{
		"title": "③ 升级三间文房厢房",
		"desc": "书房可预读明日手牌，练兵场拓展预设编成，望楼强化守城警示。所有升级只给便利，不破坏沙盘公平！",
		"btn": "开始打理小院",
	},
]

var estate_data: Dictionary = {}
var merit_data: Dictionary = {}
var me_data: Dictionary = {}
var selected_room_code: String = "study"
var is_upgrading: bool = false
var upgrading_room_code: String = ""
var displayed_merit_balance: float = 0.0
var last_layout_size: Vector2 = Vector2.ZERO
var last_dock_h: float = 46.0
var is_phone_mode: bool = false
var phone_drawer_open: bool = false
var last_celebrated_gov_key: String = ""

var _main_font: Font = null
var _drawer_tween: Tween
var _merit_tween: Tween

# 顶部标题栏
var header_bar: Panel
var header_sub_lbl: Label
var header_guide_btn: Button

# 两种响应式布局根节点（手机 720x514 / 平板 1400x1000）
var phone_root: MarginContainer
var tablet_root: MarginContainer

# 手机横屏控件引用
var ph_hero_panel: PanelContainer
var ph_hero_canvas: _CourtyardArtCanvas
var ph_lvl_lbl: Label
var ph_gov_btn: Button
var ph_city_link_btn: Button
var ph_exp_lbl: Label
var ph_exp_bar: ProgressBar
var ph_merit_card: PanelContainer
var ph_merit_num_lbl: Label
var ph_merit_sub_lbl: Label
var ph_rank_btn: Button
var ph_footprint_flow: HFlowContainer
var ph_footprint_empty_lbl: Label
var ph_room_cards: Dictionary = {}

# 平板双栏控件引用
var tb_left_col: VBoxContainer
var tb_hero_panel: PanelContainer
var tb_hero_canvas: _CourtyardArtCanvas
var tb_lvl_lbl: Label
var tb_gov_btn: Button
var tb_city_link_btn: Button
var tb_exp_lbl: Label
var tb_exp_bar: ProgressBar
var tb_room_cards: Dictionary = {}
var tb_merit_card: PanelContainer
var tb_merit_num_lbl: Label
var tb_merit_sub_lbl: Label
var tb_rank_btn: Button
var tb_gov_card: PanelContainer
var tb_gov_title_lbl: Label
var tb_gov_desc_lbl: Label
var tb_gov_focus_btn: Button
var tb_footprint_flow: HFlowContainer
var tb_footprint_empty_lbl: Label
var tb_detail_card: PanelContainer
var tb_detail_art: _RoomArtCanvas
var tb_detail_title_lbl: Label
var tb_detail_lvl_lbl: Label
var tb_detail_cur_lbl: Label
var tb_detail_next_lbl: Label
var tb_detail_cost_lbl: Label
var tb_detail_btn: Button

# 手机端 52% 上滑房间详情抽屉
var drawer_scrim: ColorRect
var drawer_panel: PanelContainer
var drawer_art: _RoomArtCanvas
var drawer_title_lbl: Label
var drawer_lvl_lbl: Label
var drawer_cur_lbl: Label
var drawer_next_lbl: Label
var drawer_cost_lbl: Label
var drawer_cancel_btn: Button
var drawer_confirm_btn: Button

# 军功排行榜浮层
var rank_overlay: Control
var rank_modal: PanelContainer
var rank_tab_week_btn: Button
var rank_tab_total_btn: Button
var rank_list_vbox: VBoxContainer
var rank_self_lbl: Label
var rank_mode: String = "week"

# 首次进入 3 步教学浮层
var tut_overlay: Control
var tut_title_lbl: Label
var tut_desc_lbl: Label
var tut_next_btn: Button
var tut_skip_btn: Button
var tut_step_idx: int = 0

# 太守当选庆祝横幅
var gov_banner: PanelContainer
var gov_banner_lbl: Label
var _gov_banner_tween: Tween


func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_main_font = load(FONT_PATH)
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG_DESK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_header()
	_build_phone_layout()
	_build_tablet_layout()
	_build_mobile_drawer()
	_build_rank_modal()
	_build_tutorial_overlay()
	_build_gov_banner()


func _build_header() -> void:
	header_bar = Panel.new()
	header_bar.add_theme_stylebox_override("panel", _style(Color("#1a1410"), C_GOLD, 0, 0))
	add_child(header_bar)

	var gold_bar := ColorRect.new()
	gold_bar.color = C_GOLD
	gold_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	gold_bar.offset_top = -2
	gold_bar.offset_bottom = 0
	header_bar.add_child(gold_bar)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	header_bar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var back_btn := _button("← 返回沙盘", Color("#423429"), 38)
	back_btn.custom_minimum_size = Vector2(104, 38)
	back_btn.pressed.connect(func(): back_to_map_requested.emit())
	row.add_child(back_btn)

	var title_lbl := _label("🏡 文房小院", 18, C_GOLD_LIGHT, true)
	row.add_child(title_lbl)

	header_sub_lbl = _label("· 城池宅院", 13, Color("#bfa98d"))
	header_sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_sub_lbl.clip_text = true
	header_sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(header_sub_lbl)

	header_guide_btn = _pill_button("? 引导", Color("#2d2219"), C_GOLD, 34)
	header_guide_btn.custom_minimum_size = Vector2(82, 34)
	header_guide_btn.pressed.connect(func(): show_tutorial(true))
	row.add_child(header_guide_btn)


func _build_phone_layout() -> void:
	phone_root = MarginContainer.new()
	phone_root.name = "EstatePhoneRoot"
	phone_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phone_root.offset_top = 64.0
	phone_root.add_theme_constant_override("margin_left", 12)
	phone_root.add_theme_constant_override("margin_right", 12)
	phone_root.add_theme_constant_override("margin_top", 10)
	phone_root.add_theme_constant_override("margin_bottom", 10)
	add_child(phone_root)

	var v_stack := VBoxContainer.new()
	v_stack.add_theme_constant_override("separation", 10)
	phone_root.add_child(v_stack)

	# 顶部两张并排主卡（左 410×182 小院画卷，右 276×182 军功+足迹合并卡）
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_row.size_flags_stretch_ratio = 182
	v_stack.add_child(top_row)

	# 左卡：小院主图
	ph_hero_panel = PanelContainer.new()
	ph_hero_panel.name = "PhoneHeroCard"
	ph_hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph_hero_panel.size_flags_stretch_ratio = 410
	ph_hero_panel.clip_contents = true
	ph_hero_panel.add_theme_stylebox_override("panel", _style(Color("#efe5d3"), C_GOLD, 2, 10, 0))
	top_row.add_child(ph_hero_panel)

	var ph_hero_layers := Control.new()
	ph_hero_layers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ph_hero_panel.add_child(ph_hero_layers)

	ph_hero_canvas = _CourtyardArtCanvas.new(_main_font)
	ph_hero_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_attach_long_press(ph_hero_canvas, func(): _copy_share_text(), Callable())
	ph_hero_layers.add_child(ph_hero_canvas)

	var ph_top_badges := HBoxContainer.new()
	ph_top_badges.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	ph_top_badges.offset_left = 8
	ph_top_badges.offset_right = -8
	ph_top_badges.offset_top = 8
	ph_top_badges.offset_bottom = 36
	ph_top_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph_hero_layers.add_child(ph_top_badges)

	var lvl_pill := PanelContainer.new()
	lvl_pill.add_theme_stylebox_override("panel", _style(Color("#241912", 0.90), C_GOLD, 1, 12, 5))
	ph_lvl_lbl = _label("★ Lv.1", 12, C_GOLD_LIGHT, true)
	lvl_pill.add_child(ph_lvl_lbl)
	ph_top_badges.add_child(lvl_pill)

	var sp_top := Control.new()
	sp_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph_top_badges.add_child(sp_top)

	ph_gov_btn = _pill_button("▲ 本周太守", Color("#7c2419", 0.94), C_GOLD_LIGHT, 26)
	ph_gov_btn.add_theme_font_size_override("font_size", 11)
	ph_gov_btn.visible = false
	ph_gov_btn.pressed.connect(func(): _on_first_gov_city_clicked())
	ph_top_badges.add_child(ph_gov_btn)

	# 底部压暗带：归属城跳转 + 经验进度条
	var ph_bot_bar := PanelContainer.new()
	ph_bot_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ph_bot_bar.offset_top = -44
	ph_bot_bar.offset_bottom = 0
	ph_bot_bar.add_theme_stylebox_override("panel", _style(Color(0.11, 0.08, 0.06, 0.86), Color.TRANSPARENT, 0, 0, 6))
	ph_hero_layers.add_child(ph_bot_bar)

	var ph_bot_h := HBoxContainer.new()
	ph_bot_h.add_theme_constant_override("separation", 8)
	ph_bot_bar.add_child(ph_bot_h)

	ph_city_link_btn = Button.new()
	ph_city_link_btn.text = "● 归属城 ↗"
	ph_city_link_btn.flat = true
	ph_city_link_btn.add_theme_font_size_override("font_size", 12)
	ph_city_link_btn.add_theme_color_override("font_color", C_GOLD_LIGHT)
	ph_city_link_btn.add_theme_color_override("font_hover_color", Color("#ffffff"))
	ph_city_link_btn.pressed.connect(func():
		var hcode := str(estate_data.get("home_node", {}).get("code", ""))
		if hcode != "":
			focus_city_requested.emit(hcode)
	)
	ph_bot_h.add_child(ph_city_link_btn)

	var exp_v := VBoxContainer.new()
	exp_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_v.alignment = BoxContainer.ALIGNMENT_CENTER
	exp_v.add_theme_constant_override("separation", 3)
	ph_bot_h.add_child(exp_v)

	ph_exp_lbl = _label("经验 0/100", 11, Color("#e8dcc5"))
	ph_exp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	exp_v.add_child(ph_exp_lbl)

	ph_exp_bar = _create_gold_progress_bar(5.0)
	exp_v.add_child(ph_exp_bar)

	# 右卡：可用军功 + 势力足迹合并卡 (276×182)
	ph_merit_card = PanelContainer.new()
	ph_merit_card.name = "PhoneMeritCard"
	ph_merit_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph_merit_card.size_flags_stretch_ratio = 276
	ph_merit_card.add_theme_stylebox_override("panel", _style(C_XUANZHI, C_BORDER, 2, 10, 10))
	top_row.add_child(ph_merit_card)

	var ph_m_v := VBoxContainer.new()
	ph_m_v.add_theme_constant_override("separation", 4)
	ph_merit_card.add_child(ph_m_v)

	var ph_m_top := HBoxContainer.new()
	ph_m_top.add_theme_constant_override("separation", 6)
	ph_m_v.add_child(ph_m_top)

	var ph_m_lbl := _label("可用军功", 12, C_MUTED)
	ph_m_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph_m_top.add_child(ph_m_lbl)

	ph_rank_btn = _pill_button("本周第 - ↗", Color("#efe2c6"), C_GOLD, 24)
	ph_rank_btn.add_theme_font_size_override("font_size", 11)
	ph_rank_btn.add_theme_color_override("font_color", Color("#7c4d10"))
	ph_rank_btn.pressed.connect(func(): merit_rank_requested.emit())
	ph_m_top.add_child(ph_rank_btn)

	var ph_num_row := HBoxContainer.new()
	ph_num_row.add_theme_constant_override("separation", 8)
	ph_m_v.add_child(ph_num_row)

	ph_merit_num_lbl = _label("0", 26, C_ZHUSHA, true)
	ph_num_row.add_child(ph_merit_num_lbl)

	ph_merit_sub_lbl = _label("累计 0", 11, C_MUTED)
	ph_merit_sub_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	ph_num_row.add_child(ph_merit_sub_lbl)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color("#d8c8ad"))
	ph_m_v.add_child(sep)

	var fp_title := _label("势力足迹（点定位·长按看贡献）", 10, C_MUTED)
	ph_m_v.add_child(fp_title)

	ph_footprint_flow = HFlowContainer.new()
	ph_footprint_flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ph_footprint_flow.add_theme_constant_override("h_separation", 6)
	ph_footprint_flow.add_theme_constant_override("v_separation", 4)
	ph_m_v.add_child(ph_footprint_flow)

	ph_footprint_empty_lbl = _label("尚无出征足迹 · 前往沙盘积累军功", 11, Color("#8f7e6a"))
	ph_footprint_empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ph_m_v.add_child(ph_footprint_empty_lbl)

	# 底部行：3 间房间卡 (225×192 ×3)
	var rooms_row := HBoxContainer.new()
	rooms_row.add_theme_constant_override("separation", 10)
	rooms_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rooms_row.size_flags_stretch_ratio = 192
	v_stack.add_child(rooms_row)

	for rcode in ["study", "drill", "tower"]:
		var card := _create_room_card(rcode, true)
		rooms_row.add_child(card["panel"])
		ph_room_cards[rcode] = card


func _build_tablet_layout() -> void:
	tablet_root = MarginContainer.new()
	tablet_root.name = "EstateTabletRoot"
	tablet_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tablet_root.offset_top = 64.0
	tablet_root.add_theme_constant_override("margin_left", 20)
	tablet_root.add_theme_constant_override("margin_right", 20)
	tablet_root.add_theme_constant_override("margin_top", 20)
	tablet_root.add_theme_constant_override("margin_bottom", 20)
	add_child(tablet_root)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	tablet_root.add_child(cols)

	# 左栏 62% (834×836)：主图 544px + 3 房间卡 276px
	tb_left_col = VBoxContainer.new()
	tb_left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_left_col.size_flags_stretch_ratio = 834
	tb_left_col.add_theme_constant_override("separation", 16)
	cols.add_child(tb_left_col)

	tb_hero_panel = PanelContainer.new()
	tb_hero_panel.name = "TabletHeroCard"
	tb_hero_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tb_hero_panel.clip_contents = true
	tb_hero_panel.add_theme_stylebox_override("panel", _style(Color("#efe5d3"), C_GOLD, 2, 12, 0))
	tb_left_col.add_child(tb_hero_panel)

	var tb_hero_layers := Control.new()
	tb_hero_layers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tb_hero_panel.add_child(tb_hero_layers)

	tb_hero_canvas = _CourtyardArtCanvas.new(_main_font)
	tb_hero_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_attach_long_press(tb_hero_canvas, func(): _copy_share_text(), Callable())
	tb_hero_layers.add_child(tb_hero_canvas)

	var tb_top_row := HBoxContainer.new()
	tb_top_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tb_top_row.offset_left = 14
	tb_top_row.offset_right = -14
	tb_top_row.offset_top = 14
	tb_top_row.offset_bottom = 48
	tb_top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tb_hero_layers.add_child(tb_top_row)

	var tb_lvl_pill := PanelContainer.new()
	tb_lvl_pill.add_theme_stylebox_override("panel", _style(Color("#241912", 0.92), C_GOLD, 1, 14, 6))
	tb_lvl_lbl = _label("★ Lv.1 · 文房初立", 14, C_GOLD_LIGHT, true)
	tb_lvl_pill.add_child(tb_lvl_lbl)
	tb_top_row.add_child(tb_lvl_pill)

	var sp_tb := Control.new()
	sp_tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp_tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tb_top_row.add_child(sp_tb)

	tb_gov_btn = _pill_button("▲ 本周太守", Color("#802419", 0.95), C_GOLD_LIGHT, 32)
	tb_gov_btn.visible = false
	tb_gov_btn.pressed.connect(func(): _on_first_gov_city_clicked())
	tb_top_row.add_child(tb_gov_btn)

	# 底部渐变条：归属城定位 + 长按分享提示 + 经验条
	var tb_bot := PanelContainer.new()
	tb_bot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tb_bot.offset_top = -62
	tb_bot.offset_bottom = 0
	tb_bot.add_theme_stylebox_override("panel", _style(Color(0.11, 0.08, 0.06, 0.86), Color.TRANSPARENT, 0, 0, 12))
	tb_hero_layers.add_child(tb_bot)

	var tb_bot_h := HBoxContainer.new()
	tb_bot_h.add_theme_constant_override("separation", 14)
	tb_bot.add_child(tb_bot_h)

	var left_meta := VBoxContainer.new()
	left_meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_meta.add_theme_constant_override("separation", 2)
	tb_bot_h.add_child(left_meta)

	tb_city_link_btn = Button.new()
	tb_city_link_btn.text = "● 归属：-- ↗"
	tb_city_link_btn.flat = true
	tb_city_link_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tb_city_link_btn.add_theme_font_size_override("font_size", 14)
	tb_city_link_btn.add_theme_color_override("font_color", C_GOLD_LIGHT)
	tb_city_link_btn.add_theme_color_override("font_hover_color", Color("#ffffff"))
	tb_city_link_btn.pressed.connect(func():
		var hcode := str(estate_data.get("home_node", {}).get("code", ""))
		if hcode != "":
			focus_city_requested.emit(hcode)
	)
	left_meta.add_child(tb_city_link_btn)

	var share_hint := _label("长按庭院画卷 0.5 秒可复制战绩分享", 11, Color("#cdbba2"))
	left_meta.add_child(share_hint)

	var right_exp := VBoxContainer.new()
	right_exp.custom_minimum_size = Vector2(280, 0)
	right_exp.alignment = BoxContainer.ALIGNMENT_CENTER
	right_exp.add_theme_constant_override("separation", 6)
	tb_bot_h.add_child(right_exp)

	tb_exp_lbl = _label("小院晋升进度：0 / 100", 12, Color("#f2e4cc"))
	tb_exp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_exp.add_child(tb_exp_lbl)

	tb_exp_bar = _create_gold_progress_bar(8.0)
	right_exp.add_child(tb_exp_bar)

	# 左栏下方：3 间厢房卡 (267×276 ×3)
	var tb_rooms_row := HBoxContainer.new()
	tb_rooms_row.custom_minimum_size.y = 276
	tb_rooms_row.add_theme_constant_override("separation", 16)
	tb_left_col.add_child(tb_rooms_row)

	for rcode in ["study", "drill", "tower"]:
		var card := _create_room_card(rcode, false)
		tb_rooms_row.add_child(card["panel"])
		tb_room_cards[rcode] = card

	# 右栏 38% (510×836)：军功卡 + 条件太守卡 + 足迹卡 + 常驻房间详情卡
	var tb_right := VBoxContainer.new()
	tb_right.custom_minimum_size.x = 510
	tb_right.size_flags_horizontal = Control.SIZE_FILL
	tb_right.size_flags_stretch_ratio = 510
	tb_right.add_theme_constant_override("separation", 12)
	cols.add_child(tb_right)

	# 1. 军功卡 (124px)
	tb_merit_card = PanelContainer.new()
	tb_merit_card.name = "TabletMeritCard"
	tb_merit_card.custom_minimum_size = Vector2(0, 124)
	tb_merit_card.add_theme_stylebox_override("panel", _style(C_XUANZHI, C_BORDER, 2, 12, 14))
	tb_right.add_child(tb_merit_card)

	var m_box := VBoxContainer.new()
	m_box.add_theme_constant_override("separation", 8)
	tb_merit_card.add_child(m_box)

	var m_top := HBoxContainer.new()
	m_top.add_theme_constant_override("separation", 8)
	m_box.add_child(m_top)

	var m_title := _label("我的可用军功", 14, C_MUTED, true)
	m_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_top.add_child(m_title)

	tb_rank_btn = _pill_button("🏆 本周第 - · 军功榜 ↗", Color("#efe2c6"), C_GOLD, 30)
	tb_rank_btn.add_theme_color_override("font_color", Color("#7c4d10"))
	tb_rank_btn.pressed.connect(func(): merit_rank_requested.emit())
	m_top.add_child(tb_rank_btn)

	var m_bot := HBoxContainer.new()
	m_bot.add_theme_constant_override("separation", 16)
	m_box.add_child(m_bot)

	tb_merit_num_lbl = _label("0", 36, C_ZHUSHA, true)
	m_bot.add_child(tb_merit_num_lbl)

	tb_merit_sub_lbl = _label("累计军功：0   |   已投入修缮：0", 13, C_MUTED)
	tb_merit_sub_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m_bot.add_child(tb_merit_sub_lbl)

	# 2. 条件太守卡 (104px，无任职时自动隐藏)
	tb_gov_card = PanelContainer.new()
	tb_gov_card.name = "TabletGovernorCard"
	tb_gov_card.custom_minimum_size = Vector2(0, 104)
	tb_gov_card.visible = false
	tb_gov_card.add_theme_stylebox_override("panel", _style(Color("#fbf0d7"), C_GOLD, 2, 12, 14))
	tb_right.add_child(tb_gov_card)

	var g_h := HBoxContainer.new()
	g_h.add_theme_constant_override("separation", 12)
	tb_gov_card.add_child(g_h)

	var g_badge := PanelContainer.new()
	g_badge.custom_minimum_size = Vector2(68, 68)
	g_badge.add_theme_stylebox_override("panel", _style(C_ZHUSHA, C_GOLD_LIGHT, 2, 10, 6))
	var g_badge_lbl := _label("▲\n太守", 15, C_GOLD_LIGHT, true)
	g_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g_badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g_badge.add_child(g_badge_lbl)
	g_h.add_child(g_badge)

	var g_v := VBoxContainer.new()
	g_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g_v.alignment = BoxContainer.ALIGNMENT_CENTER
	g_v.add_theme_constant_override("separation", 4)
	g_h.add_child(g_v)

	tb_gov_title_lbl = _label("本周太守 · --", 16, C_ZHUSHA, true)
	g_v.add_child(tb_gov_title_lbl)

	tb_gov_desc_lbl = _label("你在该城累计军功位居阵营前列", 12, C_MUTED)
	tb_gov_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g_v.add_child(tb_gov_desc_lbl)

	tb_gov_focus_btn = _pill_button("定位 ↗", Color("#efe2c6"), C_ZHUSHA, 34)
	tb_gov_focus_btn.add_theme_color_override("font_color", C_ZHUSHA)
	tb_gov_focus_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tb_gov_focus_btn.pressed.connect(func(): _on_first_gov_city_clicked())
	g_h.add_child(tb_gov_focus_btn)

	# 3. 势力足迹卡 (176px)
	var fp_card := PanelContainer.new()
	fp_card.name = "TabletFootprintCard"
	fp_card.custom_minimum_size = Vector2(0, 176)
	fp_card.add_theme_stylebox_override("panel", _style(C_XUANZHI, C_BORDER, 2, 12, 14))
	tb_right.add_child(fp_card)

	var fp_v := VBoxContainer.new()
	fp_v.add_theme_constant_override("separation", 8)
	fp_card.add_child(fp_v)

	var fp_head := HBoxContainer.new()
	fp_v.add_child(fp_head)
	var fp_h_lbl := _label("势力足迹", 14, C_INK, true)
	fp_h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fp_head.add_child(fp_h_lbl)
	fp_head.add_child(_label("单击定位 · 长按看贡献", 11, C_MUTED))

	var fp_scroll := ScrollContainer.new()
	fp_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fp_v.add_child(fp_scroll)

	var fp_holder := VBoxContainer.new()
	fp_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fp_scroll.add_child(fp_holder)

	tb_footprint_flow = HFlowContainer.new()
	tb_footprint_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_footprint_flow.add_theme_constant_override("h_separation", 8)
	tb_footprint_flow.add_theme_constant_override("v_separation", 8)
	fp_holder.add_child(tb_footprint_flow)

	tb_footprint_empty_lbl = _label("尚无出征足迹 · 在沙盘点击城池下达军令即可记入足迹", 12, Color("#8f7e6a"))
	tb_footprint_empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fp_holder.add_child(tb_footprint_empty_lbl)

	# 4. 常驻房间详情与升级卡 (EXPAND_FILL, min 396px)
	tb_detail_card = PanelContainer.new()
	tb_detail_card.name = "TabletRoomDetailCard"
	tb_detail_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tb_detail_card.custom_minimum_size = Vector2(0, 340)
	tb_detail_card.add_theme_stylebox_override("panel", _style(C_XUANZHI, C_GOLD, 2, 12, 16))
	tb_right.add_child(tb_detail_card)

	var det_v := VBoxContainer.new()
	det_v.add_theme_constant_override("separation", 12)
	tb_detail_card.add_child(det_v)

	var det_head := HBoxContainer.new()
	det_head.add_theme_constant_override("separation", 14)
	det_v.add_child(det_head)

	tb_detail_art = _RoomArtCanvas.new(_main_font)
	tb_detail_art.custom_minimum_size = Vector2(88, 88)
	det_head.add_child(tb_detail_art)

	var det_title_v := VBoxContainer.new()
	det_title_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det_title_v.alignment = BoxContainer.ALIGNMENT_CENTER
	det_title_v.add_theme_constant_override("separation", 6)
	det_head.add_child(det_title_v)

	tb_detail_title_lbl = _label("📖 书房", 20, C_INK, true)
	det_title_v.add_child(tb_detail_title_lbl)

	tb_detail_lvl_lbl = _label("Lv.0 ➔ Lv.1", 14, C_ZHUQING, true)
	det_title_v.add_child(tb_detail_lvl_lbl)

	var cur_box := PanelContainer.new()
	cur_box.add_theme_stylebox_override("panel", _style(C_XUANZHI_SOFT, Color("#d4c3a4"), 1, 8, 10))
	det_v.add_child(cur_box)
	tb_detail_cur_lbl = _label("当前效果：--", 13, C_INK)
	tb_detail_cur_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cur_box.add_child(tb_detail_cur_lbl)

	var next_box := PanelContainer.new()
	next_box.add_theme_stylebox_override("panel", _style(Color("#eaf2eb"), C_ZHUQING, 1, 8, 10))
	det_v.add_child(next_box)
	tb_detail_next_lbl = _label("下级提升：--", 13, C_ZHUQING, true)
	tb_detail_next_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_box.add_child(tb_detail_next_lbl)

	tb_detail_cost_lbl = _label("升级消耗：--", 13, C_MUTED)
	det_v.add_child(tb_detail_cost_lbl)

	var det_sp := Control.new()
	det_sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	det_v.add_child(det_sp)

	tb_detail_btn = _button("确认升级", C_ZHUSHA, 52)
	tb_detail_btn.add_theme_font_size_override("font_size", 16)
	tb_detail_btn.pressed.connect(func(): _trigger_room_upgrade(selected_room_code))
	det_v.add_child(tb_detail_btn)


func _create_room_card(rcode: String, compact: bool) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "RoomCard_%s_%s" % [rcode, "Phone" if compact else "Tablet"]
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pad := 8 if compact else 14
	panel.add_theme_stylebox_override("panel", _style(C_XUANZHI, C_BORDER, 2, 10, pad))
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_room_card_selected(rcode)
		elif ev is InputEventScreenTouch and ev.pressed:
			_on_room_card_selected(rcode)
	)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4 if compact else 10)
	panel.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	vb.add_child(head)

	var art := _RoomArtCanvas.new(_main_font)
	art.custom_minimum_size = Vector2(30, 30) if compact else Vector2(54, 54)
	head.add_child(art)

	var name_v := VBoxContainer.new()
	name_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_v.alignment = BoxContainer.ALIGNMENT_CENTER
	name_v.add_theme_constant_override("separation", 1 if compact else 2)
	head.add_child(name_v)

	var name_lbl := _label(rcode, 14 if compact else 16, C_INK, true)
	name_v.add_child(name_lbl)

	var pip_lbl := _label("Lv.0/3", 11 if compact else 12, C_GOLD, true)
	name_v.add_child(pip_lbl)

	var cur_lbl := _label("未建成", 11 if compact else 13, C_INK)
	cur_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cur_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cur_lbl.custom_minimum_size = Vector2(0, 30 if compact else 40)
	cur_lbl.clip_text = true
	vb.add_child(cur_lbl)

	var next_lbl := _label("下级：--", 10 if compact else 12, C_ZHUQING)
	next_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	next_lbl.size_flags_stretch_ratio = 0.85
	next_lbl.custom_minimum_size = Vector2(0, 26 if compact else 36)
	next_lbl.clip_text = true
	vb.add_child(next_lbl)

	var cta_btn := _button("升级", C_ZHUSHA, 36 if compact else 42)
	cta_btn.add_theme_font_size_override("font_size", 12 if compact else 14)
	cta_btn.pressed.connect(func(): _on_room_card_selected(rcode))
	vb.add_child(cta_btn)

	return {
		"panel": panel,
		"art": art,
		"name_lbl": name_lbl,
		"pip_lbl": pip_lbl,
		"cur_lbl": cur_lbl,
		"next_lbl": next_lbl,
		"cta_btn": cta_btn,
	}


func _build_mobile_drawer() -> void:
	drawer_scrim = ColorRect.new()
	drawer_scrim.name = "EstateDrawerScrim"
	drawer_scrim.color = Color(0.06, 0.04, 0.03, 0.56)
	drawer_scrim.visible = false
	drawer_scrim.z_index = 20
	drawer_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	drawer_scrim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_phone_drawer()
		elif ev is InputEventScreenTouch and ev.pressed:
			close_phone_drawer()
	)
	add_child(drawer_scrim)

	drawer_panel = PanelContainer.new()
	drawer_panel.name = "EstatePhoneDrawer"
	drawer_panel.visible = false
	drawer_panel.z_index = 21
	drawer_panel.add_theme_stylebox_override("panel", _style(C_XUANZHI, C_GOLD, 2, 14, 14))
	add_child(drawer_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	drawer_panel.add_child(v)

	# 顶部把手条
	var handle_center := CenterContainer.new()
	v.add_child(handle_center)
	var handle := Panel.new()
	handle.custom_minimum_size = Vector2(44, 4)
	handle.add_theme_stylebox_override("panel", _style(Color("#cbb799"), Color.TRANSPARENT, 0, 2, 0))
	handle_center.add_child(handle)

	# 内容区：96×96 图示 + 对比描述
	var main_h := HBoxContainer.new()
	main_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_h.add_theme_constant_override("separation", 14)
	v.add_child(main_h)

	drawer_art = _RoomArtCanvas.new(_main_font)
	drawer_art.custom_minimum_size = Vector2(96, 96)
	drawer_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_h.add_child(drawer_art)

	var info_v := VBoxContainer.new()
	info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_v.add_theme_constant_override("separation", 4)
	main_h.add_child(info_v)

	var title_h := HBoxContainer.new()
	title_h.add_theme_constant_override("separation", 10)
	info_v.add_child(title_h)

	drawer_title_lbl = _label("书房", 18, C_INK, true)
	title_h.add_child(drawer_title_lbl)

	drawer_lvl_lbl = _label("Lv.1 ➔ Lv.2", 14, C_ZHUQING, true)
	title_h.add_child(drawer_lvl_lbl)

	drawer_cur_lbl = _label("当前效果：--", 12, C_INK)
	drawer_cur_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drawer_cur_lbl.clip_text = true
	drawer_cur_lbl.custom_minimum_size = Vector2(0, 34)
	info_v.add_child(drawer_cur_lbl)

	drawer_next_lbl = _label("升级效果：--", 12, C_ZHUQING, true)
	drawer_next_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drawer_next_lbl.clip_text = true
	drawer_next_lbl.custom_minimum_size = Vector2(0, 34)
	info_v.add_child(drawer_next_lbl)

	drawer_cost_lbl = _label("升级消耗：--", 12, C_MUTED)
	info_v.add_child(drawer_cost_lbl)

	# 底部双按钮行 (46px)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	v.add_child(btn_row)

	drawer_cancel_btn = _button("取消", Color("#5e5042"), 46)
	drawer_cancel_btn.custom_minimum_size = Vector2(140, 46)
	drawer_cancel_btn.pressed.connect(func(): close_phone_drawer())
	btn_row.add_child(drawer_cancel_btn)

	drawer_confirm_btn = _button("确认升级", C_ZHUSHA, 46)
	drawer_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_confirm_btn.pressed.connect(func(): _trigger_room_upgrade(selected_room_code))
	btn_row.add_child(drawer_confirm_btn)


func _build_rank_modal() -> void:
	rank_overlay = ColorRect.new()
	rank_overlay.name = "EstateRankOverlay"
	rank_overlay.color = Color(0.05, 0.04, 0.03, 0.72)
	rank_overlay.visible = false
	rank_overlay.z_index = 25
	rank_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rank_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			rank_overlay.visible = false
	)
	add_child(rank_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rank_overlay.add_child(center)

	rank_modal = PanelContainer.new()
	rank_modal.custom_minimum_size = Vector2(460, 380)
	rank_modal.add_theme_stylebox_override("panel", _style(C_XUANZHI, C_GOLD, 2, 12, 16))
	rank_modal.gui_input.connect(func(_ev: InputEvent): accept_event())
	center.add_child(rank_modal)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	rank_modal.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)

	var title := _label("🏆 军功风云榜 Top 10", 17, C_INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var close_btn := _pill_button("✕", Color("#4e3f32"), C_BORDER, 30)
	close_btn.custom_minimum_size = Vector2(36, 30)
	close_btn.pressed.connect(func(): rank_overlay.visible = false)
	head.add_child(close_btn)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)

	rank_tab_week_btn = _pill_button("本周军功榜", C_ZHUSHA, C_GOLD, 32)
	rank_tab_week_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_tab_week_btn.pressed.connect(func():
		rank_mode = "week"
		_render_rank_list()
	)
	tabs.add_child(rank_tab_week_btn)

	rank_tab_total_btn = _pill_button("赛季总军功", Color("#3b2f26"), C_BORDER, 32)
	rank_tab_total_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_tab_total_btn.pressed.connect(func():
		rank_mode = "total"
		_render_rank_list()
	)
	tabs.add_child(rank_tab_total_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)

	rank_list_vbox = VBoxContainer.new()
	rank_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(rank_list_vbox)

	var self_box := PanelContainer.new()
	self_box.add_theme_stylebox_override("panel", _style(Color("#efe2c6"), C_GOLD, 1, 8, 8))
	v.add_child(self_box)
	rank_self_lbl = _label("我的排名：第 - 名 · 本周 0 军功", 13, C_ZHUSHA, true)
	rank_self_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	self_box.add_child(rank_self_lbl)


func _build_tutorial_overlay() -> void:
	tut_overlay = ColorRect.new()
	tut_overlay.name = "EstateTutorialOverlay"
	tut_overlay.color = Color(0.05, 0.04, 0.03, 0.72)
	tut_overlay.visible = false
	tut_overlay.z_index = 28
	tut_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tut_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tut_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 220)
	card.add_theme_stylebox_override("panel", _style(C_XUANZHI, C_GOLD, 2, 12, 18))
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	tut_title_lbl = _label("🏡 文房小院导览", 18, C_ZHUSHA, true)
	v.add_child(tut_title_lbl)

	tut_desc_lbl = _label("--", 14, C_INK)
	tut_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tut_desc_lbl)

	var btn_h := HBoxContainer.new()
	btn_h.add_theme_constant_override("separation", 12)
	v.add_child(btn_h)

	tut_skip_btn = _button("跳过引导", Color("#5e5042"), 40)
	tut_skip_btn.custom_minimum_size = Vector2(110, 40)
	tut_skip_btn.pressed.connect(func(): _finish_tutorial())
	btn_h.add_child(tut_skip_btn)

	tut_next_btn = _button("下一步", C_ZHUQING, 40)
	tut_next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tut_next_btn.pressed.connect(func(): _advance_tutorial())
	btn_h.add_child(tut_next_btn)


func _build_gov_banner() -> void:
	gov_banner = PanelContainer.new()
	gov_banner.name = "EstateGovernorBanner"
	gov_banner.visible = false
	gov_banner.z_index = 15
	gov_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gov_banner.add_theme_stylebox_override("panel", _style(Color("#7c2419", 0.96), C_GOLD_LIGHT, 2, 10, 10))
	add_child(gov_banner)

	gov_banner_lbl = _label("🏛 荣膺本周太守！", 14, C_GOLD_LIGHT, true)
	gov_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gov_banner.add_child(gov_banner_lbl)


# ---------------------------------------------------------------------------
# 公开状态同步、布局适配与页面生命周期接口
# ---------------------------------------------------------------------------

func layout_responsive(viewport_size: Vector2, dock_h: float) -> void:
	last_layout_size = viewport_size
	last_dock_h = dock_h
	var w := viewport_size.x
	var h := viewport_size.y
	if w <= 0.0 or h <= 0.0:
		return

	position = Vector2.ZERO
	size = Vector2(w, maxf(h - dock_h, 200.0))

	if header_bar != null:
		header_bar.position = Vector2.ZERO
		header_bar.size = Vector2(w, 64.0)

	is_phone_mode = (w < 900.0 or h < 650.0)
	if phone_root != null:
		phone_root.visible = is_phone_mode
		phone_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		phone_root.offset_top = 64.0

	if tablet_root != null:
		tablet_root.visible = not is_phone_mode
		tablet_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tablet_root.offset_top = 64.0

	if not is_phone_mode and phone_drawer_open:
		close_phone_drawer(true)

	# 手机抽屉覆盖包括 Dock 在内的底部 52% 全屏区域（720×514 下为 720×267）
	if drawer_scrim != null:
		drawer_scrim.position = Vector2.ZERO
		drawer_scrim.size = viewport_size
	if drawer_panel != null:
		var drawer_h := roundf(h * 0.52)
		drawer_panel.size = Vector2(w, drawer_h)
		if phone_drawer_open:
			drawer_panel.position = Vector2(0, h - drawer_h)
		else:
			drawer_panel.position = Vector2(0, h)

	if rank_modal != null:
		var mw := minf(w - 32.0, 520.0)
		var mh := minf(h - 32.0, 440.0)
		rank_modal.custom_minimum_size = Vector2(mw, mh)

	if gov_banner != null:
		var bw := minf(w - 32.0, 520.0)
		gov_banner.size = Vector2(bw, 44.0)
		gov_banner.position = Vector2((w - bw) / 2.0, 128.0)


func set_estate_state(data: Dictionary, me: Dictionary, merit_summary: Dictionary = {}) -> void:
	var old_level := int(estate_data.get("level", 0))
	if not data.is_empty():
		estate_data = data.duplicate(true)
	if not me.is_empty():
		me_data = me.duplicate(true)
	if not merit_summary.is_empty():
		for k in merit_summary.keys():
			if k == "rank":
				merit_data["my_rank"] = merit_summary[k]
			else:
				merit_data[k] = merit_summary[k]
	var new_level := int(estate_data.get("level", 1))
	if old_level > 0 and new_level > old_level and visible:
		AudioManager.play_sfx("victory")
		toast_requested.emit("🎉 文房小院晋升至 Lv.%d！院落气象焕然一新！" % new_level, false)

	_refresh_views()
	_check_governor_celebration()


func set_merit_leaderboard(data: Dictionary) -> void:
	merit_data = data.duplicate(true)
	var me_val: Variant = merit_data.get("me", null)
	if typeof(me_val) == TYPE_DICTIONARY:
		for k in ["total", "week", "week_no", "rank", "week_rank"]:
			if me_val.has(k):
				merit_data[k] = me_val[k]
		if me_val.has("rank"):
			merit_data["my_rank"] = me_val["rank"]
	_refresh_rank_pill()
	if rank_overlay != null and rank_overlay.visible:
		_render_rank_list()


func open_leaderboard() -> void:
	if rank_overlay != null:
		rank_overlay.visible = true
		_render_rank_list()


func on_entered_page() -> void:
	if is_inside_tree():
		_check_governor_celebration()
		if not _is_tutorial_completed():
			show_tutorial(false)


func on_exited_page() -> void:
	close_phone_drawer(true)
	if rank_overlay != null:
		rank_overlay.visible = false
	if tut_overlay != null:
		tut_overlay.visible = false
	if gov_banner != null:
		gov_banner.visible = false


func on_upgrade_result(ok: bool, data: Dictionary, _err: Dictionary) -> void:
	var finished_room := upgrading_room_code if upgrading_room_code != "" else selected_room_code
	is_upgrading = false
	upgrading_room_code = ""

	if not ok:
		_refresh_detail_and_cards()
		return

	var new_estate_val: Variant = data.get("estate", data if data.has("rooms") else null)
	var old_balance := displayed_merit_balance
	if typeof(new_estate_val) == TYPE_DICTIONARY and not new_estate_val.is_empty():
		set_estate_state(new_estate_val, me_data)
	else:
		_refresh_views()

	var target_bal := float(estate_data.get("merit_balance", 0))
	_animate_merit_number(old_balance, target_bal)
	_animate_upgrade_success(finished_room)
	AudioManager.play_sfx("confirm")

	if phone_drawer_open:
		close_phone_drawer()


func flash_merit_card() -> void:
	var target := ph_merit_card if is_phone_mode else tb_merit_card
	if target == null:
		return
	target.add_theme_stylebox_override("panel", _style(Color("#fff9e8"), C_GOLD, 3, 12, 10 if is_phone_mode else 14))
	if not AudioManager.is_reduced_motion:
		target.pivot_offset = target.size / 2.0
		var tw := create_tween()
		tw.tween_property(target, "scale", Vector2(1.03, 1.03), 0.2).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(target, "scale", Vector2.ONE, 0.25)
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(target):
			target.add_theme_stylebox_override("panel", _style(C_XUANZHI, C_BORDER, 2, 10 if is_phone_mode else 12, 10 if is_phone_mode else 14))
	)


func open_phone_drawer_for(room_code: String) -> void:
	selected_room_code = room_code
	_refresh_detail_and_cards()
	if not is_phone_mode:
		return
	var need_anim := not phone_drawer_open
	phone_drawer_open = true
	if drawer_scrim != null:
		drawer_scrim.visible = true
	if drawer_panel != null:
		drawer_panel.visible = true
		var w := last_layout_size.x if last_layout_size.x > 0 else 720.0
		var h := last_layout_size.y if last_layout_size.y > 0 else 514.0
		var drawer_h := roundf(h * 0.52)
		drawer_panel.position.x = 0.0
		drawer_panel.size = Vector2(w, drawer_h)
		drawer_panel.set_deferred("size", Vector2(w, drawer_h))
		if need_anim and not AudioManager.is_reduced_motion:
			if is_instance_valid(_drawer_tween) and _drawer_tween.is_running():
				_drawer_tween.kill()
			drawer_panel.position.y = h
			_drawer_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_drawer_tween.tween_property(drawer_panel, "position:y", h - drawer_h, 0.22)
		else:
			drawer_panel.position.y = h - drawer_h
	_sync_parent_dock_for_drawer(true)


func close_phone_drawer(immediate: bool = false) -> void:
	if not phone_drawer_open and (drawer_panel == null or not drawer_panel.visible):
		return
	phone_drawer_open = false
	if drawer_scrim != null:
		drawer_scrim.visible = false
	var h := last_layout_size.y if last_layout_size.y > 0 else 514.0
	if drawer_panel != null:
		if immediate or AudioManager.is_reduced_motion:
			drawer_panel.visible = false
			drawer_panel.position.y = h
		else:
			if is_instance_valid(_drawer_tween) and _drawer_tween.is_running():
				_drawer_tween.kill()
			_drawer_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_drawer_tween.tween_property(drawer_panel, "position:y", h, 0.18)
			_drawer_tween.finished.connect(func():
				if not phone_drawer_open and is_instance_valid(drawer_panel):
					drawer_panel.visible = false
			)
	_sync_parent_dock_for_drawer(false)


func show_tutorial(force_restart: bool = false) -> void:
	if tut_overlay == null:
		return
	if force_restart or not _is_tutorial_completed():
		tut_step_idx = 0
		_render_tutorial_step()
		tut_overlay.visible = true


# ---------------------------------------------------------------------------
# 内部数据渲染与交互
# ---------------------------------------------------------------------------

func _refresh_views() -> void:
	var home_val: Variant = estate_data.get("home_node", {})
	var home: Dictionary = home_val if typeof(home_val) == TYPE_DICTIONARY else {}
	var home_name := str(home.get("name", "未定城池"))
	var home_code := str(home.get("code", ""))

	var faction_val: Variant = me_data.get("faction", {})
	var f_dict: Dictionary = faction_val if typeof(faction_val) == TYPE_DICTIONARY else {}
	var f_code := str(f_dict.get("code", "bi")).to_lower()
	var f_name := str(f_dict.get("name", FACTION_NAME_MAP.get(f_code, "中立")))
	var f_col: Color = FACTION_COLOR_MAP.get(f_code, C_ZHUSHA)

	if header_sub_lbl != null:
		var owner_txt := "%s阵营" % f_name if f_name != "" else "书院"
		header_sub_lbl.text = "· 归属 %s · %s" % [home_name, owner_txt]

	var level := int(estate_data.get("level", 1))
	var merit_total := int(estate_data.get("merit_total", 0))
	var merit_spent := int(estate_data.get("merit_spent", 0))
	var merit_bal := int(estate_data.get("merit_balance", 0))
	var next_at: Variant = estate_data.get("next_level_at", null)

	var gov_val: Variant = estate_data.get("governorships", [])
	var govs: Array = gov_val if typeof(gov_val) == TYPE_ARRAY else []

	# 刷新双端庭院主图与信息
	for canvas in [ph_hero_canvas, tb_hero_canvas]:
		if canvas != null:
			canvas.set_estate_visual(level, f_code, f_col, estate_data.get("rooms", []), govs)

	if ph_lvl_lbl != null:
		ph_lvl_lbl.text = "★ Lv.%d" % level
	if tb_lvl_lbl != null:
		var tier_titles := {1: "初筑小院", 2: "文轩雅舍", 3: "名门重檐"}
		tb_lvl_lbl.text = "★ Lv.%d · %s" % [level, str(tier_titles.get(level, "文房重地"))]

	if ph_city_link_btn != null:
		ph_city_link_btn.text = "● %s · %s阵营 ↗" % [home_name, f_name]
		ph_city_link_btn.disabled = (home_code == "")
	if tb_city_link_btn != null:
		tb_city_link_btn.text = "● 归属：%s（%s阵营） · 点击定位沙盘 ↗" % [home_name, f_name]
		tb_city_link_btn.disabled = (home_code == "")

	# 经验进度条
	var exp_text := "已达最高小院等级"
	var pct := 100.0
	if next_at != null and int(next_at) > 0:
		var cap := int(next_at)
		exp_text = "经验 %d/%d" % [merit_total, cap]
		pct = clampf(float(merit_total) / float(cap) * 100.0, 0.0, 100.0)
	if ph_exp_lbl != null:
		ph_exp_lbl.text = exp_text
	if tb_exp_lbl != null:
		tb_exp_lbl.text = ("小院升级进度：" + exp_text) if next_at != null else "小院 Lv.3 · 已臻文脉巅峰"
	for bar in [ph_exp_bar, tb_exp_bar]:
		if bar != null:
			bar.value = pct

	# 军功数值与太守区
	if not is_instance_valid(_merit_tween) or not _merit_tween.is_running():
		displayed_merit_balance = float(merit_bal)
		_set_merit_labels(merit_bal, merit_total, merit_spent)

	var has_gov := not govs.is_empty()
	var gov_city_names: Array[String] = []
	var gov_merit_sum := 0
	for g in govs:
		if typeof(g) == TYPE_DICTIONARY:
			gov_city_names.append(str(g.get("name", g.get("code", ""))))
			gov_merit_sum += int(g.get("merit", 0))

	if ph_gov_btn != null:
		ph_gov_btn.visible = has_gov
		if has_gov:
			ph_gov_btn.text = "▲ 本周太守·%s" % gov_city_names[0]
	if tb_gov_btn != null:
		tb_gov_btn.visible = has_gov
		if has_gov:
			tb_gov_btn.text = "▲ 本周太守·%s" % " / ".join(gov_city_names)
	if tb_gov_card != null:
		tb_gov_card.visible = has_gov
		if has_gov:
			tb_gov_title_lbl.text = "本周太守 · %s" % "、".join(gov_city_names)
			tb_gov_desc_lbl.text = "本城累计军功 %d · 领衔同阵营诸军守备" % gov_merit_sum

	_refresh_rank_pill()
	_refresh_footprints()
	_refresh_detail_and_cards()


func _set_merit_labels(bal: int, total: int, spent: int) -> void:
	if ph_merit_num_lbl != null:
		ph_merit_num_lbl.text = str(bal)
	if ph_merit_sub_lbl != null:
		ph_merit_sub_lbl.text = "累计 %d · 已用 %d" % [total, spent]
	if tb_merit_num_lbl != null:
		tb_merit_num_lbl.text = str(bal)
	if tb_merit_sub_lbl != null:
		tb_merit_sub_lbl.text = "累计军功：%d   |   已投入修缮：%d" % [total, spent]


func _refresh_rank_pill() -> void:
	var week_rank := int(merit_data.get("week_rank", merit_data.get("my_rank", 0)))
	var short_txt := ("本周第 %d ↗" % week_rank) if week_rank > 0 else "军功榜 ↗"
	var long_txt := ("🏆 本周第 %d · 军功榜 ↗" % week_rank) if week_rank > 0 else "🏆 本周军功榜 ↗"
	if ph_rank_btn != null:
		ph_rank_btn.text = short_txt
	if tb_rank_btn != null:
		tb_rank_btn.text = long_txt


func _refresh_footprints() -> void:
	var inf_val: Variant = estate_data.get("influence", [])
	var inf: Array = inf_val if typeof(inf_val) == TYPE_ARRAY else []

	for pair in [[ph_footprint_flow, ph_footprint_empty_lbl, true], [tb_footprint_flow, tb_footprint_empty_lbl, false]]:
		var flow: HFlowContainer = pair[0]
		var empty_lbl: Label = pair[1]
		var is_compact: bool = pair[2]
		if flow == null:
			continue
		for c in flow.get_children():
			flow.remove_child(c)
			c.queue_free()
		empty_lbl.visible = inf.is_empty()
		var max_chips := 4 if is_compact else 12
		var limit := mini(inf.size(), max_chips)
		for i in range(limit):
			var item: Variant = inf[i]
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var code := str(item.get("code", ""))
			var cname := str(item.get("name", code))
			var cnt := int(item.get("count", 0))
			var merit := int(item.get("merit", 0))
			var chip := Button.new()
			if is_compact:
				var short_name := cname.substr(0, 2)
				chip.text = "%s %d" % [short_name, merit]
				chip.custom_minimum_size = Vector2(58, 24)
				chip.add_theme_font_size_override("font_size", 11)
			else:
				chip.text = "● %s · %d军功(%d次)" % [cname, merit, cnt]
				chip.custom_minimum_size = Vector2(0, 30)
				chip.add_theme_font_size_override("font_size", 12)
			chip.add_theme_color_override("font_color", C_INK)
			chip.add_theme_stylebox_override("normal", _style(C_XUANZHI_SOFT, C_BORDER, 1, 14, 6))
			chip.add_theme_stylebox_override("hover", _style(Color("#f8edd6"), C_GOLD, 1, 14, 6))
			chip.tooltip_text = "%s：累计贡献 %d 军功（出征/驻守 %d 次），点击定位地图，长按或右键看明细" % [cname, merit, cnt]
			_attach_long_press(chip, func():
				toast_requested.emit("【%s】累计贡献 %d 军功（出征/驻守 %d 次）" % [cname, merit, cnt], false),
				func():
					if code != "":
						focus_city_requested.emit(code)
			)
			flow.add_child(chip)


func _refresh_detail_and_cards() -> void:
	var rooms_val: Variant = estate_data.get("rooms", [])
	var rooms: Array = rooms_val if typeof(rooms_val) == TYPE_ARRAY else []
	var rooms_by_code: Dictionary = {}
	for r in rooms:
		if typeof(r) == TYPE_DICTIONARY:
			rooms_by_code[str(r.get("code", ""))] = r

	var balance := int(estate_data.get("merit_balance", 0))
	if not rooms_by_code.has(selected_room_code) and not rooms.is_empty() and typeof(rooms[0]) == TYPE_DICTIONARY:
		selected_room_code = str(rooms[0].get("code", "study"))

	for md in [ph_room_cards, tb_room_cards]:
		var map_dict: Dictionary = md
		var is_compact: bool = (map_dict == ph_room_cards)
		for rc in map_dict.keys():
			var rcode := str(rc)
			var rdata: Dictionary = rooms_by_code.get(rcode, {
				"code": rcode,
				"name": _fallback_room_name(rcode),
				"level": 0,
				"max_level": 3,
				"effect": "暂未筑成",
				"next_effect": "修缮开启对应文房便利",
				"next_cost": 10,
			})
			var view: Dictionary = map_dict[rcode]
			var is_sel: bool = (rcode == selected_room_code)
			var lvl := int(rdata.get("level", 0))
			var max_lvl := int(rdata.get("max_level", 3))
			var cost_val: Variant = rdata.get("next_cost", null)
			var is_max := (lvl >= max_lvl or cost_val == null)
			var cost := int(cost_val) if cost_val != null else 0
			var can_afford := (not is_max) and (balance >= cost)

			var panel: PanelContainer = view["panel"]
			var pad := 10 if is_compact else 14
			var bg_col := Color("#fffaf0") if (is_sel and not is_compact) else C_XUANZHI
			var brd_col := C_ZHUSHA if (is_sel and not is_compact) else C_BORDER
			var brd_w := 3 if (is_sel and not is_compact) else 2
			panel.add_theme_stylebox_override("panel", _style(bg_col, brd_col, brd_w, 10, pad))

			var art: _RoomArtCanvas = view["art"]
			art.set_room(rcode, lvl)

			var name_lbl: Label = view["name_lbl"]
			name_lbl.text = str(rdata.get("name", rcode))
			var pip_lbl: Label = view["pip_lbl"]
			pip_lbl.text = _format_level_pips(lvl, max_lvl)

			var cur_lbl: Label = view["cur_lbl"]
			cur_lbl.text = "当前：" + str(rdata.get("effect", "未建成"))
			var next_lbl: Label = view["next_lbl"]
			if is_max:
				next_lbl.text = "已达最高重檐"
				next_lbl.add_theme_color_override("font_color", C_GOLD)
			else:
				next_lbl.text = "下级：" + str(rdata.get("next_effect", "--"))
				next_lbl.add_theme_color_override("font_color", C_ZHUQING)

			var cta_btn: Button = view["cta_btn"]
			if is_upgrading and upgrading_room_code == rcode:
				cta_btn.text = "修缮中..."
			elif is_max:
				cta_btn.text = "已满级"
				cta_btn.add_theme_stylebox_override("normal", _style(Color("#e7dcc8"), C_BORDER, 1, 8, 6))
				cta_btn.add_theme_color_override("font_color", C_MUTED)
			elif can_afford:
				cta_btn.text = "升级 · %d 军功" % cost
				cta_btn.add_theme_stylebox_override("normal", _style(C_ZHUSHA, C_GOLD, 1, 8, 6))
				cta_btn.add_theme_color_override("font_color", Color("#ffffff"))
			else:
				var gap := maxi(cost - balance, 1)
				cta_btn.text = "还差 %d 军功" % gap
				cta_btn.add_theme_stylebox_override("normal", _style(Color("#dfd3bf"), Color("#b29e82"), 1, 8, 6))
				cta_btn.add_theme_color_override("font_color", Color("#7d4e42"))

	# 更新平板右详栏与手机底部抽屉内容
	var sel_data: Dictionary = rooms_by_code.get(selected_room_code, {
		"code": selected_room_code,
		"name": _fallback_room_name(selected_room_code),
		"level": 0,
		"max_level": 3,
		"effect": "尚未建成",
		"next_effect": "建造后激活便利能力",
		"next_cost": 10,
	})
	_fill_detail_controls(sel_data, balance, tb_detail_art, tb_detail_title_lbl, tb_detail_lvl_lbl, tb_detail_cur_lbl, tb_detail_next_lbl, tb_detail_cost_lbl, tb_detail_btn)
	_fill_detail_controls(sel_data, balance, drawer_art, drawer_title_lbl, drawer_lvl_lbl, drawer_cur_lbl, drawer_next_lbl, drawer_cost_lbl, drawer_confirm_btn)


func _fill_detail_controls(
	rdata: Dictionary,
	balance: int,
	art: _RoomArtCanvas,
	t_lbl: Label,
	lvl_lbl: Label,
	cur_lbl: Label,
	next_lbl: Label,
	cost_lbl: Label,
	act_btn: Button
) -> void:
	if t_lbl == null:
		return
	var rcode := str(rdata.get("code", ""))
	var rname := str(rdata.get("name", _fallback_room_name(rcode)))
	var lvl := int(rdata.get("level", 0))
	var max_lvl := int(rdata.get("max_level", 3))
	var cost_val: Variant = rdata.get("next_cost", null)
	var is_max := (lvl >= max_lvl or cost_val == null)
	var cost := int(cost_val) if cost_val != null else 0
	var can_afford := (not is_max) and (balance >= cost)

	if art != null:
		art.set_room(rcode, lvl)
	t_lbl.text = "%s · %s" % [_room_emoji(rcode), rname]

	if is_max:
		lvl_lbl.text = "Lv.%d / %d · 已满级" % [lvl, max_lvl]
		lvl_lbl.add_theme_color_override("font_color", C_GOLD)
	else:
		lvl_lbl.text = "Lv.%d ➔ Lv.%d" % [lvl, lvl + 1]
		lvl_lbl.add_theme_color_override("font_color", C_ZHUQING)

	cur_lbl.text = "当前加成：%s" % str(rdata.get("effect", "未建成"))
	if is_max:
		next_lbl.text = "满级成就：此厢房已臻极致，庇佑全军从容运筹。"
	else:
		next_lbl.text = "下级提升：%s" % str(rdata.get("next_effect", "--"))

	if is_upgrading and upgrading_room_code == rcode:
		cost_lbl.text = "正在动工修缮，请稍候..."
		cost_lbl.add_theme_color_override("font_color", C_MUTED)
		act_btn.text = "⏳ 修缮中..."
		act_btn.disabled = true
		act_btn.add_theme_color_override("font_disabled_color", Color("#f2e4cc"))
	elif is_max:
		cost_lbl.text = "已达最高等级（Lv.%d），无需再耗军功。" % max_lvl
		cost_lbl.add_theme_color_override("font_color", C_MUTED)
		act_btn.text = "✨ 已满级"
		act_btn.disabled = true
		act_btn.add_theme_stylebox_override("disabled", _style(Color("#e4d9c6"), C_BORDER, 1, 8, 8))
		act_btn.add_theme_color_override("font_disabled_color", C_MUTED)
	elif can_afford:
		cost_lbl.text = "升级消耗：%d 军功   |   可用余额：%d 军功（升完余 %d）" % [cost, balance, balance - cost]
		cost_lbl.add_theme_color_override("font_color", C_ZHUQING)
		act_btn.text = "确认升级 · 消耗 %d 军功" % cost
		act_btn.disabled = false
		act_btn.add_theme_stylebox_override("normal", _style(C_ZHUSHA, C_GOLD, 2, 8, 8))
		act_btn.add_theme_color_override("font_color", Color("#ffffff"))
	else:
		var gap := maxi(cost - balance, 1)
		cost_lbl.text = "还差 %d 军功（需 %d / 已有 %d），去出令或支援盟友！" % [gap, cost, balance]
		cost_lbl.add_theme_color_override("font_color", C_ZHUSHA)
		act_btn.text = "还差 %d 军功" % gap
		act_btn.disabled = true
		act_btn.add_theme_stylebox_override("disabled", _style(Color("#dfd3bf"), Color("#b29e82"), 1, 8, 8))
		act_btn.add_theme_color_override("font_disabled_color", Color("#7d4e42"))


func _on_room_card_selected(room_code: String) -> void:
	selected_room_code = room_code
	AudioManager.play_sfx("click")
	if is_phone_mode:
		open_phone_drawer_for(room_code)
	else:
		_refresh_detail_and_cards()


func _trigger_room_upgrade(room_code: String) -> void:
	if is_upgrading or room_code == "":
		return
	is_upgrading = true
	upgrading_room_code = room_code
	_refresh_detail_and_cards()
	upgrade_requested.emit(room_code)


func _on_first_gov_city_clicked() -> void:
	var govs: Variant = estate_data.get("governorships", [])
	if typeof(govs) == TYPE_ARRAY and not govs.is_empty() and typeof(govs[0]) == TYPE_DICTIONARY:
		var code := str(govs[0].get("code", ""))
		if code != "":
			focus_city_requested.emit(code)


func _copy_share_text() -> void:
	var home_name := str(estate_data.get("home_node", {}).get("name", "我城"))
	var level := int(estate_data.get("level", 1))
	var total := int(estate_data.get("merit_total", 0))
	var f_name := str(me_data.get("faction", {}).get("name", ""))
	var govs: Variant = estate_data.get("governorships", [])
	var gov_tag := ""
	if typeof(govs) == TYPE_ARRAY and not govs.is_empty() and typeof(govs[0]) == TYPE_DICTIONARY:
		gov_tag = " · 本周%s太守" % str(govs[0].get("name", ""))
	var share := "【墨染山河·文房小院】%s（%s阵营）Lv.%d%s，累计斩获 %d 军功！一起来沙盘运筹帷幄吧！" % [
		home_name, f_name, level, gov_tag, total
	]
	DisplayServer.clipboard_set(share)
	toast_requested.emit("📋 已复制小院战绩到剪贴板，快去分享吧！", false)


func _render_rank_list() -> void:
	if rank_list_vbox == null:
		return
	for c in rank_list_vbox.get_children():
		rank_list_vbox.remove_child(c)
		c.queue_free()

	var is_week := (rank_mode == "week")
	rank_tab_week_btn.add_theme_stylebox_override("normal", _style(C_ZHUSHA if is_week else Color("#3b2f26"), C_GOLD, 1, 16, 6))
	rank_tab_total_btn.add_theme_stylebox_override("normal", _style(C_ZHUSHA if not is_week else Color("#3b2f26"), C_GOLD, 1, 16, 6))

	var rows_val: Variant = merit_data.get("week_top" if is_week else "top", [])
	var rows: Array = rows_val if typeof(rows_val) == TYPE_ARRAY else []

	if rows.is_empty():
		rank_list_vbox.add_child(_label("暂无上榜学子，出征一局即抢占榜首！", 13, C_MUTED))
	else:
		var my_id := int(me_data.get("id", -1))
		for i in range(rows.size()):
			var entry: Variant = rows[i]
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var pid := int(entry.get("player_id", -2))
			var is_me := (pid > 0 and pid == my_id)
			var row_p := PanelContainer.new()
			row_p.add_theme_stylebox_override("panel", _style(Color("#fdf2d7") if is_me else C_XUANZHI_SOFT, C_GOLD if is_me else Color("#d9cab1"), 1, 8, 8))
			rank_list_vbox.add_child(row_p)

			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			row_p.add_child(h)

			var rank_num := i + 1
			var medal := "🥇" if rank_num == 1 else ("🥈" if rank_num == 2 else ("🥉" if rank_num == 3 else "%d." % rank_num))
			var r_lbl := _label(medal, 14, C_ZHUSHA if rank_num <= 3 else C_INK, true)
			r_lbl.custom_minimum_size.x = 32
			h.add_child(r_lbl)

			var fcode := str(entry.get("faction", "bi")).to_lower()
			var f_lbl := _label("【%s】" % str(entry.get("faction_name", FACTION_NAME_MAP.get(fcode, ""))), 12, FACTION_COLOR_MAP.get(fcode, C_INK), true)
			h.add_child(f_lbl)

			var n_lbl := _label(str(entry.get("nickname", "学子")) + (" (我)" if is_me else ""), 13, C_INK, is_me)
			n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(n_lbl)

			var s_lbl := _label("%d 军功" % int(entry.get("total", 0)), 13, C_ZHUSHA, true)
			h.add_child(s_lbl)

	var my_rank := int(merit_data.get("week_rank" if is_week else "my_rank", merit_data.get("rank", 0)))
	var my_pts := int(merit_data.get("week" if is_week else "total", estate_data.get("merit_total", 0)))
	var rank_str := ("第 %d 名" % my_rank) if my_rank > 0 else "暂未上榜"
	rank_self_lbl.text = "我的排名：%s   ·   %s %d 军功" % [rank_str, "本周" if is_week else "累计", my_pts]


func _animate_merit_number(from_val: float, to_val: float) -> void:
	if is_instance_valid(_merit_tween) and _merit_tween.is_running():
		_merit_tween.kill()
	var total := int(estate_data.get("merit_total", 0))
	var spent := int(estate_data.get("merit_spent", 0))
	if AudioManager.is_reduced_motion or absf(to_val - from_val) < 0.5:
		displayed_merit_balance = to_val
		_set_merit_labels(int(to_val), total, spent)
		return
	_merit_tween = create_tween()
	_merit_tween.tween_method(func(v: float):
		displayed_merit_balance = v
		_set_merit_labels(int(round(v)), total, spent)
	, from_val, to_val, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate_upgrade_success(room_code: String) -> void:
	var target_dict := ph_room_cards if is_phone_mode else tb_room_cards
	if not target_dict.has(room_code):
		return
	var panel: PanelContainer = target_dict[room_code]["panel"]
	var pad := 10 if is_phone_mode else 14
	panel.add_theme_stylebox_override("panel", _style(Color("#fff9e2"), C_GOLD, 3, 10, pad))
	if not AudioManager.is_reduced_motion:
		panel.pivot_offset = panel.size / 2.0
		var tw := create_tween()
		tw.tween_property(panel, "scale", Vector2(1.04, 1.04), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.21).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_timer(0.35).timeout.connect(func():
		if is_instance_valid(self):
			_refresh_detail_and_cards()
	)


func _check_governor_celebration() -> void:
	var govs: Variant = estate_data.get("governorships", [])
	if typeof(govs) != TYPE_ARRAY or govs.is_empty():
		return
	var g0: Variant = govs[0]
	if typeof(g0) != TYPE_DICTIONARY:
		return
	var key := "%s:%s" % [str(g0.get("code", "")), str(g0.get("week", ""))]
	if key == last_celebrated_gov_key:
		return
	last_celebrated_gov_key = key
	if gov_banner == null or gov_banner_lbl == null:
		return
	gov_banner_lbl.text = "🏛 荣膺本城太守！本周你以最高军功领衔【%s】！" % str(g0.get("name", ""))
	gov_banner.visible = true
	gov_banner.modulate.a = 0.0
	if AudioManager.is_reduced_motion:
		gov_banner.modulate.a = 1.0
		get_tree().create_timer(2.4).timeout.connect(func():
			if is_instance_valid(gov_banner):
				gov_banner.visible = false
		)
	else:
		if is_instance_valid(_gov_banner_tween) and _gov_banner_tween.is_running():
			_gov_banner_tween.kill()
		_gov_banner_tween = create_tween()
		_gov_banner_tween.tween_property(gov_banner, "modulate:a", 1.0, 0.35)
		_gov_banner_tween.tween_interval(2.0)
		_gov_banner_tween.tween_property(gov_banner, "modulate:a", 0.0, 0.6)
		_gov_banner_tween.finished.connect(func():
			if is_instance_valid(gov_banner):
				gov_banner.visible = false
		)


func _is_tutorial_completed() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(ESTATE_TUTORIAL_CFG) == OK:
		return bool(cfg.get_value("estate_tutorial", "completed", false))
	return false


func _render_tutorial_step() -> void:
	var idx := clampi(tut_step_idx, 0, ESTATE_TUTORIAL_STEPS.size() - 1)
	var step: Dictionary = ESTATE_TUTORIAL_STEPS[idx]
	tut_title_lbl.text = step["title"]
	tut_desc_lbl.text = step["desc"]
	tut_next_btn.text = step["btn"]


func _advance_tutorial() -> void:
	tut_step_idx += 1
	if tut_step_idx >= ESTATE_TUTORIAL_STEPS.size():
		_finish_tutorial()
	else:
		_render_tutorial_step()


func _finish_tutorial() -> void:
	if tut_overlay != null:
		tut_overlay.visible = false
	var cfg := ConfigFile.new()
	cfg.set_value("estate_tutorial", "completed", true)
	cfg.save(ESTATE_TUTORIAL_CFG)


func _sync_parent_dock_for_drawer(hide_dock: bool) -> void:
	var parent_slice := get_tree().current_scene
	if parent_slice != null and parent_slice.has_method("_sync_dock_for_estate_drawer"):
		parent_slice._sync_dock_for_estate_drawer(hide_dock)
	else:
		var node := get_parent()
		while node != null:
			if node.has_method("_sync_dock_for_estate_drawer"):
				node._sync_dock_for_estate_drawer(hide_dock)
				break
			node = node.get_parent()


# ---------------------------------------------------------------------------
# 通用交互（长按 0.5s 触发分享/贡献明细，短按触发点击）与样式辅助
# ---------------------------------------------------------------------------

func _attach_long_press(target: Control, on_long: Callable, on_short: Callable) -> void:
	target.set_meta("lp_pressed", false)
	target.set_meta("lp_fired", false)
	target.set_meta("lp_seq", 0)
	target.set_meta("lp_pos", Vector2.ZERO)

	target.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				if on_long.is_valid():
					on_long.call()
				return
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			if mb.pressed:
				var seq := int(target.get_meta("lp_seq")) + 1
				target.set_meta("lp_seq", seq)
				target.set_meta("lp_pressed", true)
				target.set_meta("lp_fired", false)
				target.set_meta("lp_pos", mb.position)
				get_tree().create_timer(0.5).timeout.connect(func():
					if is_instance_valid(target) and bool(target.get_meta("lp_pressed")) and int(target.get_meta("lp_seq")) == seq:
						target.set_meta("lp_fired", true)
						if on_long.is_valid():
							on_long.call()
				)
			else:
				var was_fired := bool(target.get_meta("lp_fired"))
				var start_pos: Vector2 = target.get_meta("lp_pos")
				target.set_meta("lp_pressed", false)
				target.set_meta("lp_seq", int(target.get_meta("lp_seq")) + 1)
				if not was_fired and mb.position.distance_to(start_pos) < 18.0 and on_short.is_valid():
					on_short.call()
		elif ev is InputEventScreenTouch:
			var st := ev as InputEventScreenTouch
			if st.pressed:
				var seq := int(target.get_meta("lp_seq")) + 1
				target.set_meta("lp_seq", seq)
				target.set_meta("lp_pressed", true)
				target.set_meta("lp_fired", false)
				target.set_meta("lp_pos", st.position)
				get_tree().create_timer(0.5).timeout.connect(func():
					if is_instance_valid(target) and bool(target.get_meta("lp_pressed")) and int(target.get_meta("lp_seq")) == seq:
						target.set_meta("lp_fired", true)
						if on_long.is_valid():
							on_long.call()
				)
			else:
				var was_fired := bool(target.get_meta("lp_fired"))
				var start_pos: Vector2 = target.get_meta("lp_pos")
				target.set_meta("lp_pressed", false)
				target.set_meta("lp_seq", int(target.get_meta("lp_seq")) + 1)
				if not was_fired and st.position.distance_to(start_pos) < 18.0 and on_short.is_valid():
					on_short.call()
	)


func _create_gold_progress_bar(bar_h: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = bar_h
	bar.add_theme_stylebox_override("background", _style(Color("#3a2e25"), Color("#68533b"), 1, 3, 0))
	bar.add_theme_stylebox_override("fill", _style(C_GOLD, Color.TRANSPARENT, 0, 3, 0))
	return bar


func _format_level_pips(lvl: int, max_lvl: int) -> String:
	var dots := ""
	for i in range(max_lvl):
		dots += "●" if i < lvl else "○"
	return "%s Lv.%d/%d" % [dots, lvl, max_lvl]


func _fallback_room_name(code: String) -> String:
	match code:
		"study": return "书房"
		"drill": return "练兵场"
		"tower": return "望楼"
		_: return code


func _room_emoji(code: String) -> String:
	match code:
		"study": return "📖"
		"drill": return "⚔️"
		"tower": return "🗼"
		_: return "🏛"


func _style(bg: Color, border: Color = Color.TRANSPARENT, b_w: int = 1, radius: int = 8, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	if border != Color.TRANSPARENT and b_w > 0:
		s.border_color = border
		s.border_width_left = b_w
		s.border_width_top = b_w
		s.border_width_right = b_w
		s.border_width_bottom = b_w
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


func _label(text: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if bold and _main_font != null:
		l.add_theme_font_override("font", _main_font)
	return l


func _button(text: String, bg: Color, h: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = h
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color("#ffffff"))
	b.add_theme_stylebox_override("normal", _style(bg, C_GOLD, 1, 8, 8))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.08), C_GOLD_LIGHT, 1, 8, 8))
	b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.12), C_GOLD, 1, 8, 8))
	b.add_theme_stylebox_override("disabled", _style(Color("#7f7467"), Color("#675d52"), 1, 8, 8))
	return b


func _pill_button(text: String, bg: Color, border: Color, h: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = h
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", C_GOLD_LIGHT)
	var rad := int(h / 2)
	b.add_theme_stylebox_override("normal", _style(bg, border, 1, rad, 8))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.1), border, 1, rad, 8))
	b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.1), border, 1, rad, 8))
	return b


# ---------------------------------------------------------------------------
# Style C 水彩纸雕文房庭院画布与厢房徽章（优先接入 GPT 庭院原画 + 无拉伸裁切 + 代码叠等级/太守旗）
# ---------------------------------------------------------------------------

class _CourtyardArtCanvas extends Control:
	const HOME_ART_PATH := "res://assets/art/ui/estate_home_base.png"

	var _font: Font
	var _level: int = 1
	var _faction_code: String = "bi"
	var _faction_color: Color = Color("#b83b32")
	var _room_levels: Dictionary = {}
	var _governorships: Array = []
	var _tex: Texture2D = null

	var _art_clip: Control
	var _art_rect: TextureRect
	var _sky_feather: TextureRect
	var _atlas: AtlasTexture
	var _overlay_fx: _CourtyardCodeOverlay
	var _parallax_t: float = 0.0
	var _parallax_px: float = 0.0
	var _art_draw_pos: Vector2 = Vector2.ZERO
	var _art_draw_size: Vector2 = Vector2.ZERO
	var _current_region: Rect2 = Rect2(0, 0, 1600, 640)

	func _init(f: Font = null) -> void:
		_font = f
		mouse_filter = Control.MOUSE_FILTER_STOP
		_build_art_nodes()

	func _build_art_nodes() -> void:
		_art_clip = Control.new()
		_art_clip.clip_contents = true
		_art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_art_clip)

		_art_rect = TextureRect.new()
		_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art_rect.visible = false
		_art_clip.add_child(_art_rect)

		_sky_feather = TextureRect.new()
		var sgrad := Gradient.new()
		sgrad.colors = PackedColorArray([Color("#f7c9a8", 1.0), Color("#f7c9a8", 0.0)])
		var sgtex := GradientTexture2D.new()
		sgtex.gradient = sgrad
		sgtex.width = 4
		sgtex.height = 48
		sgtex.fill = GradientTexture2D.FILL_LINEAR
		sgtex.fill_from = Vector2(0.5, 0.0)
		sgtex.fill_to = Vector2(0.5, 1.0)
		_sky_feather.texture = sgtex
		_sky_feather.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_sky_feather.stretch_mode = TextureRect.STRETCH_SCALE
		_sky_feather.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sky_feather.visible = false
		_art_clip.add_child(_sky_feather)

		_overlay_fx = _CourtyardCodeOverlay.new(_font)
		_overlay_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_overlay_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_overlay_fx)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_layout_art_rect()

	func _process(delta: float) -> void:
		if _tex == null or _art_rect == null or not _art_rect.visible or not is_visible_in_tree():
			return
		if AudioManager.is_reduced_motion or DisplayServer.get_name() == "headless":
			if absf(_parallax_px) > 0.01:
				_parallax_px = 0.0
				_layout_art_rect()
			return
		_parallax_t += delta
		_parallax_px = sin(_parallax_t * 0.6) * 4.0
		_art_rect.position.x = _art_draw_pos.x + _parallax_px
		if _overlay_fx != null:
			_overlay_fx.update_overlay(_level, _faction_color, _governorships, Vector2(_art_draw_pos.x + _parallax_px, _art_draw_pos.y), _art_draw_size, _current_region)

	func set_estate_visual(lvl: int, f_code: String, f_col: Color, rooms: Array, govs: Array = []) -> void:
		_level = clampi(lvl, 1, 3)
		_faction_code = f_code
		_faction_color = f_col
		_governorships = govs.duplicate(true)
		_room_levels.clear()
		for r in rooms:
			if typeof(r) == TYPE_DICTIONARY:
				_room_levels[str(r.get("code", ""))] = int(r.get("level", 0))

		var custom_path := "res://assets/art/estate/estate_courtyard_lv%d.png" % _level
		if ResourceLoader.exists(HOME_ART_PATH):
			_tex = load(HOME_ART_PATH)
		elif ResourceLoader.exists(custom_path):
			_tex = load(custom_path)
		elif ResourceLoader.exists("res://assets/art/estate/estate_courtyard.png"):
			_tex = load("res://assets/art/estate/estate_courtyard.png")
		else:
			_tex = null

		_layout_art_rect()
		queue_redraw()

	func _layout_art_rect() -> void:
		if _art_rect == null:
			return
		if _tex == null or size.x <= 4.0 or size.y <= 4.0:
			_art_rect.visible = false
			if _overlay_fx != null:
				_overlay_fx.visible = false
			return

		var tex_w := float(_tex.get_width())
		var tex_h := float(_tex.get_height())
		if tex_w <= 0.0 or tex_h <= 0.0:
			_art_rect.visible = false
			return

		var is_compact := size.x < 560.0
		var extra_w := 0.0 if AudioManager.is_reduced_motion else 10.0
		if _atlas == null:
			_atlas = AtlasTexture.new()
		_atlas.atlas = _tex

		if is_compact:
			# 手机 410x182：AtlasTexture 精确保留左侧门牌(x=20) + 院门/书案 + 右侧望楼(x=1385)，1:1 维持原图比例不拉伸
			_current_region = Rect2(20.0, 48.0, minf(1365.0, tex_w - 20.0), minf(592.0, tex_h - 48.0))
			_atlas.region = _current_region
			var sc := maxf((size.x + extra_w) / _current_region.size.x, size.y / _current_region.size.y)
			_art_draw_size = _current_region.size * sc
			_art_draw_pos = Vector2((size.x - _art_draw_size.x) * 0.5, size.y - _art_draw_size.y)
		else:
			# 平板 834x544：保留完整左门牌、中书案、右望楼及右竹竿旗杆，保持原始比例居下，上方云霞由底图渐变无缝延续
			_current_region = Rect2(16.0, 0.0, minf(1548.0, tex_w - 16.0), tex_h)
			_atlas.region = _current_region
			var sc := (size.x + extra_w) / _current_region.size.x
			_art_draw_size = _current_region.size * sc
			_art_draw_pos = Vector2((size.x - _art_draw_size.x) * 0.5, size.y - _art_draw_size.y)

		_art_rect.texture = _atlas
		_art_rect.position = Vector2(_art_draw_pos.x + _parallax_px, _art_draw_pos.y)
		_art_rect.size = _art_draw_size
		_art_rect.visible = true

		if _sky_feather != null:
			if not is_compact and _art_draw_pos.y > 4.0:
				_sky_feather.position = Vector2(0.0, _art_draw_pos.y - 2.0)
				_sky_feather.size = Vector2(size.x, 44.0)
				_sky_feather.visible = true
			else:
				_sky_feather.visible = false

		if _overlay_fx != null:
			_overlay_fx.visible = true
			_overlay_fx.update_overlay(_level, _faction_color, _governorships, _art_rect.position, _art_draw_size, _current_region)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if rect.size.x <= 4.0 or rect.size.y <= 4.0:
			return
		if _tex != null:
			# 暖霞水彩天穹渐变无缝衔接原图顶边(#f7c9a8)与石阶地砖底色
			var sky_h := maxf(_art_draw_pos.y + 8.0, rect.size.y * 0.5)
			var steps := 16
			var c_top := Color("#ebb28d")
			var c_join := Color("#f7c9a8")
			for i in range(steps):
				var t0 := float(i) / float(steps)
				var t1 := float(i + 1) / float(steps)
				var y0 := t0 * sky_h
				var y1 := t1 * sky_h
				draw_rect(Rect2(0.0, y0, rect.size.x, y1 - y0 + 1.0), c_top.lerp(c_join, t0))
			if _art_draw_pos.y + _art_draw_size.y < rect.size.y:
				draw_rect(Rect2(0.0, _art_draw_pos.y + _art_draw_size.y - 2.0, rect.size.x, rect.size.y), Color("#cfc0a6"))
			return

		var w := rect.size.x
		var h := rect.size.y

		# 1. 天青远山渐变底色（Style C）
		draw_rect(rect, Color("#ece3d1"))
		draw_rect(Rect2(0, 0, w, h * 0.45), Color("#cfe2e8", 0.55))

		# 远山剪影两层（青绿水彩叠加）
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, h * 0.48), Vector2(w * 0.16, h * 0.25), Vector2(w * 0.36, h * 0.38),
			Vector2(w * 0.58, h * 0.20), Vector2(w * 0.80, h * 0.35), Vector2(w, h * 0.26),
			Vector2(w, h * 0.60), Vector2(0, h * 0.60)
		]), Color("#9abdb6", 0.50))
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, h * 0.56), Vector2(w * 0.24, h * 0.39), Vector2(w * 0.48, h * 0.49),
			Vector2(w * 0.72, h * 0.37), Vector2(w, h * 0.52),
			Vector2(w, h * 0.68), Vector2(0, h * 0.68)
		]), Color("#799c8e", 0.52))

		# 庭院石阶地坪（暖宣纸+浅褐影）
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, h * 0.58), Vector2(w, h * 0.58),
			Vector2(w, h), Vector2(0, h)
		]), Color("#e2d4bc"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.28, h * 0.62), Vector2(w * 0.72, h * 0.62),
			Vector2(w * 0.86, h), Vector2(w * 0.14, h)
		]), Color("#d5c3a5"))

		# 青竹剪影与粉壁院墙
		var wall_y := h * 0.54
		draw_rect(Rect2(w * 0.06, wall_y - h * 0.06, w * 0.88, h * 0.08), Color("#f4ecdf"))
		draw_rect(Rect2(w * 0.06, wall_y - h * 0.08, w * 0.88, h * 0.025), Color("#46423d"))

		# 左侧望楼（随 tower 等级增高重檐）
		var tower_lvl := maxi(int(_room_levels.get("tower", 0)), 1 if _level >= 2 else 0)
		var tw_x := w * 0.16
		var tw_w := w * 0.14
		var tw_tiers := 1 + mini(tower_lvl, 2)
		for t in range(tw_tiers):
			var base_y := h * (0.58 - float(t) * 0.13)
			var cur_w := tw_w * (1.0 - float(t) * 0.16)
			draw_rect(Rect2(tw_x - cur_w * 0.4, base_y - h * 0.11, cur_w * 0.8, h * 0.11), Color("#634c3a"))
			_draw_tang_roof(Vector2(tw_x, base_y - h * 0.11), cur_w * 1.25, h * 0.06, Color("#3a424d"))

		# 中央书房主殿（随 estate.level 1..3 升级屋脊与灯笼）
		var cx := w * 0.50
		var main_w := w * (0.34 if _level == 1 else (0.40 if _level == 2 else 0.46))
		var main_h := h * (0.20 if _level == 1 else (0.24 if _level == 2 else 0.27))
		var floor_y := h * 0.66
		# 石台基座
		draw_rect(Rect2(cx - main_w * 0.56, floor_y, main_w * 1.12, h * 0.05), Color("#b5a38c"))
		# 暖灯木墙
		draw_rect(Rect2(cx - main_w * 0.45, floor_y - main_h, main_w * 0.90, main_h), Color("#593a28"))
		# 菱格暖窗
		var win_col := Color("#f5c869") if int(_room_levels.get("study", 0)) >= 1 or _level >= 2 else Color("#a78962")
		draw_rect(Rect2(cx - main_w * 0.28, floor_y - main_h * 0.70, main_w * 0.18, main_h * 0.42), win_col)
		draw_rect(Rect2(cx + main_w * 0.10, floor_y - main_h * 0.70, main_w * 0.18, main_h * 0.42), win_col)
		draw_rect(Rect2(cx - main_w * 0.06, floor_y - main_h * 0.72, main_w * 0.12, main_h * 0.72), Color("#8c3227"))
		# 唐风重檐大屋顶
		_draw_tang_roof(Vector2(cx, floor_y - main_h), main_w * 1.18, h * 0.11, Color("#243342"))
		if _level >= 3:
			_draw_tang_roof(Vector2(cx, floor_y - main_h - h * 0.09), main_w * 0.80, h * 0.08, _faction_color.darkened(0.25))

		# 门前阵营旌旗
		var flag_x := cx + main_w * 0.52
		var pole_top := Vector2(flag_x, floor_y - main_h * 0.95)
		draw_line(Vector2(flag_x, floor_y), pole_top, Color("#3a271a"), 3.0)
		draw_colored_polygon(PackedVector2Array([
			pole_top,
			pole_top + Vector2(w * 0.045, h * 0.03),
			pole_top + Vector2(0, h * 0.12)
		]), _faction_color)

		# 右侧练兵场沙池与木桩
		var drill_lvl := int(_room_levels.get("drill", 0))
		var dx := w * 0.80
		var dy := h * 0.68
		draw_circle(Vector2(dx, dy), w * 0.085, Color("#d4b98c"))
		draw_arc(Vector2(dx, dy), w * 0.085, 0.0, TAU, 24, Color("#8f744f"), 2.0)
		var dummy_cnt := 1 + mini(drill_lvl, 2)
		for idx in range(dummy_cnt):
			var px := dx + (float(idx) - float(dummy_cnt - 1) * 0.5) * (w * 0.045)
			draw_line(Vector2(px, dy), Vector2(px, dy - h * 0.08), Color("#634329"), 3.5)
			draw_circle(Vector2(px, dy - h * 0.09), 4.5, _faction_color)

		# 左前竹林枝叶点缀
		for bx in [w * 0.05, w * 0.085, w * 0.93]:
			draw_line(Vector2(bx, h * 0.72), Vector2(bx, h * 0.36), Color("#2c684f"), 2.5)
			draw_circle(Vector2(bx - 5, h * 0.42), 6.0, Color("#3c8462", 0.75))
			draw_circle(Vector2(bx + 5, h * 0.48), 5.0, Color("#276f57", 0.75))

	func _draw_tang_roof(top_center: Vector2, rw: float, rh: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			Vector2(top_center.x - rw * 0.56, top_center.y),
			Vector2(top_center.x - rw * 0.25, top_center.y - rh),
			Vector2(top_center.x + rw * 0.25, top_center.y - rh),
			Vector2(top_center.x + rw * 0.56, top_center.y),
		]), col)
		draw_line(
			Vector2(top_center.x - rw * 0.56, top_center.y),
			Vector2(top_center.x + rw * 0.56, top_center.y),
			Color("#c89333"), 2.0
		)


class _RoomArtCanvas extends Control:
	var _font: Font
	var _room_code: String = "study"
	var _level: int = 0
	var _tex: Texture2D = null

	func _init(f: Font = null) -> void:
		_font = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_room(code: String, lvl: int) -> void:
		_room_code = code
		_level = clampi(lvl, 0, 3)
		var custom_path := "res://assets/art/estate/estate_room_%s.png" % code
		if ResourceLoader.exists(custom_path):
			_tex = load(custom_path)
		else:
			_tex = null
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if rect.size.x <= 4.0 or rect.size.y <= 4.0:
			return
		var bg_col := Color("#ede2ce") if _level == 0 else Color("#fbf4e4")
		var brd_col := Color("#c89333") if _level > 0 else Color("#bba98e")
		draw_rect(rect, bg_col)
		draw_rect(rect, brd_col, false, 2.0)

		if _tex != null:
			draw_texture_rect(_tex, rect.grow(-4), false)
			return

		var cx := rect.size.x * 0.5
		var cy := rect.size.y * 0.5
		var r := minf(rect.size.x, rect.size.y) * 0.34
		if _room_code == "study":
			# 竹简卷轴 + 朱砂封泥造型
			draw_rect(Rect2(cx - r * 0.85, cy - r * 0.65, r * 1.7, r * 1.3), Color("#f6efe2"))
			draw_rect(Rect2(cx - r * 0.85, cy - r * 0.65, r * 1.7, r * 1.3), Color("#1e3a5f"), false, 2.0)
			for i in range(3):
				var y := cy - r * 0.3 + float(i) * (r * 0.35)
				draw_line(Vector2(cx - r * 0.5, y), Vector2(cx + r * 0.5, y), Color("#3d2f22"), 2.0)
			draw_circle(Vector2(cx + r * 0.45, cy + r * 0.35), r * 0.22, Color("#b83b32"))
		elif _room_code == "drill":
			# 双戟与校场军鼓
			draw_circle(Vector2(cx, cy + r * 0.15), r * 0.55, Color("#d4b483"))
			draw_circle(Vector2(cx, cy + r * 0.15), r * 0.55, Color("#8c3227"), false, 2.5)
			draw_line(Vector2(cx - r * 0.7, cy + r * 0.7), Vector2(cx + r * 0.7, cy - r * 0.7), Color("#3a2c20"), 3.0)
			draw_line(Vector2(cx + r * 0.7, cy + r * 0.7), Vector2(cx - r * 0.7, cy - r * 0.7), Color("#3a2c20"), 3.0)
		else:
			# 望楼重檐高台
			draw_rect(Rect2(cx - r * 0.45, cy - r * 0.15, r * 0.9, r * 0.95), Color("#634c3a"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - r * 0.85, cy - r * 0.15),
				Vector2(cx, cy - r * 0.85),
				Vector2(cx + r * 0.85, cy - r * 0.15),
			]), Color("#276f57"))
			draw_circle(Vector2(cx, cy - r * 0.4), r * 0.16, Color("#fae19c"))


class _CourtyardCodeOverlay extends Control:
	var _font: Font
	var _level: int = 1
	var _faction_color: Color = Color("#b83b32")
	var _governorships: Array = []
	var _art_pos: Vector2 = Vector2.ZERO
	var _art_size: Vector2 = Vector2.ZERO
	var _region: Rect2 = Rect2(0, 0, 1600, 640)

	func _init(f: Font = null) -> void:
		_font = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func update_overlay(lvl: int, f_col: Color, govs: Array, art_pos: Vector2, art_size: Vector2, region: Rect2) -> void:
		_level = lvl
		_faction_color = f_col
		_governorships = govs.duplicate(true)
		_art_pos = art_pos
		_art_size = art_size
		_region = region
		queue_redraw()

	func _src_to_view(src_pt: Vector2) -> Vector2:
		if _region.size.x <= 0.0 or _region.size.y <= 0.0:
			return Vector2.ZERO
		var uv := Vector2((src_pt.x - _region.position.x) / _region.size.x, (src_pt.y - _region.position.y) / _region.size.y)
		return _art_pos + uv * _art_size

	func _draw() -> void:
		if _art_size.x <= 4.0 or _art_size.y <= 4.0:
			return
		# 右侧竹竿旗杆（原图约 1498, 268）在平板完整视口内可见：当玩家担任太守时用代码绘制阵营三角太守令旗
		if not _governorships.is_empty():
			var pole_src := Vector2(1498.0, 272.0)
			if _region.has_point(pole_src):
				var top_pt := _src_to_view(pole_src)
				var fw := clampf(_art_size.x * 0.072, 34.0, 64.0)
				var fh := clampf(_art_size.y * 0.125, 22.0, 44.0)
				var flag_pts := PackedVector2Array([
					top_pt,
					top_pt - Vector2(fw, fh * 0.18),
					top_pt - Vector2(fw * 0.78, -fh * 0.35),
					top_pt + Vector2(0.0, fh * 0.85),
				])
				draw_colored_polygon(flag_pts, _faction_color)
				draw_polyline(PackedVector2Array([flag_pts[0], flag_pts[1], flag_pts[2], flag_pts[3]]), Color("#fae19c"), 1.6)
				if _font != null:
					draw_string(_font, top_pt + Vector2(-fw * 0.72, fh * 0.42), "太守", HORIZONTAL_ALIGNMENT_LEFT, fw * 0.7, 11, Color("#fae19c"))
