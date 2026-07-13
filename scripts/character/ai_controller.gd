extends Node

const LAVA_FLIGHT_STRATEGY := preload("res://scripts/character/ai_lava_flight_strategy.gd")
const BOSS_BEHAVIOR_CONTROLLER := preload("res://scripts/character/boss_behavior_controller.gd")

var _game: Node
var lava_flight_strategy: Node
var boss_behavior: Node

func setup(game_manager: Node):
	_game = game_manager
	lava_flight_strategy = LAVA_FLIGHT_STRATEGY.new()
	add_child(lava_flight_strategy)
	lava_flight_strategy.setup(_game)
	boss_behavior = BOSS_BEHAVIOR_CONTROLLER.new()
	add_child(boss_behavior)
	boss_behavior.setup(_game)

func on_shield_granted(player_index: int):
	if player_index < 0 or player_index >= _game.players.size():
		return
	lava_flight_strategy.notify_shield_granted(_game.players[player_index])

func process_ai(delta: float):
	for i in range(_game.players.size()):
		var p: Dictionary = _game.players[i]
		if not p["ai"] or not p["alive"] or bool(p.get("downed", false)):
			continue
		if float(p.get("frozen_timer", 0.0)) > 0.0:
			continue
		if bool(p.get("is_minion", false)) and not _game.players.is_empty():
			if Constants.grid_distance(p["grid_pos"], _game.players[0]["grid_pos"]) <= 1:
				boss_behavior.explode_clone_minion(i)
				continue
		if str(p.get("boss_id", "")) != "":
			boss_behavior.process_skill(i, delta)

		_update_ai_target_memory(p)
		p["move_timer"] += delta
		p["bomb_timer"] += delta
		if p["is_moving"]:
			continue

		var danger_escape := _ai_escape_dir_from_active_bombs(i)
		if danger_escape != Vector2i.ZERO:
			p["move_dir"] = danger_escape
			if _game.movement_controller.try_move(i, danger_escape):
				p["move_timer"] = 0.0
				continue
			p["move_dir"] = Vector2i.ZERO

		var lava_action: Dictionary = lava_flight_strategy.choose_action(i, _game.bomb_manager.active_blast_cell_set())
		if bool(lava_action["active"]):
			p["move_dir"] = lava_action["direction"]
			p["move_timer"] = 0.0
			if not bool(lava_action["waiting"]):
				_game.movement_controller.try_move(i, p["move_dir"])
			continue

		if not bool(p.get("airborne", false)) and p["bomb_timer"] >= p["bomb_interval"] and p["bomb_placed_count"] < p["bomb_max"] and _ai_should_place_bomb(i):
			p["bomb_timer"] = 0.0
			var escape_dir := _ai_escape_dir_after_bomb(i)
			if escape_dir != Vector2i.ZERO:
				_game.bomb_manager.try_place_bomb(i)
				p["last_bomb_pos"] = p["grid_pos"]
				p["move_dir"] = escape_dir
				if _game.movement_controller.try_move(i, escape_dir):
					p["move_timer"] = 0.0
					continue

		if p["move_timer"] < p["move_interval"]:
			continue
		p["move_timer"] = 0.0
		p["move_dir"] = _choose_ai_direction(p)
		if p["move_dir"] != Vector2i.ZERO and not _game.movement_controller.try_move(i, p["move_dir"]):
			p["move_dir"] = Vector2i.ZERO
			p["move_timer"] = float(p["move_interval"]) * 0.75

func _update_ai_target_memory(p: Dictionary):
	if str(p.get("ai_difficulty", "normal")) != "hard" or _game.players.is_empty():
		return
	var target: Dictionary = _game.players[0]
	if not target["alive"] or (_game.weather_manager and not _game.weather_manager.can_see(p["grid_pos"], target["grid_pos"])):
		return
	p["last_seen_player_pos"] = target["grid_pos"]

func _ai_should_place_bomb(player_index: int) -> bool:
	var p: Dictionary = _game.players[player_index]
	var difficulty := str(p.get("ai_difficulty", "normal"))
	var blast_cells: Dictionary = _game.bomb_manager.blast_cell_set(p["grid_pos"], p["bomb_range"])
	if difficulty == "hard" and Constants.is_player_hidden(_game.players, 0, _game.grid) and _is_target_in_ground_attack_layer(_game.players[0]) and blast_cells.has(_game.players[0]["grid_pos"]):
		return true
	for i: int in range(_game.players.size()):
		if i == player_index:
			continue
		var target: Dictionary = _game.players[i]
		if target["alive"] and _is_target_in_ground_attack_layer(target) and not Constants.is_player_hidden(_game.players, i, _game.grid) and blast_cells.has(target["grid_pos"]):
			return true

	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for d in dirs:
		var check: Vector2i = p["grid_pos"] + d
		if check.x >= 0 and check.x < Constants.GRID_W and check.y >= 0 and check.y < Constants.GRID_H and _game.grid[check.y][check.x] == Constants.Cell.CRATE:
			return true
	var can_breach_toward_player: bool = (
		not _game.players.is_empty()
		and _game.players[0]["alive"]
		and (difficulty == "hard" or not Constants.is_player_hidden(_game.players, 0, _game.grid))
	)
	if difficulty in ["normal", "hard"] and can_breach_toward_player:
		var player_cell: Vector2i = _game.players[0]["grid_pos"]
		var current_distance := Constants.grid_distance(p["grid_pos"], player_cell)
		for cell in blast_cells.keys():
			var c := cell as Vector2i
			if _game.grid[c.y][c.x] == Constants.Cell.CRATE and Constants.grid_distance(c, player_cell) < current_distance:
				return true
	return false

func _is_target_in_ground_attack_layer(target: Dictionary) -> bool:
	return Constants.is_player_in_attack_height(target, Constants.GROUND_ATTACK_MIN_HEIGHT, Constants.GROUND_ATTACK_MAX_HEIGHT)

func _choose_ai_direction(p: Dictionary) -> Vector2i:
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	dirs.shuffle()
	var danger_cells: Dictionary = _game.bomb_manager.active_blast_cell_set()
	var walkable_cells: Dictionary = _ai_navigation_cells(p, danger_cells)
	var difficulty: String = str(p.get("ai_difficulty", "normal"))
	var can_target_player: bool = (
		not _game.players.is_empty()
		and _game.players[0]["alive"]
		and (difficulty == "hard" or not Constants.is_player_hidden(_game.players, 0, _game.grid))
		and (not _game.weather_manager or _game.weather_manager.can_see(p["grid_pos"], _game.players[0]["grid_pos"]))
	)
	var player_cell := Vector2i(-1, -1)
	if can_target_player:
		player_cell = _game.players[0]["grid_pos"]
		if Constants.grid_distance(p["grid_pos"], player_cell) <= 1:
			return Vector2i.ZERO
	var strategic_direction: Vector2i = AIDecisionPolicy.choose_direction(
		p,
		_game.powerups,
		walkable_cells,
		player_cell,
		can_target_player
	)
	if strategic_direction != Vector2i.ZERO:
		return strategic_direction
	var last_bomb: Vector2i = p["last_bomb_pos"]
	if last_bomb != Vector2i(-1, -1):
		var away := _filter_away(dirs, p["grid_pos"], last_bomb)
		if not away.is_empty():
			dirs = away

	for d in dirs:
		var target: Vector2i = p["grid_pos"] + d
		if _game.is_cell_walkable(target.x, target.y) and not danger_cells.has(target) and not Constants.is_lava_cell(_game.grid, target):
			return d
	for d in dirs:
		var target: Vector2i = p["grid_pos"] + d
		if _game.is_cell_walkable(target.x, target.y) and not danger_cells.has(target):
			return d
	return Vector2i.ZERO

func _ai_navigation_cells(p: Dictionary, danger_cells: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var start: Vector2i = p["grid_pos"]
	var occupied: Dictionary = {}
	for other: Dictionary in _game.players:
		if other["alive"] and other["grid_pos"] != start:
			occupied[other["grid_pos"]] = true
	for y: int in range(Constants.GRID_H):
		for x: int in range(Constants.GRID_W):
			var cell := Vector2i(x, y)
			if not Constants.is_walkable_cell(_game.grid[y][x]):
				continue
			if _game.bomb_map.has(cell) or _game.oil_barrels.has(cell) or occupied.has(cell):
				continue
			if danger_cells.has(cell) or Constants.is_lava_cell(_game.grid, cell):
				continue
			result[cell] = true
	result[start] = true
	return result

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

func _ai_escape_dir_after_bomb(player_index: int) -> Vector2i:
	var p: Dictionary = _game.players[player_index]
	var bomb_cell: Vector2i = p["grid_pos"]
	var blast_cells: Dictionary = _game.bomb_manager.blast_cell_set(bomb_cell, p["bomb_range"])
	var queue: Array = [{"pos": bomb_cell, "first": Vector2i.ZERO}]
	var visited := {bomb_cell: true}
	var head := 0
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	dirs.shuffle()

	while head < queue.size():
		var item: Dictionary = queue[head]
		head += 1
		var pos: Vector2i = item["pos"]
		var first_step: Vector2i = item["first"]

		if first_step != Vector2i.ZERO and not blast_cells.has(pos):
			return first_step

		for d in dirs:
			var next: Vector2i = pos + d
			if visited.has(next):
				continue
			if not _is_ai_escape_walkable(next, bomb_cell, player_index, true):
				continue
			visited[next] = true
			queue.append({
				"pos": next,
				"first": d if first_step == Vector2i.ZERO else first_step
			})

	return Vector2i.ZERO

func _ai_escape_dir_from_active_bombs(player_index: int) -> Vector2i:
	var p: Dictionary = _game.players[player_index]
	var start: Vector2i = p["grid_pos"]
	var danger_cells: Dictionary = _game.bomb_manager.active_blast_cell_set()
	if not danger_cells.has(start):
		return Vector2i.ZERO

	var queue: Array = [{"pos": start, "first": Vector2i.ZERO}]
	var visited := {start: true}
	var head := 0
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	dirs.shuffle()

	while head < queue.size():
		var item: Dictionary = queue[head]
		head += 1
		var pos: Vector2i = item["pos"]
		var first_step: Vector2i = item["first"]

		if first_step != Vector2i.ZERO and not danger_cells.has(pos):
			return first_step

		for d in dirs:
			var next: Vector2i = pos + d
			if visited.has(next):
				continue
			if not _is_ai_escape_walkable(next, Vector2i(-999, -999), player_index, false):
				continue
			visited[next] = true
			queue.append({
				"pos": next,
				"first": d if first_step == Vector2i.ZERO else first_step
			})

	return Vector2i.ZERO

func _is_ai_escape_walkable(cell: Vector2i, bomb_cell: Vector2i, player_index: int, simulated_bomb := false) -> bool:
	if cell.x < 0 or cell.x >= Constants.GRID_W or cell.y < 0 or cell.y >= Constants.GRID_H:
		return false
	if not Constants.is_walkable_cell(_game.grid[cell.y][cell.x]):
		return false
	if simulated_bomb and cell == bomb_cell:
		return false
	if _game.bomb_map.has(cell):
		return false
	if _game.oil_barrels.has(cell):
		return false
	return true
