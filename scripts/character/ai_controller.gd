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
	lava_flight_strategy.notify_state(_game.character_registry.state_at(player_index))

func on_wings_granted(player_index: int):
	lava_flight_strategy.notify_state(_game.character_registry.state_at(player_index))

func process_ai(delta: float):
	for i in range(_game.character_registry.count()):
		var state := _game.character_registry.state_at(i) as CharacterState
		if state == null or not state.can_process_ai():
			continue
		var human_state := _game.character_registry.state_at(0) as CharacterState
		if state.is_minion() and human_state != null:
			if Constants.grid_distance(state.cell(), human_state.cell()) <= 1:
				boss_behavior.explode_clone_minion(i)
				continue
		if state.boss_id() != "":
			boss_behavior.process_skill(i, delta)

		_update_ai_target_memory(state)
		state.advance_ai_clocks(delta)
		if state.is_moving():
			continue

		var danger_escape := _ai_escape_dir_from_active_bombs(i)
		if danger_escape != Vector2i.ZERO:
			state.set_move_direction(danger_escape)
			if _game.movement_controller.try_move(i, danger_escape):
				state.reset_ai_move_timer()
				continue
			state.set_move_direction(Vector2i.ZERO)

		var lava_action: Dictionary = lava_flight_strategy.choose_action(i, _game.bomb_manager.active_blast_cell_set())
		if bool(lava_action["active"]):
			state.set_move_direction(lava_action["direction"])
			state.reset_ai_move_timer()
			if not bool(lava_action["waiting"]):
				_game.movement_controller.try_move(i, state.move_direction())
			continue

		if not state.is_airborne() and state.is_ai_bomb_ready() and _ai_should_place_bomb(i):
			state.reset_ai_bomb_timer()
			var escape_dir := _ai_escape_dir_after_bomb(i)
			if escape_dir != Vector2i.ZERO:
				_game.bomb_manager.try_place_bomb(i)
				state.set_last_bomb_cell(state.cell())
				state.set_move_direction(escape_dir)
				if _game.movement_controller.try_move(i, escape_dir):
					state.reset_ai_move_timer()
					continue

		if not state.is_ai_move_ready():
			continue
		state.reset_ai_move_timer()
		state.set_move_direction(_choose_ai_direction(state))
		if state.move_direction() != Vector2i.ZERO and not _game.movement_controller.try_move(i, state.move_direction()):
			state.set_move_direction(Vector2i.ZERO)
			state.reset_ai_move_timer(0.75)

func _update_ai_target_memory(state: CharacterState):
	if state.ai_difficulty() != "hard" or _game.character_registry.is_empty():
		return
	var target := _game.character_registry.state_at(0) as CharacterState
	if target == null or not target.is_alive() or (_game.weather_manager and not _game.weather_manager.can_see(state.cell(), target.cell())):
		return
	state.remember_target(target.cell())

func _ai_should_place_bomb(player_index: int) -> bool:
	var state := _game.character_registry.state_at(player_index) as CharacterState
	if state == null:
		return false
	var difficulty := state.ai_difficulty()
	var blast_cells: Dictionary = _game.bomb_manager.blast_cell_set(state.cell(), state.bomb_range())
	var human_state := _game.character_registry.state_at(0) as CharacterState
	if difficulty == "hard" and human_state != null and human_state.is_hidden_in(_game.map_state) and _is_target_in_ground_attack_layer(human_state.data) and blast_cells.has(human_state.cell()):
		return true
	for i: int in range(_game.character_registry.count()):
		if i == player_index:
			continue
		var target_state := _game.character_registry.state_at(i) as CharacterState
		if target_state != null and target_state.is_alive() and _is_target_in_ground_attack_layer(target_state.data) and not target_state.is_hidden_in(_game.map_state) and blast_cells.has(target_state.cell()):
			return true

	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for d in dirs:
		var check: Vector2i = state.cell() + d
		if _game.map_state.is_crate(check):
			return true
	var can_breach_toward_player: bool = (
		human_state != null
		and human_state.is_alive()
		and (difficulty == "hard" or not human_state.is_hidden_in(_game.map_state))
	)
	if difficulty in ["normal", "hard"] and can_breach_toward_player:
		var player_cell := human_state.cell()
		var current_distance := Constants.grid_distance(state.cell(), player_cell)
		for cell in blast_cells.keys():
			var c := cell as Vector2i
			if _game.map_state.is_crate(c) and Constants.grid_distance(c, player_cell) < current_distance:
				return true
	return false

func _is_target_in_ground_attack_layer(target: Dictionary) -> bool:
	return Constants.is_player_in_attack_height(target, Constants.GROUND_ATTACK_MIN_HEIGHT, Constants.GROUND_ATTACK_MAX_HEIGHT)

func _choose_ai_direction(state: CharacterState) -> Vector2i:
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	dirs.shuffle()
	var danger_cells: Dictionary = _game.bomb_manager.active_blast_cell_set()
	var walkable_cells: Dictionary = _ai_navigation_cells(state, danger_cells)
	var difficulty := state.ai_difficulty()
	var human_state := _game.character_registry.state_at(0) as CharacterState
	var can_target_player: bool = (
		human_state != null
		and human_state.is_alive()
		and (difficulty == "hard" or not human_state.is_hidden_in(_game.map_state))
		and (not _game.weather_manager or _game.weather_manager.can_see(state.cell(), human_state.cell()))
	)
	var player_cell := Vector2i(-1, -1)
	if can_target_player:
		player_cell = human_state.cell()
		if Constants.grid_distance(state.cell(), player_cell) <= 1:
			return Vector2i.ZERO
	var strategic_direction: Vector2i = AIDecisionPolicy.choose_direction(
		state.query(),
		_game.powerups,
		walkable_cells,
		player_cell,
		can_target_player
	)
	if strategic_direction != Vector2i.ZERO:
		return strategic_direction
	var last_bomb := state.last_bomb_cell()
	if last_bomb != Vector2i(-1, -1):
		var away := _filter_away(dirs, state.cell(), last_bomb)
		if not away.is_empty():
			dirs = away

	for d in dirs:
		var target: Vector2i = state.cell() + d
		if _game.is_cell_walkable(target.x, target.y) and not danger_cells.has(target) and not _game.map_state.is_lava(target):
			return d
	for d in dirs:
		var target: Vector2i = state.cell() + d
		if _game.is_cell_walkable(target.x, target.y) and not danger_cells.has(target):
			return d
	return Vector2i.ZERO

func _ai_navigation_cells(state: CharacterState, danger_cells: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var start := state.cell()
	var occupied: Dictionary = {}
	for other_state in _game.character_registry.states():
		if other_state.is_alive() and other_state.cell() != start:
			occupied[other_state.cell()] = true
	for y: int in range(Constants.GRID_H):
		for x: int in range(Constants.GRID_W):
			var cell := Vector2i(x, y)
			if not _game.map_state.is_walkable(cell):
				continue
			if _game.bomb_map.has(cell) or _game.oil_barrels.has(cell) or occupied.has(cell):
				continue
			if danger_cells.has(cell) or _game.map_state.is_lava(cell):
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
	var state := _game.character_state_at(player_index) as CharacterState
	if state == null:
		return Vector2i.ZERO
	var bomb_cell := state.cell()
	var blast_cells: Dictionary = _game.bomb_manager.blast_cell_set(bomb_cell, state.bomb_range())
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
	var state := _game.character_state_at(player_index) as CharacterState
	if state == null:
		return Vector2i.ZERO
	var start := state.cell()
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
	if not _game.map_state.is_walkable(cell):
		return false
	if simulated_bomb and cell == bomb_cell:
		return false
	if _game.bomb_map.has(cell):
		return false
	if _game.oil_barrels.has(cell):
		return false
	return true
