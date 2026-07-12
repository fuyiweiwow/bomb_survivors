extends Node3D

const GRID_W := 15
const GRID_H := 11
const TILE_SIZE := 1.6
const FLOOR_Y := 0.0
const BOMB_FUSE := 2.5
const PLAYER_MAX_HP := 3
const LAVA_DAMAGE_TIME := 1.35
const DOWNED_DURATION := 5.0
const MAX_CONSUMABLES := 3
const BOMB_HOP_WINDOW := 0.30
const WALL_WARNING_TIME := 2.0
const WALL_DESTROY_TIME := 4.0
const WALL_RESTORE_TIME := 8.0
const AI_DECISION_POLICY := preload("res://scripts/character/AIDecisionPolicy.gd")
const WEATHER_MANAGER := preload("res://scripts/weather/WeatherManager.gd")
const WAVE_MANAGER := preload("res://scripts/wave/WaveManager.gd")
const TERRAIN_ART := preload("res://scripts/terrain/TerrainArtFactory.gd")
const CONSUMABLE_IDS := ["detonator", "glue", "shield_potion", "invincible_star", "dummy", "oil_barrel", "wings", "football_shoes", "tianlao"]

enum Cell { EMPTY, WALL, CRATE, FOREST, LAVA }

var grid: Array = []
var players: Array = []
var bomb_map: Dictionary = {}
var crate_nodes: Dictionary = {}
var wall_nodes: Dictionary = {}
var destroyed_walls: Dictionary = {}
var powerups: Dictionary = {}
var glue_areas: Dictionary = {}
var oil_barrels: Dictionary = {}
var game_over := false
var next_player_id := 2
var weather_manager: Node = null
var wave_manager: Node = null
var world_environment: Environment = null
var weather_visuals := Node3D.new()

var bomb_pressed := false
var hud_label: Label = null
var game_camera: Camera3D = null
var player_card_panel: PanelContainer = null
var player_card_label: Label = null
var enemy_card_panel: PanelContainer = null
var enemy_card_label: Label = null
var inventory_slot_labels: Array[Label] = []
var ai_difficulty := "normal"

var tex_floor: Texture2D = load("res://assets/art/3d/floor_tile.png")
var tex_wall: Texture2D = load("res://assets/art/3d/wall_block.png")
var tex_crate: Texture2D = load("res://assets/art/3d/crate_wood.png")
var tex_bomb: Texture2D = load("res://assets/art/3d/bomb_shell.png")
var tex_powerup: Texture2D = load("res://assets/art/3d/powerup_energy.png")
var tex_lava: Texture2D = load("res://assets/art/3d/lava_cracked.png")

var mat_floor_a := TERRAIN_ART.brushed_material(tex_floor, Color(0.70, 0.78, 0.66), TERRAIN_ART.PATCH_BRUSH)
var mat_floor_b := TERRAIN_ART.brushed_material(tex_floor, Color(0.82, 0.88, 0.76), TERRAIN_ART.PATCH_BRUSH)
var mat_wall := TERRAIN_ART.brushed_material(tex_wall, Color(0.72, 0.76, 0.82), TERRAIN_ART.PATCH_BRUSH)
var mat_crate := TERRAIN_ART.brushed_material(tex_crate, Color(1.0, 0.88, 0.70), TERRAIN_ART.PATCH_BRUSH)
var mat_player := _make_mat(Color(0.18, 0.48, 0.95))
var mat_ai := _make_mat(Color(0.95, 0.27, 0.22))
var mat_bomb := _make_mat(Color(0.75, 0.75, 0.78), false, tex_bomb)
var mat_fire := _make_mat(Color(1.0, 0.48, 0.08), true)
var mat_forest_floor := TERRAIN_ART.brushed_material(tex_floor, Color(0.18, 0.36, 0.18), TERRAIN_ART.DOTS_BRUSH)
var mat_leaf := _make_mat(Color(0.10, 0.48, 0.16))
var mat_trunk := _make_mat(Color(0.42, 0.24, 0.11))
var mat_lava := TERRAIN_ART.brushed_material(tex_lava, Color(0.95, 0.18, 0.04), TERRAIN_ART.LAVA_BRUSH, 0.8)
var mat_lava_glow := TERRAIN_ART.brushed_material(tex_lava, Color(1.0, 0.65, 0.08), TERRAIN_ART.LAVA_BRUSH, 1.5)
var mat_speed := _make_mat(Color(0.2, 0.95, 0.85), true, tex_powerup)
var mat_bomb_power := _make_mat(Color(0.95, 0.92, 0.25), true, tex_powerup)
var mat_range := _make_mat(Color(1.0, 0.22, 0.12), true, tex_powerup)
var mat_shield := _make_mat(Color(0.35, 0.55, 1.0), true, tex_powerup)
var mat_dummy := _make_mat(Color(0.92, 0.78, 0.46), true, tex_powerup)
var mat_consumable := _make_mat(Color(0.25, 0.92, 0.72), true, tex_powerup)
var mat_glue := _make_mat(Color(0.92, 0.34, 0.78), true)
var mat_oil := _make_mat(Color(0.18, 0.20, 0.22))
var mat_boss_blast := _make_mat(Color(0.52, 0.08, 0.04), true)
var mat_boss_frost := _make_mat(Color(0.40, 0.82, 1.0), true)
var mat_boss_clone := _make_mat(Color(0.62, 0.22, 0.88), true)

func _ready():
	add_to_group("game")
	randomize()
	ai_difficulty = _load_ai_difficulty()
	_init_grid()
	_create_world()
	_spawn_players()
	_setup_camera()
	_setup_hud()
	_setup_progression()

func _setup_progression():
	weather_manager = WEATHER_MANAGER.new()
	add_child(weather_manager)
	weather_manager.weather_changed.connect(_on_weather_changed)
	weather_manager.thunder_requested.connect(_request_thunder_strike)

	wave_manager = WAVE_MANAGER.new()
	add_child(wave_manager)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.start()

func _make_mat(color: Color, emission := false, texture: Texture2D = null) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if texture:
		mat.albedo_texture = texture
	mat.roughness = 0.68
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.6
	return mat

func _init_grid():
	grid.clear()
	for y in GRID_H:
		var row: Array = []
		row.resize(GRID_W)
		row.fill(Cell.EMPTY)
		grid.append(row)

	for x in GRID_W:
		grid[0][x] = Cell.WALL
		grid[GRID_H - 1][x] = Cell.WALL
	for y in GRID_H:
		grid[y][0] = Cell.WALL
		grid[y][GRID_W - 1] = Cell.WALL

	for y in range(2, GRID_H - 2, 2):
		for x in range(2, GRID_W - 2, 2):
			grid[y][x] = Cell.WALL

	for y in range(1, GRID_H - 1):
		for x in range(1, GRID_W - 1):
			if grid[y][x] != Cell.EMPTY:
				continue
			if (x <= 2 and y <= 2) or (x >= GRID_W - 3 and y >= GRID_H - 3):
				continue
			if randf() < 0.5:
				grid[y][x] = Cell.CRATE

	_seed_special_terrain()
	_load_saved_map()

func _seed_special_terrain():
	var open_cells: Array = []
	for y in range(1, GRID_H - 1):
		for x in range(1, GRID_W - 1):
			if grid[y][x] != Cell.EMPTY:
				continue
			if (x <= 2 and y <= 2) or (x >= GRID_W - 3 and y >= GRID_H - 3):
				continue
			open_cells.append(Vector2i(x, y))
	open_cells.shuffle()

	var index := 0
	for i in range(6):
		if index >= open_cells.size():
			return
		var cell := open_cells[index] as Vector2i
		grid[cell.y][cell.x] = Cell.FOREST
		index += 1
	for i in range(4):
		if index >= open_cells.size():
			return
		var cell := open_cells[index] as Vector2i
		grid[cell.y][cell.x] = Cell.LAVA
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

	var data = json.get_data()
	for y in GRID_H:
		for x in GRID_W:
			grid[y][x] = Cell.EMPTY
	for x in GRID_W:
		grid[0][x] = Cell.WALL
		grid[GRID_H - 1][x] = Cell.WALL
	for y in GRID_H:
		grid[y][0] = Cell.WALL
		grid[y][GRID_W - 1] = Cell.WALL

	for key in data.keys():
		var coords = key.split(",")
		if coords.size() != 2:
			continue
		var cx := int(coords[0])
		var cy := int(coords[1])
		if cx >= 1 and cx < GRID_W - 1 and cy >= 1 and cy < GRID_H - 1:
			grid[cy][cx] = int(data[key])

func _create_world():
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.09, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.64)
	env.ambient_light_energy = 0.9
	world.environment = env
	world_environment = env
	add_child(world)
	weather_visuals.name = "WeatherVisuals"
	add_child(weather_visuals)
	add_child(TERRAIN_ART.create_outer_terrain(GRID_W, GRID_H, TILE_SIZE, mat_wall, mat_floor_a))

	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.0
	sun.rotation_degrees = Vector3(-55, -35, 0)
	add_child(sun)

	for y in GRID_H:
		for x in GRID_W:
			var cell := Vector2i(x, y)
			var floor := _box(Vector3(TILE_SIZE, 0.08, TILE_SIZE), _floor_mat_for_cell(x, y))
			floor.position = _grid_to_world(Vector2i(x, y)) + Vector3(0, -0.04, 0)
			add_child(floor)

			if grid[y][x] == Cell.WALL:
				var wall := TERRAIN_ART.create_rock_wall(cell, TILE_SIZE, mat_wall)
				wall.position = _grid_to_world(cell) + Vector3(0, 0.62, 0)
				wall_nodes[cell] = wall
				add_child(wall)
			elif grid[y][x] == Cell.CRATE:
				var crate := _box(Vector3(TILE_SIZE * 0.84, 0.92, TILE_SIZE * 0.84), mat_crate)
				crate.position = _grid_to_world(cell) + Vector3(0, 0.46, 0)
				crate_nodes[cell] = crate
				add_child(crate)
			elif grid[y][x] == Cell.FOREST:
				add_child(_create_forest_tile(cell))
			elif grid[y][x] == Cell.LAVA:
				add_child(_create_lava_tile(cell))

func _floor_mat_for_cell(x: int, y: int) -> Material:
	match grid[y][x]:
		Cell.FOREST:
			return mat_forest_floor
		Cell.LAVA:
			return mat_lava
		_:
			return mat_floor_a if (x + y) % 2 == 0 else mat_floor_b

func _create_forest_tile(cell: Vector2i) -> Node3D:
	return TERRAIN_ART.create_forest_tile(cell, _grid_to_world(cell), TILE_SIZE, mat_forest_floor, mat_trunk, mat_leaf)

func _create_lava_tile(cell: Vector2i) -> Node3D:
	return TERRAIN_ART.create_lava_tile(cell, _grid_to_world(cell), TILE_SIZE, mat_lava_glow)

func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	return node

func _sphere(radius: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	return node

func _capsule(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	return node

func _cylinder(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	return node

func _grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (GRID_W - 1) / 2.0) * TILE_SIZE, FLOOR_Y, (cell.y - (GRID_H - 1) / 2.0) * TILE_SIZE)

func _spawn_players():
	var config := _load_player_config()
	var player := _create_player(1, Vector2i(1, 1), false, _player_material_from_config(config), str(config["gender"]))
	player["speed"] = config["start_speed"]
	player["bomb_max"] = config["start_bombs"]
	player["bomb_range"] = config["start_range"]
	player["shield"] = config["start_shields"]
	player["consumables"].append("shield_potion")
	players.append(player)

func _spawn_ai_wave(count: int):
	for i in range(count):
		var spawn_cell := _find_spawn_cell()
		if spawn_cell == Vector2i(-1, -1):
			return
		var ai_player := _create_player(next_player_id, spawn_cell, true, mat_ai, "ai")
		next_player_id += 1
		_apply_ai_difficulty(ai_player)
		players.append(ai_player)

func _spawn_boss(boss_id: String):
	var spawn_cell := _find_spawn_cell()
	if spawn_cell == Vector2i(-1, -1):
		return
	var boss_data := _boss_data(boss_id)
	var boss := _create_player(next_player_id, spawn_cell, true, boss_data["material"], "boss")
	next_player_id += 1
	boss["boss_id"] = boss_id
	boss["boss_name"] = boss_data["name"]
	boss["hp"] = boss_data["hp"]
	boss["max_hp"] = boss_data["hp"]
	boss["speed"] = boss_data["speed"]
	boss["bomb_range"] = boss_data["range"]
	boss["bomb_max"] = boss_data["bomb_max"]
	boss["move_interval"] = boss_data["move_interval"]
	boss["bomb_interval"] = boss_data["bomb_interval"]
	boss["skill_timer"] = boss_data["skill_interval"]
	boss["node"].scale = Vector3(1.45, 1.45, 1.45)
	players.append(boss)

func _boss_data(boss_id: String) -> Dictionary:
	match boss_id:
		"frost_giant":
			return {"name": "Frost Giant", "hp": 12, "speed": 3, "range": 1, "bomb_max": 0, "move_interval": 0.48, "bomb_interval": 99.0, "skill_interval": 4.5, "material": mat_boss_frost}
		"clone_demon":
			return {"name": "Clone Demon", "hp": 6, "speed": 6, "range": 2, "bomb_max": 2, "move_interval": 0.20, "bomb_interval": 1.4, "skill_interval": 5.0, "material": mat_boss_clone}
		_:
			return {"name": "Blast King", "hp": 8, "speed": 5, "range": 5, "bomb_max": 3, "move_interval": 0.28, "bomb_interval": 0.75, "skill_interval": 3.5, "material": mat_boss_blast}

func _find_spawn_cell() -> Vector2i:
	var candidates: Array = []
	for y in range(1, GRID_H - 1):
		for x in range(1, GRID_W - 1):
			var cell := Vector2i(x, y)
			if not _is_walkable_cell(grid[y][x]) or grid[y][x] == Cell.LAVA or bomb_map.has(cell):
				continue
			var occupied := false
			for p: Dictionary in players:
				if p["alive"] and p["grid_pos"] == cell:
					occupied = true
					break
			if not occupied:
				candidates.append(cell)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i): return a.distance_squared_to(Vector2i(1, 1)) > b.distance_squared_to(Vector2i(1, 1)))
	var pool_size := mini(12, candidates.size())
	return candidates[randi_range(0, pool_size - 1)]

func _apply_ai_difficulty(p: Dictionary):
	p["ai_difficulty"] = ai_difficulty
	match ai_difficulty:
		"easy":
			p["speed"] = 3
			p["bomb_range"] = 1
			p["move_interval"] = randf_range(0.75, 1.15)
			p["bomb_interval"] = randf_range(3.2, 5.0)
		"hard":
			p["speed"] = 6
			p["bomb_range"] = 3
			p["move_interval"] = randf_range(0.18, 0.38)
			p["bomb_interval"] = randf_range(0.9, 1.7)
		_:
			p["speed"] = 5
			p["bomb_range"] = 2
			p["move_interval"] = randf_range(0.35, 0.75)
			p["bomb_interval"] = randf_range(1.6, 3.2)

func _load_player_config() -> Dictionary:
	var config := {
		"gender": "male",
		"start_speed": 5,
		"start_bombs": 1,
		"start_range": 2,
		"start_shields": 0
	}
	if not FileAccess.file_exists("user://player_config.json"):
		return config
	var file := FileAccess.open("user://player_config.json", FileAccess.READ)
	if file == null:
		return config
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		config["gender"] = str(data.get("gender", config["gender"]))
		config["start_speed"] = clampi(int(data.get("start_speed", config["start_speed"])), 1, 10)
		config["start_bombs"] = clampi(int(data.get("start_bombs", config["start_bombs"])), 1, 8)
		config["start_range"] = clampi(int(data.get("start_range", config["start_range"])), 1, 10)
		config["start_shields"] = clampi(int(data.get("start_shields", config["start_shields"])), 0, 3)
	file.close()
	return config

func _load_ai_difficulty() -> String:
	if not FileAccess.file_exists("user://ai_settings.json"):
		return "normal"
	var file := FileAccess.open("user://ai_settings.json", FileAccess.READ)
	if file == null:
		return "normal"
	var result := "normal"
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		result = str(data.get("difficulty", "normal"))
	file.close()
	if not ["easy", "normal", "hard"].has(result):
		result = "normal"
	return result

func _player_material_from_config(config: Dictionary) -> Material:
	var color := Color(0.18, 0.48, 0.95)
	if str(config.get("gender", "male")) == "female":
		color = Color(0.95, 0.27, 0.22)
	return _make_mat(color)

func _create_player(id: int, cell: Vector2i, ai: bool, mat: Material, style := "male") -> Dictionary:
	var style_data := _player_style_data(style)
	var root := Node3D.new()
	root.name = "Player%d_3D" % id
	root.position = _grid_to_world(cell)

	var body := _capsule(style_data["radius"], style_data["height"], mat)
	body.position = Vector3(0, style_data["body_y"], 0)
	root.add_child(body)

	var visor := _box(Vector3(style_data["visor_w"], 0.12, 0.08), _make_mat(style_data["visor_color"], true))
	visor.position = Vector3(0, style_data["visor_y"], -0.34)
	root.add_child(visor)

	add_child(root)
	return {
		"id": id,
		"node": root,
		"grid_pos": cell,
		"alive": true,
		"hp": PLAYER_MAX_HP,
		"max_hp": PLAYER_MAX_HP,
		"downed": false,
		"downed_timer": 0.0,
		"is_moving": false,
		"move_tween": null,
		"state_tween": null,
		"speed": 5,
		"bomb_max": 1,
		"bomb_range": 2,
		"shield": 0,
		"suit": style,
		"lava_time": 0.0,
		"status": "Ready",
		"consumables": [],
		"selected_consumable_index": 0,
		"invincible_timer": 0.0,
		"wings_timer": 0.0,
		"football_timer": 0.0,
		"slow_timer": 0.0,
		"bomb_placed_count": 0,
		"ai": ai,
		"move_timer": 0.0,
		"move_interval": randf_range(0.3, 0.8),
		"bomb_timer": 0.0,
		"bomb_interval": randf_range(1.5, 3.5),
		"move_dir": Vector2i.ZERO,
		"last_bomb_pos": Vector2i(-1, -1),
		"last_bomb_place_time": -99.0,
		"bomb_hop_until": -99.0,
		"bomb_hop_cells": {},
		"last_move_dir": Vector2i.DOWN,
		"elevated_cell": Vector2i(-1, -1),
		"wall_stay_timer": 0.0,
		"wall_warning": false,
		"last_seen_player_pos": Vector2i(-1, -1),
		"boss_id": "",
		"boss_name": "",
		"is_minion": false,
		"skill_timer": 0.0,
		"frozen_timer": 0.0
	}

func _player_style_data(style: String) -> Dictionary:
	match style:
		"female":
			return {
				"radius": 0.31,
				"height": 0.98,
				"body_y": 0.58,
				"visor_y": 0.78,
				"visor_w": 0.52,
				"visor_color": Color(1.0, 0.58, 0.25)
			}
		"ai":
			return {
				"radius": 0.36,
				"height": 1.08,
				"body_y": 0.63,
				"visor_y": 0.83,
				"visor_w": 0.48,
				"visor_color": Color(0.02, 0.03, 0.04)
			}
		"boss":
			return {
				"radius": 0.40,
				"height": 1.18,
				"body_y": 0.68,
				"visor_y": 0.90,
				"visor_w": 0.56,
				"visor_color": Color(1.0, 0.82, 0.18)
			}
		_:
			return {
				"radius": 0.35,
				"height": 1.05,
				"body_y": 0.62,
				"visor_y": 0.82,
				"visor_w": 0.46,
				"visor_color": Color(0.2, 0.85, 1.0)
			}

func _setup_camera():
	game_camera = Camera3D.new()
	game_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game_camera.size = 19.0
	game_camera.position = Vector3(0, 16, 12)
	game_camera.rotation_degrees = Vector3(-58, 0, 0)
	game_camera.current = true
	add_child(game_camera)

func _setup_hud():
	var layer := CanvasLayer.new()
	add_child(layer)

	var player_card := _make_status_card(layer, "YOU", Color(0.18, 0.48, 0.95))
	player_card_panel = player_card["panel"]
	player_card_label = player_card["label"]

	var enemy_card := _make_status_card(layer, "AI", Color(0.95, 0.27, 0.22))
	enemy_card_panel = enemy_card["panel"]
	enemy_card_label = enemy_card["label"]

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.position = Vector2(0, 548)
	bg.size = Vector2(800, 52)
	layer.add_child(bg)

	hud_label = Label.new()
	hud_label.position = Vector2(12, 560)
	hud_label.size = Vector2(780, 30)
	hud_label.add_theme_font_size_override("font_size", 16)
	hud_label.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(hud_label)
	_setup_inventory_bar(layer)
	_update_hud()

func _setup_inventory_bar(layer: CanvasLayer):
	var panel := PanelContainer.new()
	panel.position = Vector2(446, 500)
	panel.custom_minimum_size = Vector2(342, 42)
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	for i in range(MAX_CONSUMABLES):
		var slot := Label.new()
		slot.custom_minimum_size = Vector2(110, 36)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 11)
		row.add_child(slot)
		inventory_slot_labels.append(slot)

func _make_status_card(parent: Node, avatar_text: String, color: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(156, 46)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var avatar := Label.new()
	avatar.text = avatar_text
	avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.custom_minimum_size = Vector2(34, 34)
	avatar.add_theme_font_size_override("font_size", 13)
	avatar.add_theme_color_override("font_color", Color.WHITE)
	avatar.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	var avatar_style := StyleBoxFlat.new()
	avatar_style.bg_color = color
	avatar_style.corner_radius_top_left = 6
	avatar_style.corner_radius_top_right = 6
	avatar_style.corner_radius_bottom_left = 6
	avatar_style.corner_radius_bottom_right = 6
	avatar.add_theme_stylebox_override("normal", avatar_style)
	row.add_child(avatar)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.custom_minimum_size = Vector2(92, 36)
	row.add_child(label)
	return {"panel": panel, "label": label}

func _unhandled_input(event):
	if game_over:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			get_tree().reload_current_scene()
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
		if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
			get_tree().quit()
		return
	if event is InputEventKey and not event.pressed and event.physical_keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_finish_player_move_immediately()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: bomb_pressed = true
			KEY_E: _try_use_player_consumable()
			KEY_Q: _cycle_player_consumable()
			KEY_ESCAPE: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func _finish_player_move_immediately():
	if players.is_empty():
		return
	var p: Dictionary = players[0]
	if not p["alive"] or not bool(p.get("is_moving", false)):
		return
	var move_tween = p.get("move_tween")
	if move_tween is Tween and is_instance_valid(move_tween):
		(move_tween as Tween).kill()
	p["move_tween"] = null
	p["is_moving"] = false
	var node = p.get("node")
	if is_instance_valid(node):
		var target_height := 0.92 if float(p.get("wings_timer", 0.0)) > 0.0 else 0.0
		node.position = _grid_to_world(p["grid_pos"]) + Vector3(0, target_height, 0)
	_check_powerup_pickup(0)

func _try_use_player_consumable():
	if players.is_empty():
		return
	var p: Dictionary = players[0]
	if bool(p.get("downed", false)):
		if _consume_dummy_if_available(p):
			_revive_player(0)
		return
	if not p["alive"]:
		return
	var items: Array = p["consumables"]
	if items.is_empty():
		p["status"] = "Bag empty"
		return
	var selected := clampi(int(p["selected_consumable_index"]), 0, items.size() - 1)
	var item_id := str(items[selected])
	if item_id == "dummy":
		p["status"] = "Dummy is passive"
		return
	if _use_consumable(0, item_id):
		items.remove_at(selected)
		p["selected_consumable_index"] = clampi(selected, 0, maxi(items.size() - 1, 0))

func _cycle_player_consumable():
	if players.is_empty() or not players[0]["alive"]:
		return
	var p: Dictionary = players[0]
	var items: Array = p["consumables"]
	if items.is_empty():
		p["status"] = "Bag empty"
		return
	p["selected_consumable_index"] = (int(p["selected_consumable_index"]) + 1) % items.size()
	p["status"] = "Selected %s" % _item_display_name(str(items[p["selected_consumable_index"]]))

func _use_consumable(player_index: int, item_id: String) -> bool:
	var p: Dictionary = players[player_index]
	match item_id:
		"detonator":
			return _use_detonator(p)
		"glue":
			_place_glue(player_index)
			return true
		"shield_potion":
			p["shield"] = clampi(int(p["shield"]) + 1, 0, 5)
			p["status"] = "Shield gained"
			return true
		"invincible_star":
			p["invincible_timer"] = 5.0
			p["status"] = "Invincible 5s"
			return true
		"oil_barrel":
			return _place_oil_barrel(player_index)
		"wings":
			p["wings_timer"] = 8.0
			p["status"] = "Wings 8s"
			return true
		"football_shoes":
			p["football_timer"] = 8.0
			p["status"] = "Football shoes 8s"
			return true
		"tianlao":
			_cast_tianlao(player_index)
			return true
	return false

func _use_detonator(p: Dictionary) -> bool:
	var direction := p["last_move_dir"] as Vector2i
	for distance in range(1, 7):
		var cell: Vector2i = p["grid_pos"] + direction * distance
		if cell.x < 0 or cell.x >= GRID_W or cell.y < 0 or cell.y >= GRID_H or grid[cell.y][cell.x] == Cell.WALL:
			break
		if bomb_map.has(cell):
			_explode_bomb(cell)
			return true
	p["status"] = "No bomb in sight"
	return false

func _place_glue(player_index: int):
	var p: Dictionary = players[player_index]
	var cell := p["grid_pos"] as Vector2i
	if glue_areas.has(cell):
		var old_node = (glue_areas[cell] as Dictionary).get("node")
		if is_instance_valid(old_node):
			old_node.queue_free()
	var node := _cylinder(TILE_SIZE * 0.38, 0.035, mat_glue)
	node.position = _grid_to_world(cell) + Vector3(0, 0.07, 0)
	add_child(node)
	glue_areas[cell] = {"node": node, "time": 5.0, "owner": player_index}
	p["status"] = "Glue placed"

func _place_oil_barrel(player_index: int) -> bool:
	var p: Dictionary = players[player_index]
	var cell: Vector2i = p["grid_pos"] + (p["last_move_dir"] as Vector2i)
	if cell.x < 0 or cell.x >= GRID_W or cell.y < 0 or cell.y >= GRID_H:
		return false
	if not _is_walkable_cell(grid[cell.y][cell.x]) or bomb_map.has(cell) or oil_barrels.has(cell) or _is_cell_occupied(cell):
		p["status"] = "No room for barrel"
		return false
	var root := Node3D.new()
	root.position = _grid_to_world(cell)
	var body := _cylinder(0.48, 0.92, mat_oil)
	body.position = Vector3(0, 0.46, 0)
	root.add_child(body)
	var band := _cylinder(0.50, 0.10, mat_bomb_power)
	band.position = Vector3(0, 0.48, 0)
	root.add_child(band)
	add_child(root)
	oil_barrels[cell] = {"node": root, "hp": 4, "owner": player_index}
	p["status"] = "Oil barrel placed"
	return true

func _cast_tianlao(player_index: int):
	var p: Dictionary = players[player_index]
	var origin := p["grid_pos"] as Vector2i
	var cells: Array = [origin]
	var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for direction in directions:
		for distance in range(1, 6):
			var cell: Vector2i = origin + direction * distance
			if cell.x < 0 or cell.x >= GRID_W or cell.y < 0 or cell.y >= GRID_H or grid[cell.y][cell.x] == Cell.WALL:
				break
			cells.append(cell)
	for raw_cell in cells:
		var marker := _box(Vector3(TILE_SIZE * 0.72, 0.06, TILE_SIZE * 0.72), mat_bomb_power)
		marker.position = _grid_to_world(raw_cell as Vector2i) + Vector3(0, 0.10, 0)
		add_child(marker)
		var marker_tw := create_tween().bind_node(marker).set_loops()
		marker_tw.tween_property(marker, "transparency", 0.75, 0.18)
		marker_tw.tween_property(marker, "transparency", 0.05, 0.18)
		var timer := get_tree().create_timer(1.5)
		timer.timeout.connect(marker.queue_free)
	get_tree().create_timer(1.5).timeout.connect(func():
		_spawn_explosion(cells)
		_apply_explosion_damage(cells, player_index)
	)
	p["status"] = "Tianlao armed"

func _item_display_name(item_id: String) -> String:
	match item_id:
		"detonator": return "Detonator"
		"glue": return "Glue"
		"shield_potion": return "Shield Potion"
		"invincible_star": return "Invincible Star"
		"dummy": return "Dummy"
		"oil_barrel": return "Oil Barrel"
		"wings": return "Wings"
		"football_shoes": return "Football Shoes"
		"tianlao": return "Tianlao"
	return item_id.capitalize()

func _process(delta):
	if game_over:
		return
	if wave_manager:
		wave_manager.process_wave(delta)
	if weather_manager:
		weather_manager.process_weather(delta)
	_process_downed_players(delta)
	_process_terrain_effects(delta)
	_process_wall_mechanics(delta)
	_process_dynamic_items(delta)
	_update_hud()
	_process_player_input()
	_process_ai(delta)
	_update_weather_visibility()

func _process_downed_players(delta: float):
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if not p["alive"] or not bool(p.get("downed", false)):
			continue
		p["downed_timer"] = maxf(float(p["downed_timer"]) - delta, 0.0)
		p["status"] = "Downed %.1fs" % float(p["downed_timer"])
		if _consume_dummy_if_available(p):
			_revive_player(i)
		elif float(p["downed_timer"]) <= 0.0:
			_kill_player(i)

func _process_terrain_effects(delta: float):
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if not p["alive"] or bool(p.get("downed", false)):
			continue
		var had_wings := float(p.get("wings_timer", 0.0)) > 0.0
		p["invincible_timer"] = maxf(float(p.get("invincible_timer", 0.0)) - delta, 0.0)
		p["wings_timer"] = maxf(float(p.get("wings_timer", 0.0)) - delta, 0.0)
		p["football_timer"] = maxf(float(p.get("football_timer", 0.0)) - delta, 0.0)
		p["slow_timer"] = maxf(float(p.get("slow_timer", 0.0)) - delta, 0.0)
		if had_wings and float(p["wings_timer"]) <= 0.0:
			_end_wings(p)
		p["frozen_timer"] = maxf(float(p.get("frozen_timer", 0.0)) - delta, 0.0)
		var cell: Vector2i = p["grid_pos"]
		var cell_type: int = grid[cell.y][cell.x]
		var status_parts: Array = []

		if cell_type == Cell.FOREST:
			status_parts.append("Hidden")
		if cell_type == Cell.LAVA and float(p["wings_timer"]) <= 0.0:
			p["lava_time"] = float(p["lava_time"]) + delta
			status_parts.append("Burning %.1fs" % maxf(LAVA_DAMAGE_TIME - float(p["lava_time"]), 0.0))
			if float(p["lava_time"]) >= LAVA_DAMAGE_TIME:
				p["lava_time"] = 0.0
				_damage_player(i, 1, "lava")
		else:
			p["lava_time"] = 0.0

		if int(p.get("shield", 0)) > 0:
			status_parts.append("Shield %d" % int(p["shield"]))
		if float(p.get("frozen_timer", 0.0)) > 0.0:
			status_parts.append("Frozen %.1fs" % float(p["frozen_timer"]))
		if float(p["invincible_timer"]) > 0.0:
			status_parts.append("Invincible %.1fs" % float(p["invincible_timer"]))
		if float(p["wings_timer"]) > 0.0:
			status_parts.append("Wings %.1fs" % float(p["wings_timer"]))
		if float(p["football_timer"]) > 0.0:
			status_parts.append("Football %.1fs" % float(p["football_timer"]))
		if float(p["slow_timer"]) > 0.0:
			status_parts.append("Glued %.1fs" % float(p["slow_timer"]))
		if status_parts.is_empty():
			p["status"] = "Ready"
		else:
			p["status"] = " / ".join(status_parts)

func _process_dynamic_items(delta: float):
	for raw_cell in glue_areas.keys():
		var cell := raw_cell as Vector2i
		var data: Dictionary = glue_areas[cell]
		data["time"] = float(data["time"]) - delta
		if float(data["time"]) <= 0.0:
			var node = data.get("node")
			if is_instance_valid(node):
				node.queue_free()
			glue_areas.erase(cell)
			continue
		for i in range(players.size()):
			if i != int(data["owner"]) and players[i]["alive"] and players[i]["grid_pos"] == cell:
				players[i]["slow_timer"] = 3.0

func _end_wings(p: Dictionary):
	var cell := p["grid_pos"] as Vector2i
	if _is_walkable_cell(grid[cell.y][cell.x]) and not bomb_map.has(cell) and not oil_barrels.has(cell):
		return
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var target: Vector2i = cell + direction
		if target.x < 0 or target.x >= GRID_W or target.y < 0 or target.y >= GRID_H:
			continue
		if _is_walkable_cell(grid[target.y][target.x]) and not bomb_map.has(target) and not oil_barrels.has(target) and not _is_cell_occupied(target):
			p["grid_pos"] = target
			var node = p.get("node")
			if is_instance_valid(node):
				node.position = _grid_to_world(target)
			return

func _process_player_input():
	if players.is_empty():
		return
	var p: Dictionary = players[0]
	if not p["alive"] or bool(p.get("downed", false)):
		bomb_pressed = false
		return

	if bomb_pressed or Input.is_action_just_pressed("p1_bomb"):
		bomb_pressed = false
		_handle_player_bomb_action()
	else:
		bomb_pressed = false

	var held_dir := _read_player_move_dir()
	if not p["is_moving"] and held_dir != Vector2i.ZERO:
		_try_move_player(0, held_dir)

func _handle_player_bomb_action():
	var p: Dictionary = players[0]
	if float(p.get("football_timer", 0.0)) > 0.0:
		_kick_bomb_in_direction(p)
	elif int(p["bomb_placed_count"]) < int(p["bomb_max"]):
		_try_place_bomb(0)

func _read_player_move_dir() -> Vector2i:
	var d := Vector2i.ZERO
	if Input.is_action_pressed("p1_up"):
		d.y -= 1
	if Input.is_action_pressed("p1_down"):
		d.y += 1
	if Input.is_action_pressed("p1_left"):
		d.x -= 1
	if Input.is_action_pressed("p1_right"):
		d.x += 1
	if d.x != 0:
		d.y = 0
	return d

func _process_ai(delta: float):
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if not p["ai"] or not p["alive"] or bool(p.get("downed", false)):
			continue
		if float(p.get("frozen_timer", 0.0)) > 0.0:
			continue
		if bool(p.get("is_minion", false)) and not players.is_empty():
			if _grid_distance(p["grid_pos"], players[0]["grid_pos"]) <= 1:
				_explode_clone_minion(i)
				continue
		if str(p.get("boss_id", "")) != "":
			_process_boss_skill(i, delta)

		_update_ai_target_memory(p)
		p["move_timer"] += delta
		p["bomb_timer"] += delta
		if p["is_moving"]:
			continue

		var danger_escape := _ai_escape_dir_from_active_bombs(i)
		if danger_escape != Vector2i.ZERO:
			p["move_dir"] = danger_escape
			if _try_move_player(i, danger_escape):
				p["move_timer"] = 0.0
				continue
			p["move_dir"] = Vector2i.ZERO

		if p["bomb_timer"] >= p["bomb_interval"] and p["bomb_placed_count"] < p["bomb_max"] and _ai_should_place_bomb(i):
			p["bomb_timer"] = 0.0
			var escape_dir := _ai_escape_dir_after_bomb(i)
			if escape_dir != Vector2i.ZERO:
				_try_place_bomb(i)
				p["last_bomb_pos"] = p["grid_pos"]
				p["move_dir"] = escape_dir
				if _try_move_player(i, escape_dir):
					p["move_timer"] = 0.0
					continue

		if p["move_timer"] < p["move_interval"]:
			continue
		p["move_timer"] = 0.0
		p["move_dir"] = _choose_ai_direction(p)
		if p["move_dir"] != Vector2i.ZERO and not _try_move_player(i, p["move_dir"]):
			p["move_dir"] = Vector2i.ZERO
			p["move_timer"] = float(p["move_interval"]) * 0.75

func _update_ai_target_memory(p: Dictionary):
	if str(p.get("ai_difficulty", "normal")) != "hard" or players.is_empty():
		return
	var target: Dictionary = players[0]
	if not target["alive"] or (weather_manager and not weather_manager.can_see(p["grid_pos"], target["grid_pos"])):
		return
	p["last_seen_player_pos"] = target["grid_pos"]

func _ai_should_place_bomb(player_index: int) -> bool:
	var p: Dictionary = players[player_index]
	var difficulty := str(p.get("ai_difficulty", "normal"))
	var blast_cells := _blast_cell_set(p["grid_pos"], p["bomb_range"])
	if difficulty == "hard" and _is_player_hidden(0) and blast_cells.has(players[0]["grid_pos"]):
		return true
	for i: int in range(players.size()):
		if i == player_index:
			continue
		var target: Dictionary = players[i]
		if target["alive"] and not _is_player_hidden(i) and blast_cells.has(target["grid_pos"]):
			return true

	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for d in dirs:
		var check: Vector2i = p["grid_pos"] + d
		if check.x >= 0 and check.x < GRID_W and check.y >= 0 and check.y < GRID_H and grid[check.y][check.x] == Cell.CRATE:
			return true
	if difficulty == "hard":
		for cell in blast_cells.keys():
			var c := cell as Vector2i
			if grid[c.y][c.x] == Cell.CRATE:
				return true
	return false

func _is_player_hidden(index: int) -> bool:
	if index < 0 or index >= players.size():
		return false
	var p: Dictionary = players[index]
	var cell: Vector2i = p["grid_pos"]
	return p["alive"] and grid[cell.y][cell.x] == Cell.FOREST

func _try_move_player(index: int, dir: Vector2i) -> bool:
	if index < 0 or index >= players.size():
		return false
	var p: Dictionary = players[index]
	if not bool(p.get("alive", false)) or bool(p.get("downed", false)) or bool(p.get("is_moving", false)):
		return false
	if float(p.get("frozen_timer", 0.0)) > 0.0:
		return false
	var target: Vector2i = p["grid_pos"] + dir
	if not is_cell_walkable(target.x, target.y, index):
		return false
	var node: Node3D = p["node"]
	if not is_instance_valid(node):
		return false

	p["grid_pos"] = target
	p["last_move_dir"] = dir
	if (p["elevated_cell"] as Vector2i) != Vector2i(-1, -1):
		_clear_wall_warning(p)
		p["elevated_cell"] = Vector2i(-1, -1)
		p["wall_stay_timer"] = 0.0
	p["is_moving"] = true
	node.look_at(_grid_to_world(target), Vector3.UP)
	var tw := create_tween().bind_node(node)
	p["move_tween"] = tw
	var effective_speed := _effective_move_speed(p, target)
	var move_duration := _move_duration_for_speed(effective_speed)
	if float(p.get("slow_timer", 0.0)) > 0.0:
		move_duration *= 3.33
	var target_height := 0.92 if float(p.get("wings_timer", 0.0)) > 0.0 else 0.0
	tw.tween_property(node, "position", _grid_to_world(target) + Vector3(0, target_height, 0), move_duration).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func():
		p["move_tween"] = null
		p["is_moving"] = false
		if bool(p.get("alive", false)) and not bool(p.get("downed", false)):
			_check_powerup_pickup(index)
	)
	return true

func _effective_move_speed(p: Dictionary, target: Vector2i) -> int:
	var effective_speed := int(p["speed"])
	if weather_manager:
		effective_speed = weather_manager.movement_speed(effective_speed, target)
	return effective_speed

func _move_duration_for_speed(speed_value: int) -> float:
	var normalized_speed := clampi(speed_value, 1, 10) - 1
	return clampf(0.31 / (1.0 + 0.14 * float(normalized_speed)), 0.12, 0.31)

func is_cell_walkable(x: int, y: int, player_index := -1) -> bool:
	if x < 0 or x >= GRID_W or y < 0 or y >= GRID_H:
		return false
	var has_wings := player_index >= 0 and player_index < players.size() and float(players[player_index].get("wings_timer", 0.0)) > 0.0
	if grid[y][x] == Cell.WALL or (not has_wings and not _is_walkable_cell(grid[y][x])):
		return false
	var cell := Vector2i(x, y)
	if oil_barrels.has(cell) and not has_wings:
		return false
	if bomb_map.has(cell) and not has_wings and not _can_player_pass_bomb(player_index, cell):
		return false
	for p in players:
		if p["alive"] and p["grid_pos"] == Vector2i(x, y):
			return false
	return true

func _can_player_pass_bomb(player_index: int, cell: Vector2i) -> bool:
	if player_index < 0 or player_index >= players.size() or not bomb_map.has(cell):
		return false
	var entry: Dictionary = bomb_map[cell]
	if int(entry.get("player_index", -1)) != player_index:
		return false
	var p: Dictionary = players[player_index]
	return _game_time() <= float(p.get("bomb_hop_until", -99.0)) and (p.get("bomb_hop_cells", {}) as Dictionary).has(cell)

func _is_walkable_cell(cell_value: int) -> bool:
	return cell_value == Cell.EMPTY or cell_value == Cell.FOREST or cell_value == Cell.LAVA

func _try_place_bomb(player_index: int) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var p: Dictionary = players[player_index]
	var cell: Vector2i = p["grid_pos"]
	if bomb_map.has(cell):
		return false

	var placed_at := _game_time()
	var previous_cell := p["last_bomb_pos"] as Vector2i
	if previous_cell != Vector2i(-1, -1) and _grid_distance(previous_cell, cell) == 1 and placed_at - float(p["last_bomb_place_time"]) <= BOMB_HOP_WINDOW:
		p["bomb_hop_until"] = placed_at + BOMB_HOP_WINDOW
		p["bomb_hop_cells"] = {previous_cell: true, cell: true}
	p["last_bomb_pos"] = cell
	p["last_bomb_place_time"] = placed_at

	p["bomb_placed_count"] += 1
	var bomb := Node3D.new()
	bomb.name = "Bomb_%d_%d" % [cell.x, cell.y]
	bomb.position = _grid_to_world(cell) + Vector3(0, 0.38, 0)
	var shell := _sphere(0.42, mat_bomb)
	bomb.add_child(shell)
	add_child(bomb)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = BOMB_FUSE
	timer.timeout.connect(func(): _explode_bomb_by_node(bomb))
	bomb.add_child(timer)
	timer.start()

	var pulse := create_tween().set_loops()
	pulse.tween_property(bomb, "scale", Vector3(1.12, 1.12, 1.12), 0.35)
	pulse.tween_property(bomb, "scale", Vector3.ONE, 0.35)

	bomb_map[cell] = {"node": bomb, "player_index": player_index, "range": p["bomb_range"], "pulse": pulse, "timer": timer, "placed_at": placed_at}
	return true

func _game_time() -> float:
	return Time.get_ticks_msec() / 1000.0

func _explode_bomb_by_node(bomb_node: Node3D):
	for raw_cell in bomb_map.keys():
		var cell := raw_cell as Vector2i
		if (bomb_map[cell] as Dictionary).get("node") == bomb_node:
			_explode_bomb(cell)
			return

func _kick_bomb_in_direction(p: Dictionary):
	var direction := p["last_move_dir"] as Vector2i
	var origin: Vector2i = p["grid_pos"] + direction
	if not bomb_map.has(origin):
		p["status"] = "No bomb to kick"
		return
	var destination := origin
	var hit_obstacle := false
	for step in range(4):
		var target: Vector2i = destination + direction
		if target.x < 0 or target.x >= GRID_W or target.y < 0 or target.y >= GRID_H:
			hit_obstacle = true
			break
		if grid[target.y][target.x] in [Cell.WALL, Cell.CRATE] or oil_barrels.has(target) or bomb_map.has(target):
			hit_obstacle = true
			break
		destination = target
	if destination == origin:
		_explode_bomb(origin)
		return
	var entry: Dictionary = bomb_map[origin]
	bomb_map.erase(origin)
	bomb_map[destination] = entry
	var node = entry.get("node")
	if is_instance_valid(node):
		var tw := create_tween().bind_node(node)
		tw.tween_property(node, "position", _grid_to_world(destination) + Vector3(0, 0.38, 0), 0.18)
		if hit_obstacle:
			tw.tween_callback(func(): _explode_bomb(destination))
	p["status"] = "Bomb kicked"

func _explode_bomb(cell: Vector2i):
	if not bomb_map.has(cell):
		return
	var entry: Dictionary = bomb_map[cell]
	var player_index: int = entry["player_index"]
	if player_index >= 0 and player_index < players.size():
		players[player_index]["bomb_placed_count"] = max(players[player_index]["bomb_placed_count"] - 1, 0)

	var bomb: Node3D = entry["node"]
	var pulse: Tween = entry["pulse"]
	if is_instance_valid(pulse):
		pulse.kill()
	bomb_map.erase(cell)

	var results: Dictionary = _get_explosion_cells(cell, entry["range"], true)
	_spawn_explosion(results["cells"])
	_apply_explosion_damage(results["cells"], player_index, cell)
	if is_instance_valid(bomb):
		bomb.queue_free()

func _get_explosion_cells(origin: Vector2i, blast_range: int, apply_weather := false) -> Dictionary:
	var cells: Array = [origin]
	var directions: Array = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for dir in directions:
		var direction_range := blast_range
		if apply_weather and weather_manager and weather_manager.should_extend_wind(dir as Vector2i):
			direction_range += 1
		for i in range(1, direction_range + 1):
			var check: Vector2i = origin + (dir as Vector2i) * i
			if check.x < 0 or check.x >= GRID_W or check.y < 0 or check.y >= GRID_H:
				break
			if grid[check.y][check.x] == Cell.WALL:
				break
			cells.append(check)
			if grid[check.y][check.x] == Cell.CRATE or oil_barrels.has(check):
				break
	return {"cells": cells}

func _spawn_explosion(cells: Array):
	for raw_cell in cells:
		var cell := raw_cell as Vector2i
		var flame := _box(Vector3(TILE_SIZE * 0.86, 0.16, TILE_SIZE * 0.86), mat_fire)
		flame.position = _grid_to_world(cell) + Vector3(0, 0.12, 0)
		add_child(flame)
		var tw := create_tween().set_parallel()
		tw.tween_property(flame, "scale", Vector3(1.12, 1.0, 1.12), 0.08)
		tw.tween_property(flame, "transparency", 1.0, 0.35).set_delay(0.18)
		tw.set_parallel(false)
		tw.tween_callback(flame.queue_free).set_delay(0.35)

func _apply_explosion_damage(cells: Array, explosion_owner := -1, exploding_cell := Vector2i(-1, -1)):
	for raw_cell in cells:
		var cell := raw_cell as Vector2i
		if grid[cell.y][cell.x] == Cell.CRATE:
			grid[cell.y][cell.x] = Cell.EMPTY
			if crate_nodes.has(cell):
				var crate: Node3D = crate_nodes[cell]
				var tw := create_tween()
				tw.tween_property(crate, "scale", Vector3(1.2, 0.2, 1.2), 0.16)
				tw.tween_callback(crate.queue_free)
				crate_nodes.erase(cell)
			_spawn_powerup(cell)
		if oil_barrels.has(cell):
			_damage_oil_barrel(cell)

		for i in range(players.size()):
			var p: Dictionary = players[i]
			if p["alive"] and p["grid_pos"] == cell:
				if i == explosion_owner and _try_bomb_boost(i, exploding_cell):
					continue
				_damage_player(i, 1, "blast")

func _damage_oil_barrel(cell: Vector2i):
	if not oil_barrels.has(cell):
		return
	var data: Dictionary = oil_barrels[cell]
	data["hp"] = int(data["hp"]) - 1
	if int(data["hp"]) > 0:
		var node = data.get("node")
		if is_instance_valid(node):
			var tw := create_tween().bind_node(node)
			tw.tween_property(node, "scale", Vector3(1.12, 0.86, 1.12), 0.07)
			tw.tween_property(node, "scale", Vector3.ONE, 0.09)
		return
	var owner := int(data.get("owner", -1))
	var node = data.get("node")
	oil_barrels.erase(cell)
	if is_instance_valid(node):
		node.queue_free()
	var result := _get_explosion_cells(cell, 2, true)
	_spawn_explosion(result["cells"])
	_apply_explosion_damage(result["cells"], owner, cell)

func _try_bomb_boost(player_index: int, _exploding_cell: Vector2i) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var p: Dictionary = players[player_index]
	if bool(p.get("downed", false)) or (p["elevated_cell"] as Vector2i) != Vector2i(-1, -1):
		return false
	var covering_bombs := 1
	for raw_cell in bomb_map.keys():
		var bomb_cell := raw_cell as Vector2i
		var entry: Dictionary = bomb_map[bomb_cell]
		if int(entry.get("player_index", -1)) != player_index:
			continue
		if _blast_cell_set(bomb_cell, int(entry["range"])).has(p["grid_pos"]):
			covering_bombs += 1
	if covering_bombs < 2:
		return false

	var directions := [p["last_move_dir"] as Vector2i, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var target := Vector2i(-1, -1)
	for direction in directions:
		var candidate: Vector2i = p["grid_pos"] + direction
		if candidate.x < 0 or candidate.x >= GRID_W or candidate.y < 0 or candidate.y >= GRID_H:
			continue
		if grid[candidate.y][candidate.x] not in [Cell.WALL, Cell.CRATE]:
			continue
		var occupied := false
		for other: Dictionary in players:
			if other != p and other["alive"] and other["grid_pos"] == candidate:
				occupied = true
				break
		if not occupied:
			target = candidate
			break
	if target == Vector2i(-1, -1):
		return false

	_cancel_player_movement(p)
	p["grid_pos"] = target
	p["elevated_cell"] = target
	p["wall_stay_timer"] = 0.0
	p["wall_warning"] = false
	p["status"] = "Bomb Boost"
	var node = p.get("node")
	if is_instance_valid(node):
		var height := 1.30 if grid[target.y][target.x] == Cell.WALL else 0.98
		var tw := create_tween().bind_node(node)
		tw.tween_property(node, "position", _grid_to_world(target) + Vector3(0, height, 0), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return true

func _process_wall_mechanics(delta: float):
	for p: Dictionary in players:
		if not p["alive"]:
			continue
		var cell := p["elevated_cell"] as Vector2i
		if cell == Vector2i(-1, -1):
			continue
		if grid[cell.y][cell.x] == Cell.CRATE:
			continue
		if grid[cell.y][cell.x] != Cell.WALL:
			_drop_player_from_block(p)
			continue
		p["wall_stay_timer"] = float(p["wall_stay_timer"]) + delta
		if float(p["wall_stay_timer"]) >= WALL_WARNING_TIME and not bool(p["wall_warning"]):
			p["wall_warning"] = true
			p["status"] = "Wall unstable"
			_set_wall_warning(cell, true)
		if float(p["wall_stay_timer"]) >= WALL_DESTROY_TIME:
			_destroy_wall(cell)
			_drop_player_from_block(p)

	for raw_cell in destroyed_walls.keys():
		var cell := raw_cell as Vector2i
		destroyed_walls[cell] = float(destroyed_walls[cell]) + delta
		if float(destroyed_walls[cell]) < WALL_RESTORE_TIME:
			continue
		if bomb_map.has(cell) or _is_cell_occupied(cell):
			continue
		grid[cell.y][cell.x] = Cell.WALL
		var wall = wall_nodes.get(cell)
		if is_instance_valid(wall):
			wall.visible = true
			wall.transparency = 0.0
		destroyed_walls.erase(cell)

func _destroy_wall(cell: Vector2i):
	grid[cell.y][cell.x] = Cell.EMPTY
	destroyed_walls[cell] = 0.0
	var wall = wall_nodes.get(cell)
	if is_instance_valid(wall):
		wall.transparency = 0.0
		wall.visible = false

func _drop_player_from_block(p: Dictionary):
	_clear_wall_warning(p)
	p["elevated_cell"] = Vector2i(-1, -1)
	p["wall_stay_timer"] = 0.0
	var node = p.get("node")
	if is_instance_valid(node):
		var tw := create_tween().bind_node(node)
		tw.tween_property(node, "position", _grid_to_world(p["grid_pos"]), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _clear_wall_warning(p: Dictionary):
	if not bool(p.get("wall_warning", false)):
		return
	_set_wall_warning(p["elevated_cell"] as Vector2i, false)
	p["wall_warning"] = false

func _set_wall_warning(cell: Vector2i, enabled: bool):
	var wall = wall_nodes.get(cell)
	if is_instance_valid(wall):
		wall.transparency = 0.45 if enabled else 0.0

func _is_cell_occupied(cell: Vector2i) -> bool:
	for p: Dictionary in players:
		if p["alive"] and p["grid_pos"] == cell:
			return true
	return false

func _spawn_powerup(cell: Vector2i):
	var r := randf()
	var ptype := ""
	var mat: Material = null
	if r < 0.23:
		ptype = "speed"
		mat = mat_speed
	elif r < 0.46:
		ptype = "bomb"
		mat = mat_bomb_power
	elif r < 0.66:
		ptype = "range"
		mat = mat_range
	elif r < 0.79:
		ptype = "shield"
		mat = mat_shield
	elif r < 0.95:
		ptype = str(CONSUMABLE_IDS.pick_random())
		mat = mat_dummy if ptype == "dummy" else mat_consumable
	else:
		return

	var node := _create_powerup_model(ptype, mat)
	node.position = _grid_to_world(cell) + Vector3(0, 0.32, 0)
	add_child(node)
	powerups[cell] = {"node": node, "type": ptype}

func _create_powerup_model(ptype: String, mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Powerup_%s" % ptype

	var base := _cylinder(0.32, 0.10, _make_mat(Color(0.08, 0.09, 0.10)))
	base.position = Vector3(0, -0.20, 0)
	root.add_child(base)

	match ptype:
		"speed":
			var arrow_body := _box(Vector3(0.18, 0.12, 0.48), mat)
			arrow_body.position = Vector3(0, 0.02, 0.02)
			root.add_child(arrow_body)

			var arrow_head := _box(Vector3(0.42, 0.14, 0.22), mat)
			arrow_head.position = Vector3(0, 0.04, -0.30)
			arrow_head.rotation_degrees = Vector3(0, 45, 0)
			root.add_child(arrow_head)

			var trail := _box(Vector3(0.36, 0.08, 0.12), _make_mat(Color(0.45, 1.0, 0.95), true))
			trail.position = Vector3(0, -0.02, 0.34)
			root.add_child(trail)
		"bomb":
			var mini_bomb := _sphere(0.26, mat_bomb)
			mini_bomb.position = Vector3(0, 0.05, 0)
			root.add_child(mini_bomb)

			var fuse := _cylinder(0.045, 0.28, _make_mat(Color(0.95, 0.65, 0.18), true))
			fuse.position = Vector3(0.12, 0.30, -0.08)
			fuse.rotation_degrees = Vector3(0, 0, 35)
			root.add_child(fuse)

			var spark := _sphere(0.08, _make_mat(Color(1.0, 0.85, 0.20), true))
			spark.position = Vector3(0.22, 0.42, -0.12)
			root.add_child(spark)
		"range":
			var core := _cylinder(0.18, 0.52, mat)
			core.position = Vector3(0, 0.10, 0)
			root.add_child(core)

			var flame_top := _sphere(0.20, _make_mat(Color(1.0, 0.40, 0.08), true))
			flame_top.position = Vector3(0, 0.42, 0)
			flame_top.scale = Vector3(0.75, 1.25, 0.75)
			root.add_child(flame_top)

			var glow := _sphere(0.34, _make_mat(Color(1.0, 0.18, 0.05), true, tex_powerup))
			glow.position = Vector3(0, 0.12, 0)
			glow.scale = Vector3(1.0, 0.45, 1.0)
			root.add_child(glow)
		"shield":
			var core := _sphere(0.20, mat)
			core.position = Vector3(0, 0.12, 0)
			root.add_child(core)

			var front := _box(Vector3(0.46, 0.08, 0.12), mat)
			front.position = Vector3(0, 0.12, -0.34)
			root.add_child(front)

			var back := _box(Vector3(0.46, 0.08, 0.12), mat)
			back.position = Vector3(0, 0.12, 0.34)
			root.add_child(back)

			var left := _box(Vector3(0.12, 0.08, 0.46), mat)
			left.position = Vector3(-0.34, 0.12, 0)
			root.add_child(left)

			var right := _box(Vector3(0.12, 0.08, 0.46), mat)
			right.position = Vector3(0.34, 0.12, 0)
			root.add_child(right)
		"dummy":
			var body := _capsule(0.18, 0.54, mat)
			body.position = Vector3(0, 0.15, 0)
			root.add_child(body)

			var head := _sphere(0.16, mat)
			head.position = Vector3(0, 0.50, 0)
			root.add_child(head)

			var face := _box(Vector3(0.18, 0.04, 0.04), _make_mat(Color(0.12, 0.08, 0.04)))
			face.position = Vector3(0, 0.52, -0.15)
			root.add_child(face)
		"oil_barrel":
			var barrel := _cylinder(0.25, 0.58, mat_oil)
			barrel.position = Vector3(0, 0.12, 0)
			root.add_child(barrel)
			var band := _cylinder(0.27, 0.08, mat_bomb_power)
			band.position = Vector3(0, 0.14, 0)
			root.add_child(band)
		"wings":
			var left_wing := _box(Vector3(0.10, 0.40, 0.34), mat)
			left_wing.position = Vector3(-0.22, 0.20, 0)
			left_wing.rotation_degrees.z = -25
			root.add_child(left_wing)
			var right_wing := _box(Vector3(0.10, 0.40, 0.34), mat)
			right_wing.position = Vector3(0.22, 0.20, 0)
			right_wing.rotation_degrees.z = 25
			root.add_child(right_wing)
		_:
			var orb := _sphere(0.28, mat)
			root.add_child(orb)

	var tw := create_tween().set_loops()
	tw.tween_property(root, "rotation_degrees:y", 360.0, 2.4).as_relative()
	return root

func _check_powerup_pickup(index: int):
	var p: Dictionary = players[index]
	var cell: Vector2i = p["grid_pos"]
	if not powerups.has(cell):
		return

	var data: Dictionary = powerups[cell]
	if CONSUMABLE_IDS.has(str(data["type"])) and (p["consumables"] as Array).size() >= MAX_CONSUMABLES:
		p["status"] = "Bag full"
		return
	var node: Node3D = data["node"]
	if is_instance_valid(node):
		node.queue_free()

	match data["type"]:
		"speed":
			p["speed"] = clampi(p["speed"] + 1, 1, 10)
		"bomb":
			p["bomb_max"] = clampi(p["bomb_max"] + 1, 1, 8)
		"range":
			p["bomb_range"] = clampi(p["bomb_range"] + 2, 1, 10)
		"shield":
			p["shield"] = clampi(p["shield"] + 1, 0, 5)
		_:
			if CONSUMABLE_IDS.has(str(data["type"])):
				_add_consumable(p, str(data["type"]))
	powerups.erase(cell)

func _add_consumable(p: Dictionary, item_id: String) -> bool:
	var items: Array = p["consumables"]
	if items.size() >= MAX_CONSUMABLES:
		p["status"] = "Bag full"
		return false
	items.append(item_id)
	p["selected_consumable_index"] = clampi(int(p["selected_consumable_index"]), 0, items.size() - 1)
	p["status"] = "Picked %s" % _item_display_name(item_id)
	return true

func _consume_dummy_if_available(p: Dictionary) -> bool:
	var items: Array = p["consumables"]
	var index := items.find("dummy")
	if index == -1:
		return false
	items.remove_at(index)
	p["selected_consumable_index"] = clampi(int(p["selected_consumable_index"]), 0, maxi(items.size() - 1, 0))
	return true

func _choose_ai_direction(p: Dictionary) -> Vector2i:
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	dirs.shuffle()
	var danger_cells := _active_blast_cell_set()
	var walkable_cells: Dictionary = _ai_navigation_cells(p, danger_cells)
	var difficulty: String = str(p.get("ai_difficulty", "normal"))
	var can_target_player: bool = (
		not players.is_empty()
		and players[0]["alive"]
		and (difficulty == "hard" or not _is_player_hidden(0))
		and (not weather_manager or weather_manager.can_see(p["grid_pos"], players[0]["grid_pos"]))
	)
	var player_cell := Vector2i(-1, -1)
	if can_target_player:
		player_cell = players[0]["grid_pos"]
	var strategic_direction: Vector2i = AI_DECISION_POLICY.choose_direction(
		p,
		powerups,
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
		if is_cell_walkable(target.x, target.y) and not danger_cells.has(target) and not _is_lava_cell(target):
			return d
	for d in dirs:
		var target: Vector2i = p["grid_pos"] + d
		if is_cell_walkable(target.x, target.y) and not danger_cells.has(target):
			return d
	return Vector2i.ZERO

func _ai_navigation_cells(p: Dictionary, danger_cells: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var start: Vector2i = p["grid_pos"]
	var occupied: Dictionary = {}
	for other: Dictionary in players:
		if other["alive"] and other["grid_pos"] != start:
			occupied[other["grid_pos"]] = true
	for y: int in range(GRID_H):
		for x: int in range(GRID_W):
			var cell := Vector2i(x, y)
			if not _is_walkable_cell(grid[y][x]):
				continue
			if bomb_map.has(cell) or oil_barrels.has(cell) or occupied.has(cell):
				continue
			if danger_cells.has(cell) or _is_lava_cell(cell):
				continue
			result[cell] = true
	result[start] = true
	return result

func _is_lava_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= GRID_W or cell.y < 0 or cell.y >= GRID_H:
		return false
	return grid[cell.y][cell.x] == Cell.LAVA

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
	var p: Dictionary = players[player_index]
	var bomb_cell: Vector2i = p["grid_pos"]
	var blast_cells := _blast_cell_set(bomb_cell, p["bomb_range"])
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
	var p: Dictionary = players[player_index]
	var start: Vector2i = p["grid_pos"]
	var danger_cells := _active_blast_cell_set()
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

func _active_blast_cell_set() -> Dictionary:
	var result := {}
	for cell in bomb_map.keys():
		var entry: Dictionary = bomb_map[cell]
		var data: Dictionary = _get_explosion_cells(cell as Vector2i, entry["range"])
		for raw_cell in data["cells"]:
			result[raw_cell as Vector2i] = true
	return result

func _blast_cell_set(origin: Vector2i, blast_range_value: int) -> Dictionary:
	var result := {}
	var data: Dictionary = _get_explosion_cells(origin, blast_range_value)
	for raw_cell in data["cells"]:
		result[raw_cell as Vector2i] = true
	return result

func _is_ai_escape_walkable(cell: Vector2i, bomb_cell: Vector2i, player_index: int, simulated_bomb := false) -> bool:
	if cell.x < 0 or cell.x >= GRID_W or cell.y < 0 or cell.y >= GRID_H:
		return false
	if not _is_walkable_cell(grid[cell.y][cell.x]):
		return false
	if simulated_bomb and cell == bomb_cell:
		return false
	if bomb_map.has(cell):
		return false
	if oil_barrels.has(cell):
		return false
	for i in range(players.size()):
		if i == player_index:
			continue
		var other: Dictionary = players[i]
		if other["alive"] and other["grid_pos"] == cell:
			return false
	return true

func _on_wave_started(wave_number: int, enemy_count: int, boss_id: String):
	if weather_manager:
		weather_manager.start_wave(wave_number, _walkable_weather_cells())
	if boss_id != "":
		_spawn_boss(boss_id)
	_spawn_ai_wave(enemy_count)

func _walkable_weather_cells() -> Array:
	var cells: Array = []
	for y in range(1, GRID_H - 1):
		for x in range(1, GRID_W - 1):
			if _is_walkable_cell(grid[y][x]):
				cells.append(Vector2i(x, y))
	return cells

func _on_weather_changed(weather_type: String):
	for child in weather_visuals.get_children():
		child.queue_free()
	if world_environment:
		world_environment.fog_enabled = weather_type == "fog"
		world_environment.fog_light_color = Color(0.66, 0.70, 0.72)
		world_environment.fog_density = 0.075 if weather_type == "fog" else 0.0
		world_environment.background_color = Color(0.055, 0.065, 0.08) if weather_type in ["rain", "thunder"] else Color(0.07, 0.09, 0.12)
	match weather_type:
		"rain":
			_create_rain_visuals()
		"wind":
			_create_wind_visuals()
		"snow":
			_create_snow_visuals()

func _create_rain_visuals():
	var rain_mat := _make_mat(Color(0.35, 0.68, 0.92), true)
	for i in range(36):
		var drop := _box(Vector3(0.025, 0.65, 0.025), rain_mat)
		drop.position = Vector3(randf_range(-11.0, 11.0), randf_range(2.0, 8.0), randf_range(-7.5, 7.5))
		weather_visuals.add_child(drop)
		var tw := create_tween().bind_node(drop).set_loops()
		tw.tween_property(drop, "position:y", -0.1, randf_range(0.55, 0.90)).from(8.0)

func _create_wind_visuals():
	var wind_mat := _make_mat(Color(0.72, 0.92, 0.94), true)
	var dir3 := Vector3(weather_manager.wind_direction.x, 0, weather_manager.wind_direction.y)
	for i in range(12):
		var streak := _box(Vector3(0.7 if dir3.x != 0 else 0.04, 0.035, 0.7 if dir3.z != 0 else 0.04), wind_mat)
		streak.position = Vector3(randf_range(-10.0, 10.0), randf_range(0.6, 1.8), randf_range(-7.0, 7.0))
		weather_visuals.add_child(streak)
		var tw := create_tween().bind_node(streak).set_loops()
		tw.tween_property(streak, "position", streak.position + dir3 * 4.0, 1.2).from(streak.position - dir3 * 4.0)

func _create_snow_visuals():
	var snow_mat := _make_mat(Color(0.82, 0.92, 1.0), true)
	for raw_cell in weather_manager.snow_cells.keys():
		var cell := raw_cell as Vector2i
		var patch := _box(Vector3(TILE_SIZE * 0.82, 0.045, TILE_SIZE * 0.82), snow_mat)
		patch.position = _grid_to_world(cell) + Vector3(0, 0.08, 0)
		weather_visuals.add_child(patch)

func _request_thunder_strike():
	var cells := _walkable_weather_cells()
	if cells.is_empty():
		return
	var cell := cells.pick_random() as Vector2i
	var warning := _cylinder(0.58, 0.04, _make_mat(Color(1.0, 0.82, 0.12), true))
	warning.position = _grid_to_world(cell) + Vector3(0, 0.10, 0)
	weather_visuals.add_child(warning)
	var tw := create_tween().bind_node(warning)
	tw.tween_property(warning, "scale", Vector3(1.4, 1.0, 1.4), 0.35)
	tw.tween_property(warning, "scale", Vector3(0.75, 1.0, 0.75), 0.30)
	tw.tween_callback(func(): _strike_thunder(cell, warning))

func _strike_thunder(cell: Vector2i, warning: Node3D):
	if is_instance_valid(warning):
		warning.queue_free()
	var bolt := _box(Vector3(0.18, 7.0, 0.18), _make_mat(Color(0.75, 0.90, 1.0), true))
	bolt.position = _grid_to_world(cell) + Vector3(0, 3.5, 0)
	weather_visuals.add_child(bolt)
	var tw := create_tween().bind_node(bolt)
	tw.tween_property(bolt, "transparency", 1.0, 0.22)
	tw.tween_callback(bolt.queue_free)
	for i in range(players.size()):
		if players[i]["alive"] and players[i]["grid_pos"] == cell:
			_damage_player(i, 1, "thunder")

func _update_weather_visibility():
	if players.is_empty() or not weather_manager:
		return
	for i in range(1, players.size()):
		var p: Dictionary = players[i]
		var node = p.get("node")
		if is_instance_valid(node):
			(node as Node3D).visible = p["alive"] and weather_manager.can_see(players[0]["grid_pos"], p["grid_pos"])

func _process_boss_skill(index: int, delta: float):
	var boss: Dictionary = players[index]
	boss["skill_timer"] = float(boss["skill_timer"]) - delta
	if float(boss["skill_timer"]) > 0.0:
		return
	match str(boss["boss_id"]):
		"blast_king":
			boss["skill_timer"] = 3.5
			if int(boss["bomb_placed_count"]) < int(boss["bomb_max"]):
				_try_place_bomb(index)
			boss["bomb_timer"] = float(boss["bomb_interval"])
		"frost_giant":
			boss["skill_timer"] = 4.5
			_frost_giant_skill(index)
		"clone_demon":
			boss["skill_timer"] = 5.0
			call_deferred("_spawn_clone_minions", boss["grid_pos"])

func _frost_giant_skill(index: int):
	if players.is_empty() or not players[0]["alive"]:
		return
	var boss: Dictionary = players[index]
	var player: Dictionary = players[0]
	var delta: Vector2i = player["grid_pos"] - boss["grid_pos"]
	if absi(delta.x) <= 1 and absi(delta.y) <= 1:
		player["frozen_timer"] = 3.0
		player["status"] = "Frozen 3.0s"
		var freeze := _box(Vector3(TILE_SIZE * 0.9, 0.12, TILE_SIZE * 0.9), _make_mat(Color(0.45, 0.88, 1.0), true))
		freeze.position = _grid_to_world(player["grid_pos"]) + Vector3(0, 0.14, 0)
		add_child(freeze)
		var tw := create_tween()
		tw.tween_property(freeze, "transparency", 1.0, 3.0)
		tw.tween_callback(freeze.queue_free)
		return
	var charge_dir := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
	_frost_charge(index, charge_dir)

func _frost_charge(index: int, direction: Vector2i):
	var boss: Dictionary = players[index]
	var destination: Vector2i = boss["grid_pos"]
	for step in range(2):
		var target := destination + direction
		if not players.is_empty() and players[0]["alive"] and target == players[0]["grid_pos"]:
			_damage_player(0, 1, "frost charge")
			break
		if not is_cell_walkable(target.x, target.y):
			break
		destination = target
	if destination == boss["grid_pos"]:
		return
	boss["grid_pos"] = destination
	boss["is_moving"] = true
	var node: Node3D = boss["node"]
	node.look_at(_grid_to_world(destination), Vector3.UP)
	var tw := create_tween()
	tw.tween_property(node, "position", _grid_to_world(destination), 0.18)
	tw.tween_callback(func(): boss["is_moving"] = false)

func _spawn_clone_minions(origin: Vector2i):
	var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	directions.shuffle()
	var spawned := 0
	for raw_direction in directions:
		var direction := raw_direction as Vector2i
		var cell: Vector2i = origin + direction
		if not is_cell_walkable(cell.x, cell.y):
			continue
		var minion := _create_player(next_player_id, cell, true, mat_boss_clone, "ai")
		next_player_id += 1
		minion["is_minion"] = true
		minion["hp"] = 1
		minion["max_hp"] = 1
		minion["speed"] = 6
		minion["bomb_max"] = 0
		minion["move_interval"] = 0.18
		minion["ai_difficulty"] = "hard"
		minion["status"] = "Decoy"
		minion["node"].scale = Vector3(0.72, 0.72, 0.72)
		players.append(minion)
		spawned += 1
		if spawned >= 2:
			return

func _explode_clone_minion(index: int):
	var minion: Dictionary = players[index]
	var data := _get_explosion_cells(minion["grid_pos"], 1, true)
	_spawn_explosion(data["cells"])
	_apply_explosion_damage(data["cells"])
	if minion["alive"]:
		_kill_player(index)

func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _damage_player(index: int, amount: int, source: String):
	if index < 0 or index >= players.size():
		return
	var p: Dictionary = players[index]
	if not p["alive"]:
		return
	if float(p.get("invincible_timer", 0.0)) > 0.0:
		p["status"] = "Invincible"
		return
	if bool(p.get("downed", false)):
		if source == "blast":
			_kill_player(index)
		return
	if int(p.get("shield", 0)) > 0:
		p["shield"] = int(p["shield"]) - 1
		_flash_player_shield(p)
		return
	if str(p.get("boss_id", "")) != "" or bool(p.get("is_minion", false)):
		p["hp"] = maxi(int(p["hp"]) - amount, 0)
		p["status"] = "HP %d" % int(p["hp"])
		_flash_player_damage(p)
		if int(p["hp"]) <= 0:
			_kill_player(index)
		return
	p["hp"] = maxi(int(p["hp"]), 1)
	p["status"] = "Downed"
	_enter_downed(index, source)

func _enter_downed(index: int, source: String):
	var p: Dictionary = players[index]
	if not p["alive"]:
		return
	p["downed"] = true
	p["downed_timer"] = DOWNED_DURATION
	p["status"] = "Downed by %s" % source
	_cancel_player_movement(p)
	_cancel_player_state_animation(p)
	if index == 0:
		bomb_pressed = false
	var node: Node3D = p["node"]
	if is_instance_valid(node):
		var tw := create_tween().bind_node(node)
		p["state_tween"] = tw
		tw.tween_property(node, "scale", Vector3(1.0, 0.35, 1.0), 0.18)

func _revive_player(index: int):
	var p: Dictionary = players[index]
	p["downed"] = false
	p["downed_timer"] = 0.0
	p["hp"] = mini(2, int(p["max_hp"]))
	p["status"] = "Revived"
	p["is_moving"] = false
	_cancel_player_state_animation(p)
	var node: Node3D = p["node"]
	if is_instance_valid(node):
		var tw := create_tween().bind_node(node)
		p["state_tween"] = tw
		tw.tween_property(node, "scale", Vector3(1.12, 1.12, 1.12), 0.12)
		tw.tween_property(node, "scale", Vector3.ONE, 0.16)

func _kill_player(index: int):
	var p: Dictionary = players[index]
	if not p["alive"]:
		return
	p["alive"] = false
	p["downed"] = false
	p["downed_timer"] = 0.0
	p["status"] = "Defeated"
	_cancel_player_movement(p)
	_cancel_player_state_animation(p)
	if str(p.get("boss_id", "")) != "":
		_spawn_boss_reward(p["grid_pos"])
	var node = p.get("node")
	if not is_instance_valid(node):
		_check_game_over()
		return
	var tw := create_tween().bind_node(node)
	p["state_tween"] = tw
	tw.tween_property(node, "scale", Vector3(1.0, 0.05, 1.0), 0.35)
	tw.tween_callback(func():
		if is_instance_valid(node):
			p["node"] = null
			node.queue_free()
		p["state_tween"] = null
		_check_game_over()
	)

func _cancel_player_movement(p: Dictionary):
	var move_tween = p.get("move_tween")
	if move_tween is Tween and is_instance_valid(move_tween):
		(move_tween as Tween).kill()
	p["move_tween"] = null
	p["is_moving"] = false
	var node = p.get("node")
	if is_instance_valid(node):
		node.position = _grid_to_world(p["grid_pos"])

func _cancel_player_state_animation(p: Dictionary):
	var state_tween = p.get("state_tween")
	if state_tween is Tween and is_instance_valid(state_tween):
		(state_tween as Tween).kill()
	p["state_tween"] = null

func _spawn_boss_reward(cell: Vector2i):
	if powerups.has(cell):
		return
	var node := _create_powerup_model("dummy", mat_dummy)
	node.position = _grid_to_world(cell) + Vector3(0, 0.32, 0)
	add_child(node)
	powerups[cell] = {"node": node, "type": "dummy"}

func _flash_player_damage(p: Dictionary):
	var node: Node3D = p["node"]
	if not is_instance_valid(node):
		return
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3(1.12, 0.88, 1.12), 0.08)
	tw.tween_property(node, "scale", Vector3.ONE, 0.10)

func _flash_player_shield(p: Dictionary):
	var node: Node3D = p["node"]
	if not is_instance_valid(node):
		return
	var shield := _sphere(0.62, mat_shield)
	shield.transparency = 0.35
	node.add_child(shield)
	var tw := create_tween()
	tw.tween_property(shield, "scale", Vector3(1.35, 1.35, 1.35), 0.18)
	tw.tween_property(shield, "transparency", 1.0, 0.18)
	tw.tween_callback(shield.queue_free)

func _check_game_over():
	if players.is_empty():
		return
	if not players[0]["alive"]:
		game_over = true
		_show_result(2)
		return
	var hostile_count := 0
	for i in range(1, players.size()):
		if players[i]["alive"]:
			hostile_count += 1
	if wave_manager and wave_manager.is_final_wave() and hostile_count == 0:
		game_over = true
		_show_result(1)

func _show_result(winner_id: int):
	var layer := CanvasLayer.new()
	add_child(layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 250)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var label := Label.new()
	if winner_id == 0:
		label.text = "Draw!"
	elif winner_id == 1:
		label.text = "You Win!"
	else:
		label.text = "AI Wins!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.YELLOW)
	box.add_child(label)

	var hint := Label.new()
	hint.text = "Choose your next move"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	box.add_child(hint)

	var restart_btn := _make_result_button("Restart (R)")
	restart_btn.pressed.connect(func(): get_tree().reload_current_scene())
	box.add_child(restart_btn)

	var menu_btn := _make_result_button("Main Menu (Esc)")
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	box.add_child(menu_btn)

	var quit_btn := _make_result_button("Quit Game (Q)")
	quit_btn.pressed.connect(func(): get_tree().quit())
	box.add_child(quit_btn)

func _make_result_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 34)
	btn.add_theme_font_size_override("font_size", 18)
	return btn

func _update_hud():
	if hud_label == null or players.is_empty():
		return
	_position_status_cards()
	var p: Dictionary = players[0]
	var wave_text := "Wave -"
	var weather_text := "Clear"
	if wave_manager:
		wave_text = "Wave %d/7  %.0fs" % [wave_manager.current_wave, wave_manager.time_remaining()]
	if weather_manager:
		weather_text = weather_manager.display_name()
	hud_label.text = "%s  |  %s  |  AI %s  |  SPD %d  BOMB %d/%d  RNG %d  SH %d  BAG %d/%d" % [wave_text, weather_text, _difficulty_label(), p["speed"], p["bomb_placed_count"], p["bomb_max"], p["bomb_range"], p["shield"], (p["consumables"] as Array).size(), MAX_CONSUMABLES]
	_update_inventory_bar(p)
	if player_card_label:
		player_card_label.text = _player_card_text(players[0])
	if enemy_card_label:
		var featured := _featured_enemy()
		enemy_card_label.text = _player_card_text(featured) if not featured.is_empty() else "No enemies\nNext wave"

func _player_card_text(p: Dictionary) -> String:
	if not p["alive"]:
		return "HP 0/%d\nDown" % int(p["max_hp"])
	if bool(p.get("downed", false)):
		return "HP %d/%d\nDown %.1fs" % [int(p["hp"]), int(p["max_hp"]), float(p["downed_timer"])]
	var title := str(p.get("boss_name", ""))
	if title != "":
		return "%s  HP %d/%d\n%s" % [title, int(p["hp"]), int(p["max_hp"]), str(p["status"])]
	return "HP %d/%d\n%s" % [int(p["hp"]), int(p["max_hp"]), str(p["status"])]

func _featured_enemy() -> Dictionary:
	for i in range(1, players.size()):
		if players[i]["alive"] and str(players[i].get("boss_id", "")) != "":
			return players[i]
	for i in range(1, players.size()):
		if players[i]["alive"]:
			return players[i]
	return {}

func _bag_text(p: Dictionary) -> String:
	var items: Array = p.get("consumables", [])
	if items.is_empty():
		return "-"
	var names: Array[String] = []
	var selected := clampi(int(p.get("selected_consumable_index", 0)), 0, items.size() - 1)
	for i in range(items.size()):
		var item_name := _item_display_name(str(items[i]))
		names.append("[%s]" % item_name if i == selected else item_name)
	return ", ".join(names)

func _update_inventory_bar(p: Dictionary):
	var items: Array = p.get("consumables", [])
	var selected := clampi(int(p.get("selected_consumable_index", 0)), 0, maxi(items.size() - 1, 0))
	for i in range(inventory_slot_labels.size()):
		var slot := inventory_slot_labels[i]
		slot.text = _item_display_name(str(items[i])) if i < items.size() else "-"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.42, 0.50, 0.92) if i == selected and i < items.size() else Color(0.08, 0.09, 0.11, 0.86)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.40, 0.95, 0.78) if i == selected and i < items.size() else Color(0.25, 0.28, 0.32)
		slot.add_theme_stylebox_override("normal", style)

func _position_status_cards():
	if game_camera == null:
		return
	if player_card_panel:
		var player_pos := game_camera.unproject_position(_grid_to_world(Vector2i(2, 0)) + Vector3(0, 1.05, 0))
		player_card_panel.position = player_pos + Vector2(-78, -22)
	if enemy_card_panel:
		var enemy_pos := game_camera.unproject_position(_grid_to_world(Vector2i(GRID_W - 3, 0)) + Vector3(0, 1.05, 0))
		enemy_card_panel.position = enemy_pos + Vector2(-78, -22)

func _difficulty_label() -> String:
	match ai_difficulty:
		"easy":
			return "Easy"
		"hard":
			return "Hard"
		_:
			return "Normal"
