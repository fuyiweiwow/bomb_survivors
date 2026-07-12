extends Node

var _game: Node

func setup(game_manager: Node):
	_game = game_manager

func create_player(id: int, cell: Vector2i, ai: bool, mat: Material, style := "male") -> Dictionary:
	var style_data := _player_style_data(style)
	var root := Area3D.new()
	root.name = "Player%d_3D" % id
	root.position = Constants.grid_to_world(cell)
	root.collision_layer = 2
	root.collision_mask = 2
	root.monitoring = true
	root.monitorable = true
	var collision_shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = style_data["radius"]
	capsule_shape.height = style_data["height"]
	collision_shape.shape = capsule_shape
	collision_shape.position = Vector3(0, style_data["body_y"], 0)
	root.add_child(collision_shape)

	var body := MeshHelpers.capsule(style_data["radius"], style_data["height"], mat)
	body.position = Vector3(0, style_data["body_y"], 0)
	root.add_child(body)

	var visor := MeshHelpers.box(Vector3(style_data["visor_w"], 0.12, 0.08), MeshHelpers.make_mat(style_data["visor_color"], true))
	visor.position = Vector3(0, style_data["visor_y"], -0.34)
	root.add_child(visor)

	_game.add_child(root)
	return {
		"id": id,
		"node": root,
		"grid_pos": cell,
		"alive": true,
		"hp": Constants.PLAYER_MAX_HP,
		"max_hp": Constants.PLAYER_MAX_HP,
		"downed": false,
		"downed_timer": 0.0,
		"is_moving": false,
		"move_tween": null,
		"move_target_world": Vector3.ZERO,
		"move_speed_world": 0.0,
		"grid_motion_active": false,
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

func load_player_config() -> Dictionary:
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

func load_ai_difficulty() -> String:
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

func apply_ai_difficulty(p: Dictionary, difficulty: String):
	p["ai_difficulty"] = difficulty
	match difficulty:
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

func player_material_from_config(config: Dictionary) -> Material:
	var color := Color(0.18, 0.48, 0.95)
	if str(config.get("gender", "male")) == "female":
		color = Color(0.95, 0.27, 0.22)
	return MeshHelpers.make_mat(color)

func find_spawn_cell() -> Vector2i:
	var candidates: Array = []
	for y in range(1, Constants.GRID_H - 1):
		for x in range(1, Constants.GRID_W - 1):
			var cell := Vector2i(x, y)
			if not Constants.is_walkable_cell(_game.grid[cell.y][cell.x]) or Constants.is_lava_cell(_game.grid, cell) or _game.bomb_map.has(cell):
				continue
			var occupied := false
			for p: Dictionary in _game.players:
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

func boss_data(boss_id: String) -> Dictionary:
	match boss_id:
		"frost_giant":
			return {"name": "Frost Giant", "hp": 12, "speed": 3, "range": 1, "bomb_max": 0, "move_interval": 0.48, "bomb_interval": 99.0, "skill_interval": 4.5, "material": _game.mat_boss_frost}
		"clone_demon":
			return {"name": "Clone Demon", "hp": 6, "speed": 6, "range": 2, "bomb_max": 2, "move_interval": 0.20, "bomb_interval": 1.4, "skill_interval": 5.0, "material": _game.mat_boss_clone}
		_:
			return {"name": "Blast King", "hp": 8, "speed": 5, "range": 5, "bomb_max": 3, "move_interval": 0.28, "bomb_interval": 0.75, "skill_interval": 3.5, "material": _game.mat_boss_blast}

func spawn_player(config: Dictionary, inventory_manager):
	var player := create_player(1, Vector2i(1, 1), false, player_material_from_config(config), str(config["gender"]))
	player["speed"] = config["start_speed"]
	player["bomb_max"] = config["start_bombs"]
	player["bomb_range"] = config["start_range"]
	player["shield"] = config["start_shields"]
	inventory_manager.add_item(player, "shield_potion")
	return player

func spawn_ai_wave(count: int, difficulty: String, start_id: int):
	var current_id := start_id
	for i in range(count):
		var spawn_cell := find_spawn_cell()
		if spawn_cell == Vector2i(-1, -1):
			return
		var ai_player := create_player(current_id, spawn_cell, true, _game.mat_ai, "ai")
		current_id += 1
		apply_ai_difficulty(ai_player, difficulty)
		_game.players.append(ai_player)
		_play_spawn_effect(spawn_cell, false)

func spawn_boss(boss_id: String, boss_id_val: int):
	var spawn_cell := find_spawn_cell()
	if spawn_cell == Vector2i(-1, -1):
		return
	var boss_data_dict := boss_data(boss_id)
	var boss := create_player(boss_id_val, spawn_cell, true, boss_data_dict["material"], "boss")
	boss["boss_id"] = boss_id
	boss["boss_name"] = boss_data_dict["name"]
	boss["hp"] = boss_data_dict["hp"]
	boss["max_hp"] = boss_data_dict["hp"]
	boss["speed"] = boss_data_dict["speed"]
	boss["bomb_range"] = boss_data_dict["range"]
	boss["bomb_max"] = boss_data_dict["bomb_max"]
	boss["move_interval"] = boss_data_dict["move_interval"]
	boss["bomb_interval"] = boss_data_dict["bomb_interval"]
	boss["skill_timer"] = boss_data_dict["skill_interval"]
	boss["node"].scale = Vector3(1.45, 1.45, 1.45)
	_game.players.append(boss)
	_play_spawn_effect(spawn_cell, true)
	_game.game_ui.flash_boss_spawn()

func spawn_clone_minions(origin: Vector2i, start_id: int):
	var current_id := start_id
	var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	directions.shuffle()
	var spawned := 0
	for raw_direction in directions:
		var direction := raw_direction as Vector2i
		var cell: Vector2i = origin + direction
		if not _is_clone_spawn_walkable(cell):
			continue
		var minion := create_player(current_id, cell, true, _game.mat_boss_clone, "ai")
		current_id += 1
		minion["is_minion"] = true
		minion["hp"] = 1
		minion["max_hp"] = 1
		minion["speed"] = 6
		minion["bomb_max"] = 0
		minion["move_interval"] = 0.18
		minion["ai_difficulty"] = "hard"
		minion["status"] = "Decoy"
		minion["node"].scale = Vector3(0.72, 0.72, 0.72)
		_game.players.append(minion)
		spawned += 1
		if spawned >= 2:
			return

func _is_clone_spawn_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= Constants.GRID_W or cell.y < 0 or cell.y >= Constants.GRID_H:
		return false
	if not Constants.is_walkable_cell(_game.grid[cell.y][cell.x]):
		return false
	if _game.bomb_map.has(cell):
		return false
	for p in _game.players:
		if p["alive"] and p["grid_pos"] == cell:
			return false
	return true

func _play_spawn_effect(cell: Vector2i, is_boss: bool):
	var duration := 1.5 if is_boss else 0.5
	var color := Color(1.0, 0.16, 0.08) if is_boss else Color(0.20, 0.88, 1.0)
	var material := MeshHelpers.make_mat(color, true)
	var effect_root := Node3D.new()
	effect_root.name = "BossSpawnEffect" if is_boss else "AISpawnEffect"
	effect_root.position = Constants.grid_to_world(cell)
	_game.add_child(effect_root)

	var pillar := MeshHelpers.cylinder(0.34 if is_boss else 0.22, 5.5 if is_boss else 3.8, material)
	pillar.position.y = 2.75 if is_boss else 1.9
	pillar.transparency = 0.18
	effect_root.add_child(pillar)
	var ring := MeshHelpers.cylinder(0.55, 0.05, material)
	ring.position.y = 0.08
	effect_root.add_child(ring)

	var tween := _game.create_tween().bind_node(effect_root).set_parallel()
	tween.tween_property(pillar, "transparency", 1.0, duration)
	tween.tween_property(pillar, "scale", Vector3(0.45, 1.0, 0.45), duration)
	tween.tween_property(ring, "scale", Vector3(3.2 if is_boss else 1.8, 1.0, 3.2 if is_boss else 1.8), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "transparency", 1.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(effect_root.queue_free)

func _player_style_data(style: String) -> Dictionary:
	match style:
		"female":
			return {"radius": 0.31, "height": 0.98, "body_y": 0.58, "visor_y": 0.78, "visor_w": 0.52, "visor_color": Color(1.0, 0.58, 0.25)}
		"ai":
			return {"radius": 0.36, "height": 1.08, "body_y": 0.63, "visor_y": 0.83, "visor_w": 0.48, "visor_color": Color(0.02, 0.03, 0.04)}
		"boss":
			return {"radius": 0.40, "height": 1.18, "body_y": 0.68, "visor_y": 0.90, "visor_w": 0.56, "visor_color": Color(1.0, 0.82, 0.18)}
		_:
			return {"radius": 0.35, "height": 1.05, "body_y": 0.62, "visor_y": 0.82, "visor_w": 0.46, "visor_color": Color(0.2, 0.85, 1.0)}
