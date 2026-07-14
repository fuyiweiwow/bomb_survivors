extends Node

const AI_PATHFINDER := preload("res://scripts/character/ai_pathfinder.gd")
const INVALID_CELL := Vector2i(-1, -1)
const SAFETY_MARGIN := 0.20

var _game: Node

func setup(game_manager: Node):
	_game = game_manager

func notify_state(state: CharacterState):
	if state != null:
		state.grant_lava_flight_opportunity()

func notify_protection_granted(player: Dictionary):
	var state := _game.character_state_by_id(int(player.get("id", -1))) as CharacterState
	if state != null:
		notify_state(state)
	elif bool(player.get("ai", false)):
		player["lava_flight_available"] = true
		player["lava_flight_target"] = INVALID_CELL

func choose_action(player_index: int, danger_cells: Dictionary, roll_override: Variant = null) -> Dictionary:
	var inactive := {"active": false, "waiting": false, "direction": Vector2i.ZERO, "target": INVALID_CELL}
	var state := _game.character_state_at(player_index) as CharacterState
	if state == null:
		return inactive
	var player := state.data
	if state.protection_time_left() <= 0.0:
		_cancel_state(state, true)
		return inactive
	if state.is_airborne():
		_cancel_state(state, false)
		return inactive

	var target := state.lava_flight_target()
	if target == INVALID_CELL:
		if not state.has_lava_flight_opportunity():
			return inactive
		state.consume_lava_flight_opportunity()
		var roll := randf() if roll_override == null else float(roll_override)
		if not should_activate(player, roll):
			return inactive
		target = _find_reachable_lava_target(state, danger_cells)
		if target == INVALID_CELL:
			return inactive
		state.set_lava_flight_target(target)

	if not _game.map_state.is_lava(target):
		_cancel_state(state, false)
		return inactive
	if state.cell() == target:
		var eruption_remaining := maxf(Constants.LAVA_ERUPTION_TIME - state.lava_eruption_time(), 0.0)
		if eruption_remaining + SAFETY_MARGIN > state.protection_time_left():
			_cancel_state(state, true)
			return inactive
		state.set_status("Lava launch %.1fs" % maxf(Constants.LAVA_ERUPTION_TIME - state.lava_eruption_time(), 0.0))
		return {"active": true, "waiting": true, "direction": Vector2i.ZERO, "target": target}

	var path := _path_to_lava(state, target, danger_cells)
	if path.is_empty():
		_cancel_state(state, false)
		return inactive
	if not _protection_lasts_for_path(state, path):
		_cancel_state(state, true)
		return inactive
	state.set_status("Seeking lava lift")
	return {
		"active": true,
		"waiting": false,
		"direction": path[0] - state.cell(),
		"target": target,
	}

func should_activate(player: Dictionary, roll: float) -> bool:
	return roll < activation_probability(player)

func activation_probability(player: Dictionary) -> float:
	match str(player.get("ai_difficulty", "normal")):
		"easy":
			return 0.16
		"hard":
			return 0.58
	return 0.34

func cancel(player: Dictionary, consume_opportunity := false):
	var state := _game.character_state_by_id(int(player.get("id", -1))) as CharacterState
	if state != null:
		_cancel_state(state, consume_opportunity)
	else:
		player["lava_flight_target"] = INVALID_CELL
		if consume_opportunity:
			player["lava_flight_available"] = false

func _cancel_state(state: CharacterState, consume_opportunity := false):
	state.cancel_lava_flight(consume_opportunity)

func _find_reachable_lava_target(state: CharacterState, danger_cells: Dictionary) -> Vector2i:
	var best_target := INVALID_CELL
	var best_length := 999999
	var start := state.cell()
	for y in range(1, Constants.GRID_H - 1):
		for x in range(1, Constants.GRID_W - 1):
			var candidate := Vector2i(x, y)
			if not _game.map_state.is_lava(candidate) or danger_cells.has(candidate):
				continue
			if _is_occupied_by_other(candidate, state):
				continue
			var path := _path_to_lava(state, candidate, danger_cells)
			var path_length := 0 if candidate == start else path.size()
			if candidate != start and path.is_empty():
				continue
			if not _protection_lasts_for_path(state, path):
				continue
			if path_length < best_length:
				best_length = path_length
				best_target = candidate
	return best_target

func _path_to_lava(state: CharacterState, target: Vector2i, danger_cells: Dictionary) -> Array[Vector2i]:
	var start := state.cell()
	if start == target:
		return []
	var walkable: Dictionary = {}
	for y in range(Constants.GRID_H):
		for x in range(Constants.GRID_W):
			var cell := Vector2i(x, y)
			if cell != target and not _game.map_state.is_walkable(cell):
				continue
			if cell != target and _game.map_state.is_lava(cell):
				continue
			if _game.bomb_map.has(cell) or _game.oil_barrels.has(cell) or danger_cells.has(cell):
				continue
			if _is_occupied_by_other(cell, state):
				continue
			walkable[cell] = true
	walkable[start] = true
	return AI_PATHFINDER.find_path(start, target, walkable)

func _protection_lasts_for_path(state: CharacterState, path: Array[Vector2i]) -> bool:
	var travel_time := 0.0
	var base_duration := Constants.move_duration_for_speed(state.speed_value())
	for cell in path:
		var cell_duration := base_duration
		if _game.weather_manager:
			cell_duration *= _game.weather_manager.movement_duration_multiplier(cell)
		cell_duration *= state.movement_duration_multiplier()
		travel_time += cell_duration
	return travel_time + Constants.LAVA_ERUPTION_TIME + SAFETY_MARGIN <= state.protection_time_left()

func _is_occupied_by_other(cell: Vector2i, state: CharacterState) -> bool:
	for other_state in _game.character_registry.states():
		if other_state != state and other_state.is_alive() and other_state.cell() == cell:
			return true
	return false
