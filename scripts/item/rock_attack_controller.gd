class_name RockAttackController
extends Node

var game: Node
var _last_attack_time_by_id: Dictionary = {}

func setup(game_manager: Node) -> void:
	game = game_manager

func try_shoot_rock(player_index: int) -> bool:
	var state := game.character_state_at(player_index) as CharacterState
	if state == null or not state.is_alive() or state.is_airborne() or not state.effects.has_rock() or state.node() == null:
		return false
	if not _consume_attack_cooldown(state):
		return false
	var direction := state.last_move_direction()
	if direction == Vector2i.ZERO:
		direction = Vector2i.DOWN
	var origin := state.cell()
	var destination := origin
	for step in range(Constants.ROCK_SHOT_DISTANCE):
		var target := destination + direction
		if not Constants.is_grid_cell_valid(target) or game.map_state.is_wall(target):
			break
		destination = target
		if _has_opposing_character(target, player_index) or game.map_state.is_crate(target) or game.oil_barrels.has(target) or game.bomb_map.has(target):
			break
	var start_position := state.world_position() + Vector3(0, 0.42, 0)
	var rock := _create_rock(start_position, "GroundRockShot", 0.22)
	rock.set_meta("impact_cell", destination)
	game.add_child(rock)
	var impact_position := Constants.grid_to_world(destination) + Vector3(0, 0.32, 0)
	var distance := start_position.distance_to(impact_position)
	var duration := maxf(distance / Constants.ROCK_SHOT_SPEED, 0.10)
	var tween := game.create_tween().bind_node(rock).set_parallel()
	tween.tween_property(rock, "position", impact_position, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(rock, "rotation_degrees", Vector3(360, 540, 240), duration).as_relative()
	tween.set_parallel(false)
	tween.tween_callback(func(): _impact_ground_rock(rock, destination, player_index))
	state.set_status("Rock fired")
	game.audio_manager.play("bomb_place")
	return true

func try_drop_rock(player_index: int) -> bool:
	var state := game.character_state_at(player_index) as CharacterState
	if state == null or not state.is_alive() or not state.is_airborne() or not state.effects.has_wings() or not state.effects.has_rock() or state.node() == null:
		return false
	if not _consume_attack_cooldown(state):
		return false
	var cell := Constants.world_to_grid(state.node().position)
	state.set_cell(cell)
	var rock := _create_rock(state.node().position - Vector3(0, 0.22, 0), "WingDropRock", Constants.TILE_SIZE * 0.30)
	game.add_child(rock)
	var drop_height := state.world_position().y
	var impact_position := Constants.grid_to_world(cell) + Vector3(0, 0.30, 0)
	var fall_distance := maxf(rock.position.y - impact_position.y, 0.0)
	var duration := maxf(fall_distance / Constants.AERIAL_ROCK_FALL_SPEED, 0.12)
	var tween := game.create_tween().bind_node(rock).set_parallel()
	tween.tween_property(rock, "position", impact_position, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(rock, "rotation_degrees", Vector3(360, 240, 180), duration).as_relative()
	tween.set_parallel(false)
	tween.tween_callback(func(): _impact_aerial_rock(rock, cell, player_index, drop_height))
	state.set_status("Rock dropped")
	return true

func _impact_ground_rock(rock: Node3D, cell: Vector2i, owner_index: int) -> void:
	var owner := game.character_state_at(owner_index) as CharacterState
	for target_index in range(game.character_registry.count()):
		if target_index == owner_index:
			continue
		var target := game.character_state_at(target_index) as CharacterState
		if target == null or not target.is_alive() or target.node() == null:
			continue
		if owner != null and target.is_ai() == owner.is_ai():
			continue
		if Constants.world_to_grid(target.node().position) == cell and target.is_in_attack_height(Constants.GROUND_ATTACK_MIN_HEIGHT, Constants.GROUND_ATTACK_MAX_HEIGHT):
			game.combat_manager.damage_player(target_index, 1, "rock")
	if game.map_state.is_crate(cell):
		game.grid_manager.destroy_crate(cell)
		game.powerup_manager.spawn_powerup(cell)
	if game.oil_barrels.has(cell):
		game.consumable_effects.damage_oil_barrel(cell)
	if game.bomb_map.has(cell):
		game.bomb_manager.explode_bomb(cell)
	_play_impact(cell, "RockShotImpact")
	game.audio_manager.play("stomp")
	if is_instance_valid(rock):
		rock.queue_free()

func _impact_aerial_rock(rock: Node3D, cell: Vector2i, owner_index: int, drop_height: float) -> void:
	var owner := game.character_state_at(owner_index) as CharacterState
	for target_index in range(game.character_registry.count()):
		if target_index == owner_index:
			continue
		var target := game.character_state_at(target_index) as CharacterState
		if target == null or not target.is_alive() or target.node() == null:
			continue
		if owner != null and target.is_ai() == owner.is_ai():
			continue
		if Constants.world_to_grid(target.node().position) == cell and target.world_position().y < drop_height:
			game.combat_manager.kill_player(target_index)
	if game.map_state.is_crate(cell):
		game.grid_manager.destroy_crate(cell)
		game.powerup_manager.spawn_powerup(cell)
	if game.oil_barrels.has(cell):
		game.consumable_effects.damage_oil_barrel(cell)
	if game.bomb_map.has(cell):
		game.bomb_manager.explode_bomb(cell)
	_play_impact(cell, "WingRockImpact")
	game.audio_manager.play("stomp")
	if is_instance_valid(rock):
		rock.queue_free()

func _consume_attack_cooldown(state: CharacterState) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_attack_time_by_id.get(state.id(), -99.0)) < Constants.ROCK_ATTACK_COOLDOWN:
		state.set_status("Rock attack cooling down")
		return false
	_last_attack_time_by_id[state.id()] = now
	return true

func _has_opposing_character(cell: Vector2i, owner_index: int) -> bool:
	var owner := game.character_state_at(owner_index) as CharacterState
	for target_index in range(game.character_registry.count()):
		if target_index == owner_index:
			continue
		var target := game.character_state_at(target_index) as CharacterState
		if target != null and target.is_alive() and target.cell() == cell and (owner == null or target.is_ai() != owner.is_ai()):
			return true
	return false

func _create_rock(start_position: Vector3, node_name: String, radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = start_position
	var body := MeshHelpers.sphere(radius, game.art.mat_wall)
	body.scale = Vector3(1.0, 0.82, 0.94)
	root.add_child(body)
	var chip_radius := radius * 0.27
	for offset in [Vector3(radius * 0.60, radius * 0.25, radius * 0.25), Vector3(-radius * 0.48, -radius * 0.16, radius * 0.52), Vector3(radius * 0.08, radius * 0.42, -radius * 0.58)]:
		var chip := MeshHelpers.sphere(chip_radius, game.art.mat_wall)
		chip.position = offset
		root.add_child(chip)
	return root

func _play_impact(cell: Vector2i, effect_name: String) -> void:
	var origin := Constants.grid_to_world(cell) + Vector3(0, 0.08, 0)
	var ring := MeshHelpers.cylinder(0.28, 0.045, MeshHelpers.make_mat(Color(0.72, 0.68, 0.58, 0.82), true))
	ring.name = effect_name
	ring.position = origin
	game.add_child(ring)
	var ring_tween := game.create_tween().bind_node(ring).set_parallel()
	ring_tween.tween_property(ring, "scale", Vector3(2.8, 1.0, 2.8), 0.24)
	ring_tween.tween_property(ring, "transparency", 1.0, 0.24)
	ring_tween.set_parallel(false)
	ring_tween.tween_callback(ring.queue_free)
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		var fragment := MeshHelpers.sphere(0.07, game.art.mat_wall)
		fragment.position = origin
		game.add_child(fragment)
		var destination := origin + Vector3(cos(angle) * 0.62, 0.28, sin(angle) * 0.62)
		var fragment_tween := game.create_tween().bind_node(fragment).set_parallel()
		fragment_tween.tween_property(fragment, "position", destination, 0.22)
		fragment_tween.tween_property(fragment, "transparency", 1.0, 0.22)
		fragment_tween.set_parallel(false)
		fragment_tween.tween_callback(fragment.queue_free)
