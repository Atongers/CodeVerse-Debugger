@tool
class_name WorkbenchOverlay
extends CanvasLayer

## Modal Dual-Layer Crafting & Logic Calibration Workbench (Layer 1 Instan + Layer 2 Python Calibration).

signal workbench_closed()
signal item_crafted(item_id: String)

var _is_open: bool = false
var _selected_cal_idx: int = 0
var _hint_counts: Dictionary = {}

var _scrap_lbl: Label = null
var _inv_summary_lbl: Label = null
var _instant_vbox: VBoxContainer = null
var _cal_tabs_hbox: HBoxContainer = null
var _cal_title_lbl: Label = null
var _cal_ing_lbl: Label = null
var _code_edit: CodeEdit = null
var _output_lbl: RichTextLabel = null
var _hint_btn: Button = null
var _run_craft_btn: Button = null
var _dex_ref: Node = null


func _ready() -> void:
	layer = 24
	_build_ui()
	visible = false


func is_open() -> bool:
	return _is_open


func open_workbench(dex: Node = null) -> void:
	_dex_ref = dex
	_is_open = true
	visible = true
	_refresh_all()
	_load_calibration_recipe(_selected_cal_idx)


func close_workbench() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	workbench_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_workbench()
			get_viewport().set_input_as_handled()
		elif (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and event.ctrl_pressed:
			_on_run_calibrate_pressed()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.06, 0.86)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var modal := PanelContainer.new()
	modal.custom_minimum_size = Vector2(980, 560)
	modal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modal.add_theme_stylebox_override("panel", UiPixelTheme.make_modal_style())
	center.add_child(modal)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	modal.add_child(outer)

	# Header
	var h_bar := HBoxContainer.new()
	h_bar.add_theme_constant_override("separation", 10)
	outer.add_child(h_bar)

	var wb_icon := UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_QUEST_EMOTES, Rect2(5 * 16, 0, 16, 16))
	if wb_icon:
		h_bar.add_child(UiPixelTheme.make_icon_rect(wb_icon, Vector2(20, 20)))

	var title := Label.new()
	title.text = "WORKBENCH — DUAL-LAYER CRAFTING & LOGIC CALIBRATION"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("#38bdf8"))
	h_bar.add_child(title)

	_scrap_lbl = Label.new()
	_scrap_lbl.add_theme_font_size_override("font_size", 13)
	_scrap_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
	h_bar.add_child(_scrap_lbl)

	var close_btn := UiPixelTheme.make_close_button()
	close_btn.pressed.connect(close_workbench)
	h_bar.add_child(close_btn)

	# Inventory bar
	var inv_card := PanelContainer.new()
	inv_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	inv_card.add_theme_stylebox_override("panel", UiPixelTheme.make_card_style(0, 10, 6))
	outer.add_child(inv_card)

	_inv_summary_lbl = Label.new()
	_inv_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inv_summary_lbl.add_theme_font_size_override("font_size", 11)
	_inv_summary_lbl.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98))
	inv_card.add_child(_inv_summary_lbl)

	# Split Left (Instant) & Right (Calibration)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	outer.add_child(split)

	# Left Column: Layer 1 Instant Crafting
	var left_card := PanelContainer.new()
	left_card.custom_minimum_size = Vector2(340, 0)
	left_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left_card.add_theme_stylebox_override("panel", UiPixelTheme.make_card_style(0, 12, 10))
	split.add_child(left_card)

	var left_v := VBoxContainer.new()
	left_v.add_theme_constant_override("separation", 8)
	left_card.add_child(left_v)

	var l_hdr := Label.new()
	l_hdr.text = "LAYER 1 — PERAKITAN INSTAN"
	l_hdr.add_theme_font_size_override("font_size", 13)
	l_hdr.add_theme_color_override("font_color", Color("#4ade80"))
	left_v.add_child(l_hdr)

	var l_scroll := ScrollContainer.new()
	l_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_v.add_child(l_scroll)

	_instant_vbox = VBoxContainer.new()
	_instant_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_instant_vbox.add_theme_constant_override("separation", 8)
	l_scroll.add_child(_instant_vbox)

	# Right Column: Layer 2 Logic Calibration
	var right_card := PanelContainer.new()
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	right_card.add_theme_stylebox_override("panel", UiPixelTheme.make_card_style(1, 12, 10))
	split.add_child(right_card)

	var right_v := VBoxContainer.new()
	right_v.add_theme_constant_override("separation", 8)
	right_card.add_child(right_v)

	var r_hdr := Label.new()
	r_hdr.text = "LAYER 2 — LOGIC CALIBRATION (DEBUG SKRIP IF/ELSE)"
	r_hdr.add_theme_font_size_override("font_size", 13)
	r_hdr.add_theme_color_override("font_color", Color("#fbbf24"))
	right_v.add_child(r_hdr)

	_cal_tabs_hbox = HBoxContainer.new()
	_cal_tabs_hbox.add_theme_constant_override("separation", 6)
	right_v.add_child(_cal_tabs_hbox)

	for i in range(World2Data.CALIBRATION_RECIPES.size()):
		var rec: Dictionary = World2Data.CALIBRATION_RECIPES[i]
		var tab_btn := Button.new()
		tab_btn.text = str(rec["id"]).replace("_", " ").capitalize()
		tab_btn.custom_minimum_size = Vector2(160, 28)
		UiPixelTheme.apply_pixel_button(tab_btn, "primary", 8, 4)
		var idx_capture := i
		tab_btn.pressed.connect(func() -> void:
			_selected_cal_idx = idx_capture
			_load_calibration_recipe(idx_capture)
		)
		_cal_tabs_hbox.add_child(tab_btn)

	_cal_title_lbl = Label.new()
	_cal_title_lbl.add_theme_font_size_override("font_size", 13)
	_cal_title_lbl.add_theme_color_override("font_color", Color("#38bdf8"))
	right_v.add_child(_cal_title_lbl)

	_cal_ing_lbl = Label.new()
	_cal_ing_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cal_ing_lbl.add_theme_font_size_override("font_size", 11)
	_cal_ing_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.96))
	right_v.add_child(_cal_ing_lbl)

	_code_edit = CodeEdit.new()
	_code_edit.name = "CalibrationCodeEdit"
	_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code_edit.custom_minimum_size = Vector2(0, 155)
	_code_edit.gutters_draw_line_numbers = true
	_code_edit.indent_automatic = true
	_code_edit.add_theme_font_size_override("font_size", 13)
	right_v.add_child(_code_edit)

	_output_lbl = RichTextLabel.new()
	_output_lbl.bbcode_enabled = true
	_output_lbl.custom_minimum_size = Vector2(0, 74)
	_output_lbl.add_theme_font_size_override("normal_font_size", 12)
	right_v.add_child(_output_lbl)

	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 8)
	right_v.add_child(act_row)

	_run_craft_btn = Button.new()
	_run_craft_btn.name = "RunCalibrateBtn"
	_run_craft_btn.text = "▶ Kalibrasi & Rakit [Ctrl+Enter]"
	_run_craft_btn.custom_minimum_size = Vector2(220, 34)
	UiPixelTheme.apply_pixel_button(_run_craft_btn, "primary", 10, 6)
	_run_craft_btn.pressed.connect(_on_run_calibrate_pressed)
	act_row.add_child(_run_craft_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Kode"
	reset_btn.custom_minimum_size = Vector2(105, 34)
	UiPixelTheme.apply_pixel_button(reset_btn, "secondary", 10, 6)
	reset_btn.pressed.connect(func() -> void:
		_load_calibration_recipe(_selected_cal_idx)
	)
	act_row.add_child(reset_btn)

	_hint_btn = Button.new()
	_hint_btn.text = "Hint (0/3)"
	_hint_btn.custom_minimum_size = Vector2(110, 34)
	UiPixelTheme.apply_pixel_button(_hint_btn, "secondary", 10, 6)
	_hint_btn.pressed.connect(_on_hint_pressed)
	act_row.add_child(_hint_btn)


func _get_effective_ingredients(raw_ing: Dictionary) -> Dictionary:
	var res := raw_ing.duplicate(true)
	var sm: Node = get_node_or_null("/root/SaveManager")
	var has_opt := sm != null and sm.has_method("has_upgrade") and bool(sm.call("has_upgrade", "util_2"))
	if has_opt:
		for k in res.keys():
			var v := int(res[k])
			if v > 1:
				res[k] = v - 1
	return res


func _has_ingredients(ing: Dictionary) -> bool:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if not sm or not sm.has_method("get_item_count"):
		return false
	for k in ing.keys():
		if int(sm.call("get_item_count", str(k))) < int(ing[k]):
			return false
	return true


func _consume_ingredients(ing: Dictionary) -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if not sm or not sm.has_method("consume_item"):
		return
	for k in ing.keys():
		sm.call("consume_item", str(k), int(ing[k]))


func _format_ingredients_text(ing: Dictionary) -> String:
	var sm: Node = get_node_or_null("/root/SaveManager")
	var parts: PackedStringArray = []
	for k in ing.keys():
		var req := int(ing[k])
		var have := int(sm.call("get_item_count", str(k))) if (sm and sm.has_method("get_item_count")) else 0
		var meta: Dictionary = World2Data.ITEMS_META.get(str(k), {"name": str(k)})
		parts.append("%s: %d/%d" % [str(meta.get("name", k)), have, req])
	return "Bahan: " + " | ".join(parts)


func _refresh_all() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	var bits := int(sm.get("scrap_bits")) if sm else 0
	if _scrap_lbl:
		_scrap_lbl.text = "Scrap Bits: %d" % bits

	if _inv_summary_lbl and sm and sm.has_method("get_item_count"):
		var items_str: PackedStringArray = []
		for item_id in ["scrap_metal", "copper_wire", "coolant_cell", "logic_core", "glitch_shard", "repair_patch", "battery_cell", "coolant_stabilizer", "shield_breaker_coil"]:
			var cnt := int(sm.call("get_item_count", item_id))
			var m: Dictionary = World2Data.ITEMS_META.get(item_id, {"name": item_id})
			items_str.append("%s: %d" % [str(m["name"]), cnt])
		_inv_summary_lbl.text = "Inventori Bahan & Item:  " + "  •  ".join(items_str)

	if _instant_vbox:
		for ch in _instant_vbox.get_children():
			_instant_vbox.remove_child(ch)
			ch.queue_free()

		for rec in World2Data.INSTANT_RECIPES:
			var r_card := PanelContainer.new()
			r_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			r_card.add_theme_stylebox_override("panel", UiPixelTheme.make_card_style(0, 10, 8))
			var rv := VBoxContainer.new()
			rv.add_theme_constant_override("separation", 4)
			r_card.add_child(rv)

			var r_top := HBoxContainer.new()
			r_top.add_theme_constant_override("separation", 8)
			rv.add_child(r_top)

			var res_id := str(rec["result_item"])
			var meta: Dictionary = World2Data.ITEMS_META.get(res_id, {"col": 0})
			var icon_tex := UiPixelTheme.get_w2_item_icon(int(meta.get("col", 0)), true)
			if icon_tex:
				r_top.add_child(UiPixelTheme.make_icon_rect(icon_tex, Vector2(20, 20)))

			var n_lbl := Label.new()
			n_lbl.text = str(rec["name"])
			n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n_lbl.add_theme_font_size_override("font_size", 12)
			n_lbl.add_theme_color_override("font_color", Color("#38bdf8"))
			r_top.add_child(n_lbl)

			var eff_ing := _get_effective_ingredients(rec["ingredients"] as Dictionary)
			var can_craft := _has_ingredients(eff_ing)

			var ing_lbl := Label.new()
			ing_lbl.text = _format_ingredients_text(eff_ing)
			ing_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ing_lbl.add_theme_font_size_override("font_size", 11)
			ing_lbl.add_theme_color_override("font_color", Color("#86efac") if can_craft else Color("#fca5a5"))
			rv.add_child(ing_lbl)

			var c_btn := Button.new()
			c_btn.text = "Rakit Sekarang" if can_craft else "Bahan Belum Cukup"
			c_btn.disabled = not can_craft
			c_btn.custom_minimum_size = Vector2(0, 28)
			UiPixelTheme.apply_pixel_button(c_btn, "primary" if can_craft else "secondary", 8, 4)
			var rec_capture: Dictionary = rec
			c_btn.pressed.connect(func() -> void:
				_craft_instant_recipe(rec_capture)
			)
			rv.add_child(c_btn)
			_instant_vbox.add_child(r_card)


func _craft_instant_recipe(rec: Dictionary) -> void:
	var eff_ing := _get_effective_ingredients(rec["ingredients"] as Dictionary)
	if not _has_ingredients(eff_ing):
		return
	_consume_ingredients(eff_ing)
	var res_id := str(rec["result_item"])
	var sm: Node = get_node_or_null("/root/SaveManager")
	if res_id == "emp_charge_pack" and is_instance_valid(_dex_ref) and _dex_ref.has_method("restore_energy"):
		_dex_ref.call("restore_energy", 100.0, true)
	elif sm and sm.has_method("add_item"):
		sm.call("add_item", res_id, int(rec.get("result_count", 1)))
	item_crafted.emit(res_id)
	_refresh_all()
	_update_cal_ingredients_label()


func _load_calibration_recipe(idx: int) -> void:
	if idx < 0 or idx >= World2Data.CALIBRATION_RECIPES.size():
		return
	var rec: Dictionary = World2Data.CALIBRATION_RECIPES[idx]
	var rec_id := str(rec["id"])
	var sm: Node = get_node_or_null("/root/SaveManager")
	var has_scanner := sm != null and sm.has_method("has_upgrade") and bool(sm.call("has_upgrade", "util_4"))
	var scan_tag := "  [Insight Scanner: Cek baris if!]" if has_scanner else ""
	_cal_title_lbl.text = "%s%s" % [str(rec["name"]), scan_tag]
	_update_cal_ingredients_label()

	var lines: Array = rec["initial_code"]
	var joined := PackedStringArray()
	for l in lines:
		joined.append(str(l))
	_code_edit.text = "\n".join(joined)

	var h_cnt := int(_hint_counts.get(rec_id, 0))
	_hint_btn.text = "Hint (%d/3)" % h_cnt
	_output_lbl.text = "[color=#38bdf8]Siap kalibrasi.[/color] Bahan tidak akan berkurang jika kode masih ber-bug. Perbaiki skrip agar memanggil [b]rakit_item(\"%s\")[/b]!" % str(rec["target_arg"])


func _update_cal_ingredients_label() -> void:
	if _selected_cal_idx < 0 or _selected_cal_idx >= World2Data.CALIBRATION_RECIPES.size():
		return
	var rec: Dictionary = World2Data.CALIBRATION_RECIPES[_selected_cal_idx]
	var eff_ing := _get_effective_ingredients(rec["ingredients"] as Dictionary)
	var sm: Node = get_node_or_null("/root/SaveManager")
	var owned := int(sm.call("get_item_count", str(rec["result_item"]))) if (sm and sm.has_method("get_item_count")) else 0
	_cal_ing_lbl.text = "%s  |  Dimiliki: %d" % [_format_ingredients_text(eff_ing), owned]


func _on_hint_pressed() -> void:
	var rec: Dictionary = World2Data.CALIBRATION_RECIPES[_selected_cal_idx]
	var rec_id := str(rec["id"])
	var hints: Array = rec.get("hints", [])
	if hints.is_empty():
		return
	var cur := clampi(int(_hint_counts.get(rec_id, 0)) + 1, 1, hints.size())
	_hint_counts[rec_id] = cur
	_hint_btn.text = "Hint (%d/%d)" % [cur, hints.size()]
	_output_lbl.text = "[color=#fbbf24][b]Hint %d:[/b] %s[/color]" % [cur, str(hints[cur - 1])]


func _on_run_calibrate_pressed() -> void:
	var rec: Dictionary = World2Data.CALIBRATION_RECIPES[_selected_cal_idx]
	var eff_ing := _get_effective_ingredients(rec["ingredients"] as Dictionary)
	var res: Dictionary = PythonInterpreter.run_script(_code_edit.text, ["rakit_item"])
	if not bool(res.get("ok", false)):
		_output_lbl.text = "[color=#f87171][b]✗ %s[/b]\n(Bahan aman, belum dipotong.)[/color]" % str(res.get("error", "Error"))
		return

	var calls: Array = res.get("calls", [])
	var target_arg := str(rec["target_arg"])
	var matched := false
	var got_arg := "(tidak memanggil rakit_item)"
	for c in calls:
		if str(c.get("name", "")) == "rakit_item":
			var args: Array = c.get("args", [])
			if not args.is_empty():
				got_arg = str(args[0])
				if got_arg == target_arg:
					matched = true

	if not matched:
		_output_lbl.text = "[color=#fbbf24][b]⚠ Kalibrasi Belum Tepat:[/b] Skrip menghasilkan rakit_item(\"%s\"), sedangkan dibutuhkan rakit_item(\"%s\"). Bahan tidak dipotong.[/color]" % [got_arg, target_arg]
		return

	if not _has_ingredients(eff_ing):
		_output_lbl.text = "[color=#fbbf24][b]✓ Logika Kode Benar![/b] Namun bahan di inventori belum cukup untuk merakit item ini.[/color]"
		return

	_consume_ingredients(eff_ing)
	var res_id := str(rec["result_item"])
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm:
		if sm.has_method("add_item"):
			sm.call("add_item", res_id, 1)
		if sm.has_method("unlock_bug_log"):
			sm.call("unlock_bug_log", str(rec.get("bug_id", "")))
		if sm.has_method("unlock_achievement"):
			if res_id == "coolant_stabilizer":
				sm.call("unlock_achievement", "ACH-06")
			elif res_id == "shield_breaker_coil":
				sm.call("unlock_achievement", "ACH-07")

	_output_lbl.text = "[color=#4ade80][b]✓ KALIBRASI SUKSES![/b] 1x %s berhasil dirakit ke inventori![/color]" % str(rec["name"])
	item_crafted.emit(res_id)
	_refresh_all()
	_update_cal_ingredients_label()
