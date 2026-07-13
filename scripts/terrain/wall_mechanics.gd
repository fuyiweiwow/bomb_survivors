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
	for player_index in range(game.players.size()):
		var player: Dictionary = game.players[player_index]
		if not player["alive"]:
			continue
		var cell := player["elevated_cell"] as Vector2i
		if cell == Vector2i(-1, -1):
			continue
		if bool(player.get("impact_support", false)):
			_process_impact_support(player_index, player, cell, delta)
			continue
		if game.grid[cell.y][cell.x] == CELL_CRATE:
			continue
		if game.grid[cell.y][cell.x] != CELL_WALL:
			_drop_player_from_block(player)
			continue
		player["wall_stay_timer"] = float(player["wall_stay_timer"]) + delta
		if float(player["wall_stay_timer"]) >= WALL_WARNING_TIME and not bool(player["wall_warning"]):
			player["wall_warning"] = true
			player["status"] = "Wall unstable"
			_set_wall_warning(cell, true)
		if float(player["wall_stay_timer"]) >= WALL_DESTROY_TIME:
			_destroy_wall(cell)
			_drop_player_from_block(player)

	for raw_cell in game.grid_manager.destroyed_walls.keys():
		var cell := raw_cell as Vector2i
		game.grid_manager.destroyed_walls[cell] = float(game.grid_manager.destroyed_walls[cell]) + delta
		if float(game.grid_manager.destroyed_walls[cell]) < WALL_RESTORE_TIME:
			continue
		if game.bomb_map.has(cell) or is_cell_occupied(cell):
			continue
		game.grid[cell.y][cell.x] = CELL_WALL
		var wall = game.grid_manager.wall_nodes.get(cell)
		if is_instance_valid(wall):
			wall.visible = true
			wall.transparency = 0.0
		game.grid_manager.destroyed_walls.erase(cell)

func start_fall_support(player_index: int, cell: Vector2i):
	if player_index < 0 or player_index >= game.players.size():
		return
	var player: Dictionary = game.players[player_index]
	_clear_crack_visual(player)
	player["elevated_cell"] = cell
	player["impact_support"] = true
	player["impact_support_timer"] = 0.0
	player["wall_stay_timer"] = 0.0
	player["wall_warning"] = false
	player["status"] = "Support cracking 1.0s"
	player["impact_support_cracks"] = _create_crack_visual(cell)

func leave_elevated_cell(player: Dictionary):
	if bool(player.get("impact_support", false)):
		_reset_impact_support_visual(player["elevated_cell"] as Vector2i)
		_clear_crack_visual(player)
	clear_wall_warning(player)
	player["elevated_cell"] = Vector2i(-1, -1)
	player["wall_stay_timer"] = 0.0
	player["impact_support"] = false
	player["impact_support_timer"] = 0.0

func _process_impact_support(player_index: int, player: Dictionary, cell: Vector2i, delta: float):
	if not _is_in_bounds(cell) or game.grid[cell.y][cell.x] not in [CELL_WALL, CELL_CRATE]:
		leave_elevated_cell(player)
		game.airborne_controller.begin_fall(player_index)
		return
	player["impact_support_timer"] = float(player.get("impact_support_timer", 0.0)) + delta
	var progress := clampf(float(player["impact_support_timer"]) / Constants.IMPACT_SUPPORT_BREAK_TIME, 0.0, 1.0)
	player["status"] = "Support cracking %.1fs" % maxf(Constants.IMPACT_SUPPORT_BREAK_TIME - float(player["impact_support_timer"]), 0.0)
	_update_impact_support_visual(player, cell, progress)
	if float(player["impact_support_timer"]) >= Constants.IMPACT_SUPPORT_BREAK_TIME:
		_break_impact_support(player_index, player, cell)

func _break_impact_support(player_index: int, player: Dictionary, cell: Vector2i):
	var cell_type: int = game.grid[cell.y][cell.x]
	_reset_impact_support_visual(cell)
	_clear_crack_visual(player)
	player["elevated_cell"] = Vector2i(-1, -1)
	player["impact_support"] = false
	player["impact_support_timer"] = 0.0
	player["wall_stay_timer"] = 0.0
	_spawn_break_fragments(cell, cell_type)
	if cell_type == CELL_CRATE:
		game.grid_manager.destroy_crate(cell)
		game.powerup_manager.spawn_powerup(cell)
	elif cell_type == CELL_WALL:
		_destroy_wall(cell)
	game.airborne_controller.begin_fall(player_index, -0.55)

func _update_impact_support_visual(player: Dictionary, cell: Vector2i, progress: float):
	var support = _support_node(cell)
	if is_instance_valid(support):
		var base_position := Constants.grid_to_world(cell) + Vector3(0, 0.62 if game.grid[cell.y][cell.x] == CELL_WALL else 0.46, 0)
		var shake := sin(float(player["impact_support_timer"]) * 52.0) * 0.045 * progress
		(support as Node3D).position = base_position + Vector3(shake, -0.08 * progress, -shake * 0.6)
		(support as Node3D).scale = Vector3(1.0 + 0.05 * progress, 1.0 - 0.24 * progress, 1.0 + 0.05 * progress)
	var cracks = player.get("impact_support_cracks")
	if is_instance_valid(cracks):
		(cracks as Node3D).scale = Vector3.ONE * lerpf(0.25, 1.15, progress)

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
	var support_height := Constants.WALL_SUPPORT_HEIGHT if game.grid[cell.y][cell.x] == CELL_WALL else Constants.CRATE_SUPPORT_HEIGHT
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

func _clear_crack_visual(player: Dictionary):
	var cracks = player.get("impact_support_cracks")
	if is_instance_valid(cracks):
		cracks.queue_free()
	player["impact_support_cracks"] = null

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
	if player_index < 0 or player_index >= game.players.size():
		return false
	var player: Dictionary = game.players[player_index]
	if bool(player.get("downed", false)) or (player["elevated_cell"] as Vector2i) != Vector2i(-1, -1):
		return false
	var covering_bombs := 1
	for raw_cell in game.bomb_map.keys():
		var bomb_cell := raw_cell as Vector2i
		var entry: Dictionary = game.bomb_map[bomb_cell]
		if int(entry.get("player_index", -1)) == player_index and game.bomb_manager.blast_cell_set(bomb_cell, int(entry["range"])).has(player["grid_pos"]):
			covering_bombs += 1
	if covering_bombs < 2:
		return false

	var directions := [player["last_move_dir"] as Vector2i, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var target := Vector2i(-1, -1)
	for direction in directions:
		var candidate: Vector2i = player["grid_pos"] + direction
		if candidate.x < 0 or candidate.x >= Constants.GRID_W or candidate.y < 0 or candidate.y >= Constants.GRID_H:
			continue
		if game.grid[candidate.y][candidate.x] not in [CELL_WALL, CELL_CRATE] or is_cell_occupied(candidate, player):
			continue
		target = candidate
		break
	if target == Vector2i(-1, -1):
		return false

	game.combat_manager.cancel_player_movement(player)
	player["grid_pos"] = target
	player["elevated_cell"] = target
	player["wall_stay_timer"] = 0.0
	player["wall_warning"] = false
	player["status"] = "Bomb Boost"
	var node = player.get("node")
	if is_instance_valid(node):
		var height := Constants.WALL_SUPPORT_HEIGHT if game.grid[target.y][target.x] == CELL_WALL else Constants.CRATE_SUPPORT_HEIGHT
		game.create_tween().bind_node(node).tween_property(node, "position", Constants.grid_to_world(target) + Vector3(0, height, 0), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return true

func try_wall_hop(player_index: int, direction: Vector2i) -> bool:
	if player_index < 0 or player_index >= game.players.size() or direction == Vector2i.ZERO:
		return false
	var player: Dictionary = game.players[player_index]
	if game.bomb_manager.game_time() > float(player.get("bomb_hop_until", -99.0)):
		return false
	var hop_cells := player.get("bomb_hop_cells", {}) as Dictionary
	if hop_cells.size() < 2:
		return false
	var active_hop_bombs := 0
	for raw_cell in hop_cells.keys():
		var bomb_cell := raw_cell as Vector2i
		if game.bomb_map.has(bomb_cell) and int((game.bomb_map[bomb_cell] as Dictionary).get("player_index", -1)) == player_index:
			active_hop_bombs += 1
	if active_hop_bombs < 2:
		return false
	var origin := player["grid_pos"] as Vector2i
	var wall_cell := origin + direction
	if not _is_in_bounds(wall_cell) or game.grid[wall_cell.y][wall_cell.x] != CELL_WALL:
		return false
	var perpendicular := Vector2i(-direction.y, direction.x)
	var required_empty := [origin - perpendicular, origin, origin + perpendicular, wall_cell - perpendicular, wall_cell + perpendicular]
	for raw_cell in required_empty:
		var cell := raw_cell as Vector2i
		if not _is_in_bounds(cell) or game.grid[cell.y][cell.x] != CELL_EMPTY:
			return false
	for exit_cell in [wall_cell - perpendicular, wall_cell + perpendicular]:
		if game.bomb_map.has(exit_cell) or game.oil_barrels.has(exit_cell):
			return false

	player["grid_pos"] = wall_cell
	player["last_move_dir"] = direction
	player["elevated_cell"] = wall_cell
	player["wall_stay_timer"] = 0.0
	player["wall_warning"] = false
	player["bomb_hop_until"] = -99.0
	player["bomb_hop_cells"] = {}
	player["is_moving"] = true
	player["status"] = "Wall Hop"
	var node = player.get("node")
	if not is_instance_valid(node):
		player["is_moving"] = false
		return false
	(node as Node3D).look_at(Constants.grid_to_world(wall_cell), Vector3.UP)
	var tween := game.create_tween().bind_node(node)
	player["move_tween"] = tween
	tween.tween_property(node, "position", Constants.grid_to_world(wall_cell) + Vector3(0, 1.30, 0), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		player["move_tween"] = null
		player["is_moving"] = false
	)
	return true

func clear_wall_warning(player: Dictionary):
	if not bool(player.get("wall_warning", false)):
		return
	_set_wall_warning(player["elevated_cell"] as Vector2i, false)
	player["wall_warning"] = false

func is_cell_occupied(cell: Vector2i, ignored_player: Dictionary = {}) -> bool:
	for player: Dictionary in game.players:
		if player != ignored_player and player["alive"] and player["grid_pos"] == cell:
			return true
	return false

func _destroy_wall(cell: Vector2i):
	game.grid[cell.y][cell.x] = CELL_EMPTY
	game.grid_manager.destroyed_walls[cell] = 0.0
	var wall = game.grid_manager.wall_nodes.get(cell)
	if is_instance_valid(wall):
		wall.transparency = 0.0
		wall.visible = false

func _drop_player_from_block(player: Dictionary):
	clear_wall_warning(player)
	player["elevated_cell"] = Vector2i(-1, -1)
	player["wall_stay_timer"] = 0.0
	var node = player.get("node")
	if is_instance_valid(node):
		game.create_tween().bind_node(node).tween_property(node, "position", Constants.grid_to_world(player["grid_pos"]), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _set_wall_warning(cell: Vector2i, enabled: bool):
	var wall = game.grid_manager.wall_nodes.get(cell)
	if is_instance_valid(wall):
		wall.transparency = 0.45 if enabled else 0.0

func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < Constants.GRID_W and cell.y >= 0 and cell.y < Constants.GRID_H
