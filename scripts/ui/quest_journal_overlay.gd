@tool
class_name QuestJournalOverlay
extends CanvasLayer

## Modal Quest Tracker (3 Main + 3 Side Quests) & Lore Data Log Codex ([J]).

signal journal_closed()

var _is_open: bool = false
var _quests_vbox: VBoxContainer = null
var _lore_vbox: VBoxContainer = null


func _ready() -> void:
	layer = 24
	_build_ui()
	visible = false


func is_open() -> bool:
	return _is_open


func open_journal() -> void:
	_is_open = true
	visible = true
	_refresh_journal()


func close_journal() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	journal_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_J:
			close_journal()
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
	modal.custom_minimum_size = Vector2(920, 520)
	modal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modal.add_theme_stylebox_override("panel", UiPixelTheme.make_modal_style())
	center.add_child(modal)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	modal.add_child(outer)

	var h_bar := HBoxContainer.new()
	h_bar.add_theme_constant_override("separation", 10)
	outer.add_child(h_bar)

	var q_icon := UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_QUEST_EMOTES, Rect2(0, 0, 16, 16))
	if q_icon:
		h_bar.add_child(UiPixelTheme.make_icon_rect(q_icon, Vector2(20, 20)))

	var title := Label.new()
	title.text = "JURNAL MISI & ARSIP LORE CONDITION CANYON [J]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("#38bdf8"))
	h_bar.add_child(title)

	var close_btn := UiPixelTheme.make_close_button()
	close_btn.pressed.connect(close_journal)
	h_bar.add_child(close_btn)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	outer.add_child(split)

	# Left: Quests
	var q_panel := PanelContainer.new()
	q_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	q_panel.add_theme_stylebox_override("panel", UiPixelTheme.make_card_style(0, 12, 10))
	split.add_child(q_panel)

	var q_outer := VBoxContainer.new()
	q_outer.add_theme_constant_override("separation", 8)
	q_panel.add_child(q_outer)

	var q_hdr := Label.new()
	q_hdr.text = "DAFTAR MISI (3 MAIN QUEST & 3 SIDE QUEST)"
	q_hdr.add_theme_font_size_override("font_size", 13)
	q_hdr.add_theme_color_override("font_color", Color("#fbbf24"))
	q_outer.add_child(q_hdr)

	var q_scroll := ScrollContainer.new()
	q_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	q_outer.add_child(q_scroll)

	_quests_vbox = VBoxContainer.new()
	_quests_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quests_vbox.add_theme_constant_override("separation", 8)
	q_scroll.add_child(_quests_vbox)

	# Right: Lore Logs
	var l_panel := PanelContainer.new()
	l_panel.custom_minimum_size = Vector2(360, 0)
	l_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l_panel.add_theme_stylebox_override("panel", UiPixelTheme.make_card_style(1, 12, 10))
	split.add_child(l_panel)

	var l_outer := VBoxContainer.new()
	l_outer.add_theme_constant_override("separation", 8)
	l_panel.add_child(l_outer)

	var l_hdr := Label.new()
	l_hdr.text = "ARSIP DATA LOG NGARAI (3 LORE)"
	l_hdr.add_theme_font_size_override("font_size", 13)
	l_hdr.add_theme_color_override("font_color", Color("#4ade80"))
	l_outer.add_child(l_hdr)

	var l_scroll := ScrollContainer.new()
	l_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l_outer.add_child(l_scroll)

	_lore_vbox = VBoxContainer.new()
	_lore_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lore_vbox.add_theme_constant_override("separation", 8)
	l_scroll.add_child(_lore_vbox)


func _refresh_journal() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")

	if _quests_vbox:
		for ch in _quests_vbox.get_children():
			_quests_vbox.remove_child(ch)
			ch.queue_free()

		for qid in ["MQ-01", "SQ-01", "SQ-02", "SQ-03", "MQ-02", "MQ-03"]:
			var q: Dictionary = World2Data.QUESTS.get(qid, {})
			var is_done := sm != null and sm.has_method("is_quest_completed") and bool(sm.call("is_quest_completed", qid))
			var is_act := sm != null and sm.has_method("is_quest_active") and bool(sm.call("is_quest_active", qid))

			var card := PanelContainer.new()
			card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			card.add_theme_stylebox_override("panel", UiPixelTheme.make_card_style(0 if (is_done or is_act) else 2, 10, 8))

			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", 4)
			card.add_child(cv)

			var state_str := "SELESAI ✓" if is_done else ("AKTIF" if is_act else "TERKUNCI")
			var h_lbl := Label.new()
			h_lbl.text = "[%s] %s — (%s)" % [qid, str(q.get("title", qid)), state_str]
			h_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			h_lbl.add_theme_font_size_override("font_size", 12)
			h_lbl.add_theme_color_override("font_color", Color("#4ade80") if is_done else (Color("#fbbf24") if is_act else Color(0.55, 0.62, 0.72)))
			cv.add_child(h_lbl)

			var d_lbl := Label.new()
			d_lbl.text = str(q.get("desc", ""))
			d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d_lbl.add_theme_font_size_override("font_size", 11)
			d_lbl.add_theme_color_override("font_color", Color(0.86, 0.91, 0.97))
			cv.add_child(d_lbl)

			var r_lbl := Label.new()
			r_lbl.text = "Hadiah: " + str(q.get("reward_text", ""))
			r_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			r_lbl.add_theme_font_size_override("font_size", 10)
			r_lbl.add_theme_color_override("font_color", Color("#38bdf8"))
			cv.add_child(r_lbl)

			_quests_vbox.add_child(card)

	if _lore_vbox:
		for ch in _lore_vbox.get_children():
			_lore_vbox.remove_child(ch)
			ch.queue_free()

		var collected: Array = sm.get("collected_lore_logs") if sm else []
		for lg in World2Data.LORE_LOGS:
			var lid := str(lg["id"])
			var unlocked := collected.has(lid)

			var lcard := PanelContainer.new()
			lcard.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			lcard.add_theme_stylebox_override("panel", UiPixelTheme.make_card_style(0 if unlocked else 2, 10, 8))

			var lv := VBoxContainer.new()
			lv.add_theme_constant_override("separation", 4)
			lcard.add_child(lv)

			var lt := Label.new()
			lt.text = "[%s] %s" % [lid, str(lg["title"]) if unlocked else "Data Log Terenkripsi (Belum Ditemukan)"]
			lt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lt.add_theme_font_size_override("font_size", 12)
			lt.add_theme_color_override("font_color", Color("#38bdf8") if unlocked else Color(0.55, 0.62, 0.72))
			lv.add_child(lt)

			var ltxt := Label.new()
			ltxt.text = str(lg["text"]) if unlocked else ("Lokasi: " + str(lg["district"]))
			ltxt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ltxt.add_theme_font_size_override("font_size", 11)
			ltxt.add_theme_color_override("font_color", Color(0.86, 0.91, 0.97) if unlocked else Color(0.5, 0.56, 0.66))
			lv.add_child(ltxt)

			_lore_vbox.add_child(lcard)
