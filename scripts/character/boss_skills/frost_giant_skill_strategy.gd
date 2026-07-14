class_name FrostGiantSkillStrategy
extends BossSkillStrategy

func boss_id() -> String:
	return "frost_giant"

func execute(_player_index: int, boss_state: CharacterState) -> void:
	var player_state := _game.character_registry.state_at(0) as CharacterState
	if player_state == null or not player_state.is_alive():
		return
	var delta_vector := player_state.cell() - boss_state.cell()
	if absi(delta_vector.x) <= 1 and absi(delta_vector.y) <= 1 and _is_in_ground_attack_layer(player_state):
		_freeze_player(player_state)
		return
	var charge_direction := Vector2i(signi(delta_vector.x), 0) if absi(delta_vector.x) >= absi(delta_vector.y) else Vector2i(0, signi(delta_vector.y))
	_charge(boss_state, charge_direction)

func _freeze_player(player_state: CharacterState) -> void:
	player_state.effects.freeze(3.0)
	player_state.set_status("Frozen 3.0s")
	var freeze := MeshHelpers.box(Vector3(Constants.TILE_SIZE * 0.9, 0.12, Constants.TILE_SIZE * 0.9), MeshHelpers.make_mat(Color(0.45, 0.88, 1.0), true))
	freeze.position = Constants.grid_to_world(player_state.cell()) + Vector3(0, 0.14, 0)
	_game.add_child(freeze)
	var tween := create_tween()
	tween.tween_property(freeze, "transparency", 1.0, 3.0)
	tween.tween_callback(freeze.queue_free)

func _charge(boss_state: CharacterState, direction: Vector2i) -> void:
	var player_state := _game.character_registry.state_at(0) as CharacterState
	var destination := boss_state.cell()
	for step in range(2):
		var target := destination + direction
		if player_state != null and player_state.is_alive() and _is_in_ground_attack_layer(player_state) and target == player_state.cell():
			_game.combat_manager.damage_player(0, 1, "frost charge")
			break
		if not _game.movement_controller.is_cell_walkable(target):
			break
		destination = target
	if destination == boss_state.cell():
		return
	boss_state.begin_scripted_move(destination)
	var boss_node := boss_state.node()
	if boss_node == null:
		boss_state.complete_scripted_move()
		return
	boss_node.look_at(Constants.grid_to_world(destination), Vector3.UP)
	var tween := create_tween()
	tween.tween_property(boss_node, "position", Constants.grid_to_world(destination), 0.18)
	tween.tween_callback(boss_state.complete_scripted_move)

func _is_in_ground_attack_layer(target: CharacterState) -> bool:
	return target.is_in_attack_height(Constants.GROUND_ATTACK_MIN_HEIGHT, Constants.GROUND_ATTACK_MAX_HEIGHT)
