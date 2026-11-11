extends Control

## S10 赛季史书与终局颁奖页面
## 接入：GET /api/slice/season + GET /api/slice/season/history
## 支持：进行中（周次 / 长安倒计时 / 四阵营版图 / 四周史书）与 终局颁奖（占长安或第 28 回合 finished）

signal back_to_map_requested
signal refresh_requested

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

const FACTION_COLORS := {
	"bi": Color("#b83b32"),
	"mo": Color("#1e3a5f"),
	"yan": Color("#276f57"),
	"zhi": Color("#cf8325"),
	"neutral": Color("#7a7066"),
}

var _font: Font = null

var header_bar: Panel
var header_sub_lbl: Label
var header_refresh_btn: Button

var body_margin: MarginContainer
var scroll: ScrollContainer
var content_vbox: VBoxContainer

var award_card: PanelContainer
var award_banner_lbl: Label
var award_reason_lbl: Label
var award_me_lbl: Label

var overview_card: PanelContainer
var week_title_lbl: Label
var changan_lbl: Label
var changan_bar: ProgressBar
var factions_vbox: VBoxContainer

var history_vbox: VBoxContainer

var season_data: Dictionary = {}
var history_data: Dictionary = {}
var merit_data: Dictionary = {}
var game_data: Dictionary = {}
var me_data: Dictionary = {}

func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	_build_ui()
	render_loading()

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

func _button(txt: String, bg: Color, h: int = 38) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(90, h)
	if _font != null:
		b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", C_CREAM)
	b.add_theme_stylebox_override("normal", _style(bg, C_BORDER_GOLD, 1, 6, 6))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.12), C_GOLD_LIGHT, 1, 6, 6))
	b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.15), C_BORDER_GOLD, 1, 6, 6))
	return b

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_WOOD_DESK.darkened(0.18)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 顶部统一页头 (64px)
	header_bar = Panel.new()
	header_bar.position = Vector2.ZERO
	header_bar.size = Vector2(size.x, 64)
	header_bar.add_theme_stylebox_override("panel", _style(Color("#1e1611"), C_BORDER_GOLD, 1, 0, 0))
	add_child(header_bar)

	var h_margin := MarginContainer.new()
	h_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h_margin.add_theme_constant_override("margin_left", 14)
	h_margin.add_theme_constant_override("margin_right", 14)
	header_bar.add_child(h_margin)

	var h_row := HBoxContainer.new()
	h_row.add_theme_constant_override("separation", 12)
	h_margin.add_child(h_row)

	var back_btn := _button("← 返回沙盘", Color("#423429"), 38)
	back_btn.custom_minimum_size = Vector2(104, 38)
	back_btn.pressed.connect(func(): back_to_map_requested.emit())
	h_row.add_child(back_btn)

	var title_lbl := _label("🏆 九州赛季史书", 18, C_GOLD_LIGHT)
	h_row.add_child(title_lbl)

	header_sub_lbl = _label("加载赛季态势中...", 13, Color("#c9b697"))
	header_sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_sub_lbl.clip_text = true
	header_sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h_row.add_child(header_sub_lbl)

	header_refresh_btn = _button("↻ 刷新", C_MOLAN, 34)
	header_refresh_btn.custom_minimum_size = Vector2(82, 34)
	header_refresh_btn.pressed.connect(func(): refresh_requested.emit())
	h_row.add_child(header_refresh_btn)

	body_margin = MarginContainer.new()
	body_margin.position = Vector2(16, 70)
	body_margin.size = Vector2(maxf(320.0, size.x - 32), maxf(220.0, size.y - 136))
	add_child(body_margin)

	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body_margin.add_child(scroll)

	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(content_vbox)

	# 1. 终局颁奖横幅（仅 season_over == true 或 game.status == "finished" 时展开）
	award_card = PanelContainer.new()
	award_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	award_card.add_theme_stylebox_override("panel", _style(Color("#3a1b16"), C_GOLD_LIGHT, 2, 10, 14))
	award_card.visible = false
	content_vbox.add_child(award_card)

	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 6)
	award_card.add_child(av)

	award_banner_lbl = _label("👑 赛季终局颁奖 · 九州问鼎", 18, C_GOLD_LIGHT, true)
	av.add_child(award_banner_lbl)
	award_reason_lbl = _label("", 14, C_CREAM, true)
	av.add_child(award_reason_lbl)
	award_me_lbl = _label("", 13, Color("#d9e8dc"), true)
	av.add_child(award_me_lbl)

	# 2. 赛季总览 & 长安进度 & 四阵营实时版图
	overview_card = PanelContainer.new()
	overview_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_card.add_theme_stylebox_override("panel", _style(C_XUANZHI, C_BORDER_GOLD, 2, 10, 14))
	content_vbox.add_child(overview_card)

	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 8)
	overview_card.add_child(ov)

	week_title_lbl = _label("赛季总览", 16, C_ZHUSHA, true)
	ov.add_child(week_title_lbl)

	changan_lbl = _label("长安态势加载中...", 13, C_WOOD_DESK, true)
	ov.add_child(changan_lbl)

	changan_bar = ProgressBar.new()
	changan_bar.custom_minimum_size = Vector2(0, 16)
	changan_bar.min_value = 0.0
	changan_bar.max_value = 5.0
	changan_bar.value = 0.0
	changan_bar.show_percentage = false
	ov.add_child(changan_bar)

	var sep := HSeparator.new()
	ov.add_child(sep)

	var f_head := _label("◆ 四阵营山河版图（城池数与总民心）", 14, C_MOLAN)
	ov.add_child(f_head)

	factions_vbox = VBoxContainer.new()
	factions_vbox.add_theme_constant_override("separation", 6)
	ov.add_child(factions_vbox)

	# 3. 四周赛季史书卷轴
	var hist_card := PanelContainer.new()
	hist_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hist_card.add_theme_stylebox_override("panel", _style(C_XUANZHI, Color("#d7c099"), 1, 10, 14))
	content_vbox.add_child(hist_card)

	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 8)
	hist_card.add_child(hv)

	var h_title := _label("📜 四候赛季史书（周报与关键战役）", 16, C_WOOD_DESK)
	hv.add_child(h_title)

	history_vbox = VBoxContainer.new()
	history_vbox.add_theme_constant_override("separation", 8)
	hv.add_child(history_vbox)

func layout_responsive(viewport_size: Vector2, dock_h: float) -> void:
	var w := viewport_size.x
	var h := viewport_size.y
	if w <= 0.0 or h <= 0.0:
		return
	var is_compact := h < 650.0 or w < 900.0
	var hdr_h := 56.0 if h < 650.0 else 64.0
	if header_bar != null:
		header_bar.size = Vector2(w, hdr_h)
	if body_margin != null:
		var pad_x := 10.0 if is_compact else 16.0
		body_margin.position = Vector2(pad_x, hdr_h + 6.0)
		body_margin.size = Vector2(w - pad_x * 2.0, maxf(160.0, h - hdr_h - dock_h - 12.0))

func render_loading() -> void:
	if header_sub_lbl != null:
		header_sub_lbl.text = "正在调取九州赛季档案..."

func set_season_data(s_data: Dictionary, h_data: Dictionary, m_data: Dictionary, g_data: Dictionary, me_dict: Dictionary) -> void:
	if not s_data.is_empty():
		season_data = s_data.duplicate(true)
	if not h_data.is_empty():
		history_data = h_data.duplicate(true)
	if not m_data.is_empty():
		merit_data = m_data.duplicate(true)
	if not g_data.is_empty():
		game_data = g_data.duplicate(true)
	if not me_dict.is_empty():
		me_data = me_dict.duplicate(true)
	_render_all()

func _render_all() -> void:
	var week := int(season_data.get("week", maxi(1, int(history_data.get("current_week", 1)))))
	var turn_no := int(season_data.get("turn_no", int(history_data.get("max_turn", 1))))
	var days_left := int(season_data.get("days_left", maxi(0, 28 - turn_no)))
	var season_over := bool(season_data.get("season_over", false))
	var game_status := str(game_data.get("status", ""))
	var is_finished := season_over or (game_status == "finished")

	var phase_desc := "赛季已收官" if is_finished else (
		"开拓期" if week <= 2 else ("长安争夺期" if week == 3 else "决战终周")
	)
	if header_sub_lbl != null:
		header_sub_lbl.text = "第 %d 周 · 第 %d / 28 候 · %s" % [week, turn_no, phase_desc]

	# 1. 终局颁奖大页区
	if award_card != null:
		award_card.visible = is_finished
		if is_finished:
			var winner_v: Variant = season_data.get("winner", null)
			var w_dict: Dictionary = winner_v if typeof(winner_v) == TYPE_DICTIONARY else {}
			if not w_dict.is_empty():
				var w_name := str(w_dict.get("name", ""))
				var w_reason := str(w_dict.get("reason", ""))
				var w_cities := int(w_dict.get("cities", 0))
				var w_morale := int(w_dict.get("morale", 0))
				var reason_txt := "攻克王城【长安】，提前一统问鼎！" if w_reason == "changan" else "28 候期满总决，以最多城池（%d 城 · 民心 %d）荣登首座！" % [w_cities, w_morale]
				award_banner_lbl.text = "👑 本季胜出阵营：【%s】荣膺山河首座！" % w_name
				award_reason_lbl.text = reason_txt
			else:
				award_banner_lbl.text = "👑 本季战局收官 · 群雄并立"
				award_reason_lbl.text = "28 候推演圆满落幕，各书院势均力敌，平分秋色！"

			var my_name := str(me_data.get("name", "学子"))
			var my_fac := str(me_data.get("faction", {}).get("name", "")) if typeof(me_data.get("faction", null)) == TYPE_DICTIONARY else ""
			var my_total_m := int(merit_data.get("total", 0))
			var my_rank := int(merit_data.get("rank", 0))
			var rank_part := "全班总榜第 %d 名" % my_rank if my_rank > 0 else "已记录参战功勋"
			award_me_lbl.text = "🎖️ %s（%s阵营）赛季勋绩：累计军功 %d · %s" % [my_name, my_fac, my_total_m, rank_part]

	# 2. 进行中总览与长安倒计时
	if week_title_lbl != null:
		var remain_str := "已收官" if is_finished else "距 28 候终局余 %d 天" % days_left
		week_title_lbl.text = "◆ 第 %d 周态势（第 %d 候 · %s）" % [week, turn_no, remain_str]

	var changan_v: Variant = season_data.get("changan", null)
	if typeof(changan_v) == TYPE_DICTIONARY and not changan_v.is_empty():
		var c_owner_name := str(changan_v.get("owner_name", "")) if changan_v.get("owner_name", null) != null else ""
		var c_morale := int(changan_v.get("morale", 0))
		var c_cap := int(changan_v.get("morale_cap", 5))
		changan_bar.max_value = float(maxi(1, c_cap))
		changan_bar.value = float(c_morale)
		if c_owner_name != "":
			changan_lbl.text = "🏯 长安王城：已由【%s】占领（民心 %d / %d）" % [c_owner_name, c_morale, c_cap]
		elif week < 3:
			var turns_until_w3 := maxi(1, 15 - turn_no)
			changan_lbl.text = "🔒 长安开放倒计时：第 3 周（第 15 候）解锁，还剩 %d 候 · 先开拓四野" % turns_until_w3
		elif week == 3:
			changan_lbl.text = "⚔️ 长安已开放争夺！当前中立（民心 %d / %d），先攻克者直接赢得赛季" % [c_morale, c_cap]
		else:
			changan_lbl.text = "🔥 第 4 周决战：全军仅可攻打长安及其 4 座邻城（当前民心 %d / %d）" % [c_morale, c_cap]
	else:
		changan_bar.value = 0.0
		changan_lbl.text = "🏯 正在等候长安战局同步..."

	# 四阵营版图柱状行
	for ch in factions_vbox.get_children():
		factions_vbox.remove_child(ch)
		ch.queue_free()

	var factions: Array = season_data.get("factions", [])
	var neutral_cities := int(season_data.get("neutral_cities", 0))
	var max_cities := 13.0
	for f in factions:
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var code := str(f.get("code", ""))
		var fname := str(f.get("name", code))
		var cities := int(f.get("cities", 0))
		var morale := int(f.get("morale", 0))
		var fcol: Color = FACTION_COLORS.get(code, C_MOLAN)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		factions_vbox.add_child(row)

		var nl := _label("%s阵营" % fname, 13, fcol)
		nl.custom_minimum_size = Vector2(74, 0)
		row.add_child(nl)

		var bar := ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 14)
		bar.max_value = max_cities
		bar.value = float(cities)
		bar.show_percentage = false
		var fill_sb := StyleBoxFlat.new()
		fill_sb.bg_color = fcol
		fill_sb.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill_sb)
		var bg_sb := StyleBoxFlat.new()
		bg_sb.bg_color = Color("#e3d6be")
		bg_sb.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bg_sb)
		row.add_child(bar)

		var stat_l := _label("%d 城 · 民心 %d" % [cities, morale], 12, C_WOOD_DESK)
		stat_l.custom_minimum_size = Vector2(118, 0)
		stat_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(stat_l)

	if neutral_cities > 0:
		var neu_lbl := _label("尚有 %d 座中立城池待群雄争夺" % neutral_cities, 12, Color("#6e5d4b"))
		factions_vbox.add_child(neu_lbl)

	# 3. 周报史书列表
	for ch in history_vbox.get_children():
		history_vbox.remove_child(ch)
		ch.queue_free()

	var weeks: Array = history_data.get("weeks", [])
	if weeks.is_empty():
		history_vbox.add_child(_label("开局尚早，今夜 21:00 首候结算后将写下第一笔九州史书。", 13, Color("#685848"), true))
		return

	# 最新一周排最前，便于先看近期战史
	var ordered := weeks.duplicate()
	ordered.reverse()
	for w_v in ordered:
		if typeof(w_v) != TYPE_DICTIONARY:
			continue
		var w_no := int(w_v.get("week", 1))
		var t_from := int(w_v.get("turn_from", 1))
		var t_to := int(w_v.get("turn_to", t_from))
		var is_comp := bool(w_v.get("complete", false))
		var b_cnt := int(w_v.get("battles", 0))
		var hl := str(w_v.get("headline", "第 %d 周战史" % w_no))

		var w_card := PanelContainer.new()
		w_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w_card.add_theme_stylebox_override("panel", _style(C_PAPER_WARM, C_BORDER_GOLD if is_comp else Color("#c9baa7"), 1, 8, 10))
		history_vbox.add_child(w_card)

		var wv := VBoxContainer.new()
		wv.add_theme_constant_override("separation", 4)
		w_card.add_child(wv)

		var top_r := HBoxContainer.new()
		top_r.add_theme_constant_override("separation", 8)
		wv.add_child(top_r)

		var wt := _label("【第 %d 周 · 第 %d–%d 候】%s" % [w_no, t_from, t_to, hl], 14, C_ZHUSHA if is_comp else C_MOLAN, true)
		wt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_r.add_child(wt)

		var badge := _label("已收官" if is_comp else "连载中", 11, C_ZHUQING if is_comp else C_TENGHUANG)
		top_r.add_child(badge)

		var meta_parts: Array[String] = ["本周战事 %d 场" % b_cnt]
		var captures: Array = w_v.get("captures", [])
		if not captures.is_empty():
			var cap_names: Array[String] = []
			for c in captures:
				if typeof(c) == TYPE_DICTIONARY:
					var wname := str(c.get("winner", {}).get("name", "")) if typeof(c.get("winner", null)) == TYPE_DICTIONARY else ""
					cap_names.append("%s(→%s)" % [str(c.get("node_name", "")), wname])
			meta_parts.append("易主：%s" % "、".join(cap_names))

		var kb_v: Variant = w_v.get("key_battle", null)
		if typeof(kb_v) == TYPE_DICTIONARY and not kb_v.is_empty():
			meta_parts.append("焦点战役：第%d候【%s】%s" % [
				int(kb_v.get("turn_no", 1)),
				str(kb_v.get("node_name", "")),
				str(kb_v.get("headline", "激战"))
			])

		var st_arr: Array = w_v.get("standings", [])
		var st_parts: Array[String] = []
		for st in st_arr:
			if typeof(st) == TYPE_DICTIONARY:
				st_parts.append("%s%d" % [str(st.get("name", "")), int(st.get("cities", 0))])
		if not st_parts.is_empty():
			meta_parts.append("疆域：" + " · ".join(st_parts))

		wv.add_child(_label("\n".join(meta_parts), 12, C_WOOD_DESK, true))
