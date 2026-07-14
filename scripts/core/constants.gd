class_name Constants
extends RefCounted

enum Cell { EMPTY, WALL, CRATE, FOREST, LAVA }

const LEGACY_GRID_W := 19
const LEGACY_GRID_H := 13
const LEGACY_TILE_SIZE := 1.8
const GRID_REFINEMENT := 2
const GRID_W := LEGACY_GRID_W * GRID_REFINEMENT
const GRID_H := LEGACY_GRID_H * GRID_REFINEMENT
const TILE_SIZE := LEGACY_TILE_SIZE / float(GRID_REFINEMENT)
const MOVE_SUBSTEPS_PER_TILE := 1
const MOVE_STEP_SIZE := TILE_SIZE / float(MOVE_SUBSTEPS_PER_TILE)
const BLAST_HIT_RADIUS := TILE_SIZE * 0.5
const PLAYER_START_CELL := Vector2i(GRID_REFINEMENT + 1, GRID_REFINEMENT + 1)
const FLOOR_Y := 0.0
const PLAYER_MAX_HP := 3
const LAVA_DAMAGE_TIME := 1.35
const DOWNED_DURATION := 5.0
const SHIELD_DURATION := 5.0
const WINGS_DURATION := 8.0
const GLUE_AREA_DURATION := 5.0
const GLUE_SLOW_DURATION := 3.0
const GLUE_AREA_RADIUS := 1
const OIL_FIRE_DURATION := 5.0
const OIL_FIRE_DAMAGE_TIME := 1.25
const OIL_FIRE_RADIUS := 4
const PRISON_DURATION := 4.0
const PRISON_RADIUS := 4
const LAVA_ERUPTION_TIME := 1.0
const AIR_LAUNCH_HEIGHT := 1.15
const AIR_LAUNCH_VELOCITY := 3.6
const AIR_GRAVITY := 1.65
const WINGS_AIR_GRAVITY := 0.65
const CRATE_SUPPORT_HEIGHT := 0.98
const WALL_SUPPORT_HEIGHT := 1.30
const IMPACT_SUPPORT_BREAK_TIME := 1.0
const STOMP_CONTACT_HEIGHT := 1.05
const STOMP_HORIZONTAL_RADIUS := 0.58
const STOMP_BOUNCE_VELOCITY := 1.65
const GROUND_ATTACK_MIN_HEIGHT := -0.25
const GROUND_ATTACK_MAX_HEIGHT := 0.95
const AERIAL_ATTACK_MIN_HEIGHT := GROUND_ATTACK_MAX_HEIGHT
const AERIAL_ATTACK_MAX_HEIGHT := 8.0
const ATTACK_HEIGHT_EPSILON := 0.0001

const CONSUMABLE_IDS := ["detonator", "glue", "shield_potion", "invincible_star", "dummy", "oil_barrel", "wings", "football_shoes", "prison", "duel"]

static func grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (GRID_W - 1) / 2.0) * TILE_SIZE, FLOOR_Y, (cell.y - (GRID_H - 1) / 2.0) * TILE_SIZE)

static func world_to_grid(world_position: Vector3) -> Vector2i:
	var grid_x := floori(world_position.x / TILE_SIZE + (GRID_W - 1) / 2.0 + 0.5)
	var grid_y := floori(world_position.z / TILE_SIZE + (GRID_H - 1) / 2.0 + 0.5)
	return Vector2i(grid_x, grid_y)

static func is_grid_cell_valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_W and cell.y >= 0 and cell.y < GRID_H

static func is_world_position_in_blast_cell(world_position: Vector3, cell: Vector2i) -> bool:
	var center := grid_to_world(cell)
	var hit_radius := BLAST_HIT_RADIUS - 0.001
	return absf(world_position.x - center.x) < hit_radius and absf(world_position.z - center.z) < hit_radius

static func is_height_in_attack_range(height: float, min_height: float, max_height: float) -> bool:
	return height >= min_height - ATTACK_HEIGHT_EPSILON and height <= max_height + ATTACK_HEIGHT_EPSILON

static func player_world_height(player: Dictionary) -> float:
	var player_node = player.get("node")
	if is_instance_valid(player_node):
		return (player_node as Node3D).position.y
	return FLOOR_Y

static func is_player_in_attack_height(player: Dictionary, min_height: float, max_height: float) -> bool:
	return is_height_in_attack_range(player_world_height(player), min_height, max_height)

static func substep_target(world_position: Vector3, direction: Vector2i, height: float) -> Vector3:
	var target := world_position + Vector3(direction.x * MOVE_STEP_SIZE, 0.0, direction.y * MOVE_STEP_SIZE)
	var grid_origin := grid_to_world(Vector2i.ZERO)
	target.x = roundf((target.x - grid_origin.x) / MOVE_STEP_SIZE) * MOVE_STEP_SIZE + grid_origin.x
	target.y = height
	target.z = roundf((target.z - grid_origin.z) / MOVE_STEP_SIZE) * MOVE_STEP_SIZE + grid_origin.z
	return target

static func is_world_position_at_cell_center(world_position: Vector3, cell: Vector2i) -> bool:
	var center := grid_to_world(cell)
	return absf(world_position.x - center.x) < 0.01 and absf(world_position.z - center.z) < 0.01

static func grid_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func is_walkable_cell(cell_value: int) -> bool:
	return cell_value == Cell.EMPTY or cell_value == Cell.FOREST or cell_value == Cell.LAVA

static func move_duration_for_speed(speed_value: int) -> float:
	var normalized_speed := float(clampi(speed_value, 1, 10) - 1) / 9.0
	var world_speed := 4.5 + 5.0 * pow(normalized_speed, 0.82)
	return TILE_SIZE / world_speed

static func is_lava_cell(grid_array: Array, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= GRID_W or cell.y < 0 or cell.y >= GRID_H:
		return false
	return grid_array[cell.y][cell.x] == Cell.LAVA

static func is_player_hidden(players: Array, index: int, grid_array: Array) -> bool:
	if index < 0 or index >= players.size():
		return false
	var p: Dictionary = players[index]
	var cell: Vector2i = p["grid_pos"]
	if not p["alive"] or not is_grid_cell_valid(cell) or bool(p.get("airborne", false)):
		return false
	return grid_array[cell.y][cell.x] == Cell.FOREST
