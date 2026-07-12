class_name Constants
extends RefCounted

enum Cell { EMPTY, WALL, CRATE, FOREST, LAVA }

const GRID_W := 15
const GRID_H := 11
const TILE_SIZE := 1.8
const FLOOR_Y := 0.0
const PLAYER_MAX_HP := 3
const LAVA_DAMAGE_TIME := 1.35
const DOWNED_DURATION := 5.0

const CONSUMABLE_IDS := ["detonator", "glue", "shield_potion", "invincible_star", "dummy", "oil_barrel", "wings", "football_shoes", "tianlao"]

static func grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (GRID_W - 1) / 2.0) * TILE_SIZE, FLOOR_Y, (cell.y - (GRID_H - 1) / 2.0) * TILE_SIZE)

static func grid_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func is_walkable_cell(cell_value: int) -> bool:
	return cell_value == Cell.EMPTY or cell_value == Cell.FOREST or cell_value == Cell.LAVA

static func move_duration_for_speed(speed_value: int) -> float:
	var normalized_speed := clampi(speed_value, 1, 10) - 1
	return clampf(0.31 / (1.0 + 0.14 * float(normalized_speed)), 0.12, 0.31)

static func is_lava_cell(grid_array: Array, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= GRID_W or cell.y < 0 or cell.y >= GRID_H:
		return false
	return grid_array[cell.y][cell.x] == Cell.LAVA

static func is_player_hidden(players: Array, index: int, grid_array: Array) -> bool:
	if index < 0 or index >= players.size():
		return false
	var p: Dictionary = players[index]
	var cell: Vector2i = p["grid_pos"]
	return p["alive"] and grid_array[cell.y][cell.x] == Cell.FOREST
