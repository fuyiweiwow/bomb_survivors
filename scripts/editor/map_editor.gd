extends Node2D

const TILE_SIZE := 32
const GRID_W := 15
const GRID_H := 11

enum Cell { EMPTY, WALL, CRATE }

var grid: Array = []
var sprites: Array = []
var selected_cell := Cell.WALL
var floor_tex = preload("res://assets/art/sprites/floor.png")
var wall_tex = preload("res://assets/art/sprites/wall.png")
var crate_tex = preload("res://assets/art/sprites/crate.png")

func _ready():
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

	_refresh_view()
	_setup_ui()
	_setup_camera()

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
			s.position = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
			s.centered = true
			add_child(s)
			sprites[y][x] = s

func _setup_ui():
	var label := Label.new()
	label.text = "Map Editor - LeftClick: Place | RightClick: Erase | 1:Wall 2:Crate 3:Empty"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(10, GRID_H * TILE_SIZE + 10)
	label.size = Vector2(600, 30)
	add_child(label)

	var sel_label := Label.new()
	sel_label.name = "SelLabel"
	sel_label.add_theme_font_size_override("font_size", 18)
	sel_label.add_theme_color_override("font_color", Color.YELLOW)
	sel_label.position = Vector2(10, GRID_H * TILE_SIZE + 45)
	sel_label.size = Vector2(200, 30)
	_update_sel_label(sel_label)
	add_child(sel_label)

	var save_btn := Button.new()
	save_btn.text = "Save Map"
	save_btn.position = Vector2(200, GRID_H * TILE_SIZE + 10)
	save_btn.size = Vector2(100, 30)
	save_btn.pressed.connect(_save_map)
	add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "Load Map"
	load_btn.position = Vector2(310, GRID_H * TILE_SIZE + 10)
	load_btn.size = Vector2(100, 30)
	load_btn.pressed.connect(_load_map)
	add_child(load_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.position = Vector2(420, GRID_H * TILE_SIZE + 10)
	back_btn.size = Vector2(100, 30)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	add_child(back_btn)

func _update_sel_label(lbl: Label):
	var names := {Cell.WALL: "Wall", Cell.CRATE: "Crate", Cell.EMPTY: "Empty"}
	lbl.text = "Current: " + names.get(selected_cell, "?")

func _setup_camera():
	var cam := Camera2D.new()
	cam.position = Vector2(GRID_W * TILE_SIZE / 2.0, GRID_H * TILE_SIZE / 2.0)
	cam.zoom = Vector2(1.4, 1.4)
	cam.enabled = true
	add_child(cam)

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: selected_cell = Cell.WALL
			KEY_2: selected_cell = Cell.CRATE
			KEY_3: selected_cell = Cell.EMPTY
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
		var lbl = get_node_or_null("SelLabel")
		if lbl: _update_sel_label(lbl)

	if event is InputEventMouseButton:
		var mp := get_global_mouse_position()
		var gx := int(mp.x / TILE_SIZE)
		var gy := int(mp.y / TILE_SIZE)
		if gx >= 1 and gx < GRID_W - 1 and gy >= 1 and gy < GRID_H - 1:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				grid[gy][gx] = selected_cell
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				grid[gy][gx] = Cell.EMPTY
			_refresh_view()

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

func _load_map():
	if not FileAccess.file_exists("user://map_data.json"):
		print("No saved map.")
		return
	var file := FileAccess.open("user://map_data.json", FileAccess.READ)
	if file:
		var text := file.get_as_text()
		file.close()
		var json := JSON.new()
		if json.parse(text) == OK:
			var data = json.get_data()
			for y in GRID_H:
				for x in GRID_W:
					grid[y][x] = Cell.EMPTY
			# keep perimeter walls
			for x in GRID_W:
				grid[0][x] = Cell.WALL
				grid[GRID_H - 1][x] = Cell.WALL
			for y in GRID_H:
				grid[y][0] = Cell.WALL
				grid[y][GRID_W - 1] = Cell.WALL
			for key in data.keys():
				var coords = key.split(",")
				var cx = int(coords[0])
				var cy = int(coords[1])
				if cx >= 1 and cx < GRID_W - 1 and cy >= 1 and cy < GRID_H - 1:
					grid[cy][cx] = data[key]
			_refresh_view()
			print("Map loaded!")
