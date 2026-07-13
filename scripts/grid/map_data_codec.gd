extends RefCounted

const FORMAT_VERSION := 2


static func encode(grid: Array, width: int, height: int, empty_cell: int) -> Dictionary:
	var cells := {}
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			if int(grid[y][x]) != empty_cell:
				cells["%d,%d" % [x, y]] = int(grid[y][x])
	return {
		"version": FORMAT_VERSION,
		"width": width,
		"height": height,
		"cells": cells,
	}


static func decode_into_grid(
	raw_data: Variant,
	target_grid: Array,
	target_width: int,
	target_height: int,
	empty_cell: int,
	wall_cell: int
) -> bool:
	if not raw_data is Dictionary:
		return false
	var root := raw_data as Dictionary
	var raw_cells: Variant = root.get("cells", root)
	if not raw_cells is Dictionary:
		return false
	var cells := raw_cells as Dictionary

	var inferred_size := _infer_source_size(cells)
	var source_width := int(root.get("width", inferred_size.x)) if root.has("cells") else inferred_size.x
	var source_height := int(root.get("height", inferred_size.y)) if root.has("cells") else inferred_size.y
	if source_width < 3 or source_height < 3:
		return false

	_reset_grid(target_grid, target_width, target_height, empty_cell, wall_cell)
	var offset_x := floori(float(target_width - source_width) / 2.0)
	var offset_y := floori(float(target_height - source_height) / 2.0)
	for raw_key in cells.keys():
		var coords := str(raw_key).split(",")
		if coords.size() != 2:
			continue
		var source_x := int(coords[0])
		var source_y := int(coords[1])
		# Borders are regenerated for the target size so legacy borders never
		# become internal walls after a map expansion.
		if source_x <= 0 or source_x >= source_width - 1 or source_y <= 0 or source_y >= source_height - 1:
			continue
		var target_x := source_x + offset_x
		var target_y := source_y + offset_y
		if target_x >= 1 and target_x < target_width - 1 and target_y >= 1 and target_y < target_height - 1:
			target_grid[target_y][target_x] = int(cells[raw_key])
	return true


static func _infer_source_size(cells: Dictionary) -> Vector2i:
	var max_x := -1
	var max_y := -1
	for raw_key in cells.keys():
		var coords := str(raw_key).split(",")
		if coords.size() != 2:
			continue
		max_x = maxi(max_x, int(coords[0]))
		max_y = maxi(max_y, int(coords[1]))
	return Vector2i(max_x + 1, max_y + 1)


static func _reset_grid(grid: Array, width: int, height: int, empty_cell: int, wall_cell: int):
	for y in height:
		for x in width:
			grid[y][x] = wall_cell if x == 0 or x == width - 1 or y == 0 or y == height - 1 else empty_cell
