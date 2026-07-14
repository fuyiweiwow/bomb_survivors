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

	if not _check(game.consumable_effects.use(0, "glue") and game.glue_areas.size() == 9, "Glue did not cover the complete 3x3 neighborhood"):
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

	_place_state(enemy_a, center + Vector2i(1, 0))
	_place_state(enemy_b, center + Vector2i(0, 1))
	if not _check(game.consumable_effects.use(0, "prison"), "Prison rejected nearby enemies"):
		return
	if not _check(enemy_a.effects.is_imprisoned() and enemy_b.effects.is_imprisoned(), "Prison did not trap every enemy in the 3x3 neighborhood"):
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

	var air_blast_count: int = game.bomb_manager.active_explosions.size()
	player.effects.grant_wings(Constants.WINGS_DURATION)
	player.set_cell(center)
	player.node().position = Constants.grid_to_world(center) + Vector3(0, 2.0, 0)
	player.begin_airborne(0.0, "Airborne")
	game.player_commands.handle_bomb_action()
	if not _check(not game.bomb_map.has(center) and game.bomb_manager.active_explosions.size() == air_blast_count + 1, "Airborne bomb did not detonate immediately"):
		return
	game.airborne_controller.force_land(0)
	player.effects.grant_wings(0.0)

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
	for hit in range(4):
		game.consumable_effects.damage_oil_barrel(barrel_cell)
	if not _check(game.fire_areas.size() == 9 and not game.bomb_map.has(chained_bomb_cell), "Oil Barrel did not create a 3x3 fire area or chain an enclosed bomb"):
		return

	_place_state(enemy_a, center)
	enemy_a.data["invincible_timer"] = 0.0
	enemy_a.data["shield"] = 0
	enemy_a.data["shield_timer"] = 0.0
	enemy_a.effects.reset_fire_exposure()
	game.consumable_effects.area_effects.process(Constants.OIL_FIRE_DAMAGE_TIME + 0.01)
	if not _check(enemy_a.is_downed() and enemy_a.is_alive(), "Persistent oil fire did not put an exposed enemy into Down"):
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
	print("CONSUMABLE_EFFECTS_SMOKE_OK glue_3x3 glue_ai_awareness prison_3x3 detonator_all wing_air_bomb oil_fire_chain oil_fire_defeat duel_aggression")
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
