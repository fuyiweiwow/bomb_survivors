extends Node3D

const INVENTORY_MANAGER_SCRIPT := preload("res://scripts/item/inventory_manager.gd")
const MAX_CONSUMABLES := INVENTORY_MANAGER_SCRIPT.MAX_ITEMS
const GAME_HUD := preload("res://scripts/ui/game_hud.gd")

var grid_manager: Node
var player_manager: Node
var airborne_controller: Node
var airborne_collision_resolver: Node
var movement_controller: Node
var ai_controller: Node
var combat_manager: Node
var powerup_manager: Node
var game_ui: Node

var bomb_manager: Node
var wall_mechanics: Node
var consumable_effects: Node
var inventory_manager: RefCounted = INVENTORY_MANAGER_SCRIPT.new()
var weather_manager: Node
var wave_manager: Node
var input_controller: Node
var game_hud: Node

var players: Array = []
var bomb_map: Dictionary = {}
var powerups: Dictionary = {}
var oil_barrels: Dictionary = {}
var glue_areas: Dictionary = {}
var world_environment: Environment = null
var game_over := false
var next_player_id := 2
var bomb_pressed := false
var ai_difficulty := "normal"

var grid: Array:
	get: return grid_manager.grid

var tex_floor: Texture2D = load("res://assets/art/3d/floor_tile.png")
var tex_wall: Texture2D = load("res://assets/art/3d/wall_block.png")
var tex_crate: Texture2D = load("res://assets/art/3d/crate_wood.png")
var tex_bomb: Texture2D = load("res://assets/art/3d/bomb_shell.png")
var tex_powerup: Texture2D = load("res://assets/art/3d/powerup_energy.png")
var tex_lava: Texture2D = load("res://assets/art/3d/lava_cracked.png")

var mat_floor_a := TerrainArtFactory.brushed_material(tex_floor, Color(0.70, 0.78, 0.66), TerrainArtFactory.PATCH_BRUSH)
var mat_floor_b := TerrainArtFactory.brushed_material(tex_floor, Color(0.82, 0.88, 0.76), TerrainArtFactory.PATCH_BRUSH)
var mat_wall := TerrainArtFactory.brushed_material(tex_wall, Color(0.72, 0.76, 0.82), TerrainArtFactory.PATCH_BRUSH)
var mat_crate := TerrainArtFactory.brushed_material(tex_crate, Color(1.0, 0.88, 0.70), TerrainArtFactory.PATCH_BRUSH)
var mat_player := MeshHelpers.make_mat(Color(0.18, 0.48, 0.95))
var mat_ai := MeshHelpers.make_mat(Color(0.95, 0.27, 0.22))
var mat_bomb := MeshHelpers.make_mat(Color(0.75, 0.75, 0.78), false, tex_bomb)
var mat_fire := MeshHelpers.make_mat(Color(1.0, 0.48, 0.08), true)
var mat_forest_floor := TerrainArtFactory.brushed_material(tex_floor, Color(0.18, 0.36, 0.18), TerrainArtFactory.DOTS_BRUSH)
var mat_leaf := MeshHelpers.make_mat(Color(0.10, 0.48, 0.16))
var mat_trunk := MeshHelpers.make_mat(Color(0.42, 0.24, 0.11))
var mat_lava := TerrainArtFactory.brushed_material(tex_lava, Color(0.95, 0.18, 0.04), TerrainArtFactory.LAVA_BRUSH, 0.8)
var mat_lava_glow := TerrainArtFactory.brushed_material(tex_lava, Color(1.0, 0.65, 0.08), TerrainArtFactory.LAVA_BRUSH, 1.5)
var mat_speed := MeshHelpers.make_mat(Color(0.2, 0.95, 0.85), true, tex_powerup)
var mat_bomb_power := MeshHelpers.make_mat(Color(0.95, 0.92, 0.25), true, tex_powerup)
var mat_range := MeshHelpers.make_mat(Color(1.0, 0.22, 0.12), true, tex_powerup)
var mat_shield := MeshHelpers.make_mat(Color(0.35, 0.55, 1.0), true, tex_powerup)
var mat_dummy := MeshHelpers.make_mat(Color(0.92, 0.78, 0.46), true, tex_powerup)
var mat_consumable := MeshHelpers.make_mat(Color(0.25, 0.92, 0.72), true, tex_powerup)
var mat_glue := MeshHelpers.make_mat(Color(0.92, 0.34, 0.78), true)
var mat_oil := MeshHelpers.make_mat(Color(0.18, 0.20, 0.22))
var mat_boss_blast := MeshHelpers.make_mat(Color(0.52, 0.08, 0.04), true)
var mat_boss_frost := MeshHelpers.make_mat(Color(0.40, 0.82, 1.0), true)
var mat_boss_clone := MeshHelpers.make_mat(Color(0.62, 0.22, 0.88), true)

func _ready():
	add_to_group("game")
	randomize()
	_setup_gameplay_systems()
	ai_difficulty = player_manager.load_ai_difficulty()
	grid_manager.init_grid()
	grid_manager.create_world()
	_spawn_players()
	game_ui.setup_camera()
	game_ui.setup_hud()
	_setup_input_controller()
	_setup_progression()

func _setup_gameplay_systems():
	bomb_manager = load("res://scripts/bomb/bomb_manager.gd").new()
	add_child(bomb_manager)
	bomb_manager.setup(self)
	wall_mechanics = load("res://scripts/terrain/wall_mechanics.gd").new()
	add_child(wall_mechanics)
	wall_mechanics.setup(self)
	consumable_effects = load("res://scripts/item/consumable_effects.gd").new()
	add_child(consumable_effects)
	consumable_effects.setup(self)

	grid_manager = load("res://scripts/grid/grid_manager.gd").new()
	add_child(grid_manager)
	grid_manager.setup(self, {
		"floor_a": mat_floor_a, "floor_b": mat_floor_b, "wall": mat_wall,
		"crate": mat_crate, "forest_floor": mat_forest_floor, "trunk": mat_trunk,
		"leaf": mat_leaf, "lava": mat_lava_glow
	})

	player_manager = load("res://scripts/character/player_manager.gd").new()
	add_child(player_manager)
	player_manager.setup(self)

	airborne_collision_resolver = load("res://scripts/character/airborne_collision_resolver.gd").new()
	add_child(airborne_collision_resolver)
	airborne_collision_resolver.setup(self)

	airborne_controller = load("res://scripts/character/airborne_controller.gd").new()
	add_child(airborne_controller)
	airborne_controller.setup(self)

	movement_controller = load("res://scripts/character/grid_movement_controller.gd").new()
	add_child(movement_controller)
	movement_controller.setup(self)

	ai_controller = load("res://scripts/character/ai_controller.gd").new()
	add_child(ai_controller)
	ai_controller.setup(self)

	combat_manager = load("res://scripts/combat/combat_manager.gd").new()
	add_child(combat_manager)
	combat_manager.setup(self)

	powerup_manager = load("res://scripts/bomb/powerup_manager.gd").new()
	add_child(powerup_manager)
	powerup_manager.setup(self)

	game_ui = load("res://scripts/ui/game_ui.gd").new()
	add_child(game_ui)
	game_ui.setup(self)

func _setup_input_controller():
	input_controller = load("res://scripts/character/player_input_controller.gd").new()
	add_child(input_controller)
	input_controller.action_requested.connect(_on_player_action)

func _on_player_action(action: String):
	if game_over:
		match action:
			"restart": get_tree().reload_current_scene()
			"menu": get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
			"cycle_item": get_tree().quit()
		return
	if action.begins_with("select_item_"):
		_select_player_consumable(int(action.trim_prefix("select_item_")))
		return
	match action:
		"bomb": bomb_pressed = true
		"use_item": _try_use_player_consumable()
		"cycle_item": _cycle_player_consumable()
		"menu": get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func _setup_progression():
	weather_manager = load("res://scripts/weather/weather_manager.gd").new()
	add_child(weather_manager)
	weather_manager.weather_changed.connect(game_ui.on_weather_changed)
	weather_manager.thunder_requested.connect(game_ui.request_thunder_strike)

	wave_manager = load("res://scripts/wave/wave_manager.gd").new()
	add_child(wave_manager)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.start()

func _spawn_players():
	var config: Dictionary = player_manager.load_player_config()
	inventory_manager = INVENTORY_MANAGER_SCRIPT.new()
	var player: Dictionary = player_manager.spawn_player(config, inventory_manager)
	players.append(player)

func _on_wave_started(wave_number: int, enemy_count: int, boss_id: String):
	if weather_manager:
		weather_manager.start_wave(wave_number, grid_manager.walkable_cells())
	if boss_id != "":
		grid_manager.refresh_crates_for_boss()
		player_manager.spawn_boss(boss_id, next_player_id)
		next_player_id += 1
	player_manager.spawn_ai_wave(enemy_count, ai_difficulty, next_player_id)
	next_player_id += 1

func _process(delta):
	if game_over:
		return
	if wave_manager:
		wave_manager.process_wave(delta)
	if weather_manager:
		weather_manager.process_weather(delta)
	combat_manager.process_downed(delta)
	combat_manager.process_character_overlaps()
	combat_manager.process_terrain_effects(delta)
	wall_mechanics.process(delta)
	consumable_effects.process(delta)
	game_ui.update_hud()
	_process_player_input()
	ai_controller.process_ai(delta)
	game_ui.update_weather_visibility()

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

	if not p["is_moving"] and input_controller:
		_try_move_player_from_input(0)

func _try_move_player_from_input(index: int) -> bool:
	if input_controller == null:
		return false
	for move_direction in input_controller.consume_move_candidates():
		if _try_move_player(index, move_direction):
			return true
	return false

# Compatibility helper for systems that only need the current preferred input.
func read_player_move_direction() -> Vector2i:
	if input_controller == null:
		return Vector2i.ZERO
	return input_controller.read_move_direction()

func _handle_player_bomb_action():
	var p: Dictionary = players[0]
	if bool(p.get("airborne", false)):
		p["status"] = "Cannot place a ground bomb in the air"
		return
	if float(p.get("football_timer", 0.0)) > 0.0:
		bomb_manager.kick_bomb_in_direction(p)
	elif int(p["bomb_placed_count"]) < int(p["bomb_max"]):
		bomb_manager.try_place_bomb(0)

func _try_use_player_consumable():
	if players.is_empty():
		return
	var p: Dictionary = players[0]
	if bool(p.get("downed", false)):
		if combat_manager._consume_dummy_if_available(p):
			combat_manager._revive_player(0)
		return
	if not p["alive"]:
		return
	var items: Array = p["consumables"]
	if items.is_empty():
		p["status"] = "Bag empty"
		return
	var item_id := str(inventory_manager.selected_item(p))
	if item_id == "dummy":
		p["status"] = "Dummy is passive"
		return
	if consumable_effects.use(0, item_id):
		inventory_manager.consume_selected(p)

func _cycle_player_consumable():
	if players.is_empty() or not players[0]["alive"]:
		return
	var p: Dictionary = players[0]
	var items: Array = p["consumables"]
	if items.is_empty():
		p["status"] = "Bag empty"
		return
	var selected_item := str(inventory_manager.cycle(p))
	p["status"] = "Selected %s" % powerup_manager._item_display_name(selected_item)

func _select_player_consumable(slot_index: int):
	if players.is_empty() or not players[0]["alive"]:
		return
	var p: Dictionary = players[0]
	var selected_item: String = inventory_manager.select_slot(p, slot_index)
	if selected_item.is_empty():
		p["status"] = "Bag slot %d empty" % (slot_index + 1)
		return
	p["status"] = "Selected %s" % powerup_manager._item_display_name(selected_item)

func _try_move_player(index: int, dir: Vector2i) -> bool:
	if index < 0 or index >= players.size():
		return false
	var p: Dictionary = players[index]
	if not bool(p.get("alive", false)) or bool(p.get("downed", false)) or bool(p.get("is_moving", false)):
		return false
	if float(p.get("frozen_timer", 0.0)) > 0.0:
		return false
	if dir == Vector2i.ZERO:
		return false
	var node: Node3D = p["node"]
	if not is_instance_valid(node):
		return false
	var current_cell := Constants.world_to_grid(node.position)
	p["grid_pos"] = current_cell
	if bool(p.get("impact_support", false)):
		wall_mechanics.leave_elevated_cell(p)
		airborne_controller.begin_fall(index)
	var is_airborne := bool(p.get("airborne", false))
	var target_height := node.position.y if is_airborne else (0.92 if float(p.get("wings_timer", 0.0)) > 0.0 else 0.0)
	var target_world := Constants.substep_target(node.position, dir, target_height)
	var target := Constants.world_to_grid(target_world)
	if target.x < 0 or target.x >= Constants.GRID_W or target.y < 0 or target.y >= Constants.GRID_H:
		return false
	if not is_airborne and target != current_cell and grid[target.y][target.x] == Constants.Cell.WALL:
		return wall_mechanics.try_wall_hop(index, dir)
	if not is_airborne and target != current_cell and not is_cell_walkable(target.x, target.y, index):
		return false

	p["last_move_dir"] = dir
	if (p["elevated_cell"] as Vector2i) != Vector2i(-1, -1):
		wall_mechanics.leave_elevated_cell(p)
	p["is_moving"] = true
	node.look_at(target_world, Vector3.UP)
	var move_duration: float = Constants.move_duration_for_speed(int(p["speed"])) / float(Constants.MOVE_SUBSTEPS_PER_TILE)
	if weather_manager:
		move_duration *= weather_manager.movement_duration_multiplier(target)
	if float(p.get("slow_timer", 0.0)) > 0.0:
		move_duration *= 3.33
	movement_controller.start_move(index, current_cell, target, target_world, move_duration)
	return true

func is_cell_walkable(x: int, y: int, player_index := -1) -> bool:
	if x < 0 or x >= Constants.GRID_W or y < 0 or y >= Constants.GRID_H:
		return false
	var has_wings := player_index >= 0 and player_index < players.size() and float(players[player_index].get("wings_timer", 0.0)) > 0.0
	if grid[y][x] == Constants.Cell.WALL or (not has_wings and not Constants.is_walkable_cell(grid[y][x])):
		return false
	var cell := Vector2i(x, y)
	if oil_barrels.has(cell) and not has_wings:
		return false
	if bomb_map.has(cell) and not has_wings and not _can_player_pass_bomb(player_index, cell):
		return false
	return true

func _can_player_pass_bomb(player_index: int, cell: Vector2i) -> bool:
	if player_index < 0 or player_index >= players.size() or not bomb_map.has(cell):
		return false
	var entry: Dictionary = bomb_map[cell]
	if int(entry.get("player_index", -1)) != player_index:
		return false
	var p: Dictionary = players[player_index]
	return bomb_manager.game_time() <= float(p.get("bomb_hop_until", -99.0)) and (p.get("bomb_hop_cells", {}) as Dictionary).has(cell)

func _apply_explosion_damage(cells: Array, explosion_owner := -1, exploding_cell := Vector2i(-1, -1)):
	combat_manager.apply_explosion_damage(cells, explosion_owner, exploding_cell)

func _damage_player(index: int, amount: int, source: String):
	combat_manager.damage_player(index, amount, source)

func _kill_player(index: int):
	combat_manager._kill_player(index)
