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
	if not _check(game.airborne_controller != null, "AirborneController was not initialized"):
		return
	if not _check(game.airborne_collision_resolver != null, "AirborneCollisionResolver was not initialized"):
		return
	if not _check(game.ai_controller.lava_flight_strategy != null, "AI lava flight strategy was not initialized"):
		return
	if not _check(not game.players.is_empty(), "Game did not create a player"):
		return
	if not _check(Constants.GRID_W == 19 and Constants.GRID_H == 13, "Expanded grid dimensions are incorrect"):
		return
	if not _check(
		Constants.move_duration_for_speed(1) > Constants.move_duration_for_speed(5)
		and Constants.move_duration_for_speed(5) > Constants.move_duration_for_speed(10)
		and Constants.move_duration_for_speed(5) > 0.24,
		"Character speed curve is not gradual or remains too fast"
	):
		return
	for y in range(Constants.GRID_H):
		for x in range(Constants.GRID_W):
			var cell := Vector2i(x, y)
			if not _check(Constants.world_to_grid(Constants.grid_to_world(cell)) == cell, "Grid/world conversion did not preserve a tile center"):
				return

	var player: Dictionary = game.players[0]
	if not _check(game.players.size() > 1, "Initial AI wave was not created"):
		return
	game.weather_manager.current_weather = "clear"
	game.weather_manager.snow_cells.clear()
	game.game_ui.on_weather_changed("clear")
	var frontier_actor := player.duplicate(true)
	frontier_actor["grid_pos"] = Vector2i(1, 1)
	frontier_actor["ai_difficulty"] = "hard"
	var frontier_walkable := {Vector2i(1, 1): true, Vector2i(2, 1): true, Vector2i(3, 1): true}
	if not _check(
		AIDecisionPolicy.choose_direction(frontier_actor, {}, frontier_walkable, Vector2i(5, 1), true) == Vector2i.RIGHT,
		"AI did not advance toward the closest reachable frontier on a blocked large map"
	):
		return
	if not _check(game.game_ui._map_half_extents().x > 17.0 and game.game_ui._map_half_extents().y > 11.5, "Weather visuals still use the old map bounds"):
		return
	game.weather_manager.current_weather = "rain"
	if not _check(is_equal_approx(game.weather_manager.movement_duration_multiplier(Vector2i(1, 1)), 1.12), "Rain movement multiplier is incorrect"):
		return
	game.weather_manager.current_weather = "clear"
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
	var breach_enemy_cell := Vector2i(3, 3)
	var breach_crate_cell := Vector2i(5, 3)
	var breach_player_cell := Vector2i(7, 3)
	for breach_cell in [breach_enemy_cell, Vector2i(4, 3), breach_player_cell]:
		game.grid_manager.set_cell(breach_cell.x, breach_cell.y, Constants.Cell.EMPTY)
	game.grid_manager.set_cell(breach_crate_cell.x, breach_crate_cell.y, Constants.Cell.CRATE)
	enemy["grid_pos"] = breach_enemy_cell
	enemy["node"].position = Constants.grid_to_world(breach_enemy_cell)
	enemy["ai_difficulty"] = "normal"
	enemy["bomb_range"] = 3
	player["grid_pos"] = breach_player_cell
	player["node"].position = Constants.grid_to_world(breach_player_cell)
	if not _check(game.ai_controller._ai_should_place_bomb(1), "Normal AI did not bomb a crate blocking its route toward the player"):
		return
	game.grid_manager.set_cell(breach_crate_cell.x, breach_crate_cell.y, Constants.Cell.EMPTY)
	player["grid_pos"] = Vector2i(1, 1)
	player["node"].position = Constants.grid_to_world(Vector2i(1, 1))
	for lava_y in range(1, Constants.GRID_H - 1):
		for lava_x in range(1, Constants.GRID_W - 1):
			if game.grid[lava_y][lava_x] == Constants.Cell.LAVA:
				game.grid_manager.set_cell(lava_x, lava_y, Constants.Cell.EMPTY)
	var ai_lava_start := Vector2i(12, 9)
	var ai_lava_step := Vector2i(13, 9)
	var ai_lava_target := Vector2i(14, 9)
	for ai_lava_cell in [ai_lava_start, ai_lava_step]:
		game.grid_manager.set_cell(ai_lava_cell.x, ai_lava_cell.y, Constants.Cell.EMPTY)
	game.grid_manager.set_cell(ai_lava_target.x, ai_lava_target.y, Constants.Cell.LAVA)
	game.combat_manager._cancel_player_movement(enemy)
	enemy["alive"] = true
	enemy["downed"] = false
	enemy["airborne"] = false
	enemy["grid_pos"] = ai_lava_start
	enemy["node"].position = Constants.grid_to_world(ai_lava_start)
	enemy["ai_difficulty"] = "hard"
	enemy["speed"] = 6
	game.combat_manager.grant_shield(1)
	var lava_strategy = game.ai_controller.lava_flight_strategy
	var easy_actor := enemy.duplicate(true)
	easy_actor["ai_difficulty"] = "easy"
	var normal_actor := enemy.duplicate(true)
	normal_actor["ai_difficulty"] = "normal"
	if not _check(
		lava_strategy.activation_probability(easy_actor) < lava_strategy.activation_probability(normal_actor)
		and lava_strategy.activation_probability(normal_actor) < lava_strategy.activation_probability(enemy),
		"AI lava flight probability does not increase with difficulty"
	):
		return
	if not _check(not lava_strategy.should_activate(easy_actor, 0.20) and lava_strategy.should_activate(enemy, 0.20), "AI lava flight activation roll ignored difficulty probability"):
		return
	enemy["shield_timer"] = 1.0
	var lava_action: Dictionary = lava_strategy.choose_action(1, {}, 0.0)
	if not _check(not bool(lava_action["active"]), "AI selected lava without enough shield time to launch"):
		return
	game.combat_manager.grant_shield(1)
	lava_action = lava_strategy.choose_action(1, {}, 0.0)
	if not _check(bool(lava_action["active"]) and lava_action["direction"] == Vector2i.RIGHT and lava_action["target"] == ai_lava_target, "Shielded AI did not choose the reachable lava target"):
		return
	enemy["move_timer"] = float(enemy["move_interval"])
	game.ai_controller.process_ai(0.05)
	if not _check(bool(enemy["is_moving"]) and enemy["move_dir"] == Vector2i.RIGHT, "AI controller did not execute the lava strategy movement"):
		return
	game.movement_controller.cancel_move(enemy)
	enemy["grid_pos"] = ai_lava_target
	enemy["node"].position = Constants.grid_to_world(ai_lava_target)
	lava_action = lava_strategy.choose_action(1, {})
	if not _check(bool(lava_action["waiting"]) and lava_action["direction"] == Vector2i.ZERO, "AI did not wait on lava for the eruption"):
		return
	game.combat_manager.process_terrain_effects(Constants.LAVA_ERUPTION_TIME + 0.01)
	if not _check(bool(enemy["airborne"]), "Shielded AI did not launch from lava"):
		return
	if not _check(not game.bomb_manager.try_place_bomb(1), "Airborne AI placed a ground bomb"):
		return
	lava_strategy.choose_action(1, {})
	if not _check(enemy["lava_flight_target"] == Vector2i(-1, -1), "Airborne AI retained its lava target"):
		return
	game.airborne_controller.force_land(1)
	enemy["shield"] = 0
	enemy["shield_timer"] = 0.0

	var stomp_cell := Vector2i(8, 9)
	game.grid_manager.set_cell(stomp_cell.x, stomp_cell.y, Constants.Cell.EMPTY)
	game.combat_manager._cancel_player_movement(player)
	game.combat_manager._cancel_player_movement(enemy)
	player["alive"] = true
	player["downed"] = false
	player["grid_pos"] = stomp_cell
	player["node"].position = Constants.grid_to_world(stomp_cell) + Vector3(0, 1.20, 0)
	enemy["alive"] = true
	enemy["downed"] = false
	enemy["shield"] = 1
	enemy["shield_timer"] = Constants.SHIELD_DURATION
	enemy["grid_pos"] = stomp_cell
	enemy["node"].position = Constants.grid_to_world(stomp_cell)
	game.airborne_controller.begin_fall(0, -2.0)
	game.airborne_controller._physics_process(0.08)
	if not _check(not enemy["downed"] and int(enemy["shield"]) == 0, "Shield did not block an airborne stomp"):
		return
	if not _check(bool(player["airborne"]) and float(player["vertical_velocity"]) == Constants.STOMP_BOUNCE_VELOCITY, "Stomping player did not bounce"):
		return
	player["node"].position = Constants.grid_to_world(stomp_cell) + Vector3(0, 1.20, 0)
	game.airborne_controller.begin_fall(0, -2.0)
	game.airborne_controller._physics_process(0.08)
	if not _check(enemy["downed"] and enemy["alive"], "Unshielded stomp did not put the target into down state"):
		return
	game.combat_manager.process_character_overlaps()
	if not _check(enemy["downed"] and enemy["alive"], "Stomp bounce allowed immediate overlap execution"):
		return
	if not _check(game.get_node_or_null("StompImpact_1") != null, "Stomp impact visual was not created"):
		return
	game.combat_manager._revive_player(1)
	player["node"].position = Constants.grid_to_world(stomp_cell) + Vector3(0, 1.20, 0)
	player["vertical_velocity"] = -2.0
	game.airborne_controller._physics_process(0.08)
	if not _check(not enemy["downed"], "One airborne arc stomped the same target more than once"):
		return
	game.airborne_controller.force_land(0)
	enemy["grid_pos"] = ai_lava_start
	enemy["node"].position = Constants.grid_to_world(ai_lava_start)

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
	player["node"].position = blast_center + Vector3(Constants.BLAST_HIT_RADIUS, 0.0, 0.0)
	game.bomb_manager.detonate_cells([blast_cell])
	if not _check(not player["downed"], "Explosion hit a player at the one-third safe point"):
		return
	player["node"].position = blast_center
	game.bomb_manager._process_active_explosions(0.05)
	if not _check(player["downed"], "Player entering a visible active flame was not hit"):
		return
	game.combat_manager._revive_player(0)
	game.bomb_manager.active_explosions.clear()
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

	player["alive"] = true
	player["downed"] = false
	var shield_before := int(player["shield"])
	if not _check(game.consumable_effects.use(0, "shield_potion"), "Shield potion was rejected"):
		return
	if not _check(int(player["shield"]) == shield_before + 1, "Shield potion did not change player state"):
		return
	if not _check(is_equal_approx(float(player["shield_timer"]), Constants.SHIELD_DURATION), "Shield duration was not initialized"):
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
	game.combat_manager.process_terrain_effects(Constants.SHIELD_DURATION + 0.1)
	if not _check(int(player["shield"]) == 0 and float(player["shield_timer"]) == 0.0, "Shield did not expire after five seconds"):
		return

	var eruption_cell := Vector2i(5, 7)
	var blocked_air_cell := eruption_cell + Vector2i.RIGHT
	for setup_cell in [eruption_cell, eruption_cell + Vector2i.LEFT, eruption_cell + Vector2i.UP, eruption_cell + Vector2i.DOWN]:
		game.grid_manager.set_cell(setup_cell.x, setup_cell.y, Constants.Cell.EMPTY)
	game.grid_manager.set_cell(eruption_cell.x, eruption_cell.y, Constants.Cell.LAVA)
	game.grid_manager.set_cell(blocked_air_cell.x, blocked_air_cell.y, Constants.Cell.WALL)
	game.combat_manager._cancel_player_movement(player)
	player["alive"] = true
	player["downed"] = false
	player["airborne"] = false
	player["wings_timer"] = 0.0
	player["invincible_timer"] = 0.0
	player["shield"] = 1
	player["shield_timer"] = Constants.SHIELD_DURATION
	player["grid_pos"] = eruption_cell
	player["node"].position = Constants.grid_to_world(eruption_cell)
	game.combat_manager.process_terrain_effects(Constants.LAVA_ERUPTION_TIME + 0.01)
	if not _check(bool(player["airborne"]) and player["node"].position.y >= Constants.AIR_LAUNCH_HEIGHT - 0.001, "Shielded lava did not erupt and launch the player"):
		return
	game.grid_manager.set_cell(eruption_cell.x, eruption_cell.y, Constants.Cell.FOREST)
	if not _check(not Constants.is_player_hidden(game.players, 0, game.grid), "Airborne player was hidden by forest cover"):
		return
	game.grid_manager.set_cell(eruption_cell.x, eruption_cell.y, Constants.Cell.LAVA)

	player["node"].position = Constants.grid_to_world(eruption_cell) + Vector3(Constants.MOVE_STEP_SIZE, Constants.AIR_LAUNCH_HEIGHT, 0.0)
	player["grid_pos"] = eruption_cell
	if not _check(game._try_move_player(0, Vector2i.RIGHT), "Airborne movement did not cross a blocked ground cell"):
		return
	game.movement_controller.cancel_move(player)
	player["node"].position = Constants.grid_to_world(eruption_cell) + Vector3(0.0, Constants.AIR_LAUNCH_HEIGHT, 0.0)
	player["grid_pos"] = eruption_cell
	player["shield"] = 0
	player["shield_timer"] = 0.0
	game.combat_manager.apply_explosion_damage([eruption_cell])
	if not _check(not player["downed"], "Ground explosion hit a player above its height range"):
		return
	game.combat_manager.apply_explosion_damage(
		[eruption_cell],
		-1,
		eruption_cell,
		null,
		false,
		Constants.AERIAL_ATTACK_MIN_HEIGHT,
		Constants.AERIAL_ATTACK_MAX_HEIGHT
	)
	if not _check(player["downed"] and not bool(player["airborne"]), "Aerial attack did not hit and land an airborne player"):
		return
	if not _check(not Constants.is_lava_cell(game.grid, player["grid_pos"]), "Forced landing selected an unsafe lava cell"):
		return
	game.combat_manager._revive_player(0)
	player["grid_pos"] = eruption_cell
	player["node"].position = Constants.grid_to_world(eruption_cell)
	if not _check(game.airborne_controller.launch_from_lava(0), "Second lava launch was rejected"):
		return
	player["node"].position.y = 0.02
	player["vertical_velocity"] = -1.0
	game.airborne_controller._physics_process(0.05)
	if not _check(not bool(player["airborne"]) and is_equal_approx(player["node"].position.y, Constants.FLOOR_Y), "Airborne player did not descend and land"):
		return

	var impact_crate_cell := Vector2i(9, 7)
	game.grid_manager.set_cell(impact_crate_cell.x, impact_crate_cell.y, Constants.Cell.CRATE)
	var impact_crate := MeshHelpers.box(Vector3(1.2, 0.92, 1.2), game.mat_crate)
	impact_crate.position = Constants.grid_to_world(impact_crate_cell) + Vector3(0, 0.46, 0)
	game.add_child(impact_crate)
	game.grid_manager.crate_nodes[impact_crate_cell] = impact_crate
	player["grid_pos"] = impact_crate_cell
	player["node"].position = Constants.grid_to_world(impact_crate_cell) + Vector3(0, Constants.CRATE_SUPPORT_HEIGHT + 0.04, 0)
	player["airborne"] = true
	player["vertical_velocity"] = -1.0
	game.airborne_controller._physics_process(0.05)
	if not _check(not bool(player["airborne"]) and bool(player["impact_support"]) and player["elevated_cell"] == impact_crate_cell, "Player did not land on the crate support"):
		return
	if not _check(is_equal_approx(player["node"].position.y, Constants.CRATE_SUPPORT_HEIGHT), "Crate landing used the wrong height layer"):
		return
	if not _check(
		not game.combat_manager.is_player_in_attack_cells(player, [impact_crate_cell], Constants.GROUND_ATTACK_MIN_HEIGHT, Constants.GROUND_ATTACK_MAX_HEIGHT)
		and game.combat_manager.is_player_in_attack_cells(player, [impact_crate_cell], 0.96, 1.02),
		"Support height did not separate ground and same-height attacks"
	):
		return
	game.wall_mechanics.process(0.55)
	if not _check(player["impact_support_cracks"] != null and impact_crate.scale.y < 1.0, "Crate did not show a cracking warning"):
		return
	game.wall_mechanics.process(0.50)
	if not _check(game.grid[impact_crate_cell.y][impact_crate_cell.x] == Constants.Cell.EMPTY and bool(player["airborne"]), "Crate did not break and release the falling player after one second"):
		return
	if not _check(game.get_node_or_null("SupportBreakFragment_%d_%d_0" % [impact_crate_cell.x, impact_crate_cell.y]) != null, "Crate break fragments were not created"):
		return
	player["node"].position.y = 0.02
	player["vertical_velocity"] = -1.0
	game.airborne_controller._physics_process(0.05)

	var impact_wall_cell := Vector2i(11, 7)
	game.grid_manager.set_cell(impact_wall_cell.x, impact_wall_cell.y, Constants.Cell.WALL)
	var impact_wall := MeshHelpers.box(Vector3(1.2, 1.24, 1.2), game.mat_wall)
	impact_wall.position = Constants.grid_to_world(impact_wall_cell) + Vector3(0, 0.62, 0)
	game.add_child(impact_wall)
	game.grid_manager.wall_nodes[impact_wall_cell] = impact_wall
	player["grid_pos"] = impact_wall_cell
	player["node"].position = Constants.grid_to_world(impact_wall_cell) + Vector3(0, Constants.WALL_SUPPORT_HEIGHT + 0.04, 0)
	player["airborne"] = true
	player["vertical_velocity"] = -1.0
	game.airborne_controller._physics_process(0.05)
	if not _check(bool(player["impact_support"]) and is_equal_approx(player["node"].position.y, Constants.WALL_SUPPORT_HEIGHT), "Player did not land on the rock support"):
		return
	if not _check(game._try_move_player(0, Vector2i.LEFT) and bool(player["airborne"]) and not bool(player["impact_support"]), "Player could not actively leave a cracking support"):
		return
	game.movement_controller.cancel_move(player)
	if not _check(game.grid[impact_wall_cell.y][impact_wall_cell.x] == Constants.Cell.WALL and impact_wall.scale.is_equal_approx(Vector3.ONE), "Leaving a support did not cancel its cracking state"):
		return
	player["grid_pos"] = impact_wall_cell
	player["node"].position = Constants.grid_to_world(impact_wall_cell) + Vector3(0, Constants.WALL_SUPPORT_HEIGHT + 0.04, 0)
	player["airborne"] = true
	player["vertical_velocity"] = -1.0
	game.airborne_controller._physics_process(0.05)
	game.wall_mechanics.process(Constants.IMPACT_SUPPORT_BREAK_TIME + 0.01)
	if not _check(game.grid[impact_wall_cell.y][impact_wall_cell.x] == Constants.Cell.EMPTY and game.grid_manager.destroyed_walls.has(impact_wall_cell) and bool(player["airborne"]), "Rock did not break into its temporary destroyed state"):
		return
	player["node"].position.y = 0.02
	player["vertical_velocity"] = -1.0
	game.airborne_controller._physics_process(0.05)

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

	print("GAME_DESIGN_SMOKE_OK expanded_grid legacy_map attack_frontier crate_breach ai_lava_strategy difficulty_lava_probability ai_lava_wait airborne_ai_bomb_rule airborne_stomp shielded_stomp stomp_bounce stomp_overlap_safety stomp_single_hit subgrid_turning held_subgrid_motion shared_ai_movement active_world_blast timed_status_effects bomb_warning weather_bounds speed_curve forest_materials backpack_slots wall_hop chain_reaction overlap spawn_fx lava_launch airborne_movement vertical_attack_ranges safe_landing impact_support same_height_attack active_support_exit support_cracks support_fragments")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
