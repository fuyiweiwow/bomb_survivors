extends SceneTree

const MAP_PATH := "user://map_data.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_write_incompatible_map()
	var game_scene := (load("res://scenes/game/main_3d.tscn") as PackedScene).instantiate()
	root.add_child(game_scene)
	await process_frame
	await process_frame
	var game = game_scene.get_node("GameManager3D")
	if FileAccess.file_exists(MAP_PATH) or not _is_blank_grid(game.grid):
		_fail("Game did not delete the incompatible map and start blank")
		return
	game_scene.queue_free()
	await process_frame

	_write_incompatible_map()
	var editor := (load("res://scenes/editor/map_editor.tscn") as PackedScene).instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	if FileAccess.file_exists(MAP_PATH) or not _is_blank_grid(editor.get("grid") as Array):
		_fail("Map Editor did not delete the incompatible map and start blank")
		return
	print("MAP_CONFIG_RESET_SMOKE_OK strict_version blank_game blank_editor")
	quit(0)

func _write_incompatible_map() -> void:
	var file := FileAccess.open(MAP_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 2,
		"width": 19,
		"height": 13,
		"cells": {"7,5": Constants.Cell.CRATE},
	}))
	file.close()

func _is_blank_grid(grid: Array) -> bool:
	if grid.size() != Constants.GRID_H:
		return false
	for y in Constants.GRID_H:
		if (grid[y] as Array).size() != Constants.GRID_W:
			return false
		for x in Constants.GRID_W:
			var expected := Constants.Cell.WALL if x == 0 or x == Constants.GRID_W - 1 or y == 0 or y == Constants.GRID_H - 1 else Constants.Cell.EMPTY
			if int(grid[y][x]) != expected:
				return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
