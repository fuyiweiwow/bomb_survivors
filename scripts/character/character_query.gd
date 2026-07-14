class_name CharacterQuery
extends RefCounted

var _data: Dictionary

func _init(character_data: Dictionary) -> void:
	_data = character_data

func id() -> int:
	return int(_data.get("id", -1))

func node() -> Node3D:
	var value: Variant = _data.get("node")
	return value as Node3D if is_instance_valid(value) else null

func cell() -> Vector2i:
	return _data.get("grid_pos", Vector2i(-1, -1)) as Vector2i

func is_alive() -> bool:
	return bool(_data.get("alive", false))

func is_downed() -> bool:
	return bool(_data.get("downed", false))

func is_ai() -> bool:
	return bool(_data.get("ai", false))

func is_airborne() -> bool:
	return bool(_data.get("airborne", false))

func health() -> int:
	return int(_data.get("hp", 0))

func max_health() -> int:
	return int(_data.get("max_hp", Constants.PLAYER_MAX_HP))

func downed_time_left() -> float:
	return float(_data.get("downed_timer", 0.0))

func status() -> String:
	return str(_data.get("status", ""))

func boss_id() -> String:
	return str(_data.get("boss_id", ""))

func boss_name() -> String:
	return str(_data.get("boss_name", ""))

func is_boss() -> bool:
	return not boss_id().is_empty()

func speed() -> int:
	return int(_data.get("speed", 5))

func bomb_placed_count() -> int:
	return int(_data.get("bomb_placed_count", 0))

func bomb_capacity() -> int:
	return int(_data.get("bomb_max", 0))

func bomb_range() -> int:
	return int(_data.get("bomb_range", 1))

func shield_count() -> int:
	return int(_data.get("shield", 0))

func ai_difficulty() -> String:
	return str(_data.get("ai_difficulty", "normal"))

func consumables() -> Array[String]:
	var result: Array[String] = []
	var raw_items: Variant = _data.get("consumables", [])
	if not raw_items is Array:
		return result
	for raw_item in raw_items:
		result.append(str(raw_item))
	return result

func selected_consumable_index() -> int:
	var item_count := consumables().size()
	if item_count == 0:
		return 0
	return clampi(int(_data.get("selected_consumable_index", 0)), 0, item_count - 1)

func has_consumable(item_id: String) -> bool:
	return consumables().has(item_id)
