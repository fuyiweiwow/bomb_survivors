extends Node

const ARRIVAL_EPSILON := 0.0001
const MAX_CELLS_PER_TICK := 4

var _game: Node

func setup(game_manager: Node):
	_game = game_manager

func start_move(player_index: int, target: Vector3, duration: float):
	if player_index < 0 or player_index >= _game.players.size():
		return
	var player: Dictionary = _game.players[player_index]
	player["move_target_world"] = target
	player["move_speed_world"] = Constants.TILE_SIZE / maxf(duration, 0.01)
	player["grid_motion_active"] = true
	player["is_moving"] = true
	player["move_tween"] = null

func cancel_move(player: Dictionary):
	player["is_moving"] = false
	player["move_target_world"] = Vector3.ZERO
	player["move_speed_world"] = 0.0
	player["grid_motion_active"] = false
	player["move_tween"] = null
	var node = player.get("node")
	if is_instance_valid(node):
		var target_height := 0.92 if float(player.get("wings_timer", 0.0)) > 0.0 else 0.0
		(node as Node3D).position = Constants.grid_to_world(player["grid_pos"]) + Vector3(0, target_height, 0)

func _physics_process(delta: float):
	if _game == null or _game.game_over:
		return
	for index in range(_game.players.size()):
		_advance_player(index, delta)

func _advance_player(index: int, delta: float):
	var player: Dictionary = _game.players[index]
	if not bool(player.get("alive", false)) or not bool(player.get("is_moving", false)) or not bool(player.get("grid_motion_active", false)):
		return
	var node = player.get("node")
	if not is_instance_valid(node):
		player["is_moving"] = false
		return

	var travel_budget := float(player.get("move_speed_world", 0.0)) * delta
	var cells_advanced := 0
	while travel_budget > ARRIVAL_EPSILON and bool(player.get("is_moving", false)) and cells_advanced < MAX_CELLS_PER_TICK:
		var target := player.get("move_target_world", (node as Node3D).position) as Vector3
		var distance := (node as Node3D).position.distance_to(target)
		if distance > travel_budget + ARRIVAL_EPSILON:
			(node as Node3D).position = (node as Node3D).position.move_toward(target, travel_budget)
			return

		(node as Node3D).position = target
		travel_budget = maxf(travel_budget - distance, 0.0)
		_complete_cell(index)
		cells_advanced += 1
		if index != 0 or not bool(player.get("alive", false)) or bool(player.get("downed", false)):
			return
		var next_direction: Vector2i = _game.read_player_move_direction()
		if next_direction == Vector2i.ZERO or not _game._try_move_player(index, next_direction):
			return

func _complete_cell(index: int):
	var player: Dictionary = _game.players[index]
	player["is_moving"] = false
	player["move_speed_world"] = 0.0
	player["grid_motion_active"] = false
	if bool(player.get("alive", false)) and not bool(player.get("downed", false)):
		_game.powerup_manager.check_powerup_pickup(index)
