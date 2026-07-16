extends Node

const MAP_DATA_CODEC := preload("res://scripts/grid/map_data_codec.gd")
const MAP_STATE_SCRIPT := preload("res://scripts/grid/map_state.gd")
const BOSS_CRATE_REFRESH_COUNT := 10
const SPAWN_SAFE_DEPTH := Constants.GRID_REFINEMENT * 2
const FIXED_WALL_SPACING := Constants.GRID_REFINEMENT * 2
const MAP_LOAD_MISSING := 0
const MAP_LOAD_OK := 1
const MAP_LOAD_INVALID := -1

var map_state: RefCounted = MAP_STATE_SCRIPT.new()
var grid: Array:
	get: return map_state.cells
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
	_initialize_blank_grid()
	var map_load_result := _load_saved_map()
	if map_load_result != MAP_LOAD_MISSING:
		return
	_generate_default_layout()

func _initialize_blank_grid():
	map_state.reset_blank()

func _generate_default_layout():
	for y in range(FIXED_WALL_SPACING, Constants.GRID_H - FIXED_WALL_SPACING, FIXED_WALL_SPACING):
		for x in range(FIXED_WALL_SPACING, Constants.GRID_W - FIXED_WALL_SPACING, FIXED_WALL_SPACING):
			grid[y][x] = Constants.Cell.WALL

	for y in range(1, Constants.GRID_H - 1):
		for x in range(1, Constants.GRID_W - 1):
			if grid[y][x] != Constants.Cell.EMPTY:
				continue
			if _is_spawn_safe_cell(Vector2i(x, y)):
				continue
			if randf() < 0.5:
				grid[y][x] = Constants.Cell.CRATE

	_seed_special_terrain()

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

	var floor_a_cells: Array[Vector2i] = []
	var floor_b_cells: Array[Vector2i] = []
	var forest_floor_cells: Array[Vector2i] = []
	var lava_floor_cells: Array[Vector2i] = []
	for y in Constants.GRID_H:
		for x in Constants.GRID_W:
			var cell := Vector2i(x, y)
			match grid[y][x]:
				Constants.Cell.FOREST:
					forest_floor_cells.append(cell)
				Constants.Cell.LAVA:
					lava_floor_cells.append(cell)
				_:
					(floor_a_cells if (x + y) % 2 == 0 else floor_b_cells).append(cell)
	_add_floor_batch("FloorBatchA", floor_a_cells, _mat_floor_a)
	_add_floor_batch("FloorBatchB", floor_b_cells, _mat_floor_b)
	_add_floor_batch("ForestFloorBatch", forest_floor_cells, _mat_forest_floor)
	_add_floor_batch("LavaFloorBatch", lava_floor_cells, _mat_lava)

	for y in Constants.GRID_H:
		for x in Constants.GRID_W:
			var cell := Vector2i(x, y)
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

func _add_floor_batch(batch_name: String, cells: Array[Vector2i], material: Material) -> void:
	if cells.is_empty():
		return
	_game.add_child(TerrainArtFactory.create_floor_batch(batch_name, cells, Constants.TILE_SIZE, material))

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
			for state: CharacterState in _game.character_registry.states():
				if state.is_alive() and state.cell() == cell:
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
	crate.name = "Crate_%d_%d" % [cell.x, cell.y]
	crate.position = Constants.grid_to_world(cell) + Vector3(0, 0.46, 0)
	crate_nodes[cell] = crate
	_game.add_child(crate)

func get_cell(x: int, y: int) -> int:
	return map_state.cell_at(Vector2i(x, y))

func set_cell(x: int, y: int, value: int):
	map_state.set_cell(Vector2i(x, y), value)

func is_passable(x: int, y: int) -> bool:
	return map_state.is_walkable(Vector2i(x, y))

func is_crate_at(cell: Vector2i) -> bool:
	return map_state.is_type(cell, Constants.Cell.CRATE)

func is_wall_at(cell: Vector2i) -> bool:
	return map_state.is_type(cell, Constants.Cell.WALL)

func is_forest_at(cell: Vector2i) -> bool:
	return map_state.is_type(cell, Constants.Cell.FOREST)

func is_lava_at(cell: Vector2i) -> bool:
	return map_state.is_type(cell, Constants.Cell.LAVA)

func walkable_cells() -> Array:
	return map_state.walkable_cells()

func _seed_special_terrain():
	var open_cells: Array = []
	for y in range(1, Constants.GRID_H - 1):
		for x in range(1, Constants.GRID_W - 1):
			if grid[y][x] != Constants.Cell.EMPTY:
				continue
			if _is_spawn_safe_cell(Vector2i(x, y)):
				continue
			open_cells.append(Vector2i(x, y))
	open_cells.shuffle()

	var index := 0
	for i in range(9 * Constants.GRID_REFINEMENT * Constants.GRID_REFINEMENT):
		if index >= open_cells.size():
			return
		var cell := open_cells[index] as Vector2i
		grid[cell.y][cell.x] = Constants.Cell.FOREST
		index += 1
	for i in range(6 * Constants.GRID_REFINEMENT * Constants.GRID_REFINEMENT):
		if index >= open_cells.size():
			return
		var cell := open_cells[index] as Vector2i
		grid[cell.y][cell.x] = Constants.Cell.LAVA
		index += 1

func _load_saved_map() -> int:
	if not FileAccess.file_exists("user://map_data.json"):
		return MAP_LOAD_MISSING
	var file := FileAccess.open("user://map_data.json", FileAccess.READ)
	if file == null:
		_delete_saved_map()
		return MAP_LOAD_INVALID
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		_delete_saved_map()
		return MAP_LOAD_INVALID
	file.close()

	if not MAP_DATA_CODEC.decode_into_state(
		json.get_data(),
		map_state
	):
		_delete_saved_map()
		return MAP_LOAD_INVALID
	return MAP_LOAD_OK

func _delete_saved_map():
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://map_data.json"))

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

func _is_spawn_safe_cell(cell: Vector2i) -> bool:
	return (
		(cell.x <= SPAWN_SAFE_DEPTH and cell.y <= SPAWN_SAFE_DEPTH)
		or (cell.x >= Constants.GRID_W - SPAWN_SAFE_DEPTH - 1 and cell.y >= Constants.GRID_H - SPAWN_SAFE_DEPTH - 1)
	)
