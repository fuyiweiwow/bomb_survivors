class_name CharacterElevationState
extends RefCounted

const NO_CELL := Vector2i(-1, -1)

var data: Dictionary

func _init(character_data: Dictionary) -> void:
	data = character_data

func is_airborne() -> bool:
	return bool(data.get("airborne", false))

func begin_airborne(initial_velocity: float) -> void:
	data["airborne"] = true
	data["vertical_velocity"] = initial_velocity
	data["airborne_stomped"] = {}

func vertical_velocity() -> float:
	return float(data.get("vertical_velocity", 0.0))

func integrate_velocity(gravity: float, delta: float) -> float:
	data["vertical_velocity"] = vertical_velocity() - gravity * delta
	return vertical_velocity()

func set_vertical_velocity(value: float) -> void:
	data["vertical_velocity"] = value

func finish_airborne() -> void:
	data["airborne"] = false
	data["vertical_velocity"] = 0.0
	data["airborne_stomped"] = {}

func has_stomped(character_index: int) -> bool:
	return (data.get("airborne_stomped", {}) as Dictionary).has(character_index)

func mark_stomped(character_index: int) -> void:
	var stomped := data.get("airborne_stomped", {}) as Dictionary
	stomped[character_index] = true
	data["airborne_stomped"] = stomped

func support_cell() -> Vector2i:
	return data.get("elevated_cell", NO_CELL) as Vector2i

func is_elevated() -> bool:
	return support_cell() != NO_CELL

func is_impact_support() -> bool:
	return bool(data.get("impact_support", false))

func begin_support(cell: Vector2i, impact: bool, cracks: Node3D = null) -> void:
	data["elevated_cell"] = cell
	data["impact_support"] = impact
	data["impact_support_timer"] = 0.0
	data["wall_stay_timer"] = 0.0
	data["wall_warning"] = false
	data["impact_support_cracks"] = cracks

func leave_support() -> void:
	data["elevated_cell"] = NO_CELL
	data["impact_support"] = false
	data["impact_support_timer"] = 0.0
	data["wall_stay_timer"] = 0.0
	data["wall_warning"] = false
	data["impact_support_cracks"] = null

func impact_support_time() -> float:
	return float(data.get("impact_support_timer", 0.0))

func advance_impact_support(delta: float) -> float:
	data["impact_support_timer"] = impact_support_time() + delta
	return impact_support_time()

func wall_stay_time() -> float:
	return float(data.get("wall_stay_timer", 0.0))

func advance_wall_stay(delta: float) -> float:
	data["wall_stay_timer"] = wall_stay_time() + delta
	return wall_stay_time()

func has_wall_warning() -> bool:
	return bool(data.get("wall_warning", false))

func set_wall_warning(value: bool) -> void:
	data["wall_warning"] = value

func crack_visual() -> Node3D:
	var cracks = data.get("impact_support_cracks")
	return cracks as Node3D if is_instance_valid(cracks) else null

func clear_crack_visual() -> Node3D:
	var cracks := crack_visual()
	data["impact_support_cracks"] = null
	return cracks
