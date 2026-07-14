extends Node

var _game: Node

func setup(game_manager: Node):
	_game = game_manager

func try_stomp(attacker_index: int, previous_height: float, current_height: float) -> Dictionary:
	var miss := {"hit": false, "target_index": -1, "contact_height": current_height}
	if current_height >= previous_height:
		return miss
	var attacker := _game.character_state_at(attacker_index) as CharacterState
	if attacker == null or not attacker.is_alive() or attacker.node() == null:
		return miss

	var best_target_index := -1
	var best_contact_height := -INF
	for target_index in range(_game.character_states.size()):
		if target_index == attacker_index or attacker.elevation.has_stomped(target_index):
			continue
		var target := _game.character_state_at(target_index) as CharacterState
		if target == null or not target.is_alive() or target.is_downed():
			continue
		if target.is_ai() == attacker.is_ai():
			continue
		var target_node := target.node()
		if target_node == null:
			continue
		var attacker_position := attacker.node().position
		var target_position := target_node.position
		var horizontal_distance := Vector2(attacker_position.x, attacker_position.z).distance_to(Vector2(target_position.x, target_position.z))
		if horizontal_distance > Constants.STOMP_HORIZONTAL_RADIUS:
			continue
		var target_scale := maxf(absf(target_node.scale.y), 1.0)
		var contact_height := target_position.y + Constants.STOMP_CONTACT_HEIGHT * target_scale
		if previous_height < contact_height or current_height > contact_height:
			continue
		if contact_height > best_contact_height:
			best_contact_height = contact_height
			best_target_index = target_index

	if best_target_index < 0:
		return miss
	attacker.elevation.mark_stomped(best_target_index)
	attacker.set_status("Stomp")
	_game.combat_manager.damage_player(best_target_index, 1, "stomp")
	_play_stomp_impact(best_target_index, best_contact_height)
	return {"hit": true, "target_index": best_target_index, "contact_height": best_contact_height}

func _play_stomp_impact(target_index: int, contact_height: float):
	_game.audio_manager.play("stomp")
	var target: Dictionary = _game.players[target_index]
	var target_node = target.get("node")
	if not is_instance_valid(target_node):
		return
	var impact_mat := MeshHelpers.make_mat(Color(1.0, 0.72, 0.08), true)
	var impact := MeshHelpers.cylinder(0.48, 0.045, impact_mat)
	impact.name = "StompImpact_%d" % target_index
	impact.position = Vector3((target_node as Node3D).position.x, contact_height, (target_node as Node3D).position.z)
	_game.add_child(impact)
	var tween := create_tween().bind_node(impact).set_parallel()
	tween.tween_property(impact, "scale", Vector3(1.75, 1.0, 1.75), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(impact, "transparency", 1.0, 0.22)
	tween.set_parallel(false)
	tween.tween_callback(impact.queue_free)

	for spark_index in range(6):
		var spark := MeshHelpers.sphere(0.075, impact_mat)
		var angle := TAU * float(spark_index) / 6.0
		spark.position = impact.position
		_game.add_child(spark)
		var destination := spark.position + Vector3(cos(angle) * 0.72, 0.18, sin(angle) * 0.72)
		var spark_tween := create_tween().bind_node(spark).set_parallel()
		spark_tween.tween_property(spark, "position", destination, 0.24)
		spark_tween.tween_property(spark, "transparency", 1.0, 0.24)
		spark_tween.set_parallel(false)
		spark_tween.tween_callback(spark.queue_free)
