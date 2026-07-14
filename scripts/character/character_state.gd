class_name CharacterState
extends RefCounted

var data: Dictionary

func _init(initial_data := {}):
	data = initial_data

func id() -> int:
	return int(data.get("id", -1))

func node() -> Node3D:
	var value = data.get("node")
	return value as Node3D if is_instance_valid(value) else null

func cell() -> Vector2i:
	return data.get("grid_pos", Vector2i(-1, -1)) as Vector2i

func set_cell(value: Vector2i) -> void:
	data["grid_pos"] = value

func is_alive() -> bool:
	return bool(data.get("alive", false))

func is_downed() -> bool:
	return bool(data.get("downed", false))

func is_ai() -> bool:
	return bool(data.get("ai", false))

func is_airborne() -> bool:
	return bool(data.get("airborne", false))

func is_boss_like() -> bool:
	return str(data.get("boss_id", "")) != "" or bool(data.get("is_minion", false))

func is_hidden_in(map_state: MapState) -> bool:
	return is_alive() and not is_airborne() and map_state.is_forest(cell())

func has_shield() -> bool:
	return int(data.get("shield", 0)) > 0

func is_invincible() -> bool:
	return float(data.get("invincible_timer", 0.0)) > 0.0

func has_duel_immunity() -> bool:
	return bool(data.get("duel_pending", false))

func enter_downed(source: String, duration: float) -> void:
	data["downed"] = true
	data["downed_timer"] = duration
	data["status"] = "Downed by %s" % source

func tick_downed(delta: float) -> bool:
	data["downed_timer"] = maxf(float(data.get("downed_timer", 0.0)) - delta, 0.0)
	data["status"] = "Downed %.1fs" % float(data["downed_timer"])
	return float(data["downed_timer"]) <= 0.0

func revive() -> void:
	data["downed"] = false
	data["downed_timer"] = 0.0
	data["hp"] = mini(2, int(data.get("max_hp", Constants.PLAYER_MAX_HP)))
	data["status"] = "Revived"
	data["is_moving"] = false

func defeat() -> bool:
	var was_downed := is_downed()
	data["alive"] = false
	data["downed"] = false
	data["downed_timer"] = 0.0
	data["status"] = "Defeated"
	return was_downed

func consume_shield() -> void:
	data["shield"] = maxi(int(data.get("shield", 0)) - 1, 0)
	if int(data["shield"]) <= 0:
		data["shield_timer"] = 0.0

func damage_health(amount: int) -> bool:
	data["hp"] = maxi(int(data.get("hp", 0)) - amount, 0)
	data["status"] = "HP %d" % int(data["hp"])
	return int(data["hp"]) <= 0

func world_position() -> Vector3:
	var character_node := node()
	return character_node.global_position if character_node != null else Constants.grid_to_world(cell())
