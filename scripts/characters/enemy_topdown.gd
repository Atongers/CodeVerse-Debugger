@tool
class_name EnemyTopDown
extends CharacterBody2D

## AI Musuh Top-Down World 2: ScrapHound (0), PatrolDrone (1), ShieldSentinel (2) + Conditional Shield & Loot Drop.

signal enemy_defeated(enemy: EnemyTopDown, enemy_type: int, drop_pos: Vector2)

@export_enum("ScrapHound:0", "PatrolDrone:1", "ShieldSentinel:2") var enemy_type: int = 0
@export var patrol_span: Vector2 = Vector2(72.0, 0.0)
@export var guaranteed_coolant: bool = false

var max_hp: float = 45.0
var hp: float = 45.0
var move_speed: float = 72.0
var contact_damage: float = 15.0
var shield_active: bool = false
var _shield_open_timer: float = 0.0
var _stun_timer: float = 0.0
var _attack_cd: float = 1.5
var _lunge_telegraph: float = 0.0
var _patrol_origin: Vector2 = Vector2.ZERO
var _patrol_dir: float = 1.0
var _anim_clock: float = 0.0
var _is_dead: bool = false

var _sprite: Sprite2D = null
var _shield_dome: Sprite2D = null
var _status_lbl: Label = null
var _hp_lbl: Label = null


func _ready() -> void:
	add_to_group("w2_enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	y_sort_enabled = true
	collision_layer = 2
	collision_mask = 1
	_patrol_origin = global_position
	_configure_by_type()
	_build_visuals()
	_refresh_labels()


func _configure_by_type() -> void:
	match enemy_type:
		0: # ScrapHound
			max_hp = 45.0
			hp = 45.0
			move_speed = 72.0
			contact_damage = 15.0
			shield_active = false
		1: # PatrolDrone
			max_hp = 60.0
			hp = 60.0
			move_speed = 60.0
			contact_damage = 15.0
			shield_active = false
			_attack_cd = 2.2
		2: # ShieldSentinel
			max_hp = 90.0
			hp = 90.0
			move_speed = 46.0
			contact_damage = 20.0
			shield_active = true


func _build_visuals() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()

	var col := CollisionShape2D.new()
	var c_shape := CircleShape2D.new()
	c_shape.radius = 10.0
	col.shape = c_shape
	add_child(col)

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_sprite.offset = Vector2(0.0, -14.0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	match enemy_type:
		0:
			if ResourceLoader.exists(UiPixelTheme.TEX_W2_ENEMY_HOUND):
				_sprite.texture = load(UiPixelTheme.TEX_W2_ENEMY_HOUND)
			_sprite.hframes = 4
			_sprite.vframes = 3
		1:
			if ResourceLoader.exists(UiPixelTheme.TEX_W2_ENEMY_DRONE):
				_sprite.texture = load(UiPixelTheme.TEX_W2_ENEMY_DRONE)
			_sprite.hframes = 4
			_sprite.vframes = 2
		2:
			if ResourceLoader.exists(UiPixelTheme.TEX_W2_ENEMY_SENTINEL):
				_sprite.texture = load(UiPixelTheme.TEX_W2_ENEMY_SENTINEL)
			_sprite.hframes = 4
			_sprite.vframes = 3
	add_child(_sprite)

	if enemy_type == 2:
		_shield_dome = Sprite2D.new()
		_shield_dome.name = "ShieldDome"
		if ResourceLoader.exists(UiPixelTheme.TEX_W2_VFX_COMBAT):
			_shield_dome.texture = load(UiPixelTheme.TEX_W2_VFX_COMBAT)
		_shield_dome.hframes = 4
		_shield_dome.vframes = 2
		_shield_dome.frame = 4
		_shield_dome.offset = Vector2(0.0, -14.0)
		_shield_dome.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_shield_dome)

	_status_lbl = Label.new()
	_status_lbl.position = Vector2(-95.0, -64.0 if enemy_type == 2 else -56.0)
	_status_lbl.custom_minimum_size = Vector2(190.0, 14.0)
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_size_override("font_size", 9)
	_status_lbl.add_theme_color_override("font_color", Color("#38bdf8") if enemy_type == 2 else Color("#fbbf24"))
	add_child(_status_lbl)

	_hp_lbl = Label.new()
	_hp_lbl.position = Vector2(-50.0, -50.0 if enemy_type == 2 else -42.0)
	_hp_lbl.custom_minimum_size = Vector2(100.0, 14.0)
	_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_lbl.add_theme_font_size_override("font_size", 10)
	_hp_lbl.add_theme_color_override("font_color", Color("#f87171"))
	add_child(_hp_lbl)


func _refresh_labels() -> void:
	if _hp_lbl:
		_hp_lbl.text = "HP: %d/%d" % [int(ceilf(hp)), int(max_hp)]
	if not _status_lbl:
		return
	if enemy_type == 2:
		if shield_active:
			_status_lbl.text = "if emp_tier < 2: SHIELD = IMMUNE"
			_status_lbl.add_theme_color_override("font_color", Color("#38bdf8"))
		else:
			_status_lbl.text = "elif emp_hit == True: SHIELD = OPEN (%.1fs)" % _shield_open_timer
			_status_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
	elif _stun_timer > 0.0:
		_status_lbl.text = "STUNNED (%.1fs)" % _stun_timer
	else:
		_status_lbl.text = ""


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _is_dead:
		return
	_anim_clock += delta

	if enemy_type == 2 and not shield_active and _shield_open_timer > 0.0:
		_shield_open_timer = maxf(0.0, _shield_open_timer - delta)
		if _shield_open_timer <= 0.0:
			shield_active = true
			if _shield_dome:
				_shield_dome.visible = true
		_refresh_labels()

	if _stun_timer > 0.0:
		_stun_timer = maxf(0.0, _stun_timer - delta)
		velocity = Vector2.ZERO
		_update_visual_frame(false)
		_refresh_labels()
		return

	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player and player.has_method("is_input_locked") and bool(player.call("is_input_locked")):
		velocity = Vector2.ZERO
		_update_visual_frame(false)
		return

	var dist_to_player := 9999.0
	var to_player := Vector2.ZERO
	if player:
		to_player = player.global_position - global_position
		dist_to_player = to_player.length()

	var is_chasing := dist_to_player <= 115.0
	if is_chasing and player:
		if enemy_type == 0:
			# ScrapHound lunge telegraph when close
			if dist_to_player < 38.0 and _lunge_telegraph <= 0.0 and _attack_cd <= 0.0:
				_lunge_telegraph = 0.35
				_attack_cd = 1.4
				_play_sfx("hound_telegraph", 0.05)
			if _lunge_telegraph > 0.0:
				_lunge_telegraph -= delta
				velocity = to_player.normalized() * (move_speed * 2.1 if _lunge_telegraph <= 0.1 else 15.0)
				if _sprite and _lunge_telegraph > 0.1:
					_sprite.modulate = Color(1.5, 0.45, 0.45)
			else:
				if _sprite:
					_sprite.modulate = Color.WHITE
				velocity = to_player.normalized() * move_speed
		elif enemy_type == 1:
			# PatrolDrone hovers and fires dodgeable energy orb (120 px/s) every 2.2s
			velocity = to_player.normalized() * (move_speed * 0.65 if dist_to_player > 58.0 else 0.0)
			_attack_cd -= delta
			if _attack_cd <= 0.0 and dist_to_player <= 125.0:
				_attack_cd = 2.2
				_spawn_energy_orb(to_player.normalized(), 120.0, contact_damage)
		else:
			velocity = to_player.normalized() * move_speed
	else:
		if _sprite:
			_sprite.modulate = Color.WHITE
		# Simple patrol around origin
		var target := _patrol_origin + patrol_span * _patrol_dir
		var diff := target - global_position
		if diff.length() < 8.0:
			_patrol_dir *= -1.0
		velocity = diff.normalized() * (move_speed * 0.65)

	# Soft separation steering so enemies do not stack on the exact same pixel
	var sep := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("w2_enemies"):
		if other == self or not (other is Node2D):
			continue
		var d_vec := global_position - (other as Node2D).global_position
		var d_len := d_vec.length()
		if d_len > 0.01 and d_len < 30.0:
			sep += d_vec.normalized() * ((30.0 - d_len) / 30.0) * 85.0
	velocity += sep

	if _attack_cd > 0.0 and enemy_type != 1:
		_attack_cd = maxf(0.0, _attack_cd - delta)

	move_and_slide()
	global_position.x = clampf(global_position.x, 24.0, 1896.0)
	global_position.y = clampf(global_position.y, 24.0, 1256.0)

	if player and dist_to_player < 20.0 and _lunge_telegraph <= 0.1 and player.has_method("take_damage"):
		player.call("take_damage", contact_damage, global_position)

	_update_visual_frame(is_chasing)


func _spawn_energy_orb(dir: Vector2, speed_px: float, dmg: float) -> void:
	var parent_node := get_parent()
	if not parent_node:
		return
	var orb := Area2D.new()
	orb.name = "DroneOrb"
	orb.global_position = global_position + dir * 12.0
	orb.z_index = 3
	var col := CollisionShape2D.new()
	var c_shape := CircleShape2D.new()
	c_shape.radius = 5.0
	col.shape = c_shape
	orb.add_child(col)

	var orb_rect := ColorRect.new()
	orb_rect.size = Vector2(8, 8)
	orb_rect.position = Vector2(-4, -4)
	orb_rect.color = Color("#f43f5e")
	orb.add_child(orb_rect)

	var core_rect := ColorRect.new()
	core_rect.size = Vector2(4, 4)
	core_rect.position = Vector2(-2, -2)
	core_rect.color = Color("#fde047")
	orb.add_child(core_rect)

	parent_node.add_child(orb)
	_play_sfx("drone_shoot", 0.05)
	var target_pos := orb.global_position + dir * (speed_px * 1.8)
	var hit_state := {"done": false}
	orb.body_entered.connect(func(b: Node2D) -> void:
		if hit_state["done"]:
			return
		if b and b.is_in_group("player"):
			hit_state["done"] = true
			if b.has_method("take_damage"):
				b.call("take_damage", dmg, orb.global_position)
			orb.queue_free()
	)
	var tw := orb.create_tween()
	tw.tween_property(orb, "global_position", target_pos, 1.8)
	tw.tween_callback(func() -> void:
		if is_instance_valid(orb):
			orb.queue_free()
	)


func _update_visual_frame(is_chasing: bool) -> void:
	if not _sprite:
		return
	if absf(velocity.x) > 2.0:
		_sprite.flip_h = velocity.x < 0.0
	var step := int(_anim_clock * 6.5) % 4
	if enemy_type == 0:
		var row := 2 if (_stun_timer > 0.0 or _lunge_telegraph > 0.0) else (1 if is_chasing else 0)
		_sprite.frame = row * 4 + step
	elif enemy_type == 1:
		var row := 1 if is_chasing else 0
		_sprite.frame = row * 4 + step
	elif enemy_type == 2:
		var row := 2 if not shield_active else (1 if is_chasing else 0)
		_sprite.frame = row * 4 + step


func on_emp_hit(origin: Vector2, radius: float, damage: float, stun_duration: float, emp_tier: int) -> void:
	if _is_dead:
		return
	var dist := global_position.distance_to(origin)
	if dist > radius + 16.0:
		return

	if enemy_type == 2 and shield_active:
		if emp_tier >= 2:
			shield_active = false
			_shield_open_timer = 5.0
			if _shield_dome:
				_shield_dome.visible = false
			var sm: Node = get_node_or_null("/root/SaveManager")
			if sm and sm.has_method("unlock_achievement"):
				sm.call("unlock_achievement", "ACH-11")
			_stun_timer = maxf(_stun_timer, stun_duration)
			_play_sfx("emp_tier2_break")
			_refresh_labels()
		else:
			if _shield_dome:
				_shield_dome.modulate = Color(1.4, 1.4, 1.8)
				var tw := create_tween()
				tw.tween_property(_shield_dome, "modulate", Color.WHITE, 0.2)
			_play_sfx("shield_clang", 0.04)
			_refresh_labels()
		return

	hp = maxf(0.0, hp - damage)
	_stun_timer = maxf(_stun_timer, stun_duration)
	var push_dir := (global_position - origin).normalized()
	global_position += push_dir * 14.0
	_refresh_labels()

	if _sprite:
		_sprite.modulate = Color(1.5, 0.7, 0.4)
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color.WHITE, 0.22)

	if hp <= 0.0:
		_is_dead = true
		_play_sfx("enemy_defeat")
		var sm: Node = get_node_or_null("/root/SaveManager")
		if sm and sm.has_method("record_emp_kill"):
			sm.call("record_emp_kill")
		if enemy_type == 2 and sm and sm.has_method("set_quest_flag"):
			sm.call("set_quest_flag", "sentinel_defeated", true)
		enemy_defeated.emit(self, enemy_type, global_position)
		queue_free()
	else:
		_play_sfx("enemy_stun", 0.05)


func _play_sfx(sfx_id: String, pitch_jitter: float = 0.0) -> void:
	if Engine.is_editor_hint():
		return
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.call("play_sfx", sfx_id, pitch_jitter)
