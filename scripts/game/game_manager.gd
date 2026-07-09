extends Node2D

const TILE_SIZE := 32
const GRID_W := 15
const GRID_H := 11

enum Cell { EMPTY, WALL, CRATE }

var grid: Array = []
var bomb_map: Dictionary = {}
var players: Array = []
var crate_sprites: Dictionary = {}
var game_over := false

var player_script = preload("res://scripts/player/player.gd")
var ai_script = preload("res://scripts/ai/ai_player.gd")
var bomb_script = preload("res://scripts/items/bomb.gd")

var tex_male_head = preload("res://assets/art/sprites/male_head.png")
var tex_male_body = preload("res://assets/art/sprites/male_body.png")
var tex_male_legs = preload("res://assets/art/sprites/male_legs.png")
var tex_ai_body = preload("res://assets/art/sprites/player2.png")

func _ready():
	add_to_group("game")
	randomize()
	_init_grid()
	_create_floor()
	_create_map()
	_spawn_players()
	_setup_camera()

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
			if (x <= 3 and y <= 1) or (x >= GRID_W - 4 and y >= GRID_H - 2):
				continue
			if randf() < 0.5:
				grid[y][x] = Cell.CRATE

func _create_floor():
	var floor_tex = load("res://assets/art/sprites/floor.png")
	for y in GRID_H:
		for x in GRID_W:
			var f := Sprite2D.new()
			f.texture = floor_tex
			f.position = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
			f.centered = true
			f.z_index = -1
			add_child(f)

func _create_map():
	var wall_tex = load("res://assets/art/sprites/wall.png")
	var crate_tex = load("res://assets/art/sprites/crate.png")
	for y in GRID_H:
		for x in GRID_W:
			if grid[y][x] == Cell.WALL:
				var w := Sprite2D.new()
				w.texture = wall_tex
				w.position = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
				w.centered = true
				w.z_index = 1
				add_child(w)
			elif grid[y][x] == Cell.CRATE:
				var c := Sprite2D.new()
				c.texture = crate_tex
				c.position = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
				c.centered = true
				c.z_index = 1
				crate_sprites[Vector2i(x, y)] = c
				add_child(c)

func _spawn_players():
	_spawn_player1(Vector2i(1, 1))
	_spawn_ai(Vector2i(GRID_W - 2, GRID_H - 2))

func _spawn_player1(start_pos: Vector2i):
	var p := CharacterBody2D.new()
	p.name = "Player1"

	var sg := Node2D.new()
	sg.name = "SpriteGroup"

	var head := Sprite2D.new()
	head.name = "Head"
	head.texture = tex_male_head
	head.centered = true
	head.position = Vector2(0, -8)
	sg.add_child(head)

	var body := Sprite2D.new()
	body.name = "Body"
	body.texture = tex_male_body
	body.centered = true
	body.position = Vector2(0, 0)
	sg.add_child(body)

	var legs := Sprite2D.new()
	legs.name = "Legs"
	legs.texture = tex_male_legs
	legs.centered = true
	legs.position = Vector2(0, 8)
	sg.add_child(legs)

	p.add_child(sg)

	var main_sprite := Sprite2D.new()
	main_sprite.name = "Sprite2D"
	main_sprite.hide()
	p.add_child(main_sprite)

	p.set_script(player_script)
	add_child(p)
	p.setup(1, {"head": tex_male_head, "body": tex_male_body, "legs": tex_male_legs})
	p.set_grid(start_pos.x, start_pos.y)
	p.bomb_placed.connect(func(gp): _on_bomb(gp, p))
	p.player_died.connect(_on_player_died)
	players.append(p)

func _spawn_ai(start_pos: Vector2i):
	var p := CharacterBody2D.new()
	p.name = "Player2"
	p.set_script(ai_script)

	var s := Sprite2D.new()
	s.name = "Sprite2D"
	s.centered = true
	s.z_index = 2
	p.add_child(s)

	add_child(p)
	p.setup(2, tex_ai_body)
	p.set_grid(start_pos.x, start_pos.y)
	p.bomb_placed.connect(func(gp): _on_bomb(gp, p))
	p.player_died.connect(_on_player_died)
	players.append(p)

func _on_bomb(grid_pos: Vector2i, player: Node2D):
	if game_over: return

	var b := Node2D.new()
	b.set_script(bomb_script)
	b.name = "Bomb_" + str(grid_pos.x) + "_" + str(grid_pos.y)

	var s := Sprite2D.new()
	s.name = "Sprite2D"
	s.centered = true
	s.z_index = 2
	b.add_child(s)

	var t := Timer.new()
	t.name = "Timer"
	b.add_child(t)

	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	b.add_child(ap)

	add_child(b)
	b.setup(grid_pos, player.bomb_range)
	bomb_map[grid_pos] = {"node": b, "player": player}

func is_cell_walkable(x: int, y: int) -> bool:
	if x < 0 or x >= GRID_W or y < 0 or y >= GRID_H:
		return false
	if grid[y][x] != Cell.EMPTY:
		return false
	if bomb_map.has(Vector2i(x, y)):
		return false
	for p in players:
		if is_instance_valid(p) and p.alive and p.grid_pos == Vector2i(x, y):
			return false
	return true

func has_bomb_at(x: int, y: int) -> bool:
	return bomb_map.has(Vector2i(x, y))

func unregister_bomb(pos: Vector2i, _bomb_node: Node):
	if bomb_map.has(pos):
		var entry = bomb_map[pos]
		var p = entry.get("player")
		if p and is_instance_valid(p) and p.has_method("on_bomb_exploded"):
			p.on_bomb_exploded()
		bomb_map.erase(pos)

func get_explosion_cells(origin: Vector2i, blast_range: int) -> Dictionary:
	var cells: Array = [origin]
	var tips: Dictionary = {}
	var directions := {
		"up": Vector2i(0, -1), "down": Vector2i(0, 1),
		"left": Vector2i(-1, 0), "right": Vector2i(1, 0)
	}
	for dir_name in directions.keys():
		var dir: Vector2i = directions[dir_name]
		for i in range(1, blast_range + 1):
			var check := origin + dir * i
			if check.x < 0 or check.x >= GRID_W or check.y < 0 or check.y >= GRID_H:
				break
			if grid[check.y][check.x] == Cell.WALL:
				break
			cells.append(check)
			if grid[check.y][check.x] == Cell.CRATE:
				tips[dir_name] = check
				break
			if i == blast_range:
				tips[dir_name] = check
	return {"cells": cells, "tips": tips}

func apply_explosion_damage(cells: Array):
	for cell in cells:
		var key := Vector2i(cell.x, cell.y)

		if grid[cell.y][cell.x] == Cell.CRATE:
			grid[cell.y][cell.x] = Cell.EMPTY
			if crate_sprites.has(key):
				var cs: Sprite2D = crate_sprites[key]
				var tw := cs.create_tween()
				tw.tween_property(cs, "scale", Vector2(1.3, 1.3), 0.08)
				tw.tween_property(cs, "modulate:a", 0.0, 0.2)
				tw.tween_callback(cs.queue_free)
				crate_sprites.erase(key)

		for p in players:
			if not is_instance_valid(p) or not p.alive:
				continue
			if p.grid_pos.x == cell.x and p.grid_pos.y == cell.y:
				p.die()

func _on_player_died():
	if game_over: return

	var alive_left := 0
	for p in players:
		if is_instance_valid(p) and p.alive:
			alive_left += 1

	if alive_left > 1: return

	game_over = true
	await get_tree().create_timer(0.5).timeout

	var winner_id := 0
	for p in players:
		if is_instance_valid(p) and p.alive:
			winner_id = players.find(p) + 1
			break

	_show_result(winner_id)

func _show_result(winner_id: int):
	var label := Label.new()
	if winner_id == 0:
		label.text = "Draw!"
	elif winner_id == 1:
		label.text = "You Win!"
	else:
		label.text = "AI Wins!"
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(GRID_W * TILE_SIZE / 2.0 - 160, GRID_H * TILE_SIZE / 2.0 - 60)
	label.size = Vector2(320, 60)
	label.z_index = 100
	add_child(label)

	var btn := Button.new()
	btn.text = "Menu (Esc)"
	btn.position = Vector2(GRID_W * TILE_SIZE / 2.0 - 60, GRID_H * TILE_SIZE / 2.0 + 20)
	btn.size = Vector2(120, 40)
	btn.z_index = 100
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	add_child(btn)

func _setup_camera():
	var cam := Camera2D.new()
	cam.position = Vector2(GRID_W * TILE_SIZE / 2.0, GRID_H * TILE_SIZE / 2.0)
	cam.zoom = Vector2(1.5, 1.5)
	cam.enabled = true
	add_child(cam)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if game_over:
			get_tree().reload_current_scene()
