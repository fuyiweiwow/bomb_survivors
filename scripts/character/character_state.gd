class_name CharacterState
extends RefCounted

const EFFECT_STATE_SCRIPT := preload("res://scripts/character/character_effect_state.gd")
const ELEVATION_STATE_SCRIPT := preload("res://scripts/character/character_elevation_state.gd")
const BOMB_STATE_SCRIPT := preload("res://scripts/character/character_bomb_state.gd")
const CHARACTER_QUERY_SCRIPT := preload("res://scripts/character/character_query.gd")

var data: Dictionary
var effects: CharacterEffectState
var elevation: CharacterElevationState
var bombs: CharacterBombState
var _query: CharacterQuery

func _init(initial_data := {}):
	data = initial_data
	effects = EFFECT_STATE_SCRIPT.new(data)
	elevation = ELEVATION_STATE_SCRIPT.new(data)
	bombs = BOMB_STATE_SCRIPT.new(data)
	_query = CHARACTER_QUERY_SCRIPT.new(data)

func query() -> CharacterQuery:
	return _query

func id() -> int:
	return int(data.get("id", -1))

func node() -> Node3D:
	var value = data.get("node")
	return value as Node3D if is_instance_valid(value) else null

func visual_node() -> Node3D:
	var value = data.get("visual_node")
	if is_instance_valid(value):
		return value as Node3D
	return node()

func detach_node() -> Node3D:
	var character_node := node()
	data["node"] = null
	data["visual_node"] = null
	return character_node

func cell() -> Vector2i:
	return data.get("grid_pos", Vector2i(-1, -1)) as Vector2i

func set_cell(value: Vector2i) -> void:
	data["grid_pos"] = value

func can_start_grid_move() -> bool:
	return (
		is_alive()
		and not is_downed()
		and not is_moving()
		and not effects.is_frozen()
		and node() != null
	)

func is_moving() -> bool:
	return bool(data.get("is_moving", false))

func is_grid_motion_active() -> bool:
	return bool(data.get("grid_motion_active", false))

func move_speed_world() -> float:
	return float(data.get("move_speed_world", 0.0))

func move_target_world() -> Vector3:
	return data.get("move_target_world", Vector3.ZERO) as Vector3

func set_move_target_world(value: Vector3) -> void:
	data["move_target_world"] = value

func move_target_cell() -> Vector2i:
	return data.get("move_target_cell", cell()) as Vector2i

func move_direction() -> Vector2i:
	return data.get("move_dir", Vector2i.ZERO) as Vector2i

func set_move_direction(direction: Vector2i) -> void:
	data["move_dir"] = direction

func set_last_move_direction(direction: Vector2i) -> void:
	data["last_move_dir"] = direction

func last_move_direction() -> Vector2i:
	return data.get("last_move_dir", Vector2i.DOWN) as Vector2i

func begin_grid_move(from_cell: Vector2i, target_cell: Vector2i, target_world: Vector3, world_speed: float) -> void:
	data["move_from_cell"] = from_cell
	data["move_target_cell"] = target_cell
	data["move_target_world"] = target_world
	data["move_speed_world"] = world_speed
	data["grid_motion_active"] = true
	data["is_moving"] = true
	data["move_tween"] = null

func sync_grid_position(world_position: Vector3, force_target := false) -> void:
	var actual_cell := move_target_cell() if force_target else Constants.world_to_grid(world_position)
	if Constants.is_grid_cell_valid(actual_cell):
		set_cell(actual_cell)

func complete_grid_move() -> Vector2i:
	var arrived_cell := move_target_cell()
	set_cell(arrived_cell)
	data["move_from_cell"] = arrived_cell
	data["move_target_cell"] = arrived_cell
	data["is_moving"] = false
	data["move_speed_world"] = 0.0
	data["grid_motion_active"] = false
	return arrived_cell

func cancel_grid_move(resting_position: Vector3) -> void:
	data["is_moving"] = false
	data["move_from_cell"] = cell()
	data["move_target_cell"] = cell()
	data["move_target_world"] = resting_position
	data["move_speed_world"] = 0.0
	data["grid_motion_active"] = false
	data["move_tween"] = null

func movement_duration_multiplier() -> float:
	return 3.33 if effects.is_slowed() else 1.0

func movement_height() -> float:
	var character_node := node()
	if is_airborne() and character_node != null:
		return character_node.position.y
	return 0.92 if effects.has_wings() else 0.0

func can_process_ai() -> bool:
	return is_ai() and is_alive() and not is_downed() and not effects.is_frozen()

func advance_ai_clocks(delta: float) -> void:
	data["move_timer"] = float(data.get("move_timer", 0.0)) + delta
	data["bomb_timer"] = float(data.get("bomb_timer", 0.0)) + delta

func is_ai_move_ready() -> bool:
	return float(data.get("move_timer", 0.0)) >= float(data.get("move_interval", 0.0))

func reset_ai_move_timer(fraction := 0.0) -> void:
	data["move_timer"] = float(data.get("move_interval", 0.0)) * fraction

func is_ai_bomb_ready() -> bool:
	return (
		float(data.get("bomb_timer", 0.0)) >= float(data.get("bomb_interval", 0.0))
		and bombs.can_place()
	)

func reset_ai_bomb_timer() -> void:
	data["bomb_timer"] = 0.0

func mark_ai_bomb_timer_ready() -> void:
	data["bomb_timer"] = float(data.get("bomb_interval", 0.0))

func advance_boss_skill_timer(delta: float) -> bool:
	data["skill_timer"] = float(data.get("skill_timer", 0.0)) - delta
	return float(data["skill_timer"]) <= 0.0

func reset_boss_skill_timer() -> void:
	data["skill_timer"] = boss_skill_interval()

func boss_skill_interval() -> float:
	return float(data.get("skill_interval", 0.0))

func boss_skill_time_left() -> float:
	return float(data.get("skill_timer", 0.0))

func ai_difficulty() -> String:
	return str(data.get("ai_difficulty", "normal"))

func is_minion() -> bool:
	return bool(data.get("is_minion", false))

func boss_id() -> String:
	return str(data.get("boss_id", ""))

func bomb_range() -> int:
	return bombs.blast_range()

func last_bomb_cell() -> Vector2i:
	return bombs.last_placed_cell()

func set_last_bomb_cell(value: Vector2i) -> void:
	data["last_bomb_pos"] = value

func remember_target(cell_value: Vector2i) -> void:
	data["last_seen_player_pos"] = cell_value

func set_status(value: String) -> void:
	data["status"] = value

func can_begin_airborne() -> bool:
	return is_alive() and not is_downed() and not is_airborne() and node() != null

func begin_airborne(initial_velocity: float, status_label: String) -> void:
	elevation.begin_airborne(initial_velocity)
	effects.reset_lava_exposure()
	set_status("%s %.1fm" % [status_label, node().position.y if node() != null else 0.0])

func finish_airborne(landing_cell: Vector2i, status_label := "Landed") -> void:
	elevation.finish_airborne()
	effects.reset_lava_exposure()
	set_cell(landing_cell)
	if is_alive() and not is_downed() and not status_label.is_empty():
		set_status(status_label)

func mark_not_airborne() -> void:
	elevation.finish_airborne()
	effects.reset_lava_pressure()

func begin_special_move(target_cell: Vector2i, direction: Vector2i, status_label: String) -> void:
	set_cell(target_cell)
	set_last_move_direction(direction)
	elevation.begin_support(target_cell, false)
	bombs.consume_hop_window()
	data["is_moving"] = true
	set_status(status_label)

func complete_special_move() -> void:
	data["move_tween"] = null
	data["is_moving"] = false

func begin_scripted_move(target_cell: Vector2i) -> void:
	set_cell(target_cell)
	data["is_moving"] = true

func complete_scripted_move() -> void:
	data["is_moving"] = false

func move_tween() -> Tween:
	var value = data.get("move_tween")
	return value as Tween if value is Tween and is_instance_valid(value) else null

func set_move_tween(value: Tween) -> void:
	data["move_tween"] = value

func grant_lava_flight_opportunity() -> void:
	if is_ai():
		data["lava_flight_available"] = true
		data["lava_flight_target"] = Vector2i(-1, -1)

func has_lava_flight_opportunity() -> bool:
	return bool(data.get("lava_flight_available", false))

func consume_lava_flight_opportunity() -> void:
	data["lava_flight_available"] = false

func lava_flight_target() -> Vector2i:
	return data.get("lava_flight_target", Vector2i(-1, -1)) as Vector2i

func set_lava_flight_target(value: Vector2i) -> void:
	data["lava_flight_target"] = value

func cancel_lava_flight(consume_opportunity := false) -> void:
	set_lava_flight_target(Vector2i(-1, -1))
	if consume_opportunity:
		consume_lava_flight_opportunity()

func protection_time_left() -> float:
	var shield_time := effects.shield_time_left() if has_shield() else 0.0
	return maxf(shield_time, effects.wings_time_left())

func lava_eruption_time() -> float:
	return effects.lava_pressure_time()

func speed_value() -> int:
	return int(data.get("speed", 5))

func configure_gameplay_stats(speed: int, bomb_capacity: int, blast_range: int) -> void:
	data["speed"] = clampi(speed, 1, Constants.MAX_SPEED)
	bombs.configure(bomb_capacity, blast_range)

func configure_ai(difficulty: String, speed: int, blast_range: int, move_interval: float, bomb_interval: float) -> void:
	data["ai_difficulty"] = difficulty
	data["speed"] = clampi(speed, 1, Constants.MAX_SPEED)
	data["bomb_range"] = clampi(blast_range, 1, Constants.MAX_BOMB_RANGE)
	data["move_interval"] = maxf(move_interval, 0.01)
	data["bomb_interval"] = maxf(bomb_interval, 0.01)

func configure_boss(profile_id: String, display_name: String, health: int, speed: int, bomb_capacity: int, blast_range: int, move_interval: float, bomb_interval: float, skill_interval: float) -> void:
	data["boss_id"] = profile_id
	data["boss_name"] = display_name
	data["hp"] = maxi(health, 1)
	data["max_hp"] = maxi(health, 1)
	data["speed"] = clampi(speed, 1, Constants.MAX_SPEED)
	bombs.configure(bomb_capacity, blast_range)
	data["move_interval"] = maxf(move_interval, 0.01)
	data["bomb_interval"] = maxf(bomb_interval, 0.01)
	data["skill_interval"] = maxf(skill_interval, 0.0)
	reset_boss_skill_timer()

func configure_minion(speed: int, move_interval: float, difficulty: String) -> void:
	data["is_minion"] = true
	data["hp"] = 1
	data["max_hp"] = 1
	data["speed"] = clampi(speed, 1, Constants.MAX_SPEED)
	bombs.configure(0, bombs.blast_range())
	data["move_interval"] = maxf(move_interval, 0.01)
	data["ai_difficulty"] = difficulty
	set_status("Decoy")

func increase_speed(amount := 1) -> bool:
	var previous := speed_value()
	data["speed"] = clampi(previous + amount, 1, Constants.MAX_SPEED)
	return speed_value() > previous

func status() -> String:
	return str(data.get("status", ""))

func arm_duel() -> void:
	data["duel_pending"] = true
	set_status("Duel ready: touch an enemy")

func disarm_duel() -> void:
	data["duel_pending"] = false

func is_alive() -> bool:
	return bool(data.get("alive", false))

func is_downed() -> bool:
	return bool(data.get("downed", false))

func is_ai() -> bool:
	return bool(data.get("ai", false))

func is_airborne() -> bool:
	return elevation.is_airborne()

func is_in_attack_height(min_height: float, max_height: float) -> bool:
	var character_node := node()
	return character_node != null and Constants.is_height_in_attack_range(character_node.position.y, min_height, max_height)

func is_boss_like() -> bool:
	return str(data.get("boss_id", "")) != "" or bool(data.get("is_minion", false))

func is_hidden_in(map_state: MapState) -> bool:
	return is_alive() and not is_airborne() and map_state.is_forest(cell())

func has_shield() -> bool:
	return effects.has_shield()

func is_invincible() -> bool:
	return effects.is_invincible()

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
	effects.consume_shield()

func damage_health(amount: int) -> bool:
	data["hp"] = maxi(int(data.get("hp", 0)) - amount, 0)
	data["status"] = "HP %d" % int(data["hp"])
	return int(data["hp"]) <= 0

func ensure_minimum_health(amount: int) -> void:
	data["hp"] = maxi(int(data.get("hp", 0)), amount)

func world_position() -> Vector3:
	var character_node := node()
	return character_node.global_position if character_node != null else Constants.grid_to_world(cell())
