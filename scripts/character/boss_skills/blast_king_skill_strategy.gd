class_name BlastKingSkillStrategy
extends BossSkillStrategy

func boss_id() -> String:
	return "blast_king"

func execute(player_index: int, state: CharacterState) -> void:
	if state.bombs.can_place():
		_game.bomb_manager.try_place_bomb(player_index)
	state.mark_ai_bomb_timer_ready()
