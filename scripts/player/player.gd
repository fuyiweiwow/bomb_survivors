extends CharacterBody2D

signal bomb_placed(grid_pos)
signal player_died

const TILE_SIZE = 32
const MOVE_TIME = 0.1

var player_id := 1
var grid_pos := Vector2i.ZERO
var is_moving := false
var alive := true
var bomb_max := 1
var bomb_range := 2
var bomb_placed_count := 0

var input_dir := Vector2i.ZERO
var bomb_pressed := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var head_sprite: Sprite2D = $Head
@onready var body_sprite: Sprite2D = $Body
@onready var legs_sprite: Sprite2D = $Legs

var _game_node = null

func _gm():
	if _game_node == null:
		_game_node = get_tree().get_first_node_in_group("game")
	return _game_node

func setup(p_id: int, tex_parts: Dictionary):
	player_id = p_id
	if p_id == 1:
		sprite.hide()
		head_sprite.texture = tex_parts.get("head")
		body_sprite.texture = tex_parts.get("body")
		legs_sprite.texture = tex_parts.get("legs")
		head_sprite.show()
		body_sprite.show()
		legs_sprite.show()
	else:
		sprite.texture = tex_parts.get("body")
		sprite.show()

func set_grid(gx: int, gy: int):
	grid_pos = Vector2i(gx, gy)
	position = Vector2(gx * TILE_SIZE + TILE_SIZE / 2.0, gy * TILE_SIZE + TILE_SIZE / 2.0)

func _input(event):
	if not alive or player_id != 1:
		return
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_W: input_dir = Vector2i(0, -1)
			KEY_S: input_dir = Vector2i(0, 1)
			KEY_A: input_dir = Vector2i(-1, 0)
			KEY_D: input_dir = Vector2i(1, 0)
			KEY_SPACE: bomb_pressed = true
	elif event is InputEventKey and not event.pressed:
		match event.physical_keycode:
			KEY_W, KEY_S, KEY_A, KEY_D:
				input_dir = Vector2i.ZERO

func _physics_process(_delta):
	if not alive or is_moving:
		return

	var gm = _gm()
	if not gm: return

	var d := Vector2i.ZERO

	# priority: event buffer > held keys
	if input_dir != Vector2i.ZERO:
		d = input_dir
	else:
		if Input.is_action_pressed("p1_up"): d.y = -1
		elif Input.is_action_pressed("p1_down"): d.y = 1
		elif Input.is_action_pressed("p1_left"): d.x = -1
		elif Input.is_action_pressed("p1_right"): d.x = 1

	if d != Vector2i.ZERO:
		var target := grid_pos + d
		if gm.is_cell_walkable(target.x, target.y):
			grid_pos = target
			is_moving = true
			var tw := create_tween()
			tw.tween_property(self, "position",
				Vector2(target.x * TILE_SIZE + TILE_SIZE / 2.0, target.y * TILE_SIZE + TILE_SIZE / 2.0),
				MOVE_TIME)
			tw.tween_callback(func(): is_moving = false)

	if (bomb_pressed or Input.is_action_just_pressed("p1_bomb")) and bomb_placed_count < bomb_max:
		bomb_pressed = false
		if gm and not gm.has_bomb_at(grid_pos.x, grid_pos.y):
			bomb_placed_count += 1
			bomb_placed.emit(grid_pos)

func on_bomb_exploded():
	bomb_placed_count = max(bomb_placed_count - 1, 0)

func die():
	if not alive: return
	alive = false
	var tw := create_tween()
	tw.tween_property($SpriteGroup, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): player_died.emit(); queue_free())
