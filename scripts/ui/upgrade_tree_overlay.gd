@tool
class_name UpgradeTreeOverlay
extends CanvasLayer

## Modal 12-Node Upgrade Tree Graph World 2 ([U], W2-20 Icons + W2-21 Frame + Line2D Connectors).

signal upgrade_tree_closed()
signal upgrade_purchased(node_id: String)

var _is_open: bool = false
var _selected_node_id: String = "surv_1"

var _scrap_lbl: Label = null
var _graph_canvas: Control = null
var _detail_title: Label = null
var _detail_branch: Label = null
var _detail_desc: Label = null
var _detail_status: Label = null
var _buy_btn: Button = null


func _ready() -> void:
	layer = 24
	_build_ui()
	visible = false


func is_open() -> bool:
	return _is_open


func open_upgrade_tree() -> void:
	_is_open = true
	visible = true
	_refresh_graph()
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_ui"):
		am.call("play_ui", "ui_modal_open")


func close_upgrade_tree() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_ui"):
		am.call("play_ui", "ui_modal_close")
	upgrade_tree_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_U:
			close_upgrade_tree()
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
	modal.custom_minimum_size = Vector2(940, 520)
	modal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modal.add_theme_stylebox_override("panel", UiPixelTheme.make_modal_style())
	center.add_child(modal)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	modal.add_child(outer)

	var h_bar := HBoxContainer.new()
	h_bar.add_theme_constant_override("separation", 10)
	outer.add_child(h_bar)

	var coin_tex := UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_SCRAP_COIN, Rect2(0, 0, 16, 16))
	if coin_tex:
		h_bar.add_child(UiPixelTheme.make_icon_rect(coin_tex, Vector2(20, 20)))

	var title := Label.new()
	title.text = "FIRMWARE UPGRADE TREE — 12 NODE [U]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("#38bdf8"))
	h_bar.add_child(title)

	_scrap_lbl = Label.new()
	_scrap_lbl.add_theme_font_size_override("font_size", 14)
	_scrap_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
	h_bar.add_child(_scrap_lbl)

	var close_btn := UiPixelTheme.make_close_button()
	close_btn.pressed.connect(close_upgrade_tree)
	h_bar.add_child(close_btn)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	outer.add_child(split)

	var graph_panel := PanelContainer.new()
	graph_panel.custom_minimum_size = Vector2(660, 410)
	graph_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	graph_panel.add_theme_stylebox_override("panel", UiPixelTheme.make_card_style(0, 10, 10))
	split.add_child(graph_panel)

	_graph_canvas = Control.new()
	_graph_canvas.custom_minimum_size = Vector2(640, 390)
	graph_panel.add_child(_graph_canvas)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail_panel.add_theme_stylebox_override("panel", UiPixelTheme.make_card_style(1, 14, 12))
	split.add_child(detail_panel)

	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 10)
	detail_panel.add_child(dv)

	_detail_branch = Label.new()
	_detail_branch.add_theme_font_size_override("font_size", 11)
	_detail_branch.add_theme_color_override("font_color", Color("#fbbf24"))
	dv.add_child(_detail_branch)

	_detail_title = Label.new()
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_title.add_theme_font_size_override("font_size", 15)
	_detail_title.add_theme_color_override("font_color", Color("#38bdf8"))
	dv.add_child(_detail_title)

	_detail_desc = Label.new()
	_detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_font_size_override("font_size", 12)
	_detail_desc.add_theme_color_override("font_color", Color(0.88, 0.93, 0.98))
	dv.add_child(_detail_desc)

	_detail_status = Label.new()
	_detail_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_status.add_theme_font_size_override("font_size", 12)
	dv.add_child(_detail_status)

	_buy_btn = Button.new()
	_buy_btn.name = "BuyUpgradeBtn"
	_buy_btn.text = "Beli Upgrade"
	_buy_btn.custom_minimum_size = Vector2(0, 36)
	UiPixelTheme.apply_pixel_button(_buy_btn, "primary", 12, 6)
	_buy_btn.pressed.connect(_on_buy_pressed)
	dv.add_child(_buy_btn)


func _find_node_data(nid: String) -> Dictionary:
	for n in World2Data.UPGRADE_NODES:
		if str(n["id"]) == nid:
			return n
	return World2Data.UPGRADE_NODES[0]


func _refresh_graph() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	var bits := int(sm.get("scrap_bits")) if sm else 0
	if _scrap_lbl:
		_scrap_lbl.text = "Scrap Bits: %d" % bits

	if not _graph_canvas:
		return
	for ch in _graph_canvas.get_children():
		_graph_canvas.remove_child(ch)
		ch.queue_free()

	# Branch headers
	var headers := [
		["CABANG 1: SURVIVAL", Vector2(30, 12), Color("#4ade80")],
		["CABANG 2: TACTICAL EMP", Vector2(245, 12), Color("#38bdf8")],
		["CABANG 3: UTILITY", Vector2(475, 12), Color("#fbbf24")],
	]
	for h in headers:
		var lbl := Label.new()
		lbl.text = str(h[0])
		lbl.position = h[1] as Vector2
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", h[2] as Color)
		_graph_canvas.add_child(lbl)

	# Draw Line2D connectors first
	for nd in World2Data.UPGRADE_NODES:
		var pos_to: Vector2 = (nd["pos"] as Vector2) + Vector2(28, 28)
		var parents: Array = nd.get("parents", [])
		var is_bought := sm != null and sm.has_method("has_upgrade") and bool(sm.call("has_upgrade", str(nd["id"])))
		for p_id in parents:
			var p_data := _find_node_data(str(p_id))
			var pos_from: Vector2 = (p_data["pos"] as Vector2) + Vector2(28, 28)
			var line := Line2D.new()
			line.width = 3.0
			line.default_color = Color("#38bdf8") if is_bought else Color(0.28, 0.36, 0.48, 0.85)
			line.add_point(pos_from)
			line.add_point(pos_to)
			_graph_canvas.add_child(line)

	# Create 12 Node Buttons
	for nd in World2Data.UPGRADE_NODES:
		var nid := str(nd["id"])
		var cost := int(nd["cost"])
		var parents: Array = nd.get("parents", [])
		var is_bought := sm != null and sm.has_method("has_upgrade") and bool(sm.call("has_upgrade", nid))
		var can_buy := sm != null and sm.has_method("can_purchase_upgrade") and bool(sm.call("can_purchase_upgrade", nid, cost, parents))

		var state_col := 2 if is_bought else (1 if can_buy else 0)
		var btn := Button.new()
		btn.name = "Node_" + nid
		btn.position = nd["pos"] as Vector2
		btn.custom_minimum_size = Vector2(56, 56)
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sb := UiPixelTheme.make_tree_node_style(state_col)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("focus", sb)

		var icon_tex := UiPixelTheme.load_atlas(
			UiPixelTheme.TEX_W2_UPGRADE_ICONS,
			Rect2(int(nd["col"]) * 32, int(nd["row"]) * 32, 32, 32)
		)
		if icon_tex:
			btn.icon = icon_tex
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.expand_icon = true

		var nid_capture := nid
		btn.pressed.connect(func() -> void:
			_selected_node_id = nid_capture
			_refresh_detail_panel()
		)
		UiPixelTheme.attach_button_sfx(btn)
		_graph_canvas.add_child(btn)

		var cost_lbl := Label.new()
		cost_lbl.text = "✓ AKTIF" if is_bought else ("%d Bits" % cost)
		cost_lbl.position = (nd["pos"] as Vector2) + Vector2(-12, 58)
		cost_lbl.custom_minimum_size = Vector2(80, 14)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 10)
		cost_lbl.add_theme_color_override("font_color", Color("#4ade80") if is_bought else (Color("#fbbf24") if can_buy else Color(0.55, 0.62, 0.72)))
		_graph_canvas.add_child(cost_lbl)

	_refresh_detail_panel()


func _refresh_detail_panel() -> void:
	var nd := _find_node_data(_selected_node_id)
	var nid := str(nd["id"])
	var cost := int(nd["cost"])
	var parents: Array = nd.get("parents", [])

	var sm: Node = get_node_or_null("/root/SaveManager")
	var is_bought := sm != null and sm.has_method("has_upgrade") and bool(sm.call("has_upgrade", nid))
	var can_buy := sm != null and sm.has_method("can_purchase_upgrade") and bool(sm.call("can_purchase_upgrade", nid, cost, parents))

	_detail_branch.text = "CABANG %s" % str(nd["branch"]).to_upper()
	_detail_title.text = str(nd["name"])
	_detail_desc.text = str(nd["desc"])

	if is_bought:
		_detail_status.text = "Status: SUDAH TERPASANG ✓"
		_detail_status.add_theme_color_override("font_color", Color("#4ade80"))
		_buy_btn.text = "Sudah Dibeli ✓"
		_buy_btn.disabled = true
	elif can_buy:
		_detail_status.text = "Harga: %d Scrap Bits (Siap Dibeli)" % cost
		_detail_status.add_theme_color_override("font_color", Color("#fbbf24"))
		_buy_btn.text = "Beli Upgrade (%d Bits)" % cost
		_buy_btn.disabled = false
	else:
		var reason := "Butuh node prasyarat di atasnya atau Scrap Bits belum cukup (%d Bits)." % cost
		_detail_status.text = reason
		_detail_status.add_theme_color_override("font_color", Color("#fca5a5"))
		_buy_btn.text = "Terkunci (%d Bits)" % cost
		_buy_btn.disabled = true


func _on_buy_pressed() -> void:
	var nd := _find_node_data(_selected_node_id)
	var nid := str(nd["id"])
	var cost := int(nd["cost"])
	var parents: Array = nd.get("parents", [])
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("purchase_upgrade") and bool(sm.call("purchase_upgrade", nid, cost, parents)):
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_ui"):
			am.call("play_ui", "upgrade_buy")
		upgrade_purchased.emit(nid)
		_refresh_graph()
