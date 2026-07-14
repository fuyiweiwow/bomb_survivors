extends Node

const AI_PATHFINDER := preload("res://scripts/character/ai_pathfinder.gd")
const INVALID_CELL := Vector2i(-1, -1)
const SAFETY_MARGIN := 0.20

var _game: Node

func setup(game_manager: Node):
	_game = game_manager

func notify_protection_granted(player: Dictionary):
	if not bool(player.get("ai", false)):
		return
	player["lava_flight_available"] = true
	player["lava_flight_target"] = INVALID_CELL

func choose_action(player_index: int, danger_cells: Dictionary, roll_override: Variant = null) -> Dictionary:
	var inactive := {"active": false, "waiting": false, "direction": Vector2i.ZERO, "target": INVALID_CELL}
	if player_index < 0 or player_index >= _game.players.size():
		return inactive
	var player: Dictionary = _game.players[player_index]
	if _protection_time_left(player) <= 0.0:
		cancel(player, true)
		return inactive
	if bool(player.get("airborne", false)):
		cancel(player, false)
		return inactive

	var target := player.get("lava_flight_target", INVALID_CELL) as Vector2i
	if target == INVALID_CELL:
		if not bool(player.get("lava_flight_available", false)):
			return inactive
		player["lava_flight_available"] = false
		var roll := randf() if roll_override == null else float(roll_override)
		if not should_activate(player, roll):
			return inactive
		target = _find_reachable_lava_target(player, danger_cells)
		if target == INVALID_CELL:
			return inactive
		player["lava_flight_target"] = target

	if not _game.map_state.is_lava(target):
		cancel(player, false)
		return inactive
	if player["grid_pos"] == target:
		var eruption_remaining := maxf(Constants.LAVA_ERUPTION_TIME - float(player.get("lava_eruption_time", 0.0)), 0.0)
		if eruption_remaining + SAFETY_MARGIN > _protection_time_left(player):
			cancel(player, true)
			return inactive
		player["status"] = "Lava launch %.1fs" % maxf(Constants.LAVA_ERUPTION_TIME - float(player.get("lava_eruption_time", 0.0)), 0.0)
		return {"active": true, "waiting": true, "direction": Vector2i.ZERO, "target": target}

	var path := _path_to_lava(player, target, danger_cells)
	if path.is_empty():
		cancel(player, false)
		return inactive
	if not _protection_lasts_for_path(player, path):
		cancel(player, true)
		return inactive
	player["status"] = "Seeking lava lift"
	return {
		"active": true,
		"waiting": false,
		"direction": path[0] - (player["grid_pos"] as Vector2i),
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
	player["lava_flight_target"] = INVALID_CELL
	if consume_opportunity:
		player["lava_flight_available"] = false

func _find_reachable_lava_target(player: Dictionary, danger_cells: Dictionary) -> Vector2i:
	var best_target := INVALID_CELL
	var best_length := 999999
	var start: Vector2i = player["grid_pos"]
	for y in range(1, Constants.GRID_H - 1):
		for x in range(1, Constants.GRID_W - 1):
			var candidate := Vector2i(x, y)
			if not _game.map_state.is_lava(candidate) or danger_cells.has(candidate):
				continue
			if _is_occupied_by_other(candidate, player):
				continue
			var path := _path_to_lava(player, candidate, danger_cells)
			var path_length := 0 if candidate == start else path.size()
			if candidate != start and path.is_empty():
				continue
			if not _protection_lasts_for_path(player, path):
				continue
			if path_length < best_length:
				best_length = path_length
				best_target = candidate
	return best_target

func _path_to_lava(player: Dictionary, target: Vector2i, danger_cells: Dictionary) -> Array[Vector2i]:
	var start: Vector2i = player["grid_pos"]
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
			if _is_occupied_by_other(cell, player):
				continue
			walkable[cell] = true
	walkable[start] = true
	return AI_PATHFINDER.find_path(start, target, walkable)

func _protection_lasts_for_path(player: Dictionary, path: Array[Vector2i]) -> bool:
	var travel_time := 0.0
	var base_duration := Constants.move_duration_for_speed(int(player.get("speed", 5)))
	for cell in path:
		var cell_duration := base_duration
		if _game.weather_manager:
			cell_duration *= _game.weather_manager.movement_duration_multiplier(cell)
		if float(player.get("slow_timer", 0.0)) > 0.0:
			cell_duration *= 3.33
		travel_time += cell_duration
	return travel_time + Constants.LAVA_ERUPTION_TIME + SAFETY_MARGIN <= _protection_time_left(player)

func _protection_time_left(player: Dictionary) -> float:
	var shield_time := float(player.get("shield_timer", 0.0)) if int(player.get("shield", 0)) > 0 else 0.0
	return maxf(shield_time, float(player.get("wings_timer", 0.0)))

func _is_occupied_by_other(cell: Vector2i, player: Dictionary) -> bool:
	for other: Dictionary in _game.players:
		if other != player and other["alive"] and other["grid_pos"] == cell:
			return true
	return false
