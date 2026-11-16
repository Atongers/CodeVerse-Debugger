extends Node

## SaveManager Autoload (V2): Menyimpan progres World 1 & World 2 (skin, level, debug tools, Bug Log, Scrap Bits, inventory, Upgrade Tree, Quest, Lore, Achievements) ke user://save_data.json.

signal skin_changed(skin_id: String)
signal progression_updated()
signal item_unlocked(unlock_info: Dictionary)
signal achievement_unlocked(ach_id: String, ach_info: Dictionary)
signal quest_updated(quest_id: String)
signal scrap_bits_changed(new_amount: int)
signal inventory_changed()

const SAVE_PATH := "user://save_data.json"
const SAVE_VERSION := 2

const DOCK_SLOTS: Array[Dictionary] = [
	{"id": "output", "name": "Output Console", "col_index": 0, "tooltip": "Output Console — Panel output standar Python & print().", "always_unlocked": true},
	{"id": "print_tool", "name": "Quick-Insert Print", "col_index": 1, "tooltip": "Print Tool — Sisipkan print() cepat. (Terbuka: Tamat Level 2)", "always_unlocked": false},
	{"id": "step_trace", "name": "Step Trace", "col_index": 2, "tooltip": "Step Trace — Tersedia di Dunia 3 (Loop Labyrinth)", "always_unlocked": false},
	{"id": "watch_var", "name": "Watch Variabel", "col_index": 3, "tooltip": "Watch Variabel — Tersedia di Dunia 4 (Function Foundry)", "always_unlocked": false},
	{"id": "breakpoint", "name": "Breakpoint", "col_index": 4, "tooltip": "Breakpoint — Tersedia di Dunia 5 (List Citadel)", "always_unlocked": false},
	{"id": "speed_selector", "name": "Speed 2x / Skip", "col_index": 5, "tooltip": "Speed 2x / Skip — Percepat eksekusi Terminal. (Terbuka: Tamat Level 3)", "always_unlocked": false},
	{"id": "bug_log", "name": "Bug Log", "col_index": 6, "tooltip": "Bug Log [L] — Buka catatan bug Python level ini.", "always_unlocked": true},
]

const SKIN_METADATA := {
	"default": {
		"id": "default",
		"name": "Cyan Debugger",
		"subtitle": "Unit Standar Syntax Shore",
		"sheet_path": "res://assets/sprites/characters/dex_skin_default.png",
		"topdown_sheet_path": "res://assets/world_2/characters/dex_topdown_default.png",
		"col_index": 0,
		"trail_color": Color("#38bdf8"),
		"unlock_hint": "Terbuka sejak awal",
	},
	"volt_scout": {
		"id": "volt_scout",
		"name": "Volt Scout",
		"subtitle": "Armor Pengintai Bertegangan Tinggi",
		"sheet_path": "res://assets/sprites/characters/dex_skin_volt_scout.png",
		"topdown_sheet_path": "res://assets/world_2/characters/dex_topdown_volt_scout.png",
		"col_index": 1,
		"trail_color": Color("#fbbf24"),
		"unlock_hint": "Tamatkan Level 2",
	},
	"plasma_sentinel": {
		"id": "plasma_sentinel",
		"name": "Plasma Sentinel",
		"subtitle": "Armor Penjaga Inti Reaktor",
		"sheet_path": "res://assets/sprites/characters/dex_skin_plasma_sentinel.png",
		"topdown_sheet_path": "res://assets/world_2/characters/dex_topdown_plasma_sentinel.png",
		"col_index": 2,
		"trail_color": Color("#e879f9"),
		"unlock_hint": "Tamatkan Level 3",
	},
}

const TOOL_METADATA := {
	"output": {
		"id": "output",
		"name": "Output Console",
		"description": "Panel output standar Python & print().",
	},
	"print_tool": {
		"id": "print_tool",
		"name": "Quick-Insert Print Tool",
		"description": "Tombol [+ Sisipkan print()] untuk mempercepat inspeksi variabel di Terminal.",
	},
	"speed_selector": {
		"id": "speed_selector",
		"name": "Speed Selector 2x & Skip",
		"description": "Percepat atau lewati animasi eksekusi baris kode di Terminal.",
	},
}

const ACHIEVEMENT_METADATA := {
	"ACH-01": {"id": "ACH-01", "col": 0, "name": "Udara Permukaan", "desc": "Selesaikan Cutscene Transisi & injakkan kaki di Condition Canyon."},
	"ACH-02": {"id": "ACH-02", "col": 1, "name": "Warga Teladan", "desc": "Selesaikan seluruh Side Quest (SQ-01, SQ-02, SQ-03) di World 2."},
	"ACH-03": {"id": "ACH-03", "col": 2, "name": "Penyelamat Ngarai", "desc": "Pulihkan Boss Gatekeeper AI (MQ-03) ke mode pelindung sian."},
	"ACH-04": {"id": "ACH-04", "col": 3, "name": "Master Percabangan", "desc": "Selesaikan minimal 1 Terminal if/elif/else di World 2 tanpa Hint."},
	"ACH-05": {"id": "ACH-05", "col": 4, "name": "Ensiklopedia Kondisi", "desc": "Buka seluruh entri Bug Log World 2 (BUG-11 s/d BUG-16)."},
	"ACH-06": {"id": "ACH-06", "col": 5, "name": "Insinyur Kalibrasi", "desc": "Berhasil merakit item Logic-Calibrated pertama di Workbench (Coolant Stabilizer)."},
	"ACH-07": {"id": "ACH-07", "col": 6, "name": "Ahli Persenjataan", "desc": "Rakit Shield-Breaker EMP Coil di Workbench."},
	"ACH-08": {"id": "ACH-08", "col": 7, "name": "Arsitek Firmware", "desc": "Buka minimal 4 node pada Upgrade Tree Graph."},
	"ACH-09": {"id": "ACH-09", "col": 8, "name": "Baron Rongsokan", "desc": "Kumpulkan akumulasi total >= 200 Scrap Bits."},
	"ACH-10": {"id": "ACH-10", "col": 9, "name": "Pemadam Drone", "desc": "Kalahkan total >= 5 musuh menggunakan Tactical EMP Pulse."},
	"ACH-11": {"id": "ACH-11", "col": 10, "name": "Pemecah Perisai", "desc": "Hancurkan perisai kondisional Shield Sentinel di Power Sub-Station."},
	"ACH-12": {"id": "ACH-12", "col": 11, "name": "Sejarawan Ngarai", "desc": "Temukan seluruh 3 Lore Data Log yang tersebar di Condition Canyon."},
}

var active_skin: String = "default"
var unlocked_skins: Array[String] = ["default"]
var completed_levels: Array[String] = []
var unlocked_tools: Array[String] = ["output"]
var unlocked_bug_logs: Array[String] = ["BUG-01", "BUG-02", "BUG-03", "BUG-04", "BUG-05"]

# World 2 RPG & Progression State
var scrap_bits: int = 0
var total_scrap_earned: int = 0
var emp_kills: int = 0
var inventory: Dictionary = {}
var purchased_upgrades: Array[String] = []
var active_quests: Array[String] = ["MQ-01"]
var completed_quests: Array[String] = []
var quest_progress: Dictionary = {}
var collected_lore_logs: Array[String] = []
var unlocked_achievements: Array[String] = []
var story_flags: Dictionary = {}
var w2_solved_terminals: Array[String] = []

# Sandbox Act Launch State (In-Memory Playtest isolation)
var active_w2_act: int = 1
var is_sandbox_act: bool = false


func _ready() -> void:
	load_save()


func _apply_defaults() -> void:
	active_skin = "default"
	unlocked_skins = ["default"]
	completed_levels = []
	unlocked_tools = ["output"]
	unlocked_bug_logs = ["BUG-01", "BUG-02", "BUG-03", "BUG-04", "BUG-05"]
	scrap_bits = 0
	total_scrap_earned = 0
	emp_kills = 0
	inventory = {"scrap_metal": 2, "copper_wire": 1, "coolant_cell": 1, "repair_patch": 1, "battery_cell": 1}
	purchased_upgrades = []
	active_quests = ["MQ-01"]
	completed_quests = []
	quest_progress = {}
	collected_lore_logs = []
	unlocked_achievements = []
	story_flags = {}
	w2_solved_terminals = []
	active_w2_act = 1
	is_sandbox_act = false


func load_save() -> void:
	_apply_defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		save_data()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		save_data()
		return

	var d: Dictionary = parsed
	if d.has("unlocked_skins") and typeof(d["unlocked_skins"]) == TYPE_ARRAY:
		unlocked_skins.clear()
		for s in d["unlocked_skins"]:
			var sid := str(s)
			if SKIN_METADATA.has(sid) and not unlocked_skins.has(sid):
				unlocked_skins.append(sid)
		if not unlocked_skins.has("default"):
			unlocked_skins.insert(0, "default")

	if d.has("active_skin"):
		var req_skin := str(d["active_skin"])
		active_skin = req_skin if unlocked_skins.has(req_skin) else "default"

	if d.has("completed_levels") and typeof(d["completed_levels"]) == TYPE_ARRAY:
		completed_levels.clear()
		for lv in d["completed_levels"]:
			var lvid := str(lv)
			if not completed_levels.has(lvid):
				completed_levels.append(lvid)

	if d.has("unlocked_tools") and typeof(d["unlocked_tools"]) == TYPE_ARRAY:
		unlocked_tools.clear()
		for tl in d["unlocked_tools"]:
			var tid := str(tl)
			if not unlocked_tools.has(tid):
				unlocked_tools.append(tid)
		if not unlocked_tools.has("output"):
			unlocked_tools.insert(0, "output")

	if d.has("unlocked_bug_logs") and typeof(d["unlocked_bug_logs"]) == TYPE_ARRAY:
		unlocked_bug_logs.clear()
		for bg in d["unlocked_bug_logs"]:
			var bid := str(bg)
			if not unlocked_bug_logs.has(bid):
				unlocked_bug_logs.append(bid)

	scrap_bits = maxi(0, int(d.get("scrap_bits", 0)))
	total_scrap_earned = maxi(scrap_bits, int(d.get("total_scrap_earned", scrap_bits)))
	emp_kills = maxi(0, int(d.get("emp_kills", 0)))

	if d.has("inventory") and typeof(d["inventory"]) == TYPE_DICTIONARY:
		inventory = (d["inventory"] as Dictionary).duplicate(true)

	if d.has("purchased_upgrades") and typeof(d["purchased_upgrades"]) == TYPE_ARRAY:
		purchased_upgrades.clear()
		for up in d["purchased_upgrades"]:
			var uid := str(up)
			if not purchased_upgrades.has(uid):
				purchased_upgrades.append(uid)

	if d.has("active_quests") and typeof(d["active_quests"]) == TYPE_ARRAY:
		active_quests.clear()
		for q in d["active_quests"]:
			var qid := str(q)
			if not active_quests.has(qid):
				active_quests.append(qid)
		if active_quests.is_empty() and completed_quests.is_empty():
			active_quests.append("MQ-01")

	if d.has("completed_quests") and typeof(d["completed_quests"]) == TYPE_ARRAY:
		completed_quests.clear()
		for cq in d["completed_quests"]:
			var cqid := str(cq)
			if not completed_quests.has(cqid):
				completed_quests.append(cqid)

	if d.has("quest_progress") and typeof(d["quest_progress"]) == TYPE_DICTIONARY:
		quest_progress = (d["quest_progress"] as Dictionary).duplicate(true)

	if d.has("collected_lore_logs") and typeof(d["collected_lore_logs"]) == TYPE_ARRAY:
		collected_lore_logs.clear()
		for lg in d["collected_lore_logs"]:
			var lid := str(lg)
			if not collected_lore_logs.has(lid):
				collected_lore_logs.append(lid)

	if d.has("unlocked_achievements") and typeof(d["unlocked_achievements"]) == TYPE_ARRAY:
		unlocked_achievements.clear()
		for ac in d["unlocked_achievements"]:
			var aid := str(ac)
			if ACHIEVEMENT_METADATA.has(aid) and not unlocked_achievements.has(aid):
				unlocked_achievements.append(aid)

	if d.has("story_flags") and typeof(d["story_flags"]) == TYPE_DICTIONARY:
		story_flags = (d["story_flags"] as Dictionary).duplicate(true)

	if d.has("w2_solved_terminals") and typeof(d["w2_solved_terminals"]) == TYPE_ARRAY:
		w2_solved_terminals.clear()
		for st in d["w2_solved_terminals"]:
			var stid := str(st)
			if not w2_solved_terminals.has(stid):
				w2_solved_terminals.append(stid)


func save_data() -> void:
	# If in sandbox Act playtest mode, do not overwrite main save_data.json with temporary quest/inventory overrides
	if is_sandbox_act:
		return
	var payload := {
		"version": SAVE_VERSION,
		"active_skin": active_skin,
		"unlocked_skins": unlocked_skins,
		"completed_levels": completed_levels,
		"unlocked_tools": unlocked_tools,
		"unlocked_bug_logs": unlocked_bug_logs,
		"scrap_bits": scrap_bits,
		"total_scrap_earned": total_scrap_earned,
		"emp_kills": emp_kills,
		"inventory": inventory,
		"purchased_upgrades": purchased_upgrades,
		"active_quests": active_quests,
		"completed_quests": completed_quests,
		"quest_progress": quest_progress,
		"collected_lore_logs": collected_lore_logs,
		"unlocked_achievements": unlocked_achievements,
		"story_flags": story_flags,
		"w2_solved_terminals": w2_solved_terminals,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()


func configure_w2_act_session(act: int, use_sandbox: bool = true) -> void:
	if is_sandbox_act:
		load_save()
	active_w2_act = clampi(act, 1, 3)
	if active_w2_act == 1 and not use_sandbox:
		is_sandbox_act = false
		return

	if active_w2_act == 1:
		is_sandbox_act = false
		return

	is_sandbox_act = use_sandbox
	story_flags["w2_cutscene_seen"] = true
	if not completed_quests.has("MQ-01"):
		completed_quests.append("MQ-01")
	if not completed_quests.has("SQ-01"):
		completed_quests.append("SQ-01")
	if not completed_quests.has("SQ-02"):
		completed_quests.append("SQ-02")
	active_quests.erase("MQ-01")
	active_quests.erase("SQ-01")
	active_quests.erase("SQ-02")

	for tid in ["Terminal_1", "Terminal_2"]:
		if not w2_solved_terminals.has(tid):
			w2_solved_terminals.append(tid)

	quest_progress["elder_talked"] = true
	quest_progress["iff_dialog_solved"] = true
	quest_progress["coolant_delivered"] = true
	inventory["shield_breaker_coil"] = maxi(1, get_item_count("shield_breaker_coil"))
	inventory["repair_patch"] = maxi(2, get_item_count("repair_patch"))
	inventory["battery_cell"] = maxi(2, get_item_count("battery_cell"))
	inventory["copper_wire"] = maxi(2, get_item_count("copper_wire"))
	inventory["logic_core"] = maxi(1, get_item_count("logic_core"))
	scrap_bits = maxi(90, scrap_bits)

	if active_w2_act == 2:
		if not active_quests.has("MQ-02") and not completed_quests.has("MQ-02"):
			active_quests.append("MQ-02")
	elif active_w2_act == 3:
		if not completed_quests.has("MQ-02"):
			completed_quests.append("MQ-02")
		active_quests.erase("MQ-02")
		if not active_quests.has("MQ-03") and not completed_quests.has("MQ-03"):
			active_quests.append("MQ-03")
		if not w2_solved_terminals.has("Terminal_3"):
			w2_solved_terminals.append("Terminal_3")
		quest_progress["sentinel_defeated"] = true
		scrap_bits = maxi(150, scrap_bits)


func end_w2_sandbox_if_active() -> void:
	if is_sandbox_act:
		var kept_bugs := unlocked_bug_logs.duplicate()
		var kept_ach := unlocked_achievements.duplicate()
		is_sandbox_act = false
		load_save()
		var changed := false
		for b in kept_bugs:
			if not unlocked_bug_logs.has(b):
				unlocked_bug_logs.append(b)
				changed = true
		for a in kept_ach:
			if not unlocked_achievements.has(a):
				unlocked_achievements.append(a)
				changed = true
		if changed:
			save_data()


func get_all_skin_ids() -> Array[String]:
	return ["default", "volt_scout", "plasma_sentinel"]


func get_skin_metadata(skin_id: String) -> Dictionary:
	if SKIN_METADATA.has(skin_id):
		return SKIN_METADATA[skin_id]
	return SKIN_METADATA["default"]


func is_skin_unlocked(skin_id: String) -> bool:
	return unlocked_skins.has(skin_id)


func is_tool_unlocked(tool_id: String) -> bool:
	return unlocked_tools.has(tool_id)


func is_dock_slot_unlocked(slot_id: String) -> bool:
	if slot_id == "output" or slot_id == "bug_log":
		return true
	return is_tool_unlocked(slot_id)


func is_level_completed(level_id: String) -> bool:
	return completed_levels.has(level_id)


func is_bug_log_unlocked(bug_id: String) -> bool:
	return unlocked_bug_logs.has(bug_id)


func equip_skin(skin_id: String) -> bool:
	if not unlocked_skins.has(skin_id):
		return false
	if active_skin != skin_id:
		active_skin = skin_id
		save_data()
		skin_changed.emit(active_skin)
		progression_updated.emit()
	return true


func unlock_bug_log(bug_id: String) -> void:
	if bug_id.is_empty():
		return
	if not unlocked_bug_logs.has(bug_id):
		unlocked_bug_logs.append(bug_id)
		save_data()
		progression_updated.emit()
		item_unlocked.emit({
			"type": "bug_log",
			"id": bug_id,
			"title": "Bug Log: " + bug_id,
			"subtitle": "Entri katalog bug baru terbuka di Main Menu",
			"col_index": 6,
		})
	_check_w2_bug_achievement()


func _check_w2_bug_achievement() -> void:
	for bid in ["BUG-11", "BUG-12", "BUG-13", "BUG-14", "BUG-15", "BUG-16"]:
		if not unlocked_bug_logs.has(bid):
			return
	unlock_achievement("ACH-05")


# --- World 2 Economy, Inventory, Upgrades, Quests & Achievements API ---

func add_scrap_bits(amount: int) -> void:
	if amount <= 0:
		return
	scrap_bits += amount
	total_scrap_earned += amount
	save_data()
	scrap_bits_changed.emit(scrap_bits)
	progression_updated.emit()
	if total_scrap_earned >= 200:
		unlock_achievement("ACH-09")


func spend_scrap_bits(amount: int) -> bool:
	if amount < 0 or scrap_bits < amount:
		return false
	scrap_bits -= amount
	save_data()
	scrap_bits_changed.emit(scrap_bits)
	progression_updated.emit()
	return true


func get_item_count(item_id: String) -> int:
	return maxi(0, int(inventory.get(item_id, 0)))


func add_item(item_id: String, count: int = 1) -> void:
	if item_id.is_empty() or count <= 0:
		return
	inventory[item_id] = get_item_count(item_id) + count
	save_data()
	inventory_changed.emit()
	progression_updated.emit()


func consume_item(item_id: String, count: int = 1) -> bool:
	var cur := get_item_count(item_id)
	if count <= 0 or cur < count:
		return false
	inventory[item_id] = cur - count
	save_data()
	inventory_changed.emit()
	progression_updated.emit()
	return true


func has_upgrade(node_id: String) -> bool:
	return purchased_upgrades.has(node_id)


func can_purchase_upgrade(node_id: String, cost: int, parents: Array) -> bool:
	if purchased_upgrades.has(node_id):
		return false
	if scrap_bits < cost:
		return false
	if parents.is_empty():
		return true
	for p in parents:
		if purchased_upgrades.has(str(p)):
			return true
	return false


func purchase_upgrade(node_id: String, cost: int, parents: Array) -> bool:
	if not can_purchase_upgrade(node_id, cost, parents):
		return false
	scrap_bits -= cost
	purchased_upgrades.append(node_id)
	save_data()
	scrap_bits_changed.emit(scrap_bits)
	progression_updated.emit()
	if purchased_upgrades.size() >= 4:
		unlock_achievement("ACH-08")
	return true


func is_quest_active(quest_id: String) -> bool:
	return active_quests.has(quest_id)


func is_quest_completed(quest_id: String) -> bool:
	return completed_quests.has(quest_id)


func start_quest(quest_id: String) -> void:
	if quest_id.is_empty() or completed_quests.has(quest_id):
		return
	if not active_quests.has(quest_id):
		active_quests.append(quest_id)
		save_data()
		quest_updated.emit(quest_id)
		progression_updated.emit()


func complete_quest(quest_id: String, reward_bits: int = 0) -> void:
	if quest_id.is_empty() or completed_quests.has(quest_id):
		return
	active_quests.erase(quest_id)
	completed_quests.append(quest_id)
	if reward_bits > 0:
		scrap_bits += reward_bits
		total_scrap_earned += reward_bits
		scrap_bits_changed.emit(scrap_bits)
		if total_scrap_earned >= 200:
			unlock_achievement("ACH-09")

	# Auto-unlock gated quests
	if quest_id == "MQ-01":
		for sq in ["SQ-01", "SQ-02", "SQ-03"]:
			if not active_quests.has(sq) and not completed_quests.has(sq):
				active_quests.append(sq)
	elif (quest_id == "SQ-01" or quest_id == "SQ-02") and completed_quests.has("SQ-01") and completed_quests.has("SQ-02"):
		if not active_quests.has("MQ-02") and not completed_quests.has("MQ-02"):
			active_quests.append("MQ-02")
	elif quest_id == "MQ-02":
		if not active_quests.has("MQ-03") and not completed_quests.has("MQ-03"):
			active_quests.append("MQ-03")
	elif quest_id == "MQ-03":
		if not completed_levels.has("world_2_city"):
			completed_levels.append("world_2_city")
		unlock_achievement("ACH-03")

	if completed_quests.has("SQ-01") and completed_quests.has("SQ-02") and completed_quests.has("SQ-03"):
		unlock_achievement("ACH-02")

	save_data()
	quest_updated.emit(quest_id)
	progression_updated.emit()


func set_quest_flag(key: String, val: Variant) -> void:
	quest_progress[key] = val
	save_data()
	progression_updated.emit()


func get_quest_flag(key: String, default_val: Variant = false) -> Variant:
	return quest_progress.get(key, default_val)


func set_story_flag(key: String, val: Variant) -> void:
	story_flags[key] = val
	save_data()


func get_story_flag(key: String, default_val: Variant = false) -> Variant:
	return story_flags.get(key, default_val)


func record_emp_kill() -> void:
	emp_kills += 1
	save_data()
	if emp_kills >= 5:
		unlock_achievement("ACH-10")
	_check_sq03_completion()


func collect_lore_log(lore_id: String) -> bool:
	if lore_id.is_empty() or collected_lore_logs.has(lore_id):
		return false
	collected_lore_logs.append(lore_id)
	save_data()
	progression_updated.emit()
	if collected_lore_logs.size() >= 3:
		unlock_achievement("ACH-12")
	_check_sq03_completion()
	return true


func _check_sq03_completion() -> void:
	if is_quest_active("SQ-03") and collected_lore_logs.size() >= 3 and emp_kills >= 3:
		add_item("battery_cell", 2)
		complete_quest("SQ-03", 80)


func mark_w2_terminal_solved(term_id: String, used_hints: int = 0) -> void:
	if not w2_solved_terminals.has(term_id):
		w2_solved_terminals.append(term_id)
	if used_hints == 0:
		unlock_achievement("ACH-04")
	save_data()
	progression_updated.emit()


func is_w2_terminal_solved(term_id: String) -> bool:
	return w2_solved_terminals.has(term_id)


func is_achievement_unlocked(ach_id: String) -> bool:
	return unlocked_achievements.has(ach_id)


func unlock_achievement(ach_id: String) -> bool:
	if not ACHIEVEMENT_METADATA.has(ach_id) or unlocked_achievements.has(ach_id):
		return false
	unlocked_achievements.append(ach_id)
	save_data()
	var info: Dictionary = ACHIEVEMENT_METADATA[ach_id]
	achievement_unlocked.emit(ach_id, info)
	progression_updated.emit()
	return true


func record_level_completion(level_id: String) -> Array[Dictionary]:
	var newly_unlocked: Array[Dictionary] = []
	var unlock_events: Array[Dictionary] = []
	var changed := false

	if not completed_levels.has(level_id):
		completed_levels.append(level_id)
		changed = true

	match level_id:
		"world_1_level_1":
			for bid in ["BUG-01", "BUG-02", "BUG-03", "BUG-04", "BUG-05"]:
				if not unlocked_bug_logs.has(bid):
					unlocked_bug_logs.append(bid)
					changed = true
		"world_1_level_2":
			if not unlocked_skins.has("volt_scout"):
				unlocked_skins.append("volt_scout")
				newly_unlocked.append({"type": "skin", "id": "volt_scout", "name": "Skin: Volt Scout", "desc": "Armor amber dengan jejak sprint elektrik #fbbf24"})
				unlock_events.append({"type": "skin", "id": "volt_scout", "title": "Skin: Volt Scout", "subtitle": "Armor amber dengan jejak sprint elektrik", "col_index": -1})
				changed = true
			if not unlocked_tools.has("print_tool"):
				unlocked_tools.append("print_tool")
				newly_unlocked.append({"type": "tool", "id": "print_tool", "name": "Debug Tool: Quick-Insert Print", "desc": "Tombol [+ Sisipkan print()] kini aktif di Terminal"})
				unlock_events.append({"type": "tool", "id": "print_tool", "title": "Quick-Insert Print", "subtitle": "Tombol [+ print()] kini aktif di Terminal", "col_index": 1})
				changed = true
			for bid in ["BUG-06", "BUG-07", "BUG-08"]:
				if not unlocked_bug_logs.has(bid):
					unlocked_bug_logs.append(bid)
					newly_unlocked.append({"type": "bug_log", "id": bid, "name": "Bug Log: " + bid, "desc": "Entri katalog bug baru terbuka di Main Menu"})
					unlock_events.append({"type": "bug_log", "id": bid, "title": "Bug Log: " + bid, "subtitle": "Entri katalog bug baru terbuka", "col_index": 6})
					changed = true
		"world_1_level_3":
			if not unlocked_skins.has("plasma_sentinel"):
				unlocked_skins.append("plasma_sentinel")
				newly_unlocked.append({"type": "skin", "id": "plasma_sentinel", "name": "Skin: Plasma Sentinel", "desc": "Armor magenta dengan jejak sprint plasma #e879f9"})
				unlock_events.append({"type": "skin", "id": "plasma_sentinel", "title": "Skin: Plasma Sentinel", "subtitle": "Armor magenta dengan jejak sprint plasma", "col_index": -1})
				changed = true
			if not unlocked_tools.has("speed_selector"):
				unlocked_tools.append("speed_selector")
				newly_unlocked.append({"type": "tool", "id": "speed_selector", "name": "Debug Tool: Speed 2x & Skip", "desc": "Eksekusi kode cepat 2x & Skip kini aktif di Terminal"})
				unlock_events.append({"type": "tool", "id": "speed_selector", "title": "Speed 2x & Skip", "subtitle": "Eksekusi cepat 2x & Skip aktif di Terminal", "col_index": 5})
				changed = true
			for bid in ["BUG-09", "BUG-10"]:
				if not unlocked_bug_logs.has(bid):
					unlocked_bug_logs.append(bid)
					newly_unlocked.append({"type": "bug_log", "id": bid, "name": "Bug Log: " + bid, "desc": "Entri katalog bug baru terbuka di Main Menu"})
					unlock_events.append({"type": "bug_log", "id": bid, "title": "Bug Log: " + bid, "subtitle": "Entri katalog bug baru terbuka", "col_index": 6})
					changed = true

	if changed:
		save_data()
		progression_updated.emit()
		for ev in unlock_events:
			item_unlocked.emit(ev)

	return newly_unlocked


func reset_progression() -> void:
	_apply_defaults()
	save_data()
	skin_changed.emit(active_skin)
	scrap_bits_changed.emit(scrap_bits)
	inventory_changed.emit()
	progression_updated.emit()
