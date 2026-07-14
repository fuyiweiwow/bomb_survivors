class_name MapEditorPicker
extends RefCounted

var camera: Camera3D
var width: int
var height: int
var tile_size: float
var floor_y: float

func _init(
	p_camera: Camera3D = null,
	p_width: int = Constants.GRID_W,
	p_height: int = Constants.GRID_H,
	p_tile_size: float = Constants.TILE_SIZE,
	p_floor_y: float = Constants.FLOOR_Y
) -> void:
	configure(p_camera, p_width, p_height, p_tile_size, p_floor_y)

func configure(
	p_camera: Camera3D,
	p_width: int,
	p_height: int,
	p_tile_size: float,
	p_floor_y: float
) -> void:
	camera = p_camera
	width = p_width
	height = p_height
	tile_size = p_tile_size
	floor_y = p_floor_y

func screen_to_grid(screen_position: Vector2) -> Vector2i:
	if camera == null:
		return Vector2i(-1, -1)
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) < 0.001:
		return Vector2i(-1, -1)
	var distance := (floor_y - ray_origin.y) / ray_direction.y
	if distance < 0.0:
		return Vector2i(-1, -1)
	var hit := ray_origin + ray_direction * distance
	var grid_x := floori(hit.x / tile_size + (width - 1) / 2.0 + 0.5)
	var grid_y := floori(hit.z / tile_size + (height - 1) / 2.0 + 0.5)
	return Vector2i(grid_x, grid_y)
