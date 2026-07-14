class_name CloneDemonSkillStrategy
extends BossSkillStrategy

func boss_id() -> String:
	return "clone_demon"

func execute(_player_index: int, state: CharacterState) -> void:
	call_deferred("_spawn_clone_minions", state.cell())

func explode_minion(player_index: int) -> void:
	var state := _game.character_registry.state_at(player_index) as CharacterState
	if state == null:
		return
	var explosion: Dictionary = _game.bomb_manager.get_explosion_cells(state.cell(), 1, true)
	_game.bomb_manager.detonate_cells(explosion["cells"], player_index, state.cell())
	if state.is_alive():
		_game.combat_manager.kill_player(player_index)

func _spawn_clone_minions(origin: Vector2i) -> void:
	var spawned: int = _game.player_manager.spawn_clone_minions(origin, _game.next_player_id)
	_game.next_player_id += spawned
