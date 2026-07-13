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
	var start_world := Constants.grid_to_world(Vector2i(1, 1))
	var substep_duration := Constants.move_duration_for_speed(int(player["speed"])) / float(Constants.MOVE_SUBSTEPS_PER_TILE)
	game.movement_controller._physics_process(substep_duration * 1.05)
	var first_substep_target := start_world + Vector3(Constants.MOVE_STEP_SIZE, 0.0, 0.0)
	if not _check(not player["is_moving"] and player["node"].position.is_equal_approx(first_substep_target), "Player did not stop at the first one-third tile point"):
		return
	if not _check(player["grid_pos"] == Vector2i(1, 1), "First substep changed the logical cell too early"):
		return
	if not _check(game._try_move_player(0, Vector2i.DOWN), "Player could not turn at an in-tile substep"):
		return
	game.movement_controller._physics_process(substep_duration * 1.05)
	if not _check(player["node"].position.is_equal_approx(first_substep_target + Vector3(0.0, 0.0, Constants.MOVE_STEP_SIZE)), "In-tile direction change did not preserve subgrid position"):
		return
	game.movement_controller.cancel_move(player)
	if not _check(player["node"].position.is_equal_approx(start_world), "Movement cancellation did not settle at the nearest logical center"):
		return
	var right_hold := InputEventKey.new()
	right_hold.physical_keycode = KEY_D
	right_hold.pressed = true
	game.input_controller._unhandled_input(right_hold)
	if not _check(game._try_move_player_from_input(0), "Held movement did not start"):
		return
	var full_tile_duration := Constants.move_duration_for_speed(int(player["speed"]))
	game.movement_controller._physics_process(full_tile_duration * 1.05)
	if not _check(player["is_moving"] and player["node"].position.x > Constants.grid_to_world(Vector2i(2, 1)).x, "Held movement paused at a full tile center"):
		return
	right_hold = InputEventKey.new()
	right_hold.physical_keycode = KEY_D
	right_hold.pressed = false
	game.input_controller._unhandled_input(right_hold)
	game.movement_controller._physics_process(substep_duration * 1.05)
	if not _check(not player["is_moving"], "Released movement did not stop at the next one-third tile point"):
		return
	game.movement_controller.cancel_move(player)

	var enemy: Dictionary = game.players[1]
	game.combat_manager._cancel_player_movement(enemy)
	var ai_start := Vector2i(10, 6)
	var ai_target := Vector2i(11, 6)
	game.grid_manager.set_cell(ai_start.x, ai_start.y, Constants.Cell.EMPTY)
	game.grid_manager.set_cell(ai_target.x, ai_target.y, Constants.Cell.EMPTY)
	enemy["grid_pos"] = ai_start
	enemy["node"].position = Constants.grid_to_world(ai_start)
	enemy["move_dir"] = Vector2i.RIGHT
	if not _check(game._try_move_player(1, Vector2i.RIGHT), "AI subgrid movement did not start"):
		return
	var ai_move_duration := Constants.move_duration_for_speed(int(enemy["speed"]))
	game.movement_controller._physics_process(ai_move_duration * 1.05)
	if not _check(not enemy["is_moving"] and enemy["grid_pos"] == ai_target and enemy["node"].position.is_equal_approx(Constants.grid_to_world(ai_target)), "AI did not use the same three-substep movement path"):
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
	var warning_entry: Dictionary = game.bomb_map[previous]
	game.bomb_manager._update_bomb_warning(warning_entry, 1.15)
	if not _check((warning_entry["warning"] as GeometryInstance3D).transparency < 0.1, "Bomb warning did not flash during the final countdown"):
		return
	game.bomb_manager._update_bomb_warning(warning_entry, 1.0)
	if not _check((warning_entry["warning"] as GeometryInstance3D).transparency > 0.9, "Bomb warning did not alternate between flashes"):
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
	if not _check(player["node"].get_node_or_null("ShieldEffect") != null, "Shield potion did not create a character effect"):
		return
	for effect_data in [
		{"timer": "invincible_timer", "node": "InvincibleEffect"},
		{"timer": "wings_timer", "node": "WingsEffect"},
		{"timer": "football_timer", "node": "FootballEffect"},
	]:
		player[effect_data["timer"]] = 1.0
		game.consumable_effects.status_visuals.refresh_player(player)
		if not _check(player["node"].get_node_or_null(effect_data["node"]) != null, "%s was not created" % effect_data["node"]):
			return
		player[effect_data["timer"]] = 0.0
		game.consumable_effects.status_visuals.refresh_player(player)

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

	print("GAME_DESIGN_SMOKE_OK expanded_grid legacy_map subgrid_turning held_subgrid_motion shared_ai_movement world_blast status_effects bomb_warning forest_materials backpack_slots wall_hop chain_reaction overlap spawn_fx")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
