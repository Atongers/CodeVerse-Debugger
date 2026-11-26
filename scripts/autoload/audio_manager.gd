extends Node

## Central AudioManager autoload: bus mixing graph, quadratic dB curves, crossfade BGM/Ambience, auto-ducking, and throttled SFX/UI playback.

const SETTINGS_PATH := "user://settings.cfg"
const DUCK_BUS_NAME := &"BGMDuck"
const BGM_BUS_NAME := &"BGM"
const AMBIENCE_BUS_NAME := &"Ambience"
const SFX_BUS_NAME := &"SFX"
const UI_BUS_NAME := &"UI"

const DUCK_ATTENUATION_DB := -10.0
const DUCK_TWEEN_SEC := 0.25
const SFX_POOL_SIZE := 12

const BGM_TRACKS: Dictionary = {
	"main_menu": "res://assets/audio/bgm/bgm_main_menu.ogg",
	"world1": "res://assets/audio/bgm/bgm_world1_syntax_shore.ogg",
	"cutscene": "res://assets/audio/bgm/bgm_story_cutscene.ogg",
	"world2": "res://assets/audio/bgm/bgm_world2_condition_canyon.ogg",
	"boss": "res://assets/audio/bgm/bgm_boss_gatekeeper.ogg",
}

const AMBIENCE_TRACKS: Dictionary = {
	"lab_hum": "res://assets/audio/bgm/amb_lab_hum.ogg",
	"canyon_wind": "res://assets/audio/bgm/amb_canyon_wind.ogg",
}

const UI_SOUNDS: Dictionary = {
	"ui_hover": "res://assets/audio/sfx/sfx_ui_hover.wav",
	"ui_click": "res://assets/audio/sfx/sfx_ui_click.wav",
	"ui_modal_open": "res://assets/audio/sfx/sfx_ui_modal_open.wav",
	"ui_modal_close": "res://assets/audio/sfx/sfx_ui_modal_close.wav",
	"terminal_open": "res://assets/audio/sfx/sfx_terminal_open.wav",
	"code_type_1": "res://assets/audio/sfx/sfx_code_type_1.wav",
	"code_type_2": "res://assets/audio/sfx/sfx_code_type_2.wav",
	"code_type_3": "res://assets/audio/sfx/sfx_code_type_3.wav",
	"code_run": "res://assets/audio/sfx/sfx_code_run.wav",
	"code_step": "res://assets/audio/sfx/sfx_code_step.wav",
	"code_error": "res://assets/audio/sfx/sfx_code_error.wav",
	"code_solved": "res://assets/audio/sfx/sfx_code_solved.wav",
	"lint_hint": "res://assets/audio/sfx/sfx_lint_hint.wav",
	"npc_blip_elder": "res://assets/audio/sfx/sfx_npc_blip_elder.wav",
	"npc_blip_kael": "res://assets/audio/sfx/sfx_npc_blip_kael.wav",
	"npc_blip_medic": "res://assets/audio/sfx/sfx_npc_blip_medic.wav",
	"unlock_item": "res://assets/audio/sfx/sfx_unlock_item.wav",
	"achievement_toast": "res://assets/audio/sfx/sfx_achievement_toast.wav",
	"upgrade_buy": "res://assets/audio/sfx/sfx_upgrade_buy.wav",
	"quest_complete": "res://assets/audio/sfx/sfx_quest_complete.wav",
	"level_victory": "res://assets/audio/sfx/sfx_level_victory.wav",
}

const SFX_SOUNDS: Dictionary = {
	"dex_step_1": "res://assets/audio/sfx/sfx_dex_step_1.wav",
	"dex_step_2": "res://assets/audio/sfx/sfx_dex_step_2.wav",
	"dex_step_3": "res://assets/audio/sfx/sfx_dex_step_3.wav",
	"dex_jump": "res://assets/audio/sfx/sfx_dex_jump.wav",
	"dex_land": "res://assets/audio/sfx/sfx_dex_land.wav",
	"dex_sprint_whoosh": "res://assets/audio/sfx/sfx_dex_sprint_whoosh.wav",
	"dex_hit": "res://assets/audio/sfx/sfx_dex_hit.wav",
	"dex_collapse": "res://assets/audio/sfx/sfx_dex_collapse.wav",
	"checkpoint_activate": "res://assets/audio/sfx/sfx_checkpoint_activate.wav",
	"laser_hum": "res://assets/audio/sfx/sfx_laser_hum.wav",
	"laser_off": "res://assets/audio/sfx/sfx_laser_off.wav",
	"elevator_move": "res://assets/audio/sfx/sfx_elevator_move.wav",
	"crane_move": "res://assets/audio/sfx/sfx_crane_move.wav",
	"turret_scan_alert": "res://assets/audio/sfx/sfx_turret_scan_alert.wav",
	"plasma_shoot": "res://assets/audio/sfx/sfx_plasma_shoot.wav",
	"exit_gate_open": "res://assets/audio/sfx/sfx_exit_gate_open.wav",
	"emp_pulse": "res://assets/audio/sfx/sfx_emp_pulse.wav",
	"emp_tier2_break": "res://assets/audio/sfx/sfx_emp_tier2_break.wav",
	"hound_telegraph": "res://assets/audio/sfx/sfx_hound_telegraph.wav",
	"drone_shoot": "res://assets/audio/sfx/sfx_drone_shoot.wav",
	"shield_clang": "res://assets/audio/sfx/sfx_shield_clang.wav",
	"enemy_stun": "res://assets/audio/sfx/sfx_enemy_stun.wav",
	"enemy_defeat": "res://assets/audio/sfx/sfx_enemy_defeat.wav",
	"loot_pickup_coin": "res://assets/audio/sfx/sfx_loot_pickup_coin.wav",
	"loot_pickup_item": "res://assets/audio/sfx/sfx_loot_pickup_item.wav",
	"quick_heal": "res://assets/audio/sfx/sfx_quick_heal.wav",
	"quick_battery": "res://assets/audio/sfx/sfx_quick_battery.wav",
	"workbench_weld": "res://assets/audio/sfx/sfx_workbench_weld.wav",
	"boss_laser_shot": "res://assets/audio/sfx/sfx_boss_laser_shot.wav",
	"boss_overheat": "res://assets/audio/sfx/sfx_boss_overheat.wav",
	"boss_restored": "res://assets/audio/sfx/sfx_boss_restored.wav",
}

const SFX_THROTTLE_MS: Dictionary = {
	"ui_hover": 45,
	"code_type": 35,
	"code_step": 35,
	"dex_step": 220,
	"turret_scan_alert": 450,
	"plasma_shoot": 90,
	"drone_shoot": 90,
	"shield_clang": 120,
	"enemy_stun": 90,
	"loot_pickup_coin": 70,
	"loot_pickup_item": 70,
}

var _user_settings: Dictionary = {
	"master_vol": 80,
	"bgm_vol": 75,
	"sfx_vol": 85,
	"fullscreen": false,
}

var _bgm_a: AudioStreamPlayer = null
var _bgm_b: AudioStreamPlayer = null
var _bgm_active_is_a: bool = true
var _current_bgm_id: String = ""
var _bgm_tween: Tween = null

var _amb_a: AudioStreamPlayer = null
var _amb_b: AudioStreamPlayer = null
var _amb_active_is_a: bool = true
var _current_amb_id: String = ""
var _amb_tween: Tween = null

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_cursor: int = 0
var _loop_players: Dictionary = {}
var _loop_users: Dictionary = {}

var _stream_cache: Dictionary = {}
var _randomizer_cache: Dictionary = {}
var _last_play_msec: Dictionary = {}
var _duck_sources: Dictionary = {}
var _duck_tween: Tween = null
var _is_ducked: bool = false
var _web_audio_unlocked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_audio_buses()
	_create_players()
	_build_randomizers()
	load_user_settings()
	_connect_save_manager()


func _input(event: InputEvent) -> void:
	if _web_audio_unlocked or not OS.has_feature("web"):
		return
	if (event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		_web_audio_unlocked = true
		_ensure_web_streams_active()


## Wakes up BGM/ambience streams if browser autoplay policy paused initial playback before first user gesture.
func _ensure_web_streams_active() -> void:
	if not _current_bgm_id.is_empty():
		var bgm_p := _bgm_a if _bgm_active_is_a else _bgm_b
		if is_instance_valid(bgm_p) and bgm_p.stream != null and (not bgm_p.playing or bgm_p.get_playback_position() <= 0.05):
			bgm_p.volume_db = 0.0
			bgm_p.play()
	if not _current_amb_id.is_empty():
		var amb_p := _amb_a if _amb_active_is_a else _amb_b
		if is_instance_valid(amb_p) and amb_p.stream != null and (not amb_p.playing or amb_p.get_playback_position() <= 0.05):
			amb_p.volume_db = 0.0
			amb_p.play()


## Ensures Master -> BGMDuck -> BGM, Ambience, and SFX <- UI bus topology exists.
func ensure_audio_buses() -> void:
	var required: Array[StringName] = [DUCK_BUS_NAME, BGM_BUS_NAME, AMBIENCE_BUS_NAME, SFX_BUS_NAME, UI_BUS_NAME]
	for bus_name in required:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.get_bus_count()
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)

	AudioServer.set_bus_send(AudioServer.get_bus_index(DUCK_BUS_NAME), &"Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index(BGM_BUS_NAME), DUCK_BUS_NAME)
	AudioServer.set_bus_send(AudioServer.get_bus_index(AMBIENCE_BUS_NAME), &"Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index(SFX_BUS_NAME), &"Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index(UI_BUS_NAME), SFX_BUS_NAME)


func _create_players() -> void:
	_bgm_a = AudioStreamPlayer.new()
	_bgm_a.name = "BgmPlayerA"
	_bgm_a.bus = BGM_BUS_NAME
	add_child(_bgm_a)

	_bgm_b = AudioStreamPlayer.new()
	_bgm_b.name = "BgmPlayerB"
	_bgm_b.bus = BGM_BUS_NAME
	add_child(_bgm_b)

	_amb_a = AudioStreamPlayer.new()
	_amb_a.name = "AmbiencePlayerA"
	_amb_a.bus = AMBIENCE_BUS_NAME
	add_child(_amb_a)

	_amb_b = AudioStreamPlayer.new()
	_amb_b.name = "AmbiencePlayerB"
	_amb_b.bus = AMBIENCE_BUS_NAME
	add_child(_amb_b)

	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SfxPool_%d" % i
		p.bus = SFX_BUS_NAME
		p.max_polyphony = 4
		add_child(p)
		_sfx_pool.append(p)


func _build_randomizers() -> void:
	_randomizer_cache["code_type"] = _make_randomizer(["code_type_1", "code_type_2", "code_type_3"], UI_SOUNDS, 1.06, 2.0)
	_randomizer_cache["dex_step"] = _make_randomizer(["dex_step_1", "dex_step_2", "dex_step_3"], SFX_SOUNDS, 1.06, 2.0)
	_randomizer_cache["emp_pulse"] = _make_randomizer(["emp_pulse"], SFX_SOUNDS, 1.06, 2.0)


func _make_randomizer(keys: Array[String], path_map: Dictionary, pitch_range: float, vol_db_range: float) -> AudioStreamRandomizer:
	var rand_stream := AudioStreamRandomizer.new()
	rand_stream.random_pitch = pitch_range
	rand_stream.random_volume_offset_db = vol_db_range
	for k in keys:
		var path: String = str(path_map.get(k, ""))
		if path.is_empty():
			continue
		var st := _load_audio_stream(path, false)
		if st:
			rand_stream.add_stream(-1, st, 1.0)
	return rand_stream if rand_stream.streams_count > 0 else null


func _connect_save_manager() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return
	if sm.has_signal("item_unlocked") and not sm.is_connected("item_unlocked", _on_save_item_unlocked):
		sm.connect("item_unlocked", _on_save_item_unlocked)
	if sm.has_signal("achievement_unlocked") and not sm.is_connected("achievement_unlocked", _on_save_achievement_unlocked):
		sm.connect("achievement_unlocked", _on_save_achievement_unlocked)
	if sm.has_signal("quest_updated") and not sm.is_connected("quest_updated", _on_save_quest_updated):
		sm.connect("quest_updated", _on_save_quest_updated)


func _on_save_item_unlocked(_info: Dictionary) -> void:
	play_ui("unlock_item")


func _on_save_achievement_unlocked(_ach_id: String, _info: Dictionary) -> void:
	play_ui("achievement_toast")


func _on_save_quest_updated(quest_id: String) -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("is_quest_completed") and bool(sm.call("is_quest_completed", quest_id)):
		play_ui("quest_complete")


## Quadratic slider curve so 0..100% feels linear perceptually; 0% mutes cleanly.
func pct_to_db(pct: float) -> float:
	if pct <= 0.0:
		return -80.0
	var gain := clampf(pct / 100.0, 0.0, 1.0)
	return linear_to_db(gain * gain)


func apply_volume_settings(master_pct: float, bgm_pct: float, sfx_pct: float) -> void:
	ensure_audio_buses()
	_user_settings["master_vol"] = int(round(clampf(master_pct, 0.0, 100.0)))
	_user_settings["bgm_vol"] = int(round(clampf(bgm_pct, 0.0, 100.0)))
	_user_settings["sfx_vol"] = int(round(clampf(sfx_pct, 0.0, 100.0)))
	_apply_bus_pct(&"Master", master_pct)
	_apply_bus_pct(BGM_BUS_NAME, bgm_pct)
	# Keep environmental ambience slightly tucked behind active soundtrack mix.
	_apply_bus_pct(AMBIENCE_BUS_NAME, bgm_pct * 0.72)
	_apply_bus_pct(SFX_BUS_NAME, sfx_pct)


func _apply_bus_pct(bus_name: StringName, pct: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var muted := pct <= 0.0
	AudioServer.set_bus_mute(idx, muted)
	AudioServer.set_bus_volume_db(idx, pct_to_db(pct))


func apply_bus_volume(bus_name: String, pct: float) -> void:
	ensure_audio_buses()
	if bus_name == "Master":
		_user_settings["master_vol"] = int(round(pct))
		_apply_bus_pct(&"Master", pct)
	elif bus_name == "BGM":
		_user_settings["bgm_vol"] = int(round(pct))
		_apply_bus_pct(BGM_BUS_NAME, pct)
		_apply_bus_pct(AMBIENCE_BUS_NAME, pct * 0.72)
	elif bus_name == "SFX":
		_user_settings["sfx_vol"] = int(round(pct))
		_apply_bus_pct(SFX_BUS_NAME, pct)
	else:
		_apply_bus_pct(StringName(bus_name), pct)


func load_user_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_user_settings["master_vol"] = int(cfg.get_value("audio", "master_vol", 80))
		_user_settings["bgm_vol"] = int(cfg.get_value("audio", "bgm_vol", 75))
		_user_settings["sfx_vol"] = int(cfg.get_value("audio", "sfx_vol", 85))
		_user_settings["fullscreen"] = bool(cfg.get_value("display", "fullscreen", false))

	apply_volume_settings(
		float(_user_settings["master_vol"]),
		float(_user_settings["bgm_vol"]),
		float(_user_settings["sfx_vol"])
	)
	return _user_settings.duplicate(true)


func save_user_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_vol", int(_user_settings.get("master_vol", 80)))
	cfg.set_value("audio", "bgm_vol", int(_user_settings.get("bgm_vol", 75)))
	cfg.set_value("audio", "sfx_vol", int(_user_settings.get("sfx_vol", 85)))
	cfg.set_value("display", "fullscreen", bool(_user_settings.get("fullscreen", false)))
	cfg.save(SETTINGS_PATH)


func get_user_settings() -> Dictionary:
	return _user_settings.duplicate(true)


func set_setting(key: String, value: Variant, save_now: bool = true) -> void:
	_user_settings[key] = value
	if key == "master_vol" or key == "bgm_vol" or key == "sfx_vol":
		apply_volume_settings(
			float(_user_settings.get("master_vol", 80)),
			float(_user_settings.get("bgm_vol", 75)),
			float(_user_settings.get("sfx_vol", 85))
		)
	if save_now:
		save_user_settings()


func play_bgm(track_id: String, crossfade_sec: float = 0.8) -> void:
	if track_id.is_empty():
		stop_bgm(crossfade_sec)
		return
	var active := _bgm_a if _bgm_active_is_a else _bgm_b
	if track_id == _current_bgm_id and is_instance_valid(active) and active.playing:
		return

	var path: String = str(BGM_TRACKS.get(track_id, ""))
	if path.is_empty():
		push_warning("AudioManager: unknown BGM track '%s'" % track_id)
		return
	var stream := _load_audio_stream(path, true)
	if not stream:
		push_warning("AudioManager: missing BGM asset '%s'" % path)
		return

	var next_p := _bgm_b if _bgm_active_is_a else _bgm_a
	var prev_p := active
	_bgm_active_is_a = not _bgm_active_is_a
	_current_bgm_id = track_id

	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()

	next_p.stream = stream
	next_p.volume_db = -40.0 if crossfade_sec > 0.0 else 0.0
	next_p.play()

	if crossfade_sec <= 0.0:
		if is_instance_valid(prev_p):
			prev_p.stop()
		return

	_bgm_tween = create_tween().set_parallel(true)
	_bgm_tween.tween_property(next_p, "volume_db", 0.0, crossfade_sec)
	if is_instance_valid(prev_p) and prev_p.playing:
		_bgm_tween.tween_property(prev_p, "volume_db", -40.0, crossfade_sec)
		_bgm_tween.chain().tween_callback(func() -> void:
			if is_instance_valid(prev_p) and prev_p != (_bgm_a if _bgm_active_is_a else _bgm_b):
				prev_p.stop()
		)


func stop_bgm(fade_sec: float = 0.6) -> void:
	_current_bgm_id = ""
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()
	if fade_sec <= 0.0:
		if is_instance_valid(_bgm_a):
			_bgm_a.stop()
		if is_instance_valid(_bgm_b):
			_bgm_b.stop()
		return
	_bgm_tween = create_tween().set_parallel(true)
	for p in [_bgm_a, _bgm_b]:
		if is_instance_valid(p) and p.playing:
			_bgm_tween.tween_property(p, "volume_db", -40.0, fade_sec)
	_bgm_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(_bgm_a):
			_bgm_a.stop()
		if is_instance_valid(_bgm_b):
			_bgm_b.stop()
	)


func get_current_bgm_id() -> String:
	return _current_bgm_id


func play_ambience(ambience_id: String, fade_sec: float = 0.6) -> void:
	if ambience_id.is_empty():
		stop_ambience(fade_sec)
		return
	var active := _amb_a if _amb_active_is_a else _amb_b
	if ambience_id == _current_amb_id and is_instance_valid(active) and active.playing:
		return

	var path: String = str(AMBIENCE_TRACKS.get(ambience_id, ""))
	if path.is_empty():
		push_warning("AudioManager: unknown ambience track '%s'" % ambience_id)
		return
	var stream := _load_audio_stream(path, true)
	if not stream:
		push_warning("AudioManager: missing ambience asset '%s'" % path)
		return

	var next_p := _amb_b if _amb_active_is_a else _amb_a
	var prev_p := active
	_amb_active_is_a = not _amb_active_is_a
	_current_amb_id = ambience_id

	if _amb_tween and _amb_tween.is_valid():
		_amb_tween.kill()

	next_p.stream = stream
	next_p.volume_db = -40.0 if fade_sec > 0.0 else 0.0
	next_p.play()

	if fade_sec <= 0.0:
		if is_instance_valid(prev_p):
			prev_p.stop()
		return

	_amb_tween = create_tween().set_parallel(true)
	_amb_tween.tween_property(next_p, "volume_db", 0.0, fade_sec)
	if is_instance_valid(prev_p) and prev_p.playing:
		_amb_tween.tween_property(prev_p, "volume_db", -40.0, fade_sec)
		_amb_tween.chain().tween_callback(func() -> void:
			if is_instance_valid(prev_p) and prev_p != (_amb_a if _amb_active_is_a else _amb_b):
				prev_p.stop()
		)


func stop_ambience(fade_sec: float = 0.5) -> void:
	_current_amb_id = ""
	if _amb_tween and _amb_tween.is_valid():
		_amb_tween.kill()
	if fade_sec <= 0.0:
		if is_instance_valid(_amb_a):
			_amb_a.stop()
		if is_instance_valid(_amb_b):
			_amb_b.stop()
		return
	_amb_tween = create_tween().set_parallel(true)
	for p in [_amb_a, _amb_b]:
		if is_instance_valid(p) and p.playing:
			_amb_tween.tween_property(p, "volume_db", -40.0, fade_sec)
	_amb_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(_amb_a):
			_amb_a.stop()
		if is_instance_valid(_amb_b):
			_amb_b.stop()
	)


func get_current_ambience_id() -> String:
	return _current_amb_id


## Ducks BGMDuck bus smoothly (-10 dB) without altering user's BGM volume slider.
func set_ducking(active: bool, source_id: String = "default") -> void:
	if active:
		_duck_sources[source_id] = true
	else:
		if source_id == "all":
			_duck_sources.clear()
		else:
			_duck_sources.erase(source_id)

	var should_duck := not _duck_sources.is_empty()
	if should_duck == _is_ducked:
		return
	_is_ducked = should_duck

	var bus_idx := AudioServer.get_bus_index(DUCK_BUS_NAME)
	if bus_idx < 0:
		return
	var target_db := DUCK_ATTENUATION_DB if should_duck else 0.0
	var start_db := AudioServer.get_bus_volume_db(bus_idx)

	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(
		func(db: float) -> void:
			var idx := AudioServer.get_bus_index(DUCK_BUS_NAME)
			if idx >= 0:
				AudioServer.set_bus_volume_db(idx, db),
		start_db,
		target_db,
		DUCK_TWEEN_SEC
	)


func is_ducking() -> bool:
	return _is_ducked


func play_ui(ui_id: String, pitch_jitter: float = 0.0, volume_db: float = 0.0) -> void:
	_play_sound(ui_id, UI_BUS_NAME, UI_SOUNDS, pitch_jitter, volume_db)


func play_sfx(sfx_id: String, pitch_jitter: float = 0.0, volume_db: float = 0.0) -> void:
	_play_sound(sfx_id, SFX_BUS_NAME, SFX_SOUNDS, pitch_jitter, volume_db)


func _play_sound(sound_id: String, bus_name: StringName, primary_map: Dictionary, pitch_jitter: float, volume_db: float) -> void:
	if sound_id.is_empty() or _sfx_pool.is_empty():
		return

	var min_gap_ms: int = int(SFX_THROTTLE_MS.get(sound_id, 0))
	var now_ms: int = Time.get_ticks_msec()
	if min_gap_ms > 0:
		var last_ms: int = int(_last_play_msec.get(sound_id, -9999))
		if now_ms - last_ms < min_gap_ms:
			return
	_last_play_msec[sound_id] = now_ms

	var stream: AudioStream = null
	if _randomizer_cache.has(sound_id) and _randomizer_cache[sound_id] != null:
		stream = _randomizer_cache[sound_id]
	else:
		var path: String = str(primary_map.get(sound_id, ""))
		if path.is_empty():
			path = str(SFX_SOUNDS.get(sound_id, UI_SOUNDS.get(sound_id, "")))
		if path.is_empty():
			return
		stream = _load_audio_stream(path, false)

	if not stream:
		return

	var player := _acquire_pool_player()
	player.bus = bus_name
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter) if pitch_jitter > 0.0 else 1.0
	player.play()


func _acquire_pool_player() -> AudioStreamPlayer:
	for i in range(_sfx_pool.size()):
		var idx := (_sfx_pool_cursor + i) % _sfx_pool.size()
		var candidate := _sfx_pool[idx]
		if not candidate.playing:
			_sfx_pool_cursor = (idx + 1) % _sfx_pool.size()
			return candidate
	var recycled := _sfx_pool[_sfx_pool_cursor]
	_sfx_pool_cursor = (_sfx_pool_cursor + 1) % _sfx_pool.size()
	recycled.stop()
	return recycled


## Ref-counted machine loop controller so multiple lasers/elevators/cranes never stack audio.
func set_loop_user_active(loop_key: String, user_id: int, sfx_id: String, active: bool, volume_db: float = -12.0) -> void:
	if not _loop_users.has(loop_key):
		_loop_users[loop_key] = {}
	var users: Dictionary = _loop_users[loop_key]
	if active:
		users[user_id] = true
	else:
		users.erase(user_id)

	var should_play := not users.is_empty()
	var lp: AudioStreamPlayer = _loop_players.get(loop_key, null)
	if should_play:
		if not is_instance_valid(lp):
			lp = AudioStreamPlayer.new()
			lp.name = "Loop_" + loop_key
			lp.bus = SFX_BUS_NAME
			add_child(lp)
			_loop_players[loop_key] = lp
		var path: String = str(SFX_SOUNDS.get(sfx_id, ""))
		if path.is_empty():
			return
		var st := _load_audio_stream(path, true)
		if not st:
			return
		lp.volume_db = volume_db
		if lp.stream != st or not lp.playing:
			lp.stream = st
			lp.play()
	else:
		if is_instance_valid(lp) and lp.playing:
			lp.stop()


func stop_all_loops() -> void:
	_loop_users.clear()
	for k in _loop_players.keys():
		var lp: AudioStreamPlayer = _loop_players[k]
		if is_instance_valid(lp) and lp.playing:
			lp.stop()


func get_all_registered_paths() -> Array[String]:
	var all_paths: Array[String] = []
	for dict in [BGM_TRACKS, AMBIENCE_TRACKS, UI_SOUNDS, SFX_SOUNDS]:
		for k in dict.keys():
			var p: String = str(dict[k])
			if not all_paths.has(p):
				all_paths.append(p)
	return all_paths


func _load_audio_stream(path: String, force_loop: bool) -> AudioStream:
	if _stream_cache.has(path):
		var cached: AudioStream = _stream_cache[path]
		if force_loop:
			_apply_loop_flag(cached)
		return cached

	var st: AudioStream = null
	if ResourceLoader.exists(path):
		st = ResourceLoader.load(path) as AudioStream
	if not st and FileAccess.file_exists(path):
		if path.ends_with(".ogg"):
			st = AudioStreamOggVorbis.load_from_file(path)
		elif path.ends_with(".wav"):
			st = AudioStreamWAV.load_from_file(path)

	if st:
		if force_loop:
			_apply_loop_flag(st)
		_stream_cache[path] = st
	return st


func _apply_loop_flag(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED and wav.data.size() > 0:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			var bytes_per_sample := 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var ch := 2 if wav.stereo else 1
			wav.loop_begin = 0
			wav.loop_end = int(float(wav.data.size()) / float(maxi(1, bytes_per_sample * ch)))
