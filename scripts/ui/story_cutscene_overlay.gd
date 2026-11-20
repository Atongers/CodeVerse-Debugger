@tool
class_name StoryCutsceneOverlay
extends CanvasLayer

## Overlay Cutscene Prolog 3-Slide World 2 (W2-01 + Potret Lint W2-02).

signal cutscene_finished()

var _is_open: bool = false
var _current_slide: int = 0
var _slides: Array[Dictionary] = []

var _backdrop: ColorRect = null
var _slide_rect: TextureRect = null
var _portrait_rect: TextureRect = null
var _title_lbl: Label = null
var _step_badge_lbl: Label = null
var _body_lbl: Label = null
var _next_btn: Button = null
var _skip_btn: Button = null


func _ready() -> void:
	layer = 28
	_slides = World2Data.CUTSCENE_SLIDES.duplicate(true)
	_build_ui()
	visible = false


func is_open() -> bool:
	return _is_open


func start_cutscene() -> void:
	_current_slide = 0
	_is_open = true
	visible = true
	_refresh_slide()
	var am := get_node_or_null("/root/AudioManager")
	if am:
		if am.has_method("set_ducking"):
			am.call("set_ducking", false, "all")
		if am.has_method("play_bgm"):
			am.call("play_bgm", "cutscene", 0.6)
	if is_instance_valid(_next_btn):
		_next_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_finish_cutscene()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_on_next_pressed()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.02, 0.03, 0.06, 0.94)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(760, 540)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_theme_stylebox_override("panel", UiPixelTheme.make_modal_style())
	center.add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	frame.add_child(vbox)

	# Header Row
	var h_row := HBoxContainer.new()
	h_row.add_theme_constant_override("separation", 10)
	vbox.add_child(h_row)

	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_size_override("font_size", 16)
	_title_lbl.add_theme_color_override("font_color", Color("#38bdf8"))
	h_row.add_child(_title_lbl)

	_step_badge_lbl = Label.new()
	_step_badge_lbl.add_theme_font_size_override("font_size", 13)
	_step_badge_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
	h_row.add_child(_step_badge_lbl)

	# Slide Art Container (640x360)
	var art_card := PanelContainer.new()
	art_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art_card.add_theme_stylebox_override("panel", UiPixelTheme.make_card_style(0, 6, 6))
	vbox.add_child(art_card)

	_slide_rect = TextureRect.new()
	_slide_rect.custom_minimum_size = Vector2(640, 340)
	_slide_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_slide_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_slide_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art_card.add_child(_slide_rect)

	# Dialog Box with Lint Portrait
	var dlg_box := PanelContainer.new()
	dlg_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dlg_box.add_theme_stylebox_override("panel", UiPixelTheme.make_rpg_dialog_style(14, 10))
	vbox.add_child(dlg_box)

	var dlg_hbox := HBoxContainer.new()
	dlg_hbox.add_theme_constant_override("separation", 14)
	dlg_box.add_child(dlg_hbox)

	var p_frame := PanelContainer.new()
	p_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p_frame.add_theme_stylebox_override("panel", UiPixelTheme.make_rpg_portrait_frame_style())
	dlg_hbox.add_child(p_frame)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(48, 48)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p_frame.add_child(_portrait_rect)

	_body_lbl = Label.new()
	_body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.add_theme_font_size_override("font_size", 13)
	_body_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 0.99))
	dlg_hbox.add_child(_body_lbl)

	# Action Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_skip_btn = Button.new()
	_skip_btn.name = "SkipButton"
	_skip_btn.text = "Lewati [Esc]"
	_skip_btn.custom_minimum_size = Vector2(140, 34)
	UiPixelTheme.apply_pixel_button(_skip_btn, "secondary", 12, 6)
	_skip_btn.pressed.connect(_finish_cutscene)
	btn_row.add_child(_skip_btn)

	_next_btn = Button.new()
	_next_btn.name = "NextButton"
	_next_btn.text = "Lanjut [Enter] ->"
	_next_btn.custom_minimum_size = Vector2(220, 34)
	UiPixelTheme.apply_pixel_button(_next_btn, "primary", 14, 6)
	_next_btn.pressed.connect(_on_next_pressed)
	btn_row.add_child(_next_btn)


func _refresh_slide() -> void:
	if _slides.is_empty():
		return
	var idx := clampi(_current_slide, 0, _slides.size() - 1)
	var data: Dictionary = _slides[idx]
	_title_lbl.text = str(data.get("title", "PROLOG DUNIA 2"))
	_step_badge_lbl.text = "Slide %d / %d" % [idx + 1, _slides.size()]
	_body_lbl.text = str(data.get("text", ""))

	var slide_i: int = int(data.get("slide_index", idx))
	_slide_rect.texture = UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_CUTSCENE_SLIDES, Rect2(slide_i * 640, 0, 640, 360))

	var lint_f: int = int(data.get("lint_frame", idx))
	_portrait_rect.texture = UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_LINT_PORTRAIT, Rect2(lint_f * 48, 0, 48, 48))

	if idx >= _slides.size() - 1:
		_next_btn.text = "Masuk ke Condition Canyon [Enter]"
	else:
		_next_btn.text = "Lanjut [Enter] ->"


func _on_next_pressed() -> void:
	if _current_slide < _slides.size() - 1:
		_current_slide += 1
		_refresh_slide()
	else:
		_finish_cutscene()


func _finish_cutscene() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_bgm"):
		am.call("play_bgm", "world2", 0.8)
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm:
		if sm.has_method("set_story_flag"):
			sm.call("set_story_flag", "w2_cutscene_seen", true)
		if sm.has_method("unlock_achievement"):
			sm.call("unlock_achievement", "ACH-01")
	cutscene_finished.emit()
