extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/game/main_3d.tscn") as PackedScene
	var bootstrap := scene.instantiate()
	root.add_child(bootstrap)
	await process_frame
	await process_frame
	var game = bootstrap.get_node("GameManager3D")
	var controller := game.ai_controller.boss_behavior as BossBehaviorController
	if controller == null or controller.strategy_ids().size() != 3:
		_fail("Boss strategy registry was not initialized")
		return

	var blast_index: int = game.character_registry.count()
	if not game.player_manager.spawn_boss("blast_king", game.next_player_id):
		_fail("Blast King could not spawn")
		return
	game.next_player_id += 1
	var blast_state := game.character_state_at(blast_index) as CharacterState
	blast_state.advance_boss_skill_timer(blast_state.boss_skill_interval())
	controller.process_skill(blast_index, 0.0)
	if blast_state.bombs.placed_count() != 1 or not is_equal_approx(blast_state.boss_skill_time_left(), 3.5):
		_fail("Blast King strategy did not place a bomb and reset its catalog cooldown")
		return

	var frost_index: int = game.character_registry.count()
	if not game.player_manager.spawn_boss("frost_giant", game.next_player_id):
		_fail("Frost Giant could not spawn")
		return
	game.next_player_id += 1
	var frost_state := game.character_state_at(frost_index) as CharacterState
	var player_state := game.character_state_at(0) as CharacterState
	var adjacent_cell := _adjacent_interior_cell(frost_state.cell())
	player_state.set_cell(adjacent_cell)
	player_state.node().position = Constants.grid_to_world(adjacent_cell)
	frost_state.advance_boss_skill_timer(frost_state.boss_skill_interval())
	controller.process_skill(frost_index, 0.0)
	if not player_state.effects.is_frozen() or not player_state.status().contains("Frozen"):
		_fail("Frost Giant strategy did not freeze a nearby grounded player")
		return

	var clone_index: int = game.character_registry.count()
	if not game.player_manager.spawn_boss("clone_demon", game.next_player_id):
		_fail("Clone Demon could not spawn")
		return
	game.next_player_id += 1
	var clone_state := game.character_state_at(clone_index) as CharacterState
	var count_before_minions: int = game.character_registry.count()
	clone_state.advance_boss_skill_timer(clone_state.boss_skill_interval())
	controller.process_skill(clone_index, 0.0)
	await process_frame
	if game.character_registry.count() <= count_before_minions:
		_fail("Clone Demon strategy did not spawn minions")
		return
	var minion_index := count_before_minions
	var minion_state := game.character_state_at(minion_index) as CharacterState
	controller.explode_clone_minion(minion_index)
	if minion_state.is_alive():
		_fail("Clone Demon minion strategy did not detonate and defeat the minion")
		return

	print("BOSS_STRATEGY_SMOKE_OK registry blast_bomb frost_freeze clone_spawn clone_explosion")
	quit(0)

func _adjacent_interior_cell(origin: Vector2i) -> Vector2i:
	for raw_direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var direction := raw_direction as Vector2i
		var candidate: Vector2i = origin + direction
		if candidate.x > 0 and candidate.x < Constants.GRID_W - 1 and candidate.y > 0 and candidate.y < Constants.GRID_H - 1:
			return candidate
	return origin

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
