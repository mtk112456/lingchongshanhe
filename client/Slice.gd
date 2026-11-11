extends Control

## 《青竹文房·灵宠山河》客户端主架构
## 商业级主流轻 SLG 导航骨架与全屏分层交互（对标《率土之滨》《三国志·战略版》《江南百景图》）

const FONT_PATH := "res://fonts/NotoSerifCJKsc-Regular.otf"
const SliceMapScript = preload("res://SliceMap.gd")
const Map12MapScript = preload("res://Map12Map.gd")
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
# S2 全局错误码人话翻译字典（对标中小学可读性，拒绝甩英文代码）
# ---------------------------------------------------------------------------
const ERROR_CODE_TRANSLATION := {
	"CHANGAN_LOCKED": "王城长安受天子龙气护佑，至第 3 周方可开启征伐！",
	"SEASON_FINAL_WEEK": "赛季决战周已至，诸军只准进军长安或其接壤邻城！",
	"SCOUT_REQUIRED": "军机未明！该城设有疑兵或迷雾，须先签发【哨探】将令破除迷雾！",
	"TURN_LOCKED": "今日军令已提前封印，诸军枕戈待旦，正待 21:00 沙盘推演！",
	"TURN_DEADLINE_PASSED": "今日 21:00 锁令时刻已过，请待明日晨起新一候方可出征！",
	"ALREADY_OWNED": "该城已归属我方同门书院，无需攻打，可选择派遣驻守！",
	"ORDER_SLOT_FULL": "今日 3 队将令已全部签发！可撤回任一已出队伍后重新调度！",
	"INVALID_ORDER": "军令文书有误，请核验出征路径与编队！",
	"CANNOT_ATTACK_NON_NEIGHBOR": "关河阻隔！我方行营与目标城池尚未通衢，仅能向接壤城池进军！",
	"TARGET_NOT_REACHABLE": "关河阻隔！尚未开辟通往该据点的行军驰道！",
	"ESTATE_MAX_LEVEL": "该厢房已达 3 级满级，文治武功皆已登峰！",
	"ESTATE_INSUFFICIENT_MERIT": "军功尚有不足，去沙盘出令或驻守友军即可攒取！",
	"ESTATE_BAD_ROOM": "未识得此间厢房名目，请刷新后重试。",
	"ESTATE_NO_HOME": "暂未定位所属小院城池，请稍后刷新山河图籍。",
	"INVALID_CREDENTIALS": "名录不合，姓名或密匙有误，请核实后重新踏入山河！",
	"UNAUTHORIZED": "修习凭据已失效，请重新登录学堂。",
	"SESSION_EXPIRED": "山河会话已逾时，请重新登录学堂。",
	"NETWORK_ERROR": "文渊驿报受阻，网络连接异常，请检查学堂通信网络。"
}

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
var preferred_game_code: String = ""
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
var legend_hbox: HBoxContainer
var legend_node_count: int = -1

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
var res_food_lbl: Label
var res_wood_lbl: Label
var res_iron_lbl: Label
var wallet_label: Label
var countdown_label: Label
var hud_morning_btn: Button
var morning_red_dot: Panel
var hud_settings_btn: Button
var hud_logout_btn: Button
var last_hand_signature: String = ""
var rail_buttons: Array = []
var dock_row: HBoxContainer

# 断线/弱网全局警示横幅与动效
var offline_banner: PanelContainer
var offline_banner_label: Label
var offline_retry_btn: Button
var drawer_tween: Tween
var dock_tween: Tween
var is_drawer_open: bool = false

# S2 首次登录 3 步新手教学向导
var tutorial_overlay: Control
var tutorial_box: PanelContainer
var tutorial_title_lbl: Label
var tutorial_desc_lbl: Label
var tutorial_action_btn: Button
var tutorial_skip_btn: Button
var tutorial_step: int = 0
var tutorial_img_frame: PanelContainer
var tutorial_img_clip: Control
var tutorial_img: TextureRect
var tutorial_atlas: AtlasTexture
var tutorial_tag_city: PanelContainer
var tutorial_tag_card: PanelContainer
var tutorial_parallax_t: float = 0.0
var tutorial_parallax_px: float = 0.0
var tutorial_img_base_pos: Vector2 = Vector2.ZERO
var tutorial_icon_badge: Label

# 迷雾与侦察数据
var scouted_nodes: Array = []
var reachable_targets: Array = []

# S01 左右侧栏与底部导航
var left_rail: Control
var right_rail: Control
var bottom_dock: Control
var dock_tab_buttons: Dictionary = {}

# S01 城池详情抽屉（不遮手牌双区布局 + 战前军议折叠卡）
var city_drawer: Panel
var city_drawer_margin: MarginContainer
var city_drawer_handle: Panel
var city_drawer_scroll: ScrollContainer
var city_avatar_box: Panel
var city_avatar_icon: Label
var city_title_label: Label
var city_type_badge: Label
var city_faction_badge: Label
var city_governor_badge: Label
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
var city_action_scout_btn: Button
var city_action_battle_btn: Button
var current_battle_id: int = 0

# S01 战前军议预估折叠卡（首层 3 项，详情可展开）
var city_forecast_card: PanelContainer
var city_forecast_toggle_btn: Button
var city_forecast_badge: Label
var city_forecast_summary_lbl: Label
var city_forecast_detail_box: VBoxContainer
var city_forecast_detail_lbl: Label
var city_forecast_advice_lbl: Label
var city_forecast_footer_lbl: Label
var city_forecast_expanded: bool = false
var _forecast_debounce_timer: Timer
var _forecast_req_seq: int = 0
var _last_forecast_node: String = ""
var _last_forecast_data: Dictionary = {}
var _last_forecast_err: String = ""
var _last_forecast_loading: bool = false

# Phase 1 & P0 新模块：军团编成 / 小院 / 赛季史书 / 晨报弹层
const CompositionPanelScript = preload("res://CompositionPanel.gd")
const EstateViewScript = preload("res://EstateView.gd")
const SeasonViewScript = preload("res://SeasonView.gd")
const MorningReportModalScript = preload("res://MorningReportModal.gd")
const BattleReplayScene = preload("res://BattleReplay.tscn")
var estate_page: Control
var estate_data: Dictionary = {}
var merit_summary_data: Dictionary = {}
var cached_merit_payload: Dictionary = {}
var season_page: Control
var season_data: Dictionary = {}
var season_history_data: Dictionary = {}
var bulletin_data: Dictionary = {}
var _bulletin_submitting: bool = false
var morning_modal: Control
var _morning_auto_checked: bool = false
var _season_award_auto_checked: bool = false
var hand_preview_codes: Array = []
var hand_preview_panel: PanelContainer
var _merit_highlight_on_open: bool = false
var composition_panel: PanelContainer
var army_margin: MarginContainer
var army_header_sub_lbl: Label
var army_bulletin_box: PanelContainer
var army_bulletin_row: HBoxContainer
var army_bulletin_hint_lbl: Label
var hand_cards_bar: PanelContainer
var hand_cards_container: HBoxContainer
var hand_card_views: Array = []
var hand_redraw_btn: Button
var hand_collapse_btn: Button
var hand_lane_btn: Button
var hand_row_btn: Button
var hand_lane_override: int = 0
var hand_row_override: String = ""
var hand_cards_data: Array = []
var hand_redraw_used: bool = false
var hand_bar_collapsed: bool = false
var battle_replay_overlay: Control
var battle_replay_instance: Control
var card_tooltip_panel: PanelContainer
var card_tooltip_title: Label
var card_tooltip_desc: Label

# S04 战争日报全屏页（含个人战报、诸军四榜、天下大势与嵌入复盘子页）
var report_page: Control
var report_margin: MarginContainer
var report_tab_daily_btn: Button
var report_tab_replay_btn: Button
var report_daily_box: VBoxContainer
var report_replay_box: VBoxContainer
var _active_report_subtab: String = "daily"
var report_headline_panel: PanelContainer
var report_headline_lbl: Label
var report_seal_rect: TextureRect
var report_time_lbl: Label
var report_my_text: RichTextLabel
var report_my_card: PanelContainer
var report_me_expand_btn: Button
var report_me_detail_text: RichTextLabel
var report_me_expanded: bool = false
var report_estate_row: HBoxContainer
var report_estate_lbl: Label
var report_estate_btn: Button
var report_boards_text: RichTextLabel
var last_report_turn_id := 0
var last_report_payload: Dictionary = {}
var report_world_text: RichTextLabel
var report_summary_text: RichTextLabel
var report_dialog: Control # 兼容旧代码引用
var report_text: RichTextLabel # 兼容旧代码引用
var report_loading_box: PanelContainer
var report_error_box: PanelContainer
var report_error_lbl: Label

# S04 回放子页组件（原 S05 已并入 S04_REPORT，保留字段兼容 ReplaySmoke）
var replay_page: Control
var replay_margin: MarginContainer
var replay_dialog: Control # 绑定 report_replay_box，兼容 ReplaySmoke
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
	if tutorial_overlay != null and tutorial_overlay.visible and tutorial_step == 1 and tutorial_img != null and tutorial_img.visible:
		if AudioManager.is_reduced_motion or DisplayServer.get_name() == "headless":
			if absf(tutorial_parallax_px) > 0.01:
				tutorial_parallax_px = 0.0
				_layout_tutorial_media()
		else:
			tutorial_parallax_t += delta
			tutorial_parallax_px = sin(tutorial_parallax_t * 0.7) * 3.0
			tutorial_img.position.x = tutorial_img_base_pos.x + tutorial_parallax_px

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
		s.texture_margin_left = 32
		s.texture_margin_top = 32
		s.texture_margin_right = 32
		s.texture_margin_bottom = 32
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
	b.add_theme_color_override("font_disabled_color", Color("#d6c4ad"))

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
		s.texture_margin_left = 16
		s.texture_margin_top = 16
		s.texture_margin_right = 16
		s.texture_margin_bottom = 16
		s.content_margin_left = 0
		s.content_margin_top = 0
		s.content_margin_right = 0
		s.content_margin_bottom = 0
		b.add_theme_stylebox_override("normal", s)
		var sh := StyleBoxTexture.new()
		sh.texture = tex
		sh.texture_margin_left = 16
		sh.texture_margin_top = 16
		sh.texture_margin_right = 16
		sh.texture_margin_bottom = 16
		sh.content_margin_left = 0
		sh.content_margin_top = 0
		sh.content_margin_right = 0
		sh.content_margin_bottom = 0
		sh.modulate_color = Color(1.0, 0.94, 0.86)
		b.add_theme_stylebox_override("hover", sh)
		var sp := StyleBoxTexture.new()
		sp.texture = tex
		sp.texture_margin_left = 16
		sp.texture_margin_top = 16
		sp.texture_margin_right = 16
		sp.texture_margin_bottom = 16
		sp.content_margin_left = 0
		sp.content_margin_top = 0
		sp.content_margin_right = 0
		sp.content_margin_bottom = 0
		sp.modulate_color = Color(0.86, 0.8, 0.74)
		b.add_theme_stylebox_override("pressed", sp)
		var sd := StyleBoxTexture.new()
		sd.texture = tex
		sd.texture_margin_left = 16
		sd.texture_margin_top = 16
		sd.texture_margin_right = 16
		sd.texture_margin_bottom = 16
		sd.content_margin_left = 0
		sd.content_margin_top = 0
		sd.content_margin_right = 0
		sd.content_margin_bottom = 0
		sd.modulate_color = Color(0.55, 0.5, 0.44, 0.95)
		b.add_theme_stylebox_override("disabled", sd)
	else:
		b.add_theme_stylebox_override("normal", _style(color, color.darkened(0.2), 1, 8, 8))
		b.add_theme_stylebox_override("hover", _style(color.lightened(0.12), color.darkened(0.2), 1, 8, 8))
		b.add_theme_stylebox_override("pressed", _style(color.darkened(0.15), color.darkened(0.3), 1, 8, 8))
		b.add_theme_stylebox_override("disabled", _style(Color("#3a3027"), Color("#6d6458"), 1, 8, 8))
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
		var top_bar_h := (50.0 if size.y < 650.0 else (62.0 if size.x < 900.0 else 72.0)) if current_page == "S01_MAP" else 64.0
		offline_banner.position = Vector2((size.x - banner_w) / 2.0, top_bar_h + 4.0)

# ---------------------------------------------------------------------------
# 页面路由与分层导航管理
# ---------------------------------------------------------------------------

const DOCK_PAGES := ["S01_MAP", "S03_ARMY", "S04_REPORT", "S02_CITY_HUB", "S10_SEASON"]

func _navigate_to(page_id: String) -> void:
	if page_id == "S05_REPLAY":
		page_id = "S04_REPORT"
	if page_id != "S02_CITY_HUB" and estate_page != null:
		estate_page.on_exited_page()
	if page_id != "S01_MAP" and morning_modal != null and morning_modal.visible:
		morning_modal.close_and_mark_read()
	current_page = page_id
	var target_node: Control = null
	if page_id == "S01_MAP":
		target_node = map_shell
		map_shell.visible = true
		if legend_panel != null and (city_drawer == null or not city_drawer.visible or size.y >= 650.0):
			legend_panel.visible = true
		if right_rail != null and (not is_drawer_open or size.y >= 650.0):
			right_rail.visible = true
		if hand_cards_bar != null:
			hand_cards_bar.visible = true
		for p in pages.values():
			p.visible = false
	else:
		map_shell.visible = false
		if hand_cards_bar != null:
			hand_cards_bar.visible = false
		if is_drawer_open or (city_drawer != null and city_drawer.visible):
			_toggle_city_drawer(false)
		for k in pages.keys():
			var is_target: bool = (k == page_id)
			pages[k].visible = is_target
			if is_target:
				target_node = pages[k]

	if bottom_dock != null:
		bottom_dock.visible = (page_id in DOCK_PAGES)

	if page_id == "S02_CITY_HUB" and estate_page != null:
		estate_page.set_estate_state(estate_data, me, merit_summary_data)
		estate_page.on_entered_page()
		if _merit_highlight_on_open:
			_merit_highlight_on_open = false
			estate_page.flash_merit_card()

	# BGM 路由：赛季曲缺失时回退沙盘曲；同曲由 play_bgm 去重，不会重启
	var bgm_name := "season" if page_id == "S10_SEASON" and AudioManager.has_bgm("season") else "map"
	AudioManager.play_bgm(bgm_name)

	_update_dock_highlight(page_id)
	_layout_responsive()

	if target_node != null and not AudioManager.is_reduced_motion:
		target_node.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(target_node, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _open_estate_page(highlight_merit: bool = false) -> void:
	_merit_highlight_on_open = highlight_merit
	_navigate_to("S02_CITY_HUB")
	if api != null and api.token != "":
		api.get_estate(func(ok: bool, data: Dictionary, _err: Dictionary):
			if not ok:
				return
			var es_val: Variant = data.get("estate", data)
			if typeof(es_val) == TYPE_DICTIONARY and not es_val.is_empty():
				estate_data = es_val.duplicate(true)
				state["estate"] = estate_data
				if estate_page != null:
					estate_page.set_estate_state(estate_data, me, merit_summary_data)
		)
		api.get_merit(func(ok: bool, data: Dictionary, _err: Dictionary):
			if ok and estate_page != null:
				estate_page.set_merit_leaderboard(data)
		)

func _sync_dock_for_estate_drawer(hide_dock: bool) -> void:
	if bottom_dock == null:
		return
	var is_compact_h := size.y < 650.0
	var is_phone := (size.x < 900.0) or is_compact_h
	var dock_h := 46.0 if is_compact_h else (56.0 if is_phone else 60.0)
	var target_y := size.y if hide_dock else (size.y - dock_h)
	if is_instance_valid(dock_tween) and dock_tween.is_running():
		dock_tween.kill()
	if AudioManager.is_reduced_motion:
		bottom_dock.position.y = target_y
	else:
		dock_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		dock_tween.tween_property(bottom_dock, "position:y", target_y, 0.22)

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
			var lw := 150.0 if is_compact_h else (195.0 if is_phone else 300.0)
			hud_left_box.position = Vector2(6.0 if is_compact_h else (8.0 if is_phone else 16.0), safe_top + (top_h - safe_top - 44.0) / 2.0)
			hud_left_box.size = Vector2(lw, 44.0)
			hud_left_box.add_theme_constant_override("separation", 6 if is_compact_h else 10)
		if top_avatar_box != null:
			top_avatar_box.custom_minimum_size = Vector2(36, 36) if is_compact_h else Vector2(44, 44)
		if title_label != null:
			title_label.add_theme_font_size_override("font_size", 13 if is_compact_h else 15)
		if faction_label != null:
			faction_label.add_theme_font_size_override("font_size", 10 if is_compact_h else 12)
		if combat_power_label != null:
			combat_power_label.add_theme_font_size_override("font_size", 10 if is_compact_h else 12)
			
		if hud_right_box != null:
			var rw := 208.0 if is_compact_h else (260.0 if is_phone else 420.0)
			hud_right_box.position = Vector2(w - rw - (6.0 if is_compact_h else (8.0 if is_phone else 16.0)), safe_top + (top_h - safe_top - 44.0) / 2.0)
			hud_right_box.size = Vector2(rw, 44.0)
			hud_right_box.add_theme_constant_override("separation", 4 if is_compact_h else 8)
		if hud_morning_btn != null:
			var m_w := 44.0 if is_compact_h else 76.0
			hud_morning_btn.text = "📰" if is_compact_h else "📰 晨报"
			hud_morning_btn.custom_minimum_size = Vector2(m_w, 44)
			if morning_red_dot != null:
				morning_red_dot.position = Vector2(m_w - 11.0, 3.0)
		for hbtn in [hud_settings_btn, hud_logout_btn]:
			if hbtn != null:
				hbtn.custom_minimum_size = Vector2(34, 44) if is_compact_h else Vector2(44, 44)
		if countdown_label != null:
			countdown_label.add_theme_font_size_override("font_size", 11 if is_compact_h else 13)
			_on_countdown_tick()
			
		if resource_bar != null:
			resource_bar.add_theme_constant_override("separation", 3 if is_compact_h else 8)
			if res_food_lbl != null:
				res_food_lbl.text = "🌾300" if is_compact_h else "🌾 粮 300"
				res_food_lbl.add_theme_font_size_override("font_size", 11 if is_compact_h else 13)
			if res_wood_lbl != null:
				res_wood_lbl.text = "🌲240" if is_compact_h else "🌲 木 240"
				res_wood_lbl.add_theme_font_size_override("font_size", 11 if is_compact_h else 13)
			if res_iron_lbl != null:
				res_iron_lbl.text = "⛏180" if is_compact_h else "⛏️ 铁 180"
				res_iron_lbl.add_theme_font_size_override("font_size", 11 if is_compact_h else 13)
			if wallet_label != null:
				var cur_jade := int(wallet.get("jade_balance", wallet.get("jade", 0)))
				wallet_label.text = ("💎%d" % cur_jade) if is_compact_h else ("💎 文玉 %d" % cur_jade)
				wallet_label.add_theme_font_size_override("font_size", 11 if is_compact_h else 13)
			if recharge_btn != null:
				recharge_btn.custom_minimum_size = Vector2(28, 36) if is_compact_h else Vector2(32, 32)
			if is_compact_h and hud_left_box != null and hud_right_box != null:
				var rx := hud_left_box.position.x + hud_left_box.size.x + 4.0
				var rw_avail := maxf(hud_right_box.position.x - rx - 4.0, 120.0)
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

	# 5. 底部导航栏（上提至 game_layer，仅主导航页常驻，抽屉滑出时同步让位）
	var is_dock_page := current_page in DOCK_PAGES
	var dock_h := 46.0 if is_compact_h else (56.0 if is_phone else 60.0)
	var estate_drawer_open := (estate_page != null and bool(estate_page.get("phone_drawer_open")))
	if bottom_dock != null:
		bottom_dock.visible = is_dock_page
		bottom_dock.size = Vector2(w, dock_h)
		if is_instance_valid(dock_tween) and dock_tween.is_running():
			dock_tween.kill()
		var hide_dock_for_compact_drawer := (is_compact_h and is_drawer_open)
		if hide_dock_for_compact_drawer or estate_drawer_open or not is_dock_page:
			bottom_dock.position = Vector2(0, h)
		else:
			bottom_dock.position = Vector2(0, h - dock_h)
		if dock_row != null:
			var max_dock_w := minf(w - 16.0, 740.0)
			dock_row.position = Vector2((w - max_dock_w) / 2.0, (dock_h - (38.0 if is_compact_h else 44.0)) / 2.0)
			dock_row.size = Vector2(max_dock_w, 38.0 if is_compact_h else 44.0)
			
		for tab_id in dock_tab_buttons.keys():
			var btn: Button = dock_tab_buttons[tab_id]
			btn.add_theme_font_size_override("font_size", 11 if is_compact_h else 14)

	if estate_page != null:
		estate_page.layout_responsive(Vector2(w, h), dock_h)
	if season_page != null:
		season_page.layout_responsive(Vector2(w, h), dock_h)
	if morning_modal != null:
		morning_modal.layout_responsive(Vector2(w, h))

	# 5.1 每日将令手牌栏（始终贴底可见！抽屉打开时不隐藏，构成上城下牌双区）
	var hand_bar_top := h - dock_h - 104.0
	if hand_cards_bar != null:
		var bar_w := minf(w - 12.0, 740.0)
		var target_bar_h := 28.0 if hand_bar_collapsed else (96.0 if is_compact_h else 106.0)
		var min_bar_h := 28.0 if hand_bar_collapsed else hand_cards_bar.get_combined_minimum_size().y
		var actual_bar_h := maxf(target_bar_h, min_bar_h)
		hand_cards_bar.size = Vector2(bar_w, actual_bar_h)
		var effective_bottom := 4.0 if (is_compact_h and is_drawer_open) else (dock_h + 2.0)
		hand_bar_top = h - effective_bottom - actual_bar_h
		hand_cards_bar.position = Vector2((w - bar_w) / 2.0, hand_bar_top)
		if current_page == "S01_MAP":
			hand_cards_bar.visible = true

	# 6. S01 城池详情抽屉 + 战前军议折叠卡（双区布局，绝不遮挡底部手牌栏与左侧主视野）
	if city_drawer != null:
		var drawer_w := minf(388.0, w * 0.56) if is_compact_h else (minf(w - 24.0, 480.0) if is_portrait else minf(w * 0.36, 480.0))
		var max_avail_h := maxf(180.0, hand_bar_top - top_h - 10.0)
		var desired_h := max_avail_h if is_compact_h else minf(max_avail_h, 520.0 if city_forecast_expanded else 372.0)
		var drawer_h := minf(max_avail_h, desired_h)
		var drawer_x := (w - drawer_w - 8.0) if is_compact_h else (w - drawer_w - 16.0)
		var drawer_y := (top_h + 4.0) if is_compact_h else (hand_bar_top - drawer_h - 10.0)
		city_drawer.size = Vector2(drawer_w, drawer_h)
		if is_drawer_open:
			if is_instance_valid(drawer_tween) and drawer_tween.is_running():
				drawer_tween.kill()
			city_drawer.modulate.a = 1.0
			city_drawer.position = Vector2(drawer_x, drawer_y)
		else:
			city_drawer.position = Vector2(drawer_x, h)
		if city_drawer_margin != null:
			city_drawer_margin.position = Vector2(10.0, 6.0)
			city_drawer_margin.size = Vector2(drawer_w - 20.0, drawer_h - 12.0)
		if city_drawer_handle != null:
			city_drawer_handle.position = Vector2((drawer_w - 44.0) / 2.0, 3.0)

		var act_btn_h := 34.0 if is_compact_h else 42.0
		var act_font_size := 12 if is_compact_h else 14
		if city_action_advance_btn != null:
			city_action_advance_btn.custom_minimum_size.y = act_btn_h
			city_action_advance_btn.add_theme_font_size_override("font_size", act_font_size)
		if city_action_scout_btn != null:
			city_action_scout_btn.custom_minimum_size = Vector2(86 if is_compact_h else 104, act_btn_h)
			city_action_scout_btn.add_theme_font_size_override("font_size", 11 if is_compact_h else 13)

	# 8. S03 / S04(含回放) / S06 页面自适应（有 Dock 页面按 h - top - dock_h 留足底部空间）
	var dock_bottom_pad := (dock_h + 6.0) if is_dock_page else 10.0
	if report_margin != null:
		var rep_top := 62.0 if is_compact_h else 70.0
		var rep_px := 10.0 if is_compact_h else 16.0
		report_margin.position = Vector2(rep_px, rep_top)
		report_margin.size = Vector2(w - rep_px * 2.0, h - rep_top - dock_bottom_pad)
		if replay_map != null:
			replay_map.custom_minimum_size = Vector2(0, 170 if is_compact_h else (360 if is_portrait else 300))
			
	if faction_margin != null:
		faction_margin.position = Vector2(16, 70)
		faction_margin.size = Vector2(w - 32, h - 80)
		if faction_cards_container != null:
			faction_cards_container.columns = 1 if is_phone else 2

	if army_margin != null:
		var army_top := 68.0 if is_compact_h else 70.0
		army_margin.position = Vector2(10.0 if is_compact_h else 16.0, army_top)
		army_margin.size = Vector2(w - (20.0 if is_compact_h else 32.0), h - army_top - dock_bottom_pad)

	# 9. Toast 通知条（非地图页统一按 64px 顶栏基准定位，防止遮挡返回栏）
	var active_header_h := top_h if current_page == "S01_MAP" else 64.0
	if toast_panel != null:
		var tw := minf(w - 40.0, 480.0)
		toast_panel.size = Vector2(tw, 44.0)
		toast_panel.position = Vector2((w - tw) / 2.0, active_header_h + 8.0)

	if offline_banner != null and offline_banner.visible:
		var banner_w := minf(w - 20.0, 400.0)
		offline_banner.size = Vector2(banner_w, 36.0)
		offline_banner.position = Vector2((w - banner_w) / 2.0, active_header_h + 4.0)

	# 10. 更新城池触控热区位置
	if map != null and not node_buttons.is_empty():
		for code in node_buttons.keys():
			var b: Button = node_buttons[code]
			if is_instance_valid(b):
				b.size = Vector2(140, 140)
				b.position = map.node_position(code) - Vector2(70, 105)

	# 11. S2 首次新手引导条自适应（第1步展示首令双步图卡且绝不占全屏；第2/3步收成轻量横条）
	if tutorial_box != null:
		var is_step1 := (tutorial_step <= 1)
		var is_compact_tut := (is_phone or is_compact_h)
		if is_step1:
			if tutorial_atlas != null and tutorial_atlas.atlas != null:
				tutorial_atlas.region = Rect2(24.0, 52.0, 948.0, 494.0) if is_compact_tut else Rect2(16.0, 28.0, 992.0, 532.0)
			var tb_w := minf(w - 28.0, 446.0 if is_compact_tut else 592.0)
			var tb_h := 130.0 if is_compact_tut else 182.0
			tutorial_box.custom_minimum_size = Vector2(tb_w, tb_h)
			tutorial_box.size = Vector2(tb_w, tb_h)
			tutorial_box.position = Vector2((w - tb_w) / 2.0, top_h + (8.0 if is_compact_h else 16.0))
			if tutorial_desc_lbl != null:
				tutorial_desc_lbl.custom_minimum_size = Vector2(160.0 if is_compact_tut else 220.0, 0.0)
			if tutorial_img_frame != null:
				var img_sz := Vector2(212.0, 110.0) if is_compact_tut else Vector2(308.0, 164.0)
				tutorial_img_frame.custom_minimum_size = img_sz
				tutorial_img_frame.size = img_sz
		else:
			var tb_w := minf(w - 24.0, 620.0 if not is_phone else 560.0)
			var tb_h := 66.0 if is_compact_h else 76.0
			tutorial_box.custom_minimum_size = Vector2(tb_w, tb_h)
			tutorial_box.size = Vector2(tb_w, tb_h)
			tutorial_box.position = Vector2((w - tb_w) / 2.0, top_h + (38.0 if is_compact_h else 58.0))
			if tutorial_desc_lbl != null:
				tutorial_desc_lbl.custom_minimum_size = Vector2(220.0, 0.0)
			if tutorial_img_frame != null:
				var img_sz := Vector2(96.0, 54.0) if is_compact_tut else Vector2(116.0, 64.0)
				tutorial_img_frame.custom_minimum_size = img_sz
				tutorial_img_frame.size = img_sz
		call_deferred("_layout_tutorial_media")

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
		else:
			# 抽屉已改右浮双区，地图不垂直上移露出底部暗板
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
	login_gear_btn.text = " 设置"
	if ResourceLoader.exists("res://assets/art/ui/icon_settings.png"):
		login_gear_btn.icon = load("res://assets/art/ui/icon_settings.png")
		login_gear_btn.expand_icon = true
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

	var raw_nodes: Variant = state.get("map", {}).get("nodes", [])
	var node_count: int = raw_nodes.size() if typeof(raw_nodes) == TYPE_ARRAY else 0
	var map_script: GDScript = SliceMapScript if node_count <= 5 else Map12MapScript
	map = map_script.new()
	map.size = Vector2(1400, 1000)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_world.add_child(map)

	_build_top_hud()
	_build_side_rails()
	_build_map_legend()
	_build_hand_cards_bar()
	_build_city_drawer()

	# 2. 独立全屏页面容器（S02-S13 等）与常驻上浮 BottomDock
	pages_container = Control.new()
	pages_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_layer.add_child(pages_container)

	_build_report_page()
	_build_all_placeholder_pages()
	_build_bottom_dock()
	_build_card_tooltip()
	_build_battle_replay_overlay()

	morning_modal = MorningReportModalScript.new()
	morning_modal.name = "MorningReportModal"
	morning_modal.dismissed.connect(_on_morning_modal_dismissed)
	morning_modal.go_estate_requested.connect(func(tid: int):
		_mark_morning_turn_seen(tid)
		_open_estate_page(true)
	)
	morning_modal.go_map_requested.connect(func(tid: int):
		_mark_morning_turn_seen(tid)
		_navigate_to("S01_MAP")
	)
	morning_modal.bulletin_selected.connect(_choose_bulletin_choice)
	game_layer.add_child(morning_modal)

	_forecast_debounce_timer = Timer.new()
	_forecast_debounce_timer.one_shot = true
	_forecast_debounce_timer.wait_time = 0.30
	_forecast_debounce_timer.timeout.connect(_on_forecast_debounce_timeout)
	add_child(_forecast_debounce_timer)

	# 3. 教师后台（抽屉保留以满足权限隔离和无头测试需求）
	_build_teacher_deck()
	_build_recharge_dialog()
	_build_legacy_compat_nodes()
	_init_tutorial_ui()

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

	var p_food := _create_res_pill("🌾 粮 300")
	res_food_lbl = p_food.get_child(0) as Label
	resource_bar.add_child(p_food)
	var p_wood := _create_res_pill("🌲 木 240")
	res_wood_lbl = p_wood.get_child(0) as Label
	resource_bar.add_child(p_wood)
	var p_iron := _create_res_pill("⛏️ 铁 180")
	res_iron_lbl = p_iron.get_child(0) as Label
	resource_bar.add_child(p_iron)

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

	hud_morning_btn = _button("📰 晨报", Color("#33485c"), 44)
	hud_morning_btn.custom_minimum_size = Vector2(72, 44)
	hud_morning_btn.tooltip_text = "查看昨日战报摘要与今日邸报 2 选 1"
	hud_morning_btn.pressed.connect(func(): _open_morning_report(true))
	hud_right_box.add_child(hud_morning_btn)

	morning_red_dot = Panel.new()
	morning_red_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	morning_red_dot.size = Vector2(10, 10)
	morning_red_dot.position = Vector2(61, 3)
	morning_red_dot.add_theme_stylebox_override("panel", _style(Color("#ff3b30"), CREAM, 1, 5, 0))
	morning_red_dot.visible = false
	hud_morning_btn.add_child(morning_red_dot)

	hud_settings_btn = _button("", Color("#3d2f26"), 44)
	hud_settings_btn.custom_minimum_size = Vector2(44, 44)
	if ResourceLoader.exists("res://assets/art/ui/icon_settings.png"):
		hud_settings_btn.icon = load("res://assets/art/ui/icon_settings.png")
		hud_settings_btn.expand_icon = true
	else:
		hud_settings_btn.text = "⚙️"
	hud_settings_btn.tooltip_text = "学堂设置"
	hud_settings_btn.pressed.connect(func(): _navigate_to("S11_SETTINGS"))
	hud_right_box.add_child(hud_settings_btn)

	hud_logout_btn = _button("🚪", Color("#3d2f26"), 44)
	hud_logout_btn.custom_minimum_size = Vector2(44, 44)
	hud_logout_btn.tooltip_text = "归隐登出"
	hud_logout_btn.pressed.connect(_on_logout)
	hud_right_box.add_child(hud_logout_btn)

# 构建 S01 左右贴边半透明悬浮图标列（仅保留已实装功能，未实装模块收起）
func _build_side_rails() -> void:
	rail_buttons.clear()
	left_rail = VBoxContainer.new()
	left_rail.position = Vector2(14, 86)
	left_rail.size = Vector2(48, 120)
	left_rail.add_theme_constant_override("separation", 8)
	map_shell.add_child(left_rail)

	_add_rail_item(left_rail, "🚩 阵营", "🚩", func(): _navigate_to("S06_FACTION"))

	right_rail = VBoxContainer.new()
	right_rail.position = Vector2(size.x - 62, 86)
	right_rail.size = Vector2(48, 120)
	right_rail.add_theme_constant_override("separation", 8)
	map_shell.add_child(right_rail)

	_add_rail_item(right_rail, "🎯 全图", "🎯", reset_view)
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

	legend_hbox = HBoxContainer.new()
	legend_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend_hbox.add_theme_constant_override("separation", 6)
	legend_panel.add_child(legend_hbox)
	_update_map_legend(5)

func _update_map_legend(n_count: int) -> void:
	if legend_hbox == null or legend_node_count == n_count:
		return
	legend_node_count = n_count
	for ch in legend_hbox.get_children():
		legend_hbox.remove_child(ch)
		ch.queue_free()
	var tag_title := _label("势态：", 11, CREAM)
	tag_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend_hbox.add_child(tag_title)
	var tags := [
		["● 笔", Color("#eb6a58")],
		["● 墨", Color("#649be8")],
		["● 中立", Color("#dfcaa7")]
	] if n_count <= 5 else [
		["● 笔", Color("#eb6a58")],
		["● 墨", Color("#649be8")],
		["● 砚", Color("#47c79c")],
		["● 纸", Color("#f2b646")],
		["● 中立", Color("#dfcaa7")]
	]
	for t in tags:
		var l := _label(str(t[0]), 11, t[1])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legend_hbox.add_child(l)

# 构建 S01 底部导航栏（P0: 贴底通栏半透明条）
func _build_bottom_dock() -> void:
	bottom_dock = Panel.new()
	bottom_dock.position = Vector2(0, size.y - 60)
	bottom_dock.size = Vector2(size.x, 60)
	bottom_dock.add_theme_stylebox_override("panel", _style(Color(0.12, 0.09, 0.07, 0.90), Color(0.81, 0.51, 0.15, 0.7), 1, 0))
	bottom_dock.z_index = 5
	game_layer.add_child(bottom_dock)

	dock_row = HBoxContainer.new()
	dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_row.add_theme_constant_override("separation", 8)
	bottom_dock.add_child(dock_row)

	_add_dock_tab(dock_row, "S01_MAP", "🗺️", "沙盘地图", func(): _navigate_to("S01_MAP"))
	_add_dock_tab(dock_row, "S03_ARMY", "⚔️", "军团编成", func(): _open_army_page())
	_add_dock_tab(dock_row, "S04_REPORT", "📜", "战争日报", func(): _open_report())
	_add_dock_tab(dock_row, "S02_CITY_HUB", "🏡", "文房小院", func(): _open_estate_page())
	_add_dock_tab(dock_row, "S10_SEASON", "🏆", "赛季史书", func(): _open_season_page())

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

# 抽屉显示状态（打开时不隐藏手牌栏，720×514 下抽屉浮于右上、手牌贴底常驻）
func _toggle_city_drawer(is_show: bool) -> void:
	is_drawer_open = is_show
	if city_drawer == null:
		if not is_show and _forecast_debounce_timer != null:
			_forecast_debounce_timer.stop()
		return
	var is_compact_h := size.y < 650.0
	var is_phone := size.x < 900.0 or is_compact_h
	var dock_h := 46.0 if is_compact_h else (56.0 if is_phone else 60.0)
	if is_instance_valid(drawer_tween) and drawer_tween.is_running():
		drawer_tween.kill()

	if is_show:
		city_drawer.visible = true
		city_drawer.modulate.a = 1.0
		if legend_panel != null and is_compact_h:
			legend_panel.visible = false
		if right_rail != null and is_compact_h:
			right_rail.visible = false
		if hand_cards_bar != null and current_page == "S01_MAP":
			hand_cards_bar.visible = true
		_layout_responsive()
		if not AudioManager.is_reduced_motion:
			var target_y := city_drawer.position.y
			city_drawer.position.y = target_y + 16.0
			city_drawer.modulate.a = 0.0
			drawer_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			drawer_tween.tween_property(city_drawer, "position:y", target_y, 0.20)
			drawer_tween.tween_property(city_drawer, "modulate:a", 1.0, 0.18)
	else:
		_forecast_req_seq += 1
		if _forecast_debounce_timer != null:
			_forecast_debounce_timer.stop()
		if legend_panel != null:
			legend_panel.visible = true
		if right_rail != null:
			right_rail.visible = true
		if hand_cards_bar != null and current_page == "S01_MAP":
			hand_cards_bar.visible = true
		_layout_responsive()
		if AudioManager.is_reduced_motion:
			city_drawer.visible = false
			city_drawer.modulate.a = 1.0
		else:
			if bottom_dock != null and current_page in DOCK_PAGES:
				if is_instance_valid(dock_tween) and dock_tween.is_running():
					dock_tween.kill()
				dock_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				dock_tween.tween_property(bottom_dock, "position:y", size.y - dock_h, 0.16)
			drawer_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			drawer_tween.tween_property(city_drawer, "modulate:a", 0.0, 0.14)
			drawer_tween.chain().tween_callback(func():
				if is_instance_valid(city_drawer):
					city_drawer.visible = false
					city_drawer.modulate.a = 1.0
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
	title_v.clip_contents = true
	h_top.add_child(title_v)

	var row_name := HBoxContainer.new()
	row_name.add_theme_constant_override("separation", 4)
	title_v.add_child(row_name)

	city_title_label = _label("【据点名称】", 15, GOLD_LIGHT)
	row_name.add_child(city_title_label)

	city_type_badge = _label("[要塞]", 11, GOLD)
	row_name.add_child(city_type_badge)

	city_faction_badge = _label("归属：中立", 11, Color("#d5c4a1"))
	city_faction_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_faction_badge.clip_text = true
	city_faction_badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row_name.add_child(city_faction_badge)

	city_governor_badge = _label("", 11, Color("#fae19c"))
	city_governor_badge.visible = false
	row_name.add_child(city_governor_badge)

	# 右上角小“传”文脉按钮与关闭
	var top_btns := HBoxContainer.new()
	top_btns.add_theme_constant_override("separation", 4)
	h_top.add_child(top_btns)

	var lore_btn := Button.new()
	lore_btn.text = "📜传"
	lore_btn.tooltip_text = "查看城池文脉与小传"
	lore_btn.custom_minimum_size = Vector2(40, 30)
	lore_btn.add_theme_font_size_override("font_size", 12)
	lore_btn.add_theme_color_override("font_color", GOLD_LIGHT)
	lore_btn.add_theme_stylebox_override("normal", _style(Color("#2d2218", 0.9), GOLD, 1, 6, 3))
	lore_btn.pressed.connect(_open_city_lore_dialog)
	top_btns.add_child(lore_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, Color("#baa789"), 1, 15))
	close_btn.pressed.connect(func(): _toggle_city_drawer(false))
	top_btns.add_child(close_btn)

	# 2. 中部可滚动内容区：城情/驰道 + ⚔️ 战前军议预估折叠卡
	city_drawer_scroll = ScrollContainer.new()
	city_drawer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	city_drawer_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(city_drawer_scroll)

	var scroll_body := VBoxContainer.new()
	scroll_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_body.add_theme_constant_override("separation", 6)
	city_drawer_scroll.add_child(scroll_body)

	var info_box := PanelContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 6, 8))
	scroll_body.add_child(info_box)

	var info_v := VBoxContainer.new()
	info_v.add_theme_constant_override("separation", 2)
	info_box.add_child(info_v)

	var def_top := HBoxContainer.new()
	def_top.add_theme_constant_override("separation", 8)
	info_v.add_child(def_top)
	city_def_badge = _label("🛡️ 守备：3 / 3", 12, C_ZHUSHA)
	def_top.add_child(city_def_badge)
	city_morale_badge = _label("❤️ 民心：0 / 2", 12, C_TENGHUANG)
	city_morale_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	def_top.add_child(city_morale_badge)

	city_garrison_label = _label("👥 守军状态：待踏勘", 11, Color("#5a4a3a"))
	city_garrison_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_v.add_child(city_garrison_label)

	city_routes_label = _label("🗺️ 连通驰道：--", 12, C_WOOD_DESK)
	city_routes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_v.add_child(city_routes_label)

	city_order_hint = _label("📢 每天最多出 3 令 · 点击下方手牌向此城出令", 11, C_MOLAN)
	city_order_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_v.add_child(city_order_hint)

	city_power_diff_label = _label("", 11, Color("#554433"))
	city_power_diff_label.visible = false
	info_v.add_child(city_power_diff_label)
	city_tactical_label = _label("", 11, Color("#665544"))
	city_tactical_label.visible = false
	info_v.add_child(city_tactical_label)

	# 2.5 ⚔️ 战前军议预估折叠卡（首层 3 项，详情可展开）
	city_forecast_card = PanelContainer.new()
	city_forecast_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_forecast_card.add_theme_stylebox_override("panel", _panel_style(Color("#f8f2e6"), Color("#276f57"), 1, 6, 8))
	scroll_body.add_child(city_forecast_card)

	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 4)
	city_forecast_card.add_child(fv)

	var f_hdr := HBoxContainer.new()
	f_hdr.add_theme_constant_override("separation", 6)
	fv.add_child(f_hdr)

	var f_title := _label("⚔ 战前军议", 13, C_WOOD_DESK)
	f_hdr.add_child(f_title)

	city_forecast_badge = _label("测算中", 11, Color("#ffffff"))
	var badge_wrap := PanelContainer.new()
	badge_wrap.add_theme_stylebox_override("panel", _style(Color("#5a4d3f"), Color.TRANSPARENT, 0, 4, 2))
	badge_wrap.add_child(city_forecast_badge)
	f_hdr.add_child(badge_wrap)

	var f_sp := Control.new()
	f_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f_hdr.add_child(f_sp)

	city_forecast_toggle_btn = Button.new()
	city_forecast_toggle_btn.text = "展开详情 ▾"
	city_forecast_toggle_btn.custom_minimum_size = Vector2(78, 24)
	city_forecast_toggle_btn.add_theme_font_size_override("font_size", 11)
	city_forecast_toggle_btn.add_theme_color_override("font_color", C_MOLAN)
	city_forecast_toggle_btn.add_theme_stylebox_override("normal", _style(Color("#efe4d0"), Color("#c9b08a"), 1, 4, 2))
	city_forecast_toggle_btn.pressed.connect(_on_forecast_toggle_pressed)
	f_hdr.add_child(city_forecast_toggle_btn)

	city_forecast_summary_lbl = _label("测算中...", 12, C_WOOD_DESK)
	city_forecast_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fv.add_child(city_forecast_summary_lbl)

	city_forecast_detail_box = VBoxContainer.new()
	city_forecast_detail_box.add_theme_constant_override("separation", 3)
	city_forecast_detail_box.visible = false
	fv.add_child(city_forecast_detail_box)

	city_forecast_detail_box.add_child(HSeparator.new())
	city_forecast_detail_lbl = _label("", 11, Color("#3e3126"))
	city_forecast_detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	city_forecast_detail_box.add_child(city_forecast_detail_lbl)

	city_forecast_advice_lbl = _label("", 11, C_ZHUQING)
	city_forecast_advice_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	city_forecast_detail_box.add_child(city_forecast_advice_lbl)

	city_forecast_footer_lbl = _label("预估不消耗令", 10, Color("#7c6c5b"))
	city_forecast_footer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fv.add_child(city_forecast_footer_lbl)

	# 3. 动作操作栏（统一引导走手牌出令：只保留 [去手牌出令] 与 [哨探军报]）
	var h_act := HBoxContainer.new()
	h_act.add_theme_constant_override("separation", 8)
	v.add_child(h_act)

	city_action_advance_btn = _button("🎴 去手牌出令", C_ZHUSHA, 40)
	city_action_advance_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_action_advance_btn.pressed.connect(_on_city_advance_pressed)
	h_act.add_child(city_action_advance_btn)

	city_action_scout_btn = _button("🔍 哨探军报", Color("#2c4a5e"), 40)
	city_action_scout_btn.custom_minimum_size = Vector2(96, 40)
	city_action_scout_btn.add_theme_font_size_override("font_size", 13)
	city_action_scout_btn.pressed.connect(func(): _open_city_intel_dialog(selected_code))
	city_action_scout_btn.visible = false
	h_act.add_child(city_action_scout_btn)

	city_action_battle_btn = Button.new()
	city_action_battle_btn.visible = false

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
		var col_hex := str(owner.get("color", ""))
		if col_hex != "" and Color.html_is_valid(col_hex):
			owner_color = Color.from_string(col_hex, NEUTRAL)
		else:
			var code_str := str(owner.get("code", ""))
			if code_str == "bamboo" or code_str == "bi":
				owner_color = C_ZHUSHA
			elif code_str == "ink" or code_str == "mo":
				owner_color = C_MOLAN
			elif code_str == "crimson" or code_str == "yan" or code_str == "shuang":
				owner_color = C_ZHUQING
			elif code_str == "azure" or code_str == "zhi" or code_str == "dan":
				owner_color = C_TENGHUANG
		
	var is_scouted: bool = scouted_nodes.has(code)
	if is_scouted:
		city_title_label.text = "【%s】 👁 已侦察" % c_name
	else:
		city_title_label.text = "【%s】" % c_name
	city_type_badge.text = "[主营大本营]" if is_start else "[要冲关隘]"
	city_faction_badge.text = "归属：%s" % owner_name
	if city_governor_badge != null:
		var gov_val: Variant = n.get("governor", null)
		if typeof(gov_val) == TYPE_DICTIONARY and str(gov_val.get("nickname", "")) != "":
			city_governor_badge.text = "· ⚑ 太守：%s" % str(gov_val.get("nickname", ""))
			city_governor_badge.visible = true
		else:
			city_governor_badge.visible = false
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
	elif is_scouted:
		city_garrison_label.text = "👁 已侦察 · 敌军虚实皆明 (可查阅哨探情报)"
	elif typeof(owner) == TYPE_DICTIONARY and str(owner.get("code", "")) != "" and str(owner.get("code", "")) != "neutral":
		city_garrison_label.text = "👥 守军兵力：虚实未知 (未侦察·须出哨探)"
	else:
		city_garrison_label.text = "👥 守军兵力：虚实未知 (中立关塞·须出哨探)"

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
		_:
			var nd: Dictionary = map.node_by_code(code)
			if nd.has("tag") and nd.has("verse"):
				lore = "%s · %s" % [str(nd.get("tag", "")), str(nd.get("verse", ""))]
			else:
				lore = "山河要冲，兵家必争。"
	city_lore_label.text = "城池小传：" + lore
	if city_lore_dialog != null:
		city_lore_dialog.title = "【%s】城池文脉与小传" % c_name

	var role := str(me.get("role", "player"))
	var can_edit := bool(state.get("can_edit", false)) and role == "player"
	var cur_week := _current_week()
	var is_king := _is_king_node(code, n)

	var card_orders_list: Array = state.get("card_orders", []) if typeof(state.get("card_orders", null)) == TYPE_ARRAY else []
	var city_orders_cnt := 0
	var has_scout_on_city := false
	for ord in card_orders_list:
		if typeof(ord) == TYPE_DICTIONARY and str(ord.get("target_node_code", "")) == code:
			city_orders_cnt += 1
			if str(ord.get("card_code", "")) == "scout":
				has_scout_on_city = true

	if is_mine:
		city_action_advance_btn.text = "🛡️ 去手牌驻守"
		city_action_advance_btn.tooltip_text = "每天最多出 3 令 · 点击下方手牌向己方据点出令驻守"
		city_action_advance_btn.disabled = not can_edit
	else:
		city_action_advance_btn.text = "🎴 去手牌出令"
		city_action_advance_btn.tooltip_text = "每天最多出 3 令 · 点击下方手牌（牌+城+路+前后排）出征"
		city_action_advance_btn.disabled = not can_edit

	# 长安王城、决战周与迷雾可达性判定
	if is_king and cur_week < 3:
		city_action_advance_btn.disabled = true
		city_action_advance_btn.text = "🔒 第 3 周开放"
		city_action_advance_btn.tooltip_text = "中央帝都长安第 3 周开放，前两周专注于开拓四野"
	elif cur_week >= 4 and not _is_changan_or_neighbor(code):
		city_action_advance_btn.disabled = true
		city_action_advance_btn.text = "🔒 决战周限长安及邻城"
		city_action_advance_btn.tooltip_text = "第 4 周决战周已至，诸军仅可会战长安及邻近要冲！"
	elif not is_mine and not reachable_targets.is_empty() and not reachable_targets.has(code):
		city_action_advance_btn.disabled = true
		city_action_advance_btn.text = "🔒 不与己方领土相邻"
		city_action_advance_btn.tooltip_text = "该据点关河阻隔，尚未与我方领土接壤，无法出令进军！"

	var used_cnt := card_orders_list.size()
	if city_orders_cnt > 0:
		city_order_hint.text = "📢 本城已派 %d 令（今日共 %d / 3 令，每天最多出 3 令）" % [city_orders_cnt, used_cnt]
	elif is_mine:
		city_order_hint.text = "📢 己方据点（今日 %d / 3 令）· 点下方手牌出令即驻守" % used_cnt
	else:
		city_order_hint.text = "📢 待出征（今日 %d / 3 令 · 每天最多出 3 令）· 点下方手牌" % used_cnt

	var can_see_intel: bool = has_scout_on_city or is_scouted
	if city_action_scout_btn != null:
		city_action_scout_btn.visible = can_see_intel
		if can_see_intel:
			city_action_scout_btn.text = "👁 哨探情报 (已侦察)" if is_scouted else "🔍 哨探军报"
			city_action_scout_btn.tooltip_text = "点击查阅哨探刺探到的该城敌军军情与集结动向"

	if not has_scout_on_city and city_intel_dialog != null and city_intel_dialog.visible:
		city_intel_dialog.hide()

	_render_hand_cards(false)
	_toggle_city_drawer(true)
	focus_city(code)
	_request_city_forecast(code)
	if tutorial_step == 1:
		_advance_tutorial(2)

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
	var tgt_name := str(map.node_by_code(selected_code).get("name", selected_code))
	if hand_cards_bar != null:
		if hand_bar_collapsed:
			hand_bar_collapsed = false
			_toggle_hand_bar_collapse()
		hand_cards_bar.visible = true
		_shake_node(hand_cards_bar)
	_toast("每天最多出 3 令 · 点击下方【每日将令】即可向【%s】出令！" % tgt_name)

# ---------------------------------------------------------------------------
# S01 战前军议折叠卡：POST /api/slice/battle/forecast 与 300ms 去抖重算
# ---------------------------------------------------------------------------

func _on_forecast_toggle_pressed() -> void:
	city_forecast_expanded = not city_forecast_expanded
	_apply_forecast_expand_state()
	_layout_responsive()

func _apply_forecast_expand_state() -> void:
	if city_forecast_detail_box == null or city_forecast_toggle_btn == null:
		return
	var can_expand := (
		not _last_forecast_loading
		and _last_forecast_err == ""
		and bool(_last_forecast_data.get("ready", false))
		and str(_last_forecast_data.get("role", "attack")) != "defend"
		and str(_last_forecast_data.get("reason", "")) != "DEFEND_CITY"
	)
	city_forecast_toggle_btn.visible = can_expand
	if can_expand:
		city_forecast_detail_box.visible = city_forecast_expanded
		city_forecast_toggle_btn.text = "收起详情 ▴" if city_forecast_expanded else "展开详情 ▾"
	else:
		city_forecast_detail_box.visible = false

func _schedule_forecast_recalc() -> void:
	if not is_drawer_open or selected_code == "" or _forecast_debounce_timer == null:
		return
	_forecast_debounce_timer.stop()
	_forecast_debounce_timer.start(0.30)

func _on_forecast_debounce_timeout() -> void:
	if is_drawer_open and selected_code != "":
		_request_city_forecast(selected_code)

func _request_city_forecast(node_code: String) -> void:
	if api == null or api.token == "" or node_code == "" or _turn_id() <= 0:
		return
	if _forecast_debounce_timer != null:
		_forecast_debounce_timer.stop()
	_forecast_req_seq += 1
	var seq := _forecast_req_seq
	_last_forecast_node = node_code
	_last_forecast_loading = true
	_last_forecast_err = ""
	_render_city_forecast(node_code, {}, "", true)

	api.battle_forecast(_turn_id(), node_code, func(ok: bool, data: Dictionary, err: Dictionary):
		if seq != _forecast_req_seq or selected_code != node_code or not is_drawer_open:
			return
		_last_forecast_loading = false
		if not ok:
			_last_forecast_data = {}
			_last_forecast_err = str(err.get("message", "暂时无法预估"))
			_render_city_forecast(node_code, {}, _last_forecast_err, false)
			return
		_last_forecast_err = ""
		_last_forecast_data = data.duplicate(true)
		_render_city_forecast(node_code, data, "", false)
	)

func _render_city_forecast(node_code: String, data: Dictionary, err_msg: String, is_loading: bool) -> void:
	if city_forecast_card == null:
		return
	var n: Dictionary = map.node_by_code(node_code)
	var is_mine := bool(n.get("is_my_faction", false))

	var badge_panel := city_forecast_badge.get_parent() as PanelContainer
	var set_badge := func(txt: String, col: Color):
		city_forecast_badge.text = txt
		if badge_panel != null:
			badge_panel.add_theme_stylebox_override("panel", _style(col, Color.TRANSPARENT, 0, 4, 2))

	if is_loading:
		set_badge.call("测算中", Color("#5a4d3f"))
		city_forecast_summary_lbl.text = "正在研判战前态势..."
		_apply_forecast_expand_state()
		return

	if err_msg != "" or data.is_empty():
		set_badge.call("暂不可用", Color("#6b5747"))
		city_forecast_summary_lbl.text = "暂时无法预估"
		_apply_forecast_expand_state()
		return

	var role := str(data.get("role", "attack"))
	var ready := bool(data.get("ready", false))
	var reason := str(data.get("reason", ""))

	# 己方城红线：绝对不显示进攻预估
	if is_mine or role == "defend" or reason == "DEFEND_CITY":
		set_badge.call("驻守", C_MOLAN)
		city_forecast_summary_lbl.text = "本令做什么：驻守己方城池（取驻守令前 3 名迎战）
最大风险：无驻守令将回落固定守军
结果方向：固守待援 · 这是己方城，出令 = 驻守"
		_apply_forecast_expand_state()
		return

	if not ready:
		set_badge.call("待出令", Color("#7c5c26"))
		if reason == "NO_VANGUARD":
			city_forecast_summary_lbl.text = "本令做什么：请先出一张队伍牌（火攻/侦察/疑兵不占先锋位）
最大风险：当前缺少主力队伍进战
结果方向：尚缺先锋队伍，暂未形成推演预估"
		else:
			city_forecast_summary_lbl.text = "本令做什么：先从下方手牌选一张牌指向此城
最大风险：尚未下达进攻将令
结果方向：待出令后自动预测破墙与战果"
		_apply_forecast_expand_state()
		return

	# ready == true 且非己方城
	var intel_known := bool(data.get("intel_known", false))
	var fc: Dictionary = data.get("forecast", {}) if typeof(data.get("forecast", null)) == TYPE_DICTIONARY else {}
	var att: Dictionary = data.get("attacker", {}) if typeof(data.get("attacker", null)) == TYPE_DICTIONARY else {}
	var defn: Dictionary = data.get("defender", {}) if typeof(data.get("defender", null)) == TYPE_DICTIONARY else {}

	var att_teams_cnt := (att.get("teams", []) as Array).size() if typeof(att.get("teams", null)) == TYPE_ARRAY else 0
	var sup_cnt := int(att.get("supporters", 0))
	var att_troops := int(round(float(att.get("troops", 0.0))))

	var what_line := "本令做什么：攻城夺关（我方 %d 队先锋" % maxi(1, att_teams_cnt)
	if sup_cnt > 0:
		what_line += " + %d 支援" % sup_cnt
	what_line += "）"

	var risk_line := ""
	var dir_line := ""
	var verdict := str(fc.get("verdict", "均势"))

	if not intel_known:
		# 红线：未侦察不显示精确守军与确定战果，也不泄露 defender.teams
		set_badge.call("未侦察", C_TENGHUANG)
		risk_line = "最大风险：守军未侦察，兵力与布阵未知"
		dir_line = "结果方向：情报不明（建议先派哨探侦察再决断）"
		var r_arr: Variant = defn.get("troops_range", [])
		var range_txt := "未知"
		if typeof(r_arr) == TYPE_ARRAY and r_arr.size() >= 2:
			range_txt = "%d–%d" % [int(r_arr[0]), int(r_arr[1])]
		city_forecast_detail_lbl.text = "攻方集结：约 %d 兵
守军估测：%s 兵（未侦察 · 不展示敌军编成）
破墙/易主：未侦察暂不给出确定战果" % [att_troops, range_txt]
	else:
		var badge_col := C_ZHUQING if verdict == "优势" else (C_TENGHUANG if verdict == "均势" else C_ZHUSHA)
		set_badge.call(verdict, badge_col)

		var def_troops := int(round(float(defn.get("troops", 0.0))))
		var wall_base := clampf(float(fc.get("wall_base", 1650.0)), 1.0, 99999.0)
		var wall_rem := clampf(float(fc.get("wall", wall_base)), 0.0, wall_base)
		var wall_broken := clampf(wall_base - wall_rem, 0.0, wall_base)
		var wall_pct := int(round(wall_broken / wall_base * 100.0))
		var m_before := int(fc.get("morale_before", 0))
		var m_after := int(fc.get("morale_after", 0))
		var m_cap := int(fc.get("morale_cap", 2))
		var will_cap := bool(fc.get("capture_estimate", false))

		if att_troops < def_troops:
			risk_line = "最大风险：我方兵力不足（攻 %d < 守 %d）" % [att_troops, def_troops]
		elif wall_rem > wall_base * 0.5:
			risk_line = "最大风险：城防未半，破墙推进偏慢"
		elif not will_cap:
			risk_line = "最大风险：本回合民心尚难一举破城（%d→%d/%d）" % [m_before, m_after, m_cap]
		else:
			risk_line = "最大风险：敌可能临战增兵，留意 21:00 前动向"

		if verdict == "优势":
			dir_line = "结果方向：%s" % ("有望破城易主！" if will_cap else "有望破墙占优")
		elif verdict == "劣势":
			dir_line = "结果方向：兵力处劣势（建议增兵或改途）"
		else:
			dir_line = "结果方向：势均力敌（均势相持）"

		var counters_dict: Dictionary = data.get("counters", {}) if typeof(data.get("counters", null)) == TYPE_DICTIONARY else {}
		var c_parts: Array[String] = []
		var c_names := {"cav": "骑", "shield": "盾", "arc": "弓", "spear": "枪"}
		for ck in counters_dict.keys():
			var cnt := int(counters_dict[ck])
			if cnt <= 0:
				continue
			var sp := str(ck).split(">")
			if sp.size() == 2:
				c_parts.append("%s克%s ×%d" % [c_names.get(sp[0], sp[0]), c_names.get(sp[1], sp[1]), cnt])
		var counter_str := "克制：%s" % ("、".join(c_parts) if not c_parts.is_empty() else "无明显克制差")

		city_forecast_detail_lbl.text = "攻 %d · 守 %d
破墙 %d / %d（%d%%）
民心 %d → %d / %d，%s
%s" % [
			att_troops, def_troops,
			int(round(wall_broken)), int(round(wall_base)), wall_pct,
			m_before, m_after, m_cap,
			"本回合有望易主" if will_cap else "本回合不会易主",
			counter_str
		]

	city_forecast_summary_lbl.text = "%s
%s
%s" % [what_line, risk_line, dir_line]

	var adv_arr: Variant = data.get("advice", [])
	var adv_lines: Array[String] = []
	if typeof(adv_arr) == TYPE_ARRAY:
		for item in adv_arr:
			var s := _normalize_balance_copy(str(item).strip_edges())
			if s != "":
				adv_lines.append("· " + s)
	city_forecast_advice_lbl.text = "
".join(adv_lines)
	city_forecast_advice_lbl.visible = not adv_lines.is_empty()
	_apply_forecast_expand_state()
	_layout_responsive()

func _normalize_balance_copy(txt: String) -> String:
	var out := txt
	out = out.replace("每人 +2%，上限 +30%", "每人 +2%，上限 +15%")
	out = out.replace("每人+2%，上限+30%", "每人 +2%，上限 +15%")
	out = out.replace("每人 +2%, 上限 +30%", "每人 +2%，上限 +15%")
	out = out.replace("支援 +30%", "每人 +2%，上限 +15%").replace("支援+30%", "每人 +2%，上限 +15%")
	out = out.replace("上限 +30%", "每人 +2%，上限 +15%").replace("上限+30%", "每人 +2%，上限 +15%")
	out = out.replace("支援 30%", "支援 15%").replace("支援30%", "支援15%")
	out = out.replace("器械攻墙 +50%", "器械攻墙 +60%").replace("器械攻墙+50%", "器械攻墙+60%")
	return out

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
	v.add_theme_constant_override("separation", 8)
	report_margin.add_child(v)

	# 0. 子页切换：战报与四榜 | 战局回放（替代原独立第 5 Tab）
	var sub_tab_row := HBoxContainer.new()
	sub_tab_row.add_theme_constant_override("separation", 8)
	v.add_child(sub_tab_row)

	report_tab_daily_btn = _button("📜 个人与诸军战报", C_ZHUSHA, 34)
	report_tab_daily_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_tab_daily_btn.pressed.connect(func(): _switch_report_subtab("daily"))
	sub_tab_row.add_child(report_tab_daily_btn)

	report_tab_replay_btn = _button("🔄 战局沙盘回放", Color("#3b2f26"), 34)
	report_tab_replay_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_tab_replay_btn.pressed.connect(_open_replay)
	sub_tab_row.add_child(report_tab_replay_btn)

	# A. 战报子页
	report_daily_box = VBoxContainer.new()
	report_daily_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_daily_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_daily_box.add_theme_constant_override("separation", 8)
	v.add_child(report_daily_box)

	# 1. 顶部决战头条 Banner（C 宣纸纸卡 + 金边）
	report_headline_panel = PanelContainer.new()
	report_headline_panel.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, C_TENGHUANG, 2, 10, 12))
	report_daily_box.add_child(report_headline_panel)

	var hl_v := VBoxContainer.new()
	hl_v.add_theme_constant_override("separation", 4)
	report_headline_panel.add_child(hl_v)

	var hl_row := HBoxContainer.new()
	hl_row.add_theme_constant_override("separation", 10)
	hl_v.add_child(hl_row)

	report_seal_rect = TextureRect.new()
	report_seal_rect.custom_minimum_size = Vector2(38, 38)
	report_seal_rect.size = Vector2(38, 38)
	report_seal_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	report_seal_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	report_seal_rect.visible = false
	hl_row.add_child(report_seal_rect)

	report_headline_lbl = _label("【决战头条】九州第一候推演决战备战中", 17, C_WOOD_DESK)
	report_headline_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl_row.add_child(report_headline_lbl)

	report_time_lbl = _label("推演时点：今夜 21:00 准时结算", 12, Color("#685848"))
	hl_v.add_child(report_time_lbl)

	# 2. 四大板块（个人战报 + 诸军四榜 + 天下大势 + 诸军战况）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_daily_box.add_child(scroll)

	var scroll_v := VBoxContainer.new()
	scroll_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_v.add_theme_constant_override("separation", 10)
	scroll.add_child(scroll_v)

	# 板块 1：个人战报（首屏先给真实行动 + 军功 + 小院直通，明细收进展开区）
	report_my_text = _build_report_card(scroll_v, "◆ 个人战报")
	report_text = report_my_text
	var my_card_v := report_my_text.get_parent()
	report_my_card = my_card_v.get_parent() as PanelContainer

	report_me_expand_btn = Button.new()
	report_me_expand_btn.text = "展开每令伤害与明细 ▾"
	report_me_expand_btn.custom_minimum_size = Vector2(160, 28)
	report_me_expand_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	report_me_expand_btn.add_theme_font_size_override("font_size", 11)
	report_me_expand_btn.add_theme_color_override("font_color", C_MOLAN)
	report_me_expand_btn.add_theme_stylebox_override("normal", _style(Color("#efe4d0"), Color("#c9b08a"), 1, 5, 4))
	report_me_expand_btn.visible = false
	report_me_expand_btn.pressed.connect(func():
		report_me_expanded = not report_me_expanded
		if report_me_detail_text != null:
			report_me_detail_text.visible = report_me_expanded
		report_me_expand_btn.text = "收起每令明细 ▴" if report_me_expanded else "展开每令伤害与明细 ▾"
	)
	my_card_v.add_child(report_me_expand_btn)

	report_me_detail_text = RichTextLabel.new()
	report_me_detail_text.bbcode_enabled = true
	report_me_detail_text.fit_content = true
	report_me_detail_text.scroll_active = false
	report_me_detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_me_detail_text.add_theme_font_size_override("normal_font_size", 12)
	report_me_detail_text.add_theme_color_override("default_color", Color("#4d3f32"))
	report_me_detail_text.visible = false
	my_card_v.add_child(report_me_detail_text)

	var es_sep := HSeparator.new()
	my_card_v.add_child(es_sep)
	report_estate_row = HBoxContainer.new()
	report_estate_row.add_theme_constant_override("separation", 10)
	my_card_v.add_child(report_estate_row)
	report_estate_lbl = _label("🏡 小院 +0 军功", 13, Color("#8c3a32"))
	report_estate_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_estate_row.add_child(report_estate_lbl)
	report_estate_btn = _button("去看看", C_ZHUQING, 32)
	report_estate_btn.custom_minimum_size = Vector2(92, 32)
	report_estate_btn.add_theme_font_size_override("font_size", 12)
	report_estate_btn.pressed.connect(func(): _open_estate_page(true))
	report_estate_row.add_child(report_estate_btn)

	# 板块 2：诸军四榜（先锋 / 支援 / 侦察 / 守城）
	report_boards_text = _build_report_card(scroll_v, "◆ 诸军四榜（先锋 / 支援 / 侦察 / 守城）")

	# 板块 3：全域城池易帜与据点布防
	report_world_text = _build_report_card(scroll_v, "◆ 天下大势与关隘城池易帜")

	# 板块 4：诸军战况与下候军略备忘
	report_summary_text = _build_report_card(scroll_v, "◆ 诸军战功交锋与下候备忘")

	# B. 嵌入的战局回放子页（原 S05 并入 S04，保留 replay_dialog 兼容 ReplaySmoke）
	report_replay_box = VBoxContainer.new()
	report_replay_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_replay_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_replay_box.add_theme_constant_override("separation", 8)
	report_replay_box.visible = false
	v.add_child(report_replay_box)
	replay_page = report_replay_box
	replay_dialog = report_replay_box

	var r_row := HBoxContainer.new()
	r_row.add_theme_constant_override("separation", 10)
	report_replay_box.add_child(r_row)

	r_row.add_child(_label("回放回合：", 14, GOLD_LIGHT))
	replay_turn_select = OptionButton.new()
	replay_turn_select.custom_minimum_size = Vector2(150, 36)
	replay_turn_select.add_theme_stylebox_override("normal", _style(C_XUANZHI, Color("#c9baa7"), 1, 7, 8))
	replay_turn_select.add_theme_color_override("font_color", C_WOOD_DESK)
	replay_turn_select.item_selected.connect(_render_replay_turn)
	r_row.add_child(replay_turn_select)

	prev_turn_btn = _button("◀ 上一候", C_MOLAN, 36)
	prev_turn_btn.custom_minimum_size = Vector2(84, 36)
	prev_turn_btn.pressed.connect(_step_replay.bind(-1))
	r_row.add_child(prev_turn_btn)

	next_turn_btn = _button("下一候 ▶", C_MOLAN, 36)
	next_turn_btn.custom_minimum_size = Vector2(84, 36)
	next_turn_btn.pressed.connect(_step_replay.bind(1))
	r_row.add_child(next_turn_btn)

	replay_time_lbl = _label("推演时点：--", 12, Color("#d5c4a1"))
	replay_time_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_row.add_child(replay_time_lbl)

	replay_map = ReplayMapScript.new()
	replay_map.custom_minimum_size = Vector2(0, 300)
	replay_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_replay_box.add_child(replay_map)

	var text_panel := PanelContainer.new()
	text_panel.custom_minimum_size = Vector2(0, 140)
	text_panel.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 10, 12))
	report_replay_box.add_child(text_panel)

	replay_text = RichTextLabel.new()
	replay_text.bbcode_enabled = true
	replay_text.scroll_active = true
	replay_text.add_theme_font_size_override("normal_font_size", 13)
	replay_text.add_theme_color_override("default_color", C_WOOD_DESK)
	text_panel.add_child(replay_text)

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

func _switch_report_subtab(tab: String) -> void:
	_active_report_subtab = tab
	var is_daily := (tab != "replay")
	if report_daily_box != null:
		report_daily_box.visible = is_daily
	if report_replay_box != null:
		report_replay_box.visible = not is_daily
	if report_tab_daily_btn != null:
		report_tab_daily_btn.add_theme_stylebox_override("normal", _style(C_ZHUSHA if is_daily else Color("#3b2f26"), GOLD_LIGHT if is_daily else Color("#6e5a44"), 1, 6, 4))
	if report_tab_replay_btn != null:
		report_tab_replay_btn.add_theme_stylebox_override("normal", _style(C_ZHUSHA if not is_daily else Color("#3b2f26"), GOLD_LIGHT if not is_daily else Color("#6e5a44"), 1, 6, 4))

func _open_report() -> void:
	_switch_report_subtab("daily")
	var last_rep: Variant = state.get("last_report", null)
	var target_turn_id := 0
	if typeof(last_rep) == TYPE_DICTIONARY:
		target_turn_id = int(last_rep.get("turn_id", 0))
	if target_turn_id <= 0:
		if str(state.get("turn", {}).get("status", "")) == "settled":
			target_turn_id = int(state.get("turn", {}).get("id", 0))

	if target_turn_id > 0:
		action_status.text = "正在展开第 %d 候战事日报..." % target_turn_id
		api.report(target_turn_id, func(ok: bool, data: Dictionary, _err: Dictionary):
			if not ok:
				_render_in_progress_report()
				_navigate_to("S04_REPORT")
				return
			var finish_open := func(payload: Dictionary):
				last_report_turn_id = target_turn_id
				_show_report(payload)
				_navigate_to("S04_REPORT")
				if api.token != "":
					api.get_merit(func(mok: bool, mdata: Dictionary, _merr: Dictionary):
						if not mok or not is_instance_valid(self):
							return
						cached_merit_payload = mdata.duplicate(true)
						var m_me: Variant = mdata.get("me", {})
						if typeof(m_me) == TYPE_DICTIONARY and not m_me.is_empty():
							merit_summary_data = m_me.duplicate(true)
						if current_page == "S04_REPORT" and last_report_turn_id == target_turn_id:
							_show_report(last_report_payload)
					)
			var me_rep_v: Variant = data.get("me_report", null)
			if typeof(me_rep_v) != TYPE_DICTIONARY or me_rep_v.is_empty():
				api.get_me_report(target_turn_id, func(mok: bool, mdata: Dictionary, _merr: Dictionary):
					var merged := data.duplicate(true)
					if mok and not mdata.is_empty():
						merged["me_report"] = mdata
					finish_open.call(merged)
				)
			else:
				finish_open.call(data)
		)
	else:
		last_report_turn_id = 0
		last_report_payload = {}
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
	var card_ords: Array = state.get("card_orders", []) if typeof(state.get("card_orders", null)) == TYPE_ARRAY else []
	var my_b := "[b]出征学子：[/b]%s | [b]出战灵宠：[/b]%s\n" % [p_name, pet_name]
	if not card_ords.is_empty():
		my_b += "[color=#b83b32]• 今日已签将令 %d / 3 令（每天最多出 3 令，21:00 锁令前可随时撤回）[/color]\n" % card_ords.size()
	else:
		my_b += "[color=#b83b32]• 当前军令状态：今日尚未出手牌！前往【沙盘】点城并轻触下方手牌出令（每天最多出 3 令）。[/color]\n"
	var cur_pts := int(wallet.get("available_points", 0))
	var cur_wenyu := int(wallet.get("jade_balance", wallet.get("jade", 0)))
	my_b += "• 可用学堂积分：%d 分 | 军备文玉：%d 枚（1 积分 = 10 文玉，每日限 20 积分）" % [cur_pts, cur_wenyu]
	if report_estate_lbl != null:
		report_estate_lbl.text = "🏡 文房小院 · 当前可用 %d 军功" % int(estate_data.get("merit_balance", 0))
	if report_me_expand_btn != null:
		report_me_expand_btn.visible = false
	if report_me_detail_text != null:
		report_me_detail_text.visible = false
	report_my_text.text = my_b
	if report_boards_text != null:
		report_boards_text.text = "[color=#685848]今夜 21:00 首候推演结算后，将自动张榜公布本周四榜（先锋 / 支援 / 侦察 / 守城）及全班榜首！[/color]"


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

const REPORT_ROLE_META := {
	"vanguard": {"icon": "⚔", "label": "先锋"},
	"support": {"icon": "🤝", "label": "支援"},
	"garrison": {"icon": "🛡", "label": "驻守"},
	"scout": {"icon": "🕵", "label": "侦察"},
	"fire": {"icon": "🔥", "label": "火攻"},
	"feint": {"icon": "🎭", "label": "疑兵"},
	"reserve": {"icon": "🏕", "label": "未接战"},
}

const REPORT_BULLETIN_NAMES := {
	"ram": "器械",
	"grain": "粮草",
	"scout": "斥候",
}

func _resolve_me_report(data: Dictionary) -> Dictionary:
	var mr: Variant = data.get("me_report", null)
	if typeof(mr) == TYPE_DICTIONARY and not mr.is_empty():
		return mr
	if data.has("orders") and data.has("merit"):
		return data
	return {}

func _extract_turn_merit(data: Dictionary, my_rep: Variant, me_rep: Dictionary) -> int:
	var mr_m: Variant = me_rep.get("merit", {})
	if typeof(mr_m) == TYPE_DICTIONARY and mr_m.has("turn_total"):
		return int(mr_m.get("turn_total", 0))
	if typeof(my_rep) == TYPE_DICTIONARY:
		var legacy_m: Variant = my_rep.get("merit", {})
		if typeof(legacy_m) == TYPE_DICTIONARY and legacy_m.has("turn_total"):
			return int(legacy_m.get("turn_total", 0))
	var top_m: Variant = data.get("merit", {})
	if typeof(top_m) == TYPE_DICTIONARY and top_m.has("turn_total"):
		return int(top_m.get("turn_total", 0))
	return 0

func _resolve_report_week_rank(data: Dictionary, me_rep: Dictionary) -> int:
	for src in [me_rep.get("merit", {}), data.get("merit", {}), merit_summary_data]:
		if typeof(src) == TYPE_DICTIONARY:
			var wr := int(src.get("week_rank", 0))
			if wr > 0:
				return wr
			var rk := int(src.get("rank", 0))
			if rk > 0:
				return rk
	return 0

func _resolve_report_bulletin_code(data: Dictionary, me_rep: Dictionary, turn_id: int) -> String:
	for raw in [me_rep.get("bulletin", null), data.get("bulletin", null)]:
		if typeof(raw) == TYPE_STRING and str(raw) != "":
			return str(raw)
		if typeof(raw) == TYPE_DICTIONARY:
			var cv: Variant = raw.get("choice", raw.get("code", ""))
			if typeof(cv) == TYPE_STRING and str(cv) != "":
				return str(cv)

	var my_pid := int(me.get("id", me.get("player_id", 0)))
	var rep_val: Variant = data.get("report", {})
	if my_pid > 0 and typeof(rep_val) == TYPE_DICTIONARY:
		var battles: Variant = rep_val.get("battles", [])
		if typeof(battles) == TYPE_ARRAY:
			for b in battles:
				if typeof(b) != TYPE_DICTIONARY:
					continue
				for team_key in ["teams", "defender_teams"]:
					var tlist: Variant = b.get(team_key, [])
					if typeof(tlist) != TYPE_ARRAY:
						continue
					for tm in tlist:
						if typeof(tm) != TYPE_DICTIONARY:
							continue
						if int(tm.get("player_id", 0)) == my_pid:
							var bc: Variant = tm.get("bulletin", "")
							if typeof(bc) == TYPE_STRING and str(bc) != "":
								return str(bc)

	var st_bul: Variant = state.get("bulletin", {})
	if typeof(st_bul) == TYPE_DICTIONARY:
		var st_tid := int(st_bul.get("turn_id", 0))
		if turn_id <= 0 or st_tid <= 0 or st_tid == turn_id:
			var sc: Variant = st_bul.get("choice", "")
			if typeof(sc) == TYPE_STRING:
				return str(sc)
	return ""

func _format_me_report_order(ord: Dictionary) -> Array[String]:
	var role_code := str(ord.get("role", ""))
	var rmeta: Dictionary = REPORT_ROLE_META.get(role_code, {
		"icon": "📜",
		"label": role_code if role_code != "" else "出征",
	})
	var node_label := str(ord.get("node_name", ord.get("node_code", "")))
	var contrib_pct := int(round(float(ord.get("contribution", 0.0)) * 100.0))
	var dmg := int(round(float(ord.get("damage", 0.0))))
	var wall_dmg := int(round(float(ord.get("wall_damage", 0.0))))
	var is_combat_role := role_code in ["vanguard", "garrison", "fire"]

	var out: Array[String] = []
	var head := "%s [b]%s[/b] · %s" % [str(rmeta["icon"]), node_label, str(rmeta["label"])]
	if role_code == "support":
		# 决策红线 §1.9：支援只显示“你给主攻 +2%”，不画成个人伤害
		head += " · 你给主攻 +2%（阵营协攻加成）"
		out.append(head)
		return out
	if contrib_pct > 0 or (is_combat_role and (dmg > 0 or wall_dmg > 0)):
		head += " · 贡献 %d%%（本场攻方伤害占比）" % contrib_pct
	out.append(head)
	if is_combat_role and (dmg > 0 or wall_dmg > 0):
		out.append("[color=#5a4a3a]   伤害 %d · 破墙 %d[/color]" % [dmg, wall_dmg])
	return out

func _build_me_report_bbcode(data: Dictionary, my_rep: Variant, me_rep: Dictionary, turn_id: int) -> String:
	var raw_orders: Variant = me_rep.get("orders", [])
	var mr_orders: Array = raw_orders if typeof(raw_orders) == TYPE_ARRAY else []
	var lines: Array[String] = []
	var hl_raw: Variant = me_rep.get("highlight", "")
	var mr_highlight := str(hl_raw).strip_edges() if hl_raw != null else ""

	if mr_highlight != "":
		lines.append("[b]我今天下了 %d 令[/b]  [color=#8c3a32]%s[/color]" % [mr_orders.size(), mr_highlight])
	else:
		lines.append("[b]我今天下了 %d 令[/b]" % mr_orders.size())

	if mr_orders.is_empty() and typeof(my_rep) == TYPE_DICTIONARY:
		var legacy_desc := str(my_rep.get("readable_text", "")).strip_edges()
		if legacy_desc != "":
			lines.append(legacy_desc)

	for ord_v in mr_orders:
		if typeof(ord_v) == TYPE_DICTIONARY:
			lines.append_array(_format_me_report_order(ord_v))

	var bul_code := _resolve_report_bulletin_code(data, me_rep, turn_id)
	var bul_name: String = str(REPORT_BULLETIN_NAMES.get(bul_code, ""))
	lines.append("🌾 邸报：%s" % (bul_name if bul_name != "" else "未选择"))

	var turn_merit := _extract_turn_merit(data, my_rep, me_rep)
	var week_rank := _resolve_report_week_rank(data, me_rep)
	if week_rank > 0:
		lines.append("[b][color=#8c3a32]军功 +%d · 本周第 %d[/color][/b]" % [turn_merit, week_rank])
	else:
		lines.append("[b][color=#8c3a32]军功 +%d[/color][/b]" % turn_merit)
	return "\n".join(lines)

func _build_me_report_detail_bbcode(me_rep: Dictionary) -> String:
	var raw_orders: Variant = me_rep.get("orders", [])
	var mr_orders: Array = raw_orders if typeof(raw_orders) == TYPE_ARRAY else []
	var out: Array[String] = []
	for ord_v in mr_orders:
		if typeof(ord_v) == TYPE_DICTIONARY:
			var lost := int(round(float(ord_v.get("troops_lost", 0.0))))
			var nname := str(ord_v.get("node_name", ord_v.get("node_code", "")))
			if lost > 0:
				out.append("• %s：兵力战损 %d" % [nname, lost])
	return "\n".join(out)

func _show_report(data: Dictionary) -> void:
	last_report_payload = data
	var turn: Dictionary = data.get("turn", {})
	var rep: Dictionary = data.get("report", {})
	var summary: Dictionary = rep.get("summary", {})
	var changes: Array = rep.get("node_changes", [])
	var my_rep: Variant = data.get("me", data.get("my_report", null))
	var me_rep: Dictionary = _resolve_me_report(data)
	var reports: Array = rep.get("reports", [])

	var turn_id := int(turn.get("id", last_report_turn_id))
	var turn_no := int(turn.get("turn_no", me_rep.get("turn_no", 1)))

	report_headline_lbl.text = str(rep.get("headline", "【决战头条】第 %d 候推演决战圆满告捷" % turn_no))
	if report_seal_rect != null:
		var has_won := str(turn.get("status", "")) == "victory" or turn_no > 1
		var seal_path := "res://assets/art/ui/seal_victory.png" if has_won else "res://assets/art/ui/seal_defeat.png"
		if ResourceLoader.exists(seal_path):
			report_seal_rect.texture = load(seal_path)
			report_seal_rect.visible = true
	var settled_raw: Variant = turn.get("settled_at", me_rep.get("settled_at", "—"))
	var settled_str := str(settled_raw) if (settled_raw != null and str(settled_raw) != "") else "—"
	report_time_lbl.text = "推演决算时点：%s" % settled_str

	if not me_rep.is_empty():
		report_my_text.text = _build_me_report_bbcode(data, my_rep, me_rep, turn_id)
		var detail_str := _build_me_report_detail_bbcode(me_rep)
		if report_me_expand_btn != null and report_me_detail_text != null:
			report_me_expand_btn.visible = (detail_str != "")
			report_me_detail_text.text = detail_str
			report_me_detail_text.visible = report_me_expanded and (detail_str != "")
	else:
		if report_me_expand_btn != null:
			report_me_expand_btn.visible = false
		if report_me_detail_text != null:
			report_me_detail_text.visible = false
		var b_my := ""
		if typeof(my_rep) == TYPE_DICTIONARY and not my_rep.is_empty():
			var desc := str(my_rep.get("readable_text", ""))
			if desc != "":
				b_my += desc + "\n\n"
			else:
				b_my += "出征行动：%s\n决胜战果：%s\n\n" % [str(my_rep.get("description", "")), str(my_rep.get("result_summary", ""))]
		else:
			b_my += "本候出征顺利，班宠灵力激荡，守备得力，立下军功！\n\n"

		var cur_pts := int(wallet.get("available_points", 0))
		var cur_wenyu := int(wallet.get("jade_balance", wallet.get("jade", 0)))
		b_my += "• 可用学堂积分：%d 分 | 军备文玉：%d 枚（1 积分 = 10 文玉）\n" % [cur_pts, cur_wenyu]
		b_my += "• 本候推演奖励已入库，积分与文玉已按学堂规则完成发放。"

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

	if report_estate_lbl != null:
		var turn_m := _extract_turn_merit(data, my_rep, me_rep)
		if turn_m > 0:
			report_estate_lbl.text = "🏡 文房小院 +%d 军功" % turn_m
		else:
			report_estate_lbl.text = "🏡 文房小院 · 可用 %d 军功" % int(estate_data.get("merit_balance", 0))

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
	b_sum += "\n[color=#b83b32]◆ 下候备战提示：[/color]\n新一候军令开启后，请先查晨报与今日邸报，再前往沙盘出满 3 令！"
	report_summary_text.text = b_sum

	if report_boards_text != null:
		report_boards_text.text = _build_four_boards_bbcode(rep, me_rep)

const TACTICAL_EFFECTS := {
	"night_raid": "攻击 +20%（本城未侦察）",
	"forced_march": "先手行动，免疫断粮",
	"fire_attack": "器械攻墙 +60%",
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

func _build_four_boards_bbcode(rep: Dictionary, me_rep: Dictionary) -> String:
	var id_to_name: Dictionary = {}
	for w_arr in [cached_merit_payload.get("week_top", []), cached_merit_payload.get("top", [])]:
		if typeof(w_arr) == TYPE_ARRAY:
			for r in w_arr:
				if typeof(r) == TYPE_DICTIONARY and int(r.get("player_id", 0)) > 0:
					id_to_name[int(r.get("player_id", 0))] = str(r.get("nickname", ""))
	var my_pid := int(me.get("id", 0))
	if my_pid > 0:
		id_to_name[my_pid] = str(me.get("name", "我"))

	var battles: Array = rep.get("battles", []) if typeof(rep.get("battles", null)) == TYPE_ARRAY else []
	var vang_names: Dictionary = {}
	var def_names: Dictionary = {}
	var scout_cities: Array[String] = []
	var fire_cities: Array[String] = []
	for b in battles:
		if typeof(b) != TYPE_DICTIONARY:
			continue
		var ncode := str(b.get("node_code", ""))
		var nname := str(map.node_by_code(ncode).get("name", ncode))
		for t in (b.get("teams", []) if typeof(b.get("teams", null)) == TYPE_ARRAY else []):
			if typeof(t) == TYPE_DICTIONARY and int(t.get("player_id", 0)) > 0:
				var pid := int(t.get("player_id", 0))
				var nm := str(id_to_name.get(pid, "学子#%d" % pid))
				vang_names[nm] = int(vang_names.get(nm, 0)) + 1
		for dt in (b.get("defender_teams", []) if typeof(b.get("defender_teams", null)) == TYPE_ARRAY else []):
			if typeof(dt) == TYPE_DICTIONARY and int(dt.get("player_id", 0)) > 0:
				var pid := int(dt.get("player_id", 0))
				var nm := str(id_to_name.get(pid, "学子#%d" % pid))
				def_names[nm] = int(def_names.get(nm, 0)) + 1
		if bool(b.get("scouted", false)):
			scout_cities.append(nname)
		if bool(b.get("fire", false)):
			fire_cities.append(nname)

	var sup_cnt := 0
	for ord_v in (me_rep.get("orders", []) if typeof(me_rep.get("orders", null)) == TYPE_ARRAY else []):
		if typeof(ord_v) == TYPE_DICTIONARY and str(ord_v.get("role", "")) == "support":
			sup_cnt += 1

	var role_map := {}
	var my_roles: Variant = merit_summary_data.get("roles", [])
	if typeof(my_roles) == TYPE_ARRAY:
		for mr in my_roles:
			if typeof(mr) == TYPE_DICTIONARY:
				role_map[str(mr.get("kind", ""))] = int(mr.get("rank", 0))

	var top_str := func(d: Dictionary, empty_tip: String) -> String:
		if d.is_empty():
			return empty_tip
		var arr: Array[String] = []
		for k in d.keys():
			arr.append("%s(%d次)" % [str(k), int(d[k])])
		return "、".join(arr.slice(0, 3))

	var out: Array[String] = []
	var r_v := (" · 我的本周先锋第 %d" % int(role_map["vanguard"])) if role_map.has("vanguard") else ""
	var r_s := (" · 我的本周支援第 %d" % int(role_map["support"])) if role_map.has("support") else ""
	var r_c := (" · 我的本周侦察第 %d" % int(role_map["scout"])) if role_map.has("scout") else ""
	var r_d := (" · 我的本周守城第 %d" % int(role_map["defend"])) if role_map.has("defend") else ""

	out.append("• [b][color=#b83b32]⚔️ 先锋榜[/color][/b]：%s%s" % [top_str.call(vang_names, "本候尚无先锋出战"), r_v])
	out.append("• [b][color=#276f57]🤝 支援榜[/color][/b]：%s%s" % ["我本候协攻 %d 令（各给主攻 +2%%）" % sup_cnt if sup_cnt > 0 else "全阵营出令即计入协攻", r_s])
	out.append("• [b][color=#1e3a5f]🕵 侦察榜[/color][/b]：%s%s" % ["破雾据点：" + ("、".join(scout_cities) if not scout_cities.is_empty() else "本候未触发哨探"), r_c])
	out.append("• [b][color=#cf8325]🛡️ 守城榜[/color][/b]：%s%s" % [top_str.call(def_names, "由城池固定守军迎敌"), r_d])

	var week_top: Array = cached_merit_payload.get("week_top", []) if typeof(cached_merit_payload.get("week_top", null)) == TYPE_ARRAY else []
	if not week_top.is_empty():
		var wt_strs: Array[String] = []
		for i in range(mini(3, week_top.size())):
			var row: Dictionary = week_top[i]
			wt_strs.append("%d.%s(%d)" % [i + 1, str(row.get("nickname", "")), int(row.get("total", 0))])
		out.append("[color=#5a4a3a]本周军功总榜前三：%s[/color]" % " · ".join(wt_strs))
	return "\n".join(out)

# ---------------------------------------------------------------------------
# S04 战局回放子页（已并入战争日报，保留 _open_replay / replay_dialog 兼容）
# ---------------------------------------------------------------------------

func _open_replay() -> void:
	action_status.text = "正在调取沙盘推演记录..."
	api.request("GET", "/api/slice/replay", null, func(ok: bool, data: Dictionary, err: Dictionary):
		if not ok:
			_render_fallback_replay()
			_navigate_to("S04_REPORT")
			_switch_report_subtab("replay")
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
		replay_text.text = "[font_size=16][color=#b83b32]◆ 沙盘军情态势（备战中）[/color][/font_size]\n各据点布防已毕，各大书院同门学子正在集结待命。\n[color=#685848]今夜 21:00 定时结算后，将自动生成城池易帜复盘与战场日志。[/color]"
		_navigate_to("S04_REPORT")
		_switch_report_subtab("replay")
		return

	replay_turn_select.clear()
	for i in range(turns.size()):
		var no := int(turns[i].get("turn_no", i + 1))
		var idx := replay_turn_select.item_count
		replay_turn_select.add_item("第 %d 候推演复盘" % no)
		replay_turn_select.set_item_metadata(idx, i)
	replay_turn_select.select(turns.size() - 1)
	_render_replay_turn(turns.size() - 1)
	_navigate_to("S04_REPORT")
	_switch_report_subtab("replay")

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

	_build_estate_page()

	_build_army_composition_page()

	_build_season_page()

	# 未实装模块收起主入口，仅保留简洁“敬请期待”兜底页（已清除假任务与假商城文案）
	_build_placeholder_page("S07_GENERAL", "🐾 班宠将军", "功能筹备中", "🐾", "敬请期待", [
		{"title": "敬请期待", "desc": "班宠将军进阶养成与图鉴将于后续版本开放，敬请期待。"}
	])
	_build_placeholder_page("S08_CODEX", "📜 文脉图鉴", "功能筹备中", "📜", "敬请期待", [
		{"title": "敬请期待", "desc": "九州文脉诗卷典藏将于后续版本开放，敬请期待。"}
	])
	_build_placeholder_page("S09_SHOP", "🏮 文房榷场", "功能筹备中", "🏮", "敬请期待", [
		{"title": "敬请期待", "desc": "文玉外观兑换阁将于后续版本开放，敬请期待。"}
	])
	_build_placeholder_page("S12_MAIL", "✉️ 军府谕告", "请点击顶栏【晨报】查看最新战报与邸报", "✉️", "已整合至晨报", [
		{"title": "请使用顶栏【📰 晨报】", "desc": "每日战果头条、个人战报摘要与今日邸报 2 选 1 已统一整合到【晨报】中。"}
	])

	_build_settings_page()

func _build_season_page() -> void:
	season_page = SeasonViewScript.new()
	season_page.name = "SeasonPage"
	season_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	season_page.visible = false
	season_page.back_to_map_requested.connect(func(): _navigate_to("S01_MAP"))
	season_page.refresh_requested.connect(func(): _fetch_season_and_history(true))
	pages["S10_SEASON"] = season_page
	pages_container.add_child(season_page)

func _open_season_page() -> void:
	_navigate_to("S10_SEASON")
	_fetch_season_and_history(false)

func _fetch_season_and_history(auto_check_award: bool = false) -> void:
	if api == null or api.token == "":
		return
	api.get_season(func(ok: bool, sdata: Dictionary, _err: Dictionary):
		if ok and not sdata.is_empty():
			season_data = sdata.duplicate(true)
			if season_page != null:
				season_page.set_season_data(season_data, season_history_data, merit_summary_data, state.get("game", {}), me)
			var is_over := bool(sdata.get("season_over", false)) or str(state.get("game", {}).get("status", "")) == "finished"
			if auto_check_award and is_over and not _season_award_auto_checked and str(me.get("role", "player")) == "player":
				_season_award_auto_checked = true
				_navigate_to("S10_SEASON")
	)
	api.get_season_history(func(ok: bool, hdata: Dictionary, _err: Dictionary):
		if ok and not hdata.is_empty():
			season_history_data = hdata.duplicate(true)
			if season_page != null:
				season_page.set_season_data(season_data, season_history_data, merit_summary_data, state.get("game", {}), me)
	)

func _build_estate_page() -> void:
	estate_page = EstateViewScript.new()
	estate_page.name = "EstatePage"
	estate_page.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	estate_page.visible = false
	estate_page.back_to_map_requested.connect(func(): _navigate_to("S01_MAP"))
	estate_page.focus_city_requested.connect(func(city_code: String):
		_navigate_to("S01_MAP")
		reset_view()
		_open_city_drawer(city_code)
	)
	estate_page.upgrade_requested.connect(func(room_code: String):
		api.upgrade_estate(room_code, func(ok: bool, data: Dictionary, err: Dictionary):
			if estate_page != null:
				estate_page.on_upgrade_result(ok, data, err)
			if not ok:
				_show_error(err)
				return
			var new_es: Variant = data.get("estate", data if data.has("rooms") else null)
			if typeof(new_es) == TYPE_DICTIONARY:
				estate_data = new_es.duplicate(true)
				state["estate"] = estate_data
			var ur: Variant = data.get("upgraded", data.get("upgraded_room", {}))
			var room_names := {"study": "书房", "drill": "练兵场", "tower": "望楼"}
			var fallback_rname := str(room_names.get(room_code, room_code))
			var rname := str(ur.get("name", fallback_rname)) if typeof(ur) == TYPE_DICTIONARY else fallback_rname

			var rlvl := int(ur.get("level", 1)) if typeof(ur) == TYPE_DICTIONARY else 1
			_toast("🏡 【%s】已修缮至 Lv.%d！" % [rname, rlvl])
			_refresh_state()
		)
	)
	estate_page.merit_rank_requested.connect(func():
		api.get_merit(func(ok: bool, data: Dictionary, err: Dictionary):
			if not ok:
				_show_error(err)
				return
			if estate_page != null:
				estate_page.set_merit_leaderboard(data)
				estate_page.open_leaderboard()
		)
	)
	estate_page.toast_requested.connect(func(msg: String, is_err: bool): _toast(msg, is_err))
	pages["S02_CITY_HUB"] = estate_page
	pages_container.add_child(estate_page)

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
# S11 学堂设置页面（音量、动效、教学向导、网络与学籍）
# ---------------------------------------------------------------------------

func _build_settings_page() -> void:
	var page_id := "S11_SETTINGS"
	var p := Control.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	pages[page_id] = p
	pages_container.add_child(p)

	var bg := ColorRect.new()
	bg.color = C_WOOD_DESK.darkened(0.2)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(bg)

	var header := _create_page_header("⚙️ 学堂备忘与设置", "音效、画面动效与学堂通信链路配置")
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

	# 1. 声音与韶乐卡片
	var audio_card := PanelContainer.new()
	audio_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_card.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 8, 14))
	v.add_child(audio_card)

	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 10)
	audio_card.add_child(av)

	var a_title := _label("🎵 韶乐与战阵音效", 16, C_WOOD_DESK)
	av.add_child(a_title)

	# 总音量
	var m_row := HBoxContainer.new()
	m_row.add_theme_constant_override("separation", 12)
	av.add_child(m_row)
	var m_lbl := _label("主音量：", 14, Color("#554433"))
	m_lbl.custom_minimum_size = Vector2(80, 0)
	m_row.add_child(m_lbl)
	var m_slider := HSlider.new()
	m_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_slider.min_value = 0.0
	m_slider.max_value = 100.0
	m_slider.value = AudioManager.master_volume * 100.0
	m_row.add_child(m_slider)
	var m_val_lbl := _label("%d%%" % int(m_slider.value), 14, C_WOOD_DESK)
	m_val_lbl.custom_minimum_size = Vector2(45, 0)
	m_row.add_child(m_val_lbl)
	m_slider.value_changed.connect(func(val: float):
		m_val_lbl.text = "%d%%" % int(val)
		AudioManager.set_master_volume(val / 100.0)
	)

	# 音乐音量
	var bgm_row := HBoxContainer.new()
	bgm_row.add_theme_constant_override("separation", 10)
	av.add_child(bgm_row)
	var bgm_lbl := _label("背景音乐：", 14, Color("#554433"))
	bgm_lbl.custom_minimum_size = Vector2(76, 0)
	bgm_row.add_child(bgm_lbl)
	var bgm_mute_btn := Button.new()
	bgm_mute_btn.custom_minimum_size = Vector2(32, 32)
	bgm_mute_btn.expand_icon = true
	var music_on_tex := load("res://assets/art/ui/icon_music_on.png") if ResourceLoader.exists("res://assets/art/ui/icon_music_on.png") else null
	var music_off_tex := load("res://assets/art/ui/icon_music_off.png") if ResourceLoader.exists("res://assets/art/ui/icon_music_off.png") else null
	bgm_mute_btn.icon = music_on_tex if AudioManager.music_volume > 0.0 else music_off_tex
	bgm_row.add_child(bgm_mute_btn)
	var bgm_slider := HSlider.new()
	bgm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bgm_slider.min_value = 0.0
	bgm_slider.max_value = 100.0
	bgm_slider.value = AudioManager.music_volume * 100.0
	bgm_row.add_child(bgm_slider)
	var bgm_val_lbl := _label("%d%%" % int(bgm_slider.value), 14, C_WOOD_DESK)
	bgm_val_lbl.custom_minimum_size = Vector2(45, 0)
	bgm_row.add_child(bgm_val_lbl)
	bgm_slider.value_changed.connect(func(val: float):
		bgm_val_lbl.text = "%d%%" % int(val)
		AudioManager.set_music_volume(val / 100.0)
		bgm_mute_btn.icon = music_on_tex if val > 0.0 else music_off_tex
	)
	bgm_mute_btn.pressed.connect(func():
		if AudioManager.music_volume > 0.0:
			AudioManager.set_music_volume(0.0)
			bgm_slider.value = 0.0
			bgm_val_lbl.text = "0%"
			bgm_mute_btn.icon = music_off_tex
		else:
			AudioManager.set_music_volume(0.8)
			bgm_slider.value = 80.0
			bgm_val_lbl.text = "80%"
			bgm_mute_btn.icon = music_on_tex
	)

	# 音效音量
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 10)
	av.add_child(sfx_row)
	var sfx_lbl := _label("交互音效：", 14, Color("#554433"))
	sfx_lbl.custom_minimum_size = Vector2(76, 0)
	sfx_row.add_child(sfx_lbl)
	var sfx_mute_btn := Button.new()
	sfx_mute_btn.custom_minimum_size = Vector2(32, 32)
	sfx_mute_btn.expand_icon = true
	var sound_on_tex := load("res://assets/art/ui/icon_sound_on.png") if ResourceLoader.exists("res://assets/art/ui/icon_sound_on.png") else null
	var sound_off_tex := load("res://assets/art/ui/icon_sound_off.png") if ResourceLoader.exists("res://assets/art/ui/icon_sound_off.png") else null
	sfx_mute_btn.icon = sound_on_tex if AudioManager.sfx_volume > 0.0 else sound_off_tex
	sfx_row.add_child(sfx_mute_btn)
	var sfx_slider := HSlider.new()
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 100.0
	sfx_slider.value = AudioManager.sfx_volume * 100.0
	sfx_row.add_child(sfx_slider)
	var sfx_val_lbl := _label("%d%%" % int(sfx_slider.value), 14, C_WOOD_DESK)
	sfx_val_lbl.custom_minimum_size = Vector2(45, 0)
	sfx_row.add_child(sfx_val_lbl)
	sfx_slider.value_changed.connect(func(val: float):
		sfx_val_lbl.text = "%d%%" % int(val)
		AudioManager.set_sfx_volume(val / 100.0)
		sfx_mute_btn.icon = sound_on_tex if val > 0.0 else sound_off_tex
	)
	sfx_mute_btn.pressed.connect(func():
		if AudioManager.sfx_volume > 0.0:
			AudioManager.set_sfx_volume(0.0)
			sfx_slider.value = 0.0
			sfx_val_lbl.text = "0%"
			sfx_mute_btn.icon = sound_off_tex
		else:
			AudioManager.set_sfx_volume(0.8)
			sfx_slider.value = 80.0
			sfx_val_lbl.text = "80%"
			sfx_mute_btn.icon = sound_on_tex
	)
	sfx_slider.drag_ended.connect(func(_changed: bool):
		AudioManager.play_sfx("click")
	)

	# 2. 视觉表现与动效设置
	var visual_card := PanelContainer.new()
	visual_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual_card.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 8, 14))
	v.add_child(visual_card)

	var vv := VBoxContainer.new()
	vv.add_theme_constant_override("separation", 8)
	visual_card.add_child(vv)

	var v_title := _label("✨ 视觉表现与动效", 16, C_WOOD_DESK)
	vv.add_child(v_title)

	var motion_row := HBoxContainer.new()
	motion_row.add_theme_constant_override("separation", 12)
	vv.add_child(motion_row)

	var motion_lbl := _label("减少动效模式：", 14, Color("#554433"))
	motion_lbl.custom_minimum_size = Vector2(100, 0)
	motion_row.add_child(motion_lbl)

	var motion_btn := Button.new()
	motion_btn.custom_minimum_size = Vector2(118, 36)
	if ResourceLoader.exists("res://assets/art/ui/icon_reduce_motion.png"):
		motion_btn.icon = load("res://assets/art/ui/icon_reduce_motion.png")
		motion_btn.expand_icon = true
	motion_btn.text = "【已开启】" if AudioManager.is_reduced_motion else "【已关闭】"
	motion_btn.add_theme_color_override("font_color", C_ZHUQING if AudioManager.is_reduced_motion else Color("#756858"))
	motion_btn.pressed.connect(func():
		var new_state: bool = not AudioManager.is_reduced_motion
		AudioManager.set_reduced_motion(new_state)
		motion_btn.text = "【已开启】" if new_state else "【已关闭】"
		motion_btn.add_theme_color_override("font_color", C_ZHUQING if new_state else Color("#756858"))
		_toast("已%s减少动效模式" % ("开启" if new_state else "关闭"))
	)
	motion_row.add_child(motion_btn)

	var motion_tip := _label("开启后跳过战场碎石粒子、镜头微缩放与卡牌翻入，降低性能功耗与眩晕感。", 12, Color("#756858"))
	motion_tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	motion_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vv.add_child(motion_tip)

	# 3. 新手教学修习
	var tut_card := PanelContainer.new()
	tut_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tut_card.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 8, 14))
	v.add_child(tut_card)

	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 8)
	tut_card.add_child(tv)

	var t_title := _label("📖 新手修习向导", 16, C_WOOD_DESK)
	tv.add_child(t_title)

	var t_row := HBoxContainer.new()
	t_row.add_theme_constant_override("separation", 12)
	tv.add_child(t_row)

	var t_desc := _label("重温三步军令修习：踏勘城池、谋划战策、加盖帅印。", 13, Color("#554433"))
	t_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_row.add_child(t_desc)

	var restart_tut_btn := _button(" 重温新手教学", C_MOLAN, 38)
	if ResourceLoader.exists("res://assets/art/ui/icon_tutorial.png"):
		restart_tut_btn.icon = load("res://assets/art/ui/icon_tutorial.png")
		restart_tut_btn.expand_icon = true
	restart_tut_btn.custom_minimum_size = Vector2(146, 38)
	restart_tut_btn.pressed.connect(func():
		var cfg := ConfigFile.new()
		cfg.set_value("tutorial", "completed", false)
		cfg.save("user://tutorial_completed.cfg")
		_navigate_to("S01_MAP")
		_start_tutorial()
		_toast("已开启新手军令修习向导！")
	)
	t_row.add_child(restart_tut_btn)

	# 4. 服务器通信配置
	var net_card := PanelContainer.new()
	net_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	net_card.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 8, 14))
	v.add_child(net_card)

	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 8)
	net_card.add_child(nv)

	var n_title := _label("🌐 学堂通信网络", 16, C_WOOD_DESK)
	nv.add_child(n_title)

	var n_row := HBoxContainer.new()
	n_row.add_theme_constant_override("separation", 10)
	nv.add_child(n_row)

	var net_edit := LineEdit.new()
	net_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	net_edit.text = url_edit.text
	net_edit.custom_minimum_size = Vector2(0, 38)
	n_row.add_child(net_edit)

	var net_save_btn := _button("保存通信链路", C_ZHUQING, 38)
	net_save_btn.custom_minimum_size = Vector2(120, 38)
	net_save_btn.pressed.connect(func():
		var new_url := net_edit.text.strip_edges()
		if new_url != "":
			url_edit.text = new_url
			api.set_base_url(new_url)
			_save_config()
			_toast("已更新学堂服务器通信地址！")
	)
	n_row.add_child(net_save_btn)

	# 5. 账号学籍与版本信息
	var info_card := PanelContainer.new()
	info_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_card.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, Color("#dfcaa7"), 1, 8, 14))
	v.add_child(info_card)

	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 10)
	info_card.add_child(iv)

	var i_title := _label("📜 学籍与版本", 16, C_WOOD_DESK)
	iv.add_child(i_title)

	var ver_lbl := _label("客户端版本：青竹文房 · 灵宠山河 v1.5.0-alpha (Milestone A)", 13, Color("#685848"))
	iv.add_child(ver_lbl)

	var logout_btn := _button("🚪 安全归隐退堂 (登出学籍)", C_ZHUSHA, 42)
	logout_btn.custom_minimum_size = Vector2(0, 42)
	logout_btn.pressed.connect(_on_logout)
	iv.add_child(logout_btn)

# ---------------------------------------------------------------------------
# S2 新手 3 步修习向导与界面抖动交互
# ---------------------------------------------------------------------------

func _init_tutorial_ui() -> void:
	tutorial_overlay = Control.new()
	tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_overlay.visible = false
	tutorial_overlay.z_index = 30
	game_layer.add_child(tutorial_overlay)

	tutorial_box = PanelContainer.new()
	tutorial_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_box.add_theme_stylebox_override("panel", _style(Color("#fdf6e8", 0.96), C_ZHUSHA, 2, 10, 8))
	tutorial_overlay.add_child(tutorial_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_box.add_child(row)

	tutorial_img_frame = PanelContainer.new()
	tutorial_img_frame.custom_minimum_size = Vector2(212, 110)
	tutorial_img_frame.size = Vector2(212, 110)
	tutorial_img_frame.clip_contents = true
	tutorial_img_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_img_frame.add_theme_stylebox_override("panel", _style(Color("#f4e3cb"), C_BORDER_GOLD, 1, 6, 0))
	row.add_child(tutorial_img_frame)

	tutorial_img_clip = Control.new()
	tutorial_img_clip.clip_contents = true
	tutorial_img_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_img_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_img_frame.add_child(tutorial_img_clip)

	tutorial_img = TextureRect.new()
	tutorial_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tutorial_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tutorial_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_img_clip.add_child(tutorial_img)

	# 第 1 步专属图文浮签：挂在普通 Control 容器 tutorial_img_clip 下，避免 PanelContainer 强制铺满遮挡原画
	tutorial_tag_city = PanelContainer.new()
	tutorial_tag_city.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_tag_city.z_index = 2
	tutorial_tag_city.add_theme_stylebox_override("panel", _style(Color("#fbf2df", 0.95), C_ZHUSHA, 1, 4, 4))
	var tag_city_lbl := _label("先点城", 11, C_ZHUSHA)
	tag_city_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_tag_city.add_child(tag_city_lbl)
	tutorial_img_clip.add_child(tutorial_tag_city)

	tutorial_tag_card = PanelContainer.new()
	tutorial_tag_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_tag_card.z_index = 2
	tutorial_tag_card.add_theme_stylebox_override("panel", _style(Color("#1e3a5f", 0.94), C_BORDER_GOLD, 1, 4, 4))
	var tag_card_lbl := _label("再选牌", 11, Color("#fae19c"))
	tag_card_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_tag_card.add_child(tag_card_lbl)
	tutorial_img_clip.add_child(tutorial_tag_card)

	tutorial_icon_badge = _label("🏮", 18, C_ZHUSHA)
	tutorial_icon_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_icon_badge.visible = false
	row.add_child(tutorial_icon_badge)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.add_theme_constant_override("separation", 4)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)

	tutorial_title_lbl = _label("【第一步 · 先点城，再选牌】", 13, C_ZHUSHA)
	tutorial_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(tutorial_title_lbl)

	tutorial_desc_lbl = _label("轻触下方沙盘城池开启军议，再选底部手牌出征（每天最多出 3 令）。", 12, Color("#3a2d24"))
	tutorial_desc_lbl.custom_minimum_size = Vector2(180, 0)
	tutorial_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(tutorial_desc_lbl)

	var btn_col := HBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 6)
	btn_col.size_flags_vertical = Control.SIZE_SHRINK_END
	text_col.add_child(btn_col)

	tutorial_action_btn = Button.new()
	tutorial_action_btn.text = "✓ 我已通晓"
	tutorial_action_btn.custom_minimum_size = Vector2(80, 30)
	tutorial_action_btn.add_theme_font_size_override("font_size", 12)
	tutorial_action_btn.add_theme_color_override("font_color", Color("#fae19c"))
	tutorial_action_btn.add_theme_stylebox_override("normal", _style(C_ZHUQING, C_BORDER_GOLD, 1, 4, 4))
	tutorial_action_btn.visible = false
	tutorial_action_btn.pressed.connect(_complete_tutorial)
	btn_col.add_child(tutorial_action_btn)

	tutorial_skip_btn = Button.new()
	tutorial_skip_btn.text = "⏩ 跳过"
	tutorial_skip_btn.custom_minimum_size = Vector2(64, 28)
	tutorial_skip_btn.add_theme_font_size_override("font_size", 12)
	tutorial_skip_btn.add_theme_color_override("font_color", Color("#e7dcc8"))
	tutorial_skip_btn.add_theme_stylebox_override("normal", _style(Color("#30241b"), Color("#5a4838"), 1, 4, 4))
	tutorial_skip_btn.pressed.connect(_complete_tutorial)
	btn_col.add_child(tutorial_skip_btn)

func _is_tutorial_completed() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load("user://tutorial_completed.cfg") == OK:
		return bool(cfg.get_value("tutorial", "completed", false))
	return false

func _check_and_trigger_tutorial() -> void:
	# 无头模式自动化测试不启动交互引导，保证测试纯净
	if DisplayServer.get_name() == "headless" or "--headless" in OS.get_cmdline_args():
		return
	if not _is_tutorial_completed():
		_start_tutorial()

func _layout_tutorial_media() -> void:
	if tutorial_img_frame == null or tutorial_img == null:
		return
	var fw := tutorial_img_frame.size.x
	var fh := tutorial_img_frame.size.y
	if fw <= 4.0 or fh <= 4.0:
		return
	var is_step1 := (tutorial_step == 1)
	if tutorial_icon_badge != null:
		tutorial_icon_badge.visible = not is_step1
	if tutorial_tag_city != null:
		tutorial_tag_city.visible = is_step1
	if tutorial_tag_card != null:
		tutorial_tag_card.visible = is_step1

	if is_step1 and tutorial_atlas != null and tutorial_atlas.region.size.x > 0.0:
		var reg := tutorial_atlas.region
		var pad_x := 0.0 if AudioManager.is_reduced_motion else 6.0
		var sc := maxf((fw + pad_x) / reg.size.x, fh / reg.size.y)
		var draw_size := reg.size * sc
		tutorial_img_base_pos = Vector2((fw - draw_size.x) * 0.5, (fh - draw_size.y) * 0.5)
		tutorial_img.size = draw_size
		tutorial_img.position = Vector2(tutorial_img_base_pos.x + tutorial_parallax_px, tutorial_img_base_pos.y)
		# 基于当前裁剪 region，精准把“先点城”压到左下纸块中心，“再选牌”压到右上关隘城池旁
		if tutorial_tag_city != null:
			var tc_sz := tutorial_tag_city.get_combined_minimum_size()
			tutorial_tag_city.size = tc_sz
			var uv_city := Vector2((382.0 - reg.position.x) / reg.size.x, (426.0 - reg.position.y) / reg.size.y)
			var cpos := tutorial_img_base_pos + uv_city * draw_size - tc_sz * 0.5
			tutorial_tag_city.position = Vector2(clampf(cpos.x, 4.0, fw - tc_sz.x - 4.0), clampf(cpos.y, 4.0, fh - tc_sz.y - 4.0))
		if tutorial_tag_card != null:
			var tk_sz := tutorial_tag_card.get_combined_minimum_size()
			tutorial_tag_card.size = tk_sz
			var uv_card := Vector2((804.0 - reg.position.x) / reg.size.x, (358.0 - reg.position.y) / reg.size.y)
			var kpos := tutorial_img_base_pos + uv_card * draw_size - tk_sz * 0.5
			tutorial_tag_card.position = Vector2(clampf(kpos.x, 4.0, fw - tk_sz.x - 4.0), clampf(kpos.y, 4.0, fh - tk_sz.y - 4.0))
	else:
		tutorial_img_base_pos = Vector2.ZERO
		tutorial_img.position = Vector2.ZERO
		tutorial_img.size = Vector2(fw, fh)

func _update_tutorial_illustration(step: int) -> void:
	if tutorial_img == null:
		return
	var guide_path := "res://assets/art/ui/first_order_city_card_guide.png"
	if step == 1 and ResourceLoader.exists(guide_path):
		var gtex: Texture2D = load(guide_path)
		if gtex != null:
			var is_compact := size.x < 900.0 or size.y < 650.0
			if tutorial_atlas == null:
				tutorial_atlas = AtlasTexture.new()
			tutorial_atlas.atlas = gtex
			tutorial_atlas.region = Rect2(24.0, 52.0, 948.0, 494.0) if is_compact else Rect2(16.0, 28.0, 992.0, 532.0)
			tutorial_img.texture = tutorial_atlas
			tutorial_img.visible = true
			_layout_tutorial_media()
			return
	var path := ""
	match step:
		1: path = "res://assets/art/ui/tutorial_01_choose_city.png"
		2: path = "res://assets/art/ui/tutorial_02_choose_card.png"
		3: path = "res://assets/art/ui/tutorial_03_confirm.png"
	if path != "" and ResourceLoader.exists(path):
		tutorial_img.texture = load(path)
		tutorial_img.visible = true
	else:
		tutorial_img.visible = false
	_layout_tutorial_media()

func _start_tutorial() -> void:
	if tutorial_overlay == null:
		return
	tutorial_step = 1
	tutorial_overlay.visible = true
	tutorial_action_btn.visible = false
	tutorial_skip_btn.visible = true
	tutorial_title_lbl.text = "【第一步 · 先点城，再选牌】"
	tutorial_desc_lbl.text = "轻触下方沙盘城池开启军议，再选底部手牌出征（每天最多出 3 令）。"
	_update_tutorial_illustration(1)
	_layout_responsive()
	if not AudioManager.is_reduced_motion:
		tutorial_box.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(tutorial_box, "modulate:a", 1.0, 0.25)

func _advance_tutorial(next_step: int) -> void:
	if tutorial_step <= 0 or tutorial_overlay == null or not tutorial_overlay.visible:
		return
	tutorial_step = next_step
	_update_tutorial_illustration(next_step)
	_layout_responsive()
	if tutorial_step == 2:
		tutorial_title_lbl.text = "【第二步 · 手牌出令】"
		tutorial_desc_lbl.text = "已选中据点！无需关抽屉，直接点下方【每日将令】手牌出征（每天最多出 3 令）。"
		tutorial_action_btn.visible = false
	elif tutorial_step == 3:
		tutorial_title_lbl.text = "【第三步 · 帅印盖定】"
		tutorial_desc_lbl.text = "已出 1 令（每天最多出 3 令）！21:00 锁令前可点已出牌撤回；三军依战策与阵位决胜。"
		tutorial_action_btn.visible = true
	if not AudioManager.is_reduced_motion:
		_shake_node(tutorial_box)

func _complete_tutorial() -> void:
	tutorial_step = 0
	if tutorial_overlay != null:
		if AudioManager.is_reduced_motion:
			tutorial_overlay.visible = false
		else:
			var tw := create_tween()
			tw.tween_property(tutorial_box, "modulate:a", 0.0, 0.20)
			tw.tween_callback(func(): tutorial_overlay.visible = false)
	var cfg := ConfigFile.new()
	cfg.set_value("tutorial", "completed", true)
	cfg.save("user://tutorial_completed.cfg")

func _shake_node(node: Control) -> void:
	if not is_instance_valid(node) or AudioManager.is_reduced_motion:
		return
	var orig_x := node.position.x
	var tw := create_tween()
	tw.tween_property(node, "position:x", orig_x - 5.0, 0.03)
	tw.tween_property(node, "position:x", orig_x + 5.0, 0.03)
	tw.tween_property(node, "position:x", orig_x - 3.0, 0.03)
	tw.tween_property(node, "position:x", orig_x + 3.0, 0.03)
	tw.tween_property(node, "position:x", orig_x, 0.03)

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

	var header := _create_page_header("⚔️ 每周军团编成", "4 兵种三队战阵 · 兵源城加成 · 本周可改 1 次")
	army_page.add_child(header)
	for ch in header.get_children():
		if ch is MarginContainer:
			for hrow in ch.get_children():
				if hrow is HBoxContainer and hrow.get_child_count() >= 3:
					var sub := hrow.get_child(2)
					if sub is Label:
						army_header_sub_lbl = sub

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

	# 头部放今日邸报（2 选 1 · 结算前可随时调整）
	army_bulletin_box = PanelContainer.new()
	army_bulletin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	army_bulletin_box.add_theme_stylebox_override("panel", _panel_style(C_XUANZHI, C_BORDER_GOLD, 1, 8, 10))
	vbox.add_child(army_bulletin_box)

	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	army_bulletin_box.add_child(bv)

	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 8)
	bv.add_child(bh)
	bh.add_child(_label("📜 今日邸报（2 选 1）", 14, C_ZHUSHA))
	army_bulletin_hint_lbl = _label("每日从三策中择一加持本回合 · 结算前可改", 11, Color("#685848"))
	army_bulletin_hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	army_bulletin_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bh.add_child(army_bulletin_hint_lbl)

	army_bulletin_row = HBoxContainer.new()
	army_bulletin_row.add_theme_constant_override("separation", 8)
	army_bulletin_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bv.add_child(army_bulletin_row)

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
	{"code": "fire_attack", "aliases": [], "name": "火攻", "type": "advance", "icon": "🔥", "short_desc": "器械攻墙伤害+60%", "full_desc": "【朱·火攻】：火烧连营摧坚壁，大幅强化阵后器械对城墙的破坏力(+60%)。"},
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
	var prev_val: Variant = hand_info.get("preview", [])
	hand_preview_codes = prev_val if typeof(prev_val) == TYPE_ARRAY else []
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
		var prev_parts := PackedStringArray()
		for pc in hand_preview_codes:
			prev_parts.append(str(pc))
		var sig := "|".join(cards) + "::" + "|".join(prev_parts)
		var should_anim := (sig != last_hand_signature)
		last_hand_signature = sig
		_render_hand_cards(should_anim)

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
	root_vb.add_theme_constant_override("separation", 2)
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

	hand_lane_btn = Button.new()
	hand_lane_btn.text = "路:自动"
	hand_lane_btn.custom_minimum_size = Vector2(54, 20)
	hand_lane_btn.add_theme_font_size_override("font_size", 10)
	hand_lane_btn.add_theme_color_override("font_color", GOLD_LIGHT)
	hand_lane_btn.add_theme_stylebox_override("normal", _style(Color("#2a221c"), Color("#78654e"), 1, 4, 2))
	hand_lane_btn.tooltip_text = "切换出令分路（自动按槽位 1/2/3 路，点击可自选 1/2/3 路）"
	hand_lane_btn.pressed.connect(func():
		hand_lane_override = (hand_lane_override + 1) % 4
		hand_lane_btn.text = "路:自动" if hand_lane_override == 0 else ("路:%d路" % hand_lane_override)
		_schedule_forecast_recalc()
	)
	top_hb.add_child(hand_lane_btn)

	hand_row_btn = Button.new()
	hand_row_btn.text = "排:自动"
	hand_row_btn.custom_minimum_size = Vector2(54, 20)
	hand_row_btn.add_theme_font_size_override("font_size", 10)
	hand_row_btn.add_theme_color_override("font_color", GOLD_LIGHT)
	hand_row_btn.add_theme_stylebox_override("normal", _style(Color("#2a221c"), Color("#78654e"), 1, 4, 2))
	hand_row_btn.tooltip_text = "切换前排/后排布阵（自动按兵种分配，点击切换前排/后排）"
	hand_row_btn.pressed.connect(func():
		if hand_row_override == "":
			hand_row_override = "front"
			hand_row_btn.text = "排:前排"
		elif hand_row_override == "front":
			hand_row_override = "back"
			hand_row_btn.text = "排:后排"
		else:
			hand_row_override = ""
			hand_row_btn.text = "排:自动"
		_schedule_forecast_recalc()
	)
	top_hb.add_child(hand_row_btn)

	hand_redraw_btn = Button.new()
	hand_redraw_btn.text = "🔄 重抽(1/1)"
	hand_redraw_btn.custom_minimum_size = Vector2(72, 20)
	hand_redraw_btn.add_theme_font_size_override("font_size", 10)
	hand_redraw_btn.add_theme_color_override("font_color", Color("#ffffff"))
	hand_redraw_btn.add_theme_stylebox_override("normal", _style(C_ZHUSHA.darkened(0.2), C_BORDER_GOLD, 1, 4, 1))
	hand_redraw_btn.add_theme_stylebox_override("disabled", _style(Color("#2a221c"), Color("#5a4d3f"), 1, 4, 1))
	hand_redraw_btn.pressed.connect(_on_hand_redraw_pressed)
	top_hb.add_child(hand_redraw_btn)

	hand_collapse_btn = Button.new()
	hand_collapse_btn.text = "▼ 折叠"
	hand_collapse_btn.custom_minimum_size = Vector2(46, 20)
	hand_collapse_btn.add_theme_font_size_override("font_size", 10)
	hand_collapse_btn.add_theme_stylebox_override("normal", _style(Color("#241b15"), Color("#6b5747"), 1, 4, 1))
	hand_collapse_btn.pressed.connect(_toggle_hand_bar_collapse)
	top_hb.add_child(hand_collapse_btn)

	hand_cards_container = HBoxContainer.new()
	hand_cards_container.name = "CardsRow"
	hand_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_cards_container.add_theme_constant_override("separation", 6)
	root_vb.add_child(hand_cards_container)

	_init_hand_cards_data()
	_render_hand_cards()

func _render_hand_cards(animate: bool = false) -> void:
	if not hand_cards_container:
		return
	for c in hand_cards_container.get_children():
		hand_cards_container.remove_child(c)
		c.queue_free()
	hand_card_views.clear()

	for i in range(hand_cards_data.size()):
		var cdata: Dictionary = hand_cards_data[i]
		var card := _create_single_hand_card(i, cdata)
		hand_cards_container.add_child(card)
		hand_card_views.append(card)

		if animate and not AudioManager.is_reduced_motion:
			card.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_interval(i * 0.03)
			tw.tween_property(card, "modulate:a", 1.0, 0.16)

	hand_preview_panel = null
	if not hand_preview_codes.is_empty():
		hand_preview_panel = _create_hand_preview_slot(hand_preview_codes)
		hand_cards_container.add_child(hand_preview_panel)

func _create_hand_preview_slot(preview_codes: Array) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.name = "HandPreviewSlot"
	slot.custom_minimum_size = Vector2(108 if preview_codes.size() >= 3 else 96, 68)
	slot.add_theme_stylebox_override("panel", _style(Color("#1d2838"), Color("#78a6d1"), 1, 6, 4))
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	slot.add_child(pv)

	var top_l := Label.new()
	top_l.text = "📖 明日预读"
	top_l.add_theme_font_size_override("font_size", 10)
	top_l.add_theme_color_override("font_color", Color("#a9d6e5"))
	pv.add_child(top_l)

	var names := PackedStringArray()
	for c in preview_codes:
		var meta := _get_tactical_card_meta(str(c))
		names.append(str(meta.get("name", str(c))))
	var list_l := Label.new()
	list_l.text = " / ".join(names)
	list_l.add_theme_font_size_override("font_size", 10 if preview_codes.size() >= 3 else 11)
	list_l.add_theme_color_override("font_color", Color("#f6efe2"))
	list_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_l.clip_text = true
	list_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(list_l)

	var tag_l := Label.new()
	tag_l.text = "只看不出"
	tag_l.add_theme_font_size_override("font_size", 9)
	tag_l.add_theme_color_override("font_color", Color("#93b4d1"))
	pv.add_child(tag_l)

	var joined := "、".join(names)
	slot.tooltip_text = "【书房特权】明日抽牌必定包含：%s（今日仅预览，不占位不耗手牌）" % joined
	slot.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			_toast("📖 明日预读手牌：%s（书房特权，明日入手）" % joined)
	)
	return slot

func _create_single_hand_card(idx: int, cdata: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 68)
	
	var c_type := str(cdata.get("type", "advance"))
	var c_code := str(cdata.get("code", ""))
	var is_played := bool(cdata.get("is_played", false))
	var is_discarded := bool(cdata.get("is_discarded", false))
	
	# 四态去色高反差视觉设计（裁切九宫格 12px 透明空白外缘，严格适配 ~70px 紧凑手牌栏）
	var patch_path := "res://assets/art/ui/card_frame_ninepatch.png"
	if ResourceLoader.exists(patch_path):
		var nine_sb := StyleBoxTexture.new()
		nine_sb.texture = load(patch_path)
		nine_sb.region_rect = Rect2(13, 12, 231, 360)
		nine_sb.texture_margin_left = 14
		nine_sb.texture_margin_top = 14
		nine_sb.texture_margin_right = 14
		nine_sb.texture_margin_bottom = 14
		nine_sb.content_margin_left = 8
		nine_sb.content_margin_right = 8
		nine_sb.content_margin_top = 7
		nine_sb.content_margin_bottom = 5
		if is_played:
			nine_sb.modulate_color = Color("#756858") # 已出：暗金古铜
		elif is_discarded:
			nine_sb.modulate_color = Color("#5f4e40") # 弃用：幽暗纯黑
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
	vb.add_theme_constant_override("separation", 1)
	card.add_child(vb)

	# 顶部标题栏（战术图标 + 卡名 + 状态徽标 + 详情按钮）
	var h_title := HBoxContainer.new()
	h_title.add_theme_constant_override("separation", 3)
	vb.add_child(h_title)

	# 12 张战术图标
	var tac_path := "res://assets/art/tactics/tactics_%s.png" % c_code
	if ResourceLoader.exists(tac_path):
		var tac_icon := TextureRect.new()
		tac_icon.texture = load(tac_path)
		tac_icon.custom_minimum_size = Vector2(15, 15)
		tac_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tac_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tac_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h_title.add_child(tac_icon)

	var name_l := Label.new()
	var fallback_prefix := "" if ResourceLoader.exists(tac_path) else str(cdata.get("icon", "")) + " "
	name_l.text = "%s%s" % [fallback_prefix, cdata.get("name", "")]
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_played:
		name_l.add_theme_color_override("font_color", Color("#ffd700"))
	elif is_discarded:
		name_l.add_theme_color_override("font_color", Color("#f0e0c8"))
	else:
		name_l.add_theme_color_override("font_color", Color("#1e1712"))
	name_l.add_theme_font_size_override("font_size", 12)
	h_title.add_child(name_l)

	var state_badge := Label.new()
	if is_played:
		state_badge.text = "[已出]"
		state_badge.add_theme_color_override("font_color", Color("#b7f0ce"))
	elif is_discarded:
		state_badge.text = "[弃用]"
		state_badge.add_theme_color_override("font_color", Color("#f2d2b8"))
	else:
		state_badge.text = "[可出]"
		state_badge.add_theme_color_override("font_color", Color("#276f57"))
	state_badge.add_theme_font_size_override("font_size", 11)
	h_title.add_child(state_badge)

	var info_btn := Button.new()
	info_btn.text = "i"
	info_btn.custom_minimum_size = Vector2(16, 16)
	info_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_btn.add_theme_font_size_override("font_size", 10)
	info_btn.add_theme_color_override("font_color", Color("#ffffff"))
	info_btn.add_theme_stylebox_override("normal", _style(Color("#3273dc"), Color("#70a9ff"), 1, 3, 0))
	info_btn.add_theme_stylebox_override("hover", _style(Color("#4788ef"), Color("#99c2ff"), 1, 3, 0))
	info_btn.add_theme_stylebox_override("pressed", _style(Color("#255bb5"), Color("#70a9ff"), 1, 3, 0))
	info_btn.pressed.connect(func(): _show_card_tooltip(cdata, card.global_position))
	h_title.add_child(info_btn)

	# 中部去向 / 战术简效（单行省略，绝不撑高）
	var desc_l := Label.new()
	desc_l.add_theme_font_size_override("font_size", 11)
	desc_l.clip_text = true
	desc_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
		desc_l.add_theme_color_override("font_color", Color("#e0ccb2"))
	else:
		desc_l.text = str(cdata.get("short_desc", "战策就绪"))
		desc_l.add_theme_color_override("font_color", Color("#42352a"))
	vb.add_child(desc_l)

	# 底部主要操作按钮（高度 22px 契合紧凑卡面）
	var assign_btn := Button.new()
	assign_btn.custom_minimum_size = Vector2(0, 22)
	assign_btn.add_theme_font_size_override("font_size", 11)
	
	if is_played:
		assign_btn.text = "↩️ 撤回"
		assign_btn.add_theme_color_override("font_color", Color("#fae19c"))
		assign_btn.add_theme_stylebox_override("normal", _style(Color("#3f3328"), Color("#dfb557"), 1, 4, 1))
		assign_btn.tooltip_text = "点击撤回该队将令，重新谋划出征"
		assign_btn.disabled = false
	elif is_discarded:
		assign_btn.text = "今日不用"
		assign_btn.add_theme_color_override("font_color", Color("#e0ccb2"))
		assign_btn.add_theme_stylebox_override("disabled", _style(Color("#4a3a2e"), Color("#6b5747"), 1, 4, 1))
		assign_btn.tooltip_text = "今日 3 队将令已满，此牌今日不用。撤回任一已出牌后可恢复使用！"
		assign_btn.disabled = true
	else:
		if selected_code != "":
			var tgt_name: String = str(map.node_by_code(selected_code).get("name", selected_code))
			assign_btn.text = "出令➔%s" % tgt_name
			assign_btn.add_theme_color_override("font_color", Color("#fae19c"))
			assign_btn.add_theme_stylebox_override("normal", _style(Color("#38271d"), C_BORDER_GOLD, 1, 4, 1))
			assign_btn.tooltip_text = "点击下达将令向【%s】出征" % tgt_name
		else:
			assign_btn.text = "点城出令"
			assign_btn.add_theme_color_override("font_color", Color("#a89684"))
			assign_btn.add_theme_stylebox_override("normal", _style(Color("#2b211a"), Color("#5a4838"), 1, 4, 1))
			assign_btn.tooltip_text = "请先在地图上点击选择目标城池，再点击出令"
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
		if idx >= 0 and idx < hand_card_views.size():
			_shake_node(hand_card_views[idx])
		AudioManager.play_sfx("click")
		_toast("今日 3 队将令已满，此牌为今日弃牌。请先撤回已出的手牌！", true)
		return

	var target_code := selected_code
	if target_code == "":
		if idx >= 0 and idx < hand_card_views.size():
			_shake_node(hand_card_views[idx])
		AudioManager.play_sfx("click")
		_toast("请先在地图上点击选择目标据点，再点击手牌出令！", true)
		return

	var n_target: Dictionary = map.node_by_code(target_code)
	var cur_w := _current_week()
	if _is_king_node(target_code, n_target) and cur_w < 3:
		_toast("中央帝都长安第 3 周开放，前两周专注于开拓四野！", true)
		if idx >= 0 and idx < hand_card_views.size():
			_shake_node(hand_card_views[idx])
		AudioManager.play_sfx("click")
		return
	if cur_w >= 4 and not _is_changan_or_neighbor(target_code):
		_toast("第 4 周决战周已至，仅可向长安及邻近要冲出征！", true)
		if idx >= 0 and idx < hand_card_views.size():
			_shake_node(hand_card_views[idx])
		AudioManager.play_sfx("click")
		return
	var is_mine_tgt := bool(n_target.get("is_my_faction", false))
	if not is_mine_tgt and not reachable_targets.is_empty() and not reachable_targets.has(target_code):
		_toast("【%s】关河阻隔，不与己方领土相邻，无法出征！" % str(n_target.get("name", target_code)), true)
		if idx >= 0 and idx < hand_card_views.size():
			_shake_node(hand_card_views[idx])
		AudioManager.play_sfx("click")
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
		if idx >= 0 and idx < hand_card_views.size():
			_shake_node(hand_card_views[idx])
		AudioManager.play_sfx("click")
		_toast("今日 3 队将令已满，可点击已出的手牌撤回！", true)
		return

	_play_card_order(chosen_slot, c_code, target_code)

func _play_card_order(slot: int, card_code: String, target_code: String) -> void:
	var comp_types: Array = state.get("composition", {}).get("types", ["cav", "shield", "arc"])
	var unit_type := "cav"
	if slot >= 0 and slot < comp_types.size():
		unit_type = str(comp_types[slot])
	var row_pos := hand_row_override if hand_row_override != "" else ("back" if unit_type == "arc" else "front")
	var lane := hand_lane_override if hand_lane_override > 0 else (slot + 1)
	var req_key := _new_key("p1_t%d_s%d" % [_turn_id(), slot])

	action_status.text = "将令传达中..."
	api.play_card_order(_turn_id(), slot, card_code, target_code, lane, row_pos, req_key, func(ok: bool, _data: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		AudioManager.play_sfx("stamp")
		var card_name := str(_get_tactical_card_meta(card_code).get("name", card_code))
		var target_name := str(map.node_by_code(target_code).get("name", target_code))
		_toast("【%s】将令已下达至【%s】(%d路%s)！" % [card_name, target_name, lane, "后排" if row_pos == "back" else "前排"])
		if tutorial_step == 2:
			_advance_tutorial(3)
		_refresh_state()
		_schedule_forecast_recalc()
	)

func _withdraw_card_order(slot: int) -> void:
	action_status.text = "撤销将令中..."
	api.withdraw_card_order(_turn_id(), slot, func(ok: bool, _data: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		AudioManager.play_sfx("card_withdraw")
		_toast("第 %d 队将令已成功撤回！" % (slot + 1))
		_refresh_state()
		_schedule_forecast_recalc()
	)

func _on_hand_redraw_pressed() -> void:
	if hand_redraw_used:
		_toast("今日重抽机会已用尽！", true)
		return
	if not AudioManager.is_reduced_motion and not hand_card_views.is_empty():
		var fly_tw := create_tween().set_parallel(true)
		for c in hand_card_views:
			if is_instance_valid(c):
				fly_tw.tween_property(c, "position:y", -20.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				fly_tw.tween_property(c, "modulate:a", 0.0, 0.15)
	action_status.text = "请求重新抽取手牌..."
	api.redraw_hand(_turn_id(), func(ok: bool, _data: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		_toast("已消耗重抽机会，生成全新将令手牌！")
		_refresh_state()
		_schedule_forecast_recalc()
	)

func _on_composition_confirmed(types: Array) -> void:
	action_status.text = "提交军团编成中..."
	api.set_composition(_current_week(), types, func(ok: bool, data: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		_toast("军团编成已成功确认保存！")
		var c_used := int(data.get("changes_used", 1 if bool(data.get("changed_once", false)) else 0))
		var c_allowed := int(data.get("changes_allowed", 1))
		if composition_panel:
			composition_panel.set_composition_state(data.get("types", types), bool(data.get("changed_once", false)), c_used, c_allowed)
		_update_army_header_text(c_used, c_allowed)
		_refresh_state()
		_schedule_forecast_recalc()
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
		AudioManager.play_bgm("battle", 0.25)
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
			_schedule_forecast_recalc()
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
	battle_replay_instance.closed.connect(func():
		battle_replay_overlay.visible = false
		AudioManager.play_bgm("map", 0.5)
	)
	battle_replay_instance.replay_finished.connect(_on_battle_replay_finished)
	battle_replay_overlay.add_child(battle_replay_instance)

func _open_battle_replay_demo() -> void:
	if battle_replay_overlay and battle_replay_instance:
		AudioManager.play_bgm("battle", 0.25)
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
	api.next_turn(_turn_id(), func(ok: bool, _d: Dictionary, err: Dictionary):
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

	recharge_info = _label("可用积分：-- | 今日已兑：0/20", 14, INK)
	v.add_child(recharge_info)

	var h := HBoxContainer.new()
	h.add_child(_label("消耗积分数量：", 14, INK))
	recharge_spin = SpinBox.new()
	recharge_spin.min_value = 1
	recharge_spin.max_value = 20
	recharge_spin.value = 5
	h.add_child(recharge_spin)
	v.add_child(h)

	var rate_hint := _label("1 可用积分 = 10 文玉（每日上限 20 积分，不扣 students.score）", 12, MUTED)
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
	var pts := int(wallet.get("available_points", 0))
	var converted := int(wallet.get("today_recharged_points", 0))
	var cap := int(wallet.get("daily_cap_points", 20))
	recharge_info.text = "可用积分：%d | 今日已转：%d/%d 分" % [pts, converted, cap]
	recharge_dialog.popup_centered()

func _do_recharge() -> void:
	var pts := int(recharge_spin.value)
	var req_key := _new_key("rech")
	recharge_confirm.disabled = true
	api.recharge(pts, req_key, func(ok: bool, data: Dictionary, err: Dictionary):
		recharge_confirm.disabled = false
		if not ok:
			_show_error(err)
			return
		recharge_dialog.hide()
		var new_w: Variant = data.get("wallet", {})
		if typeof(new_w) == TYPE_DICTIONARY and not new_w.is_empty():
			wallet = new_w.duplicate(true)
			state["wallet"] = wallet
		var jade_bal := int(wallet.get("jade_balance", int(data.get("jade_added", pts * 10))))
		wallet_label.text = ("💎%d" % jade_bal) if size.y < 650.0 else ("💎 文玉 %d" % jade_bal)
		action_status.text = "成功兑换 %d 文玉！" % int(data.get("jade_added", pts * 10))
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
		body = {"username": name_val, "password": pass_val}
	else:
		body = {"name": name_val, "password": pass_val}
	if preferred_game_code != "":
		body["game_code"] = preferred_game_code

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
		_transition_login_to_game()
		_refresh_state()
	)

func _transition_login_to_game() -> void:
	AudioManager.play_bgm("map")
	if AudioManager.is_reduced_motion:
		login_layer.visible = false
		game_layer.visible = true
		game_layer.modulate.a = 1.0
		game_layer.scale = Vector2.ONE
		_check_and_trigger_tutorial()
		return

	game_layer.visible = true
	game_layer.modulate.a = 0.0
	game_layer.pivot_offset = size / 2.0
	game_layer.scale = Vector2(0.98, 0.98)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(login_layer, "modulate:a", 0.0, 0.20)
	tw.tween_property(game_layer, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(game_layer, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		login_layer.visible = false
		login_layer.modulate.a = 1.0
		_check_and_trigger_tutorial()
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
	_navigate_to("S01_MAP")
	_morning_auto_checked = false
	_season_award_auto_checked = false
	bulletin_data = {}
	season_data = {}
	season_history_data = {}
	if morning_modal != null:
		morning_modal.visible = false
	AudioManager.stop_bgm()
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
	var raw_scouted: Variant = data.get("scouted_nodes", [])
	scouted_nodes = raw_scouted if typeof(raw_scouted) == TYPE_ARRAY else []
	var raw_reachable: Variant = data.get("reachable_targets", [])
	reachable_targets = raw_reachable if typeof(raw_reachable) == TYPE_ARRAY else []

	var map_data: Dictionary = data.get("map", {})
	var nodes_arr: Array = map_data.get("nodes", [])
	var n_count := nodes_arr.size()
	var target_script = SliceMapScript if n_count <= 5 else Map12MapScript
	if map == null or map.get_script() != target_script:
		var old_size := map.size if map != null else Vector2(1400, 1000)
		if map != null and is_instance_valid(map):
			map.queue_free()
		map = target_script.new()
		map.size = old_size
		map.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if n_count > 5:
			map.set("hud_safe_mode", true)
		map_world.add_child(map)
		map_world.move_child(map, 0)

	map.setup(map_data)
	if map != null and map.has_method("set_fog_data"):
		map.set_fog_data(scouted_nodes, reachable_targets)
	_update_map_legend(n_count)
	_layout_responsive()

	var turn: Dictionary = data.get("turn", {})
	countdown_seconds = int(turn.get("seconds_remaining", 0))
	countdown_last_msec = Time.get_ticks_msec()

	var role := str(me.get("role", "player"))
	var student_name := str(me.get("name", "学子"))
	title_label.text = student_name
	var jade_cnt := int(wallet.get("jade_balance", wallet.get("jade", 0)))
	wallet_label.text = ("💎%d" % jade_cnt) if size.y < 650.0 else ("💎 文玉 %d" % jade_cnt)

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

	# Phase 1: 同步军团编成 (composition · 动态 changes_allowed)
	var comp_val: Variant = data.get("composition", {})
	var comp_info: Dictionary = comp_val if typeof(comp_val) == TYPE_DICTIONARY else {}
	var comp_types_val: Variant = comp_info.get("types", [])
	var comp_types: Array = comp_types_val if typeof(comp_types_val) == TYPE_ARRAY else []
	var comp_changed_once: bool = bool(comp_info.get("changed_once", false))
	var comp_used: int = int(comp_info.get("changes_used", 1 if comp_changed_once else 0))
	var comp_allowed: int = int(comp_info.get("changes_allowed", 1))
	if composition_panel and not comp_types.is_empty():
		composition_panel.set_composition_state(comp_types, comp_changed_once, comp_used, comp_allowed)
	_update_army_header_text(comp_used, comp_allowed)

	# S02: 同步文房小院 (estate) 与个人军功摘要 (merit)
	var es_val: Variant = data.get("estate", {})
	if typeof(es_val) == TYPE_DICTIONARY and not es_val.is_empty():
		estate_data = es_val.duplicate(true)
	var m_val: Variant = data.get("merit", {})
	if typeof(m_val) == TYPE_DICTIONARY:
		merit_summary_data = m_val.duplicate(true)
	if estate_page != null:
		estate_page.set_estate_state(estate_data, me, merit_summary_data)

	# D6: 同步今日邸报 (bulletin)
	var bul_val: Variant = data.get("bulletin", {})
	if typeof(bul_val) == TYPE_DICTIONARY and not bul_val.is_empty():
		bulletin_data = bul_val.duplicate(true)
	_render_army_bulletin()

	# Phase 1: 同步每日手牌 (hand) 与已出令 (card_orders)
	_sync_hand_and_orders(data)

	# 晨报红点与自动轻弹（首日无战报不弹，让位 3 步教学） + 终局赛季承接检查
	_update_morning_red_dot()
	_maybe_auto_open_morning_report()
	if not _season_award_auto_checked and str(data.get("game", {}).get("status", "")) == "finished" and role == "player":
		_fetch_season_and_history(true)

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
		var cname := str(n.get("name", code))
		var is_reachable: bool = reachable_targets.is_empty() or reachable_targets.has(code)
		if not is_reachable:
			b.tooltip_text = "%s · 不与己方领土相邻" % cname
		else:
			if scouted_nodes.has(code):
				b.tooltip_text = "%s · 👁 已侦察" % cname
			else:
				b.tooltip_text = cname
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
	if not reachable_targets.is_empty() and not reachable_targets.has(code):
		var n: Dictionary = map.node_by_code(code)
		var cname := str(n.get("name", code))
		_toast("【%s】关河阻隔，不与己方领土相邻！" % cname, true)
		if node_buttons.has(code):
			_shake_node(node_buttons[code])
		AudioManager.play_sfx("click")
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

	var c_ords: Variant = state.get("card_orders", [])
	var c_cnt := (c_ords as Array).size() if typeof(c_ords) == TYPE_ARRAY else 0
	if c_cnt > 0:
		my_order_label.text = "📜 今日已出 %d / 3 令（每天最多出 3 令）" % c_cnt
	elif typeof(order) == TYPE_DICTIONARY:
		my_order_label.text = "📜 已出令：【%s】向【%s】" % [str(order.get("origin_name", "")), str(order.get("target_name", ""))]
	else:
		my_order_label.text = "⏳ 今日待命：点击地图城池并用下方手牌出令（每天最多出 3 令）"

func _on_countdown_tick() -> void:
	if not game_layer.visible or countdown_last_msec == 0:
		return
	var left: int = max(0, countdown_seconds - int((Time.get_ticks_msec() - countdown_last_msec) / 1000))
	var is_c := size.y < 650.0
	if left <= 0:
		countdown_label.text = "⏳ 截止" if is_c else "⏳ 已截止，待推演"
	else:
		countdown_label.text = ("⏳ %02d:%02d" % [int(left / 60), left % 60]) if is_c else ("⏳ 距 21:00 锁令: %02d:%02d" % [int(left / 60), left % 60])

func _new_key(prefix: String) -> String:
	return "%s_%d_%d" % [prefix, Time.get_unix_time_from_system(), randi() % 100000]

func _turn_id() -> int:
	return int(state.get("turn", {}).get("id", 0))

func _submit_advance() -> void:
	var tgt := selected_code if selected_code != "" else "N2"
	var hand_cards: Array = state.get("hand", {}).get("cards", [])
	if not hand_cards.is_empty():
		play_card(0, str(hand_cards[0]), tgt)

func _submit_defend() -> void:
	var origin := "A_START"
	for n in state.get("map", {}).get("nodes", []):
		if bool(n.get("is_my_faction", false)):
			origin = str(n.get("code", "A_START"))
			break
	var hand_cards: Array = state.get("hand", {}).get("cards", [])
	if not hand_cards.is_empty():
		play_card(0, str(hand_cards[0]), origin)

func _withdraw_order() -> void:
	var card_ords: Array = state.get("card_orders", []) if typeof(state.get("card_orders", null)) == TYPE_ARRAY else []
	if not card_ords.is_empty():
		var last_ord: Dictionary = card_ords[card_ords.size() - 1]
		_withdraw_card_order(int(last_ord.get("slot", 0)))

# ---------------------------------------------------------------------------
# P0 新增逻辑：晨报自动轻弹/红点 + 今日邸报 2 选 1 + 动态编成标题
# ---------------------------------------------------------------------------

func _open_army_page() -> void:
	_navigate_to("S03_ARMY")
	_fetch_bulletin()

func _update_army_header_text(used: int, allowed: int) -> void:
	if army_header_sub_lbl == null:
		return
	var remain := maxi(0, allowed - used)
	army_header_sub_lbl.text = "4 兵种三队战阵 · 兵源城加成 · 本周可改 %d 次（余 %d 次）" % [allowed, remain]

func _fetch_bulletin() -> void:
	if api == null or api.token == "" or _turn_id() <= 0:
		return
	api.get_bulletin(_turn_id(), func(ok: bool, data: Dictionary, _err: Dictionary):
		if ok and not data.is_empty():
			bulletin_data = data.duplicate(true)
			state["bulletin"] = bulletin_data
			_render_army_bulletin()
			if morning_modal != null and morning_modal.visible:
				morning_modal.set_bulletin_data(bulletin_data, false)
	)

func _choose_bulletin_choice(choice_code: String) -> void:
	if _bulletin_submitting or choice_code == "" or _turn_id() <= 0:
		return
	_bulletin_submitting = true
	if morning_modal != null and morning_modal.visible:
		morning_modal.set_bulletin_data(bulletin_data, true)
	_render_army_bulletin()
	api.choose_bulletin(_turn_id(), choice_code, func(ok: bool, data: Dictionary, err: Dictionary):
		_bulletin_submitting = false
		if not ok:
			_show_error(err)
			if morning_modal != null and morning_modal.visible:
				morning_modal.set_bulletin_data(bulletin_data, false)
			_render_army_bulletin()
			return
		bulletin_data = data.duplicate(true)
		state["bulletin"] = bulletin_data
		_render_army_bulletin()
		if morning_modal != null and morning_modal.visible:
			morning_modal.set_bulletin_data(bulletin_data, false)
		_schedule_forecast_recalc()
		_toast("📜 今日邸报已选定，本回合结算生效！")
	)

func _render_army_bulletin() -> void:
	if army_bulletin_row == null:
		return
	for ch in army_bulletin_row.get_children():
		army_bulletin_row.remove_child(ch)
		ch.queue_free()
	var opts: Variant = bulletin_data.get("options", [])
	var choice := str(bulletin_data.get("choice", "")) if bulletin_data.get("choice", null) != null else ""
	if typeof(opts) != TYPE_ARRAY or (opts as Array).is_empty():
		if army_bulletin_hint_lbl != null:
			army_bulletin_hint_lbl.text = "打开整军页或晨报自动读取今日邸报"
		army_bulletin_row.add_child(_label("今日邸报读取中…（或点击顶部【晨报】查看）", 12, Color("#685848")))
		return
	if army_bulletin_hint_lbl != null:
		army_bulletin_hint_lbl.text = "已选定（21:00 结算前可随时修改）" if choice != "" else "点击下方任意一项生效"
	for ov in opts:
		if typeof(ov) != TYPE_DICTIONARY:
			continue
		var code := str(ov.get("code", ""))
		var title := str(ov.get("title", code))
		var desc := str(ov.get("desc", ""))
		var icon := str(ov.get("icon", "📜"))
		var is_sel := (code != "" and code == choice)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _panel_style(Color("#ffffff") if is_sel else Color("#efe4d0"), C_ZHUQING if is_sel else Color("#bfa887"), 2 if is_sel else 1, 8, 8))
		army_bulletin_row.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_theme_constant_override("separation", 2)
		row.add_child(tv)
		tv.add_child(_label("%s %s" % [icon, title], 13, C_ZHUQING if is_sel else C_WOOD_DESK))
		tv.add_child(_label(desc, 11, Color("#554433")))
		var b := _button("✓ 已选" if is_sel else "选用", C_ZHUQING if is_sel else C_MOLAN, 32)
		b.custom_minimum_size = Vector2(72, 32)
		b.disabled = _bulletin_submitting
		b.pressed.connect(_choose_bulletin_choice.bind(code))
		row.add_child(b)

func _morning_seen_key() -> String:
	var gid := int(state.get("game", {}).get("id", 1))
	var pname := str(me.get("name", "player")).strip_edges()
	return "%s_%d" % [pname if pname != "" else "player", gid]

func _get_seen_morning_turn_id() -> int:
	var cfg := ConfigFile.new()
	if cfg.load("user://morning_report_seen.cfg") == OK:
		return int(cfg.get_value("seen", _morning_seen_key(), 0))
	return 0

func _mark_morning_turn_seen(turn_id: int) -> void:
	if turn_id <= 0:
		return
	var cfg := ConfigFile.new()
	cfg.load("user://morning_report_seen.cfg")
	var prev := int(cfg.get_value("seen", _morning_seen_key(), 0))
	if turn_id > prev:
		cfg.set_value("seen", _morning_seen_key(), turn_id)
		cfg.save("user://morning_report_seen.cfg")
	_update_morning_red_dot()

func _on_morning_modal_dismissed(turn_id: int) -> void:
	_mark_morning_turn_seen(turn_id)

func _update_morning_red_dot() -> void:
	if hud_morning_btn == null:
		return
	var is_player := (str(me.get("role", "player")) == "player")
	hud_morning_btn.visible = is_player
	if morning_red_dot == null:
		return
	var lr: Variant = state.get("last_report", null)
	var lr_tid := int(lr.get("turn_id", 0)) if typeof(lr) == TYPE_DICTIONARY else 0
	morning_red_dot.visible = is_player and (lr_tid > 0 and lr_tid > _get_seen_morning_turn_id())

func _maybe_auto_open_morning_report() -> void:
	if _morning_auto_checked:
		return
	if str(me.get("role", "player")) != "player":
		return
	# 第一天无战报不弹，让位 3 步教学
	var lr: Variant = state.get("last_report", null)
	if typeof(lr) != TYPE_DICTIONARY:
		return
	var lr_tid := int(lr.get("turn_id", 0))
	if lr_tid <= 0 or lr_tid <= _get_seen_morning_turn_id():
		return
	# 若首次教学浮层正在展示中，也礼让教学
	if tutorial_step > 0 or (tutorial_overlay != null and tutorial_overlay.visible):
		return
	_morning_auto_checked = true
	_open_morning_report(false)

func _open_morning_report(force_show: bool = true) -> void:
	if morning_modal == null:
		return
	var lr_v: Variant = state.get("last_report", null)
	var lr: Dictionary = lr_v if typeof(lr_v) == TYPE_DICTIONARY else {}
	var lr_tid := int(lr.get("turn_id", 0))
	if not force_show and lr_tid <= _get_seen_morning_turn_id():
		return
	morning_modal.open_modal(lr, {}, merit_summary_data, estate_data, _turn_id(), bulletin_data)
	morning_modal.layout_responsive(size)
	_fetch_bulletin()
	if lr_tid > 0 and api != null and api.token != "":
		api.get_me_report(lr_tid, func(ok: bool, mr: Dictionary, _err: Dictionary):
			if ok and not mr.is_empty() and morning_modal != null and morning_modal.visible:
				morning_modal.set_me_report(mr, merit_summary_data, estate_data)
		)

func _show_error(error: Dictionary) -> void:
	print("API ERROR: ", error)
	var code := str(error.get("code", ""))
	var raw_msg := str(error.get("message", "请求失败"))
	var friendly_msg: String = str(ERROR_CODE_TRANSLATION.get(code, raw_msg))
	if code == "ESTATE_INSUFFICIENT_MERIT" and typeof(error.get("details", null)) == TYPE_DICTIONARY and int(error.get("details", {}).get("gap", 0)) > 0:
		friendly_msg = "还差 %d 军功，去出令或支援盟友。" % int(error["details"]["gap"])
	action_status.text = friendly_msg
	_toast(friendly_msg, true)
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
