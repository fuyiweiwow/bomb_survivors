extends Node

var _game: Node
var _shadows: Dictionary = {}

func setup(game_manager: Node):
	_game = game_manager

func launch_from_lava(player_index: int) -> bool:
	if player_index < 0 or player_index >= _game.players.size():
		return false
	var player: Dictionary = _game.players[player_index]
	var node = player.get("node")
	if not player["alive"] or bool(player.get("downed", false)) or bool(player.get("airborne", false)) or not is_instance_valid(node):
		return false

	player["airborne"] = true
	player["vertical_velocity"] = Constants.AIR_LAUNCH_VELOCITY
	player["airborne_stomped"] = {}
	player["lava_eruption_time"] = 0.0
	player["lava_time"] = 0.0
	(node as Node3D).position.y = maxf((node as Node3D).position.y, Constants.AIR_LAUNCH_HEIGHT)
	player["status"] = "Airborne %.1fm" % (node as Node3D).position.y
	_create_shadow(player_index, node as Node3D)
	_play_lava_burst(player["grid_pos"])
	return true

func begin_fall(player_index: int, initial_vertical_velocity := -0.35) -> bool:
	if player_index < 0 or player_index >= _game.players.size():
		return false
	var player: Dictionary = _game.players[player_index]
	var node = player.get("node")
	if not player["alive"] or bool(player.get("downed", false)) or not is_instance_valid(node):
		return false
	player["airborne"] = true
	player["vertical_velocity"] = initial_vertical_velocity
	player["airborne_stomped"] = {}
	player["lava_eruption_time"] = 0.0
	player["lava_time"] = 0.0
	player["status"] = "Falling %.1fm" % (node as Node3D).position.y
	_create_shadow(player_index, node as Node3D)
	return true

func force_land(player_index: int):
	if player_index < 0 or player_index >= _game.players.size():
		return
	var player: Dictionary = _game.players[player_index]
	if (player.get("elevated_cell", Vector2i(-1, -1)) as Vector2i) != Vector2i(-1, -1):
		_game.wall_mechanics.leave_elevated_cell(player)
		player["airborne"] = true
	if not bool(player.get("airborne", false)):
		return
	_land_player(player_index)

func _physics_process(delta: float):
	if _game == null or _game.game_over:
		return
	for player_index in range(_game.players.size()):
		var player: Dictionary = _game.players[player_index]
		if not bool(player.get("airborne", false)):
			continue
		var node = player.get("node")
		if not player["alive"] or not is_instance_valid(node):
			_clear_shadow(player_index)
			player["airborne"] = false
			continue

		var previous_height := (node as Node3D).position.y
		player["vertical_velocity"] = float(player.get("vertical_velocity", 0.0)) - Constants.AIR_GRAVITY * delta
		(node as Node3D).position.y += float(player["vertical_velocity"]) * delta
		_update_shadow(player_index, node as Node3D)
		if float(player["vertical_velocity"]) <= 0.0:
			var stomp_result: Dictionary = _game.airborne_collision_resolver.try_stomp(player_index, previous_height, (node as Node3D).position.y)
			if bool(stomp_result["hit"]):
				(node as Node3D).position.y = float(stomp_result["contact_height"]) + 0.04
				player["vertical_velocity"] = Constants.STOMP_BOUNCE_VELOCITY
				_update_shadow(player_index, node as Node3D)
				continue
			var support_cell := Constants.world_to_grid((node as Node3D).position)
			var support_height := _support_height(support_cell)
			if support_height >= 0.0 and (node as Node3D).position.y <= support_height:
				_land_on_support(player_index, support_cell, support_height)
				continue
		if (node as Node3D).position.y <= Constants.FLOOR_Y and float(player["vertical_velocity"]) <= 0.0:
			_land_player(player_index)

func _support_height(cell: Vector2i) -> float:
	if not Constants.is_grid_cell_valid(cell):
		return -1.0
	match _game.grid[cell.y][cell.x]:
		Constants.Cell.CRATE:
			return Constants.CRATE_SUPPORT_HEIGHT
		Constants.Cell.WALL:
			return Constants.WALL_SUPPORT_HEIGHT
	return -1.0

func _land_on_support(player_index: int, cell: Vector2i, height: float):
	var player: Dictionary = _game.players[player_index]
	if _game.wall_mechanics.is_cell_occupied(cell, player):
		return
	var node = player.get("node")
	if not is_instance_valid(node):
		return
	player["grid_pos"] = cell
	(node as Node3D).position = Constants.grid_to_world(cell) + Vector3(0, height, 0)
	if _game.movement_controller:
		_game.movement_controller.cancel_move(player)
	player["airborne"] = false
	player["vertical_velocity"] = 0.0
	player["airborne_stomped"] = {}
	_clear_shadow(player_index)
	_game.wall_mechanics.start_fall_support(player_index, cell)

func _land_player(player_index: int):
	var player: Dictionary = _game.players[player_index]
	var node = player.get("node")
	player["airborne"] = false
	player["vertical_velocity"] = 0.0
	player["airborne_stomped"] = {}
	player["lava_eruption_time"] = 0.0
	_clear_shadow(player_index)
	if not is_instance_valid(node):
		return

	var landing_cell := _find_safe_landing_cell(Constants.world_to_grid((node as Node3D).position), player_index)
	player["grid_pos"] = landing_cell
	(node as Node3D).position = Constants.grid_to_world(landing_cell)
	if _game.movement_controller:
		_game.movement_controller.cancel_move(player)
	if player["alive"] and not bool(player.get("downed", false)):
		player["status"] = "Landed"
		_game.powerup_manager.check_powerup_pickup(player_index)

func _find_safe_landing_cell(origin: Vector2i, player_index: int) -> Vector2i:
	var queue: Array[Vector2i] = [origin]
	var visited := {origin: true}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if _is_safe_landing_cell(cell, player_index):
			return cell
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + direction
			if Constants.is_grid_cell_valid(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return Vector2i(1, 1)

func _is_safe_landing_cell(cell: Vector2i, player_index: int) -> bool:
	return (
		Constants.is_grid_cell_valid(cell)
		and not Constants.is_lava_cell(_game.grid, cell)
		and _game.is_cell_walkable(cell.x, cell.y, player_index)
	)

func _create_shadow(player_index: int, player_node: Node3D):
	_clear_shadow(player_index)
	var shadow := MeshHelpers.cylinder(0.42, 0.025, MeshHelpers.make_mat(Color(0.03, 0.03, 0.04)))
	shadow.name = "AirShadow_%d" % player_index
	shadow.transparency = 0.48
	_game.add_child(shadow)
	_shadows[player_index] = shadow
	_update_shadow(player_index, player_node)

func _update_shadow(player_index: int, player_node: Node3D):
	var shadow = _shadows.get(player_index)
	if not is_instance_valid(shadow):
		return
	(shadow as Node3D).position = Vector3(player_node.position.x, 0.02, player_node.position.z)
	var altitude_scale := clampf(1.0 - player_node.position.y * 0.055, 0.62, 1.0)
	(shadow as Node3D).scale = Vector3(altitude_scale, 1.0, altitude_scale)

func _clear_shadow(player_index: int):
	var shadow = _shadows.get(player_index)
	if is_instance_valid(shadow):
		shadow.queue_free()
	_shadows.erase(player_index)

func _play_lava_burst(cell: Vector2i):
	var origin := Constants.grid_to_world(cell)
	var burst_mat := MeshHelpers.make_mat(Color(1.0, 0.24, 0.025), true)
	var column := MeshHelpers.cylinder(0.34, 0.2, burst_mat)
	column.name = "LavaEruption"
	column.position = origin + Vector3(0, 0.1, 0)
	_game.add_child(column)
	var column_tween := create_tween().bind_node(column).set_parallel()
	column_tween.tween_property(column, "scale", Vector3(1.5, 18.0, 1.5), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	column_tween.tween_property(column, "transparency", 1.0, 0.32).set_delay(0.12)
	column_tween.set_parallel(false)
	column_tween.tween_callback(column.queue_free)

	for spark_index in range(8):
		var spark := MeshHelpers.sphere(0.09, burst_mat)
		var angle := TAU * float(spark_index) / 8.0
		spark.position = origin + Vector3(cos(angle) * 0.2, 0.18, sin(angle) * 0.2)
		_game.add_child(spark)
		var destination := spark.position + Vector3(cos(angle) * 0.9, randf_range(0.8, 1.8), sin(angle) * 0.9)
		var spark_tween := create_tween().bind_node(spark).set_parallel()
		spark_tween.tween_property(spark, "position", destination, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, "transparency", 1.0, 0.34)
		spark_tween.set_parallel(false)
		spark_tween.tween_callback(spark.queue_free)
