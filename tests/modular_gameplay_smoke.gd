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
	if not _check(not game.players.is_empty(), "Game did not create a player"):
		return

	var player: Dictionary = game.players[0]
	var bomb_cell := player["grid_pos"] as Vector2i
	if not _check(game.bomb_manager.try_place_bomb(0), "Bomb placement failed"):
		return
	if not _check(game.bomb_map.has(bomb_cell), "Placed bomb was not registered"):
		return
	if not _check(game.bomb_manager.active_blast_cell_set().has(bomb_cell), "Blast map missed bomb origin"):
		return
	if not _check(game.wall_mechanics.is_cell_occupied(bomb_cell), "Wall occupancy missed player"):
		return

	var shield_before := int(player["shield"])
	if not _check(game.consumable_effects.use(0, "shield_potion"), "Shield potion was rejected"):
		return
	if not _check(int(player["shield"]) == shield_before + 1, "Shield potion did not change player state"):
		return

	print("MODULAR_GAMEPLAY_SMOKE_OK modules=3 manager_lines_target=1700")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
