extends Node

const CELL_WALL := Constants.Cell.WALL
const STATUS_EFFECT_VISUALS := preload("res://scripts/item/status_effect_visuals.gd")

var game: Node
var status_visuals: Node

func setup(game_manager: Node):
	game = game_manager
	status_visuals = STATUS_EFFECT_VISUALS.new()
	add_child(status_visuals)
	status_visuals.setup(game)

func use(player_index: int, item_id: String) -> bool:
	var state := game.character_state_at(player_index) as CharacterState
	if state == null:
		return false
	if game.duel_manager and game.duel_manager.active:
		state.set_status("Backpack locked during duel")
		return false
	match item_id:
		"detonator":
			return _use_detonator(state)
		"glue":
			_place_glue(player_index)
			return true
		"shield_potion":
			game.combat_manager.grant_shield(player_index)
			return true
		"invincible_star":
			state.effects.grant_invincibility(5.0)
			state.set_status("Invincible 5s")
			status_visuals.refresh_player(state.data)
			return true
		"oil_barrel":
			return _place_oil_barrel(player_index)
		"wings":
			state.effects.grant_wings(Constants.WINGS_DURATION)
			state.set_status("Wings %.0fs" % Constants.WINGS_DURATION)
			if state.is_ai() and game.ai_controller:
				game.ai_controller.on_wings_granted(player_index)
			status_visuals.refresh_player(state.data)
			return true
		"football_shoes":
			state.effects.grant_football(8.0)
			state.set_status("Football shoes 8s")
			status_visuals.refresh_player(state.data)
			return true
		"tianlao":
			_cast_tianlao(player_index)
			return true
		"duel":
			return game.duel_manager.arm(player_index)
	return false

func process(delta: float):
	for raw_cell in game.glue_areas.keys():
		var cell := raw_cell as Vector2i
		var data: Dictionary = game.glue_areas[cell]
		data["time"] = float(data["time"]) - delta
		if float(data["time"]) <= 0.0:
			var node = data.get("node")
			if is_instance_valid(node):
				node.queue_free()
			game.glue_areas.erase(cell)
			continue
		for index in range(game.players.size()):
			var state := game.character_state_at(index) as CharacterState
			if index != int(data["owner"]) and state != null and state.is_alive() and state.cell() == cell:
				state.effects.apply_slow(3.0)

func end_wings(state: CharacterState):
	if state.is_airborne():
		return
	var cell := state.cell()
	if game.map_state.is_walkable(cell) and not game.bomb_map.has(cell) and not game.oil_barrels.has(cell):
		return
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var target: Vector2i = cell + direction
		if target.x < 0 or target.x >= Constants.GRID_W or target.y < 0 or target.y >= Constants.GRID_H:
			continue
		if game.map_state.is_walkable(target) and not game.bomb_map.has(target) and not game.oil_barrels.has(target) and not game.wall_mechanics.is_cell_occupied(target):
			state.set_cell(target)
			var player_node := state.node()
			if player_node != null:
				player_node.position = Constants.grid_to_world(target)
			return

func damage_oil_barrel(cell: Vector2i):
	if not game.oil_barrels.has(cell):
		return
	var data: Dictionary = game.oil_barrels[cell]
	data["hp"] = int(data["hp"]) - 1
	if int(data["hp"]) > 0:
		var node = data.get("node")
		if is_instance_valid(node):
			var tween := game.create_tween().bind_node(node)
			tween.tween_property(node, "scale", Vector3(1.12, 0.86, 1.12), 0.07)
			tween.tween_property(node, "scale", Vector3.ONE, 0.09)
		return
	var owner := int(data.get("owner", -1))
	var node = data.get("node")
	game.oil_barrels.erase(cell)
	if is_instance_valid(node):
		node.queue_free()
	var result: Dictionary = game.bomb_manager.get_explosion_cells(cell, 2, true)
	game.bomb_manager.detonate_cells(result["cells"], owner, cell)

func _use_detonator(state: CharacterState) -> bool:
	var direction := state.data["last_move_dir"] as Vector2i
	for distance in range(1, 7):
		var cell: Vector2i = state.cell() + direction * distance
		if not game.map_state.is_in_bounds(cell) or game.map_state.is_wall(cell):
			break
		if game.bomb_map.has(cell):
			game.bomb_manager.explode_bomb(cell)
			return true
	state.set_status("No bomb in sight")
	return false

func _place_glue(player_index: int):
	var state := game.character_state_at(player_index) as CharacterState
	var cell := state.cell()
	if game.glue_areas.has(cell):
		var old_node = (game.glue_areas[cell] as Dictionary).get("node")
		if is_instance_valid(old_node):
			old_node.queue_free()
	var node = MeshHelpers.cylinder(Constants.TILE_SIZE * 0.38, 0.035, game.art.mat_glue)
	node.position = Constants.grid_to_world(cell) + Vector3(0, 0.07, 0)
	game.add_child(node)
	game.glue_areas[cell] = {"node": node, "time": 5.0, "owner": player_index}
	state.set_status("Glue placed")

func _place_oil_barrel(player_index: int) -> bool:
	var state := game.character_state_at(player_index) as CharacterState
	var cell: Vector2i = state.cell() + (state.data["last_move_dir"] as Vector2i)
	if cell.x < 0 or cell.x >= Constants.GRID_W or cell.y < 0 or cell.y >= Constants.GRID_H:
		return false
	if not game.map_state.is_walkable(cell) or game.bomb_map.has(cell) or game.oil_barrels.has(cell) or game.wall_mechanics.is_cell_occupied(cell):
		state.set_status("No room for barrel")
		return false
	var root := Node3D.new()
	root.position = Constants.grid_to_world(cell)
	var body = MeshHelpers.cylinder(Constants.TILE_SIZE * 0.36, 0.92, game.art.mat_oil)
	body.position = Vector3(0, 0.46, 0)
	root.add_child(body)
	var band = MeshHelpers.cylinder(Constants.TILE_SIZE * 0.38, 0.10, game.art.mat_bomb_power)
	band.position = Vector3(0, 0.48, 0)
	root.add_child(band)
	game.add_child(root)
	game.oil_barrels[cell] = {"node": root, "hp": 4, "owner": player_index}
	state.set_status("Oil barrel placed")
	return true

func _cast_tianlao(player_index: int):
	var state := game.character_state_at(player_index) as CharacterState
	var origin := state.cell()
	var cells: Array = [origin]
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		for distance in range(1, 6):
			var cell: Vector2i = origin + direction * distance
			if not game.map_state.is_in_bounds(cell) or game.map_state.is_wall(cell):
				break
			cells.append(cell)
	for raw_cell in cells:
		var marker = MeshHelpers.box(Vector3(Constants.TILE_SIZE * 0.72, 0.06, Constants.TILE_SIZE * 0.72), game.art.mat_bomb_power)
		marker.position = Constants.grid_to_world(raw_cell as Vector2i) + Vector3(0, 0.10, 0)
		game.add_child(marker)
		var marker_tween := game.create_tween().bind_node(marker).set_loops()
		marker_tween.tween_property(marker, "transparency", 0.75, 0.18)
		marker_tween.tween_property(marker, "transparency", 0.05, 0.18)
		game.get_tree().create_timer(1.5).timeout.connect(marker.queue_free)
	game.get_tree().create_timer(1.5).timeout.connect(func():
		game.bomb_manager.detonate_cells(cells, player_index)
	)
	state.set_status("Prison armed")
