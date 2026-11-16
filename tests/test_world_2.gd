@tool
extends McpTestSuite


func suite_name() -> String:
	return "world_2"


func test_interpreter_world1_regression() -> void:
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


func test_interpreter_world2_conditionals_and_bugs() -> void:
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

	var code_bug11 := "\n".join([
		"angin = 65",
		"if angin > 50",
		"    mode = \"TERLINDUNGI\"",
	])
	var res_b11: Dictionary = PythonInterpreter.run_script(code_bug11)
	assert_eq(bool(res_b11.get("ok", true)), false, "BUG-11 missing ':' detected")
	assert_eq(str(res_b11.get("error_type", "")), "SyntaxError", "BUG-11 error_type SyntaxError")
	assert_contains(str(res_b11.get("error", "")), "titik dua ':'", "BUG-11 message mentions ':'")

	var code_bug12 := "\n".join([
		"aman = True",
		"if aman == True:",
		"aksi = \"AMAN_MASUK\"",
	])
	var res_b12: Dictionary = PythonInterpreter.run_script(code_bug12)
	assert_eq(bool(res_b12.get("ok", true)), false, "BUG-12 missing indent detected")
	assert_eq(str(res_b12.get("error_type", "")), "IndentationError", "BUG-12 error_type IndentationError")

	var code_bug13 := "\n".join([
		"badai = True",
		"if badai = True:",
		"    mode = \"TERLINDUNGI\"",
	])
	var res_b13: Dictionary = PythonInterpreter.run_script(code_bug13)
	assert_eq(bool(res_b13.get("ok", true)), false, "BUG-13 single '=' in condition detected")
	assert_eq(str(res_b13.get("error_type", "")), "SyntaxError", "BUG-13 error_type SyntaxError")
	assert_contains(str(res_b13.get("error", "")), "'=='", "BUG-13 message mentions '=='")


func test_save_manager_and_rpg_state() -> void:
	var sm_script: GDScript = load("res://scripts/autoload/save_manager.gd")
	assert_true(sm_script != null, "save_manager.gd loads")
	if not sm_script:
		return
	var sm: Node = track(sm_script.new()) as Node
	sm.set("is_sandbox_act", true)
	sm.call("_apply_defaults")
	sm.set("is_sandbox_act", true)

	sm.call("add_scrap_bits", 210)
	assert_eq(int(sm.get("scrap_bits")), 210, "Scrap bits added to 210")
	assert_true(bool(sm.call("is_achievement_unlocked", "ACH-09")), "ACH-09 Baron Rongsokan unlocked")

	assert_eq(bool(sm.call("can_purchase_upgrade", "surv_2", 45, ["surv_1"])), false, "Cannot buy surv_2 before surv_1")
	assert_eq(bool(sm.call("purchase_upgrade", "surv_1", 30, [])), true, "Buy root surv_1")
	assert_eq(bool(sm.call("purchase_upgrade", "surv_2", 45, ["surv_1"])), true, "Buy child surv_2 after surv_1")
	assert_eq(bool(sm.call("purchase_upgrade", "emp_1", 30, [])), true, "Buy root emp_1")
	assert_eq(bool(sm.call("purchase_upgrade", "util_1", 25, [])), true, "Buy root util_1 (4th node)")
	assert_true(bool(sm.call("is_achievement_unlocked", "ACH-08")), "ACH-08 Arsitek Firmware unlocked")

	sm.call("complete_quest", "MQ-01", 40)
	assert_true(bool(sm.call("is_quest_active", "SQ-01")), "SQ-01 unlocked after MQ-01")
	sm.call("complete_quest", "SQ-01", 50)
	sm.call("complete_quest", "SQ-02", 50)
	assert_true(bool(sm.call("is_quest_active", "MQ-02")), "MQ-02 unlocked after SQ-01 & SQ-02")
	sm.call("complete_quest", "SQ-03", 80)
	assert_true(bool(sm.call("is_achievement_unlocked", "ACH-02")), "ACH-02 Warga Teladan unlocked")
	sm.call("complete_quest", "MQ-02", 70)
	sm.call("complete_quest", "MQ-03", 120)
	assert_true(bool(sm.call("is_achievement_unlocked", "ACH-03")), "ACH-03 Penyelamat Ngarai unlocked")

	for bid in ["BUG-11", "BUG-12", "BUG-13", "BUG-14", "BUG-15", "BUG-16"]:
		sm.call("unlock_bug_log", bid)
	assert_true(bool(sm.call("is_achievement_unlocked", "ACH-05")), "ACH-05 Ensiklopedia Kondisi unlocked")


func test_world2_scene_and_entities_build() -> void:
	var packed: PackedScene = load("res://scenes/levels/world_2_condition_canyon/world_2_city.tscn")
	assert_true(packed != null, "world_2_city.tscn loads as PackedScene")
	if not packed:
		return
	var inst: Node2D = track(packed.instantiate()) as Node2D
	assert_true(inst != null, "world_2_city instantiates")
	if not inst:
		return
	inst.call("_build_city_environment")
	inst.call("_build_districts_and_entities")
	inst.call("_build_hud_and_overlays")

	assert_true(inst.get_node_or_null("DexTopDown") != null, "DexTopDown exists")
	assert_true(inst.get_node_or_null("NPCs/NPC_elder") != null, "NPC_elder exists")
	assert_true(inst.get_node_or_null("NPCs/NPC_kael") != null, "NPC_kael exists")
	assert_true(inst.get_node_or_null("NPCs/NPC_unit_m4") != null, "NPC_unit_m4 exists")
	assert_true(inst.get_node_or_null("Enemies/ScrapHound_1") != null, "ScrapHound_1 exists")
	assert_true(inst.get_node_or_null("Enemies/PatrolDrone_1") != null, "PatrolDrone_1 exists")
	assert_true(inst.get_node_or_null("Enemies/ShieldSentinel_1") != null, "ShieldSentinel_1 exists")
	assert_true(inst.get_node_or_null("Workbench") != null, "Workbench exists")
	assert_true(inst.get_node_or_null("BossGatekeeperAI") != null, "BossGatekeeperAI exists")
	for tid in ["Terminal_1", "Terminal_2", "Terminal_3", "Terminal_4A", "Terminal_4B"]:
		assert_true(inst.get_node_or_null("Terminals/" + tid) != null, "%s exists" % tid)
	for ov in ["TerminalOverlay", "WorkbenchOverlay", "UpgradeTreeOverlay", "QuestJournalOverlay", "StoryCutsceneOverlay"]:
		assert_true(inst.get_node_or_null(ov) != null, "%s exists" % ov)
