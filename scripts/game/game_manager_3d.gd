extends Node3D

const GRID_W := 15
const GRID_H := 11
const TILE_SIZE := 1.6
const FLOOR_Y := 0.0
const BOMB_FUSE := 2.5
const PLAYER_MAX_HP := 3
const LAVA_DAMAGE_TIME := 1.35
const AI_DECISION_POLICY := preload("res://scripts/character/AIDecisionPolicy.gd")

enum Cell { EMPTY, WALL, CRATE, FOREST, LAVA }

var grid: Array = []
var players: Array = []
var bomb_map: Dictionary = {}
var crate_nodes: Dictionary = {}
var powerups: Dictionary = {}
var game_over := false

var bomb_pressed := false
var hud_label: Label = null
var game_camera: Camera3D = null
var player_card_panel: PanelContainer = null
var player_card_label: Label = null
var enemy_card_panel: PanelContainer = null
var enemy_card_label: Label = null
var ai_difficulty := "normal"

var tex_floor: Texture2D = load("res://assets/art/3d/floor_tile.png")
var tex_wall: Texture2D = load("res://assets/art/3d/wall_block.png")
var tex_crate: Texture2D = load("res://assets/art/3d/crate_wood.png")
var tex_bomb: Texture2D = load("res://assets/art/3d/bomb_shell.png")
var tex_powerup: Texture2D = load("res://assets/art/3d/powerup_energy.png")
var tex_lava: Texture2D = load("res://assets/art/3d/lava_cracked.png")

var mat_floor_a := _make_mat(Color(0.70, 0.78, 0.66), false, tex_floor)
var mat_floor_b := _make_mat(Color(0.82, 0.88, 0.76), false, tex_floor)
var mat_wall := _make_mat(Color(0.72, 0.76, 0.82), false, tex_wall)
var mat_crate := _make_mat(Color(1.0, 0.88, 0.70), false, tex_crate)
var mat_player := _make_mat(Color(0.18, 0.48, 0.95))
var mat_ai := _make_mat(Color(0.95, 0.27, 0.22))
var mat_bomb := _make_mat(Color(0.75, 0.75, 0.78), false, tex_bomb)
var mat_fire := _make_mat(Color(1.0, 0.48, 0.08), true)
var mat_forest_floor := _make_mat(Color(0.18, 0.36, 0.18))
var mat_leaf := _make_mat(Color(0.10, 0.48, 0.16))
var mat_trunk := _make_mat(Color(0.42, 0.24, 0.11))
var mat_lava := _make_mat(Color(0.95, 0.18, 0.04), true, tex_lava)
var mat_lava_glow := _make_mat(Color(1.0, 0.65, 0.08), true, tex_lava)
var mat_speed := _make_mat(Color(0.2, 0.95, 0.85), true, tex_powerup)
var mat_bomb_power := _make_mat(Color(0.95, 0.92, 0.25), true, tex_powerup)
var mat_range := _make_mat(Color(1.0, 0.22, 0.12), true, tex_powerup)
var mat_shield := _make_mat(Color(0.35, 0.55, 1.0), true, tex_powerup)

func _ready():
	add_to_group("game")
	randomize()
	ai_difficulty = _load_ai_difficulty()
	_init_grid()
	_create_world()
	_spawn_players()
	_setup_camera()
	_setup_hud()

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
	add_child(world)

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
				var wall := _box(Vector3(TILE_SIZE * 0.94, 1.25, TILE_SIZE * 0.94), mat_wall)
				wall.position = _grid_to_world(cell) + Vector3(0, 0.62, 0)
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
	var root := Node3D.new()
	root.name = "Forest_%d_%d" % [cell.x, cell.y]
	root.position = _grid_to_world(cell)

	var offsets := [Vector3(-0.36, 0, -0.30), Vector3(0.34, 0, -0.14), Vector3(-0.04, 0, 0.34)]
	for offset in offsets:
		var trunk := _cylinder(0.08, 0.55, mat_trunk)
		trunk.position = offset + Vector3(0, 0.24, 0)
		root.add_child(trunk)

		var crown := _sphere(0.34, mat_leaf)
		crown.position = offset + Vector3(0, 0.72, 0)
		crown.scale = Vector3(1.0, 0.82, 1.0)
		root.add_child(crown)

	var cover := _box(Vector3(TILE_SIZE * 0.88, 0.08, TILE_SIZE * 0.88), _make_mat(Color(0.08, 0.30, 0.12), true))
	cover.position = Vector3(0, 0.10, 0)
	root.add_child(cover)
	return root

func _create_lava_tile(cell: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "Lava_%d_%d" % [cell.x, cell.y]
	root.position = _grid_to_world(cell)

	var pool := _box(Vector3(TILE_SIZE * 0.86, 0.10, TILE_SIZE * 0.86), mat_lava_glow)
	pool.position = Vector3(0, 0.03, 0)
	root.add_child(pool)

	var bubble := _sphere(0.16, mat_lava_glow)
	bubble.position = Vector3(0.28, 0.16, -0.22)
	bubble.scale = Vector3(1.0, 0.45, 1.0)
	root.add_child(bubble)
	var tw := create_tween().set_loops()
	tw.tween_property(bubble, "position:y", 0.28, 0.45)
	tw.tween_property(bubble, "position:y", 0.12, 0.45)
	return root

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
	players.append(player)
	var ai_player := _create_player(2, Vector2i(GRID_W - 2, GRID_H - 2), true, mat_ai, "ai")
	_apply_ai_difficulty(ai_player)
	players.append(ai_player)

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
		"is_moving": false,
		"speed": 5,
		"bomb_max": 1,
		"bomb_range": 2,
		"shield": 0,
		"suit": style,
		"lava_time": 0.0,
		"status": "Ready",
		"bomb_placed_count": 0,
		"ai": ai,
		"move_timer": 0.0,
		"move_interval": randf_range(0.3, 0.8),
		"bomb_timer": 0.0,
		"bomb_interval": randf_range(1.5, 3.5),
		"move_dir": Vector2i.ZERO,
		"last_bomb_pos": Vector2i(-1, -1),
		"last_seen_player_pos": Vector2i(-1, -1)
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
	_update_hud()

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

	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_SPACE: bomb_pressed = true
			KEY_ESCAPE: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func _process(delta):
	if game_over:
		return
	_process_terrain_effects(delta)
	_update_hud()
	_process_player_input()
	_process_ai(delta)

func _process_terrain_effects(delta: float):
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if not p["alive"]:
			continue
		var cell: Vector2i = p["grid_pos"]
		var cell_type: int = grid[cell.y][cell.x]
		var status_parts: Array = []

		if cell_type == Cell.FOREST:
			status_parts.append("Hidden")
		if cell_type == Cell.LAVA:
			p["lava_time"] = float(p["lava_time"]) + delta
			status_parts.append("Burning %.1fs" % maxf(LAVA_DAMAGE_TIME - float(p["lava_time"]), 0.0))
			if float(p["lava_time"]) >= LAVA_DAMAGE_TIME:
				p["lava_time"] = 0.0
				_damage_player(i, 1, "lava")
		else:
			p["lava_time"] = 0.0

		if int(p.get("shield", 0)) > 0:
			status_parts.append("Shield %d" % int(p["shield"]))
		if status_parts.is_empty():
			p["status"] = "Ready"
		else:
			p["status"] = " / ".join(status_parts)

func _process_player_input():
	if players.is_empty():
		return
	var p: Dictionary = players[0]
	if not p["alive"] or p["is_moving"]:
		return

	var d := _read_player_move_dir()

	if d != Vector2i.ZERO:
		_try_move_player(0, d)

	if (bomb_pressed or Input.is_action_just_pressed("p1_bomb")) and p["bomb_placed_count"] < p["bomb_max"]:
		bomb_pressed = false
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
		if not p["ai"] or not p["alive"]:
			continue

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
	if not target["alive"]:
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
	var p: Dictionary = players[index]
	var target: Vector2i = p["grid_pos"] + dir
	if not is_cell_walkable(target.x, target.y):
		return false

	p["grid_pos"] = target
	p["is_moving"] = true
	var node: Node3D = p["node"]
	node.look_at(_grid_to_world(target), Vector3.UP, true)
	var tw := create_tween()
	var move_duration := clampf(0.72 / float(p["speed"]), 0.10, 0.24)
	tw.tween_property(node, "position", _grid_to_world(target), move_duration)
	tw.tween_callback(func():
		p["is_moving"] = false
		_check_powerup_pickup(index)
	)
	return true

func is_cell_walkable(x: int, y: int) -> bool:
	if x < 0 or x >= GRID_W or y < 0 or y >= GRID_H:
		return false
	if not _is_walkable_cell(grid[y][x]):
		return false
	if bomb_map.has(Vector2i(x, y)):
		return false
	for p in players:
		if p["alive"] and p["grid_pos"] == Vector2i(x, y):
			return false
	return true

func _is_walkable_cell(cell_value: int) -> bool:
	return cell_value == Cell.EMPTY or cell_value == Cell.FOREST or cell_value == Cell.LAVA

func _try_place_bomb(player_index: int):
	var p: Dictionary = players[player_index]
	var cell: Vector2i = p["grid_pos"]
	if bomb_map.has(cell):
		return

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
	timer.timeout.connect(func(): _explode_bomb(cell))
	bomb.add_child(timer)
	timer.start()

	var pulse := create_tween().set_loops()
	pulse.tween_property(bomb, "scale", Vector3(1.12, 1.12, 1.12), 0.35)
	pulse.tween_property(bomb, "scale", Vector3.ONE, 0.35)

	bomb_map[cell] = {"node": bomb, "player_index": player_index, "range": p["bomb_range"], "pulse": pulse}

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

	var results: Dictionary = _get_explosion_cells(cell, entry["range"])
	_spawn_explosion(results["cells"])
	_apply_explosion_damage(results["cells"])
	if is_instance_valid(bomb):
		bomb.queue_free()

func _get_explosion_cells(origin: Vector2i, blast_range: int) -> Dictionary:
	var cells: Array = [origin]
	var directions: Array = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for dir in directions:
		for i in range(1, blast_range + 1):
			var check: Vector2i = origin + (dir as Vector2i) * i
			if check.x < 0 or check.x >= GRID_W or check.y < 0 or check.y >= GRID_H:
				break
			if grid[check.y][check.x] == Cell.WALL:
				break
			cells.append(check)
			if grid[check.y][check.x] == Cell.CRATE:
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

func _apply_explosion_damage(cells: Array):
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

		for i in range(players.size()):
			var p: Dictionary = players[i]
			if p["alive"] and p["grid_pos"] == cell:
				_damage_player(i, 1, "blast")

func _spawn_powerup(cell: Vector2i):
	var r := randf()
	var ptype := ""
	var mat: Material = null
	if r < 0.28:
		ptype = "speed"
		mat = mat_speed
	elif r < 0.53:
		ptype = "bomb"
		mat = mat_bomb_power
	elif r < 0.76:
		ptype = "range"
		mat = mat_range
	elif r < 0.95:
		ptype = "shield"
		mat = mat_shield
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
	powerups.erase(cell)

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
			if bomb_map.has(cell) or occupied.has(cell):
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
	for i in range(players.size()):
		if i == player_index:
			continue
		var other: Dictionary = players[i]
		if other["alive"] and other["grid_pos"] == cell:
			return false
	return true

func _damage_player(index: int, amount: int, source: String):
	var p: Dictionary = players[index]
	if not p["alive"]:
		return
	if int(p.get("shield", 0)) > 0:
		p["shield"] = int(p["shield"]) - 1
		_flash_player_shield(p)
		return
	p["hp"] = maxi(int(p["hp"]) - amount, 0)
	p["status"] = "Hit by %s" % source
	_flash_player_damage(p)
	if int(p["hp"]) <= 0:
		_kill_player(index)

func _kill_player(index: int):
	var p: Dictionary = players[index]
	if not p["alive"]:
		return
	p["alive"] = false
	var node: Node3D = p["node"]
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3(1.0, 0.05, 1.0), 0.35)
	tw.tween_callback(func():
		if is_instance_valid(node):
			node.queue_free()
		_check_game_over()
	)

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
	var alive_left := 0
	var winner_id := 0
	for p in players:
		if p["alive"]:
			alive_left += 1
			winner_id = p["id"]
	if alive_left <= 1:
		game_over = true
		_show_result(winner_id)

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
	hud_label.text = "AI: %s  |  Speed: %d  |  Bombs: %d/%d  |  Range: %d  |  Shields: %d  |  WASD + Space  |  Esc: Menu" % [_difficulty_label(), p["speed"], p["bomb_placed_count"], p["bomb_max"], p["bomb_range"], p["shield"]]
	if player_card_label:
		player_card_label.text = _player_card_text(players[0])
	if enemy_card_label and players.size() > 1:
		enemy_card_label.text = _player_card_text(players[1])

func _player_card_text(p: Dictionary) -> String:
	if not p["alive"]:
		return "HP 0/%d\nDown" % int(p["max_hp"])
	return "HP %d/%d\n%s" % [int(p["hp"]), int(p["max_hp"]), str(p["status"])]

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
