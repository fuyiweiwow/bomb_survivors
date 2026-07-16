extends SceneTree

const WORLD_MAP_SCRIPT := preload("res://scripts/menu/world_map.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	LevelSession.clear()
	var progress_path := "user://level_progress_smoke_%d.json" % Time.get_ticks_usec()
	var repository := LevelProgressRepository.new(progress_path)
	var catalog := LevelCatalog.new()
	var levels := catalog.levels()
	if not _check(levels.size() == 6 and bool(levels[0]["tutorial"]) and int(levels[0]["max_waves"]) == 2, "Level catalog did not expose the six-stage tutorial campaign"):
		return
	var first_id := str(levels[0]["id"])
	var second_id := str(levels[1]["id"])
	if not _check(repository.is_unlocked(first_id) and not repository.is_unlocked(second_id), "Initial level progression did not unlock only level one"):
		return

	var world_map := WORLD_MAP_SCRIPT.new() as WorldMap
	world_map.progress_repository = repository
	root.add_child(world_map)
	await process_frame
	if not _check(world_map.level_buttons.size() == 6 and not (world_map.level_buttons[first_id] as Button).disabled and (world_map.level_buttons[second_id] as Button).disabled, "World map level nodes did not reflect unlock state"):
		return
	world_map.queue_free()
	await process_frame

	if not _check(LevelSession.select_level(first_id) and LevelSession.current_profile()["id"] == first_id, "Selecting level one did not establish a level session"):
		return
	var packed := load("res://scenes/game/main_3d.tscn") as PackedScene
	var bootstrap := packed.instantiate()
	root.add_child(bootstrap)
	await process_frame
	await process_frame
	var game := bootstrap.get_node("GameManager3D")
	if not _check(game.is_level_run() and str(game.level_profile["id"]) == first_id and game.wave_manager.max_wave == 2 and game.wave_manager.current_wave == 0 and not game.progression_coordinator.waves_started and game.ai_difficulty == "easy" and game.return_scene_path().ends_with("world_map.tscn"), "Tutorial level configuration, safe intro, or return path did not reach the game runtime"):
		return
	if not _check(game.tutorial_controller is TutorialController and game.tutorial_controller.tutorial_step == TutorialController.STEP_MOVE and game.tutorial_controller.prompt_text().contains("W / A / S / D"), "Tutorial did not start with movement guidance"):
		return
	var player := game.character_state_at(0) as CharacterState
	player.set_cell(player.cell() + Vector2i.RIGHT)
	game.tutorial_controller._process(0.1)
	if not _check(game.tutorial_controller.tutorial_step == TutorialController.STEP_BOMB and game.tutorial_controller.prompt_text().contains("Space"), "Tutorial did not advance to bomb guidance"):
		return
	player.data["bomb_placed_count"] = 1
	game.tutorial_controller._process(0.1)
	if not _check(game.tutorial_controller.tutorial_step == TutorialController.STEP_ITEM and game.tutorial_controller.prompt_text().contains("Shield Potion"), "Tutorial did not advance to backpack guidance"):
		return
	player.data["shield"] = 1
	game.inventory_manager.consume_item(player, "shield_potion")
	game.tutorial_controller._process(0.1)
	if not _check(game.tutorial_controller.tutorial_step == TutorialController.STEP_COMBAT and game.tutorial_controller.prompt_text().contains("TUTORIAL COMPLETE") and game.progression_coordinator.waves_started and game.wave_manager.current_wave == 1, "Tutorial did not finish or start combat after the three required actions"):
		return

	game.level_progress_repository = repository
	if not _check(game.complete_current_level() and repository.is_unlocked(second_id), "Completing level one did not unlock level two"):
		return
	bootstrap.queue_free()
	await process_frame
	LevelSession.clear()
	print("LEVEL_FLOW_SMOKE_OK catalog world_map locks session wave_profile tutorial_steps unlock_next")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	LevelSession.clear()
	quit(1)
	return false
