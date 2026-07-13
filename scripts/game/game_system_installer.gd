class_name GameSystemInstaller
extends RefCounted

const BOMB_MANAGER := preload("res://scripts/bomb/bomb_manager.gd")
const WALL_MECHANICS := preload("res://scripts/terrain/wall_mechanics.gd")
const CONSUMABLE_EFFECTS := preload("res://scripts/item/consumable_effects.gd")
const GRID_MANAGER := preload("res://scripts/grid/grid_manager.gd")
const PLAYER_MANAGER := preload("res://scripts/character/player_manager.gd")
const AIRBORNE_COLLISIONS := preload("res://scripts/character/airborne_collision_resolver.gd")
const AIRBORNE_CONTROLLER := preload("res://scripts/character/airborne_controller.gd")
const MOVEMENT_CONTROLLER := preload("res://scripts/character/grid_movement_controller.gd")
const AI_CONTROLLER := preload("res://scripts/character/ai_controller.gd")
const COMBAT_MANAGER := preload("res://scripts/combat/combat_manager.gd")
const POWERUP_MANAGER := preload("res://scripts/bomb/powerup_manager.gd")
const GAME_UI := preload("res://scripts/ui/game_ui.gd")
const AUDIO_MANAGER := preload("res://scripts/audio/audio_manager.gd")
const DUEL_MANAGER := preload("res://scripts/duel/duel_manager.gd")

static func install(game: Node) -> void:
	game.audio_manager = _install(game, AUDIO_MANAGER)
	game.duel_manager = _install(game, DUEL_MANAGER)
	game.bomb_manager = _install(game, BOMB_MANAGER)
	game.wall_mechanics = _install(game, WALL_MECHANICS)
	game.consumable_effects = _install(game, CONSUMABLE_EFFECTS)
	game.grid_manager = _install(game, GRID_MANAGER, false)
	game.grid_manager.setup(game, game.art.terrain_materials())
	game.player_manager = _install(game, PLAYER_MANAGER)
	game.airborne_collision_resolver = _install(game, AIRBORNE_COLLISIONS)
	game.airborne_controller = _install(game, AIRBORNE_CONTROLLER)
	game.movement_controller = _install(game, MOVEMENT_CONTROLLER)
	game.ai_controller = _install(game, AI_CONTROLLER)
	game.combat_manager = _install(game, COMBAT_MANAGER)
	game.powerup_manager = _install(game, POWERUP_MANAGER)
	game.game_ui = _install(game, GAME_UI)

static func _install(game: Node, script: Script, run_setup := true) -> Node:
	var system := script.new() as Node
	game.add_child(system)
	if run_setup:
		system.setup(game)
	return system
