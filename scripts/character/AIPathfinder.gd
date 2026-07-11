class_name AIPathfinder
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]


static func find_path(
	start: Vector2i,
	target: Vector2i,
	walkable_cells: Dictionary,
	stop_adjacent: bool = false
) -> Array[Vector2i]:
	var empty_path: Array[Vector2i] = []
	if _is_goal(start, target, stop_adjacent):
		return empty_path

	var queue: Array[Vector2i] = [start]
	var parents: Dictionary = {start: start}
	var head: int = 0
	var goal: Vector2i = Vector2i(-1, -1)

	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for direction: Vector2i in DIRECTIONS:
			var next: Vector2i = current + direction
			if parents.has(next) or not walkable_cells.has(next):
				continue
			parents[next] = current
			if _is_goal(next, target, stop_adjacent):
				goal = next
				break
			queue.append(next)
		if goal != Vector2i(-1, -1):
			break

	if goal == Vector2i(-1, -1):
		return empty_path

	var path: Array[Vector2i] = []
	var cursor: Vector2i = goal
	while cursor != start:
		path.append(cursor)
		cursor = parents[cursor] as Vector2i
	path.reverse()
	return path


static func _is_goal(cell: Vector2i, target: Vector2i, stop_adjacent: bool) -> bool:
	if stop_adjacent:
		return cell.distance_squared_to(target) == 1
	return cell == target
