extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/game/main_3d.tscn") as PackedScene
	var bootstrap = scene.instantiate()
	root.add_child(bootstrap)
	await process_frame
	await process_frame
	var game = bootstrap.get_node("GameManager3D")
	var player: Dictionary = game.players[0]
	if not _check(game.bomb_manager.try_place_bomb(0), "Could not place the original-map timer probe"):
		return
	var bomb_entry: Dictionary = game.bomb_map[player["grid_pos"]]
	var bomb_timer := bomb_entry["timer"] as Timer
	var time_before_duel := bomb_timer.time_left
	if not _check(game.duel_manager.start_duel_with_enemy(0, 1), "Could not start duel loss flow"):
		return
	await create_timer(0.25).timeout
	if not _check(absf(bomb_timer.time_left - time_before_duel) < 0.05, "Original-map bomb timer advanced during the duel"):
		return
	game.duel_manager.resolve_current_duel(false)
	await process_frame
	if not _check(not paused and not player["alive"], "Losing the duel did not defeat the player and restore the tree"):
		return
	await create_timer(0.45).timeout
	if not _check(game.game_over, "Duel loss did not enter the normal game-over flow"):
		return
	print("DUEL_FAILURE_SMOKE_OK frozen_original_map player_defeat game_over")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	paused = false
	push_error(message)
	quit(1)
	return false
