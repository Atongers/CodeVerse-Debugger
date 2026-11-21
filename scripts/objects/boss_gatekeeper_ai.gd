@tool
class_name BossGatekeeperAI
extends Node2D

## Pertarungan Multi-Tahap Boss Gatekeeper AI (W2-22 96x96: Row 0 Corrupted -> Row 1 Overheat -> Row 2 Restored Cyan).

signal subnode_unlocked()
signal boss_restored()

var phase: int = 0 # 0 = Corrupted Shielded, 1 = Overheat Vulnerable, 2 = Restored Friendly
var subnode_ready: bool = false
var _anim_clock: float = 0.0
var _pulse_timer: float = 3.0

var _sprite: Sprite2D = null
var _shield_dome: Sprite2D = null
var _title_lbl: Label = null
var _state_lbl: Label = null


func _ready() -> void:
	y_sort_enabled = true
	if not is_instance_valid(_sprite):
		_build_visuals()
	_refresh_visuals()


func _build_visuals() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()

	_sprite = Sprite2D.new()
	_sprite.name = "BossSprite"
	if ResourceLoader.exists(UiPixelTheme.TEX_W2_BOSS_AI):
		_sprite.texture = load(UiPixelTheme.TEX_W2_BOSS_AI)
	_sprite.hframes = 4
	_sprite.vframes = 3
	_sprite.frame = 0
	_sprite.offset = Vector2(0.0, -32.0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	_shield_dome = Sprite2D.new()
	_shield_dome.name = "BossShield"
	if ResourceLoader.exists(UiPixelTheme.TEX_W2_VFX_COMBAT):
		_shield_dome.texture = load(UiPixelTheme.TEX_W2_VFX_COMBAT)
	_shield_dome.hframes = 4
	_shield_dome.vframes = 2
	_shield_dome.frame = 6
	_shield_dome.scale = Vector2(2.2, 2.2)
	_shield_dome.offset = Vector2(0.0, -14.0)
	_shield_dome.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_shield_dome)

	_title_lbl = Label.new()
	_title_lbl.text = "BOSS: THE GATEKEEPER AI"
	_title_lbl.position = Vector2(-110.0, -96.0)
	_title_lbl.custom_minimum_size = Vector2(220.0, 16.0)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 11)
	add_child(_title_lbl)

	_state_lbl = Label.new()
	_state_lbl.position = Vector2(-140.0, -80.0)
	_state_lbl.custom_minimum_size = Vector2(280.0, 16.0)
	_state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_lbl.add_theme_font_size_override("font_size", 10)
	add_child(_state_lbl)

	var solid_body := StaticBody2D.new()
	solid_body.name = "BossSolidBody"
	solid_body.collision_layer = 1
	solid_body.collision_mask = 0
	var solid_col := CollisionShape2D.new()
	var solid_rect := RectangleShape2D.new()
	solid_rect.size = Vector2(56.0, 24.0)
	solid_col.shape = solid_rect
	solid_col.position = Vector2(0.0, -10.0)
	solid_body.add_child(solid_col)
	add_child(solid_body)


func _refresh_visuals() -> void:
	if not _title_lbl or not _state_lbl:
		return
	match phase:
		0:
			_title_lbl.add_theme_color_override("font_color", Color("#f43f5e"))
			if subnode_ready:
				_state_lbl.text = "Sub-Node Terbuka! Debug Terminal 4A [E]"
				_state_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
			else:
				_state_lbl.text = "Perisai Aktif — Tembak EMP [F/Spasi] ke Sub-Node!"
				_state_lbl.add_theme_color_override("font_color", Color("#fca5a5"))
			if _shield_dome:
				_shield_dome.visible = true
		1:
			_title_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
			_state_lbl.text = "OVERHEAT — Debug Inti Logika di Terminal 4B [E]!"
			_state_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
			if _shield_dome:
				_shield_dome.visible = false
		2:
			_title_lbl.text = "GATEKEEPER AI [PULIH — MODE SIAN]"
			_title_lbl.add_theme_color_override("font_color", Color("#38bdf8"))
			_state_lbl.text = "protokol_kota == 'MODE_PELINDUNG_SIAN' (Aktif)"
			_state_lbl.add_theme_color_override("font_color", Color("#86efac"))
			if _shield_dome:
				_shield_dome.visible = false


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_anim_clock += delta
	if _sprite:
		var step := int(_anim_clock * 5.0) % 4
		_sprite.frame = clampi(phase, 0, 2) * 4 + step

	# Only phase 0 (Corrupted) fires dodgeable plasma sweep orbs
	if phase == 0:
		_pulse_timer -= delta
		if _pulse_timer <= 0.0:
			_pulse_timer = 3.0
			var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
			if player and player.global_position.distance_to(global_position) < 150.0:
				if player.has_method("is_input_locked") and not bool(player.call("is_input_locked")):
					_fire_boss_laser_orb((player.global_position - global_position).normalized())


func _fire_boss_laser_orb(dir: Vector2) -> void:
	var parent_node := get_parent()
	if not parent_node:
		return
	var orb := Area2D.new()
	orb.name = "BossLaserOrb"
	orb.global_position = global_position + dir * 24.0
	orb.z_index = 3
	var col := CollisionShape2D.new()
	var c_shape := CircleShape2D.new()
	c_shape.radius = 7.0
	col.shape = c_shape
	orb.add_child(col)

	var outer_r := ColorRect.new()
	outer_r.size = Vector2(12, 12)
	outer_r.position = Vector2(-6, -6)
	outer_r.color = Color("#f43f5e")
	orb.add_child(outer_r)

	var inner_r := ColorRect.new()
	inner_r.size = Vector2(6, 6)
	inner_r.position = Vector2(-3, -3)
	inner_r.color = Color("#fef08a")
	orb.add_child(inner_r)

	parent_node.add_child(orb)
	if not Engine.is_editor_hint():
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.call("play_sfx", "boss_laser_shot", 0.04)
	var target_pos := orb.global_position + dir * 230.0
	var hit_state := {"done": false}
	orb.body_entered.connect(func(b: Node2D) -> void:
		if hit_state["done"]:
			return
		if b and b.is_in_group("player"):
			hit_state["done"] = true
			if b.has_method("take_damage"):
				b.call("take_damage", 12.0, orb.global_position)
			orb.queue_free()
	)
	var tw := orb.create_tween()
	tw.tween_property(orb, "global_position", target_pos, 1.7)
	tw.tween_callback(func() -> void:
		if is_instance_valid(orb):
			orb.queue_free()
	)


func on_emp_hit(origin: Vector2, radius: float) -> void:
	if phase != 0 or subnode_ready:
		return
	if global_position.distance_to(origin) <= radius + 90.0:
		subnode_ready = true
		_refresh_visuals()
		subnode_unlocked.emit()


func advance_to_overheat_phase() -> void:
	phase = 1
	subnode_ready = true
	_refresh_visuals()
	if not Engine.is_editor_hint():
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.call("play_sfx", "boss_overheat")


func advance_to_restored_phase() -> void:
	phase = 2
	_refresh_visuals()
	if not Engine.is_editor_hint():
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.call("play_sfx", "boss_restored")
	boss_restored.emit()
