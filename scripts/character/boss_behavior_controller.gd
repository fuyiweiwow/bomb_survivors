class_name BossBehaviorController
extends Node

var _game: Node

func setup(game: Node) -> void:
	_game = game

func process_skill(player_index: int, delta: float) -> void:
	var boss: Dictionary = _game.players[player_index]
	boss["skill_timer"] = float(boss["skill_timer"]) - delta
	if float(boss["skill_timer"]) > 0.0:
		return
	match str(boss["boss_id"]):
		"blast_king":
			boss["skill_timer"] = 3.5
			if int(boss["bomb_placed_count"]) < int(boss["bomb_max"]):
				_game.bomb_manager.try_place_bomb(player_index)
			boss["bomb_timer"] = float(boss["bomb_interval"])
		"frost_giant":
			boss["skill_timer"] = 4.5
			_frost_giant_skill(player_index)
		"clone_demon":
			boss["skill_timer"] = 5.0
			call_deferred("_spawn_clone_minions", boss["grid_pos"])

func explode_clone_minion(player_index: int) -> void:
	var minion: Dictionary = _game.players[player_index]
	var data: Dictionary = _game.bomb_manager.get_explosion_cells(minion["grid_pos"], 1, true)
	_game.bomb_manager.detonate_cells(data["cells"], player_index, minion["grid_pos"])
	if minion["alive"]:
		_game.combat_manager.kill_player(player_index)

func _spawn_clone_minions(origin: Vector2i) -> void:
	var spawned: int = _game.player_manager.spawn_clone_minions(origin, _game.next_player_id)
	_game.next_player_id += spawned

func _frost_giant_skill(player_index: int) -> void:
	if _game.players.is_empty() or not _game.players[0]["alive"]:
		return
	var boss: Dictionary = _game.players[player_index]
	var player: Dictionary = _game.players[0]
	var delta_vec: Vector2i = player["grid_pos"] - boss["grid_pos"]
	if absi(delta_vec.x) <= 1 and absi(delta_vec.y) <= 1 and _is_target_in_ground_attack_layer(player):
		var player_state := _game.character_state_at(0) as CharacterState
		if player_state == null:
			return
		player_state.effects.freeze(3.0)
		player_state.set_status("Frozen 3.0s")
		var freeze := MeshHelpers.box(Vector3(Constants.TILE_SIZE * 0.9, 0.12, Constants.TILE_SIZE * 0.9), MeshHelpers.make_mat(Color(0.45, 0.88, 1.0), true))
		freeze.position = Constants.grid_to_world(player["grid_pos"]) + Vector3(0, 0.14, 0)
		_game.add_child(freeze)
		var tween := create_tween()
		tween.tween_property(freeze, "transparency", 1.0, 3.0)
		tween.tween_callback(freeze.queue_free)
		return
	var charge_direction := Vector2i(signi(delta_vec.x), 0) if absi(delta_vec.x) >= absi(delta_vec.y) else Vector2i(0, signi(delta_vec.y))
	_frost_charge(player_index, charge_direction)

func _frost_charge(player_index: int, direction: Vector2i) -> void:
	var boss: Dictionary = _game.players[player_index]
	var destination: Vector2i = boss["grid_pos"]
	for step in range(2):
		var target := destination + direction
		if not _game.players.is_empty() and _game.players[0]["alive"] and _is_target_in_ground_attack_layer(_game.players[0]) and target == _game.players[0]["grid_pos"]:
			_game.combat_manager.damage_player(0, 1, "frost charge")
			break
		if not _game.movement_controller.is_cell_walkable(target):
			break
		destination = target
	if destination == boss["grid_pos"]:
		return
	boss["grid_pos"] = destination
	boss["is_moving"] = true
	var node: Node3D = boss["node"]
	node.look_at(Constants.grid_to_world(destination), Vector3.UP)
	var tween := create_tween()
	tween.tween_property(node, "position", Constants.grid_to_world(destination), 0.18)
	tween.tween_callback(func(): boss["is_moving"] = false)

func _is_target_in_ground_attack_layer(target: Dictionary) -> bool:
	return Constants.is_player_in_attack_height(target, Constants.GROUND_ATTACK_MIN_HEIGHT, Constants.GROUND_ATTACK_MAX_HEIGHT)
