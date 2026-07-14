extends Node

const CELL_EMPTY := Constants.Cell.EMPTY
const CELL_WALL := Constants.Cell.WALL
const CELL_CRATE := Constants.Cell.CRATE
const WALL_WARNING_TIME := 2.0
const WALL_DESTROY_TIME := 4.0
const WALL_RESTORE_TIME := 8.0

var game: Node

func setup(game_manager: Node):
	game = game_manager

func process(delta: float):
	for player_index in range(game.character_registry.count()):
		var state := game.character_state_at(player_index) as CharacterState
		if state == null or not state.is_alive():
			continue
		var cell := state.elevation.support_cell()
		if not state.elevation.is_elevated():
			continue
		if state.elevation.is_impact_support():
			_process_impact_support(player_index, state, cell, delta)
			continue
		if game.map_state.is_crate(cell):
			continue
		if not game.map_state.is_wall(cell):
			_drop_player_from_block(state)
			continue
		var wall_time := state.elevation.advance_wall_stay(delta)
		if wall_time >= WALL_WARNING_TIME and not state.elevation.has_wall_warning():
			state.elevation.set_wall_warning(true)
			state.set_status("Wall unstable")
			_set_wall_warning(cell, true)
		if wall_time >= WALL_DESTROY_TIME:
			_destroy_wall(cell)
			_drop_player_from_block(state)

	for raw_cell in game.grid_manager.destroyed_walls.keys():
		var cell := raw_cell as Vector2i
		game.grid_manager.destroyed_walls[cell] = float(game.grid_manager.destroyed_walls[cell]) + delta
		if float(game.grid_manager.destroyed_walls[cell]) < WALL_RESTORE_TIME:
			continue
		if game.bomb_map.has(cell) or is_cell_occupied(cell):
			continue
		game.map_state.set_cell(cell, CELL_WALL)
		var wall = game.grid_manager.wall_nodes.get(cell)
		if is_instance_valid(wall):
			wall.visible = true
			wall.transparency = 0.0
		game.grid_manager.destroyed_walls.erase(cell)

func start_fall_support(player_index: int, cell: Vector2i):
	var state := game.character_state_at(player_index) as CharacterState
	if state == null:
		return
	_clear_crack_visual(state)
	state.elevation.begin_support(cell, true, _create_crack_visual(cell))
	state.set_status("Support cracking 1.0s")

func leave_elevated_cell(character: Variant):
	var state := _state_for(character)
	if state == null:
		return
	if state.elevation.is_impact_support():
		_reset_impact_support_visual(state.elevation.support_cell())
		_clear_crack_visual(state)
	clear_wall_warning(state)
	state.elevation.leave_support()

func _process_impact_support(player_index: int, state: CharacterState, cell: Vector2i, delta: float):
	if not game.map_state.is_in_bounds(cell) or game.map_state.cell_at(cell) not in [CELL_WALL, CELL_CRATE]:
		leave_elevated_cell(state)
		game.airborne_controller.begin_fall(player_index)
		return
	var support_time := state.elevation.advance_impact_support(delta)
	var progress := clampf(support_time / Constants.IMPACT_SUPPORT_BREAK_TIME, 0.0, 1.0)
	state.set_status("Support cracking %.1fs" % maxf(Constants.IMPACT_SUPPORT_BREAK_TIME - support_time, 0.0))
	_update_impact_support_visual(state, cell, progress)
	if support_time >= Constants.IMPACT_SUPPORT_BREAK_TIME:
		_break_impact_support(player_index, state, cell)

func _break_impact_support(player_index: int, state: CharacterState, cell: Vector2i):
	var cell_type: int = game.map_state.cell_at(cell)
	_reset_impact_support_visual(cell)
	_clear_crack_visual(state)
	state.elevation.leave_support()
	_spawn_break_fragments(cell, cell_type)
	if cell_type == CELL_CRATE:
		game.grid_manager.destroy_crate(cell)
		game.powerup_manager.spawn_powerup(cell)
	elif cell_type == CELL_WALL:
		_destroy_wall(cell)
	game.airborne_controller.begin_fall(player_index, -0.55)

func _update_impact_support_visual(state: CharacterState, cell: Vector2i, progress: float):
	var support = _support_node(cell)
	if is_instance_valid(support):
		var base_position := Constants.grid_to_world(cell) + Vector3(0, 0.62 if game.map_state.is_wall(cell) else 0.46, 0)
		var shake := sin(state.elevation.impact_support_time() * 52.0) * 0.045 * progress
		(support as Node3D).position = base_position + Vector3(shake, -0.08 * progress, -shake * 0.6)
		(support as Node3D).scale = Vector3(1.0 + 0.05 * progress, 1.0 - 0.24 * progress, 1.0 + 0.05 * progress)
	var cracks := state.elevation.crack_visual()
	if cracks != null:
		cracks.scale = Vector3.ONE * lerpf(0.25, 1.15, progress)

func _reset_impact_support_visual(cell: Vector2i):
	if not _is_in_bounds(cell):
		return
	var support = _support_node(cell)
	if not is_instance_valid(support):
		return
	var support_height := 0.62 if game.grid_manager.wall_nodes.has(cell) else 0.46
	(support as Node3D).position = Constants.grid_to_world(cell) + Vector3(0, support_height, 0)
	(support as Node3D).scale = Vector3.ONE

func _support_node(cell: Vector2i):
	if game.grid_manager.crate_nodes.has(cell):
		return game.grid_manager.crate_nodes[cell]
	if game.grid_manager.wall_nodes.has(cell):
		return game.grid_manager.wall_nodes[cell]
	return null

func _create_crack_visual(cell: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "SupportCracks_%d_%d" % [cell.x, cell.y]
	var support_height := Constants.WALL_SUPPORT_HEIGHT if game.map_state.is_wall(cell) else Constants.CRATE_SUPPORT_HEIGHT
	root.position = Constants.grid_to_world(cell) + Vector3(0, support_height + 0.025, 0)
	root.scale = Vector3.ONE * 0.25
	var crack_mat := MeshHelpers.make_mat(Color(1.0, 0.10, 0.025), true)
	for crack_data in [
		[Vector3(0.0, 0.0, 0.0), 0.35],
		[Vector3(0.22, 0.005, 0.10), -0.55],
		[Vector3(-0.24, 0.01, -0.12), 1.05],
		[Vector3(0.05, 0.015, -0.26), 1.55],
		[Vector3(-0.08, 0.02, 0.27), -1.25],
	]:
		var crack := MeshHelpers.box(Vector3(1.08, 0.045, 0.085), crack_mat)
		crack.position = crack_data[0]
		crack.rotation.y = float(crack_data[1])
		root.add_child(crack)
	game.add_child(root)
	return root

func _clear_crack_visual(state: CharacterState):
	var cracks := state.elevation.clear_crack_visual()
	if cracks != null:
		cracks.queue_free()

func _spawn_break_fragments(cell: Vector2i, cell_type: int):
	var fragment_mat: Material = game.art.mat_wall if cell_type == CELL_WALL else game.art.mat_crate
	var origin := Constants.grid_to_world(cell) + Vector3(0, 0.75, 0)
	for fragment_index in range(9):
		var fragment := MeshHelpers.box(Vector3(0.28, 0.24, 0.28), fragment_mat)
		fragment.name = "SupportBreakFragment_%d_%d_%d" % [cell.x, cell.y, fragment_index]
		var angle := TAU * float(fragment_index) / 9.0
		fragment.position = origin + Vector3(cos(angle) * 0.24, float(fragment_index % 3) * 0.12, sin(angle) * 0.24)
		game.add_child(fragment)
		var destination := fragment.position + Vector3(cos(angle) * 0.95, randf_range(-0.35, 0.18), sin(angle) * 0.95)
		var tween := game.create_tween().bind_node(fragment).set_parallel()
		tween.tween_property(fragment, "position", destination, 0.46).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(fragment, "rotation", Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)), 0.46)
		tween.tween_property(fragment, "transparency", 1.0, 0.24).set_delay(0.28)
		tween.set_parallel(false)
		tween.tween_callback(fragment.queue_free)

func try_bomb_boost(player_index: int) -> bool:
	var state := game.character_state_at(player_index) as CharacterState
	if state == null:
		return false
	var player := state.data
	if state.is_downed() or state.elevation.is_elevated():
		return false
	var covering_bombs := 1
	for raw_cell in game.bomb_map.keys():
		var bomb_cell := raw_cell as Vector2i
		var entry: Dictionary = game.bomb_map[bomb_cell]
		if int(entry.get("player_index", -1)) == player_index and game.bomb_manager.blast_cell_set(bomb_cell, int(entry["range"])).has(state.cell()):
			covering_bombs += 1
	if covering_bombs < 2:
		return false

	var directions := [player["last_move_dir"] as Vector2i, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var target := Vector2i(-1, -1)
	for direction in directions:
		var candidate: Vector2i = state.cell() + direction
		if not game.map_state.is_in_bounds(candidate):
			continue
		if game.map_state.cell_at(candidate) not in [CELL_WALL, CELL_CRATE] or is_cell_occupied(candidate, state):
			continue
		target = candidate
		break
	if target == Vector2i(-1, -1):
		return false

	game.combat_manager.cancel_player_movement(player)
	state.set_cell(target)
	state.elevation.begin_support(target, false)
	state.set_status("Bomb Boost")
	var player_node := state.node()
	if player_node != null:
		var height := Constants.WALL_SUPPORT_HEIGHT if game.map_state.is_wall(target) else Constants.CRATE_SUPPORT_HEIGHT
		game.create_tween().bind_node(player_node).tween_property(player_node, "position", Constants.grid_to_world(target) + Vector3(0, height, 0), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return true

func try_wall_hop(player_index: int, direction: Vector2i) -> bool:
	var state := game.character_state_at(player_index) as CharacterState
	if state == null or direction == Vector2i.ZERO:
		return false
	var player := state.data
	if not state.bombs.is_hop_window_active(game.bomb_manager.game_time()):
		return false
	var hop_cells := state.bombs.hop_cells()
	if hop_cells.size() < 2:
		return false
	var active_hop_bombs := 0
	for raw_cell in hop_cells.keys():
		var bomb_cell := raw_cell as Vector2i
		if game.bomb_map.has(bomb_cell) and int((game.bomb_map[bomb_cell] as Dictionary).get("player_index", -1)) == player_index:
			active_hop_bombs += 1
	if active_hop_bombs < 2:
		return false
	var origin := state.cell()
	var wall_cell := origin + direction
	if not game.map_state.is_wall(wall_cell):
		return false
	var perpendicular := Vector2i(-direction.y, direction.x)
	var required_empty := [origin - perpendicular, origin, origin + perpendicular, wall_cell - perpendicular, wall_cell + perpendicular]
	for raw_cell in required_empty:
		var cell := raw_cell as Vector2i
		if not game.map_state.is_type(cell, CELL_EMPTY):
			return false
	for exit_cell in [wall_cell - perpendicular, wall_cell + perpendicular]:
		if game.bomb_map.has(exit_cell) or game.oil_barrels.has(exit_cell):
			return false

	state.begin_special_move(wall_cell, direction, "Wall Hop")
	var player_node := state.node()
	if player_node == null:
		state.complete_special_move()
		return false
	player_node.look_at(Constants.grid_to_world(wall_cell), Vector3.UP)
	var tween := game.create_tween().bind_node(player_node)
	state.set_move_tween(tween)
	tween.tween_property(player_node, "position", Constants.grid_to_world(wall_cell) + Vector3(0, 1.30, 0), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(state.complete_special_move)
	return true

func clear_wall_warning(character: Variant):
	var state := _state_for(character)
	if state == null or not state.elevation.has_wall_warning():
		return
	_set_wall_warning(state.elevation.support_cell(), false)
	state.elevation.set_wall_warning(false)

func is_cell_occupied(cell: Vector2i, ignored_character: Variant = null) -> bool:
	var ignored_state := _state_for(ignored_character)
	for state: CharacterState in game.character_registry.states():
		if state != ignored_state and state.is_alive() and state.cell() == cell:
			return true
	return false

func _destroy_wall(cell: Vector2i):
	game.map_state.set_cell(cell, CELL_EMPTY)
	game.grid_manager.destroyed_walls[cell] = 0.0
	game.audio_manager.play("wall_break")
	var wall = game.grid_manager.wall_nodes.get(cell)
	if is_instance_valid(wall):
		wall.transparency = 0.0
		wall.visible = false

func _drop_player_from_block(state: CharacterState):
	clear_wall_warning(state)
	state.elevation.leave_support()
	var player_node := state.node()
	if player_node != null:
		game.create_tween().bind_node(player_node).tween_property(player_node, "position", Constants.grid_to_world(state.cell()), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _set_wall_warning(cell: Vector2i, enabled: bool):
	var wall = game.grid_manager.wall_nodes.get(cell)
	if is_instance_valid(wall):
		wall.transparency = 0.45 if enabled else 0.0

func _is_in_bounds(cell: Vector2i) -> bool:
	return game.map_state.is_in_bounds(cell)

func _state_for(character: Variant) -> CharacterState:
	if character is CharacterState:
		return character as CharacterState
	if character is Dictionary:
		return game.character_state_by_id(int((character as Dictionary).get("id", -1)))
	return null
