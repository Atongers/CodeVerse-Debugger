@tool
class_name FriendlyNPC
extends Area2D

## Node NPC Interaktif World 2 (W2-09 48x48, Emote Quest W2-12 16x16).

signal npc_interacted(npc: FriendlyNPC)

@export var npc_id: String = "elder"
@export var npc_name: String = "Rusted Elder"
@export_range(0, 2) var sprite_row: int = 0
@export_range(0, 3) var portrait_col: int = 0
@export_range(0, 5) var emote_col: int = 0

var _sprite: Sprite2D = null
var _emote_sprite: Sprite2D = null
var _name_lbl: Label = null
var _prompt_lbl: Label = null
var _player_in_range: bool = false
var _anim_clock: float = 0.0


func _ready() -> void:
	y_sort_enabled = true
	monitoring = true
	monitorable = true
	_build_visuals()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _build_visuals() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()

	var col := CollisionShape2D.new()
	var c_shape := CircleShape2D.new()
	c_shape.radius = 28.0
	col.shape = c_shape
	add_child(col)

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	if ResourceLoader.exists(UiPixelTheme.TEX_W2_NPCS):
		_sprite.texture = load(UiPixelTheme.TEX_W2_NPCS)
	_sprite.hframes = 4
	_sprite.vframes = 3
	_sprite.frame = clampi(sprite_row, 0, 2) * 4
	_sprite.offset = Vector2(0.0, -14.0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	_emote_sprite = Sprite2D.new()
	_emote_sprite.name = "EmoteSprite"
	_emote_sprite.position = Vector2(0.0, -44.0)
	_emote_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_emote_sprite)
	set_emote(emote_col)

	_name_lbl = Label.new()
	_name_lbl.text = npc_name
	_name_lbl.position = Vector2(-56.0, 8.0)
	_name_lbl.custom_minimum_size = Vector2(112.0, 16.0)
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_lbl.add_theme_font_size_override("font_size", 10)
	_name_lbl.add_theme_color_override("font_color", Color("#38bdf8"))
	add_child(_name_lbl)

	_prompt_lbl = Label.new()
	_prompt_lbl.text = "[E] Bicara"
	_prompt_lbl.visible = false
	_prompt_lbl.position = Vector2(-48.0, -60.0)
	_prompt_lbl.custom_minimum_size = Vector2(96.0, 16.0)
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.add_theme_font_size_override("font_size", 11)
	_prompt_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
	add_child(_prompt_lbl)


func set_emote(col_idx: int, show_emote: bool = true) -> void:
	emote_col = clampi(col_idx, 0, 5)
	if not _emote_sprite:
		return
	_emote_sprite.visible = show_emote
	_emote_sprite.texture = UiPixelTheme.load_atlas(UiPixelTheme.TEX_W2_QUEST_EMOTES, Rect2(emote_col * 16, 0, 16, 16))


func is_player_in_range() -> bool:
	return _player_in_range


func trigger_interact() -> void:
	npc_interacted.emit(self)


func _process(delta: float) -> void:
	_anim_clock += delta
	if _sprite:
		var f_step := int(_anim_clock * 3.5) % 4
		_sprite.frame = clampi(sprite_row, 0, 2) * 4 + f_step
	if _emote_sprite:
		_emote_sprite.position.y = -44.0 + sin(_anim_clock * 4.0) * 2.0


func _on_body_entered(body: Node2D) -> void:
	if body and body.is_in_group("player"):
		_player_in_range = true
		if _prompt_lbl:
			_prompt_lbl.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body and body.is_in_group("player"):
		_player_in_range = false
		if _prompt_lbl:
			_prompt_lbl.visible = false
