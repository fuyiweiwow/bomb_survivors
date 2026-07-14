class_name TerrainEffectProcessor
extends Node

var _game: Node
var _combat: Node

func setup(game_manager: Node, combat_manager: Node) -> void:
	_game = game_manager
	_combat = combat_manager

func process(delta: float) -> void:
	for i in range(_game.players.size()):
		var state := _game.character_state_at(i) as CharacterState
		if state == null or not state.is_alive():
			continue
		var player := state.data
		player["duel_return_grace"] = maxf(float(player.get("duel_return_grace", 0.0)) - delta, 0.0)
		if state.has_shield():
			player["shield_timer"] = maxf(float(player.get("shield_timer", Constants.SHIELD_DURATION)) - delta, 0.0)
			if float(player["shield_timer"]) <= 0.0:
				player["shield"] = 0
		else:
			player["shield_timer"] = 0.0
		if state.is_downed():
			continue
		var had_wings := float(player.get("wings_timer", 0.0)) > 0.0
		player["invincible_timer"] = maxf(float(player.get("invincible_timer", 0.0)) - delta, 0.0)
		player["wings_timer"] = maxf(float(player.get("wings_timer", 0.0)) - delta, 0.0)
		player["football_timer"] = maxf(float(player.get("football_timer", 0.0)) - delta, 0.0)
		player["slow_timer"] = maxf(float(player.get("slow_timer", 0.0)) - delta, 0.0)
		if had_wings and float(player["wings_timer"]) <= 0.0:
			_game.consumable_effects.end_wings(player)
		player["frozen_timer"] = maxf(float(player.get("frozen_timer", 0.0)) - delta, 0.0)
		var cell := state.cell()
		var cell_type: int = _game.map_state.cell_at(cell)
		var status_parts: Array = []
		if state.has_duel_immunity():
			status_parts.append("Duel ready: touch an enemy")

		if state.is_airborne():
			player["lava_time"] = 0.0
			player["lava_eruption_time"] = 0.0
			status_parts.append("Airborne %.1fm" % Constants.player_world_height(player))
		elif cell_type == Constants.Cell.FOREST:
			status_parts.append("Hidden")
		if not state.is_airborne() and cell_type == Constants.Cell.LAVA:
			if _has_lava_lift_protection(state):
				player["lava_time"] = 0.0
				player["lava_eruption_time"] = state.lava_eruption_time() + delta
				status_parts.append("Lava pressure %.1fs" % maxf(Constants.LAVA_ERUPTION_TIME - state.lava_eruption_time(), 0.0))
				if state.lava_eruption_time() >= Constants.LAVA_ERUPTION_TIME and _game.airborne_controller:
					if _game.airborne_controller.launch_from_lava(i):
						status_parts.clear()
						status_parts.append("Airborne %.1fm" % Constants.player_world_height(player))
			else:
				player["lava_eruption_time"] = 0.0
				player["lava_time"] = float(player["lava_time"]) + delta
				status_parts.append("Burning %.1fs" % maxf(Constants.LAVA_DAMAGE_TIME - float(player["lava_time"]), 0.0))
				if float(player["lava_time"]) >= Constants.LAVA_DAMAGE_TIME:
					player["lava_time"] = 0.0
					_combat.damage_player(i, 1, "lava")
		elif not state.is_airborne():
			player["lava_time"] = 0.0
			player["lava_eruption_time"] = 0.0

		if state.has_shield():
			status_parts.append("Shield %d %.1fs" % [int(player["shield"]), float(player["shield_timer"])])
		if float(player.get("frozen_timer", 0.0)) > 0.0:
			status_parts.append("Frozen %.1fs" % float(player["frozen_timer"]))
		if state.is_invincible():
			status_parts.append("Invincible %.1fs" % float(player["invincible_timer"]))
		if float(player["wings_timer"]) > 0.0:
			status_parts.append("Wings %.1fs" % float(player["wings_timer"]))
		if float(player["football_timer"]) > 0.0:
			status_parts.append("Football %.1fs" % float(player["football_timer"]))
		if float(player["slow_timer"]) > 0.0:
			status_parts.append("Glued %.1fs" % float(player["slow_timer"]))
		state.set_status("Ready" if status_parts.is_empty() else " / ".join(status_parts))

func _has_lava_lift_protection(state: CharacterState) -> bool:
	return state.has_shield() or float(state.data.get("wings_timer", 0.0)) > 0.0
