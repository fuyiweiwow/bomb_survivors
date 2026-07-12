extends Node

const CELL_WALL := Constants.Cell.WALL

var game: Node

func setup(game_manager: Node):
	game = game_manager

func use(player_index: int, item_id: String) -> bool:
	var player: Dictionary = game.players[player_index]
	match item_id:
		"detonator":
			return _use_detonator(player)
		"glue":
			_place_glue(player_index)
			return true
		"shield_potion":
			player["shield"] = clampi(int(player["shield"]) + 1, 0, 5)
			player["status"] = "Shield gained"
			return true
		"invincible_star":
			player["invincible_timer"] = 5.0
			player["status"] = "Invincible 5s"
			return true
		"oil_barrel":
			return _place_oil_barrel(player_index)
		"wings":
			player["wings_timer"] = 8.0
			player["status"] = "Wings 8s"
			return true
		"football_shoes":
			player["football_timer"] = 8.0
			player["status"] = "Football shoes 8s"
			return true
		"tianlao":
			_cast_tianlao(player_index)
			return true
	return false

func process(delta: float):
	for raw_cell in game.glue_areas.keys():
		var cell := raw_cell as Vector2i
		var data: Dictionary = game.glue_areas[cell]
		data["time"] = float(data["time"]) - delta
		if float(data["time"]) <= 0.0:
			var node = data.get("node")
			if is_instance_valid(node):
				node.queue_free()
			game.glue_areas.erase(cell)
			continue
		for index in range(game.players.size()):
			if index != int(data["owner"]) and game.players[index]["alive"] and game.players[index]["grid_pos"] == cell:
				game.players[index]["slow_timer"] = 3.0

func end_wings(player: Dictionary):
	var cell := player["grid_pos"] as Vector2i
	if Constants.is_walkable_cell(game.grid[cell.y][cell.x]) and not game.bomb_map.has(cell) and not game.oil_barrels.has(cell):
		return
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var target: Vector2i = cell + direction
		if target.x < 0 or target.x >= Constants.GRID_W or target.y < 0 or target.y >= Constants.GRID_H:
			continue
		if Constants.is_walkable_cell(game.grid[target.y][target.x]) and not game.bomb_map.has(target) and not game.oil_barrels.has(target) and not game.wall_mechanics.is_cell_occupied(target):
			player["grid_pos"] = target
			var node = player.get("node")
			if is_instance_valid(node):
				node.position = Constants.grid_to_world(target)
			return

func damage_oil_barrel(cell: Vector2i):
	if not game.oil_barrels.has(cell):
		return
	var data: Dictionary = game.oil_barrels[cell]
	data["hp"] = int(data["hp"]) - 1
	if int(data["hp"]) > 0:
		var node = data.get("node")
		if is_instance_valid(node):
			var tween := game.create_tween().bind_node(node)
			tween.tween_property(node, "scale", Vector3(1.12, 0.86, 1.12), 0.07)
			tween.tween_property(node, "scale", Vector3.ONE, 0.09)
		return
	var owner := int(data.get("owner", -1))
	var node = data.get("node")
	game.oil_barrels.erase(cell)
	if is_instance_valid(node):
		node.queue_free()
	var result: Dictionary = game.bomb_manager.get_explosion_cells(cell, 2, true)
	game.bomb_manager.spawn_explosion(result["cells"])
	game._apply_explosion_damage(result["cells"], owner, cell)

func _use_detonator(player: Dictionary) -> bool:
	var direction := player["last_move_dir"] as Vector2i
	for distance in range(1, 7):
		var cell: Vector2i = player["grid_pos"] + direction * distance
		if cell.x < 0 or cell.x >= Constants.GRID_W or cell.y < 0 or cell.y >= Constants.GRID_H or game.grid[cell.y][cell.x] == CELL_WALL:
			break
		if game.bomb_map.has(cell):
			game.bomb_manager.explode_bomb(cell)
			return true
	player["status"] = "No bomb in sight"
	return false

func _place_glue(player_index: int):
	var player: Dictionary = game.players[player_index]
	var cell := player["grid_pos"] as Vector2i
	if game.glue_areas.has(cell):
		var old_node = (game.glue_areas[cell] as Dictionary).get("node")
		if is_instance_valid(old_node):
			old_node.queue_free()
	var node = MeshHelpers.cylinder(Constants.TILE_SIZE * 0.38, 0.035, game.mat_glue)
	node.position = Constants.grid_to_world(cell) + Vector3(0, 0.07, 0)
	game.add_child(node)
	game.glue_areas[cell] = {"node": node, "time": 5.0, "owner": player_index}
	player["status"] = "Glue placed"

func _place_oil_barrel(player_index: int) -> bool:
	var player: Dictionary = game.players[player_index]
	var cell: Vector2i = player["grid_pos"] + (player["last_move_dir"] as Vector2i)
	if cell.x < 0 or cell.x >= Constants.GRID_W or cell.y < 0 or cell.y >= Constants.GRID_H:
		return false
	if not Constants.is_walkable_cell(game.grid[cell.y][cell.x]) or game.bomb_map.has(cell) or game.oil_barrels.has(cell) or game.wall_mechanics.is_cell_occupied(cell):
		player["status"] = "No room for barrel"
		return false
	var root := Node3D.new()
	root.position = Constants.grid_to_world(cell)
	var body = MeshHelpers.cylinder(0.48, 0.92, game.mat_oil)
	body.position = Vector3(0, 0.46, 0)
	root.add_child(body)
	var band = MeshHelpers.cylinder(0.50, 0.10, game.mat_bomb_power)
	band.position = Vector3(0, 0.48, 0)
	root.add_child(band)
	game.add_child(root)
	game.oil_barrels[cell] = {"node": root, "hp": 4, "owner": player_index}
	player["status"] = "Oil barrel placed"
	return true

func _cast_tianlao(player_index: int):
	var player: Dictionary = game.players[player_index]
	var origin := player["grid_pos"] as Vector2i
	var cells: Array = [origin]
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		for distance in range(1, 6):
			var cell: Vector2i = origin + direction * distance
			if cell.x < 0 or cell.x >= Constants.GRID_W or cell.y < 0 or cell.y >= Constants.GRID_H or game.grid[cell.y][cell.x] == CELL_WALL:
				break
			cells.append(cell)
	for raw_cell in cells:
		var marker = MeshHelpers.box(Vector3(Constants.TILE_SIZE * 0.72, 0.06, Constants.TILE_SIZE * 0.72), game.mat_bomb_power)
		marker.position = Constants.grid_to_world(raw_cell as Vector2i) + Vector3(0, 0.10, 0)
		game.add_child(marker)
		var marker_tween := game.create_tween().bind_node(marker).set_loops()
		marker_tween.tween_property(marker, "transparency", 0.75, 0.18)
		marker_tween.tween_property(marker, "transparency", 0.05, 0.18)
		game.get_tree().create_timer(1.5).timeout.connect(marker.queue_free)
	game.get_tree().create_timer(1.5).timeout.connect(func():
		game.bomb_manager.spawn_explosion(cells)
		game._apply_explosion_damage(cells, player_index)
	)
	player["status"] = "Tianlao armed"
