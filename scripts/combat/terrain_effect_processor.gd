class_name TerrainEffectProcessor
extends Node

var _game: Node
var _combat: Node

func setup(game_manager: Node, combat_manager: Node) -> void:
	_game = game_manager
	_combat = combat_manager

func process(delta: float) -> void:
	for i in range(_game.character_registry.count()):
		var state := _game.character_state_at(i) as CharacterState
		if state == null or not state.is_alive():
			continue
		state.effects.tick_global(delta)
		if state.is_downed():
			continue
		var expired: Dictionary = state.effects.tick_active(delta)
		if bool(expired["wings_expired"]):
			_game.consumable_effects.end_wings(state)
		var cell := state.cell()
		var cell_type: int = _game.map_state.cell_at(cell)
		var status_parts: Array = []
		if state.has_duel_immunity():
			status_parts.append("Duel ready: touch an enemy")

		if state.is_airborne():
			state.effects.reset_lava_exposure()
			status_parts.append("Airborne %.1fm" % state.world_position().y)
		elif cell_type == Constants.Cell.FOREST:
			status_parts.append("Hidden")
		if not state.is_airborne() and cell_type == Constants.Cell.LAVA:
			if _has_lava_lift_protection(state):
				state.effects.reset_lava_burn()
				state.effects.advance_lava_pressure(delta)
				status_parts.append("Lava pressure %.1fs" % maxf(Constants.LAVA_ERUPTION_TIME - state.lava_eruption_time(), 0.0))
				if state.lava_eruption_time() >= Constants.LAVA_ERUPTION_TIME and _game.airborne_controller:
					if _game.airborne_controller.launch_from_lava(i):
						status_parts.clear()
						status_parts.append("Airborne %.1fm" % state.world_position().y)
			else:
				state.effects.reset_lava_pressure()
				var burn_time := state.effects.advance_lava_burn(delta)
				status_parts.append("Burning %.1fs" % maxf(Constants.LAVA_DAMAGE_TIME - burn_time, 0.0))
				if burn_time >= Constants.LAVA_DAMAGE_TIME:
					state.effects.reset_lava_burn()
					_combat.damage_player(i, 1, "lava")
		elif not state.is_airborne():
			state.effects.reset_lava_exposure()

		if state.has_shield():
			status_parts.append("Shield %d %.1fs" % [state.effects.shield_count(), state.effects.shield_time_left()])
		if state.effects.is_frozen():
			status_parts.append("Frozen %.1fs" % state.effects.frozen_time_left())
		if state.is_invincible():
			status_parts.append("Invincible %.1fs" % state.effects.invincibility_time_left())
		if state.effects.has_wings():
			status_parts.append("Wings %.1fs" % state.effects.wings_time_left())
		if state.effects.has_football():
			status_parts.append("Football %.1fs" % state.effects.football_time_left())
		if state.effects.is_slowed():
			status_parts.append("Glued %.1fs" % state.effects.slow_time_left())
		state.set_status("Ready" if status_parts.is_empty() else " / ".join(status_parts))

func _has_lava_lift_protection(state: CharacterState) -> bool:
	return state.has_shield() or state.effects.has_wings()
