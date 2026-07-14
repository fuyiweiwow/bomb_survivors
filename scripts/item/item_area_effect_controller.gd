class_name ItemAreaEffectController
extends Node

var game: Node

func setup(game_manager: Node) -> void:
	game = game_manager

func process(delta: float) -> void:
	_process_glue(delta)
	_process_fire(delta)

func place_glue(player_index: int) -> bool:
	var state := game.character_state_at(player_index) as CharacterState
	if state == null:
		return false
	var placed_cells := 0
	for cell in _neighborhood(state.cell(), true):
		_replace_area_node(game.glue_areas, cell)
		var puddle := MeshHelpers.cylinder(Constants.TILE_SIZE * 0.38, 0.035, game.art.mat_glue)
		puddle.name = "Glue_%d_%d" % [cell.x, cell.y]
		puddle.position = Constants.grid_to_world(cell) + Vector3(0, 0.07, 0)
		game.add_child(puddle)
		game.glue_areas[cell] = {
			"node": puddle,
			"time": Constants.GLUE_AREA_DURATION,
			"owner": player_index,
		}
		placed_cells += 1
	state.set_status("Glue spread across %d cells" % placed_cells)
	return placed_cells > 0

func should_ai_avoid_glue(state: CharacterState, cell: Vector2i) -> bool:
	if state == null or state.ai_difficulty() != "hard" or not game.glue_areas.has(cell):
		return false
	return int((game.glue_areas[cell] as Dictionary).get("owner", -1)) != _index_for_state(state)

func place_oil_barrel(player_index: int) -> bool:
	var state := game.character_state_at(player_index) as CharacterState
	if state == null:
		return false
	var cell: Vector2i = state.cell() + state.last_move_direction()
	if not Constants.is_grid_cell_valid(cell):
		return false
	if not game.map_state.is_walkable(cell) or game.bomb_map.has(cell) or game.oil_barrels.has(cell) or game.wall_mechanics.is_cell_occupied(cell):
		state.set_status("No room for barrel")
		return false
	var root := Node3D.new()
	root.name = "OilBarrel_%d_%d" % [cell.x, cell.y]
	root.position = Constants.grid_to_world(cell)
	var body := MeshHelpers.cylinder(Constants.TILE_SIZE * 0.36, 0.92, game.art.mat_oil)
	body.position = Vector3(0, 0.46, 0)
	root.add_child(body)
	var band := MeshHelpers.cylinder(Constants.TILE_SIZE * 0.38, 0.10, game.art.mat_bomb_power)
	band.position = Vector3(0, 0.48, 0)
	root.add_child(band)
	game.add_child(root)
	game.oil_barrels[cell] = {"node": root, "hp": 4, "owner": player_index}
	state.set_status("Oil barrel placed")
	return true

func damage_oil_barrel(cell: Vector2i) -> void:
	if not game.oil_barrels.has(cell):
		return
	var data: Dictionary = game.oil_barrels[cell]
	data["hp"] = int(data["hp"]) - 1
	if int(data["hp"]) > 0:
		var barrel_node = data.get("node")
		if is_instance_valid(barrel_node):
			var tween := game.create_tween().bind_node(barrel_node)
			tween.tween_property(barrel_node, "scale", Vector3(1.12, 0.86, 1.12), 0.07)
			tween.tween_property(barrel_node, "scale", Vector3.ONE, 0.09)
		return
	var owner := int(data.get("owner", -1))
	var barrel_node = data.get("node")
	game.oil_barrels.erase(cell)
	if is_instance_valid(barrel_node):
		barrel_node.queue_free()
	ignite_oil(cell, owner)

func ignite_oil(origin: Vector2i, owner := -1) -> Array[Vector2i]:
	var fire_cells := _neighborhood(origin, false)
	var chained_bombs: Array[Vector2i] = []
	for cell in fire_cells:
		_replace_area_node(game.fire_areas, cell)
		var fire_root := _create_fire_visual(cell)
		game.add_child(fire_root)
		game.fire_areas[cell] = {
			"node": fire_root,
			"time": Constants.OIL_FIRE_DURATION,
			"owner": owner,
		}
		if game.bomb_map.has(cell):
			chained_bombs.append(cell)
	game.bomb_manager.detonate_cells(fire_cells, owner, origin)
	for bomb_cell in chained_bombs:
		game.bomb_manager.explode_bomb(bomb_cell)
	return fire_cells

func _process_glue(delta: float) -> void:
	for raw_cell in game.glue_areas.keys():
		var cell := raw_cell as Vector2i
		var data: Dictionary = game.glue_areas[cell]
		data["time"] = float(data["time"]) - delta
		if float(data["time"]) <= 0.0:
			_remove_area(game.glue_areas, cell)
			continue
		for index in range(game.character_registry.count()):
			var state := game.character_state_at(index) as CharacterState
			if index != int(data["owner"]) and state != null and state.is_alive() and state.cell() == cell:
				state.effects.apply_slow(Constants.GLUE_SLOW_DURATION)

func _process_fire(delta: float) -> void:
	for raw_cell in game.fire_areas.keys():
		var cell := raw_cell as Vector2i
		var data: Dictionary = game.fire_areas[cell]
		data["time"] = float(data["time"]) - delta
		if float(data["time"]) <= 0.0:
			_remove_area(game.fire_areas, cell)
	for raw_cell in game.fire_areas.keys():
		var fire_cell := raw_cell as Vector2i
		if game.bomb_map.has(fire_cell):
			game.bomb_manager.explode_bomb(fire_cell)
	for index in range(game.character_registry.count()):
		var state := game.character_state_at(index) as CharacterState
		if state == null or not state.is_alive():
			continue
		if state.is_airborne() or not game.fire_areas.has(state.cell()):
			state.effects.reset_fire_exposure()
			continue
		var exposure := state.effects.advance_fire_exposure(delta)
		if not state.is_downed():
			state.set_status("Burning %.1fs" % maxf(Constants.OIL_FIRE_DAMAGE_TIME - exposure, 0.0))
		if exposure >= Constants.OIL_FIRE_DAMAGE_TIME:
			state.effects.reset_fire_exposure()
			game.combat_manager.damage_player(index, 1, "fire")

func _neighborhood(origin: Vector2i, walkable_only: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			var cell := origin + Vector2i(x_offset, y_offset)
			if not Constants.is_grid_cell_valid(cell) or game.map_state.is_wall(cell):
				continue
			if walkable_only and not game.map_state.is_walkable(cell):
				continue
			cells.append(cell)
	return cells

func _create_fire_visual(cell: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "OilFire_%d_%d" % [cell.x, cell.y]
	root.position = Constants.grid_to_world(cell) + Vector3(0, 0.08, 0)
	var base := MeshHelpers.cylinder(Constants.TILE_SIZE * 0.40, 0.04, game.art.mat_fire)
	root.add_child(base)
	for offset in [Vector3(-0.18, 0.16, 0.0), Vector3(0.18, 0.20, 0.06), Vector3(0.0, 0.26, -0.14)]:
		var flame := MeshHelpers.sphere(0.16, game.art.mat_fire)
		flame.position = offset
		flame.scale = Vector3(0.7, 1.6, 0.7)
		root.add_child(flame)
	var pulse := game.create_tween().bind_node(root).set_loops()
	pulse.tween_property(root, "scale", Vector3(1.06, 1.18, 1.06), 0.22)
	pulse.tween_property(root, "scale", Vector3.ONE, 0.22)
	return root

func _replace_area_node(collection: Dictionary, cell: Vector2i) -> void:
	if collection.has(cell):
		_remove_area(collection, cell)

func _remove_area(collection: Dictionary, cell: Vector2i) -> void:
	var data: Dictionary = collection.get(cell, {})
	var area_node = data.get("node")
	if is_instance_valid(area_node):
		area_node.queue_free()
	collection.erase(cell)

func _index_for_state(target: CharacterState) -> int:
	for index in range(game.character_registry.count()):
		if game.character_state_at(index) == target:
			return index
	return -1
