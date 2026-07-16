extends Node3D

const UI_UPDATE_INTERVAL := 0.10

const INVENTORY_MANAGER_SCRIPT := preload("res://scripts/item/inventory_manager.gd")
const ART_CATALOG_SCRIPT := preload("res://scripts/core/game_art_catalog.gd")
const SYSTEM_INSTALLER := preload("res://scripts/game/game_system_installer.gd")
const PLAYER_COMMAND_HANDLER := preload("res://scripts/game/player_command_handler.gd")
const PROGRESSION_COORDINATOR := preload("res://scripts/game/progression_coordinator.gd")
const CHARACTER_REGISTRY_SCRIPT := preload("res://scripts/character/character_registry.gd")
const GAME_CONFIG_REPOSITORY_SCRIPT := preload("res://scripts/config/game_config_repository.gd")
const LEVEL_SESSION := preload("res://scripts/level/level_session.gd")
const LEVEL_PROGRESS_REPOSITORY_SCRIPT := preload("res://scripts/level/level_progress_repository.gd")
const TUTORIAL_CONTROLLER := preload("res://scripts/tutorial/tutorial_controller.gd")

var grid_manager: Node
var player_manager: Node
var character_presentation: Node
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
var direct_use_item_manager: Node
var rock_attack_controller: Node
var inventory_manager: RefCounted = INVENTORY_MANAGER_SCRIPT.new()
var weather_manager: Node
var wave_manager: Node
var input_controller: Node
var game_hud: Node
var player_commands: Node
var progression_coordinator: Node
var art: RefCounted = ART_CATALOG_SCRIPT.new()
var config_repository: GameConfigRepository = GAME_CONFIG_REPOSITORY_SCRIPT.new()
var level_progress_repository: LevelProgressRepository = LEVEL_PROGRESS_REPOSITORY_SCRIPT.new()
var level_profile: Dictionary = {}
var tutorial_controller: Node

var character_registry: CharacterRegistry = CHARACTER_REGISTRY_SCRIPT.new()
var players: Array:
	get: return character_registry.data_view()
var bomb_map: Dictionary = {}
var powerups: Dictionary = {}
var oil_barrels: Dictionary = {}
var glue_areas: Dictionary = {}
var fire_areas: Dictionary = {}
var world_environment: Environment = null
var game_over := false
var next_player_id := 2
var bomb_pressed := false
var ai_difficulty := "normal"
var _ui_update_accumulator := 0.0

var map_state: RefCounted:
	get: return grid_manager.map_state

var grid: Array:
	get: return grid_manager.grid

func _ready():
	add_to_group("game")
	randomize()
	level_profile = LEVEL_SESSION.current_profile()
	_setup_gameplay_systems()
	ai_difficulty = config_repository.load_ai_difficulty()
	var difficulty_override := str(level_profile.get("difficulty_override", ""))
	if not difficulty_override.is_empty():
		ai_difficulty = difficulty_override
	grid_manager.init_grid()
	grid_manager.create_world()
	_spawn_players()
	game_ui.setup_camera()
	game_ui.setup_hud()
	_setup_player_commands()
	_setup_tutorial()
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

func _setup_tutorial() -> void:
	if not bool(level_profile.get("tutorial", false)):
		return
	tutorial_controller = TUTORIAL_CONTROLLER.new()
	add_child(tutorial_controller)
	tutorial_controller.setup(self, level_profile)
	tutorial_controller.completed.connect(func(): progression_coordinator.start_waves())

func is_level_run() -> bool:
	return LEVEL_SESSION.has_selected_level() and not str(level_profile.get("id", "")).is_empty()

func return_scene_path() -> String:
	return "res://scenes/menu/world_map.tscn" if is_level_run() else "res://scenes/menu/main_menu.tscn"

func complete_current_level() -> bool:
	return is_level_run() and level_progress_repository.complete_level(str(level_profile["id"]))

func _spawn_players():
	var config: Dictionary = config_repository.load_player_config()
	inventory_manager = INVENTORY_MANAGER_SCRIPT.new()
	register_character_state(player_manager.spawn_player(config, inventory_manager))

func register_character_state(state: CharacterState) -> bool:
	var registered := character_registry.register(state)
	if not registered:
		var rejected_id := state.id() if state != null else -1
		push_error("Rejected duplicate or invalid character id %d" % rejected_id)
	return registered

func unregister_last_character_state() -> CharacterState:
	return character_registry.unregister_last()

func character_state_at(index: int) -> CharacterState:
	return character_registry.state_at(index)

func character_state_by_id(character_id: int) -> CharacterState:
	return character_registry.by_id(character_id)

func _process(delta):
	if game_over:
		return
	progression_coordinator.process(delta)
	combat_manager.process_downed(delta)
	combat_manager.process_character_overlaps()
	combat_manager.process_terrain_effects(delta)
	wall_mechanics.process(delta)
	consumable_effects.process(delta)
	player_commands.process_player_input()
	ai_controller.process_ai(delta)
	_ui_update_accumulator += delta
	if _ui_update_accumulator >= UI_UPDATE_INTERVAL:
		_ui_update_accumulator = fmod(_ui_update_accumulator, UI_UPDATE_INTERVAL)
		game_ui.update_hud()
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

func _discard_player_direct_item():
	player_commands.discard_direct_item()

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
