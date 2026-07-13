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


static func find_closest_reachable_path(
	start: Vector2i,
	target: Vector2i,
	walkable_cells: Dictionary
) -> Array[Vector2i]:
	var empty_path: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	var parents: Dictionary = {start: start}
	var path_lengths: Dictionary = {start: 0}
	var head := 0
	var best := start
	var best_distance := Constants.grid_distance(start, target)
	var best_path_length := 0

	while head < queue.size():
		var current := queue[head]
		head += 1
		var current_distance := Constants.grid_distance(current, target)
		var current_path_length := int(path_lengths[current])
		if current_distance < best_distance or (current_distance == best_distance and current_path_length < best_path_length):
			best = current
			best_distance = current_distance
			best_path_length = current_path_length
		for direction in DIRECTIONS:
			var next := current + direction
			if parents.has(next) or not walkable_cells.has(next):
				continue
			parents[next] = current
			path_lengths[next] = current_path_length + 1
			queue.append(next)

	if best == start:
		return empty_path
	var path: Array[Vector2i] = []
	var cursor := best
	while cursor != start:
		path.append(cursor)
		cursor = parents[cursor] as Vector2i
	path.reverse()
	return path


static func _is_goal(cell: Vector2i, target: Vector2i, stop_adjacent: bool) -> bool:
	if stop_adjacent:
		return cell.distance_squared_to(target) == 1
	return cell == target
