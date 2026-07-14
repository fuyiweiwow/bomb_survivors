extends Node

const PLAYER_VISUAL_FACTORY_SCRIPT := preload("res://scripts/character/player_visual_factory.gd")
const CHARACTER_STATE_FACTORY_SCRIPT := preload("res://scripts/character/character_state_factory.gd")

var _game: Node
var visual_factory: PlayerVisualFactory = PLAYER_VISUAL_FACTORY_SCRIPT.new()
var state_factory: CharacterStateFactory = CHARACTER_STATE_FACTORY_SCRIPT.new()

func setup(game_manager: Node):
	_game = game_manager

func create_player(id: int, cell: Vector2i, ai: bool, mat: Material, style := "male") -> CharacterState:
	var visual_data := visual_factory.create(id, cell, mat, style)
	var root := visual_data["root"] as Area3D
	var visual_root := visual_data["visual"] as Node3D
	_game.add_child(root)
	return state_factory.create(id, root, visual_root, cell, ai, style)

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

func apply_ai_difficulty(state: CharacterState, difficulty: String):
	match difficulty:
		"easy":
			state.configure_ai(difficulty, 3, 1, randf_range(0.55, 0.85), randf_range(3.2, 5.0))
		"hard":
			state.configure_ai(difficulty, 6, 3, randf_range(0.14, 0.26), randf_range(0.9, 1.7))
		_:
			state.configure_ai(difficulty, 5, 2, randf_range(0.22, 0.42), randf_range(1.6, 3.2))

func player_material_from_config(config: Dictionary) -> Material:
	return visual_factory.material_from_config(config)

func find_spawn_cell() -> Vector2i:
	var candidates: Array = []
	for y in range(1, Constants.GRID_H - 1):
		for x in range(1, Constants.GRID_W - 1):
			var cell := Vector2i(x, y)
			if _game.map_state.cell_at(cell) != Constants.Cell.EMPTY or _game.bomb_map.has(cell):
				continue
			if _game.powerups.has(cell) or _game.oil_barrels.has(cell) or _game.glue_areas.has(cell):
				continue
			var occupied := false
			for state: CharacterState in _game.character_registry.states():
				if state.is_alive() and state.cell() == cell:
					occupied = true
					break
			if not occupied:
				candidates.append(cell)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i): return a.distance_squared_to(Constants.PLAYER_START_CELL) > b.distance_squared_to(Constants.PLAYER_START_CELL))
	var pool_size := mini(12, candidates.size())
	return candidates[randi_range(0, pool_size - 1)]

func boss_data(boss_id: String) -> Dictionary:
	match boss_id:
		"frost_giant":
			return {"name": "Frost Giant", "hp": 12, "speed": 3, "range": 1, "bomb_max": 0, "move_interval": 0.48, "bomb_interval": 99.0, "skill_interval": 4.5, "material": _game.art.mat_boss_frost}
		"clone_demon":
			return {"name": "Clone Demon", "hp": 6, "speed": 6, "range": 2, "bomb_max": 2, "move_interval": 0.20, "bomb_interval": 1.4, "skill_interval": 5.0, "material": _game.art.mat_boss_clone}
		_:
			return {"name": "Blast King", "hp": 8, "speed": 5, "range": 5, "bomb_max": 3, "move_interval": 0.28, "bomb_interval": 0.75, "skill_interval": 3.5, "material": _game.art.mat_boss_blast}

func spawn_player(config: Dictionary, inventory_manager):
	var state := create_player(1, Constants.PLAYER_START_CELL, false, player_material_from_config(config), str(config["gender"]))
	state.configure_gameplay_stats(int(config["start_speed"]), int(config["start_bombs"]), int(config["start_range"]))
	state.effects.grant_shield(int(config["start_shields"]), Constants.SHIELD_DURATION)
	inventory_manager.add_item(state, "shield_potion")
	return state

func spawn_ai_wave(count: int, difficulty: String, start_id: int) -> int:
	var current_id := start_id
	var spawned := 0
	for i in range(count):
		var spawn_cell := find_spawn_cell()
		if spawn_cell == Vector2i(-1, -1):
			break
		var ai_state := create_player(current_id, spawn_cell, true, _game.art.mat_ai, "ai")
		current_id += 1
		spawned += 1
		apply_ai_difficulty(ai_state, difficulty)
		_game.register_character_state(ai_state)
		_game.character_presentation.play_spawn_effect(spawn_cell, false)
	return spawned

func spawn_boss(boss_id: String, boss_id_val: int) -> bool:
	var spawn_cell := find_spawn_cell()
	if spawn_cell == Vector2i(-1, -1):
		return false
	var boss_data_dict := boss_data(boss_id)
	var boss_state := create_player(boss_id_val, spawn_cell, true, boss_data_dict["material"], "boss")
	boss_state.configure_boss(
		boss_id,
		str(boss_data_dict["name"]),
		int(boss_data_dict["hp"]),
		int(boss_data_dict["speed"]),
		int(boss_data_dict["bomb_max"]),
		int(boss_data_dict["range"]),
		float(boss_data_dict["move_interval"]),
		float(boss_data_dict["bomb_interval"]),
		float(boss_data_dict["skill_interval"])
	)
	_game.character_presentation.set_character_scale(boss_state, Vector3.ONE * 1.45)
	_game.register_character_state(boss_state)
	_game.character_presentation.play_spawn_effect(spawn_cell, true)
	_game.audio_manager.play("boss_spawn")
	_game.game_ui.flash_boss_spawn()
	return true

func spawn_clone_minions(origin: Vector2i, start_id: int) -> int:
	var current_id := start_id
	var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	directions.shuffle()
	var spawned := 0
	for raw_direction in directions:
		var direction := raw_direction as Vector2i
		var cell: Vector2i = origin + direction
		if not _is_clone_spawn_walkable(cell):
			continue
		var minion_state := create_player(current_id, cell, true, _game.art.mat_boss_clone, "ai")
		current_id += 1
		minion_state.configure_minion(6, 0.18, "hard")
		_game.character_presentation.set_character_scale(minion_state, Vector3.ONE * 0.72)
		_game.register_character_state(minion_state)
		spawned += 1
		if spawned >= 2:
			break
	return spawned

func _is_clone_spawn_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= Constants.GRID_W or cell.y < 0 or cell.y >= Constants.GRID_H:
		return false
	if not _game.map_state.is_walkable(cell):
		return false
	if _game.bomb_map.has(cell):
		return false
	for state: CharacterState in _game.character_registry.states():
		if state.is_alive() and state.cell() == cell:
			return false
	return true
