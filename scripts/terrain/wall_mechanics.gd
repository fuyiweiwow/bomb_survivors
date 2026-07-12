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
	for player: Dictionary in game.players:
		if not player["alive"]:
			continue
		var cell := player["elevated_cell"] as Vector2i
		if cell == Vector2i(-1, -1):
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

	game.combat_manager._cancel_player_movement(player)
	player["grid_pos"] = target
	player["elevated_cell"] = target
	player["wall_stay_timer"] = 0.0
	player["wall_warning"] = false
	player["status"] = "Bomb Boost"
	var node = player.get("node")
	if is_instance_valid(node):
		var height := 1.30 if game.grid[target.y][target.x] == CELL_WALL else 0.98
		game.create_tween().bind_node(node).tween_property(node, "position", Constants.grid_to_world(target) + Vector3(0, height, 0), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
