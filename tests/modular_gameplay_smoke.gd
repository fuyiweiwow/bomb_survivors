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
	if not _check(game.audio_manager != null, "GameAudioManager was not initialized"):
		return
	if not _check(game.duel_manager != null and game.duel_manager.arena_catalog.arena_ids().has("lava_rift"), "DuelManager or its arena extension point was not initialized"):
		return
	for event_id in ["explosion", "pickup", "shield", "footstep", "ui_select"]:
		var stream := game.audio_manager.event_stream(event_id) as AudioStream
		if not _check(stream != null and stream.get_length() > 0.0, "Audio event %s did not load a valid stream" % event_id):
			return
	if not _check(not game.audio_manager.play("missing_event"), "Unknown audio events were accepted"):
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
	if not _check(game.ai_controller.boss_behavior != null, "Boss behavior controller was not initialized"):
		return
	if not _check(game.player_commands != null and game.input_controller.get_parent() == game.player_commands, "Player command boundary was not initialized"):
		return
	if not _check(game.progression_coordinator != null and game.wave_manager.get_parent() == game.progression_coordinator, "Progression coordinator was not initialized"):
		return
	if not _check(game.art != null and game.art.terrain_materials()["wall"] == game.art.mat_wall, "Shared art catalog was not initialized"):
		return
	if not _check(game.config_repository is GameConfigRepository, "GameManager3D did not own the shared configuration boundary"):
		return
	if not _check(not game.players.is_empty(), "Game did not create a player"):
		return
	if not _check(Constants.GRID_W == 38 and Constants.GRID_H == 26 and is_equal_approx(Constants.TILE_SIZE, 0.9), "Refined logical grid dimensions are incorrect"):
		return
	if not _check(
		Constants.move_duration_for_speed(1) > Constants.move_duration_for_speed(5)
		and Constants.move_duration_for_speed(5) > Constants.move_duration_for_speed(10)
		and Constants.move_duration_for_speed(5) > 0.12,
		"Character speed curve is not gradual or remains too fast"
	):
		return
	for y in range(Constants.GRID_H):
		for x in range(Constants.GRID_W):
			var cell := Vector2i(x, y)
			if not _check(Constants.world_to_grid(Constants.grid_to_world(cell)) == cell, "Grid/world conversion did not preserve a tile center"):
				return

	var player: Dictionary = game.players[0]
	if not _check(game.map_state is MapState and game.map_state.cells == game.grid, "Game does not expose MapState as the canonical map model"):
		return
	if not _check(game.character_registry is CharacterRegistry and game.character_registry.count() == game.players.size() and game.character_state_at(0).data == player, "CharacterRegistry is not synchronized with the compatibility player view"):
		return
	if not _check(game.character_registry.query_at(0) is CharacterQuery and game.character_registry.queries().size() == game.character_registry.count(), "CharacterRegistry did not expose typed character queries"):
		return
	var detached_view: Array = game.players
	detached_view.clear()
	if not _check(game.character_registry.count() > 0 and not game.players.is_empty(), "Compatibility player view can mutate CharacterRegistry membership"):
		return
	if not _check(game.character_presentation is CharacterPresentation, "Character presentation was not installed by the composition root"):
		return
	if not _check(game.player_manager.visual_factory is PlayerVisualFactory, "PlayerManager still owns player mesh construction"):
		return
	if not _check(game.player_manager.state_factory is CharacterStateFactory, "PlayerManager still owns the character data schema"):
		return
	if not _check(game.player_manager.boss_catalog is BossCatalog and game.player_manager.boss_catalog.profile("clone_demon")["material"] == game.art.mat_boss_clone, "PlayerManager still owns Boss profile data or the catalog art binding failed"):
		return
	if not _check(not player.has("state_tween"), "Character domain data still stores presentation Tween state"):
		return
	if not _check(game.combat_manager.rules is CombatRules, "CombatManager does not delegate decisions to CombatRules"):
		return
	if not _check(game.combat_manager.terrain_effects is TerrainEffectProcessor, "Terrain effects remain embedded in CombatManager"):
		return
	var player_shape := ((player["node"] as Area3D).get_child(0) as CollisionShape3D).shape as CapsuleShape3D
	if not _check(player_shape != null and player_shape.radius * 2.0 <= Constants.TILE_SIZE, "Player footprint exceeds one refined cell"):
		return
	if not _check(is_instance_valid(player.get("visual_node")) and (player["visual_node"] as Node3D).get_parent() == player["node"], "Player visuals are not isolated from the movement and collision root"):
		return
	if not _check(game.players.size() > 1, "Initial AI wave was not created"):
		return
	if not _check(game.weather_manager.current_weather == "clear", "The first wave did not start with clear weather"):
		return
	game.game_ui.update_weather_visibility()
	for enemy_index in range(1, game.players.size()):
		var initial_enemy: Dictionary = game.players[enemy_index]
		if not _check(game.grid[initial_enemy["grid_pos"].y][initial_enemy["grid_pos"].x] == Constants.Cell.EMPTY, "An initial enemy spawned on hidden or hazardous terrain"):
			return
		if not _check((initial_enemy["node"] as Node3D).visible, "An initial enemy was hidden immediately after spawning"):
			return
	var players_before_progression: int = game.players.size()
	var next_id_before_progression := int(game.next_player_id)
	game.progression_coordinator._on_wave_started(2, 2, "")
	if not _check(game.players.size() == players_before_progression + 2 and int(game.next_player_id) == next_id_before_progression + 2, "Progression did not advance IDs by the actual enemy count"):
		return
	var spawned_ids: Dictionary = {}
	for active_player: Dictionary in game.players:
		if not _check(not spawned_ids.has(active_player["id"]), "Progression created duplicate character IDs"):
			return
		spawned_ids[active_player["id"]] = true
	while game.players.size() > players_before_progression:
		var temporary_state := game.unregister_last_character_state() as CharacterState
		if temporary_state != null and temporary_state.node() != null:
			temporary_state.node().queue_free()
	game.next_player_id = next_id_before_progression
	game.weather_manager.current_weather = "clear"
	game.weather_manager.snow_cells.clear()
	game.game_ui.on_weather_changed("clear")
	var frontier_actor := player.duplicate(true)
	frontier_actor["grid_pos"] = Vector2i(1, 1)
	frontier_actor["ai_difficulty"] = "hard"
	var frontier_query := CharacterQuery.new(frontier_actor)
	var frontier_walkable := {Vector2i(1, 1): true, Vector2i(2, 1): true, Vector2i(3, 1): true}
	if not _check(
		AIDecisionPolicy.choose_direction(frontier_query, {}, frontier_walkable, Vector2i(5, 1), true) == Vector2i.RIGHT,
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
	if not _check(game.powerup_manager.item_display_name("tianlao") == "Prison", "Prison item still exposes its internal pinyin ID"):
		return
	game._try_use_player_consumable()
	if not _check((player["consumables"] as Array).is_empty() and int(player["shield"]) == 1, "Using the starter shield potion did not consume only the backpack item"):
		return
	var shield_pickup_node := Node3D.new()
	game.add_child(shield_pickup_node)
	game.powerups[player["grid_pos"]] = {"node": shield_pickup_node, "type": "shield"}
	var active_shields_before_pickup := int(player["shield"])
	game.powerup_manager.check_powerup_pickup(0)
	if not _check(int(player["shield"]) == active_shields_before_pickup, "A picked-up shield activated immediately instead of entering the backpack"):
		return
	if not _check((player["consumables"] as Array) == ["shield_potion"], "A picked-up shield was not stored as a shield potion"):
		return
	player["shield"] = 0
	player["shield_timer"] = 0.0
	game.consumable_effects.status_visuals.refresh_player(player)
	var inventory_probe := {"consumables": [], "selected_consumable_index": 0}
	game.inventory_manager.add_item(inventory_probe, "shield_potion")
	game.inventory_manager.add_item(inventory_probe, "shield_potion")
	game.inventory_manager.add_item(inventory_probe, "shield_potion")
	inventory_probe["selected_consumable_index"] = 2
	game.inventory_manager.add_item(inventory_probe, "glue")
	if not _check(inventory_probe["consumables"] == ["shield_potion", "shield_potion", "glue"], "A full backpack did not replace its oldest item or rejected duplicate shields"):
		return
	if not _check(int(inventory_probe["selected_consumable_index"]) == 1, "Backpack replacement left the selected slot invalid"):
		return
	game.inventory_manager.add_item(player, "glue")
	var slot_two := InputEventKey.new()
	slot_two.physical_keycode = KEY_2
	slot_two.pressed = true
	game.input_controller._unhandled_input(slot_two)
	if not _check(int(player["selected_consumable_index"]) == 1 and game.inventory_manager.selected_item(player) == "glue", "Number key did not select backpack slot 2"):
		return
	game.inventory_manager.add_item(player, "duel")
	game._select_player_consumable(2)
	game._try_use_player_consumable()
	if not _check(bool(player["duel_pending"]) and not (player["consumables"] as Array).has("duel"), "Duel Token did not arm and consume from the backpack"):
		return
	game.combat_manager.damage_player(0, 1, "duel immunity probe")
	if not _check(player["alive"] and not bool(player["downed"]), "Armed Duel Token did not grant damage immunity"):
		return
	var duel_enemy: Dictionary = game.players[1]
	var duel_trigger_position: Vector3 = player["node"].position
	duel_enemy["node"].position = duel_trigger_position
	duel_enemy["grid_pos"] = player["grid_pos"]
	var bombs_before_duel: int = game.bomb_map.size()
	if not _check(game.duel_manager.process_pending_contact(), "Touching an enemy did not start the duel"):
		return
	if not _check(game.duel_manager.active and paused and game.duel_manager.current_arena_id == "lava_rift", "Duel did not pause the original map in a registered arena"):
		return
	if not _check(not game.game_hud.visible and game.duel_manager.round.actors.size() == 2, "Duel HUD or fighters were not initialized"):
		return
	if not _check(game.duel_manager.round.actors[0].character_node.get_node_or_null("DuelWings") != null and game.duel_manager.round.actors[1].character_node.get_node_or_null("DuelWings") != null, "Duel fighters did not receive unlimited wings"):
		return
	if not _check(not game.consumable_effects.use(0, "shield_potion") and not game.bomb_manager.try_place_bomb(0) and game.bomb_map.size() == bombs_before_duel, "Duel did not lock the original backpack and bomb ability"):
		return
	var duel_round = game.duel_manager.round
	var duel_arena = game.duel_manager.arena
	var human_duelist := duel_round.actors[0] as DuelActorState
	var enemy_duelist := duel_round.actors[1] as DuelActorState
	human_duelist.character_node.position.x = float(duel_arena.lava_centers[0])
	human_duelist.character_node.position.y = duel_arena.floor_y()
	human_duelist.airborne = false
	duel_round.process_round(DuelRoundController.LAVA_CHARGE_TIME + 0.01)
	if not _check(human_duelist.airborne and human_duelist.vertical_velocity > 0.0, "Duel lava did not launch the winged player"):
		return
	var enemy_duel_hp_before := enemy_duelist.health
	human_duelist.character_node.position = enemy_duelist.character_node.position + Vector3(0, 0.35, 0)
	human_duelist.airborne = true
	human_duelist.diving = true
	human_duelist.vertical_velocity = DuelRoundController.DIVE_VELOCITY
	human_duelist.hit_cooldown = 0.0
	duel_round.resolve_dive_collisions()
	if not _check(enemy_duelist.health == enemy_duel_hp_before - 1, "A duel dive did not damage the opponent"):
		return
	var lava_refreshes_before := int(duel_arena.lava_refresh_count)
	duel_round.lava_refresh_timer = 0.0
	duel_round.process_round(0.01)
	if not _check(int(duel_arena.lava_refresh_count) == lava_refreshes_before + 1 and duel_arena.lava_centers.size() == LavaRiftArena.LAVA_ZONE_COUNT, "Duel lava did not refresh randomly"):
		return
	game.duel_manager.resolve_current_duel(true)
	await process_frame
	if not _check(not game.duel_manager.active and not paused and game.game_hud.visible, "Winning a duel did not restore the original map"):
		return
	if not _check(duel_enemy["downed"], "Duel victory opponent state: alive=%s downed=%s status=%s enemy_index=%s" % [duel_enemy["alive"], duel_enemy["downed"], duel_enemy["status"], game.duel_manager.current_enemy_index]):
		return
	if not _check(player["node"].position.is_equal_approx(duel_trigger_position), "Duel victory restored the player to %s instead of %s" % [player["node"].position, duel_trigger_position]):
		return
	game.combat_manager._revive_player(1)
	game._select_player_consumable(0)
	var crates_before_refresh: int = game.grid_manager.crate_nodes.size()
	var refreshed_crates: Array[Vector2i] = game.grid_manager.refresh_crates_for_boss(3)
	if not _check(refreshed_crates.size() == 3 and game.grid_manager.crate_nodes.size() == crates_before_refresh + 3, "Boss crate refresh did not add the requested crates"):
		return
	for refreshed_cell in refreshed_crates:
		if not _check(game.grid[refreshed_cell.y][refreshed_cell.x] == Constants.Cell.CRATE, "Boss crate refresh did not update the map grid"):
			return
		for active_player: Dictionary in game.players:
			if not _check(not active_player["alive"] or active_player["grid_pos"] != refreshed_cell, "Boss crate refresh placed a crate under a character"):
				return
		var refreshed_node = game.grid_manager.crate_nodes.get(refreshed_cell)
		if is_instance_valid(refreshed_node):
			refreshed_node.queue_free()
		game.grid_manager.crate_nodes.erase(refreshed_cell)
		game.grid_manager.set_cell(refreshed_cell.x, refreshed_cell.y, Constants.Cell.EMPTY)
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
	var movement_start := Constants.PLAYER_START_CELL
	var movement_right := movement_start + Vector2i.RIGHT
	var movement_down := movement_right + Vector2i.DOWN
	for movement_cell in [movement_start, movement_right, movement_down, movement_right + Vector2i.RIGHT]:
		game.grid_manager.set_cell(movement_cell.x, movement_cell.y, Constants.Cell.EMPTY)
	game.movement_controller.cancel_move(player)
	player["grid_pos"] = movement_start
	player["node"].position = Constants.grid_to_world(movement_start)
	if not _check(game._try_move_player(0, Vector2i.RIGHT), "Physics grid movement did not start"):
		return
	if not _check(player["move_tween"] == null and bool(player["grid_motion_active"]), "Grid movement still depends on a Tween"):
		return
	var cell_duration := Constants.move_duration_for_speed(int(player["speed"]))
	game.movement_controller._physics_process(cell_duration * 1.05)
	if not _check(not player["is_moving"] and player["node"].position.is_equal_approx(Constants.grid_to_world(movement_right)), "Player did not arrive at the adjacent refined cell"):
		return
	if not _check(player["grid_pos"] == movement_right, "Player logical occupancy did not advance by exactly one refined cell"):
		return
	if not _check(game._try_move_player(0, Vector2i.DOWN), "Player could not turn at the next refined cell"):
		return
	game.movement_controller._physics_process(cell_duration * 1.05)
	if not _check(player["grid_pos"] == movement_down and player["node"].position.is_equal_approx(Constants.grid_to_world(movement_down)), "Cell-center turn did not preserve logical occupancy"):
		return
	game.movement_controller.cancel_move(player)
	if not _check(player["node"].position.is_equal_approx(Constants.grid_to_world(movement_down)), "Movement cancellation did not settle at the current refined cell"):
		return
	player["grid_pos"] = movement_start
	player["node"].position = Constants.grid_to_world(movement_start)
	var right_hold := InputEventKey.new()
	right_hold.physical_keycode = KEY_D
	right_hold.pressed = true
	game.input_controller._unhandled_input(right_hold)
	if not _check(game._try_move_player_from_input(0), "Held movement did not start"):
		return
	game.movement_controller._physics_process(cell_duration * 1.05)
	if not _check(player["is_moving"] and player["node"].position.x > Constants.grid_to_world(movement_right).x, "Held movement paused at a refined cell center"):
		return
	right_hold = InputEventKey.new()
	right_hold.physical_keycode = KEY_D
	right_hold.pressed = false
	game.input_controller._unhandled_input(right_hold)
	game.movement_controller._physics_process(cell_duration * 1.05)
	if not _check(not player["is_moving"] and Constants.is_world_position_at_cell_center(player["node"].position, player["grid_pos"]), "Released movement did not stop at the next refined cell center"):
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
	if not _check(game._try_move_player(1, Vector2i.RIGHT), "AI refined-grid movement did not start"):
		return
	var ai_move_duration := Constants.move_duration_for_speed(int(enemy["speed"]))
	game.movement_controller._physics_process(ai_move_duration * 1.05)
	if not _check(not enemy["is_moving"] and enemy["grid_pos"] == ai_target and enemy["node"].position.is_equal_approx(Constants.grid_to_world(ai_target)), "AI did not occupy exactly one adjacent refined cell"):
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
	enemy["grid_pos"] = ai_lava_start
	enemy["node"].position = Constants.grid_to_world(ai_lava_start)
	enemy["wings_timer"] = Constants.WINGS_DURATION
	lava_strategy.notify_protection_granted(enemy)
	lava_action = lava_strategy.choose_action(1, {}, 0.0)
	if not _check(bool(lava_action["active"]) and lava_action["target"] == ai_lava_target, "Winged AI did not reuse the lava flight strategy"):
		return
	lava_strategy.cancel(enemy, true)
	enemy["wings_timer"] = 0.0

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
	var ground_cell := game.get_node_or_null("GroundCell_1_1") as MeshInstance3D
	if not _check(ground_cell != null and is_equal_approx(float(ground_cell.get_meta("logical_cell_size", 0.0)), Constants.TILE_SIZE), "Ground did not expose one mesh per refined logical cell"):
		return
	var ground_mesh := ground_cell.mesh as BoxMesh
	if not _check(ground_mesh != null and ground_mesh.size.x < Constants.TILE_SIZE and ground_mesh.size.x > Constants.TILE_SIZE * 0.9, "Ground cell mesh does not fit one refined logical cell"):
		return
	var footprint_wall := game.grid_manager.wall_nodes.values()[0] as MeshInstance3D
	var wall_mesh := footprint_wall.mesh as CylinderMesh
	if not _check(wall_mesh != null and wall_mesh.bottom_radius * 2.0 <= Constants.TILE_SIZE, "Wall footprint exceeds one refined cell"):
		return
	var footprint_crate := game.grid_manager.crate_nodes.values()[0] as MeshInstance3D
	var crate_mesh := footprint_crate.mesh as BoxMesh
	if not _check(crate_mesh != null and crate_mesh.size.x <= Constants.TILE_SIZE and crate_mesh.size.z <= Constants.TILE_SIZE, "Crate footprint exceeds one refined cell"):
		return
	player["shield"] = 0
	player["alive"] = true
	player["downed"] = false
	player["grid_pos"] = blast_cell
	player["node"].position = blast_center + Vector3(Constants.BLAST_HIT_RADIUS + 0.01, 0.0, 0.0)
	game.combat_manager.apply_explosion_damage([blast_cell])
	if not _check(not player["downed"], "Player outside the logical tile was still hit by an explosion"):
		return
	player["node"].position = blast_center + Vector3(Constants.BLAST_HIT_RADIUS - 0.01, 0.0, 0.0)
	game.combat_manager.apply_explosion_damage([blast_cell])
	if not _check(player["downed"], "Player inside the logical tile avoided an explosion"):
		return
	game.combat_manager._revive_player(0)
	player["node"].position = blast_center
	player["node"].position = blast_center + Vector3(Constants.BLAST_HIT_RADIUS + 0.01, 0.0, 0.0)
	game.bomb_manager.detonate_cells([blast_cell])
	var blast_visual := game.get_node_or_null("Explosion_%d_%d" % [blast_cell.x, blast_cell.y]) as MeshInstance3D
	var blast_mesh := blast_visual.mesh as BoxMesh if blast_visual != null else null
	if not _check(blast_mesh != null and blast_mesh.size.x <= Constants.TILE_SIZE and blast_mesh.size.z <= Constants.TILE_SIZE, "Explosion visual exceeds one refined cell"):
		return
	if not _check(not player["downed"], "Explosion hit a player beyond the logical tile boundary"):
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
	var legacy_data := {"version": 2, "width": 19, "height": 13, "cells": {"7,5": Constants.Cell.CRATE}}
	var map_codec = load("res://scripts/grid/map_data_codec.gd")
	if not _check(not map_codec.decode_into_grid(legacy_data, legacy_grid, Constants.GRID_W, Constants.GRID_H, Constants.Cell.EMPTY, Constants.Cell.WALL), "Incompatible legacy map was accepted"):
		return
	var current_data := {"version": 3, "width": Constants.GRID_W, "height": Constants.GRID_H, "cells": {"18,12": Constants.Cell.CRATE}}
	if not _check(map_codec.decode_into_grid(current_data, legacy_grid, Constants.GRID_W, Constants.GRID_H, Constants.Cell.EMPTY, Constants.Cell.WALL), "Current refined map could not be decoded"):
		return
	if not _check(legacy_grid[12][18] == Constants.Cell.CRATE and legacy_grid[12][19] == Constants.Cell.EMPTY, "Current map element did not occupy exactly one refined cell"):
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
	var bomb_shell_mesh := (warning_entry["shell"] as MeshInstance3D).mesh as SphereMesh
	if not _check(bomb_shell_mesh != null and bomb_shell_mesh.radius * 2.0 <= Constants.TILE_SIZE, "Bomb footprint exceeds one refined cell"):
		return
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

	player["grid_pos"] = eruption_cell
	player["node"].position = Constants.grid_to_world(eruption_cell) + Vector3(0.0, 0.92, 0.0)
	player["shield"] = 0
	player["shield_timer"] = 0.0
	player["wings_timer"] = Constants.WINGS_DURATION
	game.combat_manager.process_terrain_effects(Constants.LAVA_ERUPTION_TIME + 0.01)
	if not _check(bool(player["airborne"]) and player["node"].position.y >= Constants.AIR_LAUNCH_HEIGHT - 0.001, "Wings did not allow lava to launch the player"):
		return
	var wing_launch_velocity := float(player["vertical_velocity"])
	game.airborne_controller._physics_process(1.0)
	if not _check(
		is_equal_approx(float(player["vertical_velocity"]), wing_launch_velocity - Constants.WINGS_AIR_GRAVITY)
		and Constants.WINGS_AIR_GRAVITY < Constants.AIR_GRAVITY,
		"Wings did not extend airborne time with reduced gravity"
	):
		return
	game.combat_manager.process_terrain_effects(Constants.LAVA_DAMAGE_TIME + 0.01)
	if not _check(float(player["lava_time"]) == 0.0 and not player["downed"], "Airborne wings user was burned by lava"):
		return
	var airborne_height_before_expiry := float(player["node"].position.y)
	player["wings_timer"] = 0.05
	game.combat_manager.process_terrain_effects(0.10)
	if not _check(bool(player["airborne"]) and is_equal_approx(float(player["node"].position.y), airborne_height_before_expiry), "Wings expiry pulled an airborne player back to the ground"):
		return
	player["node"].position.y = 0.02
	player["vertical_velocity"] = -1.0
	game.airborne_controller._physics_process(0.05)

	var impact_crate_cell := Vector2i(9, 7)
	game.grid_manager.set_cell(impact_crate_cell.x, impact_crate_cell.y, Constants.Cell.CRATE)
	var impact_crate := MeshHelpers.box(Vector3(1.2, 0.92, 1.2), game.art.mat_crate)
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
		not game.combat_manager.is_player_in_attack_cells(game.character_state_at(0), [impact_crate_cell], Constants.GROUND_ATTACK_MIN_HEIGHT, Constants.GROUND_ATTACK_MAX_HEIGHT)
		and game.combat_manager.is_player_in_attack_cells(game.character_state_at(0), [impact_crate_cell], 0.96, 1.02),
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
	var impact_wall := MeshHelpers.box(Vector3(1.2, 1.24, 1.2), game.art.mat_wall)
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
	for event_id in ["bomb_place", "explosion", "shield", "stomp", "crate_break", "wall_break", "pickup", "ui_select", "footstep"]:
		if not _check(int(game.audio_manager.played_events.get(event_id, 0)) > 0, "Gameplay did not emit the %s audio event" % event_id):
			return

	print("GAME_DESIGN_SMOKE_OK modular_composition config_repository boss_catalog character_query character_registry character_presentation visual_factory state_factory shared_art_catalog audio_events duel_actor_state duel_token_immunity duel_arena_catalog duel_world_pause duel_locked_loadout duel_lava_launch duel_dive_damage duel_random_lava duel_win_restore progression_unique_ids boss_behavior_boundary refined_logical_grid visible_initial_spawn clear_first_wave shield_pickup_inventory duplicate_inventory_fifo boss_crate_refresh strict_map_config attack_frontier crate_breach ai_lava_strategy difficulty_lava_probability ai_lava_wait winged_ai_bomb_rule airborne_stomp shielded_stomp stomp_bounce stomp_overlap_safety stomp_single_hit one_cell_ground full_cell_blast cell_center_turning held_grid_motion shared_ai_movement active_world_blast timed_status_effects bomb_warning weather_bounds speed_curve forest_materials backpack_slots wall_hop chain_reaction overlap spawn_fx lava_launch wing_lava_launch wing_airborne_immunity wing_extended_flight airborne_movement vertical_attack_ranges safe_landing impact_support same_height_attack active_support_exit support_cracks support_fragments")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
