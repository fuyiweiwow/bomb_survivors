class_name AIDecisionPolicy
extends RefCounted

const AI_PATHFINDER := preload("res://scripts/character/ai_pathfinder.gd")

const INVALID_SCORE := -1000000.0
const EASY_POWERUP_SCORE := 27.0
const NORMAL_POWERUP_SCORE := 18.0
const HARD_POWERUP_SCORE := 14.0
const EASY_AGGRESSION_SCORE := 7.0
const NORMAL_AGGRESSION_SCORE := 18.0
const HARD_AGGRESSION_SCORE := 28.0
const NEARBY_POWERUP_BONUS := 9.0
const DISTANCE_POWERUP_COST := 1.2
const DISTANCE_ATTACK_COST := 0.35


static func choose_direction(
	actor: Dictionary,
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
	return path[0] - (actor["grid_pos"] as Vector2i)


static func _best_powerup_plan(
	actor: Dictionary,
	powerups: Dictionary,
	walkable_cells: Dictionary
) -> Dictionary:
	var best_path: Array[Vector2i] = []
	var best_score: float = INVALID_SCORE
	var start: Vector2i = actor["grid_pos"]
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


static func _powerup_score(actor: Dictionary, powerup_type: String, distance: int) -> float:
	var difficulty: String = str(actor.get("ai_difficulty", "normal"))
	var score: float = NORMAL_POWERUP_SCORE
	match difficulty:
		"easy":
			score = EASY_POWERUP_SCORE
		"hard":
			score = HARD_POWERUP_SCORE
	match powerup_type:
		"speed":
			score += float(maxi(10 - int(actor["speed"]), 0)) * 0.8
		"bomb":
			score += float(maxi(5 - int(actor["bomb_max"]), 0)) * 1.4
		"range":
			score += float(maxi(6 - int(actor["bomb_range"]), 0))
		"shield":
			score += 9.0 if int(actor["shield"]) == 0 else 3.0
		"dummy":
			var items: Array = actor.get("consumables", [])
			score += 12.0 if not items.has("dummy") else 4.0
	if distance <= 2:
		score += NEARBY_POWERUP_BONUS
	return score - float(distance) * DISTANCE_POWERUP_COST


static func _attack_plan(
	actor: Dictionary,
	walkable_cells: Dictionary,
	player_cell: Vector2i,
	can_target_player: bool
) -> Dictionary:
	var empty_path: Array[Vector2i] = []
	if not can_target_player:
		return {"path": empty_path, "score": INVALID_SCORE}
	var start: Vector2i = actor["grid_pos"]
	var path: Array[Vector2i] = AI_PATHFINDER.find_path(
		start,
		player_cell,
		walkable_cells,
		true
	)
	if path.is_empty():
		return {"path": empty_path, "score": INVALID_SCORE}
	var aggression: float = EASY_AGGRESSION_SCORE
	match str(actor.get("ai_difficulty", "normal")):
		"normal":
			aggression = NORMAL_AGGRESSION_SCORE
		"hard":
			aggression = HARD_AGGRESSION_SCORE
	return {
		"path": path,
		"score": aggression - float(path.size()) * DISTANCE_ATTACK_COST,
	}
