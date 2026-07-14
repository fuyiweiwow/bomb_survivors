class_name MapState
extends RefCounted

var width: int
var height: int
var empty_cell: int
var border_cell: int
var cells: Array = []

func _init(
	p_width: int = Constants.GRID_W,
	p_height: int = Constants.GRID_H,
	p_empty_cell: int = Constants.Cell.EMPTY,
	p_border_cell: int = Constants.Cell.WALL
):
	width = p_width
	height = p_height
	empty_cell = p_empty_cell
	border_cell = p_border_cell
	reset_blank()

func reset_blank() -> void:
	cells.clear()
	for y in height:
		var row: Array = []
		row.resize(width)
		row.fill(empty_cell)
		cells.append(row)
	for x in width:
		cells[0][x] = border_cell
		cells[height - 1][x] = border_cell
	for y in height:
		cells[y][0] = border_cell
		cells[y][width - 1] = border_cell

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func is_interior(cell: Vector2i) -> bool:
	return cell.x > 0 and cell.x < width - 1 and cell.y > 0 and cell.y < height - 1

func cell_at(cell: Vector2i, fallback := -1) -> int:
	if not is_in_bounds(cell):
		return border_cell if fallback < 0 else fallback
	return int(cells[cell.y][cell.x])

func set_cell(cell: Vector2i, value: int) -> bool:
	if not is_in_bounds(cell):
		return false
	cells[cell.y][cell.x] = value
	return true

func is_type(cell: Vector2i, cell_type: int) -> bool:
	return is_in_bounds(cell) and cell_at(cell) == cell_type

func is_walkable(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and Constants.is_walkable_cell(cell_at(cell))

func is_wall(cell: Vector2i) -> bool:
	return is_type(cell, Constants.Cell.WALL)

func is_crate(cell: Vector2i) -> bool:
	return is_type(cell, Constants.Cell.CRATE)

func is_forest(cell: Vector2i) -> bool:
	return is_type(cell, Constants.Cell.FOREST)

func is_lava(cell: Vector2i) -> bool:
	return is_type(cell, Constants.Cell.LAVA)

func walkable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell := Vector2i(x, y)
			if is_walkable(cell):
				result.append(cell)
	return result
