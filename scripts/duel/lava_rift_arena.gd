class_name LavaRiftArena
extends Node3D

const HALF_WIDTH := 8.0
const SEGMENT_COUNT := 16
const FLOOR_Y := 0.0
const LAVA_ZONE_COUNT := 3

var arena_id := "lava_rift"
var display_name := "Lava Rift"
var origin := Vector3.ZERO
var lava_centers: Array[float] = []
var lava_refresh_count := 0
var _art
var _floor_segments: Array[MeshInstance3D] = []

func setup(art, world_origin: Vector3) -> void:
	_art = art
	origin = world_origin
	position = origin
	_build_arena()
	refresh_lava()

func left_bound() -> float:
	return origin.x - HALF_WIDTH + 0.45

func right_bound() -> float:
	return origin.x + HALF_WIDTH - 0.45

func floor_y() -> float:
	return FLOOR_Y

func player_spawn() -> Vector3:
	return origin + Vector3(-5.8, FLOOR_Y, 0)

func enemy_spawn() -> Vector3:
	return origin + Vector3(5.8, FLOOR_Y, 0)

func is_lava_x(world_x: float) -> bool:
	for center in lava_centers:
		if absf(world_x - center) <= 0.48:
			return true
	return false

func nearest_lava_x(world_x: float) -> float:
	if lava_centers.is_empty():
		return origin.x
	var nearest := lava_centers[0]
	var best_distance := absf(world_x - nearest)
	for center in lava_centers:
		var distance := absf(world_x - center)
		if distance < best_distance:
			nearest = center
			best_distance = distance
	return nearest

func refresh_lava() -> void:
	lava_refresh_count += 1
	var slots: Array[int] = []
	for index in range(1, SEGMENT_COUNT - 1):
		slots.append(index)
	slots.shuffle()
	lava_centers.clear()
	for index in range(mini(LAVA_ZONE_COUNT, slots.size())):
		var slot := slots[index]
		lava_centers.append(origin.x - HALF_WIDTH + float(slot) + 0.5)
	_update_floor_materials()

func _build_arena() -> void:
	var backdrop := MeshHelpers.box(Vector3(HALF_WIDTH * 2.0 + 1.0, 11.0, 0.25), MeshHelpers.make_mat(Color(0.035, 0.045, 0.065)))
	backdrop.position = Vector3(0, 4.5, -1.25)
	add_child(backdrop)
	for index in range(SEGMENT_COUNT):
		var segment := MeshHelpers.box(Vector3(0.96, 0.42, 2.2), _art.mat_floor_a)
		segment.name = "DuelFloor%02d" % index
		segment.position = Vector3(-HALF_WIDTH + float(index) + 0.5, -0.21, 0)
		add_child(segment)
		_floor_segments.append(segment)
	for side in [-1.0, 1.0]:
		var pillar := MeshHelpers.box(Vector3(0.45, 11.0, 2.4), _art.mat_wall)
		pillar.position = Vector3(side * (HALF_WIDTH + 0.22), 5.0, 0)
		add_child(pillar)
	var light := DirectionalLight3D.new()
	light.light_energy = 1.8
	light.rotation_degrees = Vector3(-45, -30, 0)
	add_child(light)

func _update_floor_materials() -> void:
	for index in range(_floor_segments.size()):
		var center_x := origin.x - HALF_WIDTH + float(index) + 0.5
		_floor_segments[index].material_override = _art.mat_lava_glow if is_lava_x(center_x) else _art.mat_floor_a
