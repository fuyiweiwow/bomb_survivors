extends Node3D

const INVENTORY_MANAGER_SCRIPT := preload("res://scripts/item/inventory_manager.gd")
const ART_CATALOG_SCRIPT := preload("res://scripts/core/game_art_catalog.gd")
const SYSTEM_INSTALLER := preload("res://scripts/game/game_system_installer.gd")
const PLAYER_COMMAND_HANDLER := preload("res://scripts/game/player_command_handler.gd")
const PROGRESSION_COORDINATOR := preload("res://scripts/game/progression_coordinator.gd")

var grid_manager: Node
var player_manager: Node
var airborne_controller: Node
var airborne_collision_resolver: Node
var movement_controller: Node
var ai_controller: Node
var combat_manager: Node
var powerup_manager: Node
var game_ui: Node
var audio_manager: Node
var duel_manager: Node

var bomb_manager: Node
var wall_mechanics: Node
var consumable_effects: Node
var inventory_manager: RefCounted = INVENTORY_MANAGER_SCRIPT.new()
var weather_manager: Node
var wave_manager: Node
var input_controller: Node
var game_hud: Node
var player_commands: Node
var progression_coordinator: Node
var art: RefCounted = ART_CATALOG_SCRIPT.new()

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
	_setup_player_commands()
	_setup_progression()

func _setup_gameplay_systems():
	SYSTEM_INSTALLER.install(self)

func _setup_player_commands():
	player_commands = PLAYER_COMMAND_HANDLER.new()
	add_child(player_commands)
	player_commands.setup(self)

func _on_player_action(action: String):
	player_commands.handle_action(action)

func _setup_progression():
	progression_coordinator = PROGRESSION_COORDINATOR.new()
	add_child(progression_coordinator)
	progression_coordinator.setup(self)

func _spawn_players():
	var config: Dictionary = player_manager.load_player_config()
	inventory_manager = INVENTORY_MANAGER_SCRIPT.new()
	var player: Dictionary = player_manager.spawn_player(config, inventory_manager)
	players.append(player)

func _process(delta):
	if game_over:
		return
	progression_coordinator.process(delta)
	combat_manager.process_downed(delta)
	combat_manager.process_character_overlaps()
	combat_manager.process_terrain_effects(delta)
	wall_mechanics.process(delta)
	consumable_effects.process(delta)
	game_ui.update_hud()
	player_commands.process_player_input()
	ai_controller.process_ai(delta)
	game_ui.update_weather_visibility()

func _process_player_input():
	player_commands.process_player_input()

func _try_move_player_from_input(index: int) -> bool:
	return player_commands.try_move_from_input(index)

# Compatibility helper for systems that only need the current preferred input.
func read_player_move_direction() -> Vector2i:
	return player_commands.read_move_direction()

func _handle_player_bomb_action():
	player_commands.handle_bomb_action()

func _try_use_player_consumable():
	player_commands.use_consumable()

func _cycle_player_consumable():
	player_commands.cycle_consumable()

func _select_player_consumable(slot_index: int):
	player_commands.select_consumable(slot_index)

func _try_move_player(index: int, dir: Vector2i) -> bool:
	return movement_controller.try_move(index, dir)

func is_cell_walkable(x: int, y: int, player_index := -1) -> bool:
	return movement_controller.is_cell_walkable(Vector2i(x, y), player_index)

func _apply_explosion_damage(cells: Array, explosion_owner := -1, exploding_cell := Vector2i(-1, -1)):
	combat_manager.apply_explosion_damage(cells, explosion_owner, exploding_cell)

func _damage_player(index: int, amount: int, source: String):
	combat_manager.damage_player(index, amount, source)

func _kill_player(index: int):
	combat_manager.kill_player(index)
