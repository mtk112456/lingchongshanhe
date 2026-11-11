extends Control

## 每日晨报 + 今日邸报 2 选 1 轻弹层
## 触发条件：每天首次登录且 last_report.turn_id > 本地已读 turn_id 时自动轻弹一次（首日无战报不弹，让位 3 步教学）
## 顶部常驻晨报按钮，未读显示红点；关闭即标记已读，仍可随时点击红点/晨报按钮回看或修改邸报。

signal dismissed(turn_id: int)
signal go_estate_requested(turn_id: int)
signal go_map_requested(turn_id: int)
signal bulletin_selected(choice_code: String)

const FONT_PATH := "res://fonts/NotoSerifCJKsc-Regular.otf"

const C_XUANZHI := Color("#f6efe2")
const C_PAPER_WARM := Color("#efe4d0")
const C_WOOD_DESK := Color("#231c17")
const C_MOLAN := Color("#1e3a5f")
const C_ZHUQING := Color("#276f57")
const C_ZHUSHA := Color("#b83b32")
const C_TENGHUANG := Color("#cf8325")
const C_BORDER_GOLD := Color("#c9a227")
const C_CREAM := Color("#f3ead8")
const C_GOLD_LIGHT := Color("#fae19c")

const REPORT_HERO_PATH := "res://assets/art/ui/personal_report_delivery.png"
const C_HERO_CREAM := Color("#fae0c4")

var _font: Font = null
var _scrim: ColorRect
var _modal: PanelContainer
var _scroll: ScrollContainer

var _summary_box: PanelContainer
var _hero_clip: Control
var _hero_tex_rect: TextureRect
var _hero_fade: TextureRect
var _hero_right_band: ColorRect
var _hero_atlas: AtlasTexture
var _hero_tex: Texture2D
var _summary_text_margin: MarginContainer
var _hero_draw_pos: Vector2 = Vector2.ZERO
var _parallax_t: float = 0.0
var _parallax_px: float = 0.0
var _last_compact: bool = false

var _title_lbl: Label
var _headline_lbl: Label
var _me_line_lbl: Label
var _merit_gov_lbl: Label
var _bulletin_hint_lbl: Label
var _bulletin_row: HBoxContainer
var _go_estate_btn: Button
var _go_map_btn: Button

var _current_report_turn_id: int = 0
var _active_turn_id: int = 0
var _bulletin_data: Dictionary = {}
var _bulletin_submitting: bool = false

func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	if ResourceLoader.exists(REPORT_HERO_PATH):
		_hero_tex = load(REPORT_HERO_PATH)
	visible = false
	z_index = 26
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _process(delta: float) -> void:
	if not visible or _hero_tex_rect == null or not _hero_tex_rect.visible:
		return
	if AudioManager.is_reduced_motion or DisplayServer.get_name() == "headless":
		if absf(_parallax_px) > 0.01:
			_parallax_px = 0.0
			_hero_tex_rect.position.x = _hero_draw_pos.x
		return
	_parallax_t += delta
	_parallax_px = sin(_parallax_t * 0.55) * 3.0
	_hero_tex_rect.position.x = _hero_draw_pos.x + _parallax_px

func _style(bg: Color, border: Color = Color.TRANSPARENT, bw: int = 0, radius: int = 8, pad: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	if pad > 0:
		sb.content_margin_left = pad
		sb.content_margin_right = pad
		sb.content_margin_top = pad
		sb.content_margin_bottom = pad
	return sb

func _label(txt: String, sz: int, col: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = txt
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(txt: String, bg: Color, h: int = 40) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(100, h)
	if _font != null:
		b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color("#ffffff"))
	b.add_theme_stylebox_override("normal", _style(bg, C_BORDER_GOLD, 1, 6, 8))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.12), C_GOLD_LIGHT, 1, 6, 8))
	b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.15), C_BORDER_GOLD, 1, 6, 8))
	return b

func _build_ui() -> void:
	_scrim = ColorRect.new()
	_scrim.color = Color(0.06, 0.04, 0.03, 0.68)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_and_mark_read()
	)
	add_child(_scrim)

	_modal = PanelContainer.new()
	_modal.add_theme_stylebox_override("panel", _style(C_XUANZHI, C_BORDER_GOLD, 2, 12, 14))
	_modal.gui_input.connect(func(_ev: InputEvent): accept_event())
	add_child(_modal)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 8)
	_modal.add_child(root_v)

	# 顶部标题与关闭
	var top_r := HBoxContainer.new()
	top_r.add_theme_constant_override("separation", 8)
	root_v.add_child(top_r)

	_title_lbl = _label("☀️ 今日晨报", 18, C_ZHUSHA)
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_r.add_child(_title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 32)
	if _font != null:
		close_btn.add_theme_font_override("font", _font)
	close_btn.add_theme_stylebox_override("normal", _style(Color("#3a2b20"), C_BORDER_GOLD, 1, 6, 2))
	close_btn.add_theme_color_override("font_color", C_CREAM)
	close_btn.pressed.connect(close_and_mark_read)
	top_r.add_child(close_btn)

	root_v.add_child(HSeparator.new())

	# 中部可滚动正文区：上半部画卷摘要卡(左小灵宠捧卷，右云雾留白压文字) + 下半部邸报 2 选 1
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_v.add_child(_scroll)

	var body_v := VBoxContainer.new()
	body_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_v.add_theme_constant_override("separation", 8)
	_scroll.add_child(body_v)

	_summary_box = PanelContainer.new()
	_summary_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_box.clip_contents = true
	_summary_box.custom_minimum_size = Vector2(0, 160)
	_summary_box.add_theme_stylebox_override("panel", _style(C_HERO_CREAM, Color("#cf8325"), 1, 8, 0))
	_summary_box.resized.connect(_layout_summary_art)
	body_v.add_child(_summary_box)

	_hero_clip = Control.new()
	_hero_clip.clip_contents = true
	_hero_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary_box.add_child(_hero_clip)

	_hero_tex_rect = TextureRect.new()
	_hero_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_clip.add_child(_hero_tex_rect)

	_hero_right_band = ColorRect.new()
	_hero_right_band.color = C_HERO_CREAM
	_hero_right_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_clip.add_child(_hero_right_band)

	_hero_fade = TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(C_HERO_CREAM.r, C_HERO_CREAM.g, C_HERO_CREAM.b, 0.0), C_HERO_CREAM])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.width = 64
	gtex.height = 4
	gtex.fill = GradientTexture2D.FILL_LINEAR
	gtex.fill_from = Vector2(0, 0.5)
	gtex.fill_to = Vector2(1, 0.5)
	_hero_fade.texture = gtex
	_hero_fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_fade.stretch_mode = TextureRect.STRETCH_SCALE
	_hero_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_clip.add_child(_hero_fade)

	_summary_text_margin = MarginContainer.new()
	_summary_text_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_text_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary_text_margin.add_theme_constant_override("margin_left", 204)
	_summary_text_margin.add_theme_constant_override("margin_right", 14)
	_summary_text_margin.add_theme_constant_override("margin_top", 10)
	_summary_text_margin.add_theme_constant_override("margin_bottom", 10)
	_summary_box.add_child(_summary_text_margin)

	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.add_theme_constant_override("separation", 6)
	_summary_text_margin.add_child(sv)

	_headline_lbl = _label("昨日战果读取中...", 14, C_WOOD_DESK, true)
	sv.add_child(_headline_lbl)

	_me_line_lbl = _label("个人战报摘要同步中...", 13, Color("#1b5c47"), true)
	sv.add_child(_me_line_lbl)

	_merit_gov_lbl = _label("军功与太守动态同步中...", 12, Color("#4d3c2d"), true)
	sv.add_child(_merit_gov_lbl)

	# 下半屏：今日邸报 2 选 1
	var bul_title_row := HBoxContainer.new()
	bul_title_row.add_theme_constant_override("separation", 8)
	body_v.add_child(bul_title_row)

	var bt := _label("📜 今日邸报密令（2 选 1）", 14, C_MOLAN)
	bul_title_row.add_child(bt)

	_bulletin_hint_lbl = _label("结算前可随时调整", 11, Color("#6e5d4b"))
	_bulletin_hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bulletin_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bul_title_row.add_child(_bulletin_hint_lbl)

	_bulletin_row = HBoxContainer.new()
	_bulletin_row.add_theme_constant_override("separation", 10)
	_bulletin_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_v.add_child(_bulletin_row)

	# 底部双主动作
	var btn_r := HBoxContainer.new()
	btn_r.add_theme_constant_override("separation", 10)
	root_v.add_child(btn_r)

	_go_estate_btn = _button("🏡 去小院", C_ZHUQING, 42)
	_go_estate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_go_estate_btn.pressed.connect(func():
		var tid := _current_report_turn_id
		visible = false
		dismissed.emit(tid)
		go_estate_requested.emit(tid)
	)
	btn_r.add_child(_go_estate_btn)

	_go_map_btn = _button("⚔️ 回沙盘出令", C_ZHUSHA, 42)
	_go_map_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_go_map_btn.pressed.connect(func():
		var tid := _current_report_turn_id
		visible = false
		dismissed.emit(tid)
		go_map_requested.emit(tid)
	)
	btn_r.add_child(_go_map_btn)

func layout_responsive(viewport_size: Vector2) -> void:
	if _modal == null:
		return
	var w := viewport_size.x
	var h := viewport_size.y
	if w <= 0.0 or h <= 0.0:
		return
	_last_compact = (h < 650.0 or w < 900.0)
	var mw := minf(w - 24.0, 672.0 if _last_compact else 736.0)
	var mh := minf(h - 20.0, 488.0 if _last_compact else 592.0)
	_modal.size = Vector2(mw, mh)
	_modal.position = Vector2((w - mw) / 2.0, (h - mh) / 2.0)
	if _summary_box != null:
		_summary_box.custom_minimum_size = Vector2(0, 160.0 if _last_compact else 224.0)
	if _summary_text_margin != null:
		_summary_text_margin.add_theme_constant_override("margin_left", 204 if _last_compact else 290)
	call_deferred("_layout_summary_art")

func _layout_summary_art() -> void:
	if _summary_box == null or _hero_tex_rect == null:
		return
	if _hero_tex == null and ResourceLoader.exists(REPORT_HERO_PATH):
		_hero_tex = load(REPORT_HERO_PATH)
	if _hero_tex == null:
		_hero_tex_rect.visible = false
		return
	var box_w := _summary_box.size.x
	var box_h := maxf(_summary_box.size.y, 160.0 if _last_compact else 224.0)
	if box_w <= 20.0:
		box_w = 640.0 if _last_compact else 704.0

	var tex_w := float(_hero_tex.get_width())
	var tex_h := float(_hero_tex.get_height())
	if _hero_atlas == null:
		_hero_atlas = AtlasTexture.new()
	_hero_atlas.atlas = _hero_tex

	# 手机端使用 AtlasTexture 裁切右上角以外留白并保住竹叶灵宠+毛笔+展开卷轴；平板保留完整左侧场景，100% 不拉伸
	var reg := Rect2(0.0, 14.0, minf(740.0, tex_w), minf(520.0, tex_h - 14.0)) if _last_compact else Rect2(0.0, 0.0, minf(840.0, tex_w), tex_h)
	_hero_atlas.region = reg

	var pad_x := 0.0 if AudioManager.is_reduced_motion else 6.0
	var sc := box_h / reg.size.y
	var draw_size := Vector2(reg.size.x * sc, reg.size.y * sc)
	_hero_draw_pos = Vector2(-pad_x * 0.5, 0.0)

	_hero_tex_rect.texture = _hero_atlas
	_hero_tex_rect.size = draw_size
	_hero_tex_rect.position = Vector2(_hero_draw_pos.x + _parallax_px, _hero_draw_pos.y)
	_hero_tex_rect.visible = true

	var seam_x := _hero_draw_pos.x + draw_size.x
	if _hero_fade != null:
		var fade_w := 60.0 if _last_compact else 76.0
		_hero_fade.position = Vector2(maxf(0.0, seam_x - fade_w), 0.0)
		_hero_fade.size = Vector2(fade_w + 4.0, box_h)
		_hero_fade.visible = true
	if _hero_right_band != null:
		_hero_right_band.position = Vector2(maxf(0.0, seam_x - 2.0), 0.0)
		_hero_right_band.size = Vector2(maxf(0.0, box_w - seam_x + 4.0), box_h)
		_hero_right_band.visible = true

func open_modal(last_report: Dictionary, me_report: Dictionary, merit_summary: Dictionary, estate_summary: Dictionary, active_turn_id: int, bulletin_payload: Dictionary) -> void:
	_current_report_turn_id = int(last_report.get("turn_id", 0))
	_active_turn_id = active_turn_id
	var turn_no := int(last_report.get("turn_no", me_report.get("turn_no", 0)))
	var headline := str(last_report.get("headline", ""))

	if _current_report_turn_id > 0:
		_title_lbl.text = "☀️ 第 %d 候晨报 · 昨夜战报与今日邸报" % maxi(1, turn_no + 1)
		_headline_lbl.text = "【昨日头条】%s" % (headline if headline != "" else "第 %d 回合推演已毕" % maxi(1, turn_no))
	else:
		_title_lbl.text = "☀️ 今日军情晨报 · 备战启程"
		_headline_lbl.text = "【开局第一候】九州战事方兴未艾，尚未有昨日战报；先选一条今日邸报加持出征！"

	# 我的 me_report 一行摘要
	if not me_report.is_empty():
		var hl := str(me_report.get("highlight", "")).strip_edges()
		if hl == "":
			var orders: Array = me_report.get("orders", [])
			if not orders.is_empty() and typeof(orders[0]) == TYPE_DICTIONARY:
				var o0: Dictionary = orders[0]
				var contrib := int(round(float(o0.get("contribution", 0.0)) * 100.0))
				hl = "你在【%s】出征，贡献 %d%%" % [str(o0.get("node_name", "")), contrib]
			else:
				hl = "昨日共下 %d 令" % orders.size()
		_me_line_lbl.text = "我昨日：%s" % hl
	elif _current_report_turn_id > 0:
		_me_line_lbl.text = "我昨日：个人战报摘要同步中..."
	else:
		_me_line_lbl.text = "今日可出令：每天最多出 3 令（牌 + 城 + 路 + 前后排）"

	# 军功 + 太守
	var turn_merit := int(me_report.get("merit", {}).get("turn_total", 0)) if typeof(me_report.get("merit", null)) == TYPE_DICTIONARY else 0
	var total_merit := int(merit_summary.get("total", estate_summary.get("merit_balance", 0)))
	var week_rank := int(merit_summary.get("week_rank", 0))
	var merit_txt := "军功 +%d（累计 %d" % [turn_merit, total_merit]
	if week_rank > 0:
		merit_txt += " · 本周第 %d" % week_rank
	merit_txt += "）"

	var gov_names: Array[String] = []
	var govs: Variant = estate_summary.get("governor_cities", [])
	if typeof(govs) == TYPE_ARRAY:
		for g in govs:
			if typeof(g) == TYPE_DICTIONARY:
				gov_names.append(str(g.get("node_name", g.get("node_code", ""))))
			elif typeof(g) == TYPE_STRING and str(g) != "":
				gov_names.append(str(g))
	var gov_txt := ("太守：" + "、".join(gov_names)) if not gov_names.is_empty() else "太守：争夺中（本城本周贡献第一加封）"
	_merit_gov_lbl.text = "🏆 %s   |   🏯 %s" % [merit_txt, gov_txt]

	set_bulletin_data(bulletin_payload)
	visible = true
	move_to_front()

func set_me_report(me_report: Dictionary, merit_summary: Dictionary, estate_summary: Dictionary) -> void:
	if not visible:
		return
	var last_rep_tmp := {"turn_id": _current_report_turn_id, "turn_no": int(me_report.get("turn_no", 1)), "headline": _headline_lbl.text.replace("【昨日头条】", "")}
	if not me_report.is_empty():
		var hl := str(me_report.get("highlight", "")).strip_edges()
		if hl != "":
			_me_line_lbl.text = "我昨日：%s" % hl
		elif (me_report.get("orders", []) as Array).is_empty():
			_me_line_lbl.text = "我昨日：暂未出战（今日可出满 3 令抢先机）"
	else:
		_me_line_lbl.text = "我昨日：暂未出战（今日可出满 3 令抢先机）"
	var turn_merit := int(me_report.get("merit", {}).get("turn_total", 0)) if typeof(me_report.get("merit", null)) == TYPE_DICTIONARY else 0
	var total_merit := int(merit_summary.get("total", estate_summary.get("merit_balance", 0)))
	var week_rank := int(merit_summary.get("week_rank", 0))
	var merit_txt := "军功 +%d（累计 %d" % [turn_merit, total_merit] + (" · 本周第 %d）" % week_rank if week_rank > 0 else "）")
	var gov_names: Array[String] = []
	var govs: Variant = estate_summary.get("governor_cities", [])
	if typeof(govs) == TYPE_ARRAY:
		for g in govs:
			if typeof(g) == TYPE_DICTIONARY:
				gov_names.append(str(g.get("node_name", g.get("node_code", ""))))
	var gov_txt := ("太守：" + "、".join(gov_names)) if not gov_names.is_empty() else "太守：争夺中"
	_merit_gov_lbl.text = "🏆 %s   |   🏯 %s" % [merit_txt, gov_txt]

func set_bulletin_data(payload: Dictionary, busy: bool = false) -> void:
	_bulletin_data = payload.duplicate(true)
	_bulletin_submitting = busy
	for ch in _bulletin_row.get_children():
		_bulletin_row.remove_child(ch)
		ch.queue_free()

	var options: Array = _bulletin_data.get("options", [])
	var choice := str(_bulletin_data.get("choice", "")) if _bulletin_data.get("choice", null) != null else ""

	if options.is_empty():
		_bulletin_hint_lbl.text = "同步中..."
		_bulletin_row.add_child(_label("正在读取今日邸报两项秘策...", 12, Color("#6e5d4b"), true))
		return

	_bulletin_hint_lbl.text = "已选定（结算前可随时点击切换）" if choice != "" else "点击下方任意一项生效"

	for opt_v in options:
		if typeof(opt_v) != TYPE_DICTIONARY:
			continue
		var code := str(opt_v.get("code", ""))
		var title := str(opt_v.get("title", code))
		var desc := str(opt_v.get("desc", ""))
		var icon := str(opt_v.get("icon", "📜"))
		var is_sel := (code != "" and code == choice)

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _style(
			Color("#ffffff") if is_sel else C_PAPER_WARM,
			C_ZHUQING if is_sel else Color("#bfa887"),
			2 if is_sel else 1,
			8,
			10
		))
		_bulletin_row.add_child(card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		card.add_child(cv)

		cv.add_child(_label("%s %s" % [icon, title], 14, C_ZHUQING if is_sel else C_WOOD_DESK))
		cv.add_child(_label(desc, 12, Color("#4a3b2e"), true))

		var pick_btn := Button.new()
		pick_btn.custom_minimum_size = Vector2(0, 32)
		if _font != null:
			pick_btn.add_theme_font_override("font", _font)
		pick_btn.add_theme_font_size_override("font_size", 12)
		pick_btn.disabled = _bulletin_submitting
		if is_sel:
			pick_btn.text = "✓ 今日已选"
			pick_btn.add_theme_color_override("font_color", Color("#ffffff"))
			pick_btn.add_theme_stylebox_override("normal", _style(C_ZHUQING, C_GOLD_LIGHT, 1, 5, 4))
		else:
			pick_btn.text = "选择此邸报"
			pick_btn.add_theme_color_override("font_color", C_CREAM)
			pick_btn.add_theme_stylebox_override("normal", _style(C_MOLAN, C_BORDER_GOLD, 1, 5, 4))
		pick_btn.pressed.connect(func():
			if not _bulletin_submitting:
				bulletin_selected.emit(code)
		)
		cv.add_child(pick_btn)

func close_and_mark_read() -> void:
	if not visible:
		return
	var tid := _current_report_turn_id
	visible = false
	dismissed.emit(tid)
