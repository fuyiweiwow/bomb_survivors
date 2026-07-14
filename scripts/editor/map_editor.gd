extends Node3D

const GRID_W := Constants.GRID_W
const GRID_H := Constants.GRID_H
const TILE_SIZE := Constants.TILE_SIZE
const FLOOR_Y := Constants.FLOOR_Y
const TERRAIN_ART := preload("res://scripts/terrain/terrain_art_factory.gd")
const MAP_EDITOR_DOCUMENT := preload("res://scripts/editor/map_editor_document.gd")
const MAP_EDITOR_PICKER := preload("res://scripts/editor/map_editor_picker.gd")
const MAP_EDITOR_TOOLBAR := preload("res://scripts/editor/map_editor_toolbar.gd")
const ART_CATALOG := preload("res://scripts/core/game_art_catalog.gd")

var document: MapEditorDocument = MAP_EDITOR_DOCUMENT.new(GRID_W, GRID_H)
var map_state: MapState = document.map_state
var grid: Array:
	get: return document.cells()
var selected_cell := Constants.Cell.WALL
var selected_label: Label
var map_root: Node3D
var camera: Camera3D
var picker: MapEditorPicker
var toolbar: MapEditorToolbar
var art: RefCounted = ART_CATALOG.new()

func _ready() -> void:
	set_process_input(true)
	_init_grid()
	_setup_scene()
	_setup_ui()
	_load_map(false)
	_refresh_view()

func _init_grid() -> void:
	document.reset_blank()

func _setup_scene() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.07, 0.09, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.64)
	environment.ambient_light_energy = 0.9
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.0
	sun.rotation_degrees = Vector3(-55, -35, 0)
	add_child(sun)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 34.0
	camera.position = Vector3(0, 16, 12)
	camera.rotation_degrees = Vector3(-58, 0, 0)
	camera.current = true
	add_child(camera)
	picker = MAP_EDITOR_PICKER.new(camera, GRID_W, GRID_H, TILE_SIZE, FLOOR_Y)

	map_root = Node3D.new()
	map_root.name = "EditableMap3D"
	add_child(map_root)
	add_child(TERRAIN_ART.create_outer_terrain(GRID_W, GRID_H, TILE_SIZE, art.mat_wall, art.mat_floor_a))

func _setup_ui() -> void:
	toolbar = MAP_EDITOR_TOOLBAR.new()
	add_child(toolbar)
	toolbar.setup(selected_cell)
	toolbar.tool_selected.connect(_set_selected_cell)
	toolbar.save_requested.connect(_save_map)
	toolbar.exit_requested.connect(_exit_to_menu)
	selected_label = toolbar.selected_label

func _refresh_view() -> void:
	if is_instance_valid(map_root):
		map_root.queue_free()
	map_root = Node3D.new()
	map_root.name = "EditableMap3D"
	add_child(map_root)

	for y in GRID_H:
		for x in GRID_W:
			var cell := Vector2i(x, y)
			map_root.add_child(TERRAIN_ART.create_floor_cell(cell, _grid_to_world(cell), TILE_SIZE, _floor_mat_for_cell(x, y)))
			match map_state.cell_at(cell):
				Constants.Cell.WALL:
					var wall := TERRAIN_ART.create_rock_wall(cell, TILE_SIZE, art.mat_wall)
					wall.position = _grid_to_world(cell) + Vector3(0, 0.62, 0)
					map_root.add_child(wall)
				Constants.Cell.CRATE:
					var crate := MeshHelpers.box(Vector3(TILE_SIZE * 0.84, 0.92, TILE_SIZE * 0.84), art.mat_crate)
					crate.name = "Crate_%d_%d" % [cell.x, cell.y]
					crate.position = _grid_to_world(cell) + Vector3(0, 0.46, 0)
					map_root.add_child(crate)
				Constants.Cell.FOREST:
					map_root.add_child(_create_forest_tile(cell))
				Constants.Cell.LAVA:
					map_root.add_child(_create_lava_tile(cell))

func _floor_mat_for_cell(x: int, y: int) -> Material:
	match map_state.cell_at(Vector2i(x, y)):
		Constants.Cell.FOREST:
			return art.mat_forest_floor
		Constants.Cell.LAVA:
			return art.mat_lava
		_:
			return art.mat_floor_a if (x + y) % 2 == 0 else art.mat_floor_b

func _create_forest_tile(cell: Vector2i) -> Node3D:
	return TERRAIN_ART.create_forest_tile(cell, _grid_to_world(cell), TILE_SIZE, art.mat_forest_floor, art.mat_trunk, art.mat_leaf)

func _create_lava_tile(cell: Vector2i) -> Node3D:
	return TERRAIN_ART.create_lava_tile(cell, _grid_to_world(cell), TILE_SIZE, art.mat_lava_glow)

func _grid_to_world(cell: Vector2i) -> Vector3:
	return Constants.grid_to_world(cell)

func _screen_to_grid(screen_position: Vector2) -> Vector2i:
	return picker.screen_to_grid(screen_position) if picker != null else Vector2i(-1, -1)

func _set_selected_cell(cell_type: int) -> void:
	selected_cell = cell_type
	if toolbar != null:
		toolbar.set_selected_cell(cell_type)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _set_selected_cell(Constants.Cell.WALL)
			KEY_2: _set_selected_cell(Constants.Cell.CRATE)
			KEY_3: _set_selected_cell(Constants.Cell.FOREST)
			KEY_4: _set_selected_cell(Constants.Cell.LAVA)
			KEY_5: _set_selected_cell(Constants.Cell.EMPTY)
			KEY_ESCAPE: _exit_to_menu()

	if event is InputEventMouseButton and event.pressed:
		if _is_pointer_over_editor_ui(event.position):
			return
		var cell := _screen_to_grid(event.position)
		var changed := false
		if event.button_index == MOUSE_BUTTON_LEFT:
			changed = document.paint(cell, selected_cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			changed = document.erase(cell)
		if changed:
			_refresh_view()

func _is_pointer_over_editor_ui(screen_position: Vector2) -> bool:
	if toolbar == null:
		return false
	return toolbar.handles_pointer(screen_position, get_viewport().get_visible_rect().size.y)

func _save_map() -> void:
	print("Map saved!" if document.save() else "Map save failed.")

func _load_map(show_messages := true) -> void:
	var result := document.load()
	if result == MAP_EDITOR_DOCUMENT.LoadResult.LOADED:
		_refresh_view()
		if show_messages:
			print("Map loaded!")
	elif result == MAP_EDITOR_DOCUMENT.LoadResult.RESET_INCOMPATIBLE:
		_refresh_view()
		if show_messages:
			print("Incompatible map deleted. Start from an empty map.")
	elif show_messages:
		print("No saved map.")

func _delete_incompatible_map(show_messages: bool) -> void:
	document.reset_and_delete_saved_map()
	_refresh_view()
	if show_messages:
		print("Incompatible map deleted. Start from an empty map.")

func _exit_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
