class_name AIDecisionPolicy
extends RefCounted

const AI_PATHFINDER := preload("res://scripts/character/ai_pathfinder.gd")
const AI_DIFFICULTY_PROFILE_SCRIPT := preload("res://scripts/character/ai_difficulty_profile.gd")

const INVALID_SCORE := -1000000.0
const EASY_POWERUP_SCORE := 27.0
const NORMAL_POWERUP_SCORE := 16.0
const HARD_POWERUP_SCORE := 10.0
const NEARBY_POWERUP_BONUS := 9.0
const DISTANCE_POWERUP_COST := 1.2
const DISTANCE_ATTACK_COST := 0.22
const BLOCKED_PATH_PENALTY := 3.0


static func choose_direction(
	actor: CharacterQuery,
	powerups: Dictionary,
	walkable_cells: Dictionary,
	player_cell: Vector2i,
	can_target_player: bool
) -> Vector2i:
	var powerup_plan: Dictionary = _best_powerup_plan(actor, powerups, walkable_cells)
	var attack_plan: Dictionary = _attack_plan(
		actor,
		walkable_cells,
		player_cell,
		can_target_player
	)
	var selected_plan: Dictionary = attack_plan
	if float(powerup_plan["score"]) >= float(attack_plan["score"]):
		selected_plan = powerup_plan
	var path: Array[Vector2i] = selected_plan["path"]
	if path.is_empty():
		return Vector2i.ZERO
	return path[0] - actor.cell()


static func _best_powerup_plan(
	actor: CharacterQuery,
	powerups: Dictionary,
	walkable_cells: Dictionary
) -> Dictionary:
	var best_path: Array[Vector2i] = []
	var best_score: float = INVALID_SCORE
	var start := actor.cell()
	for raw_cell: Variant in powerups.keys():
		var target: Vector2i = raw_cell as Vector2i
		var path: Array[Vector2i] = AI_PATHFINDER.find_path(start, target, walkable_cells)
		if path.is_empty():
			continue
		var data: Dictionary = powerups[target]
		var score: float = _powerup_score(actor, str(data["type"]), path.size())
		if score > best_score:
			best_score = score
			best_path = path
	return {"path": best_path, "score": best_score}


static func _powerup_score(actor: CharacterQuery, powerup_type: String, distance: int) -> float:
	var difficulty := actor.ai_difficulty()
	var score: float = NORMAL_POWERUP_SCORE
	match difficulty:
		"easy":
			score = EASY_POWERUP_SCORE
		"hard":
			score = HARD_POWERUP_SCORE
	match powerup_type:
		"speed":
			score += float(maxi(10 - actor.speed(), 0)) * 0.8
		"bomb":
			score += float(maxi(5 - actor.bomb_capacity(), 0)) * 1.4
		"range":
			score += float(maxi(6 - actor.bomb_range(), 0))
		"health":
			var missing_health := maxi(actor.max_health() - actor.health(), 0)
			score += float(missing_health) * 7.0 if missing_health > 0 else -10.0
		"shield":
			score += 9.0 if actor.shield_count() == 0 else 3.0
		"rock":
			score += 8.0 if actor.direct_use_item() != "rock" else -4.0
		"dummy":
			score += 12.0 if not actor.has_consumable("dummy") else 4.0
	if distance <= 2:
		score += NEARBY_POWERUP_BONUS
	return score - float(distance) * DISTANCE_POWERUP_COST


static func _attack_plan(
	actor: CharacterQuery,
	walkable_cells: Dictionary,
	player_cell: Vector2i,
	can_target_player: bool
) -> Dictionary:
	var empty_path: Array[Vector2i] = []
	if not can_target_player:
		return {"path": empty_path, "score": INVALID_SCORE}
	var start := actor.cell()
	var path: Array[Vector2i] = AI_PATHFINDER.find_path(
		start,
		player_cell,
		walkable_cells,
		true
	)
	var blocked_path := false
	if path.is_empty():
		path = AI_PATHFINDER.find_closest_reachable_path(start, player_cell, walkable_cells)
		blocked_path = true
	if path.is_empty():
		return {"path": empty_path, "score": INVALID_SCORE}
	var aggression := AI_DIFFICULTY_PROFILE_SCRIPT.aggression_score(actor.ai_difficulty())
	return {
		"path": path,
		"score": aggression - float(path.size()) * DISTANCE_ATTACK_COST - (BLOCKED_PATH_PENALTY if blocked_path else 0.0),
	}
