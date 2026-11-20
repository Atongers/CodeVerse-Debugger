@tool
class_name HudTopBar
extends HBoxContainer

## Komponen TopBar HUD bersama (Vitality Frame, Quest Card, BugLogBtn, MenuBtn & Mini Pause Konfirmasi Popup).

signal bug_log_requested()

var status_label: Label = null
var progress_label: Label = null
var bug_log_btn: Button = null
var menu_btn: Button = null
var hp_bar: ProgressBar = null
var en_bar: ProgressBar = null

var _hp_label: Label = null
var _hp_warn_icon: TextureRect = null
var _en_label: Label = null
var _quest_icon: TextureRect = null

var _hp_fill_normal: StyleBoxTexture = null
var _hp_fill_crit: StyleBoxTexture = null
var _en_fill_normal: StyleBoxTexture = null
var _en_fill_low: StyleBoxTexture = null

var _quest_active_tex: AtlasTexture = null
var _quest_done_tex: AtlasTexture = null

var _pause_dimmer: ColorRect = null
var _pause_modal: PanelContainer = null
var _resume_btn: Button = null
var _dex_ref: Node = null
var _total_terminals: int = 4


static func attach_to_hud(hud_layer: CanvasLayer, dex: Node, total_terminals: int = 4) -> HudTopBar:
	if not hud_layer:
		return null
	var old_bar := hud_layer.get_node_or_null("TopBar")
	if old_bar:
		hud_layer.remove_child(old_bar)
		old_bar.queue_free()

	var bar := HudTopBar.new()
	bar.name = "TopBar"
	bar._dex_ref = dex
	bar._total_terminals = total_terminals
	hud_layer.add_child(bar)
	bar._build_pause_popup(hud_layer)
	return bar


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_left = 10.0
	offset_top = 6.0
	offset_right = -10.0
	offset_bottom = 50.0
	add_theme_constant_override("separation", 8)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_prepare_textures()
	_build_clusters()
	_connect_dex()
	set_progress(0, _total_terminals)


func _prepare_textures() -> void:
	var bars_tex: Texture2D = load(UiPixelTheme.TEX_HUD_VITAL_BARS) if ResourceLoader.exists(UiPixelTheme.TEX_HUD_VITAL_BARS) else null
	if bars_tex:
		_hp_fill_normal = UiPixelTheme.make_9slice(UiPixelTheme.make_atlas(bars_tex, Rect2(32, 0, 32, 32)), 6, 0, 0)
		_hp_fill_crit = UiPixelTheme.make_9slice(UiPixelTheme.make_atlas(bars_tex, Rect2(32, 32, 32, 32)), 6, 0, 0)
		_en_fill_normal = UiPixelTheme.make_9slice(UiPixelTheme.make_atlas(bars_tex, Rect2(64, 0, 32, 32)), 6, 0, 0)
		_en_fill_low = UiPixelTheme.make_9slice(UiPixelTheme.make_atlas(bars_tex, Rect2(64, 32, 32, 32)), 6, 0, 0)

	_quest_active_tex = UiPixelTheme.load_atlas(UiPixelTheme.TEX_HUD_ICONS_16, Rect2(2 * 16, 0, 16, 16))
	_quest_done_tex = UiPixelTheme.load_atlas(UiPixelTheme.TEX_HUD_ICONS_16, Rect2(4 * 16, 0, 16, 16))


func _build_clusters() -> void:
	var bars_tex: Texture2D = load(UiPixelTheme.TEX_HUD_VITAL_BARS) if ResourceLoader.exists(UiPixelTheme.TEX_HUD_VITAL_BARS) else null
	var track_sb: StyleBoxTexture = UiPixelTheme.make_9slice(UiPixelTheme.make_atlas(bars_tex, Rect2(0, 0, 32, 32)), 6, 0, 0) if bars_tex else null

	# 1. Cluster Kiri: Vitality Frame
	var vital_panel := PanelContainer.new()
	vital_panel.name = "VitalityFrame"
	vital_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var vital_bg := UiPixelTheme.load_atlas(UiPixelTheme.TEX_HUD_CONTAINERS, Rect2(0, 0, 48, 48))
	if vital_bg:
		vital_panel.add_theme_stylebox_override("panel", UiPixelTheme.make_9slice(vital_bg, 10, 10, 6))
	add_child(vital_panel)

	var vital_hbox := HBoxContainer.new()
	vital_hbox.add_theme_constant_override("separation", 8)
	vital_panel.add_child(vital_hbox)

	# HP Cluster
	var hp_box := HBoxContainer.new()
	hp_box.name = "HPCluster"
	hp_box.add_theme_constant_override("separation", 5)
	vital_hbox.add_child(hp_box)

	var heart_icon := UiPixelTheme.make_icon_rect(UiPixelTheme.load_atlas(UiPixelTheme.TEX_HUD_ICONS_16, Rect2(0, 0, 16, 16)), Vector2(16, 16))
	hp_box.add_child(heart_icon)

	hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.custom_minimum_size = Vector2(96, 16)
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	hp_bar.show_percentage = false
	hp_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if track_sb:
		hp_bar.add_theme_stylebox_override("background", track_sb)
	if _hp_fill_normal:
		hp_bar.add_theme_stylebox_override("fill", _hp_fill_normal)
	hp_box.add_child(hp_bar)

	_hp_label = Label.new()
	_hp_label.text = "100/100"
	_hp_label.custom_minimum_size = Vector2(52, 0)
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.add_theme_color_override("font_color", Color("#86efac"))
	hp_box.add_child(_hp_label)

	_hp_warn_icon = UiPixelTheme.make_icon_rect(UiPixelTheme.load_atlas(UiPixelTheme.TEX_HUD_ICONS_16, Rect2(6 * 16, 0, 16, 16)), Vector2(16, 16))
	_hp_warn_icon.visible = false
	hp_box.add_child(_hp_warn_icon)

	# EN Cluster
	var en_box := HBoxContainer.new()
	en_box.name = "ENCluster"
	en_box.add_theme_constant_override("separation", 5)
	vital_hbox.add_child(en_box)

	var bolt_icon := UiPixelTheme.make_icon_rect(UiPixelTheme.load_atlas(UiPixelTheme.TEX_HUD_ICONS_16, Rect2(16, 0, 16, 16)), Vector2(16, 16))
	en_box.add_child(bolt_icon)

	en_bar = ProgressBar.new()
	en_bar.name = "ENBar"
	en_bar.custom_minimum_size = Vector2(96, 16)
	en_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	en_bar.max_value = 100.0
	en_bar.value = 100.0
	en_bar.show_percentage = false
	en_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if track_sb:
		en_bar.add_theme_stylebox_override("background", track_sb)
	if _en_fill_normal:
		en_bar.add_theme_stylebox_override("fill", _en_fill_normal)
	en_box.add_child(en_bar)

	_en_label = Label.new()
	_en_label.text = "100/100"
	_en_label.custom_minimum_size = Vector2(52, 0)
	_en_label.add_theme_font_size_override("font_size", 11)
	_en_label.add_theme_color_override("font_color", Color("#38bdf8"))
	en_box.add_child(_en_label)

	# 2. Cluster Tengah: Quest Tracker Card
	var quest_panel := PanelContainer.new()
	quest_panel.name = "QuestCard"
	quest_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var quest_bg := UiPixelTheme.load_atlas(UiPixelTheme.TEX_HUD_CONTAINERS, Rect2(48, 0, 48, 48))
	if quest_bg:
		quest_panel.add_theme_stylebox_override("panel", UiPixelTheme.make_9slice(quest_bg, 10, 12, 6))
	add_child(quest_panel)

	var quest_hbox := HBoxContainer.new()
	quest_hbox.add_theme_constant_override("separation", 8)
	quest_panel.add_child(quest_hbox)

	_quest_icon = UiPixelTheme.make_icon_rect(_quest_active_tex, Vector2(16, 16))
	quest_hbox.add_child(_quest_icon)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.clip_text = true
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.custom_minimum_size = Vector2(160, 0)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	quest_hbox.add_child(status_label)

	var term_icon := UiPixelTheme.make_icon_rect(UiPixelTheme.load_atlas(UiPixelTheme.TEX_HUD_ICONS_16, Rect2(3 * 16, 0, 16, 16)), Vector2(16, 16))
	quest_hbox.add_child(term_icon)

	progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.add_theme_color_override("font_color", Color("#38bdf8"))
	quest_hbox.add_child(progress_label)

	# 3. Cluster Kanan: Tombol Aksi
	bug_log_btn = Button.new()
	bug_log_btn.name = "BugLogBtn"
	bug_log_btn.text = "Bug Log (0/%d) [L]" % _total_terminals
	bug_log_btn.icon = UiPixelTheme.load_atlas(UiPixelTheme.TEX_TOOLS_24, Rect2(6 * 24, 0, 24, 24))
	bug_log_btn.add_theme_constant_override("icon_max_width", 16)
	bug_log_btn.add_theme_font_size_override("font_size", 12)
	UiPixelTheme.apply_pixel_button(bug_log_btn, "primary", 10, 6)
	bug_log_btn.pressed.connect(func() -> void: bug_log_requested.emit())
	add_child(bug_log_btn)

	menu_btn = Button.new()
	menu_btn.name = "MenuBtn"
	menu_btn.text = "Menu Utama"
	menu_btn.icon = UiPixelTheme.load_atlas(UiPixelTheme.TEX_HUD_ICONS_16, Rect2(5 * 16, 0, 16, 16))
	menu_btn.add_theme_constant_override("icon_max_width", 16)
	menu_btn.add_theme_font_size_override("font_size", 12)
	UiPixelTheme.apply_pixel_button(menu_btn, "secondary", 10, 6)
	menu_btn.pressed.connect(open_pause_popup)
	add_child(menu_btn)


func _connect_dex() -> void:
	if not _dex_ref:
		return
	if _dex_ref.has_signal("health_changed") and not _dex_ref.health_changed.is_connected(_on_hp_changed):
		_dex_ref.health_changed.connect(_on_hp_changed)
	elif _dex_ref.has_signal("hp_changed") and not _dex_ref.hp_changed.is_connected(_on_hp_changed):
		_dex_ref.hp_changed.connect(_on_hp_changed)
	if _dex_ref.has_signal("energy_changed") and not _dex_ref.energy_changed.is_connected(_on_energy_changed):
		_dex_ref.energy_changed.connect(_on_energy_changed)
	if "health" in _dex_ref and "max_health" in _dex_ref:
		_on_hp_changed(_dex_ref.health, _dex_ref.max_health)
	elif "current_hp" in _dex_ref and "max_hp" in _dex_ref:
		_on_hp_changed(_dex_ref.current_hp, _dex_ref.max_hp)
	if "energy" in _dex_ref and "max_energy" in _dex_ref:
		_on_energy_changed(_dex_ref.energy, _dex_ref.max_energy)
	elif "current_energy" in _dex_ref and "max_energy" in _dex_ref:
		_on_energy_changed(_dex_ref.current_energy, _dex_ref.max_energy)


func _on_hp_changed(cur: float, max_v: float) -> void:
	if hp_bar:
		hp_bar.max_value = max_v
		hp_bar.value = cur
		var crit := cur <= 30.0
		if crit and _hp_fill_crit:
			hp_bar.add_theme_stylebox_override("fill", _hp_fill_crit)
		elif not crit and _hp_fill_normal:
			hp_bar.add_theme_stylebox_override("fill", _hp_fill_normal)
		if is_instance_valid(_hp_warn_icon):
			_hp_warn_icon.visible = crit
	if _hp_label:
		_hp_label.text = "%d/%d" % [int(round(cur)), int(round(max_v))]
		_hp_label.add_theme_color_override("font_color", Color("#f87171") if cur <= 30.0 else Color("#86efac"))


func _on_energy_changed(cur: float, max_v: float) -> void:
	if en_bar:
		en_bar.max_value = max_v
		en_bar.value = cur
		var low := cur <= 20.0
		if low and _en_fill_low:
			en_bar.add_theme_stylebox_override("fill", _en_fill_low)
		elif not low and _en_fill_normal:
			en_bar.add_theme_stylebox_override("fill", _en_fill_normal)
	if _en_label:
		_en_label.text = "%d/%d" % [int(round(cur)), int(round(max_v))]
		_en_label.add_theme_color_override("font_color", Color("#fbbf24") if cur <= 20.0 else Color("#38bdf8"))


func set_status(text: String, color: Color = Color(0.88, 0.94, 1.0)) -> void:
	if status_label and not text.is_empty():
		status_label.text = text
		status_label.add_theme_color_override("font_color", color)


func set_progress(solved_count: int, total_terminals: int) -> void:
	_total_terminals = total_terminals
	if progress_label:
		progress_label.text = "Terminal: %d/%d | [Tab]" % [solved_count, total_terminals]
	if bug_log_btn:
		bug_log_btn.text = "Bug Log (%d/%d) [L]" % [solved_count, total_terminals]
	if is_instance_valid(_quest_icon):
		_quest_icon.texture = _quest_done_tex if solved_count >= total_terminals else _quest_active_tex


func _build_pause_popup(hud_layer: CanvasLayer) -> void:
	_pause_dimmer = ColorRect.new()
	_pause_dimmer.name = "PauseConfirmOverlay"
	_pause_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_dimmer.color = Color(0.02, 0.04, 0.08, 0.65)
	_pause_dimmer.visible = false
	_pause_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_layer.add_child(_pause_dimmer)

	var menu_icon := UiPixelTheme.load_atlas(UiPixelTheme.TEX_HUD_ICONS_16, Rect2(5 * 16, 0, 16, 16))
	var shell := UiPixelTheme.build_modal_shell("JEDA — KEMBALI KE MENU UTAMA?", Vector2(390, 175), menu_icon)
	_pause_modal = shell["modal"]
	_pause_modal.visible = true
	_pause_dimmer.add_child(_pause_modal)

	var close_btn: TextureButton = shell["close_btn"]
	close_btn.pressed.connect(close_pause_popup)

	var outer: VBoxContainer = shell["outer_vbox"]
	var desc := Label.new()
	desc.text = "Progres level di sesi terminal saat ini belum tersimpan permanen jika belum mencapai gerbang selesai."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.85, 0.9, 0.96))
	outer.add_child(desc)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	outer.add_child(btn_row)

	_resume_btn = Button.new()
	_resume_btn.text = "Lanjutkan Level"
	_resume_btn.custom_minimum_size = Vector2(140, 32)
	_resume_btn.add_theme_font_size_override("font_size", 12)
	UiPixelTheme.apply_pixel_button(_resume_btn, "primary", 12, 6)
	_resume_btn.pressed.connect(close_pause_popup)
	btn_row.add_child(_resume_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Ke Menu Utama"
	quit_btn.custom_minimum_size = Vector2(130, 32)
	quit_btn.add_theme_font_size_override("font_size", 12)
	UiPixelTheme.apply_pixel_button(quit_btn, "danger", 12, 6)
	quit_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/menus/main_menu.tscn")
	)
	btn_row.add_child(quit_btn)


func open_pause_popup() -> void:
	if not _pause_dimmer:
		return
	_pause_dimmer.visible = true
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_ui"):
		am.call("play_ui", "ui_modal_open")
	if _dex_ref:
		if "controls_enabled" in _dex_ref:
			_dex_ref.controls_enabled = false
		if "velocity" in _dex_ref:
			_dex_ref.velocity = Vector2.ZERO
	if is_instance_valid(_resume_btn):
		_resume_btn.call_deferred("grab_focus")


func close_pause_popup() -> void:
	if not _pause_dimmer or not _pause_dimmer.visible:
		return
	_pause_dimmer.visible = false
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_ui"):
		am.call("play_ui", "ui_modal_close")
	if _dex_ref and "controls_enabled" in _dex_ref:
		_dex_ref.controls_enabled = true


func is_pause_popup_open() -> bool:
	return is_instance_valid(_pause_dimmer) and _pause_dimmer.visible
