extends Node

const ARRIVAL_EPSILON := 0.0001
const MAX_SUBSTEPS_PER_TICK := 4

var _game: Node

func setup(game_manager: Node):
	_game = game_manager

func try_move(player_index: int, direction: Vector2i) -> bool:
	var state := _game.character_state_at(player_index) as CharacterState
	if state == null or not state.can_start_grid_move() or direction == Vector2i.ZERO:
		return false
	var node := state.node()
	var current_cell := Constants.world_to_grid(node.position)
	state.set_cell(current_cell)
	if state.elevation.is_impact_support():
		_game.wall_mechanics.leave_elevated_cell(state)
		_game.airborne_controller.begin_fall(player_index)
	var is_airborne := state.is_airborne()
	var target_height := state.movement_height()
	var target_world := Constants.substep_target(node.position, direction, target_height)
	var target_cell := Constants.world_to_grid(target_world)
	if not Constants.is_grid_cell_valid(target_cell):
		return false
	if not is_airborne and target_cell != current_cell and _game.map_state.is_wall(target_cell):
		return _game.wall_mechanics.try_wall_hop(player_index, direction)
	if not is_airborne and target_cell != current_cell and not is_cell_walkable(target_cell, player_index):
		return false

	state.set_last_move_direction(direction)
	if state.elevation.is_elevated():
		_game.wall_mechanics.leave_elevated_cell(state)
	node.look_at(target_world, Vector3.UP)
	var move_duration: float = Constants.move_duration_for_speed(state.speed_value()) / float(Constants.MOVE_SUBSTEPS_PER_TILE)
	if _game.weather_manager:
		move_duration *= _game.weather_manager.movement_duration_multiplier(target_cell)
	move_duration *= state.movement_duration_multiplier()
	start_move(player_index, current_cell, target_cell, target_world, move_duration)
	return true

func is_cell_walkable(cell: Vector2i, player_index := -1) -> bool:
	if not Constants.is_grid_cell_valid(cell):
		return false
	var state := _game.character_state_at(player_index) as CharacterState
	var has_wings := state != null and state.effects.has_wings()
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
	var state := _game.character_state_at(player_index) as CharacterState
	return state != null and state.bombs.can_pass_hop_bomb(cell, _game.bomb_manager.game_time())

func start_move(player_index: int, from_cell: Vector2i, target_cell: Vector2i, target: Vector3, duration: float):
	var state := _game.character_state_at(player_index) as CharacterState
	if state == null:
		return
	var player_node := state.node()
	var move_distance := Constants.MOVE_STEP_SIZE
	if is_instance_valid(player_node):
		var offset := target - player_node.position
		offset.y = 0.0
		move_distance = offset.length()
	state.begin_grid_move(from_cell, target_cell, target, move_distance / maxf(duration, 0.01))

func cancel_move(player: Dictionary):
	var state := _game.character_state_by_id(int(player.get("id", -1))) as CharacterState
	if state == null:
		return
	var node := state.node()
	if node != null:
		state.sync_grid_position(node.position)
	var resting_position := Constants.grid_to_world(state.cell()) + Vector3(0, state.movement_height(), 0) if node != null else Vector3.ZERO
	state.cancel_grid_move(resting_position)
	if node != null:
		node.position = resting_position

func _physics_process(delta: float):
	if _game == null or _game.game_over:
		return
	for index in range(_game.players.size()):
		_advance_player(index, delta)

func _advance_player(index: int, delta: float):
	var state := _game.character_state_at(index) as CharacterState
	if state == null or not state.is_alive() or not state.is_moving() or not state.is_grid_motion_active():
		return
	var node := state.node()
	if node == null:
		state.cancel_grid_move(Vector3.ZERO)
		return

	var travel_budget := state.move_speed_world() * delta
	var cells_advanced := 0
	while travel_budget > ARRIVAL_EPSILON and state.is_moving() and cells_advanced < MAX_SUBSTEPS_PER_TICK:
		var target := state.move_target_world()
		if state.is_airborne():
			target.y = node.position.y
			state.set_move_target_world(target)
		var distance := node.position.distance_to(target)
		if distance > travel_budget + ARRIVAL_EPSILON:
			node.position = node.position.move_toward(target, travel_budget)
			state.sync_grid_position(node.position)
			return

		node.position = target
		state.sync_grid_position(node.position, true)
		travel_budget = maxf(travel_budget - distance, 0.0)
		_complete_substep(index)
		cells_advanced += 1
		if not state.is_alive() or state.is_downed():
			return
		var continued := false
		if index == 0:
			continued = _game.player_commands.try_move_from_input(index)
		elif state.is_ai() and not Constants.is_world_position_at_cell_center(node.position, state.cell()):
			continued = try_move(index, state.move_direction())
		if not continued:
			return

func _complete_substep(index: int):
	var state := _game.character_state_at(index) as CharacterState
	if state == null:
		return
	var arrived_cell := state.complete_grid_move()
	var player_node := state.node()
	if index == 0 and is_instance_valid(player_node) and Constants.is_world_position_at_cell_center((player_node as Node3D).position, arrived_cell):
		_game.audio_manager.play("footstep")
	if state.is_alive() and not state.is_downed() and not state.is_airborne():
		_game.powerup_manager.check_powerup_pickup(index)
