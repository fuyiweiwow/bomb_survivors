extends Node

const MAP_DATA_CODEC := preload("res://scripts/grid/map_data_codec.gd")
const BOSS_CRATE_REFRESH_COUNT := 10

var grid: Array = []
var crate_nodes: Dictionary = {}
var wall_nodes: Dictionary = {}
var destroyed_walls: Dictionary = {}

var _game: Node
var _mat_floor_a: Material
var _mat_floor_b: Material
var _mat_wall: Material
var _mat_crate: Material
var _mat_forest_floor: Material
var _mat_trunk: Material
var _mat_leaf: Material
var _mat_lava: Material

func setup(game_manager: Node, mats: Dictionary):
	_game = game_manager
	_mat_floor_a = mats["floor_a"]
	_mat_floor_b = mats["floor_b"]
	_mat_wall = mats["wall"]
	_mat_crate = mats["crate"]
	_mat_forest_floor = mats["forest_floor"]
	_mat_trunk = mats["trunk"]
	_mat_leaf = mats["leaf"]
	_mat_lava = mats["lava"]

func init_grid():
	grid.clear()
	for y in Constants.GRID_H:
		var row: Array = []
		row.resize(Constants.GRID_W)
		row.fill(Constants.Cell.EMPTY)
		grid.append(row)

	for x in Constants.GRID_W:
		grid[0][x] = Constants.Cell.WALL
		grid[Constants.GRID_H - 1][x] = Constants.Cell.WALL
	for y in Constants.GRID_H:
		grid[y][0] = Constants.Cell.WALL
		grid[y][Constants.GRID_W - 1] = Constants.Cell.WALL

	for y in range(2, Constants.GRID_H - 2, 2):
		for x in range(2, Constants.GRID_W - 2, 2):
			grid[y][x] = Constants.Cell.WALL

	for y in range(1, Constants.GRID_H - 1):
		for x in range(1, Constants.GRID_W - 1):
			if grid[y][x] != Constants.Cell.EMPTY:
				continue
			if (x <= 2 and y <= 2) or (x >= Constants.GRID_W - 3 and y >= Constants.GRID_H - 3):
				continue
			if randf() < 0.5:
				grid[y][x] = Constants.Cell.CRATE

	_seed_special_terrain()
	_load_saved_map()

func create_world():
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.09, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.64)
	env.ambient_light_energy = 0.9
	_game.world_environment = env
	var world := WorldEnvironment.new()
	world.environment = env
	_game.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.0
	sun.rotation_degrees = Vector3(-55, -35, 0)
	_game.add_child(sun)

	for y in Constants.GRID_H:
		for x in Constants.GRID_W:
			var cell := Vector2i(x, y)
			var floor := TerrainArtFactory.create_subdivided_floor_tile(
				cell,
				Constants.grid_to_world(cell),
				Constants.TILE_SIZE,
				Constants.GROUND_SUBDIVISIONS,
				_floor_mat_for_cell(x, y)
			)
			_game.add_child(floor)

			if grid[y][x] == Constants.Cell.WALL:
				var wall_node = TerrainArtFactory.create_rock_wall(cell, Constants.TILE_SIZE, _mat_wall)
				wall_node.position = Constants.grid_to_world(cell) + Vector3(0, 0.62, 0)
				wall_nodes[cell] = wall_node
				_game.add_child(wall_node)
			elif grid[y][x] == Constants.Cell.CRATE:
				_create_crate(cell)
			elif grid[y][x] == Constants.Cell.FOREST:
				_game.add_child(_create_forest_tile(cell))
			elif grid[y][x] == Constants.Cell.LAVA:
				_game.add_child(_create_lava_tile(cell))

func destroy_crate(cell: Vector2i):
	var had_crate: bool = grid[cell.y][cell.x] == Constants.Cell.CRATE or crate_nodes.has(cell)
	grid[cell.y][cell.x] = Constants.Cell.EMPTY
	if had_crate:
		_game.audio_manager.play("crate_break")
	if crate_nodes.has(cell):
		var crate: Node3D = crate_nodes[cell]
		var tw := create_tween()
		tw.tween_property(crate, "scale", Vector3(1.2, 0.2, 1.2), 0.16)
		tw.tween_callback(crate.queue_free)
		crate_nodes.erase(cell)

func refresh_crates_for_boss(count := BOSS_CRATE_REFRESH_COUNT) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for y in range(1, Constants.GRID_H - 1):
		for x in range(1, Constants.GRID_W - 1):
			var cell := Vector2i(x, y)
			if grid[y][x] != Constants.Cell.EMPTY or destroyed_walls.has(cell):
				continue
			if _game.bomb_map.has(cell) or _game.powerups.has(cell) or _game.oil_barrels.has(cell) or _game.glue_areas.has(cell):
				continue
			var occupied := false
			for player: Dictionary in _game.players:
				if player["alive"] and player["grid_pos"] == cell:
					occupied = true
					break
			if not occupied:
				candidates.append(cell)
	candidates.shuffle()
	var refreshed: Array[Vector2i] = []
	for i in range(mini(maxi(count, 0), candidates.size())):
		var cell := candidates[i]
		grid[cell.y][cell.x] = Constants.Cell.CRATE
		_create_crate(cell)
		refreshed.append(cell)
	return refreshed

func _create_crate(cell: Vector2i):
	var crate := MeshHelpers.box(Vector3(Constants.TILE_SIZE * 0.84, 0.92, Constants.TILE_SIZE * 0.84), _mat_crate)
	crate.position = Constants.grid_to_world(cell) + Vector3(0, 0.46, 0)
	crate_nodes[cell] = crate
	_game.add_child(crate)

func get_cell(x: int, y: int) -> int:
	if x < 0 or x >= Constants.GRID_W or y < 0 or y >= Constants.GRID_H:
		return Constants.Cell.WALL
	return grid[y][x]

func set_cell(x: int, y: int, value: int):
	if x >= 0 and x < Constants.GRID_W and y >= 0 and y < Constants.GRID_H:
		grid[y][x] = value

func is_passable(x: int, y: int) -> bool:
	if x < 0 or x >= Constants.GRID_W or y < 0 or y >= Constants.GRID_H:
		return false
	return Constants.is_walkable_cell(grid[y][x])

func is_crate_at(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= Constants.GRID_W or cell.y < 0 or cell.y >= Constants.GRID_H:
		return false
	return grid[cell.y][cell.x] == Constants.Cell.CRATE

func is_wall_at(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= Constants.GRID_W or cell.y < 0 or cell.y >= Constants.GRID_H:
		return false
	return grid[cell.y][cell.x] == Constants.Cell.WALL

func is_forest_at(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= Constants.GRID_W or cell.y < 0 or cell.y >= Constants.GRID_H:
		return false
	return grid[cell.y][cell.x] == Constants.Cell.FOREST

func is_lava_at(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= Constants.GRID_W or cell.y < 0 or cell.y >= Constants.GRID_H:
		return false
	return grid[cell.y][cell.x] == Constants.Cell.LAVA

func walkable_cells() -> Array:
	var cells: Array = []
	for y in range(1, Constants.GRID_H - 1):
		for x in range(1, Constants.GRID_W - 1):
			if Constants.is_walkable_cell(grid[y][x]):
				cells.append(Vector2i(x, y))
	return cells

func _seed_special_terrain():
	var open_cells: Array = []
	for y in range(1, Constants.GRID_H - 1):
		for x in range(1, Constants.GRID_W - 1):
			if grid[y][x] != Constants.Cell.EMPTY:
				continue
			if (x <= 2 and y <= 2) or (x >= Constants.GRID_W - 3 and y >= Constants.GRID_H - 3):
				continue
			open_cells.append(Vector2i(x, y))
	open_cells.shuffle()

	var index := 0
	for i in range(9):
		if index >= open_cells.size():
			return
		var cell := open_cells[index] as Vector2i
		grid[cell.y][cell.x] = Constants.Cell.FOREST
		index += 1
	for i in range(6):
		if index >= open_cells.size():
			return
		var cell := open_cells[index] as Vector2i
		grid[cell.y][cell.x] = Constants.Cell.LAVA
		index += 1

func _load_saved_map():
	if not FileAccess.file_exists("user://map_data.json"):
		return
	var file := FileAccess.open("user://map_data.json", FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()

	MAP_DATA_CODEC.decode_into_grid(
		json.get_data(),
		grid,
		Constants.GRID_W,
		Constants.GRID_H,
		Constants.Cell.EMPTY,
		Constants.Cell.WALL
	)

func _floor_mat_for_cell(x: int, y: int) -> Material:
	match grid[y][x]:
		Constants.Cell.FOREST:
			return _mat_forest_floor
		Constants.Cell.LAVA:
			return _mat_lava
		_:
			return _mat_floor_a if (x + y) % 2 == 0 else _mat_floor_b

func _create_forest_tile(cell: Vector2i) -> Node3D:
	return TerrainArtFactory.create_forest_tile(cell, Constants.grid_to_world(cell), Constants.TILE_SIZE, _mat_forest_floor, _mat_trunk, _mat_leaf)

func _create_lava_tile(cell: Vector2i) -> Node3D:
	return TerrainArtFactory.create_lava_tile(cell, Constants.grid_to_world(cell), Constants.TILE_SIZE, _mat_lava)
