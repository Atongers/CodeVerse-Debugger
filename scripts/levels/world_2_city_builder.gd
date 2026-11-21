@tool
class_name World2CityBuilder
extends Node2D

## Builder & Game Loop Peta Kota Terpadu World 2: Condition Canyon (5 Distrik, 120x80 tiles = 1920x1280 px, Y-Sorted).

const MAP_WIDTH_TILES := 120
const MAP_HEIGHT_TILES := 80
const TILE_PX := 16
const TOTAL_TERMINALS := 5

const ACT_SPAWN_POS := {
	1: Vector2(220.0, 720.0),
	2: Vector2(1100.0, 660.0),
	3: Vector2(1600.0, 640.0),
}

var dex: DexTopDownController = null
var hud_layer: CanvasLayer = null
var top_bar: HudTopBar = null
var terminal_overlay: TerminalOverlay = null
var workbench_overlay: WorkbenchOverlay = null
var upgrade_tree_overlay: UpgradeTreeOverlay = null
var quest_journal_overlay: QuestJournalOverlay = null
var cutscene_overlay: StoryCutsceneOverlay = null
var boss_ai: BossGatekeeperAI = null

var _terminals_map: Dictionary = {}
var _terminal_sprites: Dictionary = {}
var _npcs_map: Dictionary = {}
var _lore_nodes: Dictionary = {}
var _workbench_area: Area2D = null
var _upgrade_area: Area2D = null
var _substation_barrier: StaticBody2D = null
var _overpass_barrier: StaticBody2D = null
var _w3_gate_area: Area2D = null
var _barrier_toast_cooldown_ms: int = 0

# World 2 HUD & Dialog UI refs
var _w2_bits_lbl: Label = null
var _w2_patch_btn: Button = null
var _w2_batt_btn: Button = null
var _dialog_modal: PanelContainer = null
var _dialog_portrait: TextureRect = null
var _dialog_speaker_lbl: Label = null
var _dialog_body_lbl: Label = null
var _dialog_choices_vbox: VBoxContainer = null
var _dialog_close_btn: Button = null
var _toast_panel: PanelContainer = null
var _toast_icon: TextureRect = null
var _toast_lbl: Label = null
var _toast_timer: float = 0.0
var _bug_log_modal: PanelContainer = null
var _bug_log_title: Label = null
var _bug_log_subtitle: Label = null
var _bug_log_vbox: VBoxContainer = null
var _boss_bgm_active: bool = false


func _ready() -> void:
	y_sort_enabled = true
	_build_city_environment()
	_build_districts_and_entities()
	_build_hud_and_overlays()
	_apply_act_spawn_and_state()

	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm:
		if sm.has_signal("progression_updated") and not sm.is_connected("progression_updated", _on_progression_updated):
			sm.connect("progression_updated", _on_progression_updated)
		if sm.has_signal("achievement_unlocked") and not sm.is_connected("achievement_unlocked", _on_achievement_unlocked):
			sm.connect("achievement_unlocked", _on_achievement_unlocked)

	_refresh_world_state()

	# Trigger Prolog Cutscene on Act 1 if not yet seen
	var act_num := int(sm.get("active_w2_act")) if sm else 1
	var seen_cut := bool(sm.call("get_story_flag", "w2_cutscene_seen", false)) if (sm and sm.has_method("get_story_flag")) else false
	var am := get_node_or_null("/root/AudioManager")
	if am:
		if am.has_method("stop_all_loops"):
			am.call("stop_all_loops")
		if am.has_method("set_ducking"):
			am.call("set_ducking", false, "all")
		if am.has_method("play_ambience"):
			am.call("play_ambience", "canyon_wind", 0.8)
	if act_num == 1 and not seen_cut and cutscene_overlay:
		cutscene_overlay.start_cutscene()
		_sync_input_lock()
	elif am and am.has_method("play_bgm"):
		am.call("play_bgm", "world2", 0.8)


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer = maxf(0.0, _toast_timer - delta)
		if _toast_timer <= 0.0 and _toast_panel:
			_toast_panel.visible = false
	_sync_input_lock()
	if dex and not Engine.is_editor_hint():
		# BeaconPad checkpoint activation for Act 2 & Act 3 pads
		for act_id in [2, 3]:
			var pad_pos: Vector2 = ACT_SPAWN_POS[act_id]
			if dex.global_position.distance_to(pad_pos) < 24.0 and dex.spawn_position.distance_to(pad_pos) > 10.0:
				dex.spawn_position = pad_pos
				var am_cp := get_node_or_null("/root/AudioManager")
				if am_cp and am_cp.has_method("play_sfx"):
					am_cp.call("play_sfx", "checkpoint_activate")
				_show_toast("Checkpoint BeaconPad Aktif!")
		# Boss Gatekeeper encounter BGM crossfade
		if boss_ai and not (cutscene_overlay and cutscene_overlay.is_open()):
			var am_b := get_node_or_null("/root/AudioManager")
			if am_b and am_b.has_method("play_bgm"):
				if boss_ai.phase < 2 and dex.global_position.x >= 1535.0 and not _boss_bgm_active:
					_boss_bgm_active = true
					am_b.call("play_bgm", "boss", 0.8)
				elif (boss_ai.phase >= 2 or dex.global_position.x < 1460.0) and _boss_bgm_active:
					_boss_bgm_active = false
					am_b.call("play_bgm", "world2", 0.8)


func _unhandled_input(event: InputEvent) -> void:
	if is_any_modal_open():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				if _dialog_modal and _dialog_modal.visible:
					_close_dialog_modal()
					get_viewport().set_input_as_handled()
				elif _bug_log_modal and _bug_log_modal.visible:
					_bug_log_modal.visible = false
					var am_c := get_node_or_null("/root/AudioManager")
					if am_c and am_c.has_method("play_ui"):
						am_c.call("play_ui", "ui_modal_close")
					_sync_input_lock()
					get_viewport().set_input_as_handled()
				elif top_bar and top_bar.is_pause_popup_open():
					top_bar.close_pause_popup()
					_sync_input_lock()
					get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			if quest_journal_overlay:
				quest_journal_overlay.open_journal()
				_sync_input_lock()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_U:
			if upgrade_tree_overlay:
				upgrade_tree_overlay.open_upgrade_tree()
				_sync_input_lock()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_L:
			_toggle_bug_log_modal(false)
			_sync_input_lock()
			get_viewport().set_input_as_handled()


func is_any_modal_open() -> bool:
	if cutscene_overlay and cutscene_overlay.is_open():
		return true
	if terminal_overlay and terminal_overlay.is_open():
		return true
	if workbench_overlay and workbench_overlay.is_open():
		return true
	if upgrade_tree_overlay and upgrade_tree_overlay.is_open():
		return true
	if quest_journal_overlay and quest_journal_overlay.is_open():
		return true
	if _dialog_modal and _dialog_modal.visible:
		return true
	if _bug_log_modal and _bug_log_modal.visible:
		return true
	if top_bar and top_bar.is_pause_popup_open():
		return true
	return false


func _sync_input_lock() -> void:
	if dex:
		dex.set_input_locked(is_any_modal_open())


func _build_city_environment() -> void:
	# Base Canyon Sand & Dusk Backdrop (1920x1280)
	var bg := ColorRect.new()
	bg.name = "CanyonBackground"
	bg.size = Vector2(1920, 1280)
	bg.color = Color("#161922")
	bg.z_index = -20
	add_child(bg)

	# TileMapLayer using W2-06 world2_canyon_tileset.png
	var terrain := TileMapLayer.new()
	terrain.name = "TerrainLayer"
	terrain.z_index = -10
	terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(UiPixelTheme.TEX_W2_TILESET):
		var ts := TileSet.new()
		ts.tile_size = Vector2i(16, 16)
		var src := TileSetAtlasSource.new()
		src.texture = load(UiPixelTheme.TEX_W2_TILESET)
		src.texture_region_size = Vector2i(16, 16)
		for tx in range(16):
			for ty in range(16):
				src.create_tile(Vector2i(tx, ty))
		ts.add_source(src, 0)
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(0, 1)
		ts.set_physics_layer_collision_mask(0, 1)
		var chasm_poly := PackedVector2Array([
			Vector2(-8.0, -8.0),
			Vector2(8.0, -8.0),
			Vector2(8.0, 8.0),
			Vector2(-8.0, 8.0),
		])
		for chasm_x in range(4):
			var chasm_coord := Vector2i(chasm_x, 9)
			if src.has_tile(chasm_coord):
				var td: TileData = src.get_tile_data(chasm_coord, 0)
				if td:
					td.set_collision_polygons_count(0, 1)
					td.set_collision_polygon_points(0, 0, chasm_poly)
		terrain.tile_set = ts

		# Paint full canyon sand ground, cobblestone roads, canyon chasm, and steel bridge across 5 districts
		for x in range(120):
			for y in range(80):
				terrain.set_cell(Vector2i(x, y), 0, Vector2i((x + y) % 4, (x + y * 2) % 4))
		# Scrap Haven plaza & District 4 sub-station concrete pads
		for x in range(30, 58):
			for y in range(32, 50):
				terrain.set_cell(Vector2i(x, y), 0, Vector2i((x + y) % 4, 5))
		for x in range(68, 91):
			for y in range(28, 50):
				terrain.set_cell(Vector2i(x, y), 0, Vector2i((x + y) % 4, 6))
		# Main road District 1 -> District 2 -> District 4 -> District 5
		for x in range(6, 118):
			for y in range(38, 45):
				terrain.set_cell(Vector2i(x, y), 0, Vector2i((x + y) % 4, 5 + (y % 2)))
		# North road District 2 -> District 3 (Scrapyard)
		for x in range(34, 44):
			for y in range(8, 39):
				terrain.set_cell(Vector2i(x, y), 0, Vector2i((x + y) % 4, 5 + (x % 2)))
		# Canyon chasm between District 4 and District 5
		for x in range(93, 98):
			for y in range(0, 80):
				terrain.set_cell(Vector2i(x, y), 0, Vector2i(x % 4, 9))
		# Overpass Steel Bridge (x: 91..100, y: 36..46)
		for x in range(91, 100):
			for y in range(36, 46):
				terrain.set_cell(Vector2i(x, y), 0, Vector2i(x % 4, 7))
	add_child(terrain)

	# District Visual Zones & Landmarks (W2-07 & W2-24)
	var props_root := Node2D.new()
	props_root.name = "BuildingsAndProps"
	props_root.y_sort_enabled = true
	add_child(props_root)

	# District 1: Outskirts Bunker Lab
	_spawn_building_prop(props_root, "BunkerLab", Rect2(0, 0, 120, 108), Vector2(140, 650))
	_spawn_atmosphere_fx(props_root, "Lantern_D1", Rect2(64, 0, 32, 32), Vector2(260, 670))

	# District 2: Scrap Haven Safe Hub
	_spawn_building_prop(props_root, "ScrapHavenTent", Rect2(120, 0, 144, 112), Vector2(680, 560))
	_spawn_building_prop(props_root, "WeatherSensorTower", Rect2(264, 0, 120, 112), Vector2(500, 460))
	_spawn_building_prop(props_root, "HavenBarTable", Rect2(132, 112, 80, 76), Vector2(600, 740))
	_spawn_building_prop(props_root, "HavenCrates", Rect2(0, 112, 64, 76), Vector2(490, 720))
	_spawn_atmosphere_fx(props_root, "FireBarrel_Haven", Rect2(0, 0, 32, 32), Vector2(640, 650))
	_spawn_atmosphere_fx(props_root, "Lantern_Haven", Rect2(64, 0, 32, 32), Vector2(750, 620))

	# District 3: Scrapyard Barat-Utara
	_spawn_building_prop(props_root, "MechaWreck_1", Rect2(212, 112, 76, 76), Vector2(320, 200))
	_spawn_building_prop(props_root, "TirePile_1", Rect2(0, 192, 84, 64), Vector2(480, 160))
	_spawn_building_prop(props_root, "OilBarrels_1", Rect2(68, 112, 64, 76), Vector2(760, 190))

	# District 4: Power Sub-Station Timur
	_spawn_building_prop(props_root, "SubStationTower", Rect2(264, 0, 120, 112), Vector2(1340, 480))
	_spawn_building_prop(props_root, "SolarPanels", Rect2(224, 192, 160, 64), Vector2(1180, 440))
	_spawn_building_prop(props_root, "CableSpools", Rect2(88, 192, 128, 64), Vector2(1220, 790))
	_spawn_atmosphere_fx(props_root, "Lantern_SubStation", Rect2(64, 0, 32, 32), Vector2(1130, 620))

	# District 5: Canyon Overpass & Boss Arena
	_spawn_building_prop(props_root, "Signpost_Boss", Rect2(288, 112, 96, 76), Vector2(1590, 560))

	_build_perimeter_and_substation_fences()


func _add_solid_footprint(parent: Node2D, size_vec: Vector2, offset_pos: Vector2 = Vector2.ZERO) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "SolidFootprint"
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size_vec
	col.shape = rect
	col.position = offset_pos
	body.add_child(col)
	parent.add_child(body)
	return body


func _build_perimeter_and_substation_fences() -> void:
	var walls := Node2D.new()
	walls.name = "WorldPerimeterWalls"
	add_child(walls)

	var bounds := [
		["WallLeft", Vector2(-8.0, 640.0), Vector2(16.0, 1312.0)],
		["WallRight", Vector2(1928.0, 640.0), Vector2(16.0, 1312.0)],
		["WallTop", Vector2(960.0, -8.0), Vector2(1952.0, 16.0)],
		["WallBottom", Vector2(960.0, 1288.0), Vector2(1952.0, 16.0)],
	]
	for b in bounds:
		var wall := StaticBody2D.new()
		wall.name = str(b[0])
		wall.position = b[1] as Vector2
		wall.collision_layer = 1
		wall.collision_mask = 0
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = b[2] as Vector2
		col.shape = rect
		wall.add_child(col)
		walls.add_child(wall)

	# District 2/3 -> District 4 cliff & fence divider at x = 980 (road opening y = 592..720)
	var divider := Node2D.new()
	divider.name = "SubstationBorderWalls"
	add_child(divider)
	var segments := [
		["SubstationWallNorth", Vector2(980.0, 296.0), Vector2(24.0, 592.0)],
		["SubstationWallSouth", Vector2(980.0, 1000.0), Vector2(24.0, 560.0)],
	]
	for seg in segments:
		var sb := StaticBody2D.new()
		sb.name = str(seg[0])
		sb.position = seg[1] as Vector2
		sb.collision_layer = 1
		sb.collision_mask = 0
		var s_size: Vector2 = seg[2] as Vector2
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = s_size
		col.shape = rect
		sb.add_child(col)
		var visual := ColorRect.new()
		visual.size = Vector2(14.0, s_size.y)
		visual.position = Vector2(-7.0, -s_size.y * 0.5)
		visual.color = Color(0.18, 0.22, 0.29, 0.92)
		sb.add_child(visual)
		var stripe := ColorRect.new()
		stripe.size = Vector2(4.0, s_size.y)
		stripe.position = Vector2(-2.0, -s_size.y * 0.5)
		stripe.color = Color(0.95, 0.55, 0.15, 0.55)
		sb.add_child(stripe)
		divider.add_child(sb)


func _spawn_building_prop(parent: Node, node_name: String, region: Rect2, pos: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = node_name
	sp.position = pos
	sp.texture = UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_BUILDINGS, region)
	sp.offset = Vector2(0.0, -region.size.y * 0.4)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add_solid_footprint(sp, Vector2(region.size.x * 0.72, maxf(16.0, region.size.y * 0.30)), Vector2(0.0, -region.size.y * 0.08))
	parent.add_child(sp)
	return sp


func _spawn_atmosphere_fx(parent: Node, node_name: String, region: Rect2, pos: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = node_name
	sp.position = pos
	sp.texture = UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_ATMOSPHERE, region)
	sp.offset = Vector2(0.0, -region.size.y * 0.4)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add_solid_footprint(sp, Vector2(16.0, 12.0), Vector2(0.0, -2.0))
	parent.add_child(sp)
	return sp


func _build_districts_and_entities() -> void:
	# 1. BeaconPads (Act 1, Act 2, Act 3)
	for act_id in ACT_SPAWN_POS.keys():
		var b_pos: Vector2 = ACT_SPAWN_POS[act_id]
		var pad := Sprite2D.new()
		pad.name = "BeaconPad_Act%d" % int(act_id)
		pad.position = b_pos
		pad.z_index = -2
		pad.texture = UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_OBJECTS, Rect2(2 * 32, 32, 32, 32))
		pad.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(pad)

	# 2. Player DexTopDown
	dex = get_node_or_null("DexTopDown") as DexTopDownController
	if not dex:
		dex = DexTopDownController.new()
		dex.name = "DexTopDown"
		add_child(dex)
	dex.global_position = ACT_SPAWN_POS[1]
	dex.spawn_position = ACT_SPAWN_POS[1]
	if not dex.emp_fired.is_connected(_on_dex_emp_fired):
		dex.emp_fired.connect(_on_dex_emp_fired)
	if not dex.interact_requested.is_connected(_on_dex_interact_requested):
		dex.interact_requested.connect(_on_dex_interact_requested)

	# 3. 3 Friendly NPCs in District 2 (Scrap Haven)
	var npcs_root := Node2D.new()
	npcs_root.name = "NPCs"
	npcs_root.y_sort_enabled = true
	add_child(npcs_root)

	var npc_configs := [
		{"id": "elder", "name": "Rusted Elder", "row": 0, "port": 0, "emote": 0, "pos": Vector2(590, 670)},
		{"id": "kael", "name": "Kael Scrapwright", "row": 1, "port": 1, "emote": 0, "pos": Vector2(760, 670)},
		{"id": "unit_m4", "name": "Unit-M4 Medic", "row": 2, "port": 2, "emote": 0, "pos": Vector2(880, 620)},
	]
	for nc in npc_configs:
		var npc := FriendlyNPC.new()
		npc.name = "NPC_" + str(nc["id"])
		npc.npc_id = str(nc["id"])
		npc.npc_name = str(nc["name"])
		npc.sprite_row = int(nc["row"])
		npc.portrait_col = int(nc["port"])
		npc.emote_col = int(nc["emote"])
		npc.position = nc["pos"] as Vector2
		npc.npc_interacted.connect(_on_npc_interacted)
		npcs_root.add_child(npc)
		_npcs_map[npc.npc_id] = npc

	# 4. WorkbenchStation & UpgradeStation in District 2
	_workbench_area = _create_station_area(
		"Workbench",
		UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_WORKBENCH, Rect2(0, 0, 64, 64)),
		Vector2(690, 745),
		"[E] Workbench Crafting"
	)
	add_child(_workbench_area)

	_upgrade_area = _create_station_area(
		"UpgradeStation",
		UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_OBJECTS, Rect2(3 * 32, 0, 32, 32)),
		Vector2(830, 745),
		"[E / U] Upgrade Tree"
	)
	add_child(_upgrade_area)

	# 5. 5 CodeTerminals (W2-08 Row 0)
	var terms_root := Node2D.new()
	terms_root.name = "Terminals"
	terms_root.y_sort_enabled = true
	add_child(terms_root)

	var term_positions := {
		"Terminal_1": Vector2(500, 540),
		"Terminal_2": Vector2(640, 180),
		"Terminal_3": Vector2(1450, 620),
		"Terminal_4A": Vector2(1655, 535),
		"Terminal_4B": Vector2(1655, 690),
	}
	for tid in term_positions.keys():
		var t_area := _create_w2_terminal_node(str(tid), term_positions[tid] as Vector2)
		terms_root.add_child(t_area)
		_terminals_map[str(tid)] = t_area

	# 6. Enemies (3x ScrapHound in D3, 2x PatrolDrone + 1x ShieldSentinel in D4)
	var enemies_root := Node2D.new()
	enemies_root.name = "Enemies"
	enemies_root.y_sort_enabled = true
	add_child(enemies_root)

	var enemy_spawns := [
		{"name": "ScrapHound_1", "type": 0, "pos": Vector2(360, 240), "coolant": true},
		{"name": "ScrapHound_2", "type": 0, "pos": Vector2(520, 220), "coolant": true},
		{"name": "ScrapHound_3", "type": 0, "pos": Vector2(730, 250), "coolant": false},
		{"name": "PatrolDrone_1", "type": 1, "pos": Vector2(1200, 540), "coolant": false},
		{"name": "PatrolDrone_2", "type": 1, "pos": Vector2(1250, 730), "coolant": false},
		{"name": "ShieldSentinel_1", "type": 2, "pos": Vector2(1375, 630), "coolant": false},
	]
	for es in enemy_spawns:
		var en := EnemyTopDown.new()
		en.name = str(es["name"])
		en.enemy_type = int(es["type"])
		en.guaranteed_coolant = bool(es["coolant"])
		en.position = es["pos"] as Vector2
		en.enemy_defeated.connect(_on_enemy_defeated)
		enemies_root.add_child(en)

	# 7. 3 Lore Data Logs (LORE-01..03)
	var lore_positions := {
		"LORE-01": Vector2(310, 680),
		"LORE-02": Vector2(270, 185),
		"LORE-03": Vector2(1150, 440),
	}
	for lid in lore_positions.keys():
		var l_node := _create_lore_pickup_node(str(lid), lore_positions[lid] as Vector2)
		add_child(l_node)
		_lore_nodes[str(lid)] = l_node

	# 8. East Sub-Station Barrier, Overpass Barrier & Boss Gatekeeper AI in District 5
	_substation_barrier = _create_progression_barrier(
		"EastSubstationBarrier",
		Vector2(980.0, 656.0),
		Vector2(26.0, 144.0),
		"[TERKUNCI] T1 + SQ-01 + T2",
		"Gerbang Gardu Timur terkunci! Selesaikan Terminal 1, SQ-01, & Terminal 2 dahulu."
	)
	add_child(_substation_barrier)

	_overpass_barrier = _create_progression_barrier(
		"OverpassBarrier",
		Vector2(1525.0, 656.0),
		Vector2(28.0, 192.0),
		"[TERKUNCI] Terminal 3",
		"Jembatan Overpass terkunci! Kalahkan Shield Sentinel & selesaikan Terminal 3 dahulu."
	)
	add_child(_overpass_barrier)

	boss_ai = BossGatekeeperAI.new()
	boss_ai.name = "BossGatekeeperAI"
	boss_ai.position = Vector2(1790, 595)
	boss_ai._build_visuals()
	boss_ai._refresh_visuals()
	boss_ai.subnode_unlocked.connect(_refresh_world_state)
	boss_ai.boss_restored.connect(_on_boss_restored)
	add_child(boss_ai)

	_w3_gate_area = _create_station_area(
		"World3ExitGate",
		UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_OBJECTS, Rect2(3 * 32, 64, 32, 32)),
		Vector2(1865, 590),
		"[E] Gerbang Dunia 3"
	)
	add_child(_w3_gate_area)


func _create_progression_barrier(node_name: String, pos: Vector2, size_vec: Vector2, status_text: String, toast_msg: String) -> StaticBody2D:
	var barrier := StaticBody2D.new()
	barrier.name = node_name
	barrier.position = pos
	barrier.collision_layer = 1
	barrier.collision_mask = 0

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = size_vec
	col.shape = rect
	barrier.add_child(col)

	var beam_rect := ColorRect.new()
	beam_rect.name = "BarrierBeam"
	beam_rect.size = Vector2(8.0, size_vec.y)
	beam_rect.position = Vector2(-4.0, -size_vec.y * 0.5)
	beam_rect.color = Color(0.95, 0.22, 0.30, 0.52)
	barrier.add_child(beam_rect)

	var sp := Sprite2D.new()
	sp.name = "BarrierSprite"
	sp.texture = UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_OBJECTS, Rect2(0, 64, 32, 32))
	sp.scale = Vector2(1.0, maxf(1.0, size_vec.y / 32.0))
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	barrier.add_child(sp)

	var lbl := Label.new()
	lbl.name = "StatusLabel"
	lbl.text = status_text
	lbl.position = Vector2(-95.0, -size_vec.y * 0.5 - 18.0)
	lbl.custom_minimum_size = Vector2(190.0, 16.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color("#fca5a5"))
	barrier.add_child(lbl)

	var hint_zone := Area2D.new()
	hint_zone.name = "HintZone"
	hint_zone.collision_layer = 0
	hint_zone.collision_mask = 1
	var hz_col := CollisionShape2D.new()
	var hz_rect := RectangleShape2D.new()
	hz_rect.size = size_vec + Vector2(30.0, 8.0)
	hz_col.shape = hz_rect
	hint_zone.add_child(hz_col)
	var msg_capture := toast_msg
	var barrier_ref := barrier
	hint_zone.body_entered.connect(func(b: Node2D) -> void:
		if not barrier_ref.visible or Engine.is_editor_hint():
			return
		if b and b.is_in_group("player"):
			var now_ms := Time.get_ticks_msec()
			if now_ms - _barrier_toast_cooldown_ms >= 1500:
				_barrier_toast_cooldown_ms = now_ms
				_show_toast(msg_capture)
	)
	barrier.add_child(hint_zone)
	return barrier


func _create_station_area(node_name: String, tex: Texture2D, pos: Vector2, prompt_txt: String) -> Area2D:
	var area := Area2D.new()
	area.name = node_name
	area.position = pos
	area.y_sort_enabled = true

	var col := CollisionShape2D.new()
	var c_shape := CircleShape2D.new()
	c_shape.radius = 30.0
	col.shape = c_shape
	area.add_child(col)

	var sp := Sprite2D.new()
	sp.name = "Sprite2D"
	sp.texture = tex
	sp.offset = Vector2(0.0, -16.0)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	area.add_child(sp)
	var fp_size := Vector2(38.0, 16.0) if node_name == "Workbench" else Vector2(24.0, 14.0)
	_add_solid_footprint(area, fp_size, Vector2(0.0, -4.0))

	var p_lbl := Label.new()
	p_lbl.name = "PromptLabel"
	p_lbl.text = prompt_txt
	p_lbl.visible = false
	p_lbl.position = Vector2(-70.0, -52.0)
	p_lbl.custom_minimum_size = Vector2(140.0, 16.0)
	p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_lbl.add_theme_font_size_override("font_size", 10)
	p_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
	area.add_child(p_lbl)

	area.body_entered.connect(func(b: Node2D) -> void:
		if b and b.is_in_group("player"):
			p_lbl.visible = true
	)
	area.body_exited.connect(func(b: Node2D) -> void:
		if b and b.is_in_group("player"):
			p_lbl.visible = false
	)
	return area


func _create_w2_terminal_node(term_id: String, pos: Vector2) -> Area2D:
	var area := Area2D.new()
	area.name = term_id
	area.position = pos
	area.y_sort_enabled = true

	var col := CollisionShape2D.new()
	var c_shape := CircleShape2D.new()
	c_shape.radius = 28.0
	col.shape = c_shape
	area.add_child(col)

	var sp := Sprite2D.new()
	sp.name = "Sprite2D"
	sp.texture = UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_OBJECTS, Rect2(0, 0, 32, 32))
	sp.offset = Vector2(0.0, -12.0)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	area.add_child(sp)
	_terminal_sprites[term_id] = sp
	_add_solid_footprint(area, Vector2(24.0, 14.0), Vector2(0.0, -4.0))

	var t_lbl := Label.new()
	t_lbl.name = "TitleLabel"
	t_lbl.text = term_id.replace("_", " ")
	t_lbl.position = Vector2(-50.0, 6.0)
	t_lbl.custom_minimum_size = Vector2(100.0, 14.0)
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_size_override("font_size", 10)
	t_lbl.add_theme_color_override("font_color", Color("#38bdf8"))
	area.add_child(t_lbl)

	var p_lbl := Label.new()
	p_lbl.name = "PromptLabel"
	p_lbl.text = "[E] Debug " + term_id
	p_lbl.visible = false
	p_lbl.position = Vector2(-60.0, -44.0)
	p_lbl.custom_minimum_size = Vector2(120.0, 16.0)
	p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_lbl.add_theme_font_size_override("font_size", 10)
	p_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
	area.add_child(p_lbl)

	area.body_entered.connect(func(b: Node2D) -> void:
		if b and b.is_in_group("player"):
			p_lbl.visible = true
	)
	area.body_exited.connect(func(b: Node2D) -> void:
		if b and b.is_in_group("player"):
			p_lbl.visible = false
	)
	return area


func _create_lore_pickup_node(lore_id: String, pos: Vector2) -> Area2D:
	var area := Area2D.new()
	area.name = lore_id
	area.position = pos

	var col := CollisionShape2D.new()
	var c_shape := CircleShape2D.new()
	c_shape.radius = 20.0
	col.shape = c_shape
	area.add_child(col)

	var sp := Sprite2D.new()
	sp.texture = UiPixelTheme.get_w2_item_icon(6, true)
	sp.scale = Vector2(1.4, 1.4)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	area.add_child(sp)

	var lbl := Label.new()
	lbl.text = lore_id
	lbl.position = Vector2(-36.0, -24.0)
	lbl.custom_minimum_size = Vector2(72.0, 14.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color("#4ade80"))
	area.add_child(lbl)

	var lid_capture := lore_id
	area.body_entered.connect(func(b: Node2D) -> void:
		if b and b.is_in_group("player"):
			var sm: Node = get_node_or_null("/root/SaveManager")
			if sm and sm.has_method("collect_lore_log") and bool(sm.call("collect_lore_log", lid_capture)):
				var am := get_node_or_null("/root/AudioManager")
				if am and am.has_method("play_sfx"):
					am.call("play_sfx", "loot_pickup_item")
				_show_toast("Data Log Ditemukan: " + lid_capture + " (Buka [J] untuk membaca)")
				area.visible = false
				area.set_deferred("monitoring", false)
	)
	return area


func _build_hud_and_overlays() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUD"
	hud_layer.layer = 10
	add_child(hud_layer)

	top_bar = HudTopBar.attach_to_hud(hud_layer, dex, TOTAL_TERMINALS)
	if top_bar:
		top_bar.bug_log_requested.connect(func() -> void: _toggle_bug_log_modal(false))

	var dock := DebugToolDock.new()
	dock.name = "DebugToolDock"
	dock.bug_log_requested.connect(func() -> void: _toggle_bug_log_modal(false))
	hud_layer.add_child(dock)

	# World 2 Bottom-Left Quick Action & Economy Bar
	var w2_bar := PanelContainer.new()
	w2_bar.name = "World2ActionBar"
	w2_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	w2_bar.offset_left = 12.0
	w2_bar.offset_top = -54.0
	w2_bar.offset_right = 760.0
	w2_bar.offset_bottom = -10.0
	w2_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	w2_bar.add_theme_stylebox_override("panel", UiPixelTheme.make_card_style(0, 10, 6))
	hud_layer.add_child(w2_bar)

	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 8)
	w2_bar.add_child(bh)

	var coin_icon := UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_SCRAP_COIN, Rect2(0, 0, 16, 16))
	if coin_icon:
		bh.add_child(UiPixelTheme.make_icon_rect(coin_icon, Vector2(18, 18)))

	_w2_bits_lbl = Label.new()
	_w2_bits_lbl.text = "0 Bits"
	_w2_bits_lbl.custom_minimum_size = Vector2(72, 0)
	_w2_bits_lbl.add_theme_font_size_override("font_size", 12)
	_w2_bits_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
	bh.add_child(_w2_bits_lbl)

	_w2_patch_btn = Button.new()
	_w2_patch_btn.text = "[1] Patch (0)"
	_w2_patch_btn.custom_minimum_size = Vector2(106, 30)
	UiPixelTheme.apply_pixel_button(_w2_patch_btn, "secondary", 8, 4)
	_w2_patch_btn.pressed.connect(func() -> void:
		if dex:
			dex.use_quick_repair_patch()
	)
	bh.add_child(_w2_patch_btn)

	_w2_batt_btn = Button.new()
	_w2_batt_btn.text = "[2] Battery (0)"
	_w2_batt_btn.custom_minimum_size = Vector2(114, 30)
	UiPixelTheme.apply_pixel_button(_w2_batt_btn, "secondary", 8, 4)
	_w2_batt_btn.pressed.connect(func() -> void:
		if dex:
			dex.use_quick_battery_cell()
	)
	bh.add_child(_w2_batt_btn)

	var emp_btn := Button.new()
	emp_btn.text = "[F] EMP Pulse"
	emp_btn.custom_minimum_size = Vector2(110, 30)
	UiPixelTheme.apply_pixel_button(emp_btn, "primary", 8, 4)
	emp_btn.pressed.connect(func() -> void:
		if dex:
			dex.try_fire_emp()
	)
	bh.add_child(emp_btn)

	var wb_btn := Button.new()
	wb_btn.text = "Workbench"
	wb_btn.custom_minimum_size = Vector2(96, 30)
	UiPixelTheme.apply_pixel_button(wb_btn, "primary", 8, 4)
	wb_btn.pressed.connect(func() -> void:
		if workbench_overlay:
			workbench_overlay.open_workbench(dex)
			_sync_input_lock()
	)
	bh.add_child(wb_btn)

	var upg_btn := Button.new()
	upg_btn.text = "[U] Upgrade"
	upg_btn.custom_minimum_size = Vector2(96, 30)
	UiPixelTheme.apply_pixel_button(upg_btn, "primary", 8, 4)
	upg_btn.pressed.connect(func() -> void:
		if upgrade_tree_overlay:
			upgrade_tree_overlay.open_upgrade_tree()
			_sync_input_lock()
	)
	bh.add_child(upg_btn)

	var jrn_btn := Button.new()
	jrn_btn.text = "[J] Jurnal"
	jrn_btn.custom_minimum_size = Vector2(88, 30)
	UiPixelTheme.apply_pixel_button(jrn_btn, "primary", 8, 4)
	jrn_btn.pressed.connect(func() -> void:
		if quest_journal_overlay:
			quest_journal_overlay.open_journal()
			_sync_input_lock()
	)
	bh.add_child(jrn_btn)

	_build_rpg_dialog_modal()
	_build_toast_banner()
	_build_bug_log_modal()

	# Overlays (Layers 20, 24, 28)
	terminal_overlay = TerminalOverlay.new()
	terminal_overlay.name = "TerminalOverlay"
	terminal_overlay.terminal_solved.connect(_on_terminal_solved)
	terminal_overlay.terminal_closed.connect(_sync_input_lock)
	add_child(terminal_overlay)

	workbench_overlay = WorkbenchOverlay.new()
	workbench_overlay.name = "WorkbenchOverlay"
	workbench_overlay.workbench_closed.connect(_sync_input_lock)
	workbench_overlay.item_crafted.connect(func(_id: String) -> void: _refresh_world_state())
	add_child(workbench_overlay)

	upgrade_tree_overlay = UpgradeTreeOverlay.new()
	upgrade_tree_overlay.name = "UpgradeTreeOverlay"
	upgrade_tree_overlay.upgrade_tree_closed.connect(_sync_input_lock)
	add_child(upgrade_tree_overlay)

	quest_journal_overlay = QuestJournalOverlay.new()
	quest_journal_overlay.name = "QuestJournalOverlay"
	quest_journal_overlay.journal_closed.connect(_sync_input_lock)
	add_child(quest_journal_overlay)

	cutscene_overlay = StoryCutsceneOverlay.new()
	cutscene_overlay.name = "StoryCutsceneOverlay"
	cutscene_overlay.cutscene_finished.connect(_sync_input_lock)
	add_child(cutscene_overlay)


func _build_rpg_dialog_modal() -> void:
	_dialog_modal = PanelContainer.new()
	_dialog_modal.name = "DialogRpgModal"
	_dialog_modal.visible = false
	_dialog_modal.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog_modal.custom_minimum_size = Vector2(760, 210)
	_dialog_modal.offset_left = -380.0
	_dialog_modal.offset_right = 380.0
	_dialog_modal.offset_top = -270.0
	_dialog_modal.offset_bottom = -60.0
	_dialog_modal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dialog_modal.add_theme_stylebox_override("panel", UiPixelTheme.make_rpg_dialog_style(16, 12))
	hud_layer.add_child(_dialog_modal)

	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	_dialog_modal.add_child(dv)

	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 12)
	dv.add_child(top_h)

	var p_frame := PanelContainer.new()
	p_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p_frame.add_theme_stylebox_override("panel", UiPixelTheme.make_rpg_portrait_frame_style())
	top_h.add_child(p_frame)

	_dialog_portrait = TextureRect.new()
	_dialog_portrait.custom_minimum_size = Vector2(48, 48)
	_dialog_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dialog_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p_frame.add_child(_dialog_portrait)

	var txt_v := VBoxContainer.new()
	txt_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt_v.add_theme_constant_override("separation", 4)
	top_h.add_child(txt_v)

	_dialog_speaker_lbl = Label.new()
	_dialog_speaker_lbl.add_theme_font_size_override("font_size", 14)
	_dialog_speaker_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
	txt_v.add_child(_dialog_speaker_lbl)

	_dialog_body_lbl = Label.new()
	_dialog_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_body_lbl.add_theme_font_size_override("font_size", 12)
	_dialog_body_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	txt_v.add_child(_dialog_body_lbl)

	_dialog_choices_vbox = VBoxContainer.new()
	_dialog_choices_vbox.add_theme_constant_override("separation", 6)
	dv.add_child(_dialog_choices_vbox)

	var b_row := HBoxContainer.new()
	b_row.alignment = BoxContainer.ALIGNMENT_END
	dv.add_child(b_row)

	_dialog_close_btn = Button.new()
	_dialog_close_btn.text = "Tutup Dialog [Esc]"
	_dialog_close_btn.custom_minimum_size = Vector2(140, 28)
	UiPixelTheme.apply_pixel_button(_dialog_close_btn, "secondary", 10, 4)
	_dialog_close_btn.pressed.connect(_close_dialog_modal)
	b_row.add_child(_dialog_close_btn)


func _close_dialog_modal() -> void:
	if _dialog_modal:
		_dialog_modal.visible = false
	var am := get_node_or_null("/root/AudioManager")
	if am:
		if am.has_method("set_ducking"):
			am.call("set_ducking", false, "npc_dialog")
		if am.has_method("play_ui"):
			am.call("play_ui", "ui_modal_close")
	_sync_input_lock()


func _build_toast_banner() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "ToastBanner"
	_toast_panel.visible = false
	_toast_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast_panel.offset_left = -420.0
	_toast_panel.offset_right = -14.0
	_toast_panel.offset_top = 56.0
	_toast_panel.offset_bottom = 104.0
	_toast_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_toast_panel.add_theme_stylebox_override("panel", UiPixelTheme.make_card_style(1, 12, 8))
	hud_layer.add_child(_toast_panel)

	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 8)
	_toast_panel.add_child(th)

	_toast_icon = TextureRect.new()
	_toast_icon.custom_minimum_size = Vector2(24, 24)
	_toast_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_toast_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	th.add_child(_toast_icon)

	_toast_lbl = Label.new()
	_toast_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_lbl.add_theme_font_size_override("font_size", 11)
	_toast_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
	th.add_child(_toast_lbl)


func _show_toast(text: String, icon_tex: Texture2D = null) -> void:
	if not _toast_panel or not _toast_lbl:
		return
	_toast_lbl.text = text
	if _toast_icon:
		_toast_icon.texture = icon_tex
		_toast_icon.visible = icon_tex != null
	_toast_panel.visible = true
	_toast_timer = 4.5


func _on_achievement_unlocked(ach_id: String, ach_info: Dictionary) -> void:
	var col := int(ach_info.get("col", 0))
	var icon := UiPixelTheme.get_achievement_icon(col, true)
	_show_toast("🏆 Achievement Terbuka: [%s] %s!" % [ach_id, str(ach_info.get("name", ach_id))], icon)


func _build_bug_log_modal() -> void:
	var book_icon := UiPixelTheme.load_atlas(UiPixelTheme.TEX_TOOLS_24, Rect2(6 * 24, 0, 24, 24))
	var shell := UiPixelTheme.build_modal_shell("BUG LOG — DUNIA 2: CONDITION CANYON", Vector2(760, 460), book_icon)
	_bug_log_modal = shell["modal"]
	_bug_log_modal.name = "BugLogModal"
	_bug_log_title = shell["title_label"]
	var close_x: TextureButton = shell["close_btn"]
	close_x.pressed.connect(func() -> void:
		_bug_log_modal.visible = false
		_sync_input_lock()
	)

	var vbox: VBoxContainer = shell["outer_vbox"]
	_bug_log_subtitle = Label.new()
	_bug_log_subtitle.text = "Katalog Bug Kondisional (BUG-11 s/d BUG-16):"
	_bug_log_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bug_log_subtitle.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_bug_log_subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_bug_log_vbox = VBoxContainer.new()
	_bug_log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bug_log_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_bug_log_vbox)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var menu_btn := Button.new()
	menu_btn.text = "Kembali ke Main Menu"
	menu_btn.custom_minimum_size = Vector2(180, 34)
	UiPixelTheme.apply_pixel_button(menu_btn, "primary", 12, 6)
	menu_btn.pressed.connect(func() -> void:
		var sm := get_node_or_null("/root/SaveManager")
		if sm and sm.has_method("end_w2_sandbox_if_active"):
			sm.call("end_w2_sandbox_if_active")
		get_tree().change_scene_to_file("res://scenes/ui/menus/main_menu.tscn")
	)
	btn_row.add_child(menu_btn)

	var close_btn := Button.new()
	close_btn.text = "Tutup [L / Esc]"
	close_btn.custom_minimum_size = Vector2(140, 34)
	UiPixelTheme.apply_pixel_button(close_btn, "secondary", 12, 6)
	close_btn.pressed.connect(func() -> void:
		_bug_log_modal.visible = false
		_sync_input_lock()
	)
	btn_row.add_child(close_btn)

	hud_layer.add_child(_bug_log_modal)


func _toggle_bug_log_modal(is_victory: bool) -> void:
	if not _bug_log_modal:
		return
	if _bug_log_modal.visible and not is_victory:
		_bug_log_modal.visible = false
		var am_c := get_node_or_null("/root/AudioManager")
		if am_c and am_c.has_method("play_ui"):
			am_c.call("play_ui", "ui_modal_close")
		return

	if is_victory:
		_bug_log_title.text = "DUNIA 2 SELESAI! — GATEKEEPER AI PULIH (MODE SIAN)"
		_bug_log_subtitle.text = "Selamat! Dex & Lint memulihkan jaringan Condition Canyon dan membuka akses menuju Dunia 3: Loop Labyrinth!"
	else:
		_bug_log_title.text = "BUG LOG — DUNIA 2: CONDITION CANYON"
		_bug_log_subtitle.text = "Katalog Bug Kondisional (BUG-11 s/d BUG-16):"

	for ch in _bug_log_vbox.get_children():
		_bug_log_vbox.remove_child(ch)
		ch.queue_free()

	var sm: Node = get_node_or_null("/root/SaveManager")
	for entry in World2Data.BUG_CATALOG_W2:
		var unlocked: bool = is_victory or (sm != null and sm.has_method("is_bug_log_unlocked") and bool(sm.call("is_bug_log_unlocked", str(entry["id"]))))
		_bug_log_vbox.add_child(UiPixelTheme.build_bug_card(entry, unlocked))

	_bug_log_modal.visible = true
	if not is_victory:
		var am_o := get_node_or_null("/root/AudioManager")
		if am_o and am_o.has_method("play_ui"):
			am_o.call("play_ui", "ui_modal_open")
	_sync_input_lock()


func _apply_act_spawn_and_state() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	var act: int = int(sm.get("active_w2_act")) if sm else 1
	var sp_pos: Vector2 = ACT_SPAWN_POS.get(clampi(act, 1, 3), ACT_SPAWN_POS[1])
	if dex:
		dex.global_position = sp_pos
		dex.spawn_position = sp_pos


func _on_progression_updated() -> void:
	_refresh_world_state()


func _refresh_world_state() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if not sm:
		return

	var bits := int(sm.get("scrap_bits"))
	if _w2_bits_lbl:
		_w2_bits_lbl.text = "%d Bits" % bits
	if _w2_patch_btn and sm.has_method("get_item_count"):
		_w2_patch_btn.text = "[1] Patch (%d)" % int(sm.call("get_item_count", "repair_patch"))
	if _w2_batt_btn and sm.has_method("get_item_count"):
		_w2_batt_btn.text = "[2] Battery (%d)" % int(sm.call("get_item_count", "battery_cell"))

	# Update terminal visual states & solved count
	var solved_cnt := 0
	for tid in _terminal_sprites.keys():
		var sp: Sprite2D = _terminal_sprites[tid]
		var solved := sm.has_method("is_w2_terminal_solved") and bool(sm.call("is_w2_terminal_solved", str(tid)))
		if solved:
			solved_cnt += 1
			sp.texture = UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_OBJECTS, Rect2(3 * 32, 0, 32, 32))
		else:
			sp.texture = UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_OBJECTS, Rect2(0, 0, 32, 32))

	# East Sub-Station Barrier open only after Terminal_1, SQ-01, and Terminal_2 are completed
	var substation_t1_done := sm.has_method("is_w2_terminal_solved") and bool(sm.call("is_w2_terminal_solved", "Terminal_1"))
	var substation_sq1_done := sm.has_method("is_quest_completed") and bool(sm.call("is_quest_completed", "SQ-01"))
	var substation_t2_done := sm.has_method("is_w2_terminal_solved") and bool(sm.call("is_w2_terminal_solved", "Terminal_2"))
	var substation_open := substation_t1_done and substation_sq1_done and substation_t2_done
	_set_barrier_open(_substation_barrier, substation_open)

	# Overpass Barrier open if Terminal_3 is solved
	var t3_done := sm.has_method("is_w2_terminal_solved") and bool(sm.call("is_w2_terminal_solved", "Terminal_3"))
	_set_barrier_open(_overpass_barrier, t3_done)

	# Update NPC Emotes
	if _npcs_map.has("elder"):
		var elder: FriendlyNPC = _npcs_map["elder"]
		var mq1_done := bool(sm.call("is_quest_completed", "MQ-01"))
		elder.set_emote(2 if mq1_done else 0)
	if _npcs_map.has("unit_m4"):
		var m4: FriendlyNPC = _npcs_map["unit_m4"]
		var sq1_done := bool(sm.call("is_quest_completed", "SQ-01"))
		var has_stab := int(sm.call("get_item_count", "coolant_stabilizer")) > 0
		m4.set_emote(2 if (sq1_done or has_stab) else 0)
	if _npcs_map.has("kael"):
		var kael: FriendlyNPC = _npcs_map["kael"]
		var sq2_done := bool(sm.call("is_quest_completed", "SQ-02"))
		var iff_ok := bool(sm.call("get_quest_flag", "iff_dialog_solved", false))
		kael.set_emote(2 if sq2_done else (1 if iff_ok else 0))

	# Update TopBar Quest Tracker
	if top_bar:
		top_bar.set_progress(solved_cnt, TOTAL_TERMINALS)
		if top_bar.bug_log_btn:
			top_bar.bug_log_btn.text = "Bug Log (%d/%d) [L]" % [solved_cnt, TOTAL_TERMINALS]
		var active_q: Array = sm.get("active_quests")
		if not active_q.is_empty():
			var qid := str(active_q[0])
			var q_info: Dictionary = World2Data.QUESTS.get(qid, {})
			top_bar.set_status("[%s] %s: %s" % [qid, str(q_info.get("title", qid)), str(q_info.get("desc", ""))])
		else:
			top_bar.set_status("Seluruh Misi Condition Canyon Selesai! Gerbang Dunia 3 Terbuka.", Color("#86efac"))


func _set_barrier_open(barrier: StaticBody2D, is_open: bool) -> void:
	if not barrier:
		return
	barrier.visible = not is_open
	var col_node := barrier.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_node:
		col_node.set_deferred("disabled", is_open)
	var hz := barrier.get_node_or_null("HintZone") as Area2D
	if hz:
		hz.set_deferred("monitoring", not is_open)


func _on_dex_emp_fired(origin: Vector2, radius: float, damage: float, stun_duration: float, emp_tier: int) -> void:
	for en in get_tree().get_nodes_in_group("w2_enemies"):
		if en and en.has_method("on_emp_hit"):
			en.call("on_emp_hit", origin, radius, damage, stun_duration, emp_tier)
	if boss_ai:
		var sm: Node = get_node_or_null("/root/SaveManager")
		var t3_done := sm != null and sm.has_method("is_w2_terminal_solved") and bool(sm.call("is_w2_terminal_solved", "Terminal_3"))
		if t3_done:
			boss_ai.on_emp_hit(origin, radius)
		elif boss_ai.global_position.distance_to(origin) <= radius + 90.0:
			_show_toast("Gatekeeper AI kebal! Selesaikan Terminal 3 (MQ-02) di Gardu Timur terlebih dahulu!")


func _on_enemy_defeated(enemy: EnemyTopDown, e_type: int, _drop_pos: Vector2) -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if not sm:
		return
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.call("play_sfx", "loot_pickup_coin")
		am.call("play_sfx", "loot_pickup_item")
	var bonus_bits := 5 if (sm.has_method("has_upgrade") and bool(sm.call("has_upgrade", "util_1"))) else 0
	match e_type:
		0: # ScrapHound
			sm.call("add_scrap_bits", 15 + bonus_bits)
			var drop_coolant: bool = (enemy != null and enemy.guaranteed_coolant) or (randf() < 0.65)
			if drop_coolant:
				sm.call("add_item", "coolant_cell", 1)
			sm.call("add_item", "scrap_metal", 1)
			var c_msg := ", +1 Coolant Cell" if drop_coolant else ""
			_show_toast("Loot Scrap Hound: +%d Bits%s, +1 Scrap Metal" % [15 + bonus_bits, c_msg])
		1: # PatrolDrone
			sm.call("add_scrap_bits", 20 + bonus_bits)
			sm.call("add_item", "copper_wire", 1)
			sm.call("add_item", "logic_core", 1)
			_show_toast("Loot Patrol Drone: +%d Bits, +1 Copper Wire, +1 Logic Core" % (20 + bonus_bits))
		2: # ShieldSentinel
			sm.call("add_scrap_bits", 45 + bonus_bits)
			sm.call("add_item", "logic_core", 2)
			sm.call("add_item", "glitch_shard", 1)
			_show_toast("Loot Shield Sentinel: +%d Bits, +2 Logic Core, +1 Glitch Shard" % (45 + bonus_bits))


func _on_dex_interact_requested() -> void:
	if is_any_modal_open() or not dex:
		return

	# 1. Check NPCs in range
	for nid in _npcs_map.keys():
		var npc: FriendlyNPC = _npcs_map[nid]
		if is_instance_valid(npc) and npc.is_player_in_range():
			_on_npc_interacted(npc)
			return

	# 2. Check Workbench / Upgrade Station / World 3 Exit Gate
	if _workbench_area and dex.global_position.distance_to(_workbench_area.global_position) <= 42.0:
		if workbench_overlay:
			workbench_overlay.open_workbench(dex)
			_sync_input_lock()
		return
	if _upgrade_area and dex.global_position.distance_to(_upgrade_area.global_position) <= 42.0:
		if upgrade_tree_overlay:
			upgrade_tree_overlay.open_upgrade_tree()
			_sync_input_lock()
		return
	if _w3_gate_area and dex.global_position.distance_to(_w3_gate_area.global_position) <= 48.0:
		var sm: Node = get_node_or_null("/root/SaveManager")
		if sm and sm.has_method("is_quest_completed") and bool(sm.call("is_quest_completed", "MQ-03")):
			_toggle_bug_log_modal(true)
		else:
			_show_toast("Gerbang Dunia 3 terkunci! Pulihkan Boss Gatekeeper AI (MQ-03) terlebih dahulu.")
		return

	# 3. Check CodeTerminals in range
	for tid in _terminals_map.keys():
		var t_area: Area2D = _terminals_map[tid]
		if is_instance_valid(t_area) and dex.global_position.distance_to(t_area.global_position) <= 44.0:
			_try_open_w2_terminal(str(tid))
			return


func _try_open_w2_terminal(term_id: String) -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if term_id == "Terminal_3":
		var t1_done := sm != null and sm.has_method("is_w2_terminal_solved") and bool(sm.call("is_w2_terminal_solved", "Terminal_1"))
		var sq1_done := sm != null and sm.has_method("is_quest_completed") and bool(sm.call("is_quest_completed", "SQ-01"))
		var t2_done := sm != null and sm.has_method("is_w2_terminal_solved") and bool(sm.call("is_w2_terminal_solved", "Terminal_2"))
		if not (t1_done and sq1_done and t2_done):
			_show_toast("Terminal 3 terkunci! Selesaikan Terminal 1, SQ-01, & Terminal 2 dahulu!")
			return
		var sentinel_alive := get_node_or_null("Enemies/ShieldSentinel_1") != null
		var sentinel_done := sm != null and sm.has_method("get_quest_flag") and bool(sm.call("get_quest_flag", "sentinel_defeated", false))
		if sentinel_alive and not sentinel_done:
			_show_toast("Terminal 3 dijaga Shield Sentinel! Rakit Shield-Breaker EMP Coil di Workbench lalu kalahkan Sentinel!")
			return
	if term_id == "Terminal_4A" or term_id == "Terminal_4B":
		var t3_done := sm != null and sm.has_method("is_w2_terminal_solved") and bool(sm.call("is_w2_terminal_solved", "Terminal_3"))
		if not t3_done:
			_show_toast("Akses Inti Kota terkunci! Selesaikan Terminal 3 (MQ-02) terlebih dahulu!")
			return
	if term_id == "Terminal_4A" and boss_ai and boss_ai.phase == 0 and not boss_ai.subnode_ready:
		_show_toast("Sub-Node terkunci perisai merah! Tembakkan EMP Pulse [F / Spasi] ke Boss terlebih dahulu!")
		return
	if term_id == "Terminal_4B" and boss_ai and boss_ai.phase < 1:
		_show_toast("Inti Gatekeeper AI masih terlindungi! Selesaikan Terminal 4A terlebih dahulu!")
		return

	var cfg: Dictionary = World2Data.TERMINALS.get(term_id, {})
	if cfg.is_empty() or not terminal_overlay:
		return
	terminal_overlay.open_terminal(term_id, cfg, TOTAL_TERMINALS)
	_sync_input_lock()


func _on_terminal_solved(term_id: String, _bug_info: Dictionary) -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if not sm:
		return

	var used_hints := terminal_overlay.get_used_hints(term_id) if terminal_overlay else 0
	sm.call("mark_w2_terminal_solved", term_id, used_hints)

	var cfg: Dictionary = World2Data.TERMINALS.get(term_id, {})
	for bid in cfg.get("unlock_bugs", []):
		sm.call("unlock_bug_log", str(bid))

	match term_id:
		"Terminal_1":
			sm.call("complete_quest", "MQ-01", 40)
			_show_toast("MQ-01 Selesai! +40 Scrap Bits. Misi Sampingan SQ-01, SQ-02, SQ-03 terbuka!")
		"Terminal_2":
			sm.call("complete_quest", "SQ-02", 50)
			_show_toast("SQ-02 Selesai! +50 Scrap Bits. Resep Shield-Breaker EMP Coil siap dirakit di Workbench!")
		"Terminal_3":
			sm.call("complete_quest", "MQ-02", 70)
			_show_toast("MQ-02 Selesai! +70 Scrap Bits. Jembatan Canyon Overpass menuju Boss Gatekeeper terbuka!")
		"Terminal_4A":
			if boss_ai:
				boss_ai.advance_to_overheat_phase()
			_show_toast("Perisai Boss Runtuh (OVERHEAT)! Segera perbaiki Inti AI di Terminal 4B!")
		"Terminal_4B":
			if boss_ai:
				boss_ai.advance_to_restored_phase()

	_refresh_world_state()


func _on_boss_restored() -> void:
	_boss_bgm_active = false
	var am := get_node_or_null("/root/AudioManager")
	if am:
		if am.has_method("play_bgm"):
			am.call("play_bgm", "world2", 1.0)
		if am.has_method("play_ui"):
			am.call("play_ui", "level_victory")
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm:
		sm.call("unlock_bug_log", "BUG-16")
		sm.call("complete_quest", "MQ-03", 120)
	_refresh_world_state()
	_toggle_bug_log_modal(true)


func _on_npc_interacted(npc: FriendlyNPC) -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if not sm or not _dialog_modal:
		return

	_dialog_portrait.texture = UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_NPC_PORTRAITS, Rect2(npc.portrait_col * 48, 0, 48, 48))
	_dialog_speaker_lbl.text = npc.npc_name

	for ch in _dialog_choices_vbox.get_children():
		_dialog_choices_vbox.remove_child(ch)
		ch.queue_free()

	if npc.npc_id == "elder":
		sm.call("set_quest_flag", "elder_talked", true)
		if not bool(sm.call("is_quest_completed", "MQ-01")):
			_dialog_body_lbl.text = "\"Selamat datang di Scrap Haven, Debugger. Badai debu merusak Menara Sensor Cuaca di utara tenda ini. Tolong perbaiki kondisi 'if' di Terminal 1 [E] agar gerbang kota stabil!\""
		else:
			_dialog_body_lbl.text = "\"Kerja bagus menstabilkan gerbang kota! Bantu Unit-M4 Medic (SQ-01) dan Kael Scrapwright (SQ-02) agar kita bisa menembus Gardu Listrik Timur dan memulihkan Gatekeeper AI.\""

	elif npc.npc_id == "unit_m4":
		if bool(sm.call("is_quest_completed", "SQ-01")):
			_dialog_body_lbl.text = "\"Terima kasih! Coolant Stabilizer buatanmu menjaga reaktor medis klinik tetap dingin. Gunakan Repair Patch [1] jika sasis-mu terluka.\""
		elif int(sm.call("get_item_count", "coolant_stabilizer")) > 0:
			sm.call("consume_item", "coolant_stabilizer", 1)
			sm.call("add_item", "repair_patch", 2)
			sm.call("complete_quest", "SQ-01", 50)
			_dialog_body_lbl.text = "\"Luar biasa! Kamu berhasil mengkalibrasi Coolant Stabilizer! Ini hadiahmu: +50 Scrap Bits dan 2x Repair Patch [1]!\""
			_refresh_world_state()
		else:
			_dialog_body_lbl.text = "\"Klinik darurat hampir overheat! Kumpulkan Coolant Cell dari Scrap Hound di Scrapyard Utara, lalu rakit 'Coolant Stabilizer' pada tab Layer 2 di Workbench [E]!\""

	elif npc.npc_id == "kael":
		var iff_solved := bool(sm.call("get_quest_flag", "iff_dialog_solved", false))
		if bool(sm.call("is_quest_completed", "SQ-02")):
			_dialog_body_lbl.text = "\"Turret IFF bengkel sudah aman! Jangan lupa merakit 'Shield-Breaker EMP Coil' di Workbench sebelum melawan Shield Sentinel di Gardu Timur.\""
		elif not iff_solved:
			_dialog_body_lbl.text = "\"Hei Dex! Sebelum kamu mengakses Terminal 2, bantu aku memilih ekspresi kondisi Python yang tepat agar turret HANYA mengizinkan masuk jika unit_tag adalah 'WARGA' DAN senjata_aktif bernilai False:\""
			var options := [
				{"text": "A) if unit_tag == \"WARGA\" and senjata_aktif == False:", "correct": true},
				{"text": "B) if unit_tag = \"WARGA\" or senjata_aktif == True:", "correct": false},
				{"text": "C) if unit_tag == \"WARGA\" and senjata_aktif == True:", "correct": false},
			]
			for opt in options:
				var obtn := Button.new()
				obtn.text = str(opt["text"])
				obtn.custom_minimum_size = Vector2(0, 28)
				var is_corr := bool(opt["correct"])
				UiPixelTheme.apply_pixel_button(obtn, "primary", 10, 4)
				obtn.pressed.connect(func() -> void:
					var am_dlg := get_node_or_null("/root/AudioManager")
					if is_corr:
						sm.call("set_quest_flag", "iff_dialog_solved", true)
						if am_dlg and am_dlg.has_method("play_ui"):
							am_dlg.call("play_ui", "code_solved")
						_dialog_body_lbl.text = "\"TEPAT SEKALI! Operator '==' membandingkan nilai dan 'and' memastikan kedua syarat terpenuhi. Sekarang perbaiki Terminal 2 di Scrapyard Utara!\""
						for c in _dialog_choices_vbox.get_children():
							c.queue_free()
						_refresh_world_state()
					else:
						if am_dlg and am_dlg.has_method("play_ui"):
							am_dlg.call("play_ui", "code_error")
						_dialog_body_lbl.text = "\"Hmm, belum tepat! Ingat: gunakan '==' untuk membandingkan dan 'and' dengan senjata_aktif == False. Coba pilih lagi!\""
				)
				_dialog_choices_vbox.add_child(obtn)
		else:
			_dialog_body_lbl.text = "\"Teka-teki logika IFF sudah kamu pecahkan! Sekarang pergilah ke utara (Distrik 3 Scrapyard) dan perbaiki Terminal 2 [E].\""

	var am_npc := get_node_or_null("/root/AudioManager")
	if am_npc:
		if am_npc.has_method("set_ducking"):
			am_npc.call("set_ducking", true, "npc_dialog")
		if am_npc.has_method("play_ui"):
			var blip_id := "npc_blip_elder"
			if npc.npc_id == "kael":
				blip_id = "npc_blip_kael"
			elif npc.npc_id == "unit_m4":
				blip_id = "npc_blip_medic"
			am_npc.call("play_ui", blip_id)
	_dialog_modal.visible = true
	_sync_input_lock()
