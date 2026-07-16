class_name CombatRules
extends RefCounted

enum DamageRoute {
	IGNORE,
	DUEL_IMMUNE,
	INVINCIBLE,
	EXECUTE_DOWNED,
	ABSORB_SHIELD,
	DAMAGE_HEALTH,
}

func damage_route(state: CharacterState, source: String) -> int:
	if not state.is_alive():
		return DamageRoute.IGNORE
	if state.has_duel_immunity():
		return DamageRoute.DUEL_IMMUNE
	if state.is_invincible():
		return DamageRoute.INVINCIBLE
	if state.is_downed():
		return DamageRoute.EXECUTE_DOWNED if source in ["blast", "fire"] else DamageRoute.IGNORE
	if state.has_shield():
		return DamageRoute.ABSORB_SHIELD
	return DamageRoute.DAMAGE_HEALTH

func is_in_attack_cells(state: CharacterState, cells: Array, min_height: float, max_height: float) -> bool:
	var world_position := state.world_position()
	if not Constants.is_height_in_attack_range(world_position.y, min_height, max_height):
		return false
	for raw_cell in cells:
		if Constants.is_world_position_in_blast_cell(world_position, raw_cell as Vector2i):
			return true
	return false

func characters_overlap(first: CharacterState, second: CharacterState) -> bool:
	var first_node := first.node()
	var second_node := second.node()
	if first_node == null or second_node == null:
		return false
	var first_position := first_node.global_position
	var second_position := second_node.global_position
	return (
		absf(first_position.y - second_position.y) <= 0.8
		and Vector2(first_position.x, first_position.z).distance_to(Vector2(second_position.x, second_position.z)) <= 0.72
	)
