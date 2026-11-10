extends Control

## 《青竹文房·灵宠山河》客户端主架构
## 商业级主流轻 SLG 导航骨架与全屏分层交互（对标《率土之滨》《三国志·战略版》《江南百景图》）

const FONT_PATH := "res://fonts/NotoSerifCJKsc-Regular.otf"
const SliceMapScript = preload("res://SliceMap.gd")
const ReplayMapScript = preload("res://ReplayMap.gd")

# ---------------------------------------------------------------------------
# Style C 水彩纸雕国风色板（严格对齐 ART_BRIEF_GPT.md）
# ---------------------------------------------------------------------------
const C_XUANZHI := Color("#f6efe2")     # 宣纸米黄（面板底色、纸卡底衬）
const C_MOLAN := Color("#1e3a5f")       # 墨蓝（次级按钮、文墨深蓝）
const C_ZHUQING := Color("#276f57")     # 竹青（青竹书院主色、防守与确认按钮）
const C_ZHUSHA := Color("#b83b32")      # 朱砂（主行动按钮、红营主色、警示印章）
const C_TENGHUANG := Color("#cf8325")   # 藤黄（烫金线条、高亮标识、重点点缀）
const C_TIANQING := Color("#a9d6e5")    # 天青（水域微光、信息标签、清雅蓝）
const C_WOOD_DESK := Color("#2f2721")   # 深墨木桌（案台底色、深木色面板封边）
const C_SHADOW_WARM := Color(0.24, 0.20, 0.17, 0.35) # 暖灰纸片投影（杜绝死黑）
const C_BORDER_GOLD := Color("#c9a227") # 烫金描边与高亮线

# 兼容与别名常量映射
const INK_DARK := C_WOOD_DESK
const INK := Color("#231c17")
const INK_LIGHT := Color("#4a3e35")
const CREAM := C_XUANZHI
const PAPER := Color("#ede5d5")
const CORAL := C_ZHUSHA
const BAMBOO := C_ZHUQING
const GOLD := C_TENGHUANG
const GOLD_LIGHT := Color("#fae19c")
const MUTED := Color("#8a7c6c")
const DARK := Color("#1c1612")
const NEUTRAL := Color("#7e7263")

# ---------------------------------------------------------------------------
# GPT Style C UI Kit Asset 插槽注册表
# ---------------------------------------------------------------------------
const UI_ASSET_PATHS := {
	"panel_card": "res://assets/art/ui_panel_card.png",
	"btn_primary": "res://assets/art/ui_button_primary.png",
	"btn_secondary": "res://assets/art/ui_button_secondary.png",
	"btn_confirm": "res://assets/art/ui_button_confirm.png",
	"report_banner": "res://assets/art/ui_report_banner.png",
	"replay_frame": "res://assets/art/ui_replay_frame.png",
	"seal_victory": "res://assets/art/ui_seal_victory.png",
	"seal_defeat": "res://assets/art/ui_seal_defeat.png",
	"order_advance": "res://assets/art/icon_order_advance.png",
	"order_defend": "res://assets/art/icon_order_defend.png",
	"order_scout": "res://assets/art/icon_order_scout.png",
	"order_supply": "res://assets/art/icon_order_supply.png",
	"mascot_bamboo": "res://assets/art/mascot_bamboo_normal.png",
	"mascot_ink": "res://assets/art/mascot_ink_normal.png",
}

var ui_kit_textures: Dictionary = {}

# ---------------------------------------------------------------------------
# 基础核心与通信
# ---------------------------------------------------------------------------
var api: Node
var login_layer: Control
var game_layer: Control
var login_gear_btn: Button

# 页面路由与容器
var current_page := "S01_MAP"
var pages: Dictionary = {}
var pages_container: Control

# S01 主沙盘外壳
var map_shell: Control
var map_view: Control
var map_world: Control
var map: Control
var node_buttons: Dictionary = {}
var map_zoom: float = 1.0
var map_pan: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var pan_start: Vector2 = Vector2.ZERO
var touch_points: Dictionary = {}
var initial_pinch_dist: float = 0.0
var initial_pinch_zoom: float = 1.0

var legend_panel: PanelContainer

# S01 顶部 HUD & 导航栏
var top_bar: Panel
var gold_line: ColorRect
var hud_left_box: HBoxContainer
var hud_right_box: HBoxContainer
var top_avatar_box: Panel
var top_pet_icon: Label
var title_label: Label
var faction_label: Label
var combat_power_label: Label
var resource_bar: HBoxContainer
var wallet_label: Label
var countdown_label: Label
var rail_buttons: Array = []
var dock_row: HBoxContainer

# 断线/弱网全局警示横幅与动效
var offline_banner: PanelContainer
var offline_banner_label: Label
var offline_retry_btn: Button
var drawer_tween: Tween
var is_drawer_open: bool = false

# S01 左右侧栏与底部导航
var left_rail: Control
var right_rail: Control
var bottom_dock: Control
var dock_tab_buttons: Dictionary = {}

# S02 城池底部抽屉
var city_drawer: Panel
var city_drawer_margin: MarginContainer
var city_drawer_handle: Panel
var city_avatar_box: Panel
var city_avatar_icon: Label
var city_title_label: Label
var city_type_badge: Label
var city_faction_badge: Label
var city_def_badge: Label
var city_morale_badge: Label
var city_garrison_label: Label
var city_routes_label: Label
var city_tactical_label: Label
var city_order_hint: Label
var city_lore_label: Label
var city_power_diff_label: Label
var city_lore_dialog: AcceptDialog
var city_action_advance_btn: Button
var city_action_defend_btn: Button
var city_action_scout_btn: Button
var city_action_supply_btn: Button
var city_action_withdraw_btn: Button
var city_action_battle_btn: Button
var current_battle_id: int = 0

# Phase 1: 军团编成、每日战术手牌与 3x2 战斗回放
const CompositionPanelScript = preload("res://CompositionPanel.gd")
const BattleReplayScene = preload("res://BattleReplay.tscn")
var composition_panel: PanelContainer
var army_margin: MarginContainer
var hand_cards_bar: PanelContainer
var hand_cards_container: HBoxContainer
var hand_card_views: Array = []
var hand_redraw_btn: Button
var hand_collapse_btn: Button
var hand_cards_data: Array = []
var hand_redraw_used: bool = false
var hand_bar_collapsed: bool = false
var battle_replay_overlay: Control
var battle_replay_instance: Control
var card_tooltip_panel: PanelContainer
var card_tooltip_title: Label
var card_tooltip_desc: Label

# S03 军令确认浮层
var order_confirm_overlay: Control
var order_confirm_modal: Panel
var confirm_title_label: Label
var confirm_origin_label: Label
var confirm_target_label: Label
var confirm_pet_label: Label
var confirm_cost_label: Label
var confirm_hint_label: Label
var confirm_action_type := "advance"
var confirm_origin_code := ""
var confirm_target_code := ""

# S04 战争日报全屏页
var report_page: Control
var report_margin: MarginContainer
var report_headline_panel: PanelContainer
var report_headline_lbl: Label
var report_time_lbl: Label
var report_my_text: RichTextLabel
var report_world_text: RichTextLabel
var report_summary_text: RichTextLabel
var report_dialog: Control # 兼容旧代码引用
var report_text: RichTextLabel # 兼容旧代码引用
var report_loading_box: PanelContainer
var report_error_box: PanelContainer
var report_error_lbl: Label

# S05 战局复盘全屏页
var replay_page: Control
var replay_margin: MarginContainer
var replay_dialog: Control # 兼容自动化测试引用
var replay_map: Control
var replay_turn_select: OptionButton
var replay_text: RichTextLabel
var replay_data: Dictionary = {}
var replay_time_lbl: Label
var prev_turn_btn: Button
var next_turn_btn: Button

# S06 阵营势力全屏页
var faction_page: Control
var faction_margin: MarginContainer
var faction_summary_box: PanelContainer
var faction_cards_container: GridContainer
var faction_top_title: Label
var faction_top_desc: Label
var faction_cards: Array = []

# 登录与网络设置
var login_panel: Panel
var login_inner_box: Panel
var login_margin: MarginContainer
var login_vbox: VBoxContainer
var login_title_lbl: Label
var login_sub_lbl: Label
var login_foot_lbl: Label
var login_sep: HSeparator
var url_edit: LineEdit
var name_edit: LineEdit
var pass_edit: LineEdit
var login_status: Label
var login_student_btn: Button
var dev_settings_dialog: AcceptDialog

# 教师专属督军案台（保留给自动化测试与管理权限）
var teacher_box: Control
var lock_btn: Button
var settle_btn: Button
var next_btn: Button
var admin_status_btn: Button

# 充值弹窗
var recharge_dialog: AcceptDialog
var recharge_spin: SpinBox
var recharge_info: Label
var recharge_confirm: Button
var recharge_btn: Button

# 核心状态机与兼容控件
var origin_select: OptionButton
var target_select: OptionButton
var advance_btn: Button
var defend_btn: Button
var withdraw_btn: Button
var report_btn: Button
var replay_btn: Button
var refresh_btn: Button
var player_box: Control
var pet_banner_label: Label
var my_order_label: Label
var node_info: Label
var turn_hint: Label
var action_status: Label

var state: Dictionary = {}
var me: Dictionary = {}
var wallet: Dictionary = {}
var selected_code := ""
var countdown_seconds := 0
var countdown_last_msec := 0
var polling := false
var api_epoch := 0
var order_submitting := false

var toast_panel: PanelContainer
var toast_label: Label
var toast_timer := 0.0

# 哨探情报面板
var city_intel_dialog: AcceptDialog
var city_intel_vbox: VBoxContainer
var city_intel_status_lbl: Label
var city_intel_lane_box: PanelContainer
var city_intel_massing_box: PanelContainer
var poll_timer: Timer

# ---------------------------------------------------------------------------
# 生命周期
# ---------------------------------------------------------------------------

func _ready() -> void:
	api = get_node_or_null("/root/Api")
	if api == null:
		var ApiScript = load("res://Api.gd")
		api = ApiScript.new()
		add_child(api)
	_setup_theme()
	_init_ui_asset_slots()
	_build_login()
	_build_game()
	_build_toast_banner()
	_build_offline_banner()
	_load_config()
	_layout_responsive()

func _init_ui_asset_slots() -> void:
	ui_kit_textures.clear()
	for key in UI_ASSET_PATHS.keys():
		var path: String = UI_ASSET_PATHS[key]
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex != null:
				ui_kit_textures[key] = tex

func _process(delta: float) -> void:
	_on_countdown_tick()
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0 and toast_panel != null:
			toast_panel.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_responsive()

# ---------------------------------------------------------------------------
# 主题与通用组件样式生成器
# ---------------------------------------------------------------------------

func _setup_theme() -> void:
	var t := Theme.new()
	var f = load(FONT_PATH)
	if f != null:
		t.default_font = f
	t.default_font_size = 15
	theme = t

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
	if bg.a > 0.05:
		s.shadow_color = C_SHADOW_WARM
		s.shadow_size = 3
		s.shadow_offset = Vector2(0, 2)
	return s

func _panel_style(bg: Color = C_XUANZHI, border: Color = C_TENGHUANG, width: int = 1, radius: int = 10, pad: int = 12) -> StyleBox:
	if ui_kit_textures.has("panel_card"):
		var tex: Texture2D = ui_kit_textures["panel_card"]
		var s := StyleBoxTexture.new()
		s.texture = tex
		s.texture_margin_left = 16
		s.texture_margin_top = 16
		s.texture_margin_right = 16
		s.texture_margin_bottom = 16
		s.content_margin_left = pad
		s.content_margin_top = pad
		s.content_margin_right = pad
		s.content_margin_bottom = pad
		return s
	return _style(bg, border, width, radius, pad)

func _label(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, color: Color, height: int = 42) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color("#ffffff"))
	b.add_theme_color_override("font_disabled_color", Color("#9e9282"))

	var tex_key := ""
	if color == C_ZHUSHA or color == CORAL:
		tex_key = "btn_primary"
	elif color == C_MOLAN:
		tex_key = "btn_secondary"
	elif color == C_ZHUQING or color == BAMBOO:
		tex_key = "btn_confirm"

	if tex_key != "" and ui_kit_textures.has(tex_key):
		var tex: Texture2D = ui_kit_textures[tex_key]
		var s := StyleBoxTexture.new()
		s.texture = tex
		s.texture_margin_left = 12
		s.texture_margin_top = 12
		s.texture_margin_right = 12
		s.texture_margin_bottom = 12
		b.add_theme_stylebox_override("normal", s)
	else:
		b.add_theme_stylebox_override("normal", _style(color, color.darkened(0.2), 1, 8, 8))
		b.add_theme_stylebox_override("hover", _style(color.lightened(0.12), color.darkened(0.2), 1, 8, 8))
		b.add_theme_stylebox_override("pressed", _style(color.darkened(0.15), color.darkened(0.3), 1, 8, 8))
		b.add_theme_stylebox_override("disabled", _style(Color("#8a8074"), Color("#6d6458"), 1, 8, 8))
	return b

func _pill_btn(text: String, color: Color = Color("#2a2018"), border: Color = GOLD, height: int = 36) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", GOLD_LIGHT)
	b.add_theme_stylebox_override("normal", _style(color, border, 1, height / 2, 8))
	b.add_theme_stylebox_override("hover", _style(color.lightened(0.1), border.lightened(0.2), 1, height / 2, 8))
	b.add_theme_stylebox_override("pressed", _style(color.darkened(0.1), border, 1, height / 2, 8))
	return b

func _line_edit(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 44)
	e.add_theme_color_override("font_placeholder_color", Color("#9e8d76"))
	e.add_theme_color_override("font_color", INK)
	e.add_theme_stylebox_override("normal", _style(Color("#fffefb"), Color("#c9b99a"), 1, 8, 10))
	e.add_theme_stylebox_override("focus", _style(Color("#fffefb"), GOLD, 2, 8, 10))
	return e

func _create_res_pill(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color("#221b15"), Color("#4d3a2a"), 1, 14, 6))
	var l := _label(text, 13, Color("#faecd3"))
	p.add_child(l)
	return p

# 统一国风徽章（印章风格或圆角胶囊风格）
func _badge(text: String, bg_color: Color, border_color: Color, font_color: Color, font_size: int = 11, is_pill: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	var radius := 11 if is_pill else 4
	p.add_theme_stylebox_override("panel", _style(bg_color, border_color, 1, radius, 4))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", font_color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

# 统一国风纸雕空态卡片（规范空态展示：暂无军情、战报备战等）
func _build_empty_state(icon: String, title: String, desc: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 150)
	p.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 10, 16))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	
	var icn := _label(icon, 30, Color(GOLD.r, GOLD.g, GOLD.b, 0.9))
	icn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(icn)
	
	var tl := _label(title, 15, C_WOOD_DESK)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	
	var dc := _label(desc, 12, Color("#7a6b5c"))
	dc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(dc)
	return p

# 统一墨韵推演加载指示器
func _build_loading_indicator(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(260, 44)
	p.add_theme_stylebox_override("panel", _style(Color("#241c16", 0.95), GOLD, 1, 8, 8))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	var spin := _label("⏳", 15, GOLD_LIGHT)
	row.add_child(spin)
	var lbl := _label(text, 13, GOLD_LIGHT)
	row.add_child(lbl)
	return p

func _create_page_header(title: String, subtitle: String = "") -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 64)
	p.size = Vector2(size.x, 64)
	p.add_theme_stylebox_override("panel", _style(Color("#1a1410"), GOLD, 0, 0))
	
	var bar := ColorRect.new()
	bar.color = GOLD
	bar.position = Vector2(0, 62)
	bar.size = Vector2(2560, 2)
	p.add_child(bar)
	
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	p.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	
	var back_btn := _button("← 返回沙盘", Color("#423429"), 38)
	back_btn.custom_minimum_size = Vector2(100, 38)
	back_btn.pressed.connect(func(): _navigate_to("S01_MAP"))
	row.add_child(back_btn)
	
	var title_lbl := _label(title, 18, GOLD_LIGHT)
	row.add_child(title_lbl)
	
	if subtitle != "":
		var sub_lbl := _label("· " + subtitle, 13, Color("#bfa98d"))
		row.add_child(sub_lbl)
		
	return p

# ---------------------------------------------------------------------------
# 全局悬浮 Toast 通知条
# ---------------------------------------------------------------------------

func _build_toast_banner() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.visible = false
	toast_panel.custom_minimum_size = Vector2(480, 46)
	toast_panel.position = Vector2((size.x - 480) / 2.0, 78)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_theme_stylebox_override("panel", _style(Color("#241c16", 0.96), GOLD, 2, 8, 10))
	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 15)
	toast_label.add_theme_color_override("font_color", GOLD_LIGHT)
	toast_panel.add_child(toast_label)
	add_child(toast_panel)

func _toast(msg: String, is_error: bool = false) -> void:
	if toast_label == null or toast_panel == null:
		return
	toast_label.text = msg
	var border_color := CORAL if is_error else GOLD
	var text_color := Color("#ff8a80") if is_error else GOLD_LIGHT
	toast_panel.add_theme_stylebox_override("panel", _style(Color("#241c16", 0.96), border_color, 2, 8, 10))
	toast_label.add_theme_color_override("font_color", text_color)
	toast_panel.visible = true
	toast_timer = 3.2

# ---------------------------------------------------------------------------
# 全局断线 / 离线警示指示条 (设计系统标准状态响应)
# ---------------------------------------------------------------------------

func _build_offline_banner() -> void:
	offline_banner = PanelContainer.new()
	offline_banner.visible = false
	offline_banner.custom_minimum_size = Vector2(400, 36)
	offline_banner.mouse_filter = Control.MOUSE_FILTER_PASS
	offline_banner.add_theme_stylebox_override("panel", _style(Color("#2c1712", 0.96), C_ZHUSHA, 1, 6, 6))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	offline_banner.add_child(h)
	
	offline_banner_label = _label("⚠️ 烽烟信号微弱 · 正在重连学堂...", 12, Color("#ffd4cc"))
	h.add_child(offline_banner_label)
	
	offline_retry_btn = Button.new()
	offline_retry_btn.text = "🔄 重连"
	offline_retry_btn.custom_minimum_size = Vector2(68, 26)
	offline_retry_btn.add_theme_font_size_override("font_size", 11)
	offline_retry_btn.add_theme_stylebox_override("normal", _style(C_ZHUSHA, Color("#ff8a80"), 1, 4, 3))
	offline_retry_btn.add_theme_color_override("font_color", Color("#ffffff"))
	offline_retry_btn.pressed.connect(func():
		_set_offline(false)
		_refresh_state()
	)
	h.add_child(offline_retry_btn)
	add_child(offline_banner)

func _set_offline(is_offline: bool, msg: String = "⚠️ 烽烟信号微弱 · 正在重连学堂...") -> void:
	if offline_banner == null:
		return
	offline_banner_label.text = msg
	offline_banner.visible = is_offline
	if is_offline:
		var banner_w := minf(size.x - 20.0, 400.0)
		offline_banner.size = Vector2(banner_w, 36.0)
		var top_bar_h := 50.0 if size.y < 650.0 else (62.0 if size.x < 900.0 else 72.0)
		offline_banner.position = Vector2((size.x - banner_w) / 2.0, top_bar_h + 4.0)

# ---------------------------------------------------------------------------
# 页面路由与分层导航管理
# ---------------------------------------------------------------------------

func _navigate_to(page_id: String) -> void:
	current_page = page_id
	if page_id == "S01_MAP":
		map_shell.visible = true
		if legend_panel != null and (city_drawer == null or not city_drawer.visible):
			legend_panel.visible = true
		if hand_cards_bar != null and (city_drawer == null or not city_drawer.visible):
			hand_cards_bar.visible = true
		for p in pages.values():
			p.visible = false
	else:
		map_shell.visible = false
		if hand_cards_bar != null:
			hand_cards_bar.visible = false
		if city_drawer != null:
			_toggle_city_drawer(false)
		if order_confirm_overlay != null:
			order_confirm_overlay.visible = false
		for k in pages.keys():
			pages[k].visible = (k == page_id)
			
	_update_dock_highlight(page_id)

func _update_dock_highlight(page_id: String) -> void:
	for k in dock_tab_buttons.keys():
		var btn: Button = dock_tab_buttons[k]
		if k == page_id:
			btn.add_theme_stylebox_override("normal", _style(Color("#3d2f24"), GOLD, 1, 8, 6))
			btn.add_theme_color_override("font_color", GOLD_LIGHT)
		else:
			btn.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 8, 6))
			btn.add_theme_color_override("font_color", Color("#c4b295"))

# ---------------------------------------------------------------------------
# 响应式布局自适应（手机与平板断点：900dp）
# ---------------------------------------------------------------------------

func _layout_responsive() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
		
	var is_phone := w < 900.0 or h < 650.0
	var is_compact_h := h < 650.0
	var is_portrait := h > w

	# 1. 登录卡片（自适应手机横屏 720×514，确保 0 截断）
	if login_panel != null:
		var lp_w := minf(w - 32.0, 480.0 if is_compact_h else 500.0)
		var lp_h := minf(h - 20.0, 484.0 if is_compact_h else 600.0)
		login_panel.size = Vector2(lp_w, lp_h)
		login_panel.position = Vector2((w - lp_w) / 2.0, maxf((h - lp_h) / 2.0, 10.0))
		if login_inner_box != null:
			login_inner_box.position = Vector2(10, 10)
			login_inner_box.size = Vector2(lp_w - 20, lp_h - 20)
		if login_margin != null:
			login_margin.position = Vector2(20.0 if is_compact_h else 28.0, 14.0 if is_compact_h else 28.0)
			login_margin.size = Vector2(lp_w - (40.0 if is_compact_h else 56.0), lp_h - (28.0 if is_compact_h else 56.0))
		if login_vbox != null:
			login_vbox.add_theme_constant_override("separation", 6 if is_compact_h else 14)
		if login_title_lbl != null:
			login_title_lbl.add_theme_font_size_override("font_size", 24 if is_compact_h else 38)
		if login_sub_lbl != null:
			login_sub_lbl.add_theme_font_size_override("font_size", 12 if is_compact_h else 15)
		if name_edit != null:
			name_edit.custom_minimum_size.y = 36 if is_compact_h else 44
		if pass_edit != null:
			pass_edit.custom_minimum_size.y = 36 if is_compact_h else 44
		if login_student_btn != null:
			login_student_btn.custom_minimum_size.y = 40 if is_compact_h else 48
			login_student_btn.add_theme_font_size_override("font_size", 15 if is_compact_h else 18)
		if login_status != null:
			login_status.custom_minimum_size.y = 24 if is_compact_h else 36
			login_status.add_theme_font_size_override("font_size", 11 if is_compact_h else 13)
		if login_foot_lbl != null:
			login_foot_lbl.add_theme_font_size_override("font_size", 10 if is_compact_h else 12)
	if login_gear_btn != null:
		login_gear_btn.position = Vector2(w - 124.0, 14.0)
		
	# 2. 地图全屏与沙盘视口自适应
	if map_view != null:
		map_view.size = Vector2(w, h)
	if map != null:
		map.size = Vector2(w, h)
	_clamp_pan()
		
	# 接入 DisplayServer.get_display_safe_area() 避让刘海屏/挖孔屏顶栏
	var safe_top := 0.0
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var win_size: Vector2i = DisplayServer.window_get_size()
	if win_size.y > 0 and safe_rect.position.y > 0:
		safe_top = float(safe_rect.position.y) * (h / float(win_size.y))

	# 3. 顶部 HUD（支持异形屏/刘海屏安全内缩，按钮高度保障 >=44px）
	var top_h := (50.0 if is_compact_h else (62.0 if is_phone else 72.0)) + safe_top
	if top_bar != null:
		top_bar.size = Vector2(w, top_h)
		if gold_line != null:
			gold_line.size = Vector2(w, 2.0)
			gold_line.position = Vector2(0, top_h - 2.0)
			
		if hud_left_box != null:
			var lw := 210.0 if is_phone else 300.0
			hud_left_box.position = Vector2(8.0 if is_phone else 16.0, safe_top + (top_h - safe_top - 44.0) / 2.0)
			hud_left_box.size = Vector2(lw, 44.0)
			
		if hud_right_box != null:
			var rw := 190.0 if is_compact_h else (240.0 if is_phone else 420.0)
			hud_right_box.position = Vector2(w - rw - (8.0 if is_phone else 16.0), safe_top + (top_h - safe_top - 44.0) / 2.0)
			hud_right_box.size = Vector2(rw, 44.0)
			
		if resource_bar != null:
			if is_compact_h and hud_left_box != null and hud_right_box != null:
				var rx := hud_left_box.position.x + hud_left_box.size.x + 8.0
				var rw_avail := maxf(hud_right_box.position.x - rx - 8.0, 80.0)
				resource_bar.position = Vector2(rx, safe_top + (top_h - safe_top - 40.0) / 2.0)
				resource_bar.size = Vector2(rw_avail, 40.0)
			elif is_phone and hud_left_box != null and hud_right_box != null:
				var rx := hud_left_box.position.x + hud_left_box.size.x + 8.0
				var rw_avail := maxf(hud_right_box.position.x - rx - 8.0, 100.0)
				resource_bar.position = Vector2(rx, safe_top + (top_h - safe_top - 40.0) / 2.0)
				resource_bar.size = Vector2(rw_avail, 40.0)
			else:
				var rw_ideal := 520.0
				resource_bar.position = Vector2((w - rw_ideal) / 2.0, safe_top + (top_h - safe_top - 44.0) / 2.0)
				resource_bar.size = Vector2(rw_ideal, 44.0)

	# 4. 左右侧栏：贴边半透明印章式悬浮图标列（P0: 去除实心黑底板，全屏通栏）
	var rail_top := top_h + (6.0 if is_compact_h else 14.0)
	var rail_btn_size := Vector2(36, 36) if is_compact_h else (Vector2(42, 42) if is_portrait else Vector2(48, 48))
	if left_rail != null:
		left_rail.position = Vector2(8 if is_phone else 14, rail_top)
		left_rail.size = Vector2(rail_btn_size.x, 220)
			
	if right_rail != null:
		right_rail.position = Vector2(w - rail_btn_size.x - (8 if is_phone else 14), rail_top)
		right_rail.size = Vector2(rail_btn_size.x, 220)
			
	for item in rail_buttons:
		var btn: Button = item.get("btn", null)
		if btn != null:
			btn.text = str(item.get("icon", ""))
			btn.tooltip_text = str(item.get("full", ""))
			btn.custom_minimum_size = rail_btn_size

	if legend_panel != null:
		var leg_y := 315.0
		if is_portrait:
			# 手机竖屏（720×1280）：避开西北大营云麓关(y=281)，置于中左侧开阔远山处
			leg_y = 480.0
		elif is_compact_h:
			# 手机横屏（720×514）：置于左侧悬浮图标下方与西南据点之间
			leg_y = rail_top + 168.0
		else:
			leg_y = rail_top + 225.0
		legend_panel.position = Vector2(8 if is_phone else 14, minf(leg_y, h - 85.0))

	# 5. 底部导航栏（P0: 贴底通栏，半透明条）
	if bottom_dock != null:
		var dock_h := 46.0 if is_compact_h else (56.0 if is_phone else 60.0)
		bottom_dock.size = Vector2(w, dock_h)
		# 抽屉滑出时 Dock 向下滑出屏幕让位；关闭时贴底
		if city_drawer != null and city_drawer.visible:
			bottom_dock.position = Vector2(0, h)
		else:
			bottom_dock.position = Vector2(0, h - dock_h)
			
		if dock_row != null:
			var max_dock_w := minf(w - 20.0, 720.0)
			dock_row.position = Vector2((w - max_dock_w) / 2.0, (dock_h - (38.0 if is_compact_h else 44.0)) / 2.0)
			dock_row.size = Vector2(max_dock_w, 38.0 if is_compact_h else 44.0)
			
		for tab_id in dock_tab_buttons.keys():
			var btn: Button = dock_tab_buttons[tab_id]
			btn.add_theme_font_size_override("font_size", 12 if is_compact_h else 14)

	# 5.1 每日战术手牌栏（悬浮贴于底部导航栏上方，抽屉打开时避让）
	if hand_cards_bar != null:
		var dock_h := 46.0 if is_compact_h else (56.0 if is_phone else 60.0)
		var bar_w := minf(w - 16.0, 720.0)
		var actual_bar_h := 28.0 if hand_bar_collapsed else (102.0 if is_compact_h else 108.0)
		hand_cards_bar.size = Vector2(bar_w, actual_bar_h)
		if is_drawer_open:
			hand_cards_bar.visible = false
		elif current_page == "S01_MAP":
			hand_cards_bar.visible = true
			hand_cards_bar.position = Vector2((w - bar_w) / 2.0, h - dock_h - actual_bar_h - 2.0)

	# 6. S02 城池底部抽屉（P1: 高度压到紧凑战术条 ≤28–32%，杜绝大块黑白空卡）
	if city_drawer != null:
		var drawer_w := w if (is_phone or is_portrait) else minf(w - 40.0, 840.0)
		var drawer_h := 168.0 if is_compact_h else 210.0
		city_drawer.size = Vector2(drawer_w, drawer_h)
		city_drawer.position = Vector2((w - drawer_w) / 2.0, h - drawer_h)
		if city_drawer_margin != null:
			city_drawer_margin.position = Vector2(10.0, 4.0 if is_compact_h else 6.0)
			city_drawer_margin.size = Vector2(drawer_w - 20.0, drawer_h - (8.0 if is_compact_h else 10.0))
		if city_drawer_handle != null:
			city_drawer_handle.position = Vector2((drawer_w - 44.0) / 2.0, 3.0)

		# 动作按钮尺寸与字号紧凑响应，杜绝在 720x514 手机横屏截断
		var act_btn_h := 34.0 if is_compact_h else 42.0
		var act_font_size := 12 if is_compact_h else 14
		if city_action_advance_btn != null:
			city_action_advance_btn.custom_minimum_size.y = act_btn_h
			city_action_advance_btn.add_theme_font_size_override("font_size", act_font_size)
		if city_action_defend_btn != null:
			city_action_defend_btn.custom_minimum_size.y = act_btn_h
			city_action_defend_btn.add_theme_font_size_override("font_size", act_font_size)
		if city_action_scout_btn != null:
			city_action_scout_btn.custom_minimum_size = Vector2(56 if is_compact_h else 66, act_btn_h)
			city_action_scout_btn.add_theme_font_size_override("font_size", 11 if is_compact_h else 13)
		if city_action_supply_btn != null:
			city_action_supply_btn.custom_minimum_size = Vector2(56 if is_compact_h else 66, act_btn_h)
			city_action_supply_btn.add_theme_font_size_override("font_size", 11 if is_compact_h else 13)
		if city_action_withdraw_btn != null:
			city_action_withdraw_btn.custom_minimum_size = Vector2(56 if is_compact_h else 66, act_btn_h)
			city_action_withdraw_btn.add_theme_font_size_override("font_size", 11 if is_compact_h else 13)

	# 7. S03 军令确认浮层
	if order_confirm_modal != null:
		var mw := minf(w - 32.0, 540.0)
		var mh := minf(h - 32.0, 400.0)
		order_confirm_modal.size = Vector2(mw, mh)
		order_confirm_modal.position = Vector2((w - mw) / 2.0, (h - mh) / 2.0)

	# 8. S04 / S05 / S06 全屏页自适应
	if report_margin != null:
		report_margin.position = Vector2(16, 70)
		report_margin.size = Vector2(w - 32, h - 80)
		
	if replay_margin != null:
		replay_margin.position = Vector2(16, 70)
		replay_margin.size = Vector2(w - 32, h - 80)
		if replay_map != null:
			replay_map.custom_minimum_size = Vector2(0, 200 if is_compact_h else (400 if is_portrait else 340))
			
	if faction_margin != null:
		faction_margin.position = Vector2(16, 70)
		faction_margin.size = Vector2(w - 32, h - 80)
		if faction_cards_container != null:
			faction_cards_container.columns = 1 if is_phone else 2

	if army_margin != null:
		army_margin.position = Vector2(10.0 if is_compact_h else 16.0, 50.0 if is_compact_h else 70.0)
		army_margin.size = Vector2(w - (20.0 if is_compact_h else 32.0), h - (58.0 if is_compact_h else 80.0))

	# 9. Toast 通知条
	if toast_panel != null:
		var tw := minf(w - 40.0, 480.0)
		toast_panel.size = Vector2(tw, 44.0)
		toast_panel.position = Vector2((w - tw) / 2.0, top_h + 8.0)

	if offline_banner != null and offline_banner.visible:
		var banner_w := minf(w - 20.0, 400.0)
		offline_banner.size = Vector2(banner_w, 36.0)
		offline_banner.position = Vector2((w - banner_w) / 2.0, top_h + 4.0)

	# 10. 更新城池触控热区位置
	if map != null and not node_buttons.is_empty():
		for code in node_buttons.keys():
			var b: Button = node_buttons[code]
			if is_instance_valid(b):
				b.size = Vector2(140, 140)
				b.position = map.node_position(code) - Vector2(70, 105)

# ---------------------------------------------------------------------------
# MapView 沙盘视口交互控制器（双指缩放、拖拽平移、双击放大、视野聚焦、边界限制）
# ---------------------------------------------------------------------------

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
				_zoom_at(mb.position, 1.4 if map_zoom < 1.7 else 1.0 / (map_zoom / 1.0))
				get_viewport().set_input_as_handled()
			elif mb.is_pressed():
				is_dragging = true
				drag_start = mb.position
				pan_start = map_pan
			else:
				if is_dragging and (mb.position - drag_start).length() < 6.0:
					# 单击地图空白处，收起城池抽屉，恢复底部通栏 Dock
					if city_drawer != null and city_drawer.visible:
						_toggle_city_drawer(false)
				is_dragging = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if is_dragging:
			map_pan = pan_start + (mm.position - drag_start)
			_clamp_pan()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.is_pressed():
			touch_points[st.index] = st.position
		else:
			touch_points.erase(st.index)
		
		if touch_points.size() == 2:
			var pts := touch_points.values()
			initial_pinch_dist = pts[0].distance_to(pts[1])
			initial_pinch_zoom = map_zoom
		elif touch_points.size() == 1:
			var p: Vector2 = touch_points.values()[0]
			is_dragging = true
			drag_start = p
			pan_start = map_pan
		else:
			is_dragging = false
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		touch_points[sd.index] = sd.position
		if touch_points.size() == 2:
			var pts := touch_points.values()
			var cur_dist: float = pts[0].distance_to(pts[1])
			if initial_pinch_dist > 5.0:
				var factor := cur_dist / initial_pinch_dist
				var center: Vector2 = (pts[0] + pts[1]) / 2.0
				var target_zoom := clampf(initial_pinch_zoom * factor, 0.5, 2.5)
				_set_zoom_direct(center, target_zoom)
		elif touch_points.size() == 1 and is_dragging:
			map_pan = pan_start + (sd.position - drag_start)
			_clamp_pan()

func _zoom_at(focus_screen_pos: Vector2, factor: float) -> void:
	var old_zoom := map_zoom
	var new_zoom := clampf(map_zoom * factor, 0.5, 2.5)
	if is_equal_approx(old_zoom, new_zoom):
		return
	var world_pos := (focus_screen_pos - map_pan) / old_zoom
	map_zoom = new_zoom
	map_pan = focus_screen_pos - world_pos * map_zoom
	_clamp_pan()

func _set_zoom_direct(focus_screen_pos: Vector2, target_zoom: float) -> void:
	var old_zoom := map_zoom
	var new_zoom := clampf(target_zoom, 0.5, 2.5)
	if is_equal_approx(old_zoom, new_zoom):
		return
	var world_pos := (focus_screen_pos - map_pan) / old_zoom
	map_zoom = new_zoom
	map_pan = focus_screen_pos - world_pos * map_zoom
	_clamp_pan()

func reset_view() -> void:
	map_zoom = 1.0
	map_pan = Vector2.ZERO
	_clamp_pan()

func focus_city(code: String) -> void:
	if map == null or map_view == null:
		return
	var pos: Vector2 = map.node_position(code)
	var drawer_h := city_drawer.size.y if (city_drawer != null and city_drawer.visible) else (size.y * 0.28)
	var top_h := top_bar.size.y if top_bar != null else 60.0
	var avail_h := maxf(map_view.size.y - top_h - drawer_h, 120.0)

	# 手机竖屏（720×1280）：所有 5 个城池（A_START到最低的松风渡N1与听雨台N3）天然处于顶部可视区内，
	# 且离抽屉顶边（y=1070）至少有 50~195px 充足安全空间；
	# 未放大时不执行垂直位移，确保水彩底图 100% 贴底铺满，杜绝任何露白与平移空白带。
	if size.x < size.y and map_zoom <= 1.05:
		map_pan = Vector2.ZERO
		_clamp_pan()
		return

	# 横屏与平板环境：
	var target_screen_y := top_h + avail_h / 2.0
	if size.y < 650.0:
		# 手机横屏（720×514）：紧凑视口
		if pos.y > top_h + avail_h - 20.0:
			# 最低城（N1, N3 位于 y=400.9），抽屉顶在 338px
			# 将其向上适度平移，确保城名和归属签（pos.y + 36）位于抽屉上方，同时水彩底图底边深藏抽屉之后
			var desired_screen_y := top_h + avail_h - 55.0
			map_pan.y = desired_screen_y - pos.y * map_zoom
		else:
			map_pan.y = 0.0
		map_pan.x = 0.0
	else:
		map_pan = Vector2(map_view.size.x / 2.0, target_screen_y) - pos * map_zoom
	_clamp_pan()

func _clamp_pan() -> void:
	if map_view == null or map == null or map_world == null:
		return
	var vw := map_view.size.x
	var vh := map_view.size.y
	if vw <= 0.0 or vh <= 0.0:
		return
	var mw := map.size.x * map_zoom
	var mh := map.size.y * map_zoom
	
	if mw <= vw:
		map_pan.x = (vw - mw) / 2.0
	else:
		map_pan.x = clampf(map_pan.x, vw - mw, 0.0)
		
	if mh <= vh:
		# 当地图高度未超过视口：
		if map_zoom < 0.98:
			# 缩小状态（例如 0.5x 全景查看）：沙盘居中
			map_pan.y = (vh - mh) / 2.0
		elif size.x < size.y:
			# 竖屏：保持 0，地图底图 100% 铺满视口，绝不向上平移漏出底板
			map_pan.y = 0.0
		elif city_drawer != null and city_drawer.visible:
			# 横屏且抽屉打开：最大上抬量严格限制在抽屉高度内减去 24px 安全重叠，
			# 确保地图底边（vh + map_pan.y）始终深藏于抽屉（vh - drawer_h）之后至少 24px，绝不露底
			var max_lift := maxf(city_drawer.size.y - 24.0, 0.0)
			map_pan.y = clampf(map_pan.y, -max_lift, 0.0)
		else:
			map_pan.y = 0.0
	else:
		# 放大状态（mh > vh）：允许在实际超出的地图尺寸范围内拖拽平移
		var drawer_lift := city_drawer.size.y if (city_drawer != null and city_drawer.visible) else 0.0
		map_pan.y = clampf(map_pan.y, vh - mh - drawer_lift, 0.0)
		
	map_world.position = map_pan
	map_world.scale = Vector2(map_zoom, map_zoom)
	if map != null and map.has_method("set_zoom_level"):
		map.set_zoom_level(map_zoom)

# ---------------------------------------------------------------------------
# S00 登录界面（大厂游戏画卷风，无杂质）
# ---------------------------------------------------------------------------

func _build_login() -> void:
	login_layer = Control.new()
	login_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(login_layer)

	# C 主视觉水彩纸雕背景（大厂质感，高雅宣纸山水）
	if ResourceLoader.exists("res://assets/art/keyart_c.png"):
		var keyart_tex: Texture2D = load("res://assets/art/keyart_c.png")
		var keyart_rect := TextureRect.new()
		keyart_rect.texture = keyart_tex
		keyart_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		keyart_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		keyart_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		login_layer.add_child(keyart_rect)

		var scrim := ColorRect.new()
		scrim.color = Color(0.12, 0.09, 0.07, 0.42)
		scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		login_layer.add_child(scrim)
	else:
		var bg := ColorRect.new()
		bg.color = C_WOOD_DESK
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		login_layer.add_child(bg)

	var stripe := ColorRect.new()
	stripe.color = C_TENGHUANG
	stripe.position = Vector2(0, 0)
	stripe.size = Vector2(2560, 4)
	login_layer.add_child(stripe)

	login_panel = Panel.new()
	login_panel.position = Vector2((size.x - 520) / 2.0, (size.y - 620) / 2.0)
	login_panel.size = Vector2(520, 620)
	login_panel.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, C_TENGHUANG, 2, 16, 20))
	login_layer.add_child(login_panel)
	var panel := login_panel

	login_inner_box = Panel.new()
	login_inner_box.position = Vector2(10, 10)
	login_inner_box.size = Vector2(500, 600)
	login_inner_box.add_theme_stylebox_override("panel", _style(Color.TRANSPARENT, Color("#dfcaa7"), 1, 12))
	panel.add_child(login_inner_box)

	login_margin = MarginContainer.new()
	login_margin.position = Vector2(28, 30)
	login_margin.size = Vector2(464, 560)
	panel.add_child(login_margin)

	login_vbox = VBoxContainer.new()
	login_vbox.add_theme_constant_override("separation", 14)
	login_margin.add_child(login_vbox)
	var v := login_vbox

	var seal_box := HBoxContainer.new()
	seal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	seal_box.add_theme_constant_override("separation", 8)
	var seal_lbl := _label("青竹文房", 14, C_XUANZHI)
	var seal_p := PanelContainer.new()
	seal_p.add_theme_stylebox_override("panel", _style(C_ZHUSHA, Color("#80241d"), 1, 4, 4))
	seal_p.add_child(seal_lbl)
	seal_box.add_child(seal_p)
	v.add_child(seal_box)

	login_title_lbl = _label("灵宠山河", 38, C_WOOD_DESK)
	login_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(login_title_lbl)

	login_sub_lbl = _label("纸雕国风 · 班宠为将 · 九州沙盘推演", 15, Color("#6d5e4f"))
	login_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(login_sub_lbl)

	login_sep = HSeparator.new()
	login_sep.custom_minimum_size = Vector2(0, 10)
	v.add_child(login_sep)

	name_edit = _line_edit("姓名")
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(name_edit)

	pass_edit = _line_edit("学堂密码")
	pass_edit.secret = true
	pass_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(pass_edit)

	login_student_btn = _button("踏 入 山 河", C_ZHUSHA, 48)
	login_student_btn.add_theme_font_size_override("font_size", 18)
	login_student_btn.pressed.connect(_on_login.bind(false))
	v.add_child(login_student_btn)

	login_status = _label("", 13, C_ZHUSHA)
	login_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	login_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	login_status.custom_minimum_size = Vector2(0, 36)
	v.add_child(login_status)

	login_foot_lbl = _label("班级量化考核系统联动 · 每日 21:00 全班推演结算", 12, Color("#7e6e5a"))
	login_foot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(login_foot_lbl)

	login_gear_btn = Button.new()
	login_gear_btn.text = "⚙️ 网络设置"
	login_gear_btn.position = Vector2(size.x - 124, 18)
	login_gear_btn.size = Vector2(110, 34)
	login_gear_btn.add_theme_font_size_override("font_size", 12)
	login_gear_btn.add_theme_stylebox_override("normal", _style(Color("#2b221a"), Color("#4d3a2a"), 1, 6, 6))
	login_gear_btn.add_theme_color_override("font_color", Color("#c4b295"))
	login_gear_btn.pressed.connect(_open_dev_settings)
	login_layer.add_child(login_gear_btn)

	_build_dev_settings_dialog()

func _build_dev_settings_dialog() -> void:
	dev_settings_dialog = AcceptDialog.new()
	dev_settings_dialog.title = "网络与快捷测试设置"
	dev_settings_dialog.ok_button_text = "确认"
	dev_settings_dialog.min_size = Vector2i(480, 360)

	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(440, 280)
	v.add_theme_constant_override("separation", 10)
	dev_settings_dialog.add_child(v)

	v.add_child(_label("服务器 API 地址 (局域网/公网):", 13, INK))
	url_edit = _line_edit("http://127.0.0.1:8080")
	url_edit.text = "http://127.0.0.1:8080"
	v.add_child(url_edit)

	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 8)
	var fill_student := Button.new()
	fill_student.text = "填入学生测试账号 (青竹一)"
	fill_student.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill_student.custom_minimum_size = Vector2(0, 34)
	fill_student.pressed.connect(_fill_test_student)
	quick.add_child(fill_student)
	v.add_child(quick)

	var local_btn := Button.new()
	local_btn.text = "切换为本机 127.0.0.1:8080"
	local_btn.custom_minimum_size = Vector2(0, 34)
	local_btn.pressed.connect(_use_local_forward)
	v.add_child(local_btn)

	add_child(dev_settings_dialog)

func _open_dev_settings() -> void:
	dev_settings_dialog.popup_centered()

func _fill_test_student() -> void:
	name_edit.text = "青竹一"
	pass_edit.text = "slice2026"

func _use_local_forward() -> void:
	url_edit.text = "http://127.0.0.1:8080"
	api.set_base_url(url_edit.text)
	_save_config()

# ---------------------------------------------------------------------------
# S01 主沙盘与整体游戏分层构建
# ---------------------------------------------------------------------------

func _build_game() -> void:
	game_layer = Control.new()
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_layer.visible = false
	add_child(game_layer)

	# 1. 主地图沙盘 Shell（包含地图、顶部 HUD、左右侧栏、底部导航、城池抽屉）
	map_shell = Control.new()
	map_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_layer.add_child(map_shell)

	# MapView (视口裁剪与触控手势监听) & MapWorld (世界坐标容器，承载底图与城池)
	map_view = Control.new()
	map_view.clip_contents = true
	map_view.mouse_filter = Control.MOUSE_FILTER_PASS
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.gui_input.connect(_on_map_view_gui_input)
	map_shell.add_child(map_view)

	map_world = Control.new()
	map_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.add_child(map_world)

	map = SliceMapScript.new()
	map.size = Vector2(1400, 1000)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_world.add_child(map)

	_build_top_hud()
	_build_side_rails()
	_build_map_legend()
	_build_bottom_dock()
	_build_hand_cards_bar()
	_build_city_drawer()
	_build_order_confirm_modal()
	_build_card_tooltip()
	_build_battle_replay_overlay()

	# 2. 独立全屏页面容器（S04 战报、S05 回放、S06-S13 等）
	pages_container = Control.new()
	pages_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_layer.add_child(pages_container)

	_build_report_page()
	_build_replay_page()
	_build_all_placeholder_pages()

	# 3. 教师后台（抽屉保留以满足权限隔离和无头测试需求）
	_build_teacher_deck()
	_build_recharge_dialog()
	_build_legacy_compat_nodes()

	poll_timer = Timer.new()
	poll_timer.wait_time = 5.0
	poll_timer.timeout.connect(_refresh_state)
	add_child(poll_timer)

# 构建 S01 顶部 HUD
# 构建 S01 顶部 HUD（P0: 改半透明深墨，让地图从下方透出来）
func _build_top_hud() -> void:
	top_bar = Panel.new()
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(size.x, 72)
	top_bar.add_theme_stylebox_override("panel", _style(Color(0.12, 0.09, 0.07, 0.78), Color.TRANSPARENT, 0, 0))
	map_shell.add_child(top_bar)

	gold_line = ColorRect.new()
	gold_line.color = Color(0.81, 0.51, 0.15, 0.75)
	gold_line.position = Vector2(0, 70)
	gold_line.size = Vector2(size.x, 2)
	top_bar.add_child(gold_line)

	# 左侧：头像 + 班宠 + 阵营 + 战力
	hud_left_box = HBoxContainer.new()
	hud_left_box.position = Vector2(16, 12)
	hud_left_box.size = Vector2(300, 48)
	hud_left_box.add_theme_constant_override("separation", 10)
	top_bar.add_child(hud_left_box)

	top_avatar_box = Panel.new()
	top_avatar_box.custom_minimum_size = Vector2(44, 44)
	top_avatar_box.add_theme_stylebox_override("panel", _style(CORAL, GOLD, 2, 22))
	hud_left_box.add_child(top_avatar_box)

	top_pet_icon = _label("令", 20, CREAM)
	top_pet_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_pet_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_pet_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_avatar_box.add_child(top_pet_icon)

	var id_box := VBoxContainer.new()
	id_box.add_theme_constant_override("separation", 2)
	hud_left_box.add_child(id_box)

	title_label = _label("青竹学子", 15, CREAM)
	id_box.add_child(title_label)

	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	id_box.add_child(sub_row)

	faction_label = _label("青竹军", 12, Color("#dfcaa7"))
	sub_row.add_child(faction_label)

	combat_power_label = _label("战力 120", 12, GOLD_LIGHT)
	sub_row.add_child(combat_power_label)

	# 中间：四项粮资与军备文玉
	resource_bar = HBoxContainer.new()
	resource_bar.position = Vector2(340, 14)
	resource_bar.size = Vector2(500, 44)
	resource_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	resource_bar.add_theme_constant_override("separation", 8)
	top_bar.add_child(resource_bar)

	resource_bar.add_child(_create_res_pill("🌾 粮 300"))
	resource_bar.add_child(_create_res_pill("🌲 木 240"))
	resource_bar.add_child(_create_res_pill("⛏️ 铁 180"))

	var wallet_pill := PanelContainer.new()
	wallet_pill.add_theme_stylebox_override("panel", _style(Color("#26323d"), GOLD, 1, 14, 6))
	wallet_label = _label("💎 文玉 0", 13, GOLD_LIGHT)
	wallet_pill.add_child(wallet_label)
	resource_bar.add_child(wallet_pill)

	recharge_btn = _button("+", GOLD, 32)
	recharge_btn.custom_minimum_size = Vector2(32, 32)
	recharge_btn.tooltip_text = "积分兑换文玉"
	recharge_btn.pressed.connect(_open_recharge)
	resource_bar.add_child(recharge_btn)

	# 右侧：倒计时与快捷菜单
	hud_right_box = HBoxContainer.new()
	hud_right_box.position = Vector2(size.x - 440, 14)
	hud_right_box.size = Vector2(420, 44)
	hud_right_box.alignment = BoxContainer.ALIGNMENT_END
	hud_right_box.add_theme_constant_override("separation", 8)
	top_bar.add_child(hud_right_box)

	var timer_pill := PanelContainer.new()
	timer_pill.add_theme_stylebox_override("panel", _style(Color("#0f161e"), Color("#5a4833"), 1, 14, 6))
	countdown_label = _label("⏳ 距 21:00 锁令: --:--", 13, Color("#f3ead8"))
	timer_pill.add_child(countdown_label)
	hud_right_box.add_child(timer_pill)

	var mail_btn := _button("✉️", Color("#33485c"), 44)
	mail_btn.custom_minimum_size = Vector2(44, 44)
	mail_btn.tooltip_text = "军府信件/活动"
	mail_btn.pressed.connect(func(): _navigate_to("S12_MAIL"))
	hud_right_box.add_child(mail_btn)

	var settings_btn := _button("⚙️", Color("#3d2f26"), 44)
	settings_btn.custom_minimum_size = Vector2(44, 44)
	settings_btn.tooltip_text = "学堂设置"
	settings_btn.pressed.connect(func(): _navigate_to("S11_SETTINGS"))
	hud_right_box.add_child(settings_btn)

	var logout_btn := _button("🚪", Color("#3d2f26"), 44)
	logout_btn.custom_minimum_size = Vector2(44, 44)
	logout_btn.tooltip_text = "归隐登出"
	logout_btn.pressed.connect(_on_logout)
	hud_right_box.add_child(logout_btn)

# 构建 S01 左右贴边半透明悬浮图标列（P0: 去除实心黑底栏，改为贴边半透明印章）
func _build_side_rails() -> void:
	rail_buttons.clear()
	left_rail = VBoxContainer.new()
	left_rail.position = Vector2(14, 86)
	left_rail.size = Vector2(48, 220)
	left_rail.add_theme_constant_override("separation", 8)
	map_shell.add_child(left_rail)

	_add_rail_item(left_rail, "🚩 阵营", "🚩", func(): _navigate_to("S06_FACTION"))
	_add_rail_item(left_rail, "🐾 将军", "🐾", func(): _navigate_to("S07_GENERAL"))
	_add_rail_item(left_rail, "📜 图鉴", "📜", func(): _navigate_to("S08_CODEX"))
	_add_rail_item(left_rail, "🎯 任务", "🎯", func(): _navigate_to("S13_TASKS"))

	right_rail = VBoxContainer.new()
	right_rail.position = Vector2(size.x - 62, 86)
	right_rail.size = Vector2(48, 220)
	right_rail.add_theme_constant_override("separation", 8)
	map_shell.add_child(right_rail)

	_add_rail_item(right_rail, "🎯 全图", "🎯", reset_view)
	_add_rail_item(right_rail, "🏮 榷场", "🏮", func(): _navigate_to("S09_SHOP"))
	_add_rail_item(right_rail, "🏆 赛季", "🏆", func(): _navigate_to("S10_SEASON"))
	_add_rail_item(right_rail, "⚙️ 设置", "⚙️", func(): _navigate_to("S11_SETTINGS"))

func _add_rail_item(parent: Control, full_text: String, icon_only: String, on_click: Callable) -> void:
	var btn := Button.new()
	btn.text = icon_only
	btn.tooltip_text = full_text
	btn.custom_minimum_size = Vector2(46, 46)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color("#f5ecd7"))
	btn.add_theme_stylebox_override("normal", _style(Color(0.12, 0.09, 0.07, 0.72), Color(0.81, 0.51, 0.15, 0.65), 1.5, 8, 4))
	btn.add_theme_stylebox_override("hover", _style(Color(0.22, 0.16, 0.12, 0.88), GOLD, 1.5, 8, 4))
	btn.add_theme_stylebox_override("pressed", _style(Color(0.08, 0.06, 0.04, 0.95), CORAL, 1.5, 8, 4))
	btn.pressed.connect(on_click)
	parent.add_child(btn)
	rail_buttons.append({"btn": btn, "full": full_text, "icon": icon_only})

# 构建固定 UI 图例（P0: 固定于屏幕视口左侧，绝不随相机平移缩放错位，不遮挡任何城池）
func _build_map_legend() -> void:
	legend_panel = PanelContainer.new()
	legend_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend_panel.add_theme_stylebox_override("panel", _style(Color(0.12, 0.09, 0.07, 0.78), Color(0.81, 0.51, 0.15, 0.65), 1, 6, 4))
	map_shell.add_child(legend_panel)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 6)
	legend_panel.add_child(hbox)

	var tag_title := _label("势态：", 11, CREAM)
	tag_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(tag_title)

	var tags = [["🔴笔", CORAL], ["🔵墨", C_MOLAN], ["⚪中立", Color("#dfcaa7")]]
	for t in tags:
		var l := _label(str(t[0]), 11, t[1])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(l)

# 构建 S01 底部导航栏（P0: 贴底通栏半透明条）
func _build_bottom_dock() -> void:
	bottom_dock = Panel.new()
	bottom_dock.position = Vector2(0, size.y - 60)
	bottom_dock.size = Vector2(size.x, 60)
	bottom_dock.add_theme_stylebox_override("panel", _style(Color(0.12, 0.09, 0.07, 0.85), Color(0.81, 0.51, 0.15, 0.7), 1, 0))
	map_shell.add_child(bottom_dock)

	dock_row = HBoxContainer.new()
	dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_row.add_theme_constant_override("separation", 8)
	bottom_dock.add_child(dock_row)

	_add_dock_tab(dock_row, "S01_MAP", "🗺️", "沙盘地图", func(): _navigate_to("S01_MAP"))
	_add_dock_tab(dock_row, "S02_CITY_HUB", "🏯", "主城行营", func(): _navigate_to("S02_CITY_HUB"))
	_add_dock_tab(dock_row, "S03_ARMY", "⚔️", "军团编组", func(): _navigate_to("S03_ARMY"))
	_add_dock_tab(dock_row, "S04_REPORT", "📜", "战争日报", func(): _open_report())
	_add_dock_tab(dock_row, "S05_REPLAY", "🔄", "战局复盘", func(): _open_replay())

	_update_dock_highlight("S01_MAP")

func _add_dock_tab(parent: Control, page_id: String, icon: String, title: String, on_click: Callable) -> void:
	var btn := Button.new()
	btn.text = "%s %s" % [icon, title]
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 46)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color("#d5c4a1"))
	btn.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 8, 6))
	btn.add_theme_stylebox_override("hover", _style(Color("#2d231b"), GOLD, 1, 8, 6))
	btn.add_theme_stylebox_override("pressed", _style(Color("#1d1612"), GOLD, 1, 8, 6))
	btn.pressed.connect(on_click)
	parent.add_child(btn)
	dock_tab_buttons[page_id] = btn

# 抽屉显示状态与底部 Dock 避让让位联动（设计系统动效：220ms TRANS_CUBIC EASE_OUT）
func _toggle_city_drawer(is_show: bool) -> void:
	is_drawer_open = is_show
	if city_drawer == null:
		return
	var is_compact_h := size.y < 650.0
	var drawer_h := 168.0 if is_compact_h else 210.0
	var dock_h := 46.0 if is_compact_h else (56.0 if (size.x < 900.0 or is_compact_h) else 60.0)
	
	if is_instance_valid(drawer_tween) and drawer_tween.is_running():
		drawer_tween.kill()

	if is_show:
		city_drawer.visible = true
		city_drawer.position.y = size.y
		if legend_panel != null:
			legend_panel.visible = false
		if hand_cards_bar != null:
			hand_cards_bar.visible = false
		drawer_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		drawer_tween.tween_property(city_drawer, "position:y", size.y - drawer_h, 0.22)
		if bottom_dock != null:
			drawer_tween.tween_property(bottom_dock, "position:y", size.y, 0.22)
	else:
		if legend_panel != null:
			legend_panel.visible = true
		if hand_cards_bar != null and current_page == "S01_MAP":
			hand_cards_bar.visible = true
		drawer_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		drawer_tween.tween_property(city_drawer, "position:y", size.y, 0.18)
		if bottom_dock != null:
			drawer_tween.tween_property(bottom_dock, "position:y", size.y - dock_h, 0.18)
		drawer_tween.chain().tween_callback(func():
			if is_instance_valid(city_drawer):
				city_drawer.visible = false
		)
	_clamp_pan()

# ---------------------------------------------------------------------------
# S02 城池底部抽屉（P1: 高度压至 28-30%，战术面板首屏优先）
# ---------------------------------------------------------------------------

func _build_city_drawer() -> void:
	city_drawer = Panel.new()
	city_drawer.position = Vector2(280, 720)
	city_drawer.size = Vector2(840, 280)
	city_drawer.add_theme_stylebox_override("panel", _style(Color("#1e1712", 0.96), Color(0.81, 0.51, 0.15, 0.85), 2, 12))
	city_drawer.visible = false
	map_shell.add_child(city_drawer)

	# 顶部抽屉拖拽把手
	city_drawer_handle = Panel.new()
	city_drawer_handle.position = Vector2((city_drawer.size.x - 44) / 2.0, 3)
	city_drawer_handle.size = Vector2(44, 3)
	city_drawer_handle.add_theme_stylebox_override("panel", _style(Color("#8a7862"), Color.TRANSPARENT, 0, 2))
	city_drawer.add_child(city_drawer_handle)

	city_drawer_margin = MarginContainer.new()
	city_drawer_margin.position = Vector2(16, 8)
	city_drawer_margin.size = Vector2(808, 264)
	city_drawer.add_child(city_drawer_margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	city_drawer_margin.add_child(v)

	# 1. 顶部城池标牌与功能按钮
	var h_top := HBoxContainer.new()
	h_top.add_theme_constant_override("separation", 10)
	v.add_child(h_top)

	city_avatar_box = Panel.new()
	city_avatar_box.custom_minimum_size = Vector2(38, 38)
	city_avatar_box.add_theme_stylebox_override("panel", _style(BAMBOO, GOLD, 1, 8))
	h_top.add_child(city_avatar_box)

	city_avatar_icon = _label("🏯", 20, CREAM)
	city_avatar_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	city_avatar_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	city_avatar_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	city_avatar_box.add_child(city_avatar_icon)

	var title_v := VBoxContainer.new()
	title_v.add_theme_constant_override("separation", 1)
	title_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_top.add_child(title_v)

	var row_name := HBoxContainer.new()
	row_name.add_theme_constant_override("separation", 8)
	title_v.add_child(row_name)

	city_title_label = _label("【据点名称】", 17, GOLD_LIGHT)
	row_name.add_child(city_title_label)

	city_type_badge = _label("[要塞关隘]", 12, GOLD)
	row_name.add_child(city_type_badge)

	city_faction_badge = _label("归属：中立关塞", 12, Color("#d5c4a1"))
	row_name.add_child(city_faction_badge)

	# 右上角小“传”文脉按钮与关闭
	var top_btns := HBoxContainer.new()
	top_btns.add_theme_constant_override("separation", 8)
	h_top.add_child(top_btns)

	var lore_btn := Button.new()
	lore_btn.text = "📜 传"
	lore_btn.tooltip_text = "查看城池文脉与小传"
	lore_btn.custom_minimum_size = Vector2(48, 32)
	lore_btn.add_theme_font_size_override("font_size", 13)
	lore_btn.add_theme_color_override("font_color", GOLD_LIGHT)
	lore_btn.add_theme_stylebox_override("normal", _style(Color("#2d2218", 0.9), GOLD, 1, 6, 4))
	lore_btn.pressed.connect(_open_city_lore_dialog)
	top_btns.add_child(lore_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, Color("#baa789"), 1, 15))
	close_btn.pressed.connect(func(): _toggle_city_drawer(false))
	top_btns.add_child(close_btn)

	# 2. 战术属性卡片（守备+战力差 / 驰道+军令）
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 10)
	v.add_child(info_row)

	# 左卡：城防守备与敌我战力差
	var def_box := PanelContainer.new()
	def_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	def_box.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 6, 8))
	info_row.add_child(def_box)
	var def_v := VBoxContainer.new()
	def_v.add_theme_constant_override("separation", 2)
	def_box.add_child(def_v)
	city_def_badge = _label("🛡️ 城防守备：3 / 3 点 · 坚固", 13, C_ZHUSHA)
	def_v.add_child(city_def_badge)
	city_morale_badge = _label("❤️ 城池民心：0 / 2 格", 12, C_TENGHUANG)
	def_v.add_child(city_morale_badge)
	city_power_diff_label = _label("⚔️ 战意差：我方 0 vs 敌方 0", 12, Color("#554433"))
	def_v.add_child(city_power_diff_label)
	city_garrison_label = _label("👥 驻防状态：守备严整", 11, Color("#665544"))
	def_v.add_child(city_garrison_label)

	# 右卡：驰道地理与今日军令
	var route_box := PanelContainer.new()
	route_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route_box.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 6, 8))
	info_row.add_child(route_box)
	var route_v := VBoxContainer.new()
	route_v.add_theme_constant_override("separation", 2)
	route_box.add_child(route_v)
	city_routes_label = _label("🗺️ 连通驰道：--", 13, C_WOOD_DESK)
	route_v.add_child(city_routes_label)
	city_order_hint = _label("📢 今日军令：待命中 · 请选下方指令", 12, C_MOLAN)
	route_v.add_child(city_order_hint)
	city_tactical_label = _label("🎯 战术地位：兵家必争，交锋要冲", 11, Color("#665544"))
	route_v.add_child(city_tactical_label)

	# 3. 动作操作栏（首屏优先：主动作大按钮突出，次级动作紧凑排布）
	var h_act := HBoxContainer.new()
	h_act.add_theme_constant_override("separation", 8)
	v.add_child(h_act)

	# 主动作：进军与驻守
	city_action_advance_btn = _button("⚔️ 进军攻打", C_ZHUSHA, 44)
	city_action_advance_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_action_advance_btn.pressed.connect(_on_city_advance_pressed)
	h_act.add_child(city_action_advance_btn)

	city_action_defend_btn = _button("🛡️ 驻守据点", C_ZHUQING, 44)
	city_action_defend_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_action_defend_btn.pressed.connect(_on_city_defend_pressed)
	h_act.add_child(city_action_defend_btn)

	city_action_battle_btn = _button("⚔️ 演武决战", Color("#8c3a32"), 44)
	city_action_battle_btn.custom_minimum_size = Vector2(88, 44)
	city_action_battle_btn.add_theme_font_size_override("font_size", 13)
	city_action_battle_btn.pressed.connect(func(): _start_demo_battle(selected_code))
	h_act.add_child(city_action_battle_btn)

	# 次级动作：哨探军报（打出哨探才出现）、补给、撤销
	city_action_scout_btn = _button("🔍 哨探军报", Color("#2c4a5e"), 44)
	city_action_scout_btn.custom_minimum_size = Vector2(88, 44)
	city_action_scout_btn.add_theme_font_size_override("font_size", 13)
	city_action_scout_btn.pressed.connect(func(): _open_city_intel_dialog(selected_code))
	city_action_scout_btn.visible = false
	h_act.add_child(city_action_scout_btn)

	city_action_supply_btn = _button("🌾 补给", Color("#423429"), 44)
	city_action_supply_btn.custom_minimum_size = Vector2(66, 44)
	city_action_supply_btn.add_theme_font_size_override("font_size", 13)
	city_action_supply_btn.pressed.connect(func(): _toast("【军需官】本据点粮草充足，士饱马腾！"))
	h_act.add_child(city_action_supply_btn)

	city_action_withdraw_btn = _button("↩️ 撤销", Color("#5c4c3d"), 44)
	city_action_withdraw_btn.custom_minimum_size = Vector2(66, 44)
	city_action_withdraw_btn.add_theme_font_size_override("font_size", 13)
	city_action_withdraw_btn.pressed.connect(_withdraw_order)
	h_act.add_child(city_action_withdraw_btn)

	# 4. 独立城池小传弹窗与哨探情报弹窗
	_build_city_lore_dialog()
	_build_city_intel_dialog()

func _build_city_lore_dialog() -> void:
	city_lore_dialog = AcceptDialog.new()
	city_lore_dialog.title = "城池文脉与小传"
	city_lore_dialog.ok_button_text = "知悉"
	city_lore_dialog.min_size = Vector2i(460, 240)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	city_lore_dialog.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	city_lore_label = _label("城池小传：--", 14, Color("#443322"))
	city_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(city_lore_label)

	add_child(city_lore_dialog)

func _open_city_lore_dialog() -> void:
	if city_lore_dialog != null:
		city_lore_dialog.popup_centered()

func _build_city_intel_dialog() -> void:
	city_intel_dialog = AcceptDialog.new()
	city_intel_dialog.title = "🔍 哨探敌情密报"
	city_intel_dialog.ok_button_text = "知悉军情"
	city_intel_dialog.min_size = Vector2i(480, 320)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	city_intel_dialog.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(448, 250)
	margin.add_child(scroll)

	city_intel_vbox = VBoxContainer.new()
	city_intel_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_intel_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(city_intel_vbox)

	city_intel_status_lbl = _label("密探急报传输中...", 12, Color("#776655"))
	city_intel_vbox.add_child(city_intel_status_lbl)

	add_child(city_intel_dialog)

func _open_city_intel_dialog(node_code: String) -> void:
	if node_code == "":
		node_code = selected_code if selected_code != "" else "N2"
	var n_name := str(map.node_by_code(node_code).get("name", node_code))
	if city_intel_dialog == null:
		return
	city_intel_dialog.title = "🔍【%s】哨探敌情密报" % n_name
	city_intel_dialog.popup_centered()

	for c in city_intel_vbox.get_children():
		c.queue_free()

	city_intel_status_lbl = _label("正在密调【%s】前哨飞鸽急信..." % n_name, 12, Color("#776655"))
	city_intel_vbox.add_child(city_intel_status_lbl)

	api.get_intel(node_code, _turn_id(), func(ok: bool, data: Dictionary, err: Dictionary):
		if not is_instance_valid(city_intel_vbox):
			return
		for c in city_intel_vbox.get_children():
			c.queue_free()

		if not ok:
			var msg := str(err.get("message", "未能获取哨探情报"))
			var err_l := _label("⚠️ 军报受阻：%s" % msg, 13, C_ZHUSHA)
			city_intel_vbox.add_child(err_l)
			return

		# 1. 敌方一路情报
		var lane_box := PanelContainer.new()
		lane_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lane_box.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 6, 8))
		city_intel_vbox.add_child(lane_box)

		var lane_v := VBoxContainer.new()
		lane_v.add_theme_constant_override("separation", 4)
		lane_box.add_child(lane_v)

		var lane_title := _label("🛡️ 敌军守阵探报（侦得一路部属）", 13, C_ZHUSHA)
		lane_v.add_child(lane_title)

		var lane_data: Dictionary = data.get("lane", {})
		if not lane_data.is_empty():
			var l_num := int(lane_data.get("lane", 1))
			var u_type := str(lane_data.get("type", "spear"))
			var u_name := str(lane_data.get("name", "枪"))
			var row_val := str(lane_data.get("row", "front"))
			var row_name := "前排" if row_val == "front" else "后排"
			var troops := int(lane_data.get("troops", 0))
			var icon_map := {"cav": "🏇", "shield": "🛡️", "arc": "🏹", "spear": "🗡️"}
			var icon := str(icon_map.get(u_type, "⚔️"))

			var est_low := int(troops * 0.95)
			var est_high := int(ceil(troops * 1.05))
			var detail_l := _label("%s 兵种：%s兵 | %d路%s | 侦测兵力：估计 %d–%d 兵 (疑似 %d 兵)" % [icon, u_name, l_num, row_name, est_low, est_high, troops], 12, Color("#332211"))
			lane_v.add_child(detail_l)
		else:
			var empty_l := _label("（城关未布设独立防线或无守军）", 12, Color("#665544"))
			lane_v.add_child(empty_l)

		# 2. 诸军集结概览
		var mass_box := PanelContainer.new()
		mass_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mass_box.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 6, 8))
		city_intel_vbox.add_child(mass_box)

		var mass_v := VBoxContainer.new()
		mass_v.add_theme_constant_override("separation", 6)
		mass_box.add_child(mass_v)

		var mass_title := _label("🚩 该城诸军动向与集结态势", 13, C_MOLAN)
		mass_v.add_child(mass_title)

		var mass_list: Array = data.get("massing", [])
		if mass_list.is_empty():
			var no_mass := _label("本城四野暂无活跃大队集结。", 12, Color("#665544"))
			mass_v.add_child(no_mass)
		else:
			var faction_map := {"bi": "笔", "bamboo": "笔", "mo": "墨", "ink": "墨", "yan": "砚", "zhi": "纸"}
			var my_fc := _my_faction_code()
			var my_fn := _my_faction_name()
			for m in mass_list:
				if typeof(m) != TYPE_DICTIONARY:
					continue
				var f_code := str(m.get("faction", ""))
				var f_name := str(m.get("name", faction_map.get(f_code, f_code)))
				var p_cnt := int(m.get("players", 0))
				var t_cnt := int(m.get("teams", 0))
				var troops := int(m.get("troops", 0))
				var is_feint := bool(m.get("feint", false))
				var is_my := (f_code == my_fc or f_name == my_fn or (my_fc in ["bi", "bamboo"] and f_code in ["bi", "bamboo"]) or (my_fc in ["mo", "ink"] and f_code in ["mo", "ink"]))

				var row_panel := PanelContainer.new()
				if is_my:
					row_panel.add_theme_stylebox_override("panel", _style(Color("#212b24"), Color("#4e7a5d"), 1, 4, 6))
				elif is_feint:
					row_panel.add_theme_stylebox_override("panel", _style(Color("#2c221a"), Color("#cf7b32"), 1, 4, 6))
				else:
					row_panel.add_theme_stylebox_override("panel", _style(Color("#f0e8dc"), Color("#baa892"), 1, 4, 6))
				mass_v.add_child(row_panel)

				var row_v := VBoxContainer.new()
				row_v.add_theme_constant_override("separation", 2)
				row_panel.add_child(row_v)

				var f_icon := "🔴" if f_name == "笔" else ("🔵" if f_name == "墨" else "🚩")
				var txt_col := Color("#bce5c8") if is_my else (Color("#fae19c") if is_feint else Color("#221a12"))
				
				var m_line := Label.new()
				if is_my:
					if is_feint:
						var real_troops := int(round(float(troops) / 1.5))
						m_line.text = "%s 【我方·%s阵营】 %d位同窗 · %d队 · 真实兵力 %d 兵 (外示 %d 兵)" % [f_icon, f_name, p_cnt, t_cnt, real_troops, troops]
					else:
						m_line.text = "%s 【我方·%s阵营】 %d位同窗 · %d队 · 真实兵力 %d 兵" % [f_icon, f_name, p_cnt, t_cnt, troops]
				else:
					var est_low := int(troops * 0.95)
					var est_high := int(ceil(troops * 1.05))
					if is_feint:
						m_line.text = "%s 【敌方·%s阵营】 %d位学子 · %d队 · 估计兵力：约 %d–%d 兵 [疑似 %d 兵·虚张]" % [f_icon, f_name, p_cnt, t_cnt, est_low, est_high, troops]
					else:
						m_line.text = "%s 【敌方·%s阵营】 %d位学子 · %d队 · 估计兵力：约 %d–%d 兵 [疑似 %d 兵]" % [f_icon, f_name, p_cnt, t_cnt, est_low, est_high, troops]
				m_line.add_theme_color_override("font_color", txt_col)
				m_line.add_theme_font_size_override("font_size", 12)
				row_v.add_child(m_line)

				if is_my and is_feint:
					var tip_l := Label.new()
					tip_l.text = "✨【我军疑兵】本部已施展疑兵之计瞒天过海，敌方所见我军兵力已被虚夸 1.5 倍！"
					tip_l.add_theme_color_override("font_color", Color("#8ec99e"))
					tip_l.add_theme_font_size_override("font_size", 10)
					row_v.add_child(tip_l)
				elif not is_my and is_feint:
					var warn_l := Label.new()
					warn_l.text = "⚠️【疑兵虚张】情报兵力已被虚夸1.5倍，非真实数字！"
					warn_l.add_theme_color_override("font_color", Color("#e88d43"))
					warn_l.add_theme_font_size_override("font_size", 10)
					row_v.add_child(warn_l)
	)

func _my_faction_code() -> String:
	var f: Variant = me.get("faction", null)
	if typeof(f) == TYPE_DICTIONARY:
		return str(f.get("code", "bamboo"))
	elif typeof(f) == TYPE_STRING and str(f) != "":
		return str(f)
	return "bamboo"

func _my_faction_name() -> String:
	var f: Variant = me.get("faction", null)
	if typeof(f) == TYPE_DICTIONARY:
		return str(f.get("name", "笔"))
	var code := _my_faction_code()
	return "笔" if code == "bamboo" else ("墨" if code == "ink" else "中立")

func _open_city_drawer(code: String) -> void:
	var n: Dictionary = map.node_by_code(code)
	if n.is_empty():
		var all_nodes: Array = state.get("map", {}).get("nodes", state.get("nodes", []))
		if not all_nodes.is_empty():
			n = all_nodes[0]
			code = str(n.get("code", "A_START"))
		else:
			return

	selected_code = code
	map.set_selected(code)
	var c_name := str(n.get("name", code))
	var is_start := bool(n.get("is_start", false))
	var is_mine := bool(n.get("is_my_faction", false))
	var owner: Variant = n.get("owner", null)
	var owner_name := "中立关塞"
	var owner_color := Color("#7e7263")
	if typeof(owner) == TYPE_DICTIONARY:
		owner_name = str(owner.get("name", "中立")) + "阵营"
		var code_str := str(owner.get("code", ""))
		if code_str == "bamboo":
			owner_color = BAMBOO
		elif code_str == "ink":
			owner_color = Color("#1e252b")
		elif code_str == "crimson":
			owner_color = CORAL
		elif code_str == "azure":
			owner_color = Color("#2a4e6c")
		
	city_title_label.text = "【%s】" % c_name
	city_type_badge.text = "[主营大本营]" if is_start else "[要冲关隘]"
	city_faction_badge.text = "归属：%s" % owner_name
	city_avatar_box.add_theme_stylebox_override("panel", _style(owner_color, GOLD, 1, 8))
	
	var def_points := int(n.get("defense", 3))
	city_def_badge.text = "🛡️ 城防守备：%d / 3 点" % def_points
	if n.has("morale") and n.has("morale_cap"):
		var m_cur := int(n.get("morale", 0))
		var m_cap := int(n.get("morale_cap", 2))
		var m_boxes := ""
		for i in range(m_cap):
			m_boxes += "■ " if i < m_cur else "□ "
		city_morale_badge.text = "❤️ 民心所向：%s(%d/%d格·满格易主)" % [m_boxes, m_cur, m_cap]
		city_morale_badge.visible = true
	else:
		city_morale_badge.visible = false
	if is_mine:
		city_garrison_label.text = "👥 驻防状态：我方据点 · 守备严整"
	elif typeof(owner) == TYPE_DICTIONARY and str(owner.get("code", "")) != "" and str(owner.get("code", "")) != "neutral":
		city_garrison_label.text = "👥 驻防状态：敌方据点 · 戒备森严"
	else:
		city_garrison_label.text = "👥 驻防状态：中立关塞 · 虚席以待"

	var pts_bamboo := int(n.get("points_bamboo", 0))
	if pts_bamboo == 0:
		pts_bamboo = int(n.get("points_bi", 0))
	var pts_ink := int(n.get("points_ink", 0))
	if pts_ink == 0:
		pts_ink = int(n.get("points_mo", 0))
	var my_fcode := _my_faction_code()
	var diff_str := ""
	if my_fcode == "bi" or my_fcode == "bamboo":
		diff_str = "⚔️ 战意差：我方(笔) %d vs 敌方(墨) %d" % [pts_bamboo, pts_ink]
	elif my_fcode == "mo" or my_fcode == "ink":
		diff_str = "⚔️ 战意差：我方(墨) %d vs 敌方(笔) %d" % [pts_ink, pts_bamboo]
	else:
		diff_str = "⚔️ 战意差：笔阵营 %d vs 墨阵营 %d" % [pts_bamboo, pts_ink]
	city_power_diff_label.text = diff_str

	var neighbors := _neighbors(code)
	city_routes_label.text = "🗺️ 连通驰道：%s" % ("、".join(neighbors) if neighbors.size() > 0 else "无")
	city_tactical_label.text = "🎯 战术地位：东南重镇，粮秣咽喉" if is_start else "🎯 战术地位：兵家必争，交锋要害"

	var lore := ""
	match code:
		"A_START": lore = "唐风边塞，烽火台高踞山脊。控扼北道，是青竹书院的门户。"
		"N1": lore = "兰舟晚渡，松风两岸。谁掌握渡口，谁就掌握粮道。"
		"N2": lore = "耕读传家，稻浪千顷。看似无险，却是四路交汇的粮仓。"
		"N3": lore = "琴心竹韵，烟雨楼台。高台可望十里，是侦察与奇袭的支点。"
		"B_START": lore = "鸿雁关山，塞下秋声。墨点精据此为营，与云麓关遥遥相望。"
		_: lore = "山河要冲，兵家必争。"
	city_lore_label.text = "城池小传：" + lore
	if city_lore_dialog != null:
		city_lore_dialog.title = "【%s】城池文脉与小传" % c_name

	var role := str(me.get("role", "player"))
	var can_edit := bool(state.get("can_edit", false)) and role == "player" and not order_submitting
	var order: Variant = state.get("my_order", null)
	city_action_withdraw_btn.disabled = not can_edit or typeof(order) != TYPE_DICTIONARY

	var cur_week := _current_week()
	var is_king := _is_king_node(code, n)

	if is_mine:
		city_action_advance_btn.text = "🛡️ 驻守此城"
		city_action_advance_btn.tooltip_text = "向己方据点下达驻守军令，前3位学子队伍将代表阵营迎战来犯敌军"
		city_action_advance_btn.disabled = not can_edit
		city_action_defend_btn.disabled = not can_edit
	else:
		city_action_advance_btn.text = "⚔️ 进军攻打"
		city_action_advance_btn.tooltip_text = "下达进军军令，向该目标据点出征"
		city_action_advance_btn.disabled = not can_edit
		city_action_defend_btn.disabled = true

	# 长安王城与赛季阶段规则
	if is_king and cur_week < 3:
		city_action_advance_btn.disabled = true
		city_action_advance_btn.text = "🔒 第 3 周开放"
		city_action_advance_btn.tooltip_text = "中央帝都长安第 3 周开放，前两周专注于开拓四野"
	elif cur_week >= 4 and not _is_changan_or_neighbor(code):
		city_action_advance_btn.disabled = true
		city_action_advance_btn.text = "🔒 决战周限长安及邻城"
		city_action_advance_btn.tooltip_text = "第 4 周决战周已至，诸军仅可会战长安及邻近要冲！"

	if typeof(order) == TYPE_DICTIONARY:
		var act := str(order.get("action", ""))
		var t_name := str(order.get("target_name", ""))
		city_order_hint.text = "今日已令：向【%s】%s，帅印已加盖！" % [t_name, "进军攻打" if act == "advance" else "驻守据点"]
	else:
		if is_mine:
			city_order_hint.text = "今日军令：己方要冲据点 · 可点击【🛡️ 驻守此城】"
		else:
			city_order_hint.text = "今日军令：待命中 · 请选择下方军略指令"

	# 检查本城是否已打出哨探将令（Phase 1.5 哨探情报入口）
	var has_scout_on_city := false
	var orders_val: Variant = state.get("card_orders", [])
	if typeof(orders_val) == TYPE_ARRAY:
		for ord in orders_val:
			if typeof(ord) == TYPE_DICTIONARY:
				if str(ord.get("card_code", "")) == "scout" and str(ord.get("target_node_code", "")) == code:
					has_scout_on_city = true
					break

	if city_action_scout_btn != null:
		city_action_scout_btn.visible = has_scout_on_city
		if has_scout_on_city:
			city_action_scout_btn.text = "🔍 哨探军报"
			city_action_scout_btn.tooltip_text = "点击查阅哨探刺探到的该城敌军军情与集结动向"

	if not has_scout_on_city and city_intel_dialog != null and city_intel_dialog.visible:
		city_intel_dialog.hide()

	_toggle_city_drawer(true)
	_render_hand_cards()
	_layout_responsive()
	focus_city(code)

func _current_week() -> int:
	var turn_no := int(state.get("turn", {}).get("turn_no", 1))
	return int(ceil(float(turn_no) / 7.0))

func _is_king_node(code: String, n: Dictionary) -> bool:
	if code == "changan":
		return true
	if str(n.get("node_type", "")) == "king" or bool(n.get("is_king", false)):
		return true
	return false

func _is_changan_or_neighbor(code: String) -> bool:
	if code == "changan":
		return true
	for e in state.get("map", {}).get("edges", []):
		if typeof(e) != TYPE_ARRAY or e.size() < 2:
			continue
		if (str(e[0]) == "changan" and str(e[1]) == code) or (str(e[1]) == "changan" and str(e[0]) == code):
			return true
	return false

func _my_faction_asset_code() -> String:
	var c := _my_faction_code()
	if c == "bamboo" or c == "bi": return "bi"
	if c == "ink" or c == "mo": return "mo"
	if c == "shuang" or c == "yan": return "yan"
	if c == "dan" or c == "zhi": return "zhi"
	return "bi"

func _on_city_advance_pressed() -> void:
	if selected_code == "":
		return
	var n: Dictionary = map.node_by_code(selected_code)
	var is_mine := bool(n.get("is_my_faction", false))
	if is_mine:
		_on_city_defend_pressed()
		return
	var my_origin := _find_adjacent_my_node(selected_code)
	if my_origin == "":
		_toast("此城与己方领地不相邻，无法下令进军！", true)
		return
	confirm_action_type = "advance"
	confirm_origin_code = my_origin
	confirm_target_code = selected_code
	_open_order_confirm()

func _on_city_defend_pressed() -> void:
	if selected_code == "":
		return
	confirm_action_type = "defend"
	confirm_origin_code = selected_code
	confirm_target_code = selected_code
	_open_order_confirm()

func _find_adjacent_my_node(target: String) -> String:
	for e in state.get("map", {}).get("edges", []):
		if typeof(e) != TYPE_ARRAY or e.size() < 2:
			continue
		var a := str(e[0])
		var b := str(e[1])
		if a == target:
			if bool(map.node_by_code(b).get("is_my_faction", false)):
				return b
		elif b == target:
			if bool(map.node_by_code(a).get("is_my_faction", false)):
				return a
	return ""

# ---------------------------------------------------------------------------
# S03 军令确认浮层
# ---------------------------------------------------------------------------

func _build_order_confirm_modal() -> void:
	order_confirm_overlay = ColorRect.new()
	order_confirm_overlay.color = Color(0, 0, 0, 0.55)
	order_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	order_confirm_overlay.visible = false
	game_layer.add_child(order_confirm_overlay)

	order_confirm_modal = Panel.new()
	order_confirm_modal.position = Vector2(420, 300)
	order_confirm_modal.size = Vector2(560, 400)
	order_confirm_modal.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, C_TENGHUANG, 2, 16, 20))
	order_confirm_overlay.add_child(order_confirm_modal)

	var margin := MarginContainer.new()
	margin.position = Vector2(24, 20)
	margin.size = Vector2(512, 360)
	order_confirm_modal.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	confirm_title_label = _label("⚔️ 九州军令出征确认", 20, C_WOOD_DESK)
	confirm_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(confirm_title_label)

	var sep1 := HSeparator.new()
	v.add_child(sep1)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color("#f7f0e1"), Color("#dfcaa7"), 1, 8, 12))
	var card_v := VBoxContainer.new()
	card_v.add_theme_constant_override("separation", 8)
	card.add_child(card_v)
	v.add_child(card)

	confirm_origin_label = _label("出发据点：【问津关】", 14, C_WOOD_DESK)
	card_v.add_child(confirm_origin_label)

	confirm_target_label = _label("目标据点：【墨池隘】", 14, C_ZHUSHA)
	card_v.add_child(confirm_target_label)

	confirm_pet_label = _label("出征灵宠：青竹灵猫（战力 120）", 14, C_ZHUQING)
	card_v.add_child(confirm_pet_label)

	confirm_cost_label = _label("军令开销：今日军令 1 道（每日限 1 道）", 13, Color("#7a5223"))
	card_v.add_child(confirm_cost_label)

	confirm_hint_label = _label("决算谕告：今夕 21:00 准时决战，战果载入次日战报", 12, Color("#685848"))
	v.add_child(confirm_hint_label)

	var row_act := HBoxContainer.new()
	row_act.add_theme_constant_override("separation", 14)
	v.add_child(row_act)

	var cancel_btn := _button("再作权衡", C_MOLAN, 44)
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(func(): order_confirm_overlay.visible = false)
	row_act.add_child(cancel_btn)

	var do_confirm_btn := _button("加盖军印", C_ZHUSHA, 44)
	do_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	do_confirm_btn.pressed.connect(_on_confirm_order_pressed)
	row_act.add_child(do_confirm_btn)

func _open_order_confirm() -> void:
	var orig_name := str(map.node_by_code(confirm_origin_code).get("name", confirm_origin_code))
	var targ_name := str(map.node_by_code(confirm_target_code).get("name", confirm_target_code))
	var pet_name := str(me.get("pet", {}).get("name", "青竹灵宠"))

	if confirm_action_type == "advance":
		confirm_title_label.text = "⚔️ 进军出征确认"
		confirm_origin_label.text = "出发据点：【%s】" % orig_name
		confirm_target_label.text = "进军目标：【%s】" % targ_name
		confirm_cost_label.text = "军令开销：今日军令 1 道（每日限 1 道）"
		confirm_hint_label.text = "决算谕告：今夕 21:00 准时决战，战果载入次日战报"
	else:
		confirm_title_label.text = "🛡️ 驻守此城确认"
		confirm_origin_label.text = "守备要塞：【%s】" % targ_name
		confirm_target_label.text = "驻防使命：守护据点 · 迎战来犯敌军（取前3名学生队伍御敌）"
		confirm_cost_label.text = "驻守开销：今日军令 1 道 · 固守我方疆土"
		confirm_hint_label.text = "驻防谕告：若本城无驻守令将回落固定守军，学子驻守可克敌制胜"

	confirm_pet_label.text = "出战灵宠：%s（士气高昂）" % pet_name
	order_confirm_overlay.visible = true

func _on_confirm_order_pressed() -> void:
	order_confirm_overlay.visible = false
	if city_drawer != null:
		_toggle_city_drawer(false)
	if confirm_action_type == "advance":
		_submit_advance_direct(confirm_origin_code, confirm_target_code)
	else:
		_submit_defend_direct(confirm_origin_code)

# ---------------------------------------------------------------------------
# S04 战争日报独立全屏页（头条、城池变化、分数、我的军令、全部军令、下候提示）
# ---------------------------------------------------------------------------

func _build_report_page() -> void:
	report_page = Control.new()
	report_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	report_page.visible = false
	pages["S04_REPORT"] = report_page
	report_dialog = report_page
	pages_container.add_child(report_page)

	var bg := ColorRect.new()
	bg.color = C_WOOD_DESK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	report_page.add_child(bg)

	var header := _create_page_header("📜 九州战争日报", "每日 21:00 诸军推演决战战报")
	report_page.add_child(header)

	report_margin = MarginContainer.new()
	report_margin.position = Vector2(16, 70)
	report_margin.size = Vector2(size.x - 32, size.y - 80)
	report_page.add_child(report_margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	report_margin.add_child(v)

	# 1. 顶部决战头条 Banner（C 宣纸纸卡 + 金边）
	report_headline_panel = PanelContainer.new()
	report_headline_panel.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, C_TENGHUANG, 2, 10, 12))
	v.add_child(report_headline_panel)

	var hl_v := VBoxContainer.new()
	hl_v.add_theme_constant_override("separation", 4)
	report_headline_panel.add_child(hl_v)

	var hl_row := HBoxContainer.new()
	hl_row.add_theme_constant_override("separation", 10)
	hl_v.add_child(hl_row)

	report_headline_lbl = _label("【决战头条】九州第一候推演决战备战中", 17, C_WOOD_DESK)
	report_headline_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl_row.add_child(report_headline_lbl)

	var view_replay_btn := _button("🔄 调取沙盘复盘", C_ZHUSHA, 34)
	view_replay_btn.custom_minimum_size = Vector2(140, 34)
	view_replay_btn.pressed.connect(_open_replay)
	hl_row.add_child(view_replay_btn)

	report_time_lbl = _label("推演时点：今夜 21:00 准时结算", 12, Color("#685848"))
	hl_v.add_child(report_time_lbl)

	# 2. 三大板块（支持滑动）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)

	var scroll_v := VBoxContainer.new()
	scroll_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_v.add_theme_constant_override("separation", 10)
	scroll.add_child(scroll_v)

	# 板块 1：我的出征演武与积分变动
	report_my_text = _build_report_card(scroll_v, "◆ 个人出征演武与学分变动")
	report_text = report_my_text

	# 板块 2：全域城池易帜与据点布防
	report_world_text = _build_report_card(scroll_v, "◆ 天下大势与关隘城池易帜")

	# 板块 3：诸军战况与下候军略备忘
	report_summary_text = _build_report_card(scroll_v, "◆ 诸军战功交锋与下候备忘")

func _build_report_card(parent: Control, card_title: String) -> RichTextLabel:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 150)
	p.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 10, 14))
	parent.add_child(p)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)

	var tl := _label(card_title, 15, C_ZHUSHA)
	v.add_child(tl)

	var sep := HSeparator.new()
	v.add_child(sep)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_font_size_override("normal_font_size", 13)
	rtl.add_theme_color_override("default_color", C_WOOD_DESK)
	v.add_child(rtl)
	return rtl

func _open_report() -> void:
	var last_rep: Variant = state.get("last_report", null)
	var target_turn_id := 0
	if typeof(last_rep) == TYPE_DICTIONARY:
		target_turn_id = int(last_rep.get("turn_id", 0))
	if target_turn_id <= 0:
		if str(state.get("turn", {}).get("status", "")) == "settled":
			target_turn_id = int(state.get("turn", {}).get("id", 0))

	if target_turn_id > 0:
		action_status.text = "正在展开第 %d 候战事日报..." % target_turn_id
		api.request("GET", "/api/slice/report?turn_id=%d" % target_turn_id, null, func(ok: bool, data: Dictionary, err: Dictionary):
			if not ok:
				_render_in_progress_report()
				_navigate_to("S04_REPORT")
				return
			_show_report(data)
			_navigate_to("S04_REPORT")
		)
	else:
		_render_in_progress_report()
		_navigate_to("S04_REPORT")

func _render_in_progress_report() -> void:
	var turn: Dictionary = state.get("turn", {})
	var turn_no := int(turn.get("turn_no", 1))
	var deadline := str(turn.get("deadline", "今日 21:00:00"))
	
	report_headline_lbl.text = "【第 %d 候战事筹备中】九州诸军沙盘集结待战，今夜 21:00 准时决算！" % turn_no
	report_time_lbl.text = "决算时点：%s（锁令前可随时调整军略）" % deadline

	# 1. 个人出征演武与学分变动
	var p_name := str(me.get("name", "青竹学子"))
	var pet_name := str(me.get("pet", {}).get("name", "青竹灵宠"))
	var my_ord: Variant = state.get("my_order", null)
	var my_b := "[b]出征学子：[/b]%s | [b]出战灵宠：[/b]%s（战力 120）\n" % [p_name, pet_name]
	if typeof(my_ord) == TYPE_DICTIONARY and not my_ord.is_empty():
		var act := str(my_ord.get("action", ""))
		var t_name := str(my_ord.get("target_name", ""))
		my_b += "[color=#b83b32]• 当前已签军令：向【%s】执行【%s】，已加盖行营帅印！[/color]\n" % [
			t_name, "挥师进军攻打" if act == "advance" else "坚壁固守城池"
		]
	else:
		my_b += "[color=#b83b32]• 当前军令状态：尚未签发军令！请前往【沙盘】轻触城池下达【进军】或【坚守】。[/color]\n"
	
	var cur_score := int(wallet.get("score", 0))
	var cur_wenyu := int(wallet.get("balance", 0))
	my_b += "• 学堂积分余额：%d 分 | 军备文玉：%d 枚（兑换比率 1:10，每日限额 20 文玉）\n" % [cur_score, cur_wenyu]
	my_b += "• 奖励规则：每日参与军令推演可获积分奖励，战报结算后自动结算入库。"
	report_my_text.text = my_b

	# 2. 天下大势与关隘城池布防现状
	var w_b := "[b]九州五大核心据点防御格局一览：[/b]\n"
	var nodes: Array = state.get("map", {}).get("nodes", [])
	if nodes.is_empty():
		nodes = state.get("nodes", [])
	for n in nodes:
		var c_name := str(n.get("name", ""))
		var is_start := bool(n.get("is_start", false))
		var owner: Variant = n.get("owner", null)
		var owner_name := "中立关塞"
		var f_color := "#5f5242"
		if typeof(owner) == TYPE_DICTIONARY:
			owner_name = str(owner.get("name", "中立")) + "阵营"
			var ocode := str(owner.get("code", ""))
			if ocode == "bi" or ocode == "bamboo":
				f_color = "#b83b32"
			elif ocode == "mo" or ocode == "ink":
				f_color = "#1e3a5f"
		w_b += "• [b]%s[/b]（%s）：归属 [color=%s]%s[/color] | 守备强度：3 点（固若金汤）\n" % [
			c_name, "起兵大营" if is_start else "要冲关隘", f_color, owner_name
		]
	report_world_text.text = w_b

	# 3. 诸军战功交锋与下候备忘
	var s_b := "[b]各大书院阵营集结动态：[/b]\n"
	var parts: Array = state.get("faction_participation", [])
	for f in parts:
		var f_info: Dictionary = f.get("faction", {})
		var f_name := str(f_info.get("name", "书院"))
		var conf := int(f.get("confirmed", 0))
		var tot := int(f.get("players", 0))
		s_b += "• %s：参战 %d 人 / 已交令 %d 人\n" % [f_name, tot, conf]
	s_b += "\n[color=#b83b32]◆ 下候推演备忘：[/color]\n"
	s_b += "• 每日 21:00 系统准时生成只读快照并触发结算，锁令后不可撤销；\n"
	s_b += "• 结算完成后自动生成详细战报与战局回放，请及时查阅战场复盘。"
	report_summary_text.text = s_b

func _show_report(data: Dictionary) -> void:
	var turn: Dictionary = data.get("turn", {})
	var rep: Dictionary = data.get("report", {})
	var summary: Dictionary = rep.get("summary", {})
	var changes: Array = rep.get("node_changes", [])
	var my_rep: Variant = data.get("me", data.get("my_report", null))
	var reports: Array = rep.get("reports", [])

	report_headline_lbl.text = str(rep.get("headline", "【决战头条】第 %d 候推演决战圆满告捷" % int(turn.get("turn_no", 1))))
	report_time_lbl.text = "推演决算时点：%s" % str(turn.get("settled_at", "—"))

	var b_my := ""
	if typeof(my_rep) == TYPE_DICTIONARY and not my_rep.is_empty():
		var desc := str(my_rep.get("readable_text", ""))
		if desc != "":
			b_my += desc + "\n\n"
		else:
			b_my += "出征行动：%s\n决胜战果：%s\n\n" % [str(my_rep.get("description", "")), str(my_rep.get("result_summary", ""))]
	else:
		b_my += "本候出征顺利，班宠灵力激荡，守备得力，立下军功！\n\n"
	
	var cur_score := int(wallet.get("score", 0))
	var cur_wenyu := int(wallet.get("balance", 0))
	b_my += "• 学堂积分余额：%d 分 | 军备文玉：%d 枚（兑换比率 1:10）\n" % [cur_score, cur_wenyu]
	b_my += "• 本候推演奖励已入库，积分与文玉已按学堂规则完成发放。"

	# Phase 1.5 战报折页逐队解释：回答“我的牌干了什么”
	var tactics_lines: Array[String] = []
	var teams_data: Array = []
	if typeof(my_rep) == TYPE_DICTIONARY and my_rep.has("teams"):
		var raw_teams: Variant = my_rep.get("teams", [])
		if typeof(raw_teams) == TYPE_ARRAY and not raw_teams.is_empty():
			teams_data = raw_teams

	if teams_data.is_empty():
		var card_orders_list: Array = state.get("card_orders", [])
		tactics_lines = _parse_tactics_lines_from_orders(card_orders_list)
	else:
		tactics_lines = _parse_tactics_lines_from_teams(teams_data)

	if not tactics_lines.is_empty():
		b_my += "\n\n[b][color=#fae19c]◆ 诸队战术实效清单：[/color][/b]\n"
		for line in tactics_lines:
			b_my += line + "\n"

	report_my_text.text = b_my

	var b_world := ""
	if changes.is_empty():
		b_world += "本候四野承平，各处关隘城防坚固，未有易帜失陷。\n"
	else:
		for c in changes:
			b_world += "• [b]%s[/b]：从 [color=#6f6252]%s[/color] 易为 [color=#b83b32]%s[/color]（原因：%s）\n" % [
				str(c.get("node_name", "")),
				str(c.get("prev_owner_name", "中立")),
				str(c.get("new_owner_name", "中立")),
				str(c.get("reason", "力战夺关")),
			]
	report_world_text.text = b_world

	var b_sum := "参战总灵宠：%d 只 | 进军总令：%d | 守备总令：%d\n\n" % [
		int(summary.get("total_orders", 0)),
		int(summary.get("advances", 0)),
		int(summary.get("defends", 0)),
	]
	for r in reports:
		b_sum += "• %s（%s）在 %s %s\n" % [
			str(r.get("student_name", "")),
			str(r.get("pet_name", "")),
			str(r.get("target_name", "")),
			str(r.get("result_summary", "")),
		]
	b_sum += "\n[color=#b83b32]◆ 下候备战提示：[/color]\n下一候军令已开启，请前往沙盘审视关防，谋划进军或坚守！"
	report_summary_text.text = b_sum

const TACTICAL_EFFECTS := {
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

const TACTICAL_NAMES := {
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

func _parse_tactics_lines_from_teams(teams: Array) -> Array[String]:
	var lines: Array[String] = []
	lines.append("⚔️【诸队战术与实效】")
	var type_names := {"cav": "骑", "shield": "盾", "arc": "弓", "spear": "枪"}
	for t in teams:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var raw_type := str(t.get("type", "cav"))
		var t_name := str(type_names.get(raw_type, raw_type))
		var lane_num := int(t.get("lane", 1))
		var row_val := str(t.get("row", "front"))
		var row_str := "后" if row_val == "back" or row_val == "后" else "前"
		var card_code := str(t.get("card", "") if t.get("card") != null else "")
		if card_code != "" and card_code != "null":
			var card_title := str(TACTICAL_NAMES.get(card_code, card_code))
			var effect_desc := str(TACTICAL_EFFECTS.get(card_code, "战术生效"))
			lines.append("• ⚡%s生效 · %s兵 · %d路%s · %s" % [card_title, t_name, lane_num, row_str, effect_desc])
		else:
			lines.append("• 常规突进 · %s兵 · %d路%s · (未佩战策)" % [t_name, lane_num, row_str])
	return lines

func _parse_tactics_lines_from_orders(orders: Array) -> Array[String]:
	var lines: Array[String] = []
	lines.append("⚔️【诸队战术与实效】")
	var comp_types: Array = state.get("composition", {}).get("types", ["cav", "shield", "arc"])
	var type_names := {"cav": "骑", "shield": "盾", "arc": "弓", "spear": "枪"}
	
	for slot in range(3):
		var u_type := "cav"
		if slot < comp_types.size():
			u_type = str(comp_types[slot])
		var t_name := str(type_names.get(u_type, u_type))
		var default_row := "后" if u_type == "arc" else "前"
		var lane := slot + 1
		
		var matching_order: Dictionary = {}
		for o in orders:
			if typeof(o) == TYPE_DICTIONARY and int(o.get("slot", -1)) == slot:
				matching_order = o
				break
		
		if not matching_order.is_empty():
			var c_code := str(matching_order.get("card_code", ""))
			var row_val := str(matching_order.get("row_pos", default_row))
			var row_str := "后" if row_val == "back" or row_val == "后" else "前"
			var c_name := str(TACTICAL_NAMES.get(c_code, c_code))
			var eff := str(TACTICAL_EFFECTS.get(c_code, "战术生效"))
			lines.append("• ⚡%s生效 · %s兵 · %d路%s · %s" % [c_name, t_name, lane, row_str, eff])
		else:
			lines.append("• 常规突进 · %s兵 · %d路%s · (未佩战策)" % [t_name, lane, default_row])
	return lines

# ---------------------------------------------------------------------------
# S05 战局回放独立全屏页（5 节点/路线/归属/变化高亮/战斗日志）
# ---------------------------------------------------------------------------

func _build_replay_page() -> void:
	replay_page = Control.new()
	replay_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	replay_page.visible = false
	pages["S05_REPLAY"] = replay_page
	replay_dialog = replay_page # 别名绑定，保证 ReplaySmoke 测试判定成立
	pages_container.add_child(replay_page)

	var bg := ColorRect.new()
	bg.color = C_WOOD_DESK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	replay_page.add_child(bg)

	var header := _create_page_header("🔄 九州沙盘推演复盘", "逐候复盘天下城池归属变迁")
	replay_page.add_child(header)

	replay_margin = MarginContainer.new()
	replay_margin.position = Vector2(16, 70)
	replay_margin.size = Vector2(size.x - 32, size.y - 80)
	replay_page.add_child(replay_margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	replay_margin.add_child(v)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)

	row.add_child(_label("回放回合：", 14, GOLD_LIGHT))
	replay_turn_select = OptionButton.new()
	replay_turn_select.custom_minimum_size = Vector2(160, 38)
	replay_turn_select.add_theme_stylebox_override("normal", _style(C_XUANZHI, Color("#c9baa7"), 1, 7, 8))
	replay_turn_select.add_theme_color_override("font_color", C_WOOD_DESK)
	replay_turn_select.item_selected.connect(_render_replay_turn)
	row.add_child(replay_turn_select)

	prev_turn_btn = _button("◀ 上一候", C_MOLAN, 38)
	prev_turn_btn.custom_minimum_size = Vector2(88, 38)
	prev_turn_btn.pressed.connect(_step_replay.bind(-1))
	row.add_child(prev_turn_btn)

	next_turn_btn = _button("下一候 ▶", C_MOLAN, 38)
	next_turn_btn.custom_minimum_size = Vector2(88, 38)
	next_turn_btn.pressed.connect(_step_replay.bind(1))
	row.add_child(next_turn_btn)

	replay_time_lbl = _label("推演时点：--", 12, Color("#d5c4a1"))
	replay_time_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(replay_time_lbl)

	replay_map = ReplayMapScript.new()
	replay_map.custom_minimum_size = Vector2(0, 360)
	replay_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(replay_map)

	var text_panel := PanelContainer.new()
	text_panel.custom_minimum_size = Vector2(0, 160)
	text_panel.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 10, 14))
	v.add_child(text_panel)

	replay_text = RichTextLabel.new()
	replay_text.bbcode_enabled = true
	replay_text.scroll_active = true
	replay_text.add_theme_font_size_override("normal_font_size", 13)
	replay_text.add_theme_color_override("default_color", C_WOOD_DESK)
	text_panel.add_child(replay_text)

func _open_replay() -> void:
	action_status.text = "正在调取沙盘推演记录..."
	api.request("GET", "/api/slice/replay", null, func(ok: bool, data: Dictionary, err: Dictionary):
		if not ok:
			_render_fallback_replay()
			_navigate_to("S05_REPLAY")
			return
		_show_replay(data)
	)

func _show_replay(data: Dictionary) -> void:
	replay_data = data
	var turns: Array = data.get("turns", [])
	var map_info: Dictionary = data.get("map", {})
	var nodes: Array = map_info.get("nodes", state.get("map", {}).get("nodes", []))
	var edges: Array = map_info.get("edges", state.get("map", {}).get("edges", []))
	if nodes.is_empty():
		nodes = state.get("nodes", [])

	if turns.is_empty():
		replay_turn_select.clear()
		replay_turn_select.add_item("第 1 候（战局备战中）")
		replay_turn_select.select(0)
		var owners := {}
		for n in nodes:
			owners[str(n.get("code", ""))] = n.get("owner", {})
		replay_map.setup(nodes, edges, owners, {})
		replay_time_lbl.text = "推演时点：今夜 21:00 准时结算"
		replay_text.text = "[font_size=16][color=#b83b32]◆ 第一候沙盘军情态势（备战中）[/color][/font_size]\n天下 5 大要害据点布防已毕，各大书院同门学子正在集结待命。\n[color=#685848]今夜 21:00 定时结算后，系统将自动生成城池易帜金色光环与战场动态对决复盘。[/color]"
		_navigate_to("S05_REPLAY")
		return

	replay_turn_select.clear()
	for i in range(turns.size()):
		var no := int(turns[i].get("turn_no", i + 1))
		var idx := replay_turn_select.item_count
		replay_turn_select.add_item("第 %d 候推演复盘" % no)
		replay_turn_select.set_item_metadata(idx, i)
	replay_turn_select.select(turns.size() - 1)
	_render_replay_turn(turns.size() - 1)
	_navigate_to("S05_REPLAY")

func _render_fallback_replay() -> void:
	var nodes: Array = state.get("map", {}).get("nodes", state.get("nodes", []))
	var edges: Array = state.get("map", {}).get("edges", [])
	var owners := {}
	for n in nodes:
		owners[str(n.get("code", ""))] = n.get("owner", {})
	replay_turn_select.clear()
	replay_turn_select.add_item("第 1 候（战局备战中）")
	replay_turn_select.select(0)
	replay_map.setup(nodes, edges, owners, {})
	replay_time_lbl.text = "推演时点：今夜 21:00 准时结算"
	replay_text.text = "[font_size=16][color=#b83b32]◆ 第一候沙盘军情态势（备战中）[/color][/font_size]\n天下 5 大要害据点布防已毕，各大书院同门学子正在集结待命。"

func _step_replay(delta: int) -> void:
	var total := replay_turn_select.item_count
	if total == 0:
		return
	var cur := replay_turn_select.selected
	var next_idx := clampi(cur + delta, 0, total - 1)
	if next_idx != cur:
		replay_turn_select.select(next_idx)
		_render_replay_turn(next_idx)

func _render_replay_turn(index: int) -> void:
	var turns: Array = replay_data.get("turns", [])
	if index < 0 or index >= turns.size():
		return
	var t: Dictionary = turns[index]
	var map_info: Dictionary = replay_data.get("map", {})
	var nodes: Array = map_info.get("nodes", state.get("map", {}).get("nodes", []))
	var edges: Array = map_info.get("edges", state.get("map", {}).get("edges", []))
	var raw_owners: Variant = t.get("owners", {})
	var owners: Dictionary = raw_owners if typeof(raw_owners) == TYPE_DICTIONARY else {}
	var changes: Array = t.get("changes", [])
	var changed_codes := {}
	for c in changes:
		changed_codes[str(c.get("node_code", ""))] = true

	replay_map.setup(nodes, edges, owners, changed_codes)
	replay_time_lbl.text = "推演时点：%s" % str(t.get("settled_at", "—"))

	var b := "[font_size=17][color=#b83b32]第 %d 候战况复盘[/color][/font_size]（决算时点：%s）\n" % [
		int(t.get("turn_no", 0)),
		str(t.get("settled_at", "—")),
	]
	if changes.is_empty():
		b += "本候全域防线坚如铁壁，各阵营据点无失陷易帜。\n"
	else:
		for c in changes:
			b += "• [b]%s[/b] 从 %s 归为 %s（%s）\n" % [
				str(c.get("node_name", "")),
				str(c.get("prev_owner_name", "中立")),
				str(c.get("new_owner_name", "中立")),
				str(c.get("reason", "力战夺城")),
			]
	replay_text.text = b

# ---------------------------------------------------------------------------
# S06 阵营势力独立全屏页（真实阵营数据、书院占领、势力格局）
# ---------------------------------------------------------------------------

func _build_faction_page() -> void:
	faction_page = Control.new()
	faction_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	faction_page.visible = false
	pages["S06_FACTION"] = faction_page
	pages_container.add_child(faction_page)

	var bg := ColorRect.new()
	bg.color = C_WOOD_DESK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	faction_page.add_child(bg)

	var header := _create_page_header("🚩 九州阵营大势", "四大书院山河争雄 · 笔墨纸砚势力格局")
	faction_page.add_child(header)

	faction_margin = MarginContainer.new()
	faction_margin.position = Vector2(16, 70)
	faction_margin.size = Vector2(size.x - 32, size.y - 80)
	faction_page.add_child(faction_margin)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	faction_margin.add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	scroll.add_child(v)

	# 1. 顶部本军概览卡（C 宣纸纸卡 + 朱砂金边）
	faction_summary_box = PanelContainer.new()
	faction_summary_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faction_summary_box.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, C_ZHUSHA, 2, 10, 14))
	v.add_child(faction_summary_box)

	var sum_v := VBoxContainer.new()
	sum_v.add_theme_constant_override("separation", 6)
	faction_summary_box.add_child(sum_v)

	faction_top_title = _label("🚩 本方阵营：笔阵营（青竹书院）", 18, C_ZHUSHA)
	sum_v.add_child(faction_top_title)

	faction_top_desc = _label("【阵营加成】驻守本方据点守备力额外 +1 | 参战同袍：集结中", 13, Color("#554433"))
	sum_v.add_child(faction_top_desc)

	# 2. 四大书院势力卡片网格
	faction_cards_container = GridContainer.new()
	faction_cards_container.columns = 2
	faction_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faction_cards_container.add_theme_constant_override("h_separation", 12)
	faction_cards_container.add_theme_constant_override("v_separation", 12)
	v.add_child(faction_cards_container)

	# 3. 待接入特性规划提示卡
	var roadmap_card := PanelContainer.new()
	roadmap_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roadmap_card.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, C_ZHUQING, 1, 8, 12))
	v.add_child(roadmap_card)

	var rm_v := VBoxContainer.new()
	rm_v.add_theme_constant_override("separation", 4)
	roadmap_card.add_child(rm_v)

	var rm_t := _label("📜 阵营文脉进阶特性（后续赛季规划）", 15, C_ZHUQING)
	rm_v.add_child(rm_t)

	var rm_d := _label("• 【同盟战功榜】：待下赛季接入，结算后根据阵营贡献发放额外文玉；\n• 【书院科技树】：待下赛季接入，研发【墨染山河】、【竹韵清风】等全阵营被动技。", 13, Color("#554433"))
	rm_v.add_child(rm_d)

	_refresh_faction_page()

func _refresh_faction_page() -> void:
	if faction_cards_container == null:
		return
	for c in faction_cards_container.get_children():
		c.queue_free()

	var f_data := [
		{
			"code": "bi",
			"alias": "bamboo",
			"name": "笔阵营 · 青竹书院（本方）",
			"slogan": "宁折不弯，文脉延绵",
			"color": C_ZHUSHA,
			"icon": "🖌️",
			"is_mine": true,
			"desc": "本方书院，学子英才辈出，擅长以守为攻、坚壁清野。"
		},
		{
			"code": "mo",
			"alias": "ink",
			"name": "墨阵营 · 玄墨书院（墨点精）",
			"slogan": "笔锋如剑，墨染九州",
			"color": C_MOLAN,
			"icon": "🖋️",
			"is_mine": false,
			"desc": "扼守塞外重镇，兵强马壮，主力与云麓关遥遥相对。"
		},
		{
			"code": "azure",
			"alias": "azure",
			"name": "沧浪书院（苍岚军）",
			"slogan": "沧浪之水，滔滔不绝",
			"color": Color("#274f73"),
			"icon": "🌊",
			"is_mine": false,
			"desc": "依傍水寨要冲，战船巡弋，随时准备渡江争夺中立关防。"
		},
		{
			"code": "neutral",
			"alias": "neutral",
			"name": "九州中立关塞（待破关）",
			"slogan": "天地不仁，山河以待",
			"color": NEUTRAL,
			"icon": "🏰",
			"is_mine": false,
			"desc": "松风渡、落霞原、听雨台等天下要塞，静待英豪合力夺取。"
		}
	]

	var nodes: Array = state.get("map", {}).get("nodes", [])
	if nodes.is_empty():
		nodes = state.get("nodes", [])
	var owned_map := {}
	for n in nodes:
		var owner: Variant = n.get("owner", null)
		if typeof(owner) == TYPE_DICTIONARY:
			var fcode := str(owner.get("code", ""))
			if not owned_map.has(fcode):
				owned_map[fcode] = []
			owned_map[fcode].append(str(n.get("name", "")))

	var part_map := {}
	for p in state.get("faction_participation", []):
		var finfo: Dictionary = p.get("faction", {})
		var fcode := str(finfo.get("code", ""))
		part_map[fcode] = {
			"confirmed": int(p.get("confirmed", 0)),
			"players": int(p.get("players", 0)),
		}

	for fd in f_data:
		var code: String = fd["code"]
		var alias: String = fd["alias"]
		var p_card := PanelContainer.new()
		p_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_card.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, fd["color"], 2, 10, 12))
		faction_cards_container.add_child(p_card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		p_card.add_child(cv)

		var h_head := HBoxContainer.new()
		h_head.add_theme_constant_override("separation", 8)
		cv.add_child(h_head)

		var icn := _label(str(fd["icon"]), 20, fd["color"])
		h_head.add_child(icn)

		var name_lbl := _label(str(fd["name"]), 16, C_WOOD_DESK)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_head.add_child(name_lbl)

		var tag := _label("【数据已接入】", 11, fd["color"])
		h_head.add_child(tag)

		var slog := _label("校训：%s" % str(fd["slogan"]), 12, fd["color"])
		cv.add_child(slog)

		var desc_lbl := _label(str(fd["desc"]), 12, Color("#685848"))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(desc_lbl)

		var sep := HSeparator.new()
		cv.add_child(sep)

		var my_nodes: Array = owned_map.get(code, [])
		if my_nodes.is_empty():
			my_nodes = owned_map.get(alias, [])
		var node_str := "、".join(my_nodes) if not my_nodes.is_empty() else "无据点（待破关夺取）"
		var nodes_lbl := _label("🏰 占领据点：%s" % node_str, 13, C_WOOD_DESK)
		cv.add_child(nodes_lbl)

		var p_info: Dictionary = part_map.get(code, part_map.get(alias, {"confirmed": 0, "players": 1}))
		var part_lbl := _label("👥 阵营兵力：已交令 %d 人 / 总参战 %d 人" % [
			p_info["confirmed"], max(p_info["players"], 1)
		], 12, Color("#554433"))
		cv.add_child(part_lbl)

# ---------------------------------------------------------------------------
# S02/S03/S07-S13 独立占位页面（入口齐全，统一纸雕色块）
# ---------------------------------------------------------------------------

func _build_all_placeholder_pages() -> void:
	_build_faction_page()

	_build_placeholder_page("S02_CITY_HUB", "🏯 主城行营", "学子营盘与城关建设", "🏯", "建设中", [
		{"title": "行营大帐", "desc": "校场演练、策定先锋军备，等级达到 5 级开放行军提速。"},
		{"title": "文墨工房", "desc": "开辟笔墨纸砚文房工坊，每日产出工坊积分与守城文玉。"},
		{"title": "粮饷辎重仓", "desc": "储备战备军粮，支撑大军远征要害关塞。"}
	])

	_build_army_composition_page()

	_build_placeholder_page("S07_GENERAL", "🐾 班宠将军", "学子灵宠身份、等级与法宝", "🐾", "出战中", [
		{"title": "出战灵宠：青竹灵猫", "desc": "等级：LV.5 | 四维：攻 35 / 防 40 / 敏 25 / 法 20。"},
		{"title": "灵宠天赋技能", "desc": "【坚守不拔】：驻守己方据点时守备力额外 +1。"},
		{"title": "灵宠饱食度与法宝", "desc": "饱食度 100/100，佩戴法宝【碧玉镇纸】，提升行军威仪。"}
	])

	_build_placeholder_page("S08_CODEX", "📜 文脉图鉴", "34 省文化地理典藏卷轴", "📜", "收录中", [
		{"title": "三秦文脉 · 关中塞上", "desc": "陕西诗卷典藏：终南阴岭秀，积雪浮云端。收录进度 80%。"},
		{"title": "齐鲁文脉 · 岱宗夫如何", "desc": "山东城关典藏：造化钟神秀，阴阳割昏晓。待争夺解锁。"},
		{"title": "江南文脉 · 忆江南", "desc": "江浙行宫图卷：日出江花红胜火，春来江水绿如蓝。"}
	])

	_build_placeholder_page("S09_SHOP", "🏮 文房榷场", "文玉换取外观与便利道具", "🏮", "营业中", [
		{"title": "【外观】青竹折扇战旗", "desc": "兑换价：10 文玉。出征时地图旌旗幻化为雅致文竹折扇。"},
		{"title": "【便利】神行千里灵符", "desc": "兑换价：5 文玉。急报传达提速，缩短行军流光用时。"},
		{"title": "【外观】古玉镇纸城池皮肤", "desc": "兑换价：20 文玉。将己方大本营外观升级为汉白玉飞檐楼阁。"}
	])

	_build_placeholder_page("S10_SEASON", "🏆 四候赛季", "四周加速赛季进度与丰厚犒赏", "🏆", "第 1 周", [
		{"title": "第一周 · 破关争雄", "desc": "目标：合力攻克 1 座中立关隘。奖励：全员获得文玉 20。"},
		{"title": "第二周 · 纵横开阖", "desc": "目标：连通两省关防驰道，触发文脉共鸣事件。"},
		{"title": "赛季终章 · 九州问鼎", "desc": "四周推演总战功最高阵营加冕【山河首座】，班宠外观永续珍藏。"}
	])

	_build_placeholder_page("S11_SETTINGS", "⚙️ 学堂备忘", "音效、网络与账号设置", "⚙️", "就绪", [
		{"title": "背景韶乐与音效", "desc": "古筝背景韶乐 [开启] | 战阵交互音效 [开启]。"},
		{"title": "测试与网络配置", "desc": "轻触右上角齿轮或在此处重新设定服务器 API 通信链路。"},
		{"title": "归隐退堂", "desc": "安全清除当前设备会话凭据，安全返回登录卷轴界面。"}
	])

	_build_placeholder_page("S12_MAIL", "✉️ 军府谕告", "班级通知、战役奖励与书简", "✉️", "2 封未读", [
		{"title": "【谕告】第一候关隘争霸已打响", "desc": "诸军请于今日 21:00 前完成军令盖印，逾期将依默认驻守。"},
		{"title": "【军饷】出征犒劳文玉到账", "desc": "恭贺学子踏入山河沙盘，学堂发放首征文玉 10 枚，请于仓库查收。"}
	])

	_build_placeholder_page("S13_TASKS", "🎯 每日军务", "每日三道治军修身悬赏", "🎯", "待交付", [
		{"title": "【军令】今日按时签发一道军令", "desc": "完成军令加盖印信。奖励：学堂积分 +2，班宠经验 +10。"},
		{"title": "【兵法】查阅上一候战争日报", "desc": "研读胜负得失，指导军阵调整。奖励：文玉 +1。"},
		{"title": "【修身】语文背诵任务打卡", "desc": "完成《短歌行》全文默写。奖励：出征士气增加 10 点。"}
	])

func _build_placeholder_page(page_id: String, title: String, subtitle: String, icon: String, badge: String, cards: Array) -> void:
	var p := Control.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	pages[page_id] = p
	pages_container.add_child(p)

	if page_id == "S10_SEASON" and ResourceLoader.exists("res://assets/art/keyart_c.png"):
		var keyart_tex: Texture2D = load("res://assets/art/keyart_c.png")
		var keyart_rect := TextureRect.new()
		keyart_rect.texture = keyart_tex
		keyart_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		keyart_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		keyart_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.add_child(keyart_rect)

		var scrim := ColorRect.new()
		scrim.color = Color(0.12, 0.09, 0.07, 0.65)
		scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.add_child(scrim)
	else:
		var bg := ColorRect.new()
		bg.color = C_WOOD_DESK.darkened(0.2)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.add_child(bg)

	var header := _create_page_header(title, subtitle)
	p.add_child(header)

	var margin := MarginContainer.new()
	margin.position = Vector2(16, 70)
	margin.size = Vector2(size.x - 32, size.y - 80)
	p.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	scroll.add_child(v)

	var summary_card := PanelContainer.new()
	summary_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_card.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, C_TENGHUANG, 2, 10, 14))
	var s_row := HBoxContainer.new()
	s_row.add_theme_constant_override("separation", 16)
	summary_card.add_child(s_row)

	var icn_lbl := _label(icon, 30, C_TENGHUANG)
	s_row.add_child(icn_lbl)

	var text_v := VBoxContainer.new()
	text_v.add_theme_constant_override("separation", 4)
	text_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s_row.add_child(text_v)

	var title_lbl := _label(title, 17, C_WOOD_DESK)
	text_v.add_child(title_lbl)

	var badge_lbl := _label("【状态】" + badge + " · 待下赛季版本接入", 12, Color("#685848"))
	text_v.add_child(badge_lbl)
	v.add_child(summary_card)

	var grid := GridContainer.new()
	grid.columns = 1 if size.x < 900.0 else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)

	for c in cards:
		var c_panel := PanelContainer.new()
		c_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_panel.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 8, 12))
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		c_panel.add_child(cv)

		var h_head := HBoxContainer.new()
		h_head.add_theme_constant_override("separation", 8)
		cv.add_child(h_head)

		var ct := _label(str(c.get("title", "")), 15, C_WOOD_DESK)
		ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_head.add_child(ct)

		var c_tag := _label("【待接入】", 11, C_ZHUQING)
		h_head.add_child(c_tag)

		var cs := _label(str(c.get("desc", "")), 13, Color("#554433"))
		cs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(cs)
		grid.add_child(c_panel)

# ---------------------------------------------------------------------------
# Phase 1: S03 每周军团编成页面
# ---------------------------------------------------------------------------

func _build_army_composition_page() -> void:
	var army_page := Control.new()
	army_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	army_page.visible = false
	pages["S03_ARMY"] = army_page
	pages_container.add_child(army_page)

	var bg := ColorRect.new()
	bg.color = C_WOOD_DESK.darkened(0.15)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	army_page.add_child(bg)

	var header := _create_page_header("⚔️ 每周军团编成", "4 兵种三队战阵 · 兵源城加成 · 周中可改 1 次")
	army_page.add_child(header)

	army_margin = MarginContainer.new()
	army_margin.position = Vector2(16, 70)
	army_margin.size = Vector2(size.x - 32, size.y - 80)
	army_margin.name = "ArmyMargin"
	army_page.add_child(army_margin)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	army_margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	composition_panel = CompositionPanelScript.new()
	composition_panel.name = "CompositionPanel"
	composition_panel.composition_confirmed.connect(_on_composition_confirmed)
	vbox.add_child(composition_panel)

	# 兵种克制与兵源加成说明卡
	var lore_box := PanelContainer.new()
	lore_box.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#c9a227"), 1, 8, 12))
	vbox.add_child(lore_box)
	
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	lore_box.add_child(lv)

	var lt := Label.new()
	lt.text = "📜 九州兵种克制与兵源城法则"
	lt.add_theme_color_override("font_color", Color("#231c17"))
	lt.add_theme_font_size_override("font_size", 14)
	lv.add_child(lt)

	var ld := Label.new()
	ld.text = "• 克制循环：骑兵 ➔ 盾兵 ➔ 弓兵 ➔ 枪兵 ➔ 骑兵 (强克伤害 x1.2，被克伤害 x0.85)。\n• 队伍布阵：前排近战(骑/盾/枪)，后排弓兵或替补近战；攻方阵后自动配备攻城重械。\n• 兵源重镇：掌控凉州/太原/邺城(骑+15%)、汉中/襄阳/成都(盾+15%)、江陵/会稽/建业(弓+15%)、洛阳/长沙/寿春(枪+15%)、长安(器械攻墙+50%)。"
	ld.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ld.add_theme_color_override("font_color", Color("#4a3e35"))
	ld.add_theme_font_size_override("font_size", 11)
	lv.add_child(ld)

# ---------------------------------------------------------------------------
# Phase 1: 每日战术手牌系统 (Daily Tactical Cards)
# ---------------------------------------------------------------------------

const ALL_TACTICAL_CARDS := [
	{"code": "night_raid", "aliases": [], "name": "夜袭", "type": "advance", "icon": "🌙", "short_desc": "未侦察伤害+20%", "full_desc": "【朱·夜袭】：若目标城池当晚未被敌方侦察识破，进军伤害额外提升20%。"},
	{"code": "forced_march", "aliases": ["rapid_march"], "name": "急行", "type": "advance", "icon": "🐎", "short_desc": "先手突袭 无视断连", "full_desc": "【朱·急行】：首轮先制动势，跳过断连惩罚，直击要塞。"},
	{"code": "fire_attack", "aliases": [], "name": "火攻", "type": "advance", "icon": "🔥", "short_desc": "器械攻墙伤害+50%", "full_desc": "【朱·火攻】：火烧连营摧坚壁，大幅强化阵后器械对城墙的破坏力(+50%)。"},
	{"code": "fortify", "aliases": ["solid_defense"], "name": "坚壁", "type": "defend", "icon": "🛡️", "short_desc": "本队防御韧性+20%", "full_desc": "【墨·坚壁】：固若金汤，全队护甲提升20%，次日手牌3选2。"},
	{"code": "mutual_support", "aliases": ["flank_support"], "name": "犄角", "type": "defend", "icon": "🤝", "short_desc": "相邻城池防守+10%", "full_desc": "【墨·犄角】：互为倚仗，相辅相成，若相邻有己方城池则防御共振提升10%。"},
	{"code": "empty_fort", "aliases": [], "name": "空城", "type": "defend", "icon": "🪈", "short_desc": "敌军攻势削弱10%", "full_desc": "【墨·空城】：大开城门，虚实莫测，来犯敌军攻击点数削减10%。"},
	{"code": "last_stand", "aliases": ["hold_ground"], "name": "死守", "type": "defend", "icon": "⚔️", "short_desc": "本队免疫一次破城", "full_desc": "【墨·死守】：誓死不退，关键时刻免疫一次城防易主，每赛季限1次。"},
	{"code": "scout", "aliases": ["scout_probe"], "name": "哨探", "type": "scout", "icon": "👁️", "short_desc": "开战前勘测敌方一路", "full_desc": "【青·哨探】：深入关隘，侦悉目标敌军上一候驻守区间与1路兵力。"},
	{"code": "counter_intel", "aliases": ["alienation"], "name": "反间", "type": "scout", "icon": "📜", "short_desc": "刺探动向 敌攻-10%", "full_desc": "【青·反间】：离间军心，查探本回合敌方下令阵营，并削弱其10%攻势。"},
	{"code": "feint", "aliases": ["decoy_troops"], "name": "疑兵", "type": "scout", "icon": "🚩", "short_desc": "制造虚假驻守假象", "full_desc": "【青·疑兵】：故布疑阵，令敌军侦察时虚增3人防守假象。"},
	{"code": "supply", "aliases": ["grain_transport"], "name": "运粮", "type": "supply", "icon": "🌾", "short_desc": "每15候回复5%兵力", "full_desc": "【黄·运粮】：粮草充盈，持久续航，对战中每15候恢复全队5%兵力。"},
	{"code": "cut_supply", "aliases": ["cut_supplies"], "name": "断粮", "type": "supply", "icon": "⛓️", "short_desc": "敌军每15候损失3%", "full_desc": "【黄·断粮】：阻截辎重通道，令守方补给瘫痪并持续流失兵力。"}
]

func _get_tactical_card_meta(code: String) -> Dictionary:
	var c := code.to_lower().strip_edges()
	for t in ALL_TACTICAL_CARDS:
		if str(t.get("code", "")).to_lower() == c:
			var res = t.duplicate(true)
			res["code"] = code
			return res
		for a in t.get("aliases", []):
			if str(a).to_lower() == c:
				var res = t.duplicate(true)
				res["code"] = code
				return res
	return {
		"code": code,
		"name": code,
		"type": "advance",
		"icon": "📜",
		"short_desc": "将令秘策",
		"full_desc": "【九州将令·%s】" % code
	}

func _sync_hand_and_orders(data: Dictionary) -> void:
	var hand_val: Variant = data.get("hand", {})
	var hand_info: Dictionary = hand_val if typeof(hand_val) == TYPE_DICTIONARY else {}
	var cards_val: Variant = hand_info.get("cards", [])
	var cards: Array = cards_val if typeof(cards_val) == TYPE_ARRAY else []
	hand_redraw_used = bool(hand_info.get("redraw_used", false))

	if hand_redraw_btn:
		hand_redraw_btn.disabled = hand_redraw_used
		hand_redraw_btn.text = "已重抽(0/1)" if hand_redraw_used else "🔄 重抽(1/1)"
		hand_redraw_btn.add_theme_color_override("font_color", Color("#7e7263") if hand_redraw_used else Color("#ffffff"))

	var card_orders_val: Variant = data.get("card_orders", [])
	var card_orders: Array = card_orders_val if typeof(card_orders_val) == TYPE_ARRAY else []
	var orders_by_card: Dictionary = {}
	for ord in card_orders:
		if typeof(ord) == TYPE_DICTIONARY:
			orders_by_card[str(ord.get("card_code", ""))] = ord

	if not cards.is_empty():
		hand_cards_data.clear()
		var is_full_slots := (card_orders.size() >= 3)
		for code in cards:
			var c_str := str(code)
			var cmeta := _get_tactical_card_meta(c_str)
			if orders_by_card.has(c_str):
				cmeta["is_played"] = true
				cmeta["order"] = orders_by_card[c_str]
				cmeta["assigned_team"] = int(orders_by_card[c_str].get("slot", 0))
				cmeta["is_discarded"] = false
			else:
				cmeta["is_played"] = false
				cmeta["order"] = {}
				cmeta["assigned_team"] = -1
				cmeta["is_discarded"] = is_full_slots
			hand_cards_data.append(cmeta)
		_render_hand_cards()

	# 同步当前打开城池的哨探情报入口
	if is_drawer_open and selected_code != "" and city_action_scout_btn != null:
		var has_scout_on_cur := false
		for ord in card_orders:
			if typeof(ord) == TYPE_DICTIONARY:
				if str(ord.get("card_code", "")) == "scout" and str(ord.get("target_node_code", "")) == selected_code:
					has_scout_on_cur = true
					break
		city_action_scout_btn.visible = has_scout_on_cur
		if not has_scout_on_cur and city_intel_dialog != null and city_intel_dialog.visible:
			city_intel_dialog.hide()

func _init_hand_cards_data() -> void:
	hand_cards_data.clear()
	for i in range(min(4, ALL_TACTICAL_CARDS.size())):
		var card = ALL_TACTICAL_CARDS[i].duplicate(true)
		card["assigned_team"] = i if i < 3 else -1
		card["is_played"] = false
		card["is_discarded"] = false
		card["order"] = {}
		hand_cards_data.append(card)

func _build_hand_cards_bar() -> void:
	hand_cards_bar = PanelContainer.new()
	hand_cards_bar.name = "HandCardsBar"
	hand_cards_bar.add_theme_stylebox_override("panel", _style(Color(0.12, 0.09, 0.07, 0.94), C_BORDER_GOLD, 1, 8, 4))
	map_shell.add_child(hand_cards_bar)
	
	var root_vb := VBoxContainer.new()
	root_vb.name = "RootVBox"
	root_vb.add_theme_constant_override("separation", 3)
	hand_cards_bar.add_child(root_vb)

	var top_hb := HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 8)
	root_vb.add_child(top_hb)

	var tag_lbl := Label.new()
	tag_lbl.text = "🎴 每日将令手牌"
	tag_lbl.add_theme_color_override("font_color", Color("#fae19c"))
	tag_lbl.add_theme_font_size_override("font_size", 11)
	top_hb.add_child(tag_lbl)

	var sub_tip := Label.new()
	sub_tip.text = "点击卡牌出令/撤回 · 悬停长按看说明"
	sub_tip.add_theme_color_override("font_color", Color("#b5a489"))
	sub_tip.add_theme_font_size_override("font_size", 10)
	top_hb.add_child(sub_tip)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hb.add_child(sp)

	hand_redraw_btn = Button.new()
	hand_redraw_btn.text = "🔄 重抽(1/1)"
	hand_redraw_btn.custom_minimum_size = Vector2(74, 22)
	hand_redraw_btn.add_theme_font_size_override("font_size", 10)
	hand_redraw_btn.add_theme_color_override("font_color", Color("#ffffff"))
	hand_redraw_btn.add_theme_stylebox_override("normal", _style(C_ZHUSHA.darkened(0.2), C_BORDER_GOLD, 1, 4, 2))
	hand_redraw_btn.pressed.connect(_on_hand_redraw_pressed)
	top_hb.add_child(hand_redraw_btn)

	hand_collapse_btn = Button.new()
	hand_collapse_btn.text = "▼ 折叠"
	hand_collapse_btn.custom_minimum_size = Vector2(46, 22)
	hand_collapse_btn.add_theme_font_size_override("font_size", 10)
	hand_collapse_btn.pressed.connect(_toggle_hand_bar_collapse)
	top_hb.add_child(hand_collapse_btn)

	hand_cards_container = HBoxContainer.new()
	hand_cards_container.name = "CardsRow"
	hand_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_cards_container.add_theme_constant_override("separation", 6)
	root_vb.add_child(hand_cards_container)

	_init_hand_cards_data()
	_render_hand_cards()

func _render_hand_cards() -> void:
	if not hand_cards_container:
		return
	for c in hand_cards_container.get_children():
		c.queue_free()
	hand_card_views.clear()

	for i in range(hand_cards_data.size()):
		var cdata: Dictionary = hand_cards_data[i]
		var card := _create_single_hand_card(i, cdata)
		hand_cards_container.add_child(card)
		hand_card_views.append(card)

func _create_single_hand_card(idx: int, cdata: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 72)
	
	var c_type := str(cdata.get("type", "advance"))
	var c_code := str(cdata.get("code", ""))
	var is_played := bool(cdata.get("is_played", false))
	var is_discarded := bool(cdata.get("is_discarded", false))
	
	# 四态去色高反差视觉设计（明亮宣纸 [可出]、暗金古铜 [已出]、幽暗纯黑 [弃用]）
	var patch_path := "res://assets/art/ui/card_frame_ninepatch.png"
	if ResourceLoader.exists(patch_path):
		var nine_sb := StyleBoxTexture.new()
		nine_sb.texture = load(patch_path)
		nine_sb.texture_margin_left = 28
		nine_sb.texture_margin_top = 28
		nine_sb.texture_margin_right = 28
		nine_sb.texture_margin_bottom = 28
		nine_sb.set_content_margin_all(5)
		if is_played:
			nine_sb.modulate_color = Color("#756858") # 已出：暗金古铜
		elif is_discarded:
			nine_sb.modulate_color = Color("#382e27") # 弃用：幽暗纯黑
		else:
			nine_sb.modulate_color = Color("#fffef6") # 可出：明亮温润宣纸
		card.add_theme_stylebox_override("panel", nine_sb)
	else:
		if is_played:
			card.add_theme_stylebox_override("panel", _style(Color("#3a2f22"), Color("#dfb557"), 2, 6, 4))
		elif is_discarded:
			card.add_theme_stylebox_override("panel", _style(Color("#14100e"), Color("#352c26"), 1, 6, 4))
		else:
			card.add_theme_stylebox_override("panel", _style(Color("#fffef6"), Color("#c4a77d"), 1, 6, 4))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	card.add_child(vb)

	# 顶部标题栏（卡名 + 状态徽标 + 战术图标）
	var h_title := HBoxContainer.new()
	h_title.add_theme_constant_override("separation", 3)
	vb.add_child(h_title)

	# 12 张战术图标
	var tac_path := "res://assets/art/tactics/tactics_%s.png" % c_code
	if ResourceLoader.exists(tac_path):
		var tac_icon := TextureRect.new()
		tac_icon.texture = load(tac_path)
		tac_icon.custom_minimum_size = Vector2(16, 16)
		tac_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tac_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h_title.add_child(tac_icon)

	var name_l := Label.new()
	var fallback_prefix := "" if ResourceLoader.exists(tac_path) else str(cdata.get("icon", "")) + " "
	name_l.text = "%s%s" % [fallback_prefix, cdata.get("name", "")]
	if is_played:
		name_l.add_theme_color_override("font_color", Color("#ffd700"))
	elif is_discarded:
		name_l.add_theme_color_override("font_color", Color("#756658"))
	else:
		name_l.add_theme_color_override("font_color", Color("#1e1712"))
	name_l.add_theme_font_size_override("font_size", 12)
	h_title.add_child(name_l)

	var state_badge := Label.new()
	if is_played:
		state_badge.text = "[已出]"
		state_badge.add_theme_color_override("font_color", Color("#73c991"))
	elif is_discarded:
		state_badge.text = "[弃用]"
		state_badge.add_theme_color_override("font_color", Color("#b84c3d"))
	else:
		state_badge.text = "[可出]"
		state_badge.add_theme_color_override("font_color", Color("#276f57"))
	state_badge.add_theme_font_size_override("font_size", 12)
	h_title.add_child(state_badge)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_title.add_child(sp)

	var info_btn := Button.new()
	info_btn.text = "ℹ"
	info_btn.flat = true
	info_btn.custom_minimum_size = Vector2(18, 16)
	info_btn.add_theme_font_size_override("font_size", 12)
	info_btn.pressed.connect(func(): _show_card_tooltip(cdata, card.global_position))
	h_title.add_child(info_btn)

	# 中部去向 / 战术简效（字号统一 >=12px）
	var desc_l := Label.new()
	desc_l.add_theme_font_size_override("font_size", 12)
	if is_played:
		var order: Dictionary = cdata.get("order", {})
		var tgt: String = str(order.get("target_node_code", ""))
		var tgt_name: String = str(map.node_by_code(tgt).get("name", tgt))
		var lane_val: int = int(order.get("lane", int(order.get("slot", 0)) + 1))
		var row_pos := str(order.get("row_pos", "front"))
		var row_str := "后" if row_pos == "back" or row_pos == "后" else "前"
		var card_c := str(cdata.get("code", ""))
		if card_c == "fire_attack" or card_c == "scout" or card_c == "feint":
			desc_l.text = "%s·特策" % tgt_name
		else:
			desc_l.text = "%s·%d路%s" % [tgt_name, lane_val, row_str]
		desc_l.add_theme_color_override("font_color", Color("#ffd700"))
	elif is_discarded:
		desc_l.text = "今日不用"
		desc_l.add_theme_color_override("font_color", Color("#63564c"))
	else:
		desc_l.text = str(cdata.get("short_desc", "战策就绪"))
		desc_l.add_theme_color_override("font_color", Color("#42352a"))
	vb.add_child(desc_l)

	# 底部主要操作按钮（字号统一 >=12px，高度 26px）
	var assign_btn := Button.new()
	assign_btn.custom_minimum_size = Vector2(0, 26)
	assign_btn.add_theme_font_size_override("font_size", 12)
	
	if is_played:
		assign_btn.text = "↩️ 撤回"
		assign_btn.add_theme_color_override("font_color", Color("#fae19c"))
		assign_btn.add_theme_stylebox_override("normal", _style(Color("#3f3328"), Color("#dfb557"), 1, 4, 2))
		assign_btn.tooltip_text = "点击撤回该槽位军令，重新谋划出征"
		assign_btn.disabled = false
	elif is_discarded:
		assign_btn.text = "今日不用"
		assign_btn.add_theme_color_override("font_color", Color("#6e5d50"))
		assign_btn.add_theme_stylebox_override("disabled", _style(Color("#181412"), Color("#352c26"), 1, 4, 2))
		assign_btn.tooltip_text = "今日 3 道将令槽位已满，此牌今日不用。撤回任一已出牌后可恢复使用！"
		assign_btn.disabled = true
	else:
		if selected_code != "":
			var tgt_name: String = str(map.node_by_code(selected_code).get("name", selected_code))
			assign_btn.text = "出令➔%s" % tgt_name
			assign_btn.add_theme_color_override("font_color", Color("#fae19c"))
			assign_btn.add_theme_stylebox_override("normal", _style(Color("#38271d"), C_BORDER_GOLD, 1, 4, 2))
			assign_btn.tooltip_text = "点击下达将令向【%s】出征" % tgt_name
		else:
			assign_btn.text = "点城出令"
			assign_btn.add_theme_color_override("font_color", Color("#a89684"))
			assign_btn.add_theme_stylebox_override("normal", _style(Color("#2b211a"), Color("#5a4838"), 1, 4, 2))
			assign_btn.tooltip_text = "请先在地图上点击选择目标据点，再点击出令"
		assign_btn.disabled = false

	assign_btn.pressed.connect(func(): _on_hand_card_clicked(idx))
	vb.add_child(assign_btn)

	card.mouse_entered.connect(func(): _show_card_tooltip(cdata, card.global_position))
	card.mouse_exited.connect(_hide_card_tooltip)

	return card

func _on_hand_card_clicked(idx: int) -> void:
	if idx < 0 or idx >= hand_cards_data.size():
		return
	var cdata: Dictionary = hand_cards_data[idx]
	var c_code: String = str(cdata.get("code", ""))
	var is_played: bool = bool(cdata.get("is_played", false))
	var is_discarded: bool = bool(cdata.get("is_discarded", false))
	var order: Dictionary = cdata.get("order", {})

	if is_played:
		var slot_to_withdraw: int = int(order.get("slot", 0))
		_withdraw_card_order(slot_to_withdraw)
		return

	if is_discarded:
		_toast("今日 3 道将令槽位已满，此牌为今日弃牌。请先撤回已出的手牌！", true)
		return

	var target_code := selected_code
	if target_code == "":
		_toast("请先在地图上点击选择目标据点，再点击手牌出令！", true)
		return

	# 找到尚未占用的槽位 (0, 1, 2)
	var used_slots: Array = []
	for o in state.get("card_orders", []):
		if typeof(o) == TYPE_DICTIONARY:
			used_slots.append(int(o.get("slot", 0)))
	var chosen_slot := -1
	for s in range(3):
		if not used_slots.has(s):
			chosen_slot = s
			break
	if chosen_slot == -1:
		_toast("今日 3 道将令槽位已满，可点击已出的手牌撤回！", true)
		return

	_play_card_order(chosen_slot, c_code, target_code)

func _play_card_order(slot: int, card_code: String, target_code: String) -> void:
	var comp_types: Array = state.get("composition", {}).get("types", ["cav", "shield", "arc"])
	var unit_type := "cav"
	if slot >= 0 and slot < comp_types.size():
		unit_type = str(comp_types[slot])
	var row_pos := "back" if unit_type == "arc" else "front"
	var lane := slot + 1
	var req_key := _new_key("p1_t%d_s%d" % [_turn_id(), slot])

	action_status.text = "将令传达中..."
	api.play_card_order(_turn_id(), slot, card_code, target_code, lane, row_pos, req_key, func(ok: bool, _data: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		var card_name := str(_get_tactical_card_meta(card_code).get("name", card_code))
		var target_name := str(map.node_by_code(target_code).get("name", target_code))
		_toast("【%s】将令已加盖帅印，下达至【%s】(队%d)！" % [card_name, target_name, lane])
		_refresh_state()
	)

func _withdraw_card_order(slot: int) -> void:
	action_status.text = "撤销将令中..."
	api.withdraw_card_order(_turn_id(), slot, func(ok: bool, _data: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		_toast("第 %d 队将令已成功撤回！" % (slot + 1))
		_refresh_state()
	)

func _on_hand_redraw_pressed() -> void:
	if hand_redraw_used:
		_toast("今日重抽机会已用尽！", true)
		return
	action_status.text = "请求重新抽取手牌..."
	api.redraw_hand(_turn_id(), func(ok: bool, _data: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		_toast("已消耗重抽机会，生成全新将令手牌！")
		_refresh_state()
	)

func _on_composition_confirmed(types: Array) -> void:
	action_status.text = "提交军团编成中..."
	api.set_composition(1, types, func(ok: bool, data: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		_toast("军团编成已成功确认保存！")
		if composition_panel:
			composition_panel.set_composition_state(data.get("types", types), bool(data.get("changed_once", false)))
		_refresh_state()
	)

func _start_demo_battle(node_code: String = "", fire: bool = true, callback: Callable = Callable()) -> void:
	if node_code == "":
		node_code = selected_code if selected_code != "" else "N2"
	action_status.text = "发起推演对决中..."
	api.demo_battle(_turn_id(), node_code, fire, func(ok: bool, data: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			if callback.is_valid():
				callback.call(false, {})
			return
		var b_id := int(data.get("battle_id", 0))
		var log: Dictionary = data.get("log", {})
		log["node_code"] = node_code
		current_battle_id = b_id
		
		# 打开回放浮层并启动确定性播放
		battle_replay_overlay.visible = true
		battle_replay_instance.play_data(log)
		_toast("⚔️ 演武决战推演开始！")
		if callback.is_valid():
			callback.call(true, data)
	)

func _on_battle_replay_finished(_result: Dictionary) -> void:
	if current_battle_id > 0:
		var b_id := current_battle_id
		current_battle_id = 0
		api.settle_battle(b_id, func(ok: bool, data: Dictionary, err: Dictionary):
			if not ok:
				push_warning("结算战斗失败: " + str(err))
				return
			var captured := bool(data.get("captured", false))
			var node := str(data.get("node_code", ""))
			var m_after := int(data.get("morale_after", 0))
			var cap := int(data.get("cap", 2))
			if captured:
				_toast("🎉 破城易主！【%s】据点已成功攻克易帜！" % str(map.node_by_code(node).get("name", node)))
			else:
				_toast("⚔️ 演武结算：【%s】民心推进至 %d/%d 格！" % [str(map.node_by_code(node).get("name", node)), m_after, cap])
			_refresh_state()
		)

# ---------------------------------------------------------------------------
# Phase 1 快捷脚本与测试接口 (Public Automation API)
# ---------------------------------------------------------------------------

func play_card(slot: int, card_code: String, target_node_code: String = "N2", lane: int = -1, row_pos: String = "") -> void:
	if lane <= 0:
		lane = slot + 1
	if row_pos == "":
		var comp_types: Array = state.get("composition", {}).get("types", ["cav", "shield", "arc"])
		var u_type := "cav"
		if slot >= 0 and slot < comp_types.size():
			u_type = str(comp_types[slot])
		row_pos = "back" if u_type == "arc" else "front"
	var req_key := _new_key("p1_t%d_s%d" % [_turn_id(), slot])
	api.play_card_order(_turn_id(), slot, card_code, target_node_code, lane, row_pos, req_key, func(ok: bool, _data: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
		else:
			_refresh_state()
	)

func withdraw_card(slot: int) -> void:
	_withdraw_card_order(slot)

func redraw_hand_cards() -> void:
	_on_hand_redraw_pressed()

func set_army_composition(types: Array) -> void:
	_on_composition_confirmed(types)

func start_demo_battle(node_code: String = "N2", fire: bool = true, callback: Callable = Callable()) -> void:
	_start_demo_battle(node_code, fire, callback)

func settle_demo_battle(battle_id: int = 0, callback: Callable = Callable()) -> void:
	var b_id := battle_id if battle_id > 0 else current_battle_id
	if b_id <= 0:
		return
	api.settle_battle(b_id, func(ok: bool, data: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			if callback.is_valid():
				callback.call(false, {})
		else:
			_refresh_state()
			if callback.is_valid():
				callback.call(true, data)
	)

func _toggle_hand_bar_collapse() -> void:
	hand_bar_collapsed = not hand_bar_collapsed
	if hand_cards_container:
		hand_cards_container.visible = not hand_bar_collapsed
	hand_collapse_btn.text = "▲ 展开" if hand_bar_collapsed else "▼ 折叠"
	_layout_responsive()

func _build_card_tooltip() -> void:
	card_tooltip_panel = PanelContainer.new()
	card_tooltip_panel.name = "CardTooltipPanel"
	card_tooltip_panel.visible = false
	card_tooltip_panel.custom_minimum_size = Vector2(240, 80)
	card_tooltip_panel.add_theme_stylebox_override("panel", _style(Color(0.12, 0.09, 0.07, 0.96), C_BORDER_GOLD, 2, 8, 8))
	map_shell.add_child(card_tooltip_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card_tooltip_panel.add_child(v)

	card_tooltip_title = Label.new()
	card_tooltip_title.add_theme_color_override("font_color", Color("#fae19c"))
	card_tooltip_title.add_theme_font_size_override("font_size", 12)
	v.add_child(card_tooltip_title)

	card_tooltip_desc = Label.new()
	card_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_tooltip_desc.add_theme_color_override("font_color", Color("#d5c4a1"))
	card_tooltip_desc.add_theme_font_size_override("font_size", 11)
	v.add_child(card_tooltip_desc)

func _show_card_tooltip(cdata: Dictionary, pos: Vector2) -> void:
	if not card_tooltip_panel:
		return
	card_tooltip_title.text = "%s %s 将令说明" % [cdata.get("icon", ""), cdata.get("name", "")]
	card_tooltip_desc.text = str(cdata.get("full_desc", ""))
	var tooltip_w := 240.0
	var tooltip_h := 80.0
	var px := clampf(pos.x, 10.0, size.x - tooltip_w - 10.0)
	var py := maxf(pos.y - tooltip_h - 10.0, 60.0)
	card_tooltip_panel.position = Vector2(px, py)
	card_tooltip_panel.size = Vector2(tooltip_w, tooltip_h)
	card_tooltip_panel.visible = true

func _hide_card_tooltip() -> void:
	if card_tooltip_panel:
		card_tooltip_panel.visible = false

func _build_battle_replay_overlay() -> void:
	battle_replay_overlay = Control.new()
	battle_replay_overlay.name = "BattleReplayOverlay"
	battle_replay_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_replay_overlay.z_index = 25
	battle_replay_overlay.visible = false
	game_layer.add_child(battle_replay_overlay)

	battle_replay_instance = BattleReplayScene.instantiate()
	battle_replay_instance.name = "BattleReplayInstance"
	battle_replay_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_replay_instance.closed.connect(func(): battle_replay_overlay.visible = false)
	battle_replay_instance.replay_finished.connect(_on_battle_replay_finished)
	battle_replay_overlay.add_child(battle_replay_instance)

func _open_battle_replay_demo() -> void:
	if battle_replay_overlay and battle_replay_instance:
		battle_replay_overlay.visible = true
		battle_replay_overlay.move_to_front()
		battle_replay_instance.load_sample_data()

# ---------------------------------------------------------------------------
# 师长督军后台控制（权限隔离）
# ---------------------------------------------------------------------------

func _build_teacher_deck() -> void:
	teacher_box = Panel.new()
	teacher_box.position = Vector2(980, 84)
	teacher_box.size = Vector2(390, 240)
	teacher_box.add_theme_stylebox_override("panel", _style(Color("#1a2633"), GOLD, 2, 12))
	teacher_box.visible = false
	game_layer.add_child(teacher_box)

	var margin := MarginContainer.new()
	margin.position = Vector2(14, 12)
	margin.size = Vector2(362, 216)
	teacher_box.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)

	var t_title := _label("👑 师长督军案台", 17, GOLD_LIGHT)
	v.add_child(t_title)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	lock_btn = _button("提前锁令", CORAL, 38)
	lock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock_btn.pressed.connect(_teacher_lock)
	row1.add_child(lock_btn)

	settle_btn = _button("结算本候", Color("#1e3a5f"), 38)
	settle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settle_btn.pressed.connect(_teacher_settle)
	row1.add_child(settle_btn)
	v.add_child(row1)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	next_btn = _button("进入下一候", BAMBOO, 38)
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn.pressed.connect(_teacher_next)
	row2.add_child(next_btn)

	admin_status_btn = _button("刷新全盘", Color("#55493b"), 38)
	admin_status_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	admin_status_btn.pressed.connect(_teacher_status)
	row2.add_child(admin_status_btn)
	v.add_child(row2)

func _teacher_lock() -> void:
	action_status.text = "锁令中..."
	api.request("POST", "/api/slice/admin/lock", {"turn_id": _turn_id(), "force": true}, func(ok: bool, _d: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		action_status.text = "已提前锁令。"
		_refresh_state()
	)

func _teacher_settle() -> void:
	action_status.text = "结算中..."
	api.request("POST", "/api/slice/admin/settle", {"turn_id": _turn_id()}, func(ok: bool, _d: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		action_status.text = "本候推演已毕。"
		_refresh_state()
	)

func _teacher_next() -> void:
	action_status.text = "进入下一候..."
	api.request("POST", "/api/slice/admin/next-turn", {"game_id": int(state.get("game", {}).get("id", 1))}, func(ok: bool, _d: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		action_status.text = "已翻开崭新一候。"
		_refresh_state()
	)

func _teacher_status() -> void:
	action_status.text = "同步全域状态..."
	_refresh_state()

# ---------------------------------------------------------------------------
# 充值弹窗与测试兼容节点
# ---------------------------------------------------------------------------

func _build_recharge_dialog() -> void:
	recharge_dialog = AcceptDialog.new()
	recharge_dialog.title = "积分兑换文玉"
	recharge_dialog.min_size = Vector2i(480, 320)
	recharge_dialog.get_ok_button().visible = false
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(430, 240)
	v.add_theme_constant_override("separation", 10)
	recharge_dialog.add_child(v)

	recharge_info = _label("现有积分：-- | 今日已兑：0/500", 14, INK)
	v.add_child(recharge_info)

	var h := HBoxContainer.new()
	h.add_child(_label("兑换文玉数量：", 14, INK))
	recharge_spin = SpinBox.new()
	recharge_spin.min_value = 1
	recharge_spin.max_value = 50
	recharge_spin.value = 10
	h.add_child(recharge_spin)
	v.add_child(h)

	var rate_hint := _label("10 积分 = 1 文玉，兑换仅记账不扣积分余额", 12, MUTED)
	v.add_child(rate_hint)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	var cancel := Button.new()
	cancel.text = "放弃"
	cancel.pressed.connect(func(): recharge_dialog.hide())
	btns.add_child(cancel)
	recharge_confirm = Button.new()
	recharge_confirm.text = "核验兑换"
	recharge_confirm.pressed.connect(_do_recharge)
	btns.add_child(recharge_confirm)
	v.add_child(btns)

	add_child(recharge_dialog)

func _open_recharge() -> void:
	if wallet.is_empty():
		_refresh_state()
	var score := int(wallet.get("score", 0))
	var converted := int(wallet.get("today_converted_points", 0))
	var cap := int(wallet.get("daily_cap", 500))
	recharge_info.text = "现有积分：%d | 今日已转：%d/%d" % [score, converted, cap]
	recharge_dialog.popup_centered()

func _do_recharge() -> void:
	var jade := int(recharge_spin.value)
	var req_key := "client_rech_%d_%d" % [Time.get_unix_time_from_system(), randi() % 10000]
	recharge_confirm.disabled = true
	api.request("POST", "/api/slice/recharge", {
		"jade_amount": jade,
		"request_key": req_key,
	}, func(ok: bool, data: Dictionary, err: Dictionary):
		recharge_confirm.disabled = false
		if not ok:
			_show_error(err)
			return
		recharge_dialog.hide()
		wallet["jade"] = data.get("jade", 0)
		wallet_label.text = "💎 文玉 %d" % int(wallet["jade"])
		action_status.text = "成功兑换 %d 文玉！" % jade
		_toast("文玉加仓成功！")
	)

func _build_legacy_compat_nodes() -> void:
	origin_select = OptionButton.new()
	target_select = OptionButton.new()
	advance_btn = Button.new()
	defend_btn = Button.new()
	withdraw_btn = Button.new()
	report_btn = Button.new()
	replay_btn = Button.new()
	refresh_btn = Button.new()
	player_box = Panel.new()
	pet_banner_label = Label.new()
	my_order_label = Label.new()
	node_info = Label.new()
	turn_hint = Label.new()
	action_status = Label.new()

	advance_btn.pressed.connect(_submit_advance)
	defend_btn.pressed.connect(_submit_defend)
	withdraw_btn.pressed.connect(_withdraw_order)

# ---------------------------------------------------------------------------
# 业务逻辑与状态同步
# ---------------------------------------------------------------------------

func _on_login(as_teacher: bool) -> void:
	var name_val := name_edit.text.strip_edges()
	var pass_val := pass_edit.text.strip_edges()
	if name_val == "" or pass_val == "":
		login_status.text = "请填写姓名与密码。"
		return
	api.set_base_url(url_edit.text)
	_save_config()
	_set_login_busy(true)

	var path := "/api/auth/admin-login" if as_teacher else "/api/auth/login"
	var body: Dictionary
	if as_teacher:
		body = {"username": name_val, "password": pass_val, "game_code": "SLICE_A"}
	else:
		body = {"name": name_val, "password": pass_val, "game_code": "SLICE_A"}

	api_epoch += 1
	var current_epoch := api_epoch
	api.request("POST", path, body, func(ok: bool, data: Dictionary, err: Dictionary):
		if current_epoch != api_epoch:
			return
		_set_login_busy(false)
		if not ok:
			login_status.text = str(err.get("message", "登录失败"))
			return
		api.token = str(data.get("token", ""))
		login_status.text = ""
		login_layer.visible = false
		game_layer.visible = true
		_refresh_state()
	)

func _set_login_busy(busy: bool) -> void:
	login_student_btn.disabled = busy
	login_student_btn.text = "正在踏入山河..." if busy else "踏 入 山 河"

func _on_logout() -> void:
	api.token = ""
	_logout_local("已安全归隐")

func _logout_local(message: String) -> void:
	api_epoch += 1
	poll_timer.stop()
	polling = false
	state = {}
	me = {}
	wallet = {}
	selected_code = ""
	game_layer.visible = false
	login_layer.visible = true
	login_status.text = message
	for b in node_buttons.values():
		if is_instance_valid(b):
			b.queue_free()
	node_buttons.clear()

func _refresh_state() -> void:
	if polling or api.token == "":
		return
	polling = true
	api_epoch += 1
	var current_epoch := api_epoch
	api.request("GET", "/api/slice/state", null, func(ok: bool, data: Dictionary, err: Dictionary):
		polling = false
		if current_epoch != api_epoch:
			return
		if not ok:
			var code := str(err.get("code", ""))
			if code == "UNAUTHORIZED" or code == "SESSION_EXPIRED":
				_logout_local("登录已过期，请重新登录")
				return
			action_status.text = str(err.get("message", "获取战局失败"))
			_toast(str(err.get("message", "获取战局失败")), true)
			_set_offline(true, "⚠️ 烽烟微弱 · 战局同步受阻（点击重试）")
			return
		_set_offline(false)
		state = data
		_render_state(data)
		if not poll_timer.is_stopped() == false:
			poll_timer.start()
	)

func _render_state(data: Dictionary) -> void:
	me = data.get("me", {})
	var raw_wallet: Variant = data.get("wallet", {})
	wallet = raw_wallet if typeof(raw_wallet) == TYPE_DICTIONARY else {}
	var map_data: Dictionary = data.get("map", {})
	map.setup(map_data)

	var turn: Dictionary = data.get("turn", {})
	countdown_seconds = int(turn.get("seconds_remaining", 0))
	countdown_last_msec = Time.get_ticks_msec()

	var role := str(me.get("role", "player"))
	var student_name := str(me.get("name", "学子"))
	title_label.text = student_name
	wallet_label.text = "💎 文玉 %d" % int(wallet.get("jade", 0))

	var faction: Variant = me.get("faction", null)
	if typeof(faction) == TYPE_DICTIONARY:
		faction_label.text = str(faction.get("name", "中立")) + "阵营"

	var pet: Variant = me.get("pet", null)
	if typeof(pet) == TYPE_DICTIONARY:
		top_pet_icon.text = str(pet.get("name", "令")).substr(0, 1)

	var nodes: Array = map_data.get("nodes", [])
	_rebuild_node_buttons(nodes)
	_refresh_faction_page()

	teacher_box.visible = (role == "teacher")
	_update_order_ui()

	# Phase 1: 同步军团编成 (composition)
	var comp_val: Variant = data.get("composition", {})
	var comp_info: Dictionary = comp_val if typeof(comp_val) == TYPE_DICTIONARY else {}
	var comp_types_val: Variant = comp_info.get("types", [])
	var comp_types: Array = comp_types_val if typeof(comp_types_val) == TYPE_ARRAY else []
	var comp_changed_once: bool = bool(comp_info.get("changed_once", false))
	if composition_panel and not comp_types.is_empty():
		composition_panel.set_composition_state(comp_types, comp_changed_once)

	# Phase 1: 同步每日手牌 (hand) 与已出令 (card_orders)
	_sync_hand_and_orders(data)

func _rebuild_node_buttons(nodes: Array) -> void:
	for b in node_buttons.values():
		if is_instance_valid(b):
			b.queue_free()
	node_buttons.clear()
	for n in nodes:
		var code := str(n.get("code", ""))
		var b := Button.new()
		b.text = ""
		b.size = Vector2(140, 140)
		b.position = map.node_position(code) - Vector2(70, 105)
		b.tooltip_text = str(n.get("name", code))
		b.focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		b.add_theme_stylebox_override("normal", empty)
		b.add_theme_stylebox_override("hover", _style(Color(1, 1, 1, 0.08), GOLD, 2, 20))
		b.add_theme_stylebox_override("pressed", _style(Color(1, 1, 1, 0.15), CORAL, 2, 20))
		b.add_theme_stylebox_override("focus", empty)
		b.pressed.connect(_on_node_pressed.bind(code))
		if map_world != null:
			map_world.add_child(b)
		else:
			map_shell.add_child(b)
		node_buttons[code] = b

func _on_node_pressed(code: String) -> void:
	_open_city_drawer(code)

func _neighbors(code: String) -> Array:
	var out: Array = []
	for e in state.get("map", {}).get("edges", []):
		if typeof(e) != TYPE_ARRAY or e.size() < 2:
			continue
		if str(e[0]) == code:
			out.append(str(map.node_by_code(str(e[1])).get("name", e[1])))
		elif str(e[1]) == code:
			out.append(str(map.node_by_code(str(e[0])).get("name", e[0])))
	return out

func _update_order_ui() -> void:
	var role := str(me.get("role", "player"))
	var can_edit := bool(state.get("can_edit", false)) and role == "player" and not order_submitting
	var order: Variant = state.get("my_order", null)
	map.set_my_order(order)

	if typeof(order) == TYPE_DICTIONARY:
		my_order_label.text = "📜 军令已下：【%s】向【%s】%s" % [
			str(order.get("origin_name", "")),
			str(order.get("target_name", "")),
			"进军" if str(order.get("action", "")) == "advance" else "驻守"
		]
	else:
		my_order_label.text = "⏳ 今日待命：点击地图城池下达军令"

func _on_countdown_tick() -> void:
	if not game_layer.visible or countdown_last_msec == 0:
		return
	var left: int = max(0, countdown_seconds - int((Time.get_ticks_msec() - countdown_last_msec) / 1000))
	if left <= 0:
		countdown_label.text = "⏳ 已截止，待推演"
	else:
		countdown_label.text = "⏳ 距 21:00 锁令: %02d:%02d" % [int(left / 60), left % 60]

func _new_key(prefix: String) -> String:
	return "%s_%d_%d" % [prefix, Time.get_unix_time_from_system(), randi() % 100000]

func _turn_id() -> int:
	return int(state.get("turn", {}).get("id", 0))

func _submit_advance() -> void:
	var origin := ""
	var target := ""
	if origin_select.item_count > 0:
		origin = str(origin_select.get_item_metadata(0))
	if target_select.item_count > 0:
		target = str(target_select.get_item_metadata(0))
	if origin == "" or target == "":
		_toast("请先选择进军城池。", true)
		return
	_submit_advance_direct(origin, target)

func _submit_advance_direct(origin: String, target: String) -> void:
	if order_submitting:
		return
	order_submitting = true
	action_status.text = "传达军令中..."
	api.request("POST", "/api/slice/orders", {
		"request_key": _new_key("adv"),
		"turn_id": _turn_id(),
		"action": "advance",
		"origin_node": origin,
		"target_node": target,
	}, func(ok: bool, data: Dictionary, err: Dictionary):
		order_submitting = false
		if not ok:
			_show_error(err)
			return
		action_status.text = "军令已盖印！"
		_toast("进军军令已加盖军印！")
		state["my_order"] = data.get("order", {})
		_update_order_ui()
	)

func _submit_defend() -> void:
	var origin := ""
	for n in state.get("map", {}).get("nodes", []):
		if bool(n.get("is_my_faction", false)):
			origin = str(n.get("code", ""))
			break
	if origin == "":
		origin = "A_START"
	_submit_defend_direct(origin)

func _submit_defend_direct(origin: String) -> void:
	if order_submitting:
		return
	order_submitting = true
	action_status.text = "传达军令中..."
	print("SUBMIT DEFEND: origin=", origin, " turn_id=", _turn_id())
	api.request("POST", "/api/slice/orders", {
		"request_key": _new_key("def"),
		"turn_id": _turn_id(),
		"action": "defend",
		"origin_node": origin,
		"target_node": origin,
	}, func(ok: bool, data: Dictionary, err: Dictionary):
		order_submitting = false
		if not ok:
			_show_error(err)
			return
		action_status.text = "坚守军令已定！"
		_toast("驻守军令已加盖军印！")
		state["my_order"] = data.get("order", {})
		_update_order_ui()
	)

func _withdraw_order() -> void:
	if order_submitting:
		return
	order_submitting = true
	action_status.text = "撤销中..."
	api.request("POST", "/api/slice/orders/withdraw", {
		"turn_id": _turn_id(),
	}, func(ok: bool, _data: Dictionary, err: Dictionary):
		order_submitting = false
		if not ok:
			_show_error(err)
			return
		action_status.text = "军令已撤回。"
		_toast("军令已成功撤回。")
		state.erase("my_order")
		_update_order_ui()
		if city_drawer != null and city_drawer.visible:
			_open_city_drawer(selected_code)
	)

func _show_error(error: Dictionary) -> void:
	print("API ERROR: ", error)
	var code := str(error.get("code", ""))
	var msg := str(error.get("message", "请求失败"))
	action_status.text = msg
	_toast(msg, true)
	if code == "UNAUTHORIZED" or code == "SESSION_EXPIRED":
		_logout_local("凭据已失效，请重新登录")

# ---------------------------------------------------------------------------
# 本地配置保存（安全红线：严禁保存密码）
# ---------------------------------------------------------------------------

func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://slice.cfg") == OK:
		var u: String = cfg.get_value("net", "url", "")
		if u != "":
			url_edit.text = u
			api.set_base_url(u)
		var saved_name := str(cfg.get_value("auth", "name", ""))
		# 学生 App 不提供教师入口：旧测试留下的 teacher 不预填
		if saved_name != "" and saved_name.to_lower() != "teacher":
			name_edit.text = saved_name

func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("net", "url", url_edit.text.strip_edges())
	var role := str(me.get("role", "player")) if typeof(me) == TYPE_DICTIONARY else "player"
	var saved_name := name_edit.text.strip_edges()
	# 只记住学生姓名；教师账号不写进学生 App 配置
	if role != "player" or saved_name.to_lower() == "teacher":
		saved_name = ""
	cfg.set_value("auth", "name", saved_name)
	cfg.save("user://slice.cfg")
