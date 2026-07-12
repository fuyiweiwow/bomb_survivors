extends SceneTree


func _init():
	call_deferred("_run")


func _run():
	var scene: PackedScene = load("res://scenes/game/main_3d.tscn")
	var bootstrap = scene.instantiate()
	root.add_child(bootstrap)
	await process_frame
	var game = bootstrap.get_node("GameManager3D")

	if not _check(game.bomb_manager != null, "BombManager was not initialized"):
		return
	if not _check(game.wall_mechanics != null, "WallMechanics was not initialized"):
		return
	if not _check(game.consumable_effects != null, "ConsumableEffects was not initialized"):
		return
	if not _check(game.movement_controller != null, "GridMovementController was not initialized"):
		return
	if not _check(not game.players.is_empty(), "Game did not create a player"):
		return

	var player: Dictionary = game.players[0]
	if not _check(game.players.size() > 1, "Initial AI wave was not created"):
		return
	if not _check(game.get_node_or_null("AISpawnEffect") != null, "AI spawn effect was not created"):
		return
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_D
	key_event.pressed = true
	game.input_controller._unhandled_input(key_event)
	if not _check(game.input_controller.consume_buffered_direction() == Vector2i.RIGHT, "Movement input was not buffered"):
		return
	game.grid_manager.set_cell(2, 1, Constants.Cell.EMPTY)
	if not _check(game._try_move_player(0, Vector2i.RIGHT), "Physics grid movement did not start"):
		return
	if not _check(player["move_tween"] == null and bool(player["grid_motion_active"]), "Grid movement still depends on a Tween"):
		return
	game.movement_controller._physics_process(1.0)
	if not _check(not player["is_moving"] and player["node"].position.is_equal_approx(Constants.grid_to_world(Vector2i(2, 1))), "Physics grid movement did not finish on the cell center"):
		return

	var forest_tile = game.grid_manager._create_forest_tile(Vector2i(5, 5))
	var trunk = forest_tile.get_child(0)
	var crown = forest_tile.get_child(1)
	if not _check(trunk.material_override != null and crown.material_override != null, "Forest trunk or leaf material is missing"):
		return
	forest_tile.free()

	var wall_cell := Vector2i(7, 5)
	var origin := Vector2i(7, 6)
	var previous := Vector2i(6, 6)
	for raw_cell in [wall_cell + Vector2i.LEFT, wall_cell + Vector2i.RIGHT, origin + Vector2i.LEFT, origin, origin + Vector2i.RIGHT]:
		var cell := raw_cell as Vector2i
		game.grid_manager.set_cell(cell.x, cell.y, Constants.Cell.EMPTY)
	game.grid_manager.set_cell(wall_cell.x, wall_cell.y, Constants.Cell.WALL)
	player["bomb_max"] = 2
	player["grid_pos"] = previous
	player["node"].position = Constants.grid_to_world(previous)
	if not _check(game.bomb_manager.try_place_bomb(0), "First hopping bomb placement failed"):
		return
	player["grid_pos"] = origin
	player["node"].position = Constants.grid_to_world(origin)
	if not _check(game.bomb_manager.try_place_bomb(0), "Second hopping bomb placement failed"):
		return
	if not _check(game.wall_mechanics.try_wall_hop(0, Vector2i.UP), "Strict wall hop was rejected"):
		return
	if not _check(player["grid_pos"] == wall_cell, "Wall hop did not move player onto wall"):
		return

	game.bomb_manager.explode_bomb(previous)
	if not _check(not game.bomb_map.has(previous) and not game.bomb_map.has(origin), "Bomb chain reaction did not detonate both bombs"):
		return

	var shield_before := int(player["shield"])
	if not _check(game.consumable_effects.use(0, "shield_potion"), "Shield potion was rejected"):
		return
	if not _check(int(player["shield"]) == shield_before + 1, "Shield potion did not change player state"):
		return

	var enemy: Dictionary = game.players[1]
	game.combat_manager._cancel_player_movement(player)
	player["alive"] = true
	player["downed"] = true
	player["grid_pos"] = enemy["grid_pos"]
	player["node"].position = enemy["node"].position
	game.combat_manager.process_character_overlaps()
	if not _check(not player["alive"], "Hostile overlap did not defeat downed player"):
		return
	var occupied_cell := enemy["grid_pos"] as Vector2i
	if not _check(game.is_cell_walkable(occupied_cell.x, occupied_cell.y, 0), "Living characters still block shared cells"):
		return

	print("GAME_DESIGN_SMOKE_OK physics_movement forest_materials wall_hop chain_reaction overlap spawn_fx")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
