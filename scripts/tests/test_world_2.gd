extends SceneTree

## Headless Gate Verification Suite untuk World 2: Condition Canyon (Milestone 2A & 2B).
## Jalankan: godot --headless --path . --script res://scripts/tests/test_world_2.gd

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	await _run_all_tests()
	print("==========================================")
	print("TEST WORLD 2 RESULTS: %d passed, %d failed" % [passed, failed])
	print("==========================================")
	quit(1 if failed > 0 else 0)


func assert_true(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		push_error("FAIL [%s]" % label)


func assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		passed += 1
	else:
		failed += 1
		push_error("FAIL [%s]: expected '%s', got '%s'" % [label, str(expected), str(actual)])


func _run_all_tests() -> void:
	await process_frame
	_test_interpreter_world1_regression()
	_test_interpreter_world2_conditionals_and_bugs()
	_test_save_manager_and_rpg_state()
	await _test_world2_scene_and_acts()


func _test_interpreter_world1_regression() -> void:
	var code_w1 := "\n".join([
		"daya_awal = 60",
		"daya_tambahan = 40",
		"total_daya = daya_awal + daya_tambahan",
		"print(total_daya)",
		"aktifkan_elevator(total_daya)",
	])
	var res: Dictionary = PythonInterpreter.run_script(code_w1, ["aktifkan_elevator"])
	assert_eq(bool(res.get("ok", false)), true, "W1 regression script ok")
	var outs: Array = res.get("outputs", [])
	assert_eq(outs.size(), 1, "W1 regression output count")
	if outs.size() > 0:
		assert_eq(str(outs[0]), "100", "W1 regression output value")
	var calls: Array = res.get("calls", [])
	assert_eq(calls.size(), 1, "W1 regression call count")
	if calls.size() > 0:
		assert_eq(str(calls[0].get("name", "")), "aktifkan_elevator", "W1 regression call name")
		assert_eq(int(calls[0].get("args", [0])[0]), 100, "W1 regression call arg")


func _test_interpreter_world2_conditionals_and_bugs() -> void:
	# 1. Nested if / elif / else + boolean operators (and, or, not) + comparisons
	var code_nested := "\n".join([
		"suhu = 95",
		"darurat = False",
		"if suhu >= 90 and not darurat:",
		"    if suhu == 95 or suhu > 100:",
		"        mode = \"BUKA_INTI\"",
		"    else:",
		"        mode = \"SIAGA\"",
		"elif suhu >= 50:",
		"    mode = \"NORMAL\"",
		"else:",
		"    mode = \"DINGIN\"",
		"nonaktifkan_perisai_boss(mode)",
	])
	var res_ok: Dictionary = PythonInterpreter.run_script(code_nested, ["nonaktifkan_perisai_boss"])
	assert_eq(bool(res_ok.get("ok", false)), true, "W2 nested if/elif/else ok")
	var calls: Array = res_ok.get("calls", [])
	assert_eq(calls.size(), 1, "W2 nested call count")
	if calls.size() > 0:
		assert_eq(str(calls[0].get("args", [""])[0]), "BUKA_INTI", "W2 nested call arg BUKA_INTI")

	# 2. BUG-11: Missing colon ':' on if/elif/else
	var code_bug11 := "\n".join([
		"angin = 65",
		"if angin > 50",
		"    mode = \"TERLINDUNGI\"",
	])
	var res_b11: Dictionary = PythonInterpreter.run_script(code_bug11)
	assert_eq(bool(res_b11.get("ok", true)), false, "BUG-11 missing ':' detected")
	assert_eq(str(res_b11.get("error_type", "")), "SyntaxError", "BUG-11 error_type SyntaxError")
	assert_true(str(res_b11.get("error", "")).find("titik dua ':'") != -1, "BUG-11 Indonesian message mentions ':'")

	# 3. BUG-12: IndentationError on block body
	var code_bug12 := "\n".join([
		"aman = True",
		"if aman == True:",
		"aksi = \"AMAN_MASUK\"",
	])
	var res_b12: Dictionary = PythonInterpreter.run_script(code_bug12)
	assert_eq(bool(res_b12.get("ok", true)), false, "BUG-12 missing indent detected")
	assert_eq(str(res_b12.get("error_type", "")), "IndentationError", "BUG-12 error_type IndentationError")

	# 4. BUG-13: Single '=' inside if/elif condition
	var code_bug13 := "\n".join([
		"badai = True",
		"if badai = True:",
		"    mode = \"TERLINDUNGI\"",
	])
	var res_b13: Dictionary = PythonInterpreter.run_script(code_bug13)
	assert_eq(bool(res_b13.get("ok", true)), false, "BUG-13 single '=' in condition detected")
	assert_eq(str(res_b13.get("error_type", "")), "SyntaxError", "BUG-13 error_type SyntaxError")
	assert_true(str(res_b13.get("error", "")).find("'=='") != -1, "BUG-13 message mentions '=='")


func _test_save_manager_and_rpg_state() -> void:
	var sm: Node = root.get_node_or_null("/root/SaveManager")
	assert_true(sm != null, "SaveManager autoload exists")
	if not sm:
		return

	# Use sandbox flag so tests do not overwrite user's real save_data.json
	sm.set("is_sandbox_act", true)
	sm.call("_apply_defaults")
	sm.set("is_sandbox_act", true)

	# 1. Scrap Bits & ACH-09
	sm.call("add_scrap_bits", 210)
	assert_eq(int(sm.get("scrap_bits")), 210, "Scrap bits added to 210")
	assert_true(bool(sm.call("is_achievement_unlocked", "ACH-09")), "ACH-09 Baron Rongsokan unlocked at >=200 bits")

	# 2. Upgrade Tree Parent Validation & ACH-08
	assert_eq(bool(sm.call("can_purchase_upgrade", "surv_2", 45, ["surv_1"])), false, "Cannot buy surv_2 before surv_1")
	assert_eq(bool(sm.call("purchase_upgrade", "surv_1", 30, [])), true, "Buy root surv_1")
	assert_eq(bool(sm.call("purchase_upgrade", "surv_2", 45, ["surv_1"])), true, "Buy child surv_2 after surv_1")
	assert_eq(bool(sm.call("purchase_upgrade", "emp_1", 30, [])), true, "Buy root emp_1")
	assert_eq(bool(sm.call("purchase_upgrade", "util_1", 25, [])), true, "Buy root util_1 (4th node)")
	assert_true(bool(sm.call("is_achievement_unlocked", "ACH-08")), "ACH-08 Arsitek Firmware unlocked at 4 upgrades")

	# 3. Inventory & Quest Progression Gating
	sm.call("add_item", "coolant_stabilizer", 1)
	assert_eq(int(sm.call("get_item_count", "coolant_stabilizer")), 1, "Inventory add coolant_stabilizer")
	assert_eq(bool(sm.call("consume_item", "coolant_stabilizer", 1)), true, "Inventory consume coolant_stabilizer")

	sm.call("complete_quest", "MQ-01", 40)
	assert_true(bool(sm.call("is_quest_active", "SQ-01")), "SQ-01 unlocked after MQ-01")
	assert_true(bool(sm.call("is_quest_active", "SQ-02")), "SQ-02 unlocked after MQ-01")
	sm.call("complete_quest", "SQ-01", 50)
	sm.call("complete_quest", "SQ-02", 50)
	assert_true(bool(sm.call("is_quest_active", "MQ-02")), "MQ-02 unlocked after SQ-01 & SQ-02")
	sm.call("complete_quest", "SQ-03", 80)
	assert_true(bool(sm.call("is_achievement_unlocked", "ACH-02")), "ACH-02 Warga Teladan unlocked after all side quests")
	sm.call("complete_quest", "MQ-02", 70)
	assert_true(bool(sm.call("is_quest_active", "MQ-03")), "MQ-03 unlocked after MQ-02")
	sm.call("complete_quest", "MQ-03", 120)
	assert_true(bool(sm.call("is_achievement_unlocked", "ACH-03")), "ACH-03 Penyelamat Ngarai unlocked after MQ-03")

	# 4. Bug Log W2 ACH-05
	for bid in ["BUG-11", "BUG-12", "BUG-13", "BUG-14", "BUG-15", "BUG-16"]:
		sm.call("unlock_bug_log", bid)
	assert_true(bool(sm.call("is_achievement_unlocked", "ACH-05")), "ACH-05 Ensiklopedia Kondisi unlocked")

	# Restore clean state from disk
	sm.set("is_sandbox_act", false)
	sm.call("load_save")


func _test_world2_scene_and_acts() -> void:
	var sm: Node = root.get_node_or_null("/root/SaveManager")
	var packed: PackedScene = load("res://scenes/levels/world_2_condition_canyon/world_2_city.tscn")
	assert_true(packed != null, "world_2_city.tscn loads as PackedScene")
	if not packed:
		return

	for act_num in [1, 2, 3]:
		if sm:
			sm.call("configure_w2_act_session", act_num, true)
		var inst: Node = packed.instantiate()
		root.add_child(inst)
		await process_frame

		var dex_node := inst.get_node_or_null("DexTopDown") as Node2D
		assert_true(dex_node != null, "Act %d: DexTopDown exists" % act_num)
		if dex_node:
			var expected_pos: Vector2 = World2CityBuilder.ACT_SPAWN_POS[act_num]
			assert_true(dex_node.global_position.distance_to(expected_pos) < 5.0, "Act %d: DexTopDown spawn position matches BeaconPad" % act_num)

		if act_num == 1:
			assert_true(inst.get_node_or_null("NPCs/NPC_elder") != null, "NPC_elder exists")
			assert_true(inst.get_node_or_null("NPCs/NPC_kael") != null, "NPC_kael exists")
			assert_true(inst.get_node_or_null("NPCs/NPC_unit_m4") != null, "NPC_unit_m4 exists")
			assert_true(inst.get_node_or_null("Enemies/ScrapHound_1") != null, "ScrapHound_1 exists")
			assert_true(inst.get_node_or_null("Enemies/PatrolDrone_1") != null, "PatrolDrone_1 exists")
			assert_true(inst.get_node_or_null("Enemies/ShieldSentinel_1") != null, "ShieldSentinel_1 exists")
			assert_true(inst.get_node_or_null("Workbench") != null, "Workbench station exists")
			assert_true(inst.get_node_or_null("BossGatekeeperAI") != null, "BossGatekeeperAI exists")
			for tid in ["Terminal_1", "Terminal_2", "Terminal_3", "Terminal_4A", "Terminal_4B"]:
				assert_true(inst.get_node_or_null("Terminals/" + tid) != null, "%s exists" % tid)
			for ov in ["TerminalOverlay", "WorkbenchOverlay", "UpgradeTreeOverlay", "QuestJournalOverlay", "StoryCutsceneOverlay"]:
				assert_true(inst.get_node_or_null(ov) != null, "%s exists" % ov)

		root.remove_child(inst)
		inst.free()
		await process_frame

	if sm:
		sm.set("is_sandbox_act", false)
		sm.call("load_save")
