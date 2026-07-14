class_name PowerupDropTable
extends RefCounted

const ENTRIES := [
	{"id": "speed", "weight": 16.0},
	{"id": "bomb", "weight": 14.0},
	{"id": "range", "weight": 14.0},
	{"id": "shield", "weight": 10.0},
	{"id": "detonator", "weight": 4.0},
	{"id": "glue", "weight": 5.0},
	{"id": "shield_potion", "weight": 4.0},
	{"id": "invincible_star", "weight": 3.0},
	{"id": "dummy", "weight": 2.0},
	{"id": "oil_barrel", "weight": 5.0},
	{"id": "wings", "weight": 4.0},
	{"id": "football_shoes", "weight": 5.0},
	{"id": "prison", "weight": 4.0},
	{"id": "duel", "weight": 2.0},
	{"id": "", "weight": 8.0},
]

func pick(normalized_roll: float) -> String:
	var total_weight := 0.0
	for entry in ENTRIES:
		total_weight += float(entry["weight"])
	var cursor := clampf(normalized_roll, 0.0, 0.999999) * total_weight
	for entry in ENTRIES:
		cursor -= float(entry["weight"])
		if cursor < 0.0:
			return str(entry["id"])
	return ""

func droppable_ids() -> Array[String]:
	var result: Array[String] = []
	for entry in ENTRIES:
		var item_id := str(entry["id"])
		if not item_id.is_empty():
			result.append(item_id)
	return result
