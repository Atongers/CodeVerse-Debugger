class_name UiPixelTheme
extends RefCounted

## Factory UI Pixel-Tech bersama (AtlasTexture, 9-Slice StyleBoxTexture, Button States, Modal Shell, Bug Card).

const TEX_MODAL_FRAME := "res://assets/ui/rework/ui_modal_frame_9slice.png"
const TEX_CARD_FRAMES := "res://assets/ui/rework/ui_card_frames_sheet.png"
const TEX_BTN_PIXEL := "res://assets/ui/rework/ui_btn_pixel_9slice_sheet.png"
const TEX_BTN_CLOSE := "res://assets/ui/rework/ui_btn_close_sheet.png"
const TEX_HUD_CONTAINERS := "res://assets/ui/rework/ui_hud_containers_sheet.png"
const TEX_HUD_VITAL_BARS := "res://assets/ui/rework/ui_hud_vital_bars_sheet.png"
const TEX_HUD_ICONS_16 := "res://assets/ui/rework/ui_hud_icons_16_sheet.png"
const TEX_LEVEL_STATE_ICONS := "res://assets/ui/rework/ui_level_state_icons_sheet.png"
const TEX_BUG_TAGS := "res://assets/ui/rework/ui_bug_tags_sheet.png"
const TEX_CODE_DIFF_BOX := "res://assets/ui/rework/ui_code_diff_box_9slice.png"
const TEX_SETTINGS_ICONS := "res://assets/ui/rework/ui_settings_icons_sheet.png"
const TEX_SLIDER_TRACK := "res://assets/ui/rework/ui_slider_track_9slice.png"
const TEX_SLIDER_GRABBER := "res://assets/ui/rework/ui_slider_grabber_sheet.png"
const TEX_TOGGLE_SWITCH := "res://assets/ui/rework/ui_toggle_switch_sheet.png"
const TEX_KEYCAP := "res://assets/ui/rework/ui_keycap_9slice.png"

const TEX_TOOLS_24 := "res://assets/ui/ui_tools_24_sheet.png"
const TEX_WORLD_BADGES := "res://assets/ui/ui_world_badges_sheet.png"
const TEX_LOCK_FEATURE := "res://assets/ui/ui_lock_feature_24.png"

const TEX_W2_CUTSCENE_SLIDES := "res://assets/world_2/story/story_w2_cutscene_slides.png"
const TEX_W2_LINT_PORTRAIT := "res://assets/world_2/story/story_lint_portrait_48.png"
const TEX_W2_DEX_DEFAULT := "res://assets/world_2/characters/dex_topdown_default.png"
const TEX_W2_DEX_VOLT := "res://assets/world_2/characters/dex_topdown_volt_scout.png"
const TEX_W2_DEX_PLASMA := "res://assets/world_2/characters/dex_topdown_plasma_sentinel.png"
const TEX_W2_TILESET := "res://assets/world_2/environment/world2_canyon_tileset.png"
const TEX_W2_BUILDINGS := "res://assets/world_2/environment/world2_buildings_props_sheet.png"
const TEX_W2_OBJECTS := "res://assets/world_2/objects/world2_condition_objects_sheet.png"
const TEX_W2_ATMOSPHERE := "res://assets/world_2/environment/world2_atmosphere_fx_sheet.png"
const TEX_W2_NPCS := "res://assets/world_2/characters/npc_canyon_robots_sheet.png"
const TEX_W2_NPC_PORTRAITS := "res://assets/world_2/ui/npc_canyon_portraits_48.png"
const TEX_W2_DIALOG_KIT := "res://assets/world_2/ui/ui_dialog_rpg_kit.png"
const TEX_W2_QUEST_EMOTES := "res://assets/world_2/ui/ui_quest_emotes_16.png"
const TEX_W2_ENEMY_HOUND := "res://assets/world_2/characters/enemy_scrap_hound_sheet.png"
const TEX_W2_ENEMY_DRONE := "res://assets/world_2/characters/enemy_patrol_drone_sheet.png"
const TEX_W2_ENEMY_SENTINEL := "res://assets/world_2/characters/enemy_shield_sentinel_sheet.png"
const TEX_W2_VFX_COMBAT := "res://assets/world_2/vfx/vfx_combat_and_shield_32.png"
const TEX_W2_WORKBENCH := "res://assets/world_2/objects/world2_workbench_station_sheet.png"
const TEX_W2_ITEMS_16 := "res://assets/world_2/items/world2_crafting_items_16_sheet.png"
const TEX_W2_SCRAP_COIN := "res://assets/world_2/ui/ui_scrap_bit_coin_16.png"
const TEX_W2_UPGRADE_ICONS := "res://assets/world_2/ui/ui_upgrade_tree_nodes_32.png"
const TEX_W2_TREE_FRAME := "res://assets/world_2/ui/ui_tree_node_frame_sheet.png"
const TEX_W2_BOSS_AI := "res://assets/world_2/characters/boss_gatekeeper_ai_sheet.png"
const TEX_W2_ACHIEVEMENTS := "res://assets/world_2/ui/ui_achievement_badges_24_sheet.png"


static func make_atlas(tex: Texture2D, rect: Rect2) -> AtlasTexture:
	if not tex:
		return null
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = rect
	at.filter_clip = true
	return at


static func load_atlas(path: String, rect: Rect2) -> AtlasTexture:
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	return make_atlas(tex, rect)


static func make_9slice(tex: Texture2D, margin: int, pad_h: int = 10, pad_v: int = 6) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


static func make_modal_style() -> StyleBoxTexture:
	var tex: Texture2D = load(TEX_MODAL_FRAME) if ResourceLoader.exists(TEX_MODAL_FRAME) else null
	return make_9slice(tex, 16, 18, 14)


static func make_card_style(col_idx: int = 0, pad_h: int = 12, pad_v: int = 8) -> StyleBoxTexture:
	var at := load_atlas(TEX_CARD_FRAMES, Rect2(col_idx * 48, 0, 48, 48))
	return make_9slice(at, 10, pad_h, pad_v)


static func attach_button_sfx(btn: BaseButton) -> void:
	if not btn or Engine.is_editor_hint() or btn.has_meta("_audio_sfx_hooked"):
		return
	btn.set_meta("_audio_sfx_hooked", true)
	btn.mouse_entered.connect(func() -> void:
		if not btn.disabled and btn.is_inside_tree():
			var am := btn.get_node_or_null("/root/AudioManager")
			if am and am.has_method("play_ui"):
				am.call("play_ui", "ui_hover")
	)
	btn.focus_entered.connect(func() -> void:
		if not btn.disabled and btn.is_inside_tree():
			var am := btn.get_node_or_null("/root/AudioManager")
			if am and am.has_method("play_ui"):
				am.call("play_ui", "ui_hover")
	)
	btn.pressed.connect(func() -> void:
		if btn.is_inside_tree():
			var am := btn.get_node_or_null("/root/AudioManager")
			if am and am.has_method("play_ui"):
				am.call("play_ui", "ui_click")
	)


static func apply_pixel_button(btn: Button, variant: String = "primary", pad_h: int = 12, pad_v: int = 6) -> void:
	var row := 0
	if variant == "secondary":
		row = 1
	elif variant == "danger":
		row = 2

	if ResourceLoader.exists(TEX_BTN_PIXEL):
		var sheet: Texture2D = load(TEX_BTN_PIXEL)
		if sheet:
			var sb_norm := make_9slice(make_atlas(sheet, Rect2(0, row * 32, 32, 32)), 8, pad_h, pad_v)
			var sb_hover := make_9slice(make_atlas(sheet, Rect2(32, row * 32, 32, 32)), 8, pad_h, pad_v)
			var sb_press := make_9slice(make_atlas(sheet, Rect2(64, row * 32, 32, 32)), 8, pad_h, pad_v)
			var sb_dis := make_9slice(make_atlas(sheet, Rect2(96, row * 32, 32, 32)), 8, pad_h, pad_v)
			btn.add_theme_stylebox_override("normal", sb_norm)
			btn.add_theme_stylebox_override("hover", sb_hover)
			btn.add_theme_stylebox_override("focus", sb_hover)
			btn.add_theme_stylebox_override("pressed", sb_press)
			btn.add_theme_stylebox_override("disabled", sb_dis)

	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_color_override("font_color", Color("#e2e8f0"))
	btn.add_theme_color_override("font_hover_color", Color("#ffffff"))
	btn.add_theme_color_override("font_focus_color", Color("#ffffff"))
	btn.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	btn.add_theme_color_override("font_disabled_color", Color("#64748b"))
	attach_button_sfx(btn)


static func make_close_button() -> TextureButton:
	var btn := TextureButton.new()
	btn.name = "CloseButton"
	btn.custom_minimum_size = Vector2(24, 24)
	btn.ignore_texture_size = false
	btn.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.focus_mode = Control.FOCUS_ALL
	btn.tooltip_text = "Tutup [Esc]"
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if ResourceLoader.exists(TEX_BTN_CLOSE):
		var sheet: Texture2D = load(TEX_BTN_CLOSE)
		if sheet:
			btn.texture_normal = make_atlas(sheet, Rect2(0, 0, 24, 24))
			btn.texture_hover = make_atlas(sheet, Rect2(24, 0, 24, 24))
			btn.texture_focused = make_atlas(sheet, Rect2(24, 0, 24, 24))
			btn.texture_pressed = make_atlas(sheet, Rect2(48, 0, 24, 24))
	attach_button_sfx(btn)
	return btn


static func make_icon_rect(tex: Texture2D, min_size: Vector2 = Vector2(16, 16)) -> TextureRect:
	var icon_rect := TextureRect.new()
	icon_rect.texture = tex
	icon_rect.custom_minimum_size = min_size
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon_rect


static func make_keycap_badge(key_text: String, font_bold: Font = null) -> PanelContainer:
	var pc := PanelContainer.new()
	if ResourceLoader.exists(TEX_KEYCAP):
		pc.add_theme_stylebox_override("panel", make_9slice(load(TEX_KEYCAP), 6, 8, 3))
	pc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var lbl := Label.new()
	lbl.text = key_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font_bold:
		lbl.add_theme_font_override("font", font_bold)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color("#38bdf8"))
	pc.add_child(lbl)
	return pc


static func build_modal_shell(title_text: String, size_vec: Vector2, header_icon_tex: Texture2D = null, font_bold: Font = null) -> Dictionary:
	var modal := PanelContainer.new()
	modal.visible = false
	modal.set_anchors_preset(Control.PRESET_CENTER)
	modal.custom_minimum_size = size_vec
	modal.offset_left = -size_vec.x * 0.5
	modal.offset_top = -size_vec.y * 0.5
	modal.offset_right = size_vec.x * 0.5
	modal.offset_bottom = size_vec.y * 0.5
	modal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modal.add_theme_stylebox_override("panel", make_modal_style())

	var outer_vbox := VBoxContainer.new()
	outer_vbox.name = "OuterVBox"
	outer_vbox.add_theme_constant_override("separation", 10)
	modal.add_child(outer_vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	outer_vbox.add_child(header)

	if header_icon_tex:
		header.add_child(make_icon_rect(header_icon_tex, Vector2(20, 20)))

	var t_lbl := Label.new()
	t_lbl.text = title_text
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.clip_text = true
	t_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if font_bold:
		t_lbl.add_theme_font_override("font", font_bold)
	t_lbl.add_theme_font_size_override("font_size", 15)
	t_lbl.add_theme_color_override("font_color", Color("#38bdf8"))
	header.add_child(t_lbl)

	var close_btn := make_close_button()
	header.add_child(close_btn)

	return {
		"modal": modal,
		"outer_vbox": outer_vbox,
		"header_hbox": header,
		"title_label": t_lbl,
		"close_btn": close_btn,
	}


static func _bug_tag_col(bug_id: String, bug_name: String) -> int:
	var upper_id := bug_id.to_upper()
	var lower_name := bug_name.to_lower()
	if upper_id == "BUG-01" or lower_name.contains("nameerror") or lower_name.contains("syntax"):
		return 1
	if upper_id in ["BUG-02", "BUG-10"] or lower_name.contains("typeerror") or lower_name.contains("casting"):
		return 2
	if upper_id.begins_with("BUG-") or lower_name.contains("logik") or lower_name.contains("operator") or lower_name.contains("modulo") or lower_name.contains("shadow") or lower_name.contains("pemdas") or lower_name.contains("slicing") or lower_name.contains("range"):
		return 3
	return 0


static func build_bug_card(entry: Dictionary, is_unlocked: bool, font_bold: Font = null, font_reg: Font = null, font_semi: Font = null) -> PanelContainer:
	var card := PanelContainer.new()
	card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card.add_theme_stylebox_override("panel", make_card_style(1 if is_unlocked else 2, 12, 10))

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 5)
	card.add_child(cv)

	var bug_id := str(entry.get("id", entry.get("terminal_id", "")))
	var bug_name := str(entry.get("name", entry.get("bug_type", "")))
	var tag_col := _bug_tag_col(bug_id, bug_name)

	var h_row := HBoxContainer.new()
	h_row.add_theme_constant_override("separation", 6)
	cv.add_child(h_row)

	var tag_tex := load_atlas(TEX_BUG_TAGS, Rect2(tag_col * 16, 0, 16, 16))
	if tag_tex:
		h_row.add_child(make_icon_rect(tag_tex, Vector2(16, 16)))

	if not is_unlocked and ResourceLoader.exists(TEX_LOCK_FEATURE):
		h_row.add_child(make_icon_rect(load(TEX_LOCK_FEATURE), Vector2(18, 18)))

	var h := Label.new()
	h.text = "[%s] %s" % [bug_id, bug_name if is_unlocked else (bug_name + " (Terkunci)")]
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_bold:
		h.add_theme_font_override("font", font_bold)
	h.add_theme_font_size_override("font_size", 13)
	h.add_theme_color_override("font_color", Color("#fbbf24") if is_unlocked else Color(0.55, 0.6, 0.7))
	h_row.add_child(h)

	if entry.has("world") or not is_unlocked:
		var w_lbl := Label.new()
		w_lbl.text = "Lokasi: %s" % str(entry.get("world", "-")) if is_unlocked else ("Syarat Terbuka: " + str(entry.get("unlock", "Selesaikan level")))
		w_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if font_semi:
			w_lbl.add_theme_font_override("font", font_semi)
		w_lbl.add_theme_font_size_override("font_size", 11)
		w_lbl.add_theme_color_override("font_color", Color("#38bdf8") if is_unlocked else Color(0.5, 0.56, 0.66))
		cv.add_child(w_lbl)

	if is_unlocked:
		var bad_code := str(entry.get("sample_bad", entry.get("broken_code", "")))
		var good_code := str(entry.get("sample_good", entry.get("fixed_code", "")))

		if not bad_code.is_empty():
			var bad_box := PanelContainer.new()
			bad_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			bad_box.add_theme_stylebox_override("panel", make_9slice(load_atlas(TEX_CODE_DIFF_BOX, Rect2(0, 0, 32, 32)), 6, 10, 5))
			var bad_row := HBoxContainer.new()
			bad_row.add_theme_constant_override("separation", 6)
			var bad_icon := load_atlas(TEX_BUG_TAGS, Rect2(72, 0, 8, 16))
			if bad_icon:
				bad_row.add_child(make_icon_rect(bad_icon, Vector2(8, 16)))
			var bad_lbl := Label.new()
			bad_lbl.text = "Salah : " + bad_code
			bad_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bad_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if font_reg:
				bad_lbl.add_theme_font_override("font", font_reg)
			bad_lbl.add_theme_font_size_override("font_size", 12)
			bad_lbl.add_theme_color_override("font_color", Color("#fca5a5"))
			bad_row.add_child(bad_lbl)
			bad_box.add_child(bad_row)
			cv.add_child(bad_box)

		if not good_code.is_empty():
			var good_box := PanelContainer.new()
			good_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			good_box.add_theme_stylebox_override("panel", make_9slice(load_atlas(TEX_CODE_DIFF_BOX, Rect2(32, 0, 32, 32)), 6, 10, 5))
			var good_row := HBoxContainer.new()
			good_row.add_theme_constant_override("separation", 6)
			var good_icon := load_atlas(TEX_BUG_TAGS, Rect2(64, 0, 8, 16))
			if good_icon:
				good_row.add_child(make_icon_rect(good_icon, Vector2(8, 16)))
			var good_lbl := Label.new()
			good_lbl.text = "Benar : " + good_code
			good_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			good_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if font_reg:
				good_lbl.add_theme_font_override("font", font_reg)
			good_lbl.add_theme_font_size_override("font_size", 12)
			good_lbl.add_theme_color_override("font_color", Color("#86efac"))
			good_row.add_child(good_lbl)
			good_box.add_child(good_row)
			cv.add_child(good_box)

		var desc_txt := str(entry.get("desc", entry.get("explanation", "")))
		if not desc_txt.is_empty():
			var d_lbl := Label.new()
			d_lbl.text = "Penjelasan: " + desc_txt
			d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if font_reg:
				d_lbl.add_theme_font_override("font", font_reg)
			d_lbl.add_theme_font_size_override("font_size", 12)
			d_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.96))
			cv.add_child(d_lbl)

	return card


static func make_rpg_dialog_style(pad_h: int = 14, pad_v: int = 10) -> StyleBoxTexture:
	var tex := load_atlas(TEX_W2_DIALOG_KIT, Rect2(0, 0, 48, 48))
	if not tex:
		return make_modal_style()
	return make_9slice(tex, 8, pad_h, pad_v)


static func make_rpg_portrait_frame_style() -> StyleBoxTexture:
	var tex := load_atlas(TEX_W2_DIALOG_KIT, Rect2(52, 2, 32, 32))
	if not tex:
		return make_card_style(0, 4, 4)
	return make_9slice(tex, 4, 4, 4)


static func get_w2_item_icon(col_idx: int, is_unlocked: bool = true) -> AtlasTexture:
	var row: int = 0 if is_unlocked else 1
	return load_atlas(TEX_W2_ITEMS_16, Rect2(clampi(col_idx, 0, 11) * 16, row * 16, 16, 16))


static func get_achievement_icon(col_idx: int, is_unlocked: bool = true) -> AtlasTexture:
	var row: int = 0 if is_unlocked else 1
	return load_atlas(TEX_W2_ACHIEVEMENTS, Rect2(clampi(col_idx, 0, 11) * 24, row * 24, 24, 24))


static func make_tree_node_style(state_col: int = 0) -> StyleBoxTexture:
	var tex := load_atlas(TEX_W2_TREE_FRAME, Rect2(clampi(state_col, 0, 2) * 48, 0, 48, 48))
	if not tex:
		return make_card_style(state_col, 6, 6)
	return make_9slice(tex, 8, 6, 6)

