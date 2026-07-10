extends Node3D

const GRID_W := 15
const GRID_H := 11
const TILE_SIZE := 1.6
const FLOOR_Y := 0.0

enum Cell { EMPTY, WALL, CRATE, FOREST, LAVA }

var grid: Array = []
var selected_cell := Cell.WALL
var selected_label: Label = null
var map_root: Node3D = null
var camera: Camera3D = null

var tex_floor: Texture2D = load("res://assets/art/3d/floor_tile.png")
var tex_wall: Texture2D = load("res://assets/art/3d/wall_block.png")
var tex_crate: Texture2D = load("res://assets/art/3d/crate_wood.png")

var mat_floor_a := _make_mat(Color(0.70, 0.78, 0.66), false, tex_floor)
var mat_floor_b := _make_mat(Color(0.82, 0.88, 0.76), false, tex_floor)
var mat_wall := _make_mat(Color(0.72, 0.76, 0.82), false, tex_wall)
var mat_crate := _make_mat(Color(1.0, 0.88, 0.70), false, tex_crate)
var mat_forest_floor := _make_mat(Color(0.18, 0.36, 0.18))
var mat_leaf := _make_mat(Color(0.10, 0.48, 0.16))
var mat_trunk := _make_mat(Color(0.42, 0.24, 0.11))
var mat_lava := _make_mat(Color(0.95, 0.18, 0.04), true)
var mat_lava_glow := _make_mat(Color(1.0, 0.65, 0.08), true)

func _ready():
	set_process_input(true)
	_init_grid()
	_setup_scene()
	_setup_ui()
	_load_map(false)
	_refresh_view()

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

func _setup_scene():
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

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19.0
	camera.position = Vector3(0, 16, 12)
	camera.rotation_degrees = Vector3(-58, 0, 0)
	camera.current = true
	add_child(camera)

	map_root = Node3D.new()
	map_root.name = "EditableMap3D"
	add_child(map_root)

func _refresh_view():
	if is_instance_valid(map_root):
		map_root.queue_free()
	map_root = Node3D.new()
	map_root.name = "EditableMap3D"
	add_child(map_root)

	for y in GRID_H:
		for x in GRID_W:
			var cell := Vector2i(x, y)
			var floor := _box(Vector3(TILE_SIZE, 0.08, TILE_SIZE), _floor_mat_for_cell(x, y))
			floor.position = _grid_to_world(cell) + Vector3(0, -0.04, 0)
			map_root.add_child(floor)

			if grid[y][x] == Cell.WALL:
				var wall := _box(Vector3(TILE_SIZE * 0.94, 1.25, TILE_SIZE * 0.94), mat_wall)
				wall.position = _grid_to_world(cell) + Vector3(0, 0.62, 0)
				map_root.add_child(wall)
			elif grid[y][x] == Cell.CRATE:
				var crate := _box(Vector3(TILE_SIZE * 0.84, 0.92, TILE_SIZE * 0.84), mat_crate)
				crate.position = _grid_to_world(cell) + Vector3(0, 0.46, 0)
				map_root.add_child(crate)
			elif grid[y][x] == Cell.FOREST:
				map_root.add_child(_create_forest_tile(cell))
			elif grid[y][x] == Cell.LAVA:
				map_root.add_child(_create_lava_tile(cell))

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
	return root

func _grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (GRID_W - 1) / 2.0) * TILE_SIZE, FLOOR_Y, (cell.y - (GRID_H - 1) / 2.0) * TILE_SIZE)

func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	if camera == null:
		return Vector2i(-1, -1)
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	if absf(ray_dir.y) < 0.001:
		return Vector2i(-1, -1)
	var distance := (FLOOR_Y - ray_origin.y) / ray_dir.y
	if distance < 0.0:
		return Vector2i(-1, -1)
	var hit := ray_origin + ray_dir * distance
	var gx := int(floor(hit.x / TILE_SIZE + (GRID_W - 1) / 2.0 + 0.5))
	var gy := int(floor(hit.z / TILE_SIZE + (GRID_H - 1) / 2.0 + 0.5))
	return Vector2i(gx, gy)

func _make_mat(color: Color, emission := false, texture: Texture2D = null) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if texture:
		mat.albedo_texture = texture
	mat.roughness = 0.68
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.4
	return mat

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

func _setup_ui():
	var layer := CanvasLayer.new()
	add_child(layer)

	var top_center := CenterContainer.new()
	top_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_center.offset_top = 12
	top_center.offset_bottom = 68
	layer.add_child(top_center)

	var top_bar := PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(760, 46)
	top_center.add_child(top_bar)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 12)
	top_margin.add_theme_constant_override("margin_top", 8)
	top_margin.add_theme_constant_override("margin_right", 12)
	top_margin.add_theme_constant_override("margin_bottom", 8)
	top_bar.add_child(top_margin)

	var label := Label.new()
	label.text = "Map Editor  |  Left: Place  Right: Erase  |  1 Wall  2 Crate  3 Forest  4 Lava  5 Empty"
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(730, 28)
	top_margin.add_child(label)

	var bottom_center := CenterContainer.new()
	bottom_center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_center.offset_top = -76
	bottom_center.offset_bottom = -14
	layer.add_child(bottom_center)

	var bottom_bar := PanelContainer.new()
	bottom_bar.custom_minimum_size = Vector2(620, 52)
	bottom_center.add_child(bottom_bar)

	var bottom_margin := MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 10)
	bottom_margin.add_theme_constant_override("margin_top", 8)
	bottom_margin.add_theme_constant_override("margin_right", 10)
	bottom_margin.add_theme_constant_override("margin_bottom", 8)
	bottom_bar.add_child(bottom_margin)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	bottom_margin.add_child(controls)

	selected_label = Label.new()
	selected_label.add_theme_font_size_override("font_size", 16)
	selected_label.add_theme_color_override("font_color", Color.YELLOW)
	selected_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selected_label.custom_minimum_size = Vector2(132, 34)
	_update_sel_label(selected_label)
	controls.add_child(selected_label)

	var wall_btn := Button.new()
	wall_btn.text = "墙"
	wall_btn.custom_minimum_size = Vector2(48, 34)
	wall_btn.pressed.connect(func(): _set_selected_cell(Cell.WALL))
	controls.add_child(wall_btn)

	var crate_btn := Button.new()
	crate_btn.text = "箱"
	crate_btn.custom_minimum_size = Vector2(48, 34)
	crate_btn.pressed.connect(func(): _set_selected_cell(Cell.CRATE))
	controls.add_child(crate_btn)

	var forest_btn := Button.new()
	forest_btn.text = "林"
	forest_btn.custom_minimum_size = Vector2(48, 34)
	forest_btn.pressed.connect(func(): _set_selected_cell(Cell.FOREST))
	controls.add_child(forest_btn)

	var lava_btn := Button.new()
	lava_btn.text = "熔"
	lava_btn.custom_minimum_size = Vector2(48, 34)
	lava_btn.pressed.connect(func(): _set_selected_cell(Cell.LAVA))
	controls.add_child(lava_btn)

	var empty_btn := Button.new()
	empty_btn.text = "空"
	empty_btn.custom_minimum_size = Vector2(48, 34)
	empty_btn.pressed.connect(func(): _set_selected_cell(Cell.EMPTY))
	controls.add_child(empty_btn)

	var save_btn := Button.new()
	save_btn.text = "保存"
	save_btn.custom_minimum_size = Vector2(76, 34)
	save_btn.pressed.connect(_save_map)
	controls.add_child(save_btn)

	var back_btn := Button.new()
	back_btn.text = "退出"
	back_btn.custom_minimum_size = Vector2(76, 34)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	controls.add_child(back_btn)

func _update_sel_label(lbl: Label):
	var names := {Cell.WALL: "Wall", Cell.CRATE: "Crate", Cell.FOREST: "Forest", Cell.LAVA: "Lava", Cell.EMPTY: "Empty"}
	lbl.text = "Current: " + names.get(selected_cell, "?")

func _set_selected_cell(cell: int):
	selected_cell = cell
	if selected_label:
		_update_sel_label(selected_label)

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _set_selected_cell(Cell.WALL)
			KEY_2: _set_selected_cell(Cell.CRATE)
			KEY_3: _set_selected_cell(Cell.FOREST)
			KEY_4: _set_selected_cell(Cell.LAVA)
			KEY_5: _set_selected_cell(Cell.EMPTY)
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

	if event is InputEventMouseButton:
		if not event.pressed:
			return
		if _is_pointer_over_editor_ui(event.position):
			return
		var cell := _screen_to_grid(event.position)
		if cell.x >= 1 and cell.x < GRID_W - 1 and cell.y >= 1 and cell.y < GRID_H - 1:
			if event.button_index == MOUSE_BUTTON_LEFT:
				grid[cell.y][cell.x] = selected_cell
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				grid[cell.y][cell.x] = Cell.EMPTY
			_refresh_view()

func _is_pointer_over_editor_ui(screen_pos: Vector2) -> bool:
	var viewport_height := get_viewport().get_visible_rect().size.y
	return screen_pos.y <= 76.0 or screen_pos.y >= viewport_height - 84.0

func _save_map():
	var file := FileAccess.open("user://map_data.json", FileAccess.WRITE)
	if file:
		var data := {}
		for y in GRID_H:
			for x in GRID_W:
				if grid[y][x] != Cell.EMPTY:
					data[str(x) + "," + str(y)] = grid[y][x]
		file.store_string(JSON.stringify(data))
		file.close()
		print("Map saved!")

func _load_map(show_messages := true):
	if not FileAccess.file_exists("user://map_data.json"):
		if show_messages:
			print("No saved map.")
		return
	var file := FileAccess.open("user://map_data.json", FileAccess.READ)
	if file:
		var text := file.get_as_text()
		file.close()
		var json := JSON.new()
		if json.parse(text) == OK:
			var data = json.get_data()
			for yy in GRID_H:
				for xx in GRID_W:
					grid[yy][xx] = Cell.EMPTY
			for xx in GRID_W:
				grid[0][xx] = Cell.WALL
				grid[GRID_H - 1][xx] = Cell.WALL
			for yy in GRID_H:
				grid[yy][0] = Cell.WALL
				grid[yy][GRID_W - 1] = Cell.WALL
			for key in data.keys():
				var coords = key.split(",")
				if coords.size() != 2:
					continue
				var cx = int(coords[0])
				var cy = int(coords[1])
				if cx >= 1 and cx < GRID_W - 1 and cy >= 1 and cy < GRID_H - 1:
					grid[cy][cx] = int(data[key])
			_refresh_view()
			if show_messages:
				print("Map loaded!")
