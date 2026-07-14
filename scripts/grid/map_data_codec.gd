extends RefCounted

const FORMAT_VERSION := 3

static func encode_state(map_state: MapState) -> Dictionary:
	return encode(map_state.cells, map_state.width, map_state.height, map_state.empty_cell)

static func decode_into_state(raw_data: Variant, map_state: MapState) -> bool:
	return decode_into_grid(
		raw_data,
		map_state.cells,
		map_state.width,
		map_state.height,
		map_state.empty_cell,
		map_state.border_cell
	)


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
	if not is_compatible(raw_data, target_width, target_height):
		return false
	var root := raw_data as Dictionary
	var cells := root["cells"] as Dictionary
	_reset_grid(target_grid, target_width, target_height, empty_cell, wall_cell)
	for raw_key in cells.keys():
		var coords := str(raw_key).split(",")
		if coords.size() != 2:
			continue
		var target_x := int(coords[0])
		var target_y := int(coords[1])
		if target_x >= 1 and target_x < target_width - 1 and target_y >= 1 and target_y < target_height - 1:
			target_grid[target_y][target_x] = int(cells[raw_key])
	return true


static func is_compatible(raw_data: Variant, target_width: int, target_height: int) -> bool:
	if not raw_data is Dictionary:
		return false
	var root := raw_data as Dictionary
	return (
		int(root.get("version", -1)) == FORMAT_VERSION
		and int(root.get("width", -1)) == target_width
		and int(root.get("height", -1)) == target_height
		and root.get("cells") is Dictionary
	)


static func _reset_grid(grid: Array, width: int, height: int, empty_cell: int, wall_cell: int):
	for y in height:
		for x in width:
			grid[y][x] = wall_cell if x == 0 or x == width - 1 or y == 0 or y == height - 1 else empty_cell
