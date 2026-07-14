class_name WingAirdropController
extends Node

var game: Node
var _last_drop_time_by_id: Dictionary = {}

func setup(game_manager: Node) -> void:
	game = game_manager

func try_drop_rock(player_index: int) -> bool:
	var state := game.character_state_at(player_index) as CharacterState
	if state == null or not state.is_alive() or not state.is_airborne() or not state.effects.has_wings() or state.node() == null:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_drop_time_by_id.get(state.id(), -99.0)) < Constants.WING_ROCK_DROP_COOLDOWN:
		state.set_status("Rock drop cooling down")
		return false
	_last_drop_time_by_id[state.id()] = now
	var cell := Constants.world_to_grid(state.node().position)
	state.set_cell(cell)
	var rock := _create_rock(state.node().position)
	game.add_child(rock)
	var drop_height := state.world_position().y
	var impact_position := Constants.grid_to_world(cell) + Vector3(0, 0.30, 0)
	var fall_distance := maxf(rock.position.y - impact_position.y, 0.0)
	var duration := maxf(fall_distance / Constants.WING_ROCK_FALL_SPEED, 0.12)
	var tween := game.create_tween().bind_node(rock).set_parallel()
	tween.tween_property(rock, "position", impact_position, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(rock, "rotation_degrees", Vector3(360, 240, 180), duration).as_relative()
	tween.set_parallel(false)
	tween.tween_callback(func(): _impact_rock(rock, cell, player_index, drop_height))
	state.set_status("Rock dropped")
	return true

func _impact_rock(rock: Node3D, cell: Vector2i, owner_index: int, drop_height: float) -> void:
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
	_play_impact(cell)
	game.audio_manager.play("stomp")
	if is_instance_valid(rock):
		rock.queue_free()

func _create_rock(start_position: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "WingDropRock"
	root.position = start_position - Vector3(0, 0.22, 0)
	var body := MeshHelpers.sphere(Constants.TILE_SIZE * 0.30, game.art.mat_wall)
	body.scale = Vector3(1.0, 0.82, 0.94)
	root.add_child(body)
	for offset in [Vector3(0.18, 0.08, 0.08), Vector3(-0.14, -0.05, 0.16), Vector3(0.02, 0.13, -0.18)]:
		var chip := MeshHelpers.sphere(0.08, game.art.mat_wall)
		chip.position = offset
		root.add_child(chip)
	return root

func _play_impact(cell: Vector2i) -> void:
	var origin := Constants.grid_to_world(cell) + Vector3(0, 0.08, 0)
	var ring := MeshHelpers.cylinder(0.28, 0.045, MeshHelpers.make_mat(Color(0.72, 0.68, 0.58, 0.82), true))
	ring.name = "WingRockImpact"
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
