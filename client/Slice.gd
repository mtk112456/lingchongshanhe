extends Control

## 《青竹文房·灵宠山河》客户端主逻辑
## 商业级手游交互与极简国风界面架构

const FONT_PATH := "res://fonts/NotoSerifCJKsc-Regular.otf"
const SliceMapScript = preload("res://SliceMap.gd")
const ReplayMapScript = preload("res://ReplayMap.gd")

const INK := Color("#1e2a38")
const INK_LIGHT := Color("#4a3e35")
const CREAM := Color("#fffaf0")
const PAPER := Color("#f3ead8")
const CORAL := Color("#b83b32")
const BAMBOO := Color("#276f57")
const GOLD := Color("#d4af37")
const GOLD_LIGHT := Color("#fae19c")
const MUTED := Color("#7e7263")
const DARK := Color("#16120e")

var api: Node
var login_layer: Control
var game_layer: Control
var map: Control
var node_buttons: Dictionary = {}

var state: Dictionary = {}
var me: Dictionary = {}
var wallet: Dictionary = {}
var selected_code := ""
var countdown_seconds := 0
var countdown_last_msec := 0
var polling := false
var api_epoch := 0
var order_submitting := false

# 全局悬浮提示 Toast
var toast_panel: PanelContainer
var toast_label: Label
var toast_timer := 0.0

# 登录相关节点
var login_panel: Panel
var url_edit: LineEdit
var name_edit: LineEdit
var pass_edit: LineEdit
var login_status: Label
var login_student_btn: Button
var dev_settings_dialog: AcceptDialog

# 顶栏 HUD 节点
var top_bar: Panel
var gold_line: ColorRect
var center_box: HBoxContainer
var right_box: HBoxContainer
var title_label: Label
var faction_label: Label
var wallet_label: Label
var turn_label: Label
var countdown_label: Label
var top_pet_icon: Label

# 底部交互行营令案
var player_box: Control
var pet_banner_label: Label
var my_order_label: Label
var node_info: Label
var turn_hint: Label
var action_status: Label

# 隐式控制（保持自动化测试与状态机兼容）
var origin_select: OptionButton
var target_select: OptionButton

# 核心动作决策按钮
var advance_btn: Button
var defend_btn: Button
var withdraw_btn: Button
var report_btn: Button
var replay_btn: Button
var recharge_btn: Button
var refresh_btn: Button

# 教师专属督军案台
var teacher_box: Control
var lock_btn: Button
var settle_btn: Button
var next_btn: Button
var admin_status_btn: Button

# 弹窗
var report_dialog: AcceptDialog
var report_text: RichTextLabel
var replay_dialog: AcceptDialog
var replay_map: Control
var replay_turn_select: OptionButton
var replay_text: RichTextLabel
var replay_data: Dictionary = {}
var recharge_dialog: AcceptDialog
var recharge_spin: SpinBox
var recharge_info: Label
var recharge_confirm: Button

var poll_timer: Timer

func _ready() -> void:
	api = get_node_or_null("/root/Api")
	if api == null:
		var ApiScript = load("res://Api.gd")
		api = ApiScript.new()
		add_child(api)
	_setup_theme()
	_build_login()
	_build_game()
	_build_toast_banner()
	_load_config()
	_layout_responsive()

func _setup_theme() -> void:
	var t := Theme.new()
	var f = load(FONT_PATH)
	if f != null:
		t.default_font = f
	t.default_font_size = 16
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
	return s

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, color: Color, height: int = 42) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color("#ffffff"))
	b.add_theme_color_override("font_disabled_color", Color("#9e9282"))
	b.add_theme_stylebox_override("normal", _style(color, color.darkened(0.2), 1, 8, 10))
	b.add_theme_stylebox_override("hover", _style(color.lightened(0.12), color.darkened(0.2), 1, 8, 10))
	b.add_theme_stylebox_override("pressed", _style(color.darkened(0.15), color.darkened(0.3), 1, 8, 10))
	b.add_theme_stylebox_override("disabled", _style(Color("#8a8074"), Color("#6d6458"), 1, 8, 10))
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_responsive()

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

func _layout_responsive() -> void:
	if map != null:
		map.size = size
	if top_bar != null:
		top_bar.size = Vector2(size.x, 74)
		if gold_line != null:
			gold_line.size = Vector2(size.x, 2)
		if center_box != null:
			center_box.position = Vector2((size.x - center_box.size.x) / 2.0, 14)
		if right_box != null:
			right_box.position = Vector2(size.x - right_box.size.x - 20, 16)
	if player_box != null:
		var bw := minf(size.x - 40.0, 920.0)
		player_box.size = Vector2(bw, 144.0)
		player_box.position = Vector2((size.x - bw) / 2.0, size.y - 160.0)
	if login_panel != null:
		login_panel.position = Vector2((size.x - login_panel.size.x) / 2.0, (size.y - login_panel.size.y) / 2.0)
	if toast_panel != null:
		var tw := minf(size.x - 40.0, 480.0)
		toast_panel.size = Vector2(tw, 46.0)
		toast_panel.position = Vector2((size.x - tw) / 2.0, 78.0)

# ---------------------------------------------------------------------------
# 登录界面（大厂游戏画卷风，剔除调试杂质）
# ---------------------------------------------------------------------------

func _build_login() -> void:
	login_layer = Control.new()
	login_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(login_layer)

	# 1. 案台沉稳深木背景
	var bg := ColorRect.new()
	bg.color = DARK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	login_layer.add_child(bg)

	# 顶部烫金细纹饰条
	var stripe := ColorRect.new()
	stripe.color = GOLD
	stripe.position = Vector2(0, 0)
	stripe.size = Vector2(1400, 5)
	login_layer.add_child(stripe)

	# 2. 居中主画卷卡片
	login_panel = Panel.new()
	login_panel.position = Vector2((size.x - 520) / 2.0, (size.y - 620) / 2.0)
	login_panel.size = Vector2(520, 620)
	login_panel.add_theme_stylebox_override("panel", _style(CREAM, Color("#a8864b"), 3, 16))
	login_layer.add_child(login_panel)
	var panel := login_panel

	# 卡片内金线装饰框
	var inner_box := Panel.new()
	inner_box.position = Vector2(12, 12)
	inner_box.size = Vector2(496, 596)
	inner_box.add_theme_stylebox_override("panel", _style(Color.TRANSPARENT, Color("#cfb995"), 1, 10))
	panel.add_child(inner_box)

	var margin := MarginContainer.new()
	margin.position = Vector2(28, 30)
	margin.size = Vector2(464, 560)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)

	# 印章与游戏标题
	var seal_box := HBoxContainer.new()
	seal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	seal_box.add_theme_constant_override("separation", 8)
	var seal_lbl := _label("青竹文房", 14, CREAM)
	var seal_p := PanelContainer.new()
	seal_p.add_theme_stylebox_override("panel", _style(CORAL, Color("#80241d"), 1, 4, 4))
	seal_p.add_child(seal_lbl)
	seal_box.add_child(seal_p)
	v.add_child(seal_box)

	var title := _label("灵宠山河", 38, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var sub := _label("纸雕国风 · 班宠为将 · 九州沙盘推演", 15, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 10)
	v.add_child(sep)

	# 登录表单：学生只填姓名与密码，不展示学号/网络设置
	name_edit = _line_edit("姓名")
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(name_edit)

	pass_edit = _line_edit("学堂密码")
	pass_edit.secret = true
	pass_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(pass_edit)

	# 主登录按钮（大气质感）
	login_student_btn = _button("踏 入 山 河", CORAL, 48)
	login_student_btn.add_theme_font_size_override("font_size", 18)
	login_student_btn.pressed.connect(_on_login.bind(false))
	v.add_child(login_student_btn)

	# App 只给学生使用；教师入口不放在客户端，后续走 Web 后台。
	login_status = _label("", 13, CORAL)
	login_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	login_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	login_status.custom_minimum_size = Vector2(0, 36)
	v.add_child(login_status)

	var foot := _label("班级量化考核系统联动 · 每日 21:00 全班推演结算", 12, Color("#9e8d76"))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)

	# 右上角极简设置齿轮（收纳开发/测试 URL，保持主屏纯净）
	var gear_btn := Button.new()
	gear_btn.text = "⚙️ 网络设置"
	gear_btn.position = Vector2(1270, 18)
	gear_btn.size = Vector2(110, 34)
	gear_btn.add_theme_font_size_override("font_size", 12)
	gear_btn.add_theme_stylebox_override("normal", _style(Color("#2b221a"), Color("#4d3a2a"), 1, 6, 6))
	gear_btn.add_theme_color_override("font_color", Color("#c4b295"))
	gear_btn.pressed.connect(_open_dev_settings)
	login_layer.add_child(gear_btn)

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
	fill_student.text = "填入学生测试账号"
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

# ---------------------------------------------------------------------------
# 主战场界面（全屏沙盘、顶部 HUD、底部行营令案）
# ---------------------------------------------------------------------------

func _build_game() -> void:
	game_layer = Control.new()
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_layer.visible = false
	add_child(game_layer)

	# 1. 全屏沉浸沙盘地图
	map = SliceMapScript.new()
	map.size = Vector2(1400, 1000)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_layer.add_child(map)

	# 2. 沉浸式顶栏 HUD
	top_bar = Panel.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(1400, 74)
	top_bar.add_theme_stylebox_override("panel", _style(INK, GOLD, 0, 0))
	game_layer.add_child(top_bar)
	var top := top_bar

	gold_line = ColorRect.new()
	gold_line.color = GOLD
	gold_line.position = Vector2(0, 72)
	gold_line.size = Vector2(1400, 2)
	top.add_child(gold_line)

	# 左侧：将领与学子标识
	var avatar_box := Panel.new()
	avatar_box.position = Vector2(18, 13)
	avatar_box.size = Vector2(48, 48)
	avatar_box.add_theme_stylebox_override("panel", _style(CORAL, GOLD, 2, 24))
	top.add_child(avatar_box)
	top_pet_icon = _label("令", 22, CREAM)
	top_pet_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_pet_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_pet_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_box.add_child(top_pet_icon)

	title_label = _label("灵宠山河", 20, CREAM)
	title_label.position = Vector2(76, 12)
	top.add_child(title_label)

	faction_label = _label("青竹军", 13, Color("#dfcaa7"))
	faction_label.position = Vector2(78, 42)
	top.add_child(faction_label)

	# 中间：战局回合与倒计时药丸
	center_box = HBoxContainer.new()
	center_box.position = Vector2(460, 14)
	center_box.size = Vector2(480, 46)
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 16)
	top.add_child(center_box)

	turn_label = _label("第 1 回合 · 争关", 18, GOLD_LIGHT)
	center_box.add_child(turn_label)

	var timer_pill := PanelContainer.new()
	timer_pill.add_theme_stylebox_override("panel", _style(Color("#0f161e"), Color("#5a4833"), 1, 14, 6))
	countdown_label = _label("⏳ 距 21:00 锁令: --:--", 14, Color("#f3ead8"))
	timer_pill.add_child(countdown_label)
	center_box.add_child(timer_pill)

	# 右侧：资产与快捷功能按键
	right_box = HBoxContainer.new()
	right_box.position = Vector2(980, 16)
	right_box.size = Vector2(400, 42)
	right_box.alignment = BoxContainer.ALIGNMENT_END
	right_box.add_theme_constant_override("separation", 8)
	top.add_child(right_box)

	# 资产药丸
	var wallet_pill := PanelContainer.new()
	wallet_pill.add_theme_stylebox_override("panel", _style(Color("#26323d"), GOLD, 1, 14, 6))
	wallet_label = _label("💎 文玉 0", 14, GOLD_LIGHT)
	wallet_pill.add_child(wallet_label)
	right_box.add_child(wallet_pill)

	recharge_btn = _button("+", GOLD, 42)
	recharge_btn.custom_minimum_size = Vector2(44, 42)
	recharge_btn.tooltip_text = "积分兑换文玉"
	recharge_btn.pressed.connect(_open_recharge)
	right_box.add_child(recharge_btn)

	report_btn = _button("📜 战报", Color("#8f3229"), 42)
	report_btn.custom_minimum_size = Vector2(88, 42)
	report_btn.pressed.connect(_open_report)
	right_box.add_child(report_btn)

	replay_btn = _button("🔄 回放", Color("#33485c"), 42)
	replay_btn.custom_minimum_size = Vector2(88, 42)
	replay_btn.pressed.connect(_open_replay)
	right_box.add_child(replay_btn)

	var logout_btn := _button("🚪", Color("#3d2f26"), 42)
	logout_btn.custom_minimum_size = Vector2(44, 42)
	logout_btn.tooltip_text = "退出登录"
	logout_btn.pressed.connect(_on_logout)
	right_box.add_child(logout_btn)

	# 3. 底部轻量交互令案（取代粗笨的右侧面板）
	_build_bottom_command_dock()

	# 4. 教师控制悬浮案台
	_build_teacher_deck()

	# 5. 弹窗与定时器
	_build_report_dialog()
	_build_replay_dialog()
	_build_recharge_dialog()

	poll_timer = Timer.new()
	poll_timer.wait_time = 5.0
	poll_timer.timeout.connect(_refresh_state)
	add_child(poll_timer)

# 构建底部悬浮行营令案（现代手游 SLG 底部交互抽屉）
func _build_bottom_command_dock() -> void:
	player_box = Panel.new()
	player_box.position = Vector2(250, 830)
	player_box.size = Vector2(900, 140)
	player_box.add_theme_stylebox_override("panel", _style(CREAM, Color("#a8864b"), 2, 14))
	game_layer.add_child(player_box)

	var margin := MarginContainer.new()
	margin.position = Vector2(16, 12)
	margin.size = Vector2(868, 116)
	player_box.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	margin.add_child(v)

	# 上排：出战灵宠信息 + 当前选中的目标城池
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	v.add_child(top_row)

	pet_banner_label = _label("出战灵宠：--", 15, BAMBOO)
	top_row.add_child(pet_banner_label)

	node_info = _label("点击地图上的城池下达军令", 14, INK_LIGHT)
	node_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(node_info)

	action_status = _label("", 13, CORAL)
	top_row.add_child(action_status)

	var sep := HSeparator.new()
	v.add_child(sep)

	# 下排：军令状态摘要 + 决策行动按键组
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	v.add_child(bottom_row)

	my_order_label = _label("今日待命：点击地图上相邻城池下达军令", 14, INK)
	my_order_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(my_order_label)

	# 核心军令按钮（鲜明直接，告别下拉选单）
	advance_btn = _button("⚔️ 进军攻打", CORAL, 42)
	advance_btn.custom_minimum_size = Vector2(130, 42)
	advance_btn.pressed.connect(_submit_advance)
	bottom_row.add_child(advance_btn)

	defend_btn = _button("🛡️ 驻守据点", BAMBOO, 42)
	defend_btn.custom_minimum_size = Vector2(130, 42)
	defend_btn.pressed.connect(_submit_defend)
	bottom_row.add_child(defend_btn)

	withdraw_btn = _button("撤销军令", Color("#6e6456"), 42)
	withdraw_btn.custom_minimum_size = Vector2(100, 42)
	withdraw_btn.pressed.connect(_withdraw_order)
	bottom_row.add_child(withdraw_btn)

	# 隐藏的内部控件（保持与原接口及自动化测试 100% 兼容）
	origin_select = OptionButton.new()
	origin_select.visible = false
	origin_select.item_selected.connect(_on_origin_changed)
	player_box.add_child(origin_select)

	target_select = OptionButton.new()
	target_select.visible = false
	target_select.item_selected.connect(_on_target_changed)
	player_box.add_child(target_select)

	turn_hint = _label("", 12, MUTED)
	turn_hint.visible = false
	player_box.add_child(turn_hint)

	refresh_btn = Button.new()
	refresh_btn.visible = false
	refresh_btn.pressed.connect(_refresh_state)
	player_box.add_child(refresh_btn)

# 构建教师专属督军案台（抽屉式设计，不污染学生视角）
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

# ---------------------------------------------------------------------------
# 战报、回放与充值弹窗
# ---------------------------------------------------------------------------

func _build_report_dialog() -> void:
	report_dialog = AcceptDialog.new()
	report_dialog.title = "📜 战报演播卷轴"
	report_dialog.ok_button_text = "掩卷"
	report_dialog.min_size = Vector2i(940, 700)
	report_text = RichTextLabel.new()
	report_text.bbcode_enabled = true
	report_text.custom_minimum_size = Vector2(900, 640)
	report_text.scroll_active = true
	report_text.add_theme_font_size_override("normal_font_size", 15)
	report_dialog.add_child(report_text)
	add_child(report_dialog)

func _build_replay_dialog() -> void:
	replay_dialog = AcceptDialog.new()
	replay_dialog.title = "🔄 沙盘战况复盘"
	replay_dialog.ok_button_text = "知悉关闭"
	replay_dialog.min_size = Vector2i(920, 720)

	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(880, 650)
	v.add_theme_constant_override("separation", 8)
	replay_dialog.add_child(v)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_label("回合：", 15, INK))
	replay_turn_select = OptionButton.new()
	replay_turn_select.custom_minimum_size = Vector2(180, 42)
	replay_turn_select.add_theme_stylebox_override("normal", _style(Color("#fffdf8"), Color("#c9b99a"), 1, 7, 6))
	replay_turn_select.item_selected.connect(_render_replay_turn)
	row.add_child(replay_turn_select)
	var prev_btn := _button("◀ 上一候", Color("#55493b"), 42)
	prev_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_btn.pressed.connect(_step_replay.bind(-1))
	row.add_child(prev_btn)
	var next_btn_rep := _button("下一候 ▶", Color("#55493b"), 42)
	next_btn_rep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn_rep.pressed.connect(_step_replay.bind(1))
	row.add_child(next_btn_rep)
	v.add_child(row)

	replay_map = ReplayMapScript.new()
	replay_map.custom_minimum_size = Vector2(880, 390)
	replay_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(replay_map)

	replay_text = RichTextLabel.new()
	replay_text.bbcode_enabled = true
	replay_text.custom_minimum_size = Vector2(880, 190)
	replay_text.scroll_active = true
	replay_text.add_theme_font_size_override("normal_font_size", 14)
	v.add_child(replay_text)

	add_child(replay_dialog)

func _build_recharge_dialog() -> void:
	recharge_dialog = AcceptDialog.new()
	recharge_dialog.title = "积分兑换文玉"
	recharge_dialog.min_size = Vector2i(480, 320)
	recharge_dialog.get_ok_button().visible = false
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(430, 240)
	v.add_theme_constant_override("separation", 10)
	recharge_dialog.add_child(v)

	v.add_child(_label("将班级量化考核可用积分兑换为游戏文玉", 15, INK))
	v.add_child(_label("比例：1 积分 = 10 文玉；每日兑换上限 20 积分。", 13, MUTED))

	recharge_info = _label("", 14, Color("#3f3a33"))
	v.add_child(recharge_info)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_label("兑换积分数：", 14, INK))
	recharge_spin = SpinBox.new()
	recharge_spin.min_value = 1
	recharge_spin.max_value = 20
	recharge_spin.value = 5
	recharge_spin.step = 1
	recharge_spin.custom_minimum_size = Vector2(120, 38)
	row.add_child(recharge_spin)
	v.add_child(row)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	recharge_confirm = _button("立即兑换", GOLD, 42)
	recharge_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recharge_confirm.pressed.connect(_do_recharge)
	btn_row.add_child(recharge_confirm)

	var cancel_btn := _button("取消", Color("#6b7280"), 42)
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(func(): recharge_dialog.hide())
	btn_row.add_child(cancel_btn)
	v.add_child(btn_row)

	add_child(recharge_dialog)

# ---------------------------------------------------------------------------
# 快捷测试与持久化
# ---------------------------------------------------------------------------

func _fill_test_student() -> void:
	name_edit.text = "青竹一"
	pass_edit.text = "slice2026"

func _use_local_forward() -> void:
	url_edit.text = "http://127.0.0.1:8080"

func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://slice.cfg") == OK:
		url_edit.text = cfg.get_value("net", "url", "http://127.0.0.1:8080")
		name_edit.text = cfg.get_value("auth", "name", "")
		# 不持久化密码：只保存服务器和姓名。
		pass_edit.text = ""
	api.set_base_url(url_edit.text)

func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("net", "url", url_edit.text)
	cfg.set_value("auth", "name", name_edit.text)
	cfg.save("user://slice.cfg")

func _set_login_busy(busy: bool) -> void:
	login_student_btn.disabled = busy
	name_edit.editable = not busy
	pass_edit.editable = not busy
	login_status.text = "正在推开山河画卷..." if busy else ""

# ---------------------------------------------------------------------------
# 业务逻辑与状态映射
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
				_logout_local("登录已过期，请重新登堂")
				return
			action_status.text = str(err.get("message", "获取战局失败"))
			_toast(str(err.get("message", "获取战局失败")), true)
			return
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
	title_label.text = str(data.get("game", {}).get("name", "灵宠山河"))
	countdown_seconds = int(turn.get("seconds_remaining", 0))
	countdown_last_msec = Time.get_ticks_msec()
	var deadline_passed := str(turn.get("status", "")) == "open" and countdown_seconds <= 0
	turn_label.text = "第 %d 候 · %s" % [
		int(turn.get("turn_no", 1)),
		"已截止" if deadline_passed else str(turn.get("status_label", "")),
	]

	var role := str(me.get("role", "player"))
	var faction: Variant = me.get("faction", null)
	if role == "teacher":
		faction_label.text = "👑 师长督军巡视"
		wallet_label.text = "师长视角"
		pet_banner_label.text = "督军掌令印"
	else:
		var pet_name := str(me.get("pet_name", "灵宠"))
		top_pet_icon.text = pet_name.substr(0, 1)
		if typeof(faction) == TYPE_DICTIONARY:
			faction_label.text = "%s阵营 · %s" % [str(faction.get("name", "")), str(me.get("nickname", ""))]
		else:
			faction_label.text = str(me.get("nickname", ""))
		pet_banner_label.text = "⚔️ 出战灵宠：【%s】(战力 1000)" % pet_name
		wallet_label.text = "💎 文玉 %d" % int(wallet.get("jade_balance", 0))

	var nodes: Array = map_data.get("nodes", [])
	if selected_code == "" or map.node_by_code(selected_code).is_empty():
		selected_code = _default_node_code(nodes, role)
	map.set_selected(selected_code)
	map.set_my_order(state.get("my_order", null))

	_rebuild_node_buttons(nodes)
	_populate_origin_options()

	var status := str(turn.get("status", ""))
	match status:
		"open":
			turn_hint.text = "已过截止时间，等待教师锁令。" if deadline_passed else "令行中：21:00 前可自由下令或撤改。"
		"locked":
			turn_hint.text = "军令已锁定，沙盘快照只读，待结算。"
		"settling":
			turn_hint.text = "诸军决胜推演中..."
		"settled":
			turn_hint.text = "本候推演已毕，请掩卷查看战报。"
		_:
			turn_hint.text = str(turn.get("status_label", ""))

	player_box.visible = (role == "player")
	teacher_box.visible = (role == "teacher")
	report_btn.visible = (data.get("last_report", null) != null or status == "settled")
	_update_node_info()
	_update_order_ui()

func _default_node_code(nodes: Array, role: String) -> String:
	if role == "player":
		for n in nodes:
			if bool(n.get("is_my_faction", false)):
				return str(n.get("code", ""))
	if nodes.size() > 0:
		return str(nodes[0].get("code", ""))
	return ""

# 重建透明点击热区（贴合全屏沙盘位置）
func _rebuild_node_buttons(nodes: Array) -> void:
	for b in node_buttons.values():
		if is_instance_valid(b):
			b.queue_free()
	node_buttons.clear()
	for n in nodes:
		var code := str(n.get("code", ""))
		var b := Button.new()
		b.text = ""
		b.size = Vector2(100, 100)
		b.position = map.node_position(code) - Vector2(50, 50)
		b.tooltip_text = str(n.get("name", code))
		b.focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		b.add_theme_stylebox_override("normal", empty)
		b.add_theme_stylebox_override("hover", _style(Color(1, 1, 1, 0.08), GOLD, 2, 50))
		b.add_theme_stylebox_override("pressed", _style(Color(1, 1, 1, 0.15), CORAL, 2, 50))
		b.add_theme_stylebox_override("focus", empty)
		b.pressed.connect(_on_node_pressed.bind(code))
		game_layer.add_child(b)
		node_buttons[code] = b

func _populate_origin_options() -> void:
	var raw_options: Variant = state.get("options", {}).get("advance_from", {})
	var options: Dictionary = raw_options if typeof(raw_options) == TYPE_DICTIONARY else {}
	var keep := _selected_meta(origin_select)
	origin_select.clear()
	for code in options.keys():
		var n: Dictionary = map.node_by_code(str(code))
		var label := str(n.get("name", code))
		var idx := origin_select.item_count
		origin_select.add_item(label)
		origin_select.set_item_metadata(idx, str(code))
	if origin_select.item_count > 0:
		var found := -1
		for i in range(origin_select.item_count):
			if str(origin_select.get_item_metadata(i)) == keep:
				found = i
				break
		origin_select.select(found if found >= 0 else 0)
	_update_targets()

func _on_origin_changed(_idx: int) -> void:
	_update_targets()
	_update_node_info()

func _update_targets() -> void:
	var raw_options: Variant = state.get("options", {}).get("advance_from", {})
	var options: Dictionary = raw_options if typeof(raw_options) == TYPE_DICTIONARY else {}
	var origin_code := _selected_meta(origin_select)
	var targets: Array = options.get(origin_code, []) if origin_code != "" else []
	var keep := _selected_meta(target_select)
	target_select.clear()
	for code in targets:
		var n: Dictionary = map.node_by_code(str(code))
		var label := str(n.get("name", code))
		var idx := target_select.item_count
		target_select.add_item(label)
		target_select.set_item_metadata(idx, str(code))
	if target_select.item_count > 0:
		var found := -1
		for i in range(target_select.item_count):
			if str(target_select.get_item_metadata(i)) == keep:
				found = i
				break
		target_select.select(found if found >= 0 else 0)

func _on_target_changed(_idx: int) -> void:
	var target := _selected_meta(target_select)
	if target != "":
		selected_code = target
		map.set_selected(target)
		_update_node_info()

# 玩家点击地图城池节点：智能识别为进军或驻守目标
func _on_node_pressed(code: String) -> void:
	selected_code = code
	map.set_selected(code)
	var n: Dictionary = map.node_by_code(code)
	var is_mine := bool(n.get("is_my_faction", false))

	if is_mine and origin_select.item_count > 0:
		for i in range(origin_select.item_count):
			if str(origin_select.get_item_metadata(i)) == code:
				origin_select.select(i)
				_update_targets()
				break
	else:
		if target_select.item_count > 0:
			for i in range(target_select.item_count):
				if str(target_select.get_item_metadata(i)) == code:
					target_select.select(i)
					break

	_update_node_info()
	_update_order_ui()

func _selected_meta(opt: OptionButton) -> String:
	var idx := opt.selected
	if idx < 0 or idx >= opt.item_count:
		return ""
	return str(opt.get_item_metadata(idx))

func _update_node_info() -> void:
	var n: Dictionary = map.node_by_code(selected_code)
	if n.is_empty():
		node_info.text = "点击地图城池调度出征"
		return
	var owner: Variant = n.get("owner", null)
	var owner_name := "中立"
	if typeof(owner) == TYPE_DICTIONARY:
		owner_name = str(owner.get("name", "中立")) + "阵营"
	var is_mine := bool(n.get("is_my_faction", false))
	var c_name := str(n.get("name", selected_code))

	if is_mine:
		node_info.text = "选中己方据点【%s】· 归属：%s · 可设为守备或出发地" % [c_name, owner_name]
	else:
		node_info.text = "瞄准目标城池【%s】· 归属：%s · 距己方相邻可发令" % [c_name, owner_name]

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
	origin_select.disabled = not can_edit
	target_select.disabled = not can_edit
	advance_btn.disabled = not can_edit or origin_select.item_count == 0 or target_select.item_count == 0
	defend_btn.disabled = not can_edit or origin_select.item_count == 0
	var order: Variant = state.get("my_order", null)
	withdraw_btn.disabled = not can_edit or typeof(order) != TYPE_DICTIONARY
	recharge_btn.disabled = (role != "player")

	map.set_my_order(order)

	if typeof(order) == TYPE_DICTIONARY:
		my_order_label.text = "📜 军令已下：【%s】向【%s】进军攻打（今夕 21:00 锁令前可随时撤改）" % [
			str(order.get("origin_name", "")),
			str(order.get("target_name", "")),
		] if str(order.get("action", "")) == "advance" else "🛡️ 军令已下：驻守【%s】据点（防守守备 +1）" % str(order.get("target_name", ""))
	else:
		my_order_label.text = "⏳ 今日待命：点击地图城池下令（未下令时默认驻守己方起点）"

func _on_countdown_tick() -> void:
	if not game_layer.visible or countdown_last_msec == 0:
		return
	var left: int = max(0, countdown_seconds - int((Time.get_ticks_msec() - countdown_last_msec) / 1000))
	if left <= 0:
		countdown_label.text = "⏳ 已截止，待推演"
		if player_box.visible:
			advance_btn.disabled = true
			defend_btn.disabled = true
			withdraw_btn.disabled = true
	else:
		countdown_label.text = "⏳ 距 21:00 锁令: %02d:%02d" % [int(left / 60), left % 60]

func _process(delta: float) -> void:
	_on_countdown_tick()
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0 and toast_panel != null:
			toast_panel.visible = false

# ---------------------------------------------------------------------------
# 军令提交与回写
# ---------------------------------------------------------------------------

func _new_key(prefix: String) -> String:
	return "%s_%d_%d" % [prefix, Time.get_unix_time_from_system(), randi() % 100000]

func _turn_id() -> int:
	return int(state.get("turn", {}).get("id", 0))

func _submit_advance() -> void:
	if order_submitting:
		return
	if origin_select.item_count > 0 and (origin_select.selected < 0 or _selected_meta(origin_select) == ""):
		origin_select.select(0)
		_update_targets()
	if target_select.item_count > 0 and (target_select.selected < 0 or _selected_meta(target_select) == ""):
		target_select.select(0)
	var origin := _selected_meta(origin_select)
	var target := _selected_meta(target_select)
	if origin == "" or target == "":
		action_status.text = "请先选择出发据点与进军目标。"
		_toast("请先选择出发据点与进军目标。", true)
		return
	order_submitting = true
	_update_order_ui()
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
			_update_order_ui()
			return
		action_status.text = "军令已盖印！"
		_toast("进军军令已加盖军印！")
		state["my_order"] = data.get("order", {})
		_update_order_ui()
	)

func _submit_defend() -> void:
	if order_submitting:
		return
	if origin_select.item_count > 0 and (origin_select.selected < 0 or _selected_meta(origin_select) == ""):
		origin_select.select(0)
	var origin := _selected_meta(origin_select)
	if origin == "":
		if selected_code != "":
			var n: Dictionary = map.node_by_code(selected_code)
			if bool(n.get("is_my_faction", false)):
				origin = selected_code
		if origin == "":
			for n in state.get("map", {}).get("nodes", []):
				if bool(n.get("is_my_faction", false)):
					origin = str(n.get("code", ""))
					break
	if origin == "":
		action_status.text = "请先选择驻守城池。"
		_toast("请先选择驻守城池。", true)
		return
	order_submitting = true
	_update_order_ui()
	action_status.text = "传达军令中..."
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
			_update_order_ui()
			return
		action_status.text = "坚守军令已定！"
		_toast("守备军令已加盖军印！")
		state["my_order"] = data.get("order", {})
		_update_order_ui()
	)

func _withdraw_order() -> void:
	if order_submitting:
		return
	order_submitting = true
	_update_order_ui()
	action_status.text = "撤销中..."
	api.request("POST", "/api/slice/orders/withdraw", {
		"turn_id": _turn_id(),
	}, func(ok: bool, _data: Dictionary, err: Dictionary):
		order_submitting = false
		if not ok:
			_show_error(err)
			_update_order_ui()
			return
		action_status.text = "军令已撤回。"
		_toast("军令已成功撤回。")
		state.erase("my_order")
		_update_order_ui()
	)

func _show_error(error: Dictionary) -> void:
	var code := str(error.get("code", ""))
	var msg := str(error.get("message", "请求失败"))
	action_status.text = msg
	_toast(msg, true)
	if code == "UNAUTHORIZED" or code == "SESSION_EXPIRED":
		_logout_local("凭据已失效，请重新登录")

# ---------------------------------------------------------------------------
# 战报与回放
# ---------------------------------------------------------------------------

func _open_report() -> void:
	var last_rep: Variant = state.get("last_report", null)
	var target_turn_id := 0
	if typeof(last_rep) == TYPE_DICTIONARY:
		target_turn_id = int(last_rep.get("turn_id", 0))
	if target_turn_id <= 0:
		if str(state.get("turn", {}).get("status", "")) == "settled":
			target_turn_id = int(state.get("turn", {}).get("id", 0))
	
	if target_turn_id <= 0:
		action_status.text = "暂无已结算回合，暂无战事日报。"
		_toast("暂无已结算回合，暂无战事日报。")
		return

	action_status.text = "正在展开第 %d 候战事日报..." % target_turn_id
	api.request("GET", "/api/slice/report?turn_id=%d" % target_turn_id, null, func(ok: bool, data: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		_show_report(data)
	)

func _show_report(data: Dictionary) -> void:
	var turn: Dictionary = data.get("turn", {})
	var rep: Dictionary = data.get("report", {})
	var summary: Dictionary = rep.get("summary", {})
	var changes: Array = rep.get("node_changes", [])
	var my_rep: Variant = data.get("my_report", null)
	var reports: Array = rep.get("reports", [])

	var b := "[font_size=22][color=#1e3a5f]📜 九州战报 · 第 %d 候[/color][/font_size]\n" % int(turn.get("turn_no", 0))
	b += "[color=#6b5b47]结算时点：%s[/color]\n\n" % str(turn.get("settled_at", "—"))

	if typeof(my_rep) == TYPE_DICTIONARY and not my_rep.is_empty():
		b += "[font_size=17][color=#b83b32]◆ 本军战况[/color][/font_size]\n"
		var desc := str(my_rep.get("readable_text", ""))
		if desc != "":
			b += desc + "\n\n"
		else:
			b += "行动：%s\n结果：%s\n\n" % [str(my_rep.get("description", "")), str(my_rep.get("result_summary", ""))]

	b += "[font_size=17][color=#1e3a5f]◆ 城池易帜动向[/color][/font_size]\n"
	if changes.is_empty():
		b += "本候四野承平，各处城池归属未变。\n\n"
	else:
		for c in changes:
			b += "• [b]%s[/b]：从 [color=#6b7280]%s[/color] 易为 [color=#cf8325]%s[/color]（原因：%s）\n" % [
				str(c.get("node_name", "")),
				str(c.get("prev_owner_name", "中立")),
				str(c.get("new_owner_name", "中立")),
				str(c.get("reason", "交锋定夺")),
			]
		b += "\n"

	b += "[font_size=17][color=#1e3a5f]◆ 军力部署全览[/color][/font_size]\n"
	b += "总计出征灵宠：%d 只 | 进军军令：%d | 驻守军令：%d\n\n" % [
		int(summary.get("total_orders", 0)),
		int(summary.get("advances", 0)),
		int(summary.get("defends", 0)),
	]

	if not reports.is_empty():
		b += "[font_size=17][color=#1e3a5f]◆ 诸生出征详情[/color][/font_size]\n"
		for r in reports:
			b += "• %s（灵宠：%s）在 %s %s\n" % [
				str(r.get("student_name", "")),
				str(r.get("pet_name", "")),
				str(r.get("target_name", "")),
				str(r.get("result_summary", "")),
			]
	report_text.text = b
	if replay_dialog != null and replay_dialog.visible:
		replay_dialog.hide()
	report_dialog.popup_centered()

func _open_replay() -> void:
	action_status.text = "正在调取沙盘推演记录..."
	api.request("GET", "/api/slice/replay", null, func(ok: bool, data: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		_show_replay(data)
	)

func _show_replay(data: Dictionary) -> void:
	replay_data = data
	var turns: Array = data.get("turns", [])
	if turns.is_empty():
		action_status.text = "暂无已结算回合，暂无复盘记录。"
		_toast("暂无已结算回合，暂无战局复盘。")
		return
	replay_turn_select.clear()
	for i in range(turns.size()):
		var no := int(turns[i].get("turn_no", i + 1))
		var idx := replay_turn_select.item_count
		replay_turn_select.add_item("第 %d 候" % no)
		replay_turn_select.set_item_metadata(idx, i)
	replay_turn_select.select(turns.size() - 1)
	_render_replay_turn(turns.size() - 1)
	if report_dialog != null and report_dialog.visible:
		report_dialog.hide()
	replay_dialog.popup_centered()

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
	var nodes: Array = map_info.get("nodes", [])
	var edges: Array = map_info.get("edges", [])
	var raw_owners: Variant = t.get("owners", {})
	var owners: Dictionary = raw_owners if typeof(raw_owners) == TYPE_DICTIONARY else {}
	var changes: Array = t.get("changes", [])
	var changed_codes := {}
	for c in changes:
		changed_codes[str(c.get("node_code", ""))] = true

	replay_map.setup(nodes, edges, owners, changed_codes)

	var b := "[font_size=18][color=#1e3a5f]第 %d 候战况复盘[/color][/font_size]（%s）\n" % [
		int(t.get("turn_no", 0)),
		str(t.get("settled_at", "—")),
	]
	if changes.is_empty():
		b += "本候防线坚固，全域无城池失陷易帜。\n"
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
# 师长督军控制
# ---------------------------------------------------------------------------

func _teacher_lock() -> void:
	action_status.text = "锁令中..."
	api.request("POST", "/api/slice/admin/lock", {"turn_id": _turn_id(), "force": true}, func(ok: bool, _d: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		action_status.text = "已锁定本候军令！"
		_refresh_state()
	)

func _teacher_settle() -> void:
	action_status.text = "推演结算中..."
	api.request("POST", "/api/slice/admin/settle", {"turn_id": _turn_id()}, func(ok: bool, _d: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		action_status.text = "全军推演结算完成！"
		_refresh_state()
	)

func _teacher_next() -> void:
	action_status.text = "开赴下一候..."
	api.request("POST", "/api/slice/admin/next-turn", null, func(ok: bool, _d: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		action_status.text = "新一候已开启！"
		_refresh_state()
	)

func _teacher_status() -> void:
	action_status.text = "刷新督军状态中..."
	api.request("GET", "/api/slice/admin/status", null, func(ok: bool, data: Dictionary, err: Dictionary):
		if not ok:
			_show_error(err)
			return
		var t: Dictionary = data.get("turn", {})
		action_status.text = "第 %d 候 · 状态：%s · 军令数：%d" % [
			int(t.get("turn_no", 0)),
			str(t.get("status", "")),
			int(data.get("order_count", 0)),
		]
	)

# ---------------------------------------------------------------------------
# 积分兑换文玉
# ---------------------------------------------------------------------------

func _open_recharge() -> void:
	var role := str(me.get("role", "player"))
	if role != "player":
		action_status.text = "仅限修习学子兑换文玉。"
		return
	recharge_info.text = "可用积分：%d · 当前持有文玉：%d\n今日已兑：%d / 20 积分" % [
		int(wallet.get("available_points", 0)),
		int(wallet.get("jade_balance", 0)),
		int(wallet.get("today_spent_points", 0)),
	]
	var max_can: int = min(20 - int(wallet.get("today_spent_points", 0)), int(wallet.get("available_points", 0)))
	recharge_spin.max_value = max(1, max_can)
	recharge_spin.value = min(recharge_spin.value, recharge_spin.max_value)
	recharge_confirm.disabled = (max_can <= 0)
	recharge_dialog.popup_centered()

func _do_recharge() -> void:
	var pts := int(recharge_spin.value)
	action_status.text = "文玉结转中..."
	recharge_confirm.disabled = true
	api.request("POST", "/api/slice/points/recharge", {
		"request_key": _new_key("rcg"),
		"points": pts,
	}, func(ok: bool, data: Dictionary, err: Dictionary):
		recharge_confirm.disabled = false
		if not ok:
			_show_error(err)
			return
		recharge_dialog.hide()
		action_status.text = "成功兑换 %d 文玉！" % int(data.get("jade_granted", 0))
		_refresh_state()
	)
