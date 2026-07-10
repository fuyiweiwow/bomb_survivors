extends Node2D

const TILE_SIZE := 32
const GRID_W := 15
const GRID_H := 11

enum Cell { EMPTY, WALL, CRATE }

var grid: Array = []
var sprites: Array = []
var selected_cell := Cell.WALL
var selected_label: Label = null
var floor_tex: Texture2D = load("res://assets/art/sprites/floor.png")
var wall_tex: Texture2D = load("res://assets/art/sprites/wall.png")
var crate_tex: Texture2D = load("res://assets/art/sprites/crate.png")

func _ready():
	set_process_input(true)

	for y in GRID_H:
		var row: Array = []
		row.resize(GRID_W)
		row.fill(Cell.EMPTY)
		grid.append(row)
		var sprite_row: Array = []
		sprite_row.resize(GRID_W)
		sprites.append(sprite_row)

	# perimeter walls
	for x in GRID_W:
		grid[0][x] = Cell.WALL
		grid[GRID_H - 1][x] = Cell.WALL
	for y in GRID_H:
		grid[y][0] = Cell.WALL
		grid[y][GRID_W - 1] = Cell.WALL

	_setup_ui()
	_load_map(false)
	_refresh_view()

func _refresh_view():
	for y in GRID_H:
		for x in GRID_W:
			if is_instance_valid(sprites[y][x]):
				sprites[y][x].queue_free()
			var s := Sprite2D.new()
			match grid[y][x]:
				Cell.WALL: s.texture = wall_tex
				Cell.CRATE: s.texture = crate_tex
				_: s.texture = floor_tex
			s.position = _map_origin() + Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
			s.centered = true
			add_child(s)
			sprites[y][x] = s

func _map_origin() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var map_size := Vector2(GRID_W * TILE_SIZE, GRID_H * TILE_SIZE)
	var usable_top := 82.0
	var usable_bottom := viewport_size.y - 90.0
	var usable_height := usable_bottom - usable_top
	return Vector2(
		(viewport_size.x - map_size.x) / 2.0,
		usable_top + (usable_height - map_size.y) / 2.0
	)

func _setup_ui():
	var layer := CanvasLayer.new()
	add_child(layer)

	var top_center := CenterContainer.new()
	top_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_center.offset_top = 12
	top_center.offset_bottom = 68
	layer.add_child(top_center)

	var top_bar := PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(700, 46)
	top_center.add_child(top_bar)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 12)
	top_margin.add_theme_constant_override("margin_top", 8)
	top_margin.add_theme_constant_override("margin_right", 12)
	top_margin.add_theme_constant_override("margin_bottom", 8)
	top_bar.add_child(top_margin)

	var label := Label.new()
	label.text = "Map Editor  |  Left: Place  Right: Erase  |  1 Wall  2 Crate  3 Empty"
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(670, 28)
	top_margin.add_child(label)

	var bottom_center := CenterContainer.new()
	bottom_center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_center.offset_top = -76
	bottom_center.offset_bottom = -14
	layer.add_child(bottom_center)

	var bottom_bar := PanelContainer.new()
	bottom_bar.custom_minimum_size = Vector2(440, 52)
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
	selected_label.custom_minimum_size = Vector2(118, 34)
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
	var names := {Cell.WALL: "Wall", Cell.CRATE: "Crate", Cell.EMPTY: "Empty"}
	lbl.text = "Current: " + names.get(selected_cell, "?")

func _set_selected_cell(cell: int):
	selected_cell = cell
	if selected_label:
		_update_sel_label(selected_label)

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: selected_cell = Cell.WALL
			KEY_2: selected_cell = Cell.CRATE
			KEY_3: selected_cell = Cell.EMPTY
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
		if selected_label:
			_update_sel_label(selected_label)

	if event is InputEventMouseButton:
		if not event.pressed:
			return
		if _is_pointer_over_editor_ui(event.position):
			return
		var local_pos: Vector2 = event.position - _map_origin()
		var gx := int(floor(local_pos.x / TILE_SIZE))
		var gy := int(floor(local_pos.y / TILE_SIZE))
		if gx >= 1 and gx < GRID_W - 1 and gy >= 1 and gy < GRID_H - 1:
			if event.button_index == MOUSE_BUTTON_LEFT:
				grid[gy][gx] = selected_cell
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				grid[gy][gx] = Cell.EMPTY
			_refresh_view()

func _is_pointer_over_editor_ui(screen_pos: Vector2) -> bool:
	var viewport_height := get_viewport_rect().size.y
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
			# keep perimeter walls
			for xx in GRID_W:
				grid[0][xx] = Cell.WALL
				grid[GRID_H - 1][xx] = Cell.WALL
			for yy in GRID_H:
				grid[yy][0] = Cell.WALL
				grid[yy][GRID_W - 1] = Cell.WALL
			for key in data.keys():
				var coords = key.split(",")
				var cx = int(coords[0])
				var cy = int(coords[1])
				if cx >= 1 and cx < GRID_W - 1 and cy >= 1 and cy < GRID_H - 1:
					grid[cy][cx] = data[key]
			_refresh_view()
			if show_messages:
				print("Map loaded!")
