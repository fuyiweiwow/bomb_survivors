extends Node

const BOMB_FUSE := 2.5
const BOMB_WARNING_SECONDS := 1.2
const BOMB_WARNING_FLASHES := 4
const EXPLOSION_ACTIVE_SECONDS := 0.42
const BOMB_HOP_WINDOW := 0.30
const CELL_WALL := Constants.Cell.WALL
const CELL_CRATE := Constants.Cell.CRATE

var game: Node
var active_explosions: Array[Dictionary] = []

func setup(game_manager: Node):
	game = game_manager

func _process(_delta: float):
	if game == null:
		return
	for raw_cell in game.bomb_map.keys():
		var entry: Dictionary = game.bomb_map[raw_cell as Vector2i]
		var timer := entry.get("timer") as Timer
		if is_instance_valid(timer):
			_update_bomb_warning(entry, timer.time_left)
	_process_active_explosions(_delta)

func try_place_bomb(player_index: int) -> bool:
	if player_index < 0 or player_index >= game.players.size():
		return false
	var player: Dictionary = game.players[player_index]
	if bool(player.get("airborne", false)):
		return false
	var cell: Vector2i = player["grid_pos"]
	if game.bomb_map.has(cell):
		return false

	var placed_at := game_time()
	var previous_cell := player["last_bomb_pos"] as Vector2i
	if previous_cell != Vector2i(-1, -1) and Constants.grid_distance(previous_cell, cell) == 1 and placed_at - float(player["last_bomb_place_time"]) <= BOMB_HOP_WINDOW:
		player["bomb_hop_until"] = placed_at + BOMB_HOP_WINDOW
		player["bomb_hop_cells"] = {previous_cell: true, cell: true}
	player["last_bomb_pos"] = cell
	player["last_bomb_place_time"] = placed_at
	player["bomb_placed_count"] += 1

	var bomb := Node3D.new()
	bomb.name = "Bomb_%d_%d" % [cell.x, cell.y]
	bomb.position = Constants.grid_to_world(cell) + Vector3(0, 0.38, 0)
	var shell := MeshHelpers.sphere(0.42, game.art.mat_bomb)
	shell.name = "BombShell"
	bomb.add_child(shell)
	var warning := MeshHelpers.sphere(0.28, MeshHelpers.make_mat(Color(1.0, 0.08, 0.02), true))
	warning.name = "CountdownFlash"
	warning.transparency = 1.0
	bomb.add_child(warning)
	game.add_child(bomb)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = BOMB_FUSE
	timer.timeout.connect(func(): _explode_bomb_by_node(bomb))
	bomb.add_child(timer)
	timer.start()

	var pulse := game.create_tween().set_loops()
	pulse.tween_property(bomb, "scale", Vector3(1.12, 1.12, 1.12), 0.35)
	pulse.tween_property(bomb, "scale", Vector3.ONE, 0.35)
	game.bomb_map[cell] = {"node": bomb, "player_index": player_index, "range": player["bomb_range"], "pulse": pulse, "timer": timer, "placed_at": placed_at, "shell": shell, "warning": warning, "warning_started": false}
	game.audio_manager.play("bomb_place")
	return true

func _update_bomb_warning(entry: Dictionary, time_left: float):
	if time_left > BOMB_WARNING_SECONDS:
		return
	if not bool(entry.get("warning_started", false)):
		entry["warning_started"] = true
		var pulse = entry.get("pulse")
		if pulse is Tween and is_instance_valid(pulse):
			(pulse as Tween).kill()
	var interval := BOMB_WARNING_SECONDS / float(BOMB_WARNING_FLASHES)
	var flash_elapsed := BOMB_WARNING_SECONDS - maxf(time_left, 0.0)
	var flash_on := fmod(flash_elapsed, interval) < interval * 0.48
	var warning = entry.get("warning")
	if is_instance_valid(warning):
		(warning as GeometryInstance3D).transparency = 0.0 if flash_on else 1.0
	var shell = entry.get("shell")
	if is_instance_valid(shell):
		(shell as GeometryInstance3D).transparency = 0.42 if flash_on else 0.0
	var bomb = entry.get("node")
	if is_instance_valid(bomb):
		(bomb as Node3D).scale = Vector3.ONE * (1.16 if flash_on else 1.0)

func game_time() -> float:
	return Time.get_ticks_msec() / 1000.0

func kick_bomb_in_direction(player: Dictionary):
	var direction := player["last_move_dir"] as Vector2i
	var origin: Vector2i = player["grid_pos"] + direction
	if not game.bomb_map.has(origin):
		player["status"] = "No bomb to kick"
		return
	var destination := origin
	var hit_obstacle := false
	for step in range(4):
		var target: Vector2i = destination + direction
		if target.x < 0 or target.x >= Constants.GRID_W or target.y < 0 or target.y >= Constants.GRID_H:
			hit_obstacle = true
			break
		if game.grid[target.y][target.x] in [CELL_WALL, CELL_CRATE] or game.oil_barrels.has(target) or game.bomb_map.has(target):
			hit_obstacle = true
			break
		destination = target
	if destination == origin:
		explode_bomb(origin)
		return
	var entry: Dictionary = game.bomb_map[origin]
	game.bomb_map.erase(origin)
	game.bomb_map[destination] = entry
	var node = entry.get("node")
	if is_instance_valid(node):
		var tween := game.create_tween().bind_node(node)
		tween.tween_property(node, "position", Constants.grid_to_world(destination) + Vector3(0, 0.38, 0), 0.18)
		if hit_obstacle:
			tween.tween_callback(func(): explode_bomb(destination))
	player["status"] = "Bomb kicked"

func explode_bomb(cell: Vector2i):
	if not game.bomb_map.has(cell):
		return
	var entry: Dictionary = game.bomb_map[cell]
	if bool(entry.get("exploded", false)):
		return
	entry["exploded"] = true
	game.audio_manager.play("explosion")
	var player_index: int = entry["player_index"]
	if player_index >= 0 and player_index < game.players.size():
		game.players[player_index]["bomb_placed_count"] = max(game.players[player_index]["bomb_placed_count"] - 1, 0)
	var bomb: Node3D = entry["node"]
	var pulse: Tween = entry["pulse"]
	if is_instance_valid(pulse):
		pulse.kill()
	game.bomb_map.erase(cell)
	var results: Dictionary = get_explosion_cells(cell, entry["range"], true)
	var chained_bombs: Array[Vector2i] = []
	for raw_cell in results["cells"]:
		var blast_cell := raw_cell as Vector2i
		if game.bomb_map.has(blast_cell):
			chained_bombs.append(blast_cell)
	detonate_cells(results["cells"], player_index, cell)
	if is_instance_valid(bomb):
		bomb.queue_free()
	for chained_cell in chained_bombs:
		explode_bomb(chained_cell)

func get_explosion_cells(origin: Vector2i, blast_range: int, apply_weather := false) -> Dictionary:
	var cells: Array = [origin]
	var directions: Array = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for direction in directions:
		var direction_range := blast_range
		if apply_weather and game.weather_manager and game.weather_manager.should_extend_wind(direction as Vector2i):
			direction_range += 1
		for distance in range(1, direction_range + 1):
			var cell: Vector2i = origin + (direction as Vector2i) * distance
			if cell.x < 0 or cell.x >= Constants.GRID_W or cell.y < 0 or cell.y >= Constants.GRID_H:
				break
			if game.grid[cell.y][cell.x] == CELL_WALL:
				break
			cells.append(cell)
			if game.grid[cell.y][cell.x] == CELL_CRATE or game.oil_barrels.has(cell):
				break
	return {"cells": cells}

func spawn_explosion(cells: Array):
	for raw_cell in cells:
		var cell := raw_cell as Vector2i
		var flame_size := Constants.BLAST_HIT_RADIUS * 2.0 - 0.08
		var flame = MeshHelpers.box(Vector3(flame_size, 0.16, flame_size), game.art.mat_fire)
		flame.position = Constants.grid_to_world(cell) + Vector3(0, 0.12, 0)
		game.add_child(flame)
		var tween := game.create_tween().set_parallel()
		tween.tween_property(flame, "scale", Vector3(1.12, 1.0, 1.12), 0.08)
		tween.tween_property(flame, "transparency", 1.0, 0.35).set_delay(0.18)
		tween.set_parallel(false)
		tween.tween_callback(flame.queue_free).set_delay(0.35)

func detonate_cells(
	cells: Array,
	explosion_owner := -1,
	exploding_cell := Vector2i(-1, -1),
	min_height := Constants.GROUND_ATTACK_MIN_HEIGHT,
	max_height := Constants.GROUND_ATTACK_MAX_HEIGHT
):
	spawn_explosion(cells)
	var hit_players: Dictionary = {}
	game.combat_manager.apply_explosion_damage(cells, explosion_owner, exploding_cell, hit_players, true, min_height, max_height)
	active_explosions.append({
		"cells": cells.duplicate(),
		"owner": explosion_owner,
		"exploding_cell": exploding_cell,
		"remaining": EXPLOSION_ACTIVE_SECONDS,
		"hit_players": hit_players,
		"min_height": min_height,
		"max_height": max_height,
	})

func _process_active_explosions(delta: float):
	for index in range(active_explosions.size() - 1, -1, -1):
		var explosion: Dictionary = active_explosions[index]
		if float(explosion["remaining"]) <= 0.0:
			active_explosions.remove_at(index)
			continue
		game.combat_manager.apply_explosion_damage(
			explosion["cells"],
			int(explosion["owner"]),
			explosion["exploding_cell"],
			explosion["hit_players"],
			false,
			float(explosion.get("min_height", Constants.GROUND_ATTACK_MIN_HEIGHT)),
			float(explosion.get("max_height", Constants.GROUND_ATTACK_MAX_HEIGHT))
		)
		explosion["remaining"] = float(explosion["remaining"]) - delta
		if float(explosion["remaining"]) <= 0.0:
			active_explosions.remove_at(index)

func active_blast_cell_set() -> Dictionary:
	var result := {}
	for raw_cell in game.bomb_map.keys():
		var cell := raw_cell as Vector2i
		var entry: Dictionary = game.bomb_map[cell]
		var data := get_explosion_cells(cell, int(entry["range"]))
		for blast_cell in data["cells"]:
			result[blast_cell as Vector2i] = true
	return result

func blast_cell_set(origin: Vector2i, blast_range: int) -> Dictionary:
	var result := {}
	var data := get_explosion_cells(origin, blast_range)
	for raw_cell in data["cells"]:
		result[raw_cell as Vector2i] = true
	return result

func _explode_bomb_by_node(bomb_node: Node3D):
	for raw_cell in game.bomb_map.keys():
		var cell := raw_cell as Vector2i
		if (game.bomb_map[cell] as Dictionary).get("node") == bomb_node:
			explode_bomb(cell)
			return
