extends CharacterBody2D

signal bomb_placed(grid_pos)
signal player_died

const TILE_SIZE = 32

var grid_pos := Vector2i.ZERO
var is_moving := false
var alive := true
var player_id := 2

var speed := 5
var bomb_max := 1
var bomb_range := 1
var bomb_placed_count := 0

const MAX_SPEED := 10
const MAX_BOMBS := 8
const MAX_RANGE := 10

var move_timer := 0.0
var move_interval := 0.5
var bomb_timer := 0.0
var bomb_interval := 2.0
var last_bomb_pos := Vector2i(-1, -1)
var move_dir := Vector2i.ZERO

@onready var sprite: Sprite2D = $Sprite2D

var _game_node = null
func _gm():
	if _game_node == null:
		_game_node = get_tree().get_first_node_in_group("game")
	return _game_node

func move_time() -> float:
	return 0.5 / float(speed)

func add_speed(amount: int):
	speed = clampi(speed + amount, 1, MAX_SPEED)

func add_bomb(amount: int):
	bomb_max = clampi(bomb_max + amount, 1, MAX_BOMBS)

func add_range(amount: int):
	bomb_range = clampi(bomb_range + amount, 1, MAX_RANGE)

func setup(p_id: int, tex: Texture2D):
	player_id = p_id
	sprite.texture = tex
	move_interval = randf_range(0.3, 0.8)
	bomb_interval = randf_range(1.5, 3.5)

func set_grid(gx: int, gy: int):
	grid_pos = Vector2i(gx, gy)
	position = Vector2(gx * TILE_SIZE + TILE_SIZE / 2.0, gy * TILE_SIZE + TILE_SIZE / 2.0)

func _physics_process(delta):
	if not alive or is_moving: return

	var gm = _gm()
	if not gm: return

	move_timer += delta
	bomb_timer += delta

	if move_timer >= move_interval:
		move_timer = 0.0
		_choose_direction(gm)

	if move_dir != Vector2i.ZERO:
		var target := grid_pos + move_dir
		if gm.is_cell_walkable(target.x, target.y):
			grid_pos = target
			is_moving = true
			var tw := create_tween()
			tw.tween_property(self, "position",
				Vector2(target.x * TILE_SIZE + TILE_SIZE / 2.0, target.y * TILE_SIZE + TILE_SIZE / 2.0),
				move_time())
			tw.tween_callback(func():
				is_moving = false
				gm.check_powerup_pickup(self)
			)
		else:
			move_dir = Vector2i.ZERO

	if bomb_timer >= bomb_interval and bomb_placed_count < bomb_max:
		bomb_timer = 0.0
		if not gm.has_bomb_at(grid_pos.x, grid_pos.y):
			if _is_safe_to_bomb(gm):
				bomb_placed_count += 1
				last_bomb_pos = grid_pos
				bomb_placed.emit(grid_pos)

func _choose_direction(gm):
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	dirs.shuffle()

	if last_bomb_pos != Vector2i(-1, -1):
		var away := grid_pos - last_bomb_pos
		if away.length() > 0:
			var best_dirs = _filter_away(dirs, grid_pos, last_bomb_pos)
			if not best_dirs.is_empty():
				dirs = best_dirs

	# try to move toward visible powerups
	var gm_ref = _gm()
	if gm_ref:
		var pu_pos = gm_ref.nearest_powerup_pos(grid_pos)
		if pu_pos != Vector2i(-1, -1):
			var dx = pu_pos.x - grid_pos.x
			var dy = pu_pos.y - grid_pos.y
			var toward := Vector2i.ZERO
			if abs(dx) >= abs(dy):
				toward = Vector2i(signi(dx), 0)
			else:
				toward = Vector2i(0, signi(dy))
			dirs.push_front(toward)

	for d in dirs:
		var t = grid_pos + d
		if gm.is_cell_walkable(t.x, t.y):
			move_dir = d
			return

	move_dir = Vector2i.ZERO

func _filter_away(dirs: Array, pos: Vector2i, away_from: Vector2i) -> Array:
	var result: Array = []
	var dx := pos.x - away_from.x
	var dy := pos.y - away_from.y
	for d in dirs:
		if d.x != 0 and signi(d.x) == signi(dx) and dx != 0:
			result.append(d)
		elif d.y != 0 and signi(d.y) == signi(dy) and dy != 0:
			result.append(d)
	if result.is_empty():
		return dirs
	result.shuffle()
	return result

func _is_safe_to_bomb(gm) -> bool:
	var escape_dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	escape_dirs.shuffle()
	for d in escape_dirs:
		var t = grid_pos + d
		if gm.is_cell_walkable(t.x, t.y):
			return true
	return false

func on_bomb_exploded():
	bomb_placed_count = max(bomb_placed_count - 1, 0)

func die():
	if not alive: return
	alive = false
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): player_died.emit(); queue_free())
