class_name DebugToolDock
extends Control

## Reusable HUD Debug Tool & Unlock Dock (sudut kanan-bawah) + Unlock Toast Banner.

signal bug_log_requested()
signal tool_info_requested(slot_id: String, message: String)

const TEX_DOCK_FRAME_PATH := "res://assets/ui/ui_dock_frame_9slice.png"
const TEX_SLOT_SHEET_PATH := "res://assets/ui/ui_tool_slot_sheet.png"
const TEX_TOOLS_SHEET_PATH := "res://assets/ui/ui_tools_24_sheet.png"
const TEX_LOCK_FEATURE_PATH := "res://assets/ui/ui_lock_feature_24.png"
const TEX_TOAST_FRAME_PATH := "res://assets/ui/ui_unlock_toast_9slice.png"
const TEX_LOCK_OPEN_ANIM_PATH := "res://assets/ui/ui_lock_open_anim.png"

const FALLBACK_SLOTS: Array[Dictionary] = [
	{"id": "output", "name": "Output Console", "col_index": 0, "tooltip": "Output Console — Panel output standar Python & print().", "always_unlocked": true},
	{"id": "print_tool", "name": "Quick-Insert Print", "col_index": 1, "tooltip": "Print Tool — Sisipkan print() cepat. (Terbuka: Tamat Level 2)", "always_unlocked": false},
	{"id": "step_trace", "name": "Step Trace", "col_index": 2, "tooltip": "Step Trace — Tersedia di Dunia 3 (Loop Labyrinth)", "always_unlocked": false},
	{"id": "watch_var", "name": "Watch Variabel", "col_index": 3, "tooltip": "Watch Variabel — Tersedia di Dunia 4 (Function Foundry)", "always_unlocked": false},
	{"id": "breakpoint", "name": "Breakpoint", "col_index": 4, "tooltip": "Breakpoint — Tersedia di Dunia 5 (List Citadel)", "always_unlocked": false},
	{"id": "speed_selector", "name": "Speed 2x / Skip", "col_index": 5, "tooltip": "Speed 2x / Skip — Percepat eksekusi Terminal. (Terbuka: Tamat Level 3)", "always_unlocked": false},
	{"id": "bug_log", "name": "Bug Log", "col_index": 6, "tooltip": "Bug Log [L] — Buka catatan bug Python level ini.", "always_unlocked": true},
]

var _slot_bg_texs: Array[AtlasTexture] = []
var _tool_unlocked_texs: Array[AtlasTexture] = []
var _tool_locked_texs: Array[AtlasTexture] = []
var _lock_open_texs: Array[AtlasTexture] = []
var _lock_feature_tex: Texture2D = null

var _slot_widgets: Array[Dictionary] = []
var _new_slots: Dictionary = {}

var _toast_panel: NinePatchRect = null
var _toast_icon: TextureRect = null
var _toast_title_lbl: Label = null
var _toast_sub_lbl: Label = null
var _toast_queue: Array[Dictionary] = []
var _toast_busy: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -16.0
	offset_bottom = -16.0
	offset_left = -320.0
	offset_top = -150.0

	_load_textures()
	_build_ui()
	refresh_slots()

	if has_node("/root/SaveManager"):
		var sm := get_node("/root/SaveManager")
		if sm.has_signal("progression_updated") and not sm.progression_updated.is_connected(refresh_slots):
			sm.progression_updated.connect(refresh_slots)
		if sm.has_signal("item_unlocked") and not sm.item_unlocked.is_connected(_on_item_unlocked):
			sm.item_unlocked.connect(_on_item_unlocked)


func _load_textures() -> void:
	if ResourceLoader.exists(TEX_LOCK_FEATURE_PATH):
		_lock_feature_tex = load(TEX_LOCK_FEATURE_PATH)

	if ResourceLoader.exists(TEX_SLOT_SHEET_PATH):
		var sheet: Texture2D = load(TEX_SLOT_SHEET_PATH)
		if sheet:
			for c in range(4):
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(c * 32, 0, 32, 32)
				at.filter_clip = true
				_slot_bg_texs.append(at)

	if ResourceLoader.exists(TEX_TOOLS_SHEET_PATH):
		var t_sheet: Texture2D = load(TEX_TOOLS_SHEET_PATH)
		if t_sheet:
			for c in range(7):
				var at_on := AtlasTexture.new()
				at_on.atlas = t_sheet
				at_on.region = Rect2(c * 24, 0, 24, 24)
				at_on.filter_clip = true
				_tool_unlocked_texs.append(at_on)

				var at_off := AtlasTexture.new()
				at_off.atlas = t_sheet
				at_off.region = Rect2(c * 24, 24, 24, 24)
				at_off.filter_clip = true
				_tool_locked_texs.append(at_off)

	if ResourceLoader.exists(TEX_LOCK_OPEN_ANIM_PATH):
		var anim_sheet: Texture2D = load(TEX_LOCK_OPEN_ANIM_PATH)
		if anim_sheet:
			for f in range(4):
				var at_f := AtlasTexture.new()
				at_f.atlas = anim_sheet
				at_f.region = Rect2(f * 24, 0, 24, 24)
				at_f.filter_clip = true
				_lock_open_texs.append(at_f)


func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	root_vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root_vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root_vbox.alignment = BoxContainer.ALIGNMENT_END
	root_vbox.add_theme_constant_override("separation", 8)
	root_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_vbox)

	# 1. Unlock Toast Banner (di atas Dock)
	_toast_panel = NinePatchRect.new()
	_toast_panel.visible = false
	_toast_panel.modulate.a = 0.0
	_toast_panel.custom_minimum_size = Vector2(280, 56)
	_toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_toast_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(TEX_TOAST_FRAME_PATH):
		_toast_panel.texture = load(TEX_TOAST_FRAME_PATH)
		_toast_panel.patch_margin_left = 14
		_toast_panel.patch_margin_top = 14
		_toast_panel.patch_margin_right = 14
		_toast_panel.patch_margin_bottom = 14
	root_vbox.add_child(_toast_panel)

	var toast_margin := MarginContainer.new()
	toast_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_margin.add_theme_constant_override("margin_left", 12)
	toast_margin.add_theme_constant_override("margin_right", 12)
	toast_margin.add_theme_constant_override("margin_top", 8)
	toast_margin.add_theme_constant_override("margin_bottom", 8)
	toast_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(toast_margin)

	var toast_hbox := HBoxContainer.new()
	toast_hbox.add_theme_constant_override("separation", 10)
	toast_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_margin.add_child(toast_hbox)

	_toast_icon = TextureRect.new()
	_toast_icon.custom_minimum_size = Vector2(24, 24)
	_toast_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_toast_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_toast_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_toast_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_hbox.add_child(_toast_icon)

	var toast_text_vbox := VBoxContainer.new()
	toast_text_vbox.add_theme_constant_override("separation", 2)
	toast_text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toast_text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_hbox.add_child(toast_text_vbox)

	var toast_badge := Label.new()
	toast_badge.text = "ITEM BARU TERBUKA!"
	toast_badge.add_theme_font_size_override("font_size", 10)
	toast_badge.add_theme_color_override("font_color", Color("#fbbf24"))
	toast_text_vbox.add_child(toast_badge)

	_toast_title_lbl = Label.new()
	_toast_title_lbl.text = ""
	_toast_title_lbl.add_theme_font_size_override("font_size", 12)
	_toast_title_lbl.add_theme_color_override("font_color", Color("#38bdf8"))
	toast_text_vbox.add_child(_toast_title_lbl)

	_toast_sub_lbl = Label.new()
	_toast_sub_lbl.text = ""
	_toast_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_sub_lbl.custom_minimum_size = Vector2(210, 0)
	_toast_sub_lbl.add_theme_font_size_override("font_size", 10)
	_toast_sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.96))
	toast_text_vbox.add_child(_toast_sub_lbl)

	# 2. Dock Frame (7 Slot 32x32)
	var dock_frame := NinePatchRect.new()
	dock_frame.size_flags_horizontal = Control.SIZE_SHRINK_END
	dock_frame.custom_minimum_size = Vector2(278, 48)
	dock_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dock_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(TEX_DOCK_FRAME_PATH):
		dock_frame.texture = load(TEX_DOCK_FRAME_PATH)
		dock_frame.patch_margin_left = 12
		dock_frame.patch_margin_top = 12
		dock_frame.patch_margin_right = 12
		dock_frame.patch_margin_bottom = 12
	root_vbox.add_child(dock_frame)

	var dock_margin := MarginContainer.new()
	dock_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	dock_margin.add_theme_constant_override("margin_left", 9)
	dock_margin.add_theme_constant_override("margin_right", 9)
	dock_margin.add_theme_constant_override("margin_top", 8)
	dock_margin.add_theme_constant_override("margin_bottom", 8)
	dock_frame.add_child(dock_margin)

	var slots_hbox := HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 6)
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_margin.add_child(slots_hbox)

	var slots_data: Array[Dictionary] = FALLBACK_SLOTS
	if has_node("/root/SaveManager"):
		var sm := get_node("/root/SaveManager")
		if sm.get("DOCK_SLOTS") is Array:
			slots_data = sm.get("DOCK_SLOTS")

	for slot_meta in slots_data:
		var slot_id := str(slot_meta.get("id", ""))
		var col_idx := int(slot_meta.get("col_index", 0))
		var tip := str(slot_meta.get("tooltip", ""))

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(32, 32)
		btn.flat = true
		btn.focus_mode = Control.FOCUS_ALL
		btn.tooltip_text = tip
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty_sb := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_sb)
		btn.add_theme_stylebox_override("hover", empty_sb)
		btn.add_theme_stylebox_override("pressed", empty_sb)
		btn.add_theme_stylebox_override("focus", empty_sb)
		slots_hbox.add_child(btn)

		var bg_rect := TextureRect.new()
		bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bg_rect)

		var icon_rect := TextureRect.new()
		icon_rect.set_anchors_preset(Control.PRESET_CENTER)
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.offset_left = -12
		icon_rect.offset_top = -12
		icon_rect.offset_right = 12
		icon_rect.offset_bottom = 12
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_rect)

		var lock_rect := TextureRect.new()
		lock_rect.set_anchors_preset(Control.PRESET_CENTER)
		lock_rect.custom_minimum_size = Vector2(24, 24)
		lock_rect.offset_left = -12
		lock_rect.offset_top = -12
		lock_rect.offset_right = 12
		lock_rect.offset_bottom = 12
		lock_rect.texture = _lock_feature_tex
		lock_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		lock_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lock_rect)

		var w_entry := {
			"id": slot_id,
			"col_index": col_idx,
			"tooltip": tip,
			"button": btn,
			"bg": bg_rect,
			"icon": icon_rect,
			"lock": lock_rect,
			"hovered": false,
		}
		_slot_widgets.append(w_entry)

		btn.mouse_entered.connect(func() -> void:
			w_entry["hovered"] = true
			if _new_slots.has(slot_id):
				_new_slots.erase(slot_id)
			_apply_slot_visual(w_entry)
		)
		btn.mouse_exited.connect(func() -> void:
			w_entry["hovered"] = false
			_apply_slot_visual(w_entry)
		)
		btn.focus_entered.connect(func() -> void:
			w_entry["hovered"] = true
			if _new_slots.has(slot_id):
				_new_slots.erase(slot_id)
			_apply_slot_visual(w_entry)
		)
		btn.focus_exited.connect(func() -> void:
			w_entry["hovered"] = false
			_apply_slot_visual(w_entry)
		)
		btn.pressed.connect(func() -> void:
			if _new_slots.has(slot_id):
				_new_slots.erase(slot_id)
				_apply_slot_visual(w_entry)
			if slot_id == "bug_log":
				bug_log_requested.emit()
			else:
				tool_info_requested.emit(slot_id, tip)
		)


func refresh_slots() -> void:
	for w_entry in _slot_widgets:
		_apply_slot_visual(w_entry)


func _is_slot_unlocked(slot_id: String) -> bool:
	if slot_id == "output" or slot_id == "bug_log":
		return true
	if has_node("/root/SaveManager"):
		var sm := get_node("/root/SaveManager")
		if sm.has_method("is_dock_slot_unlocked"):
			return bool(sm.call("is_dock_slot_unlocked", slot_id))
	return false


func _apply_slot_visual(w_entry: Dictionary) -> void:
	var slot_id: String = w_entry["id"]
	var col_idx: int = w_entry["col_index"]
	var unlocked := _is_slot_unlocked(slot_id)
	var hovered := bool(w_entry.get("hovered", false))
	var is_new := _new_slots.has(slot_id)

	var bg_rect: TextureRect = w_entry["bg"]
	var icon_rect: TextureRect = w_entry["icon"]
	var lock_rect: TextureRect = w_entry["lock"]
	var btn: Button = w_entry["button"]

	if _slot_bg_texs.size() >= 4:
		if is_new:
			bg_rect.texture = _slot_bg_texs[3]
		elif hovered:
			bg_rect.texture = _slot_bg_texs[2]
		elif unlocked:
			bg_rect.texture = _slot_bg_texs[1]
		else:
			bg_rect.texture = _slot_bg_texs[0]

	if unlocked and col_idx < _tool_unlocked_texs.size():
		icon_rect.texture = _tool_unlocked_texs[col_idx]
		icon_rect.modulate = Color.WHITE
	elif not unlocked and col_idx < _tool_locked_texs.size():
		icon_rect.texture = _tool_locked_texs[col_idx]
		icon_rect.modulate = Color(0.8, 0.85, 0.92, 0.78)

	lock_rect.visible = not unlocked
	btn.tooltip_text = str(w_entry["tooltip"]) + (" [BARU!]" if is_new else "")


func _on_item_unlocked(unlock_info: Dictionary) -> void:
	var item_id := str(unlock_info.get("id", ""))
	if unlock_info.get("type", "") == "tool" and not item_id.is_empty():
		_new_slots[item_id] = true
	refresh_slots()

	_toast_queue.append(unlock_info)
	if not _toast_busy:
		_process_next_toast()


func _process_next_toast() -> void:
	if _toast_queue.is_empty() or not is_inside_tree():
		_toast_busy = false
		return

	_toast_busy = true
	var info: Dictionary = _toast_queue.pop_front()
	_toast_title_lbl.text = str(info.get("title", "Fitur Baru"))
	_toast_sub_lbl.text = str(info.get("subtitle", ""))
	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0

	var col_idx := int(info.get("col_index", -1))

	var fade_in := create_tween()
	fade_in.tween_property(_toast_panel, "modulate:a", 1.0, 0.2)

	# Putar 4-frame animasi gembok terbuka (~10 FPS)
	if not _lock_open_texs.is_empty():
		for f_tex in _lock_open_texs:
			if not is_inside_tree():
				_toast_busy = false
				return
			_toast_icon.texture = f_tex
			await get_tree().create_timer(0.1).timeout
			if not is_inside_tree():
				_toast_busy = false
				return

	# Tampilkan ikon item yang baru terbuka
	if col_idx >= 0 and col_idx < _tool_unlocked_texs.size():
		_toast_icon.texture = _tool_unlocked_texs[col_idx]

	if not is_inside_tree():
		_toast_busy = false
		return
	await get_tree().create_timer(3.5).timeout
	if not is_inside_tree():
		_toast_busy = false
		return

	var fade_out := create_tween()
	fade_out.tween_property(_toast_panel, "modulate:a", 0.0, 0.25)
	await fade_out.finished
	if not is_inside_tree():
		_toast_busy = false
		return
	_toast_panel.visible = false

	_process_next_toast()
