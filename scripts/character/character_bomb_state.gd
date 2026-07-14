class_name CharacterBombState
extends RefCounted

const NO_CELL := Vector2i(-1, -1)

var data: Dictionary

func _init(character_data: Dictionary) -> void:
	data = character_data

func capacity() -> int:
	return int(data.get("bomb_max", 0))

func blast_range() -> int:
	return int(data.get("bomb_range", 1))

func placed_count() -> int:
	return int(data.get("bomb_placed_count", 0))

func can_place() -> bool:
	return placed_count() < capacity()

func configure(maximum: int, range_value: int) -> void:
	data["bomb_max"] = clampi(maximum, 0, 8)
	data["bomb_range"] = clampi(range_value, 1, 10)

func increase_capacity(amount := 1) -> void:
	data["bomb_max"] = clampi(capacity() + amount, 1, 8)

func increase_range(amount := 1) -> void:
	data["bomb_range"] = clampi(blast_range() + amount, 1, 10)

func record_placed(cell: Vector2i, placed_at: float, hop_window: float) -> void:
	var previous_cell := last_placed_cell()
	if previous_cell != NO_CELL and Constants.grid_distance(previous_cell, cell) == 1 and placed_at - last_placed_time() <= hop_window:
		data["bomb_hop_until"] = placed_at + hop_window
		data["bomb_hop_cells"] = {previous_cell: true, cell: true}
	data["last_bomb_pos"] = cell
	data["last_bomb_place_time"] = placed_at
	data["bomb_placed_count"] = placed_count() + 1

func record_removed() -> void:
	data["bomb_placed_count"] = maxi(placed_count() - 1, 0)

func last_placed_cell() -> Vector2i:
	return data.get("last_bomb_pos", NO_CELL) as Vector2i

func last_placed_time() -> float:
	return float(data.get("last_bomb_place_time", -99.0))

func hop_cells() -> Dictionary:
	return data.get("bomb_hop_cells", {}) as Dictionary

func is_hop_window_active(current_time: float) -> bool:
	return current_time <= float(data.get("bomb_hop_until", -99.0))

func can_pass_hop_bomb(cell: Vector2i, current_time: float) -> bool:
	return is_hop_window_active(current_time) and hop_cells().has(cell)

func consume_hop_window() -> void:
	data["bomb_hop_until"] = -99.0
	data["bomb_hop_cells"] = {}
