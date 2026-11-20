extends SceneTree

## Headless Verification Suite untuk Audio System V2.1 (Issue #18, #19, #20, #21, #22).
## Jalankan: godot --headless --path . --script res://scripts/tests/test_audio_system.gd

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	await _run_all_tests()
	print("==========================================")
	print("TEST AUDIO SYSTEM RESULTS: %d passed, %d failed" % [passed, failed])
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
	var am: Node = root.get_node_or_null("/root/AudioManager")
	assert_true(am != null, "AudioManager autoload registered")
	if not am:
		return

	_test_bus_topology(am)
	_test_volume_curve(am)
	_test_manifest_and_asset_paths(am)
	await _test_bgm_ambience_ducking_and_sfx(am)


func _test_bus_topology(am: Node) -> void:
	am.call("ensure_audio_buses")
	for bus_name in ["Master", "BGMDuck", "BGM", "Ambience", "SFX", "UI"]:
		assert_true(AudioServer.get_bus_index(bus_name) >= 0, "Bus exists: %s" % bus_name)

	assert_eq(str(AudioServer.get_bus_send(AudioServer.get_bus_index("BGM"))), "BGMDuck", "BGM sends to BGMDuck")
	assert_eq(str(AudioServer.get_bus_send(AudioServer.get_bus_index("BGMDuck"))), "Master", "BGMDuck sends to Master")
	assert_eq(str(AudioServer.get_bus_send(AudioServer.get_bus_index("UI"))), "SFX", "UI sends to SFX")


func _test_volume_curve(am: Node) -> void:
	assert_eq(float(am.call("pct_to_db", 0.0)), -80.0, "0% yields -80.0 dB")
	var db_50: float = float(am.call("pct_to_db", 50.0))
	var expected_50: float = linear_to_db(0.25)
	assert_true(absf(db_50 - expected_50) < 0.01, "50% follows quadratic curve (gain^2)")

	am.call("apply_volume_settings", 80.0, 0.0, 75.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("BGM")), "BGM muted when 0%")
	assert_true(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "SFX unmuted when 75%")
	am.call("load_user_settings")


func _test_manifest_and_asset_paths(am: Node) -> void:
	var paths: Array = am.call("get_all_registered_paths")
	assert_eq(paths.size(), 59, "AudioManager registers all 59 audio files")
	for p in paths:
		var path_str: String = str(p)
		assert_true(FileAccess.file_exists(path_str) or ResourceLoader.exists(path_str), "Audio file exists: %s" % path_str)

	var mf := FileAccess.open("res://assets/asset-manifest.json", FileAccess.READ)
	assert_true(mf != null, "asset-manifest.json readable")
	if mf:
		var parsed: Variant = JSON.parse_string(mf.get_as_text())
		mf.close()
		assert_true(parsed is Dictionary, "asset-manifest.json valid JSON object")
		if parsed is Dictionary:
			var assets: Array = (parsed as Dictionary).get("assets", [])
			var audio_count := 0
			for item in assets:
				if item is Dictionary and str(item.get("category", "")).begins_with("audio"):
					audio_count += 1
					assert_true(bool(item.get("technical_checks_passed", false)), "Manifest QA pass: %s" % str(item.get("path", "")))
			assert_eq(audio_count, 59, "asset-manifest.json tracks all 59 audio assets")


func _test_bgm_ambience_ducking_and_sfx(am: Node) -> void:
	am.call("play_bgm", "main_menu", 0.05)
	assert_eq(str(am.call("get_current_bgm_id")), "main_menu", "BGM switched to main_menu")
	am.call("play_bgm", "world2", 0.05)
	assert_eq(str(am.call("get_current_bgm_id")), "world2", "BGM switched to world2")
	am.call("play_ambience", "canyon_wind", 0.05)
	assert_eq(str(am.call("get_current_ambience_id")), "canyon_wind", "Ambience switched to canyon_wind")

	am.call("set_ducking", true, "terminal")
	assert_true(bool(am.call("is_ducking")), "Ducking active for terminal")
	await create_timer(0.30).timeout
	var duck_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGMDuck"))
	assert_true(duck_db <= -9.0, "BGMDuck attenuated near -10 dB")

	am.call("set_ducking", false, "terminal")
	assert_true(not bool(am.call("is_ducking")), "Ducking cleared after terminal closes")
	await create_timer(0.30).timeout

	am.call("play_ui", "code_type")
	am.call("play_ui", "code_solved")
	am.call("play_sfx", "dex_step")
	am.call("play_sfx", "emp_pulse")
	am.call("play_sfx", "boss_restored")
	am.call("set_loop_user_active", "laser_hum", 999, "laser_hum", true, -14.0)
	am.call("set_loop_user_active", "laser_hum", 999, "laser_hum", false, -14.0)
	am.call("stop_bgm", 0.0)
	am.call("stop_ambience", 0.0)
	am.call("stop_all_loops")
	assert_true(true, "Playback & loop API ran without crash")
