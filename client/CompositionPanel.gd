extends PanelContainer

## 每周军团编成面板 (Weekly Composition Panel)
## 一行 4 兵种按钮 + 一行 3 队伍槽位 + 兵源城加成 + 周中改 1 次
## 完美适配 720x514 手机横屏与 1400x1000 平板

signal composition_changed(slots: Array)
signal composition_confirmed(slots: Array)

const FONT_PATH := "res://fonts/NotoSerifCJKsc-Regular.otf"

# 风格水墨水彩纸雕色板
const C_XUANZHI := Color("#f6efe2")
const C_WOOD_DESK := Color("#231c17")
const C_MOLAN := Color("#1e3a5f")
const C_ZHUQING := Color("#276f57")
const C_ZHUSHA := Color("#b83b32")
const C_TENGHUANG := Color("#cf8325")
const C_BORDER_GOLD := Color("#c9a227")

# 4 兵种克制循环：骑 > 盾 > 弓 > 枪 > 骑
const UNIT_DEFS := {
	"cav": {
		"name": "骑兵",
		"icon": "🐎",
		"asset": "cavalry",
		"color": Color("#b83b32"),
		"role": "突击·克盾",
		"restrain": "盾兵",
		"weak": "枪兵",
		"desc": "强克盾兵(x1.2)，被枪兵克制(x0.85)。"
	},
	"shield": {
		"name": "盾兵",
		"icon": "🛡️",
		"asset": "shield",
		"color": Color("#1e3a5f"),
		"role": "坚守·克弓",
		"restrain": "弓兵",
		"weak": "骑兵",
		"desc": "强克弓兵(x1.2)，被骑兵克制(x0.85)。"
	},
	"arc": {
		"name": "弓兵",
		"icon": "🏹",
		"asset": "archer",
		"color": Color("#276f57"),
		"role": "远程·克枪",
		"restrain": "枪兵",
		"weak": "盾兵",
		"desc": "强克枪兵(x1.2)，被盾兵克制(x0.85)。"
	},
	"spear": {
		"name": "枪兵",
		"icon": "🗡️",
		"asset": "spear",
		"color": Color("#966324"),
		"role": "反骑·克骑",
		"restrain": "骑兵",
		"weak": "弓兵",
		"desc": "强克骑兵(x1.2)，被弓兵克制(x0.85)。"
	}
}

var current_slots: Array = ["cav", "shield", "arc"]
var active_slot_idx: int = 0

var base_power: int = 1088
var team_power: int = 363
var source_city_name: String = "凉州"
var source_unit_type: String = "cav"
var source_bonus_pct: int = 15

var changes_remaining: int = 1
var is_locked: bool = false

var root_vbox: VBoxContainer
var header_hbox: HBoxContainer
var info_label: Label
var change_status_label: Label
var unit_buttons_row: HBoxContainer
var slots_row: HBoxContainer
var slot_cards: Array = []
var unit_buttons: Dictionary = {}
var footer_hbox: HBoxContainer
var confirm_btn: Button
var quick_tip_label: Label

func _ready() -> void:
	_build_ui()
	_update_display()
	resized.connect(_layout_responsive)
	_layout_responsive()

func _layout_responsive() -> void:
	var w := size.x
	if w <= 0.0:
		return
	var is_phone := w < 800.0
	
	if unit_buttons_row:
		unit_buttons_row.add_theme_constant_override("separation", 4 if is_phone else 8)
	for code in unit_buttons.keys():
		var btn: Button = unit_buttons[code]
		var udata: Dictionary = UNIT_DEFS.get(code, {})
		if is_phone:
			btn.text = "%s %s" % [udata.icon, udata.name]
			btn.add_theme_font_size_override("font_size", 11)
			btn.custom_minimum_size = Vector2(0, 30)
		else:
			btn.text = "%s %s (%s)" % [udata.icon, udata.name, udata.role]
			btn.add_theme_font_size_override("font_size", 12)
			btn.custom_minimum_size = Vector2(0, 34)
			
	if slots_row:
		slots_row.add_theme_constant_override("separation", 6 if is_phone else 10)
		
	if confirm_btn:
		confirm_btn.text = "确认" if is_phone else "确认本周编成"
		confirm_btn.custom_minimum_size = Vector2(60 if is_phone else 110, 26 if is_phone else 28)
		confirm_btn.add_theme_font_size_override("font_size", 11 if is_phone else 12)
		
	if quick_tip_label:
		quick_tip_label.text = "克制: 骑>盾>弓>枪>骑 (x1.2/x0.85) · 点击队伍位置替换" if is_phone else "克制环: 骑>盾>弓>枪>骑 (x1.2 / x0.85) · 点击队伍位置再选兵种即可替换 (可重复编成)"

func setup_data(pet_level: int = 10, source_city: String = "凉州", source_type: String = "cav") -> void:
	base_power = int((1000 + 200 + 200 + 100) / 2.0 * (1.0 + 0.05 * (pet_level - 1)))
	team_power = int(base_power / 3.0)
	source_city_name = source_city
	source_unit_type = source_type
	_update_display()

func _build_ui() -> void:
	add_theme_stylebox_override("panel", _make_style(Color(0.12, 0.09, 0.07, 0.94), C_BORDER_GOLD, 1, 8, 8))
	
	root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	add_child(root_vbox)
	
	# 1. 顶部标题栏
	header_hbox = HBoxContainer.new()
	root_vbox.add_child(header_hbox)
	
	var title_lbl := Label.new()
	title_lbl.text = "⚔️ 每周军团编成"
	title_lbl.add_theme_color_override("font_color", Color("#fae19c"))
	title_lbl.add_theme_font_size_override("font_size", 14)
	header_hbox.add_child(title_lbl)
	
	header_hbox.add_child(_make_spacer(true))
	
	info_label = Label.new()
	info_label.text = "总兵力: 1088 (每队 363) | 兵源城: 凉州(+15%骑)"
	info_label.add_theme_color_override("font_color", Color("#d5c4a1"))
	info_label.add_theme_font_size_override("font_size", 11)
	header_hbox.add_child(info_label)
	
	change_status_label = Label.new()
	change_status_label.text = " [周中可改 1 次]"
	change_status_label.add_theme_color_override("font_color", Color("#cf8325"))
	change_status_label.add_theme_font_size_override("font_size", 11)
	header_hbox.add_child(change_status_label)
	
	# 2. 一行 4 个兵种按钮 (骑 / 盾 / 弓 / 枪)
	unit_buttons_row = HBoxContainer.new()
	unit_buttons_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_buttons_row.add_theme_constant_override("separation", 8)
	root_vbox.add_child(unit_buttons_row)
	
	for code in ["cav", "shield", "arc", "spear"]:
		var udata: Dictionary = UNIT_DEFS[code]
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		btn.text = " %s (%s)" % [udata.name, udata.role]
		var asset_name := str(udata.get("asset", code))
		var icon_path := "res://assets/art/ui/unit_icon_%s.png" % code
		if not ResourceLoader.exists(icon_path):
			icon_path = "res://assets/art/battle/%s_idle.png" % asset_name
		if ResourceLoader.exists(icon_path):
			btn.icon = load(icon_path)
			btn.expand_icon = true
		btn.tooltip_text = "%s: %s\n克制: %s | 弱势: %s" % [udata.name, udata.desc, udata.restrain, udata.weak]
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color("#f6efe2"))
		btn.add_theme_stylebox_override("normal", _make_style(udata.color.darkened(0.55), udata.color, 1, 6, 2))
		btn.add_theme_stylebox_override("hover", _make_style(udata.color.darkened(0.35), C_BORDER_GOLD, 2, 6, 2))
		btn.add_theme_stylebox_override("pressed", _make_style(udata.color, Color.WHITE, 2, 6, 2))
		btn.pressed.connect(func(): _on_unit_picked(code))
		unit_buttons_row.add_child(btn)
		unit_buttons[code] = btn
	
	# 3. 一行 3 个队伍槽位 (前锋·队1 / 中军·队2 / 后翼·队3)
	slots_row = HBoxContainer.new()
	slots_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_row.add_theme_constant_override("separation", 10)
	root_vbox.add_child(slots_row)
	
	slot_cards.clear()
	for i in range(3):
		var card := _create_slot_card(i)
		slots_row.add_child(card)
		slot_cards.append(card)
	
	# 4. 底部说明与操作栏
	footer_hbox = HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 8)
	root_vbox.add_child(footer_hbox)
	
	quick_tip_label = Label.new()
	quick_tip_label.text = "克制环: 骑>盾>弓>枪>骑 (x1.2 / x0.85) · 点击队伍位置再选兵种即可替换 (可重复编成)"
	quick_tip_label.add_theme_color_override("font_color", Color("#a69985"))
	quick_tip_label.add_theme_font_size_override("font_size", 10)
	footer_hbox.add_child(quick_tip_label)
	
	footer_hbox.add_child(_make_spacer(true))
	
	confirm_btn = Button.new()
	confirm_btn.text = "确认本周编成"
	confirm_btn.custom_minimum_size = Vector2(110, 28)
	confirm_btn.add_theme_font_size_override("font_size", 12)
	confirm_btn.add_theme_color_override("font_color", Color("#ffffff"))
	confirm_btn.add_theme_stylebox_override("normal", _make_style(C_ZHUQING, C_BORDER_GOLD, 1, 6, 4))
	confirm_btn.add_theme_stylebox_override("hover", _make_style(C_ZHUQING.lightened(0.15), Color.WHITE, 1, 6, 4))
	confirm_btn.pressed.connect(_on_confirm_pressed)
	footer_hbox.add_child(confirm_btn)

func _create_slot_card(idx: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 68)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)
	
	var tag_hbox := HBoxContainer.new()
	vbox.add_child(tag_hbox)
	
	var name_lbl := Label.new()
	name_lbl.name = "SlotTitle"
	var lane_name := "前锋·队1" if idx == 0 else ("中军·队2" if idx == 1 else "后翼·队3")
	name_lbl.text = lane_name
	name_lbl.add_theme_color_override("font_color", Color("#fae19c"))
	name_lbl.add_theme_font_size_override("font_size", 11)
	tag_hbox.add_child(name_lbl)
	
	tag_hbox.add_child(_make_spacer(true))
	
	var select_indicator := Label.new()
	select_indicator.name = "SelectIndicator"
	select_indicator.text = "▶配置中" if idx == active_slot_idx else ""
	select_indicator.add_theme_color_override("font_color", Color("#cf8325"))
	select_indicator.add_theme_font_size_override("font_size", 10)
	tag_hbox.add_child(select_indicator)
	
	var body_btn := Button.new()
	body_btn.name = "BodyBtn"
	body_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_btn.flat = true
	body_btn.pressed.connect(func(): _select_slot(idx))
	vbox.add_child(body_btn)
	
	var body_h := HBoxContainer.new()
	body_h.alignment = BoxContainer.ALIGNMENT_CENTER
	body_h.add_theme_constant_override("separation", 6)
	body_h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body_btn.add_child(body_h)

	var icon_rect := TextureRect.new()
	icon_rect.name = "SlotUnitIcon"
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body_h.add_child(icon_rect)
	
	var unit_lbl := Label.new()
	unit_lbl.name = "UnitLabel"
	unit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unit_lbl.add_theme_font_size_override("font_size", 13)
	body_h.add_child(unit_lbl)
	
	var info_h := HBoxContainer.new()
	info_h.alignment = BoxContainer.ALIGNMENT_CENTER
	info_h.add_theme_constant_override("separation", 6)
	vbox.add_child(info_h)
	
	var power_lbl := Label.new()
	power_lbl.name = "PowerLabel"
	power_lbl.add_theme_color_override("font_color", Color("#e5d5be"))
	power_lbl.add_theme_font_size_override("font_size", 11)
	info_h.add_child(power_lbl)
	
	var bonus_lbl := Label.new()
	bonus_lbl.name = "BonusLabel"
	bonus_lbl.add_theme_color_override("font_color", Color("#cf8325"))
	bonus_lbl.add_theme_font_size_override("font_size", 10)
	info_h.add_child(bonus_lbl)
	
	return card

func set_composition_state(types: Array, changed_once: bool) -> void:
	if types.size() == 3:
		current_slots = types.duplicate()
	is_locked = changed_once
	changes_remaining = 0 if changed_once else 1
	_update_display()

func _select_slot(idx: int) -> void:
	active_slot_idx = idx
	_update_display()

func _on_unit_picked(unit_code: String) -> void:
	if is_locked and changes_remaining <= 0:
		return
	if active_slot_idx >= 0 and active_slot_idx < current_slots.size():
		current_slots[active_slot_idx] = unit_code
		_update_display()
		composition_changed.emit(current_slots)

func _on_confirm_pressed() -> void:
	if changes_remaining > 0:
		changes_remaining -= 1
		is_locked = true
		_update_display()
		composition_confirmed.emit(current_slots)

func _update_display() -> void:
	if slot_cards.is_empty():
		return
	
	var is_phone := size.x < 800.0 and size.x > 0.0
	
	if is_phone:
		info_label.text = "总兵力:%d(队%d) | 兵源:%s(+%d%%%s)" % [
			base_power,
			team_power,
			source_city_name,
			source_bonus_pct,
			UNIT_DEFS.get(source_unit_type, {}).get("name", "兵")
		]
		if changes_remaining > 0:
			change_status_label.text = " [余%d次]" % changes_remaining
			change_status_label.add_theme_color_override("font_color", Color("#cf8325"))
			confirm_btn.disabled = false
			confirm_btn.text = "确认" if not is_locked else "改编(1次)"
		else:
			change_status_label.text = " [已锁定]"
			change_status_label.add_theme_color_override("font_color", Color("#7e7263"))
			confirm_btn.disabled = true
			confirm_btn.text = "已锁定"
	else:
		info_label.text = "总兵力: %d (每队 %d) | 兵源城: %s (+%d%% %s)" % [
			base_power,
			team_power,
			source_city_name,
			source_bonus_pct,
			UNIT_DEFS.get(source_unit_type, {}).get("name", "兵种")
		]
		if changes_remaining > 0:
			change_status_label.text = " [周中剩余可改 %d 次]" % changes_remaining
			change_status_label.add_theme_color_override("font_color", Color("#cf8325"))
			confirm_btn.disabled = false
			confirm_btn.text = "确认编成" if not is_locked else "提交修改(仅1次)"
		else:
			change_status_label.text = " [本周已锁定]"
			change_status_label.add_theme_color_override("font_color", Color("#7e7263"))
			confirm_btn.disabled = true
			confirm_btn.text = "编成已锁定"
	
	for i in range(slot_cards.size()):
		var card: PanelContainer = slot_cards[i]
		var u_code: String = current_slots[i]
		var u_data: Dictionary = UNIT_DEFS.get(u_code, UNIT_DEFS["cav"])
		var is_selected: bool = (i == active_slot_idx)
		
		var border_c: Color = C_BORDER_GOLD if is_selected else Color(0.35, 0.28, 0.22, 0.7)
		var bg_c: Color = Color("#231c17") if not is_selected else Color("#362a20")
		var patch_path := "res://assets/art/ui/card_frame_ninepatch.png"
		if ResourceLoader.exists(patch_path):
			var sb := StyleBoxTexture.new()
			sb.texture = load(patch_path)
			sb.texture_margin_left = 28
			sb.texture_margin_top = 28
			sb.texture_margin_right = 28
			sb.texture_margin_bottom = 28
			sb.set_content_margin_all(5)
			sb.modulate_color = Color("#fcf6ea") if is_selected else Color("#786b5e")
			card.add_theme_stylebox_override("panel", sb)
		else:
			card.add_theme_stylebox_override("panel", _make_style(bg_c, border_c, 2 if is_selected else 1, 6, 4))
		
		var sel_ind: Label = card.find_child("SelectIndicator", true, false)
		if sel_ind:
			sel_ind.text = "▶配置中" if is_selected else ""
		
		var u_lbl: Label = card.find_child("UnitLabel", true, false)
		if u_lbl:
			u_lbl.text = "%s" % u_data.name
			u_lbl.add_theme_color_override("font_color", u_data.color.lightened(0.2))
		
		var u_icon: TextureRect = card.find_child("SlotUnitIcon", true, false)
		if u_icon:
			var asset_name := str(u_data.get("asset", u_code))
			var icon_path := "res://assets/art/ui/unit_icon_%s.png" % u_code
			if not ResourceLoader.exists(icon_path):
				icon_path = "res://assets/art/battle/%s_idle.png" % asset_name
			if ResourceLoader.exists(icon_path):
				u_icon.texture = load(icon_path)
		
		var final_team_pwr := team_power
		var bonus_str := ""
		if u_code == source_unit_type:
			final_team_pwr = int(team_power * (1.0 + source_bonus_pct / 100.0))
			bonus_str = "+%d%%加成" % source_bonus_pct
		
		var pwr_lbl: Label = card.find_child("PowerLabel", true, false)
		if pwr_lbl:
			pwr_lbl.text = "兵力: %d" % final_team_pwr
		
		var b_lbl: Label = card.find_child("BonusLabel", true, false)
		if b_lbl:
			b_lbl.text = bonus_str
			b_lbl.visible = (bonus_str != "")

	var cur_picked_in_active: String = current_slots[active_slot_idx] if active_slot_idx >= 0 and active_slot_idx < current_slots.size() else ""
	for code in unit_buttons.keys():
		var btn: Button = unit_buttons[code]
		var udata: Dictionary = UNIT_DEFS[code]
		var is_btn_active: bool = (code == cur_picked_in_active)
		var is_btn_disabled: bool = (is_locked and changes_remaining <= 0)
		btn.disabled = is_btn_disabled
		if is_btn_active:
			btn.add_theme_stylebox_override("normal", _make_style(udata.color.darkened(0.2), C_BORDER_GOLD, 2, 6, 2))
		elif is_btn_disabled:
			btn.add_theme_stylebox_override("normal", _make_style(Color(0.2, 0.2, 0.2, 0.6), Color(0.4, 0.4, 0.4, 0.5), 1, 6, 2))
		else:
			btn.add_theme_stylebox_override("normal", _make_style(udata.color.darkened(0.55), udata.color, 1, 6, 2))

func _make_style(bg: Color, border: Color, border_w: int = 1, radius: int = 6, pad: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb

func _make_spacer(expand: bool = true) -> Control:
	var sp := Control.new()
	if expand:
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sp
