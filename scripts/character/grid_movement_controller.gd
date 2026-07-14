extends Node

const ARRIVAL_EPSILON := 0.0001
const MAX_SUBSTEPS_PER_TICK := 4

var _game: Node

func setup(game_manager: Node):
	_game = game_manager

func try_move(player_index: int, direction: Vector2i) -> bool:
	if player_index < 0 or player_index >= _game.players.size():
		return false
	var player: Dictionary = _game.players[player_index]
	if not bool(player.get("alive", false)) or bool(player.get("downed", false)) or bool(player.get("is_moving", false)):
		return false
	if float(player.get("frozen_timer", 0.0)) > 0.0 or direction == Vector2i.ZERO:
		return false
	var player_node = player.get("node")
	if not is_instance_valid(player_node):
		return false
	var node := player_node as Node3D
	var current_cell := Constants.world_to_grid(node.position)
	player["grid_pos"] = current_cell
	if bool(player.get("impact_support", false)):
		_game.wall_mechanics.leave_elevated_cell(player)
		_game.airborne_controller.begin_fall(player_index)
	var is_airborne := bool(player.get("airborne", false))
	var target_height := node.position.y if is_airborne else (0.92 if float(player.get("wings_timer", 0.0)) > 0.0 else 0.0)
	var target_world := Constants.substep_target(node.position, direction, target_height)
	var target_cell := Constants.world_to_grid(target_world)
	if not Constants.is_grid_cell_valid(target_cell):
		return false
	if not is_airborne and target_cell != current_cell and _game.map_state.is_wall(target_cell):
		return _game.wall_mechanics.try_wall_hop(player_index, direction)
	if not is_airborne and target_cell != current_cell and not is_cell_walkable(target_cell, player_index):
		return false

	player["last_move_dir"] = direction
	if (player["elevated_cell"] as Vector2i) != Vector2i(-1, -1):
		_game.wall_mechanics.leave_elevated_cell(player)
	player["is_moving"] = true
	node.look_at(target_world, Vector3.UP)
	var move_duration: float = Constants.move_duration_for_speed(int(player["speed"])) / float(Constants.MOVE_SUBSTEPS_PER_TILE)
	if _game.weather_manager:
		move_duration *= _game.weather_manager.movement_duration_multiplier(target_cell)
	if float(player.get("slow_timer", 0.0)) > 0.0:
		move_duration *= 3.33
	start_move(player_index, current_cell, target_cell, target_world, move_duration)
	return true

func is_cell_walkable(cell: Vector2i, player_index := -1) -> bool:
	if not Constants.is_grid_cell_valid(cell):
		return false
	var has_wings: bool = player_index >= 0 and player_index < _game.players.size() and float(_game.players[player_index].get("wings_timer", 0.0)) > 0.0
	if _game.map_state.is_wall(cell) or (not has_wings and not _game.map_state.is_walkable(cell)):
		return false
	if _game.oil_barrels.has(cell) and not has_wings:
		return false
	if _game.bomb_map.has(cell) and not has_wings and not _can_player_pass_bomb(player_index, cell):
		return false
	return true

func _can_player_pass_bomb(player_index: int, cell: Vector2i) -> bool:
	if player_index < 0 or player_index >= _game.players.size() or not _game.bomb_map.has(cell):
		return false
	var entry: Dictionary = _game.bomb_map[cell]
	if int(entry.get("player_index", -1)) != player_index:
		return false
	var player: Dictionary = _game.players[player_index]
	return _game.bomb_manager.game_time() <= float(player.get("bomb_hop_until", -99.0)) and (player.get("bomb_hop_cells", {}) as Dictionary).has(cell)

func start_move(player_index: int, from_cell: Vector2i, target_cell: Vector2i, target: Vector3, duration: float):
	if player_index < 0 or player_index >= _game.players.size():
		return
	var player: Dictionary = _game.players[player_index]
	player["move_from_cell"] = from_cell
	player["move_target_cell"] = target_cell
	player["move_target_world"] = target
	var player_node = player.get("node")
	var move_distance := Constants.MOVE_STEP_SIZE
	if is_instance_valid(player_node):
		var offset := target - (player_node as Node3D).position
		offset.y = 0.0
		move_distance = offset.length()
	player["move_speed_world"] = move_distance / maxf(duration, 0.01)
	player["grid_motion_active"] = true
	player["is_moving"] = true
	player["move_tween"] = null

func cancel_move(player: Dictionary):
	var node = player.get("node")
	if is_instance_valid(node):
		_sync_grid_cell(player, node as Node3D)
	player["is_moving"] = false
	player["move_from_cell"] = player["grid_pos"]
	player["move_target_cell"] = player["grid_pos"]
	player["move_speed_world"] = 0.0
	player["grid_motion_active"] = false
	player["move_tween"] = null
	if is_instance_valid(node):
		var target_height := (node as Node3D).position.y if bool(player.get("airborne", false)) else (0.92 if float(player.get("wings_timer", 0.0)) > 0.0 else 0.0)
		var resting_position := Constants.grid_to_world(player["grid_pos"]) + Vector3(0, target_height, 0)
		player["move_target_world"] = resting_position
		(node as Node3D).position = resting_position
	else:
		player["move_target_world"] = Vector3.ZERO

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
	while travel_budget > ARRIVAL_EPSILON and bool(player.get("is_moving", false)) and cells_advanced < MAX_SUBSTEPS_PER_TICK:
		var target := player.get("move_target_world", (node as Node3D).position) as Vector3
		if bool(player.get("airborne", false)):
			target.y = (node as Node3D).position.y
			player["move_target_world"] = target
		var distance := (node as Node3D).position.distance_to(target)
		if distance > travel_budget + ARRIVAL_EPSILON:
			(node as Node3D).position = (node as Node3D).position.move_toward(target, travel_budget)
			_sync_grid_cell(player, node as Node3D)
			return

		(node as Node3D).position = target
		_sync_grid_cell(player, node as Node3D, true)
		travel_budget = maxf(travel_budget - distance, 0.0)
		_complete_substep(index)
		cells_advanced += 1
		if not bool(player.get("alive", false)) or bool(player.get("downed", false)):
			return
		var continued := false
		if index == 0:
			continued = _game.player_commands.try_move_from_input(index)
		elif bool(player.get("ai", false)) and not Constants.is_world_position_at_cell_center((node as Node3D).position, player["grid_pos"]):
			continued = try_move(index, player.get("move_dir", Vector2i.ZERO))
		if not continued:
			return

func _complete_substep(index: int):
	var player: Dictionary = _game.players[index]
	var arrived_cell: Vector2i = player.get("move_target_cell", player["grid_pos"])
	player["grid_pos"] = arrived_cell
	player["move_from_cell"] = arrived_cell
	player["move_target_cell"] = arrived_cell
	player["is_moving"] = false
	player["move_speed_world"] = 0.0
	player["grid_motion_active"] = false
	var player_node = player.get("node")
	if index == 0 and is_instance_valid(player_node) and Constants.is_world_position_at_cell_center((player_node as Node3D).position, arrived_cell):
		_game.audio_manager.play("footstep")
	if bool(player.get("alive", false)) and not bool(player.get("downed", false)) and not bool(player.get("airborne", false)):
		_game.powerup_manager.check_powerup_pickup(index)

func _sync_grid_cell(player: Dictionary, node: Node3D, force_target := false):
	var actual_cell := Constants.world_to_grid(node.position)
	if force_target:
		actual_cell = player.get("move_target_cell", player["grid_pos"]) as Vector2i
	if Constants.is_grid_cell_valid(actual_cell):
		player["grid_pos"] = actual_cell
