class_name CharacterPresentation
extends Node

var _game: Node
var _state_tweens: Dictionary = {}

func setup(game_manager: Node) -> void:
	_game = game_manager

func show_downed(state: CharacterState) -> void:
	var visual := state.visual_node()
	if visual == null:
		return
	_cancel_state_tween(state)
	var tween := create_tween().bind_node(visual)
	_track_state_tween(state, tween)
	tween.tween_property(visual, "rotation_degrees:x", -78.0, 0.18)

func show_revived(state: CharacterState) -> void:
	var visual := state.visual_node()
	if visual == null:
		return
	_cancel_state_tween(state)
	var tween := create_tween().bind_node(visual)
	_track_state_tween(state, tween)
	tween.set_parallel()
	tween.tween_property(visual, "rotation_degrees:x", 0.0, 0.16)
	tween.tween_property(visual, "scale", Vector3(1.12, 1.12, 1.12), 0.12)
	tween.set_parallel(false)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.16)

func show_defeated(state: CharacterState, completed: Callable) -> void:
	var character_node := state.node()
	var visual := state.visual_node()
	if character_node == null or visual == null:
		completed.call()
		return
	_cancel_state_tween(state)
	var tween := create_tween().bind_node(visual)
	_track_state_tween(state, tween)
	tween.tween_property(visual, "scale", Vector3.ONE * 0.05, 0.35)
	tween.tween_callback(func():
		_state_tweens.erase(state.id())
		var detached_node := state.detach_node()
		if detached_node != null:
			detached_node.queue_free()
		completed.call()
	)

func flash_damage(state: CharacterState) -> void:
	var visual := state.visual_node()
	if visual == null:
		return
	var tween := create_tween().bind_node(visual)
	tween.tween_property(visual, "scale", Vector3.ONE * 1.12, 0.08)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.10)

func flash_shield(state: CharacterState) -> void:
	var character_node := state.node()
	if character_node == null:
		return
	var shield := MeshHelpers.sphere(0.62, _game.art.mat_shield)
	shield.transparency = 0.35
	character_node.add_child(shield)
	var tween := create_tween().bind_node(shield)
	tween.tween_property(shield, "scale", Vector3(1.35, 1.35, 1.35), 0.18)
	tween.tween_property(shield, "transparency", 1.0, 0.18)
	tween.tween_callback(shield.queue_free)

func play_spawn_effect(cell: Vector2i, is_boss: bool) -> void:
	var duration := 1.5 if is_boss else 0.5
	var color := Color(1.0, 0.16, 0.08) if is_boss else Color(0.20, 0.88, 1.0)
	var material := MeshHelpers.make_mat(color, true)
	var effect_root := Node3D.new()
	effect_root.name = "BossSpawnEffect" if is_boss else "AISpawnEffect"
	effect_root.position = Constants.grid_to_world(cell)
	_game.add_child(effect_root)

	var pillar := MeshHelpers.cylinder(0.34 if is_boss else 0.22, 5.5 if is_boss else 3.8, material)
	pillar.position.y = 2.75 if is_boss else 1.9
	pillar.transparency = 0.18
	effect_root.add_child(pillar)
	var ring := MeshHelpers.cylinder(0.55, 0.05, material)
	ring.position.y = 0.08
	effect_root.add_child(ring)

	var tween := create_tween().bind_node(effect_root).set_parallel()
	tween.tween_property(pillar, "transparency", 1.0, duration)
	tween.tween_property(pillar, "scale", Vector3(0.45, 1.0, 0.45), duration)
	tween.tween_property(ring, "scale", Vector3(3.2 if is_boss else 1.8, 1.0, 3.2 if is_boss else 1.8), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "transparency", 1.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(effect_root.queue_free)

func set_character_scale(state: CharacterState, value: Vector3) -> void:
	var character_node := state.node()
	if character_node != null:
		character_node.scale = value

func cancel_state_animation(state: CharacterState) -> void:
	_cancel_state_tween(state)

func _track_state_tween(state: CharacterState, tween: Tween) -> void:
	_state_tweens[state.id()] = tween
	tween.finished.connect(func():
		if _state_tweens.get(state.id()) == tween:
			_state_tweens.erase(state.id())
	)

func _cancel_state_tween(state: CharacterState) -> void:
	var tween = _state_tweens.get(state.id())
	if tween is Tween and is_instance_valid(tween):
		(tween as Tween).kill()
	_state_tweens.erase(state.id())
