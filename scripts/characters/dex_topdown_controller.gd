@tool
class_name DexTopDownController
extends CharacterBody2D

## Kontroler Top-Down 8-Arah Dex untuk World 2: Condition Canyon (3 Skin 48x48, EMP Pulse, Quick-Use [1]/[2], Upgrade Modifiers).

signal health_changed(current_hp: float, max_hp: float)
signal energy_changed(current_energy: float, max_energy: float)
signal emp_fired(origin: Vector2, radius: float, damage: float, stun_duration: float, emp_tier: int)
signal interact_requested()
signal player_collapsed()

@export var base_move_speed: float = 115.0
@export var sprint_multiplier: float = 1.45
@export var sprint_energy_cost: float = 20.0

var max_health: float = 100.0
var health: float = 100.0
var max_energy: float = 100.0
var energy: float = 100.0
var damage_reduction: float = 0.0
var passive_en_regen: float = 12.0

var emp_radius: float = 56.0
var emp_damage: float = 25.0
var emp_cooldown: float = 1.2
var emp_energy_cost: float = 15.0
var emp_stun_duration: float = 0.6

var spawn_position: Vector2 = Vector2(180, 720)
var _facing_dir: Vector2 = Vector2.DOWN
var _input_locked: bool = false
var _is_overview_cam: bool = false
var _emp_cd_timer: float = 0.0
var _emp_anim_timer: float = 0.0
var _hit_anim_timer: float = 0.0
var _collapse_timer: float = 0.0
var _iframe_timer: float = 0.0
var _anim_clock: float = 0.0
var _was_sprinting: bool = false
var _step_audio_timer: float = 0.0

var _sprite: Sprite2D = null
var _col_shape: CollisionShape2D = null
var _interaction_area: Area2D = null
var _emp_visual: Sprite2D = null
var _camera: Camera2D = null


func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	y_sort_enabled = true
	collision_layer = 1
	collision_mask = 1
	_ensure_nodes()
	spawn_position = global_position
	_apply_skin_texture()
	recalculate_upgrade_stats(true)

	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm:
		if sm.has_signal("skin_changed") and not sm.is_connected("skin_changed", _on_skin_changed):
			sm.connect("skin_changed", _on_skin_changed)
		if sm.has_signal("progression_updated") and not sm.is_connected("progression_updated", _on_progression_updated):
			sm.connect("progression_updated", _on_progression_updated)


func _ensure_nodes() -> void:
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if not _sprite:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		add_child(_sprite)
	_sprite.hframes = 8
	_sprite.vframes = 6
	_sprite.offset = Vector2(0.0, -14.0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_col_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not _col_shape:
		_col_shape = CollisionShape2D.new()
		_col_shape.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = 7.0
		_col_shape.shape = circle
		add_child(_col_shape)

	_interaction_area = get_node_or_null("InteractionArea") as Area2D
	if not _interaction_area:
		_interaction_area = Area2D.new()
		_interaction_area.name = "InteractionArea"
		var ia_col := CollisionShape2D.new()
		var ia_circle := CircleShape2D.new()
		ia_circle.radius = 28.0
		ia_col.shape = ia_circle
		_interaction_area.add_child(ia_col)
		add_child(_interaction_area)

	_emp_visual = get_node_or_null("EmpPulseVisual") as Sprite2D
	if not _emp_visual:
		_emp_visual = Sprite2D.new()
		_emp_visual.name = "EmpPulseVisual"
		add_child(_emp_visual)
	if ResourceLoader.exists(UiPixelTheme.TEX_W2_VFX_COMBAT):
		_emp_visual.texture = load(UiPixelTheme.TEX_W2_VFX_COMBAT)
	_emp_visual.hframes = 4
	_emp_visual.vframes = 2
	_emp_visual.frame = 0
	_emp_visual.visible = false
	_emp_visual.z_index = 2
	_emp_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_camera = get_node_or_null("Camera2D") as Camera2D
	if not _camera:
		_camera = Camera2D.new()
		_camera.name = "Camera2D"
		add_child(_camera)
	_camera.enabled = true
	_camera.zoom = Vector2(1.5, 1.5)
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = 1920
	_camera.limit_bottom = 1280


func _on_skin_changed(_skin_id: String) -> void:
	_apply_skin_texture()


func _on_progression_updated() -> void:
	recalculate_upgrade_stats(false)


func _apply_skin_texture() -> void:
	var path := UiPixelTheme.TEX_W2_DEX_DEFAULT
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm:
		var skin_id := str(sm.get("active_skin"))
		if skin_id == "volt_scout":
			path = UiPixelTheme.TEX_W2_DEX_VOLT
		elif skin_id == "plasma_sentinel":
			path = UiPixelTheme.TEX_W2_DEX_PLASMA
	if ResourceLoader.exists(path) and _sprite:
		_sprite.texture = load(path)


func recalculate_upgrade_stats(refill_vitals: bool = false) -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	var has_surv1 := false
	var has_surv2 := false
	var has_surv3 := false
	var has_surv4 := false
	var has_emp1 := false
	var has_emp2 := false
	var has_emp3 := false
	var has_emp4 := false
	var has_lens := false

	if sm and sm.has_method("has_upgrade"):
		has_surv1 = bool(sm.call("has_upgrade", "surv_1"))
		has_surv2 = bool(sm.call("has_upgrade", "surv_2"))
		has_surv3 = bool(sm.call("has_upgrade", "surv_3"))
		has_surv4 = bool(sm.call("has_upgrade", "surv_4"))
		has_emp1 = bool(sm.call("has_upgrade", "emp_1"))
		has_emp2 = bool(sm.call("has_upgrade", "emp_2"))
		has_emp3 = bool(sm.call("has_upgrade", "emp_3"))
		has_emp4 = bool(sm.call("has_upgrade", "emp_4"))
	if sm and sm.has_method("get_item_count"):
		has_lens = int(sm.call("get_item_count", "logic_calibrator")) > 0

	var old_max_hp := max_health
	var old_max_en := max_energy
	max_health = 100.0 + (25.0 if has_surv1 else 0.0)
	max_energy = 100.0 + (25.0 if has_surv3 else 0.0)
	damage_reduction = 0.20 if has_surv2 else 0.0
	passive_en_regen = 12.0 * (1.5 if has_surv4 else 1.0)

	emp_radius = 56.0 * (1.35 if has_emp1 else 1.0)
	var base_dmg := 25.0 * (1.5 if has_emp2 else 1.0)
	if has_lens:
		base_dmg *= 1.15
	emp_damage = base_dmg
	emp_cooldown = 1.2 * (0.75 if has_emp3 else 1.0)
	emp_energy_cost = 10.0 if has_emp3 else 15.0
	emp_stun_duration = 1.5 if has_emp4 else 0.6

	if refill_vitals:
		health = max_health
		energy = max_energy
	else:
		if max_health > old_max_hp:
			health += (max_health - old_max_hp)
		if max_energy > old_max_en:
			energy += (max_energy - old_max_en)
		health = clampf(health, 0.0, max_health)
		energy = clampf(energy, 0.0, max_energy)

	health_changed.emit(health, max_health)
	energy_changed.emit(energy, max_energy)


func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		velocity = Vector2.ZERO


func is_input_locked() -> bool:
	return _input_locked


func toggle_overview_camera() -> void:
	_is_overview_cam = not _is_overview_cam
	if not _camera:
		return
	var target_zoom := Vector2(0.55, 0.55) if _is_overview_cam else Vector2(1.5, 1.5)
	var tw := create_tween()
	tw.tween_property(_camera, "zoom", target_zoom, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if _input_locked or _collapse_timer > 0.0:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			toggle_overview_camera()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_1:
			use_quick_repair_patch()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_2:
			use_quick_battery_cell()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_F or event.keycode == KEY_SPACE:
			try_fire_emp()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_E:
			interact_requested.emit()
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		try_fire_emp()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_anim_clock += delta
	if _emp_cd_timer > 0.0:
		_emp_cd_timer = maxf(0.0, _emp_cd_timer - delta)
	if _iframe_timer > 0.0:
		_iframe_timer = maxf(0.0, _iframe_timer - delta)

	# Passive energy regeneration always runs (even while TerminalOverlay is open, per design agreement)
	if _collapse_timer <= 0.0 and energy < max_energy:
		energy = minf(max_energy, energy + passive_en_regen * delta)
		energy_changed.emit(energy, max_energy)

	if _emp_anim_timer > 0.0:
		_emp_anim_timer = maxf(0.0, _emp_anim_timer - delta)
		if _emp_visual:
			_emp_visual.visible = true
			var prog := 1.0 - (_emp_anim_timer / 0.32)
			var f_idx := clampi(int(prog * 4.0), 0, 3)
			_emp_visual.frame = f_idx
			var sc := lerpf(0.7, emp_radius / 22.0, prog)
			_emp_visual.scale = Vector2(sc, sc)
		if _emp_anim_timer <= 0.0 and _emp_visual:
			_emp_visual.visible = false

	if _collapse_timer > 0.0:
		_collapse_timer = maxf(0.0, _collapse_timer - delta)
		velocity = Vector2.ZERO
		_update_animation_frame(false)
		if _collapse_timer <= 0.0:
			_respawn_at_checkpoint()
		return

	if _hit_anim_timer > 0.0:
		_hit_anim_timer = maxf(0.0, _hit_anim_timer - delta)

	if _input_locked:
		velocity = Vector2.ZERO
		_update_animation_frame(false)
		return

	var input_vec := Vector2.ZERO
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vec.x += 1.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vec.x -= 1.0
	if Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vec.y += 1.0
	if Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vec.y -= 1.0

	var is_moving := input_vec.length_squared() > 0.001
	if is_moving:
		input_vec = input_vec.normalized()
		_facing_dir = input_vec

	var is_sprinting := is_moving and Input.is_action_pressed("sprint") and energy > 2.0
	var spd := base_move_speed
	if is_sprinting:
		spd *= sprint_multiplier
		energy = maxf(0.0, energy - sprint_energy_cost * delta)
		energy_changed.emit(energy, max_energy)

	velocity = input_vec * spd
	move_and_slide()
	global_position.x = clampf(global_position.x, 16.0, 1904.0)
	global_position.y = clampf(global_position.y, 24.0, 1264.0)
	if is_sprinting and not _was_sprinting:
		_play_sfx("dex_sprint_whoosh")
	_was_sprinting = is_sprinting
	if is_moving and velocity.length_squared() > 25.0:
		_step_audio_timer -= delta
		if _step_audio_timer <= 0.0:
			_step_audio_timer = 0.23 if is_sprinting else 0.33
			_play_sfx("dex_step")
	else:
		_step_audio_timer = 0.0
	_update_animation_frame(is_sprinting)


func _update_animation_frame(is_sprinting: bool) -> void:
	if not _sprite:
		return

	# Flip horizontally only when facing left on horizontal-dominant poses
	var horiz := absf(_facing_dir.x) >= absf(_facing_dir.y)
	_sprite.flip_h = horiz and _facing_dir.x < -0.05

	if _collapse_timer > 0.0:
		var elapsed := 1.2 - _collapse_timer
		var c_col := clampi(4 + int(elapsed / 0.28), 4, 7)
		_sprite.frame = 5 * 8 + c_col
		return

	if _hit_anim_timer > 0.0:
		var h_col := int(_anim_clock * 12.0) % 4
		_sprite.frame = 5 * 8 + h_col
		return

	if _emp_anim_timer > 0.0:
		var e_step := int(_anim_clock * 10.0) % 2
		if horiz:
			_sprite.frame = 4 * 8 + 4 + e_step
		elif _facing_dir.y < 0.0:
			_sprite.frame = 4 * 8 + 2 + e_step
		else:
			_sprite.frame = 4 * 8 + 0 + e_step
		return

	var moving := velocity.length_squared() > 4.0
	if not moving:
		var idle_step := int(_anim_clock * 3.5) % 2
		if horiz:
			_sprite.frame = 0 * 8 + 4 + idle_step
		elif _facing_dir.y < 0.0:
			_sprite.frame = 0 * 8 + 2 + idle_step
		else:
			_sprite.frame = 0 * 8 + 0 + idle_step
		return

	var walk_step := int(_anim_clock * (11.0 if is_sprinting else 7.5)) % 4
	if horiz:
		var base_c := 4 if is_sprinting else 0
		_sprite.frame = 2 * 8 + base_c + walk_step
	elif _facing_dir.y < 0.0:
		var row := 3 if is_sprinting else 1
		_sprite.frame = row * 8 + 4 + walk_step
	else:
		var row := 3 if is_sprinting else 1
		_sprite.frame = row * 8 + 0 + walk_step


func try_fire_emp() -> bool:
	if _emp_cd_timer > 0.0 or energy < emp_energy_cost or _collapse_timer > 0.0:
		return false
	energy = maxf(0.0, energy - emp_energy_cost)
	energy_changed.emit(energy, max_energy)
	_emp_cd_timer = emp_cooldown
	_emp_anim_timer = 0.32

	var emp_tier := 1
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("get_item_count"):
		if int(sm.call("get_item_count", "shield_breaker_coil")) > 0:
			emp_tier = 2

	emp_fired.emit(global_position, emp_radius, emp_damage, emp_stun_duration, emp_tier)
	_play_sfx("emp_pulse")
	return true


func consume_energy(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if energy < amount:
		return false
	energy = maxf(0.0, energy - amount)
	energy_changed.emit(energy, max_energy)
	return true


func heal(amount: float) -> void:
	if amount <= 0.0 or _collapse_timer > 0.0:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


func restore_energy(amount: float, reset_emp_cd: bool = false) -> void:
	if amount > 0.0:
		energy = minf(max_energy, energy + amount)
		energy_changed.emit(energy, max_energy)
	if reset_emp_cd:
		_emp_cd_timer = 0.0


func use_quick_repair_patch() -> bool:
	if health >= max_health:
		return false
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("consume_item") and bool(sm.call("consume_item", "repair_patch", 1)):
		heal(50.0)
		_play_sfx("quick_heal")
		return true
	return false


func use_quick_battery_cell() -> bool:
	if energy >= max_energy:
		return false
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("consume_item") and bool(sm.call("consume_item", "battery_cell", 1)):
		restore_energy(50.0, false)
		_play_sfx("quick_battery")
		return true
	return false


func take_damage(amount: float, knockback_from: Vector2 = Vector2.ZERO) -> void:
	if _iframe_timer > 0.0 or _collapse_timer > 0.0 or amount <= 0.0:
		return
	var final_dmg := maxf(1.0, amount * (1.0 - damage_reduction))
	health = maxf(0.0, health - final_dmg)
	health_changed.emit(health, max_health)
	_iframe_timer = 0.75
	_hit_anim_timer = 0.28
	_play_sfx("dex_hit")

	if knockback_from != Vector2.ZERO:
		var dir := (global_position - knockback_from).normalized()
		global_position += dir * 10.0

	if _sprite:
		_sprite.modulate = Color(1.0, 0.45, 0.45)
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color.WHITE, 0.25)

	if health <= 0.0:
		_collapse_timer = 1.2
		_play_sfx("dex_collapse")
		player_collapsed.emit()


func _respawn_at_checkpoint() -> void:
	global_position = spawn_position
	health = max_health
	energy = max_energy
	health_changed.emit(health, max_health)
	energy_changed.emit(energy, max_energy)


func _play_sfx(sfx_id: String) -> void:
	if Engine.is_editor_hint():
		return
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.call("play_sfx", sfx_id)
