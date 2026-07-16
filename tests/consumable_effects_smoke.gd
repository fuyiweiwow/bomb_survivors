extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/game/main_3d.tscn")
	var bootstrap := scene.instantiate()
	root.add_child(bootstrap)
	await process_frame
	var game := bootstrap.get_node("GameManager3D")
	game.game_over = true
	if game.character_registry.count() < 3:
		var spawned: int = game.player_manager.spawn_ai_wave(1, "normal", game.next_player_id)
		game.next_player_id += spawned
	if not _check(game.character_registry.count() >= 3, "Consumable test requires the initial player and two enemies"):
		return

	var player := game.character_state_at(0) as CharacterState
	var enemy_a := game.character_state_at(1) as CharacterState
	var enemy_b := game.character_state_at(2) as CharacterState
	var center := Vector2i(12, 12)
	_clear_region(game, center, 5)
	_place_state(player, center)
	_place_state(enemy_a, center + Vector2i(4, 0))
	_place_state(enemy_b, center + Vector2i(5, 0))
	if not _check(game.consumable_effects.use(0, "shield_potion") and player.effects.shield_time_left() == Constants.SHIELD_DURATION, "Shield Potion did not use the extended duration"):
		return
	if not _check(game.consumable_effects.use(0, "invincible_star") and player.effects.invincibility_time_left() == Constants.INVINCIBLE_DURATION, "Invincible Star did not use the extended duration"):
		return
	player.data["shield"] = 0
	player.data["shield_timer"] = 0.0
	player.data["invincible_timer"] = 0.0

	if not _check(game.consumable_effects.use(0, "glue") and game.glue_areas.size() == 9, "Glue did not cover the complete 3x3 neighborhood"):
		return
	if not _check(float((game.glue_areas[center] as Dictionary)["time"]) == Constants.GLUE_AREA_DURATION, "Glue did not use the extended area duration"):
		return
	if not _check(game.get_node_or_null("ItemActivation_glue") != null, "Glue did not create a visible activation outline"):
		return
	var glue_probe := center + Vector2i(1, 1)
	enemy_a.data["ai_difficulty"] = "easy"
	var easy_navigation: Dictionary = game.ai_controller._ai_navigation_cells(enemy_a, {})
	enemy_a.data["ai_difficulty"] = "normal"
	var normal_navigation: Dictionary = game.ai_controller._ai_navigation_cells(enemy_a, {})
	enemy_a.data["ai_difficulty"] = "hard"
	var hard_navigation: Dictionary = game.ai_controller._ai_navigation_cells(enemy_a, {})
	if not _check(easy_navigation.has(glue_probe) and normal_navigation.has(glue_probe) and not hard_navigation.has(glue_probe), "AI glue awareness did not differ by difficulty"):
		return
	_place_state(enemy_a, glue_probe)
	game.consumable_effects.area_effects.process(0.05)
	game.consumable_effects.status_visuals.refresh_player(enemy_a.data)
	if not _check(enemy_a.effects.is_slowed() and enemy_a.node().get_node_or_null("GlueSlowEffect") != null, "Glue slow did not create a visible character effect"):
		return

	_place_state(enemy_a, center + Vector2i(4, 4))
	_place_state(enemy_b, center + Vector2i(-4, -4))
	if not _check(game.consumable_effects.use(0, "prison"), "Prison rejected nearby enemies"):
		return
	if not _check(enemy_a.effects.is_imprisoned() and enemy_b.effects.is_imprisoned(), "Prison did not trap every enemy at the 9x9 boundary"):
		return
	if not _check(enemy_a.effects.prison_time_left() == Constants.PRISON_DURATION, "Prison did not use the extended duration"):
		return
	if not _check(game.get_node_or_null("ItemActivation_prison") != null, "Prison did not show its 9x9 activation boundary"):
		return
	if not _check(enemy_a.node().get_node_or_null("PrisonEffect") != null and enemy_b.node().get_node_or_null("PrisonEffect") != null, "Prison did not create visible cages"):
		return
	enemy_a.data["prison_timer"] = 0.0
	enemy_a.data["frozen_timer"] = 0.0
	enemy_b.data["prison_timer"] = 0.0
	enemy_b.data["frozen_timer"] = 0.0

	player.effects.grant_invincibility(20.0)
	enemy_a.effects.grant_invincibility(20.0)
	player.bombs.configure(3, 1)
	enemy_a.bombs.configure(3, 1)
	_place_state(player, center + Vector2i(-3, -3))
	_place_state(enemy_a, center + Vector2i(3, -3))
	if not _check(game.bomb_manager.try_place_bomb(0) and game.bomb_manager.try_place_bomb(1) and game.bomb_map.size() == 2, "Could not arrange bombs for the Detonator test"):
		return
	_place_state(player, center)
	if not _check(game.consumable_effects.use(0, "detonator") and game.bomb_map.is_empty(), "Detonator did not explode every bomb on the map"):
		return
	if not _check(game.get_node_or_null("ItemActivation_detonator") != null, "Detonator did not create a visible activation pulse"):
		return

	player.data["invincible_timer"] = 0.0
	player.data["shield"] = 0
	_place_state(player, center)
	if not _check(game.consumable_effects.use(0, "wings"), "Wings could not be used"):
		return
	if not _check(player.effects.wings_time_left() == Constants.WINGS_DURATION, "Wings did not use the extended duration"):
		return
	if not _check(player.node().get_node_or_null("WingsEffect") != null and game.get_node_or_null("ItemActivation_wings") != null, "Wings did not create persistent and activation visuals"):
		return
	if not _check(player.is_airborne() and player.world_position().y >= Constants.WINGS_FLIGHT_HEIGHT, "Wings did not launch the player to the high flight layer"):
		return
	game.combat_manager.apply_explosion_damage([center], -1, center, {}, false)
	if not _check(player.is_alive() and not player.is_downed(), "A ground bomb damaged a high-flying Wings user"):
		return
	game.player_commands.handle_bomb_action()
	if not _check(game.get_node_or_null("WingDropRock") == null, "Wings created an aerial rock without the Rock item"):
		return
	if not _check(game.consumable_effects.use(0, "rock"), "Rock could not be used"):
		return
	if not _check(player.effects.rock_time_left() == Constants.ROCK_DURATION, "Rock did not use the extended duration"):
		return
	if not _check(player.node().get_node_or_null("RockEffect") != null and game.get_node_or_null("ItemActivation_rock") != null, "Rock did not create persistent and activation visuals"):
		return
	_place_state(enemy_a, center)
	var bomb_count_before_rock: int = game.bomb_map.size()
	game.player_commands.handle_bomb_action()
	var dropped_rock := game.get_node_or_null("WingDropRock") as Node3D
	if not _check(dropped_rock != null and game.bomb_map.size() == bomb_count_before_rock, "Wing action did not create a rock-only airdrop"):
		return
	game.rock_attack_controller._impact_aerial_rock(dropped_rock, center, 0, player.world_position().y)
	if not _check(not enemy_a.is_alive() and game.get_node_or_null("WingRockImpact") != null, "Wing rock did not defeat the enemy below or show its impact"):
		return
	game.airborne_controller.force_land(0)
	player.effects.grant_wings(0.0)
	game.rock_attack_controller._last_attack_time_by_id.clear()
	_place_state(player, center)
	_place_state(enemy_a, center + Vector2i(3, 0))
	enemy_a.data["invincible_timer"] = 0.0
	enemy_a.data["shield"] = 0
	player.set_last_move_direction(Vector2i.RIGHT)
	game.player_commands.handle_bomb_action()
	var shot_rock := game.get_node_or_null("GroundRockShot") as Node3D
	if not _check(shot_rock != null and shot_rock.get_meta("impact_cell") == enemy_a.cell() and not game.bomb_map.has(center), "Rock did not target the first enemy along the movement direction"):
		return
	game.rock_attack_controller._impact_ground_rock(shot_rock, enemy_a.cell(), 0)
	if not _check(enemy_a.is_alive() and enemy_a.is_downed() and int(enemy_a.data["hp"]) == 0 and game.get_node_or_null("RockShotImpact") != null, "Ground Rock did not reduce a one-HP enemy to Down"):
		return
	player.effects.grant_rock(0.0)

	_place_state(player, center)
	_place_state(enemy_a, center + Vector2i(4, 0))
	player.bombs.configure(3, 1)
	player.data["bomb_placed_count"] = 0
	_place_state(player, center + Vector2i.RIGHT)
	if not _check(game.bomb_manager.try_place_bomb(0), "Could not place a bomb ahead of the player for Football Shoes"):
		return
	_place_state(player, center)
	player.set_last_move_direction(Vector2i.RIGHT)
	if not _check(game.consumable_effects.use(0, "football_shoes"), "Football Shoes could not be used"):
		return
	if not _check(player.effects.football_time_left() == Constants.FOOTBALL_DURATION, "Football Shoes did not use the extended duration"):
		return
	if not _check(game.movement_controller.try_move(0, Vector2i.RIGHT), "Football Shoes did not let the player move into a bomb"):
		return
	var enemy_kick_destination := enemy_a.cell()
	if not _check(game.bomb_map.has(enemy_kick_destination) and not game.bomb_map.has(center + Vector2i.RIGHT), "Football Shoes did not kick a safe bomb to a nearby enemy"):
		return
	game.movement_controller.cancel_move(player.data)
	game.bomb_manager.explode_bomb(enemy_kick_destination)

	_place_state(player, center)
	_place_state(enemy_a, center + Vector2i(-5, -5))
	player.bombs.configure(3, 3)
	player.data["bomb_placed_count"] = 0
	_place_state(player, center + Vector2i.RIGHT)
	if not _check(game.bomb_manager.try_place_bomb(0), "Could not place a long-range bomb for the safe Football Shoes kick"):
		return
	_place_state(player, center)
	player.set_last_move_direction(Vector2i.RIGHT)
	if not _check(game.movement_controller.try_move(0, Vector2i.RIGHT), "Football Shoes rejected a safe forward kick"):
		return
	var safe_kick_destination := center + Vector2i.RIGHT * 4
	if not _check(
		game.bomb_map.has(safe_kick_destination)
		and not game.bomb_manager.blast_cell_set(safe_kick_destination, 3).has(center),
		"Football Shoes did not move the bomb beyond its blast range"
	):
		return
	game.movement_controller.cancel_move(player.data)
	game.bomb_manager.explode_bomb(safe_kick_destination)

	_place_state(player, center + Vector2i.RIGHT)
	player.bombs.configure(3, 3)
	player.data["bomb_placed_count"] = 0
	if not _check(game.bomb_manager.try_place_bomb(0), "Could not place a bomb for the blocked Football Shoes kick"):
		return
	_place_state(player, center)
	game.grid_manager.set_cell(center.x + 2, center.y, Constants.Cell.WALL)
	if not _check(
		not game.movement_controller.try_move(0, Vector2i.RIGHT)
		and game.bomb_map.has(center + Vector2i.RIGHT),
		"Football Shoes moved or detonated a bomb without a safe landing cell"
	):
		return
	game.grid_manager.set_cell(center.x + 2, center.y, Constants.Cell.EMPTY)
	game.bomb_manager.explode_bomb(center + Vector2i.RIGHT)

	_place_state(player, center)
	player.set_move_direction(Vector2i.RIGHT)
	player.set_last_move_direction(Vector2i.RIGHT)
	if not _check(game.consumable_effects.use(0, "oil_barrel"), "Oil Barrel could not be placed"):
		return
	var barrel_cell := center + Vector2i.RIGHT
	var chained_bomb_cell := barrel_cell + Vector2i.DOWN
	_place_state(enemy_a, chained_bomb_cell)
	enemy_a.data["bomb_placed_count"] = 0
	if not _check(game.bomb_manager.try_place_bomb(1), "Could not place a bomb inside the future fire area"):
		return
	game.consumable_effects.damage_oil_barrel(barrel_cell)
	if not _check(game.fire_areas.size() == 81 and not game.bomb_map.has(chained_bomb_cell), "Oil Barrel did not create a 9x9 fire area or chain an enclosed bomb"):
		return
	if not _check(float((game.fire_areas[barrel_cell] as Dictionary)["time"]) == Constants.OIL_FIRE_DURATION, "Oil Barrel fire did not use the extended duration"):
		return
	if not _check(game.get_node_or_null("OilIgnitionWave") != null, "Oil ignition did not create an outward visual wave"):
		return

	_place_state(enemy_a, center)
	enemy_a.data["hp"] = Constants.NORMAL_AI_MAX_HP
	enemy_a.data["max_hp"] = Constants.NORMAL_AI_MAX_HP
	enemy_a.data["invincible_timer"] = 0.0
	enemy_a.data["shield"] = 0
	enemy_a.data["shield_timer"] = 0.0
	enemy_a.effects.reset_fire_exposure()
	game.consumable_effects.area_effects.process(0.10)
	game.consumable_effects.status_visuals.refresh_player(enemy_a.data)
	if not _check(enemy_a.node().get_node_or_null("BurningEffect") != null, "Oil fire did not create a visible burning effect on the character"):
		return
	game.consumable_effects.area_effects.process(Constants.OIL_FIRE_DAMAGE_TIME)
	if not _check(enemy_a.is_downed() and enemy_a.is_alive() and int(enemy_a.data["hp"]) == 0, "The first oil fire damage tick did not reduce a one-HP enemy to Down"):
		return
	game.consumable_effects.area_effects.process(Constants.OIL_FIRE_DAMAGE_TIME + 0.01)
	if not _check(not enemy_a.is_alive(), "An enemy that remained in oil fire was not defeated"):
		return

	if not _check(
		DuelRoundController.aggression_for_difficulty("easy") < DuelRoundController.aggression_for_difficulty("normal")
		and DuelRoundController.aggression_for_difficulty("normal") < DuelRoundController.aggression_for_difficulty("hard"),
		"Duel AI aggression does not increase with difficulty"
	):
		return
	print("CONSUMABLE_EFFECTS_SMOKE_OK glue_3x3 glue_ai_awareness prison_9x9 detonator_all wings_flight_only rock_ground_shot rock_wings_airdrop football_enemy_kick football_safe_kick football_blocked_kick oil_fire_9x9 oil_fire_chain oil_fire_defeat item_visual_feedback duel_aggression")
	quit(0)

func _clear_region(game: Node, center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			game.grid_manager.set_cell(x, y, Constants.Cell.EMPTY)

func _place_state(state: CharacterState, cell: Vector2i) -> void:
	state.data["alive"] = true
	state.data["downed"] = false
	state.data["downed_timer"] = 0.0
	state.data["airborne"] = false
	state.data["is_moving"] = false
	state.data["grid_motion_active"] = false
	state.set_cell(cell)
	state.node().position = Constants.grid_to_world(cell)

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
