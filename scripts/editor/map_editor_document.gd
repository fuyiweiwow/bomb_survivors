class_name MapEditorDocument
extends RefCounted

enum LoadResult { MISSING, LOADED, RESET_INCOMPATIBLE }

const DEFAULT_PATH := "user://map_data.json"
const MAP_DATA_CODEC := preload("res://scripts/grid/map_data_codec.gd")
const MAP_STATE_SCRIPT := preload("res://scripts/grid/map_state.gd")

var map_state: MapState
var file_path: String

func _init(
	p_width: int = Constants.GRID_W,
	p_height: int = Constants.GRID_H,
	p_file_path: String = DEFAULT_PATH
) -> void:
	map_state = MAP_STATE_SCRIPT.new(p_width, p_height, Constants.Cell.EMPTY, Constants.Cell.WALL)
	file_path = p_file_path

func cells() -> Array:
	return map_state.cells

func reset_blank() -> void:
	map_state.reset_blank()

func paint(cell: Vector2i, cell_type: int) -> bool:
	if not map_state.is_interior(cell):
		return false
	if map_state.cell_at(cell) == cell_type:
		return false
	return map_state.set_cell(cell, cell_type)

func erase(cell: Vector2i) -> bool:
	return paint(cell, Constants.Cell.EMPTY)

func save() -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(MAP_DATA_CODEC.encode_state(map_state)))
	file.close()
	return true

func load() -> LoadResult:
	if not FileAccess.file_exists(file_path):
		return LoadResult.MISSING
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		reset_and_delete_saved_map()
		return LoadResult.RESET_INCOMPATIBLE
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not MAP_DATA_CODEC.decode_into_state(json.get_data(), map_state):
		reset_and_delete_saved_map()
		return LoadResult.RESET_INCOMPATIBLE
	return LoadResult.LOADED

func reset_and_delete_saved_map() -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	reset_blank()
