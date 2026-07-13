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
	if not _check(Constants.GRID_W == 19 and Constants.GRID_H == 13, "Expanded grid dimensions are incorrect"):
		return
	for y in range(Constants.GRID_H):
		for x in range(Constants.GRID_W):
			var cell := Vector2i(x, y)
			if not _check(Constants.world_to_grid(Constants.grid_to_world(cell)) == cell, "Grid/world conversion did not preserve a tile center"):
				return

	var player: Dictionary = game.players[0]
	if not _check(game.players.size() > 1, "Initial AI wave was not created"):
		return
	game.game_ui.update_hud()
	if not _check(game.game_hud.inventory_slot_labels[0].text.contains("Shield Potion"), "Backpack HUD does not show the starter item"):
		return
	game.inventory_manager.add_item(player, "glue")
	var slot_two := InputEventKey.new()
	slot_two.physical_keycode = KEY_2
	slot_two.pressed = true
	game.input_controller._unhandled_input(slot_two)
	if not _check(int(player["selected_consumable_index"]) == 1 and game.inventory_manager.selected_item(player) == "glue", "Number key did not select backpack slot 2"):
		return
	game._select_player_consumable(0)
	if not _check(game.get_node_or_null("AISpawnEffect") != null, "AI spawn effect was not created"):
		return
	var left_press := InputEventKey.new()
	left_press.physical_keycode = KEY_A
	left_press.pressed = true
	game.input_controller._unhandled_input(left_press)
	var up_press := InputEventKey.new()
	up_press.physical_keycode = KEY_W
	up_press.pressed = true
	game.input_controller._unhandled_input(up_press)
	var priority_candidates: Array[Vector2i] = game.input_controller.consume_move_candidates()
	if not _check(priority_candidates.size() >= 2 and priority_candidates[0] == Vector2i.UP and priority_candidates[1] == Vector2i.LEFT, "Newest movement direction did not receive priority"):
		return
	var up_release := InputEventKey.new()
	up_release.physical_keycode = KEY_W
	up_release.pressed = false
	game.input_controller._unhandled_input(up_release)
	if not _check(game.input_controller.read_move_direction() == Vector2i.LEFT, "Released direction did not fall back to a held direction"):
		return
	var left_release := InputEventKey.new()
	left_release.physical_keycode = KEY_A
	left_release.pressed = false
	game.input_controller._unhandled_input(left_release)
	if not _check(game.input_controller.read_move_direction() == Vector2i.ZERO, "Movement continued after all direction keys were released"):
		return
	var right_tap := InputEventKey.new()
	right_tap.physical_keycode = KEY_D
	right_tap.pressed = true
	game.input_controller._unhandled_input(right_tap)
	right_tap = InputEventKey.new()
	right_tap.physical_keycode = KEY_D
	right_tap.pressed = false
	game.input_controller._unhandled_input(right_tap)
	if not _check(game.input_controller.consume_buffered_direction() == Vector2i.RIGHT, "Tapped movement input was not buffered"):
		return
	game.grid_manager.set_cell(2, 1, Constants.Cell.EMPTY)
	if not _check(game._try_move_player(0, Vector2i.RIGHT), "Physics grid movement did not start"):
		return
	if not _check(player["move_tween"] == null and bool(player["grid_motion_active"]), "Grid movement still depends on a Tween"):
		return
	if not _check(player["grid_pos"] == Vector2i(1, 1), "Grid position advanced before the character left its source cell"):
		return
	var move_duration := Constants.move_duration_for_speed(int(player["speed"]))
	game.movement_controller._physics_process(move_duration * 0.49)
	if not _check(player["grid_pos"] == Vector2i(1, 1) and Constants.world_to_grid(player["node"].position) == Vector2i(1, 1), "World position left the source grid too early"):
		return
	game.movement_controller._physics_process(move_duration * 0.06)
	if not _check(player["grid_pos"] == Vector2i(2, 1) and bool(player["is_moving"]), "Grid position did not follow the character across the cell boundary"):
		return
	game.movement_controller._physics_process(1.0)
	if not _check(not player["is_moving"] and player["node"].position.is_equal_approx(Constants.grid_to_world(Vector2i(2, 1))), "Physics grid movement did not finish on the cell center"):
		return
	if not _check(game._try_move_player(0, Vector2i.LEFT), "Movement cancellation test did not start"):
		return
	game.movement_controller._physics_process(move_duration * 0.25)
	game.movement_controller.cancel_move(player)
	if not _check(player["grid_pos"] == Vector2i(2, 1) and player["node"].position.is_equal_approx(Constants.grid_to_world(Vector2i(2, 1))), "Early movement cancellation did not return to the source cell"):
		return
	if not _check(game._try_move_player(0, Vector2i.LEFT), "Late movement cancellation test did not start"):
		return
	game.movement_controller._physics_process(move_duration * 0.75)
	game.movement_controller.cancel_move(player)
	if not _check(player["grid_pos"] == Vector2i(1, 1) and player["node"].position.is_equal_approx(Constants.grid_to_world(Vector2i(1, 1))), "Late movement cancellation did not settle in the entered cell"):
		return

	var blast_cell := Vector2i(1, 1)
	var blast_center := Constants.grid_to_world(blast_cell)
	player["shield"] = 0
	player["alive"] = true
	player["downed"] = false
	player["grid_pos"] = blast_cell
	player["node"].position = blast_center + Vector3(Constants.BLAST_HIT_RADIUS, 0.0, 0.0)
	game.combat_manager.apply_explosion_damage([blast_cell])
	if not _check(not player["downed"], "Player at one-third tile distance was still hit by an explosion"):
		return
	player["node"].position = blast_center + Vector3(Constants.BLAST_HIT_RADIUS - 0.01, 0.0, 0.0)
	game.combat_manager.apply_explosion_damage([blast_cell])
	if not _check(player["downed"], "Player inside one-third tile distance avoided an explosion"):
		return
	game.combat_manager._revive_player(0)
	player["node"].position = blast_center

	var legacy_grid: Array = []
	for y in Constants.GRID_H:
		var legacy_row: Array = []
		legacy_row.resize(Constants.GRID_W)
		legacy_row.fill(Constants.Cell.EMPTY)
		legacy_grid.append(legacy_row)
	var legacy_data := {"0,0": Constants.Cell.WALL, "14,10": Constants.Cell.WALL, "7,5": Constants.Cell.CRATE}
	var map_codec = load("res://scripts/grid/map_data_codec.gd")
	if not _check(map_codec.decode_into_grid(legacy_data, legacy_grid, Constants.GRID_W, Constants.GRID_H, Constants.Cell.EMPTY, Constants.Cell.WALL), "Legacy map could not be migrated"):
		return
	if not _check(legacy_grid[6][9] == Constants.Cell.CRATE and legacy_grid[1][2] == Constants.Cell.EMPTY, "Legacy map content was not centered without its old border"):
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

	print("GAME_DESIGN_SMOKE_OK expanded_grid legacy_map continuous_grid_sync physics_movement world_blast forest_materials backpack_slots wall_hop chain_reaction overlap spawn_fx")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
