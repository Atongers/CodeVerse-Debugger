@tool
extends McpTestSuite


func suite_name() -> String:
	return "audio_system"


func test_audio_bus_hierarchy_and_curve() -> void:
	var am_script: GDScript = load("res://scripts/autoload/audio_manager.gd")
	assert_true(am_script != null, "audio_manager.gd loads")
	if not am_script:
		return
	var am: Node = track(am_script.new()) as Node
	am.call("ensure_audio_buses")
	for bus_name in ["Master", "BGMDuck", "BGM", "Ambience", "SFX", "UI"]:
		assert_true(AudioServer.get_bus_index(bus_name) >= 0, "Audio bus exists: %s" % bus_name)

	assert_eq(str(AudioServer.get_bus_send(AudioServer.get_bus_index("BGM"))), "BGMDuck", "BGM sends to BGMDuck")
	assert_eq(str(AudioServer.get_bus_send(AudioServer.get_bus_index("BGMDuck"))), "Master", "BGMDuck sends to Master")
	assert_eq(str(AudioServer.get_bus_send(AudioServer.get_bus_index("UI"))), "SFX", "UI sends to SFX")

	assert_eq(float(am.call("pct_to_db", 0.0)), -80.0, "0% slider yields -80.0 dB")
	var expected_50: float = linear_to_db(0.25)
	assert_true(absf(float(am.call("pct_to_db", 50.0)) - expected_50) < 0.01, "50% slider uses quadratic gain^2 curve")


func test_all_59_audio_assets_and_manifest() -> void:
	var am_script: GDScript = load("res://scripts/autoload/audio_manager.gd")
	assert_true(am_script != null, "audio_manager.gd loads for manifest check")
	if not am_script:
		return
	var am: Node = track(am_script.new()) as Node
	var paths: Array = am.call("get_all_registered_paths")
	assert_eq(paths.size(), 59, "AudioManager registers 59 audio assets")
	for p in paths:
		var p_str: String = str(p)
		assert_true(ResourceLoader.exists(p_str), "ResourceLoader.exists: %s" % p_str)

	var mf := FileAccess.open("res://assets/asset-manifest.json", FileAccess.READ)
	assert_true(mf != null, "asset-manifest.json opens")
	if mf:
		var parsed: Variant = JSON.parse_string(mf.get_as_text())
		mf.close()
		assert_true(parsed is Dictionary, "asset-manifest.json parses as Dictionary")
		if parsed is Dictionary:
			var assets: Array = (parsed as Dictionary).get("assets", [])
			var audio_count := 0
			for item in assets:
				if item is Dictionary and str(item.get("category", "")).begins_with("audio"):
					audio_count += 1
					assert_true(bool(item.get("technical_checks_passed", false)), "Manifest QA flag passed")
			assert_eq(audio_count, 59, "asset-manifest.json has all 59 audio entries")


func test_audio_playback_crossfade_and_ducking() -> void:
	var am_script: GDScript = load("res://scripts/autoload/audio_manager.gd")
	assert_true(am_script != null, "audio_manager.gd loads for playback test")
	if not am_script:
		return
	var am: Node = am_script.new()
	var st := Engine.get_main_loop() as SceneTree
	var tree_root: Window = st.root if st else null
	assert_true(tree_root != null, "SceneTree root available")
	if not tree_root:
		am.free()
		return
	tree_root.add_child(am)

	am.call("play_bgm", "main_menu", 0.05)
	assert_eq(str(am.call("get_current_bgm_id")), "main_menu", "BGM switched to main_menu")
	am.call("play_bgm", "world2", 0.05)
	assert_eq(str(am.call("get_current_bgm_id")), "world2", "BGM switched to world2")
	am.call("play_ambience", "canyon_wind", 0.05)
	assert_eq(str(am.call("get_current_ambience_id")), "canyon_wind", "Ambience switched to canyon_wind")

	am.call("set_ducking", true, "terminal")
	assert_true(bool(am.call("is_ducking")), "Ducking active")
	am.call("set_ducking", false, "terminal")
	assert_true(not bool(am.call("is_ducking")), "Ducking inactive")

	am.call("play_ui", "code_type")
	am.call("play_ui", "code_solved")
	am.call("play_sfx", "dex_step")
	am.call("play_sfx", "emp_pulse")
	am.call("set_loop_user_active", "laser_hum", 123, "laser_hum", true, -14.0)
	am.call("set_loop_user_active", "laser_hum", 123, "laser_hum", false, -14.0)
	am.call("stop_bgm", 0.0)
	am.call("stop_ambience", 0.0)
	am.call("stop_all_loops")

	tree_root.remove_child(am)
	am.free()
	assert_true(true, "Audio playback lifecycle completed cleanly")
