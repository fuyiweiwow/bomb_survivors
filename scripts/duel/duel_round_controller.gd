class_name DuelRoundController
extends Node

signal finished(player_won: bool)

const DUEL_HUD := preload("res://scripts/duel/duel_hud.gd")
const GROUND_SPEED := 4.8
const AIR_SPEED := 3.8
const WING_GRAVITY := 0.95
const GLIDE_LIFT := 2.2
const LAVA_CHARGE_TIME := 0.65
const LAVA_LAUNCH_VELOCITY := 6.2
const DIVE_VELOCITY := -8.5
const DIVE_DAMAGE := 1
const HIT_HORIZONTAL_DISTANCE := 0.72
const HIT_VERTICAL_DISTANCE := 0.90
const HIT_COOLDOWN := 0.45
const LAVA_REFRESH_TIME := 4.5

var game: Node
var arena: Node3D
var actors: Array[Dictionary] = []
var camera: Camera3D = null
var hud: CanvasLayer = null
var active := false
var lava_refresh_timer := LAVA_REFRESH_TIME
var _ending := false

func setup(game_manager: Node, duel_arena: Node3D, player_index: int, enemy_index: int) -> void:
	game = game_manager
	arena = duel_arena
	process_mode = Node.PROCESS_MODE_ALWAYS
	actors = [
		_create_actor(player_index, true, arena.player_spawn()),
		_create_actor(enemy_index, false, arena.enemy_spawn()),
	]
	_setup_camera()
	hud = DUEL_HUD.new()
	add_child(hud)
	hud.setup(arena.display_name)
	active = true
	_update_hud()

func _process(delta: float) -> void:
	if not active or _ending:
		return
	process_round(minf(delta, 0.05))

func process_round(delta: float) -> void:
	lava_refresh_timer -= delta
	if lava_refresh_timer <= 0.0:
		arena.refresh_lava()
		lava_refresh_timer = LAVA_REFRESH_TIME
	_update_player_controls(actors[0])
	_update_ai_controls(actors[1], actors[0])
	for actor in actors:
		_advance_actor(actor, delta)
	resolve_dive_collisions()
	_update_hud()

func resolve_dive_collisions() -> void:
	for attacker_index in range(actors.size()):
		var target_index := 1 - attacker_index
		var attacker: Dictionary = actors[attacker_index]
		var target: Dictionary = actors[target_index]
		if not bool(attacker.get("diving", false)) or float(attacker.get("hit_cooldown", 0.0)) > 0.0:
			continue
		var attacker_node := attacker["node"] as Node3D
		var target_node := target["node"] as Node3D
		if absf(attacker_node.position.x - target_node.position.x) > HIT_HORIZONTAL_DISTANCE:
			continue
		if absf(attacker_node.position.y - target_node.position.y) > HIT_VERTICAL_DISTANCE:
			continue
		target["hp"] = maxi(int(target["hp"]) - DIVE_DAMAGE, 0)
		attacker["diving"] = false
		attacker["vertical_velocity"] = 3.2
		attacker["hit_cooldown"] = HIT_COOLDOWN
		target["hit_cooldown"] = HIT_COOLDOWN
		game.audio_manager.play("stomp")
		_spawn_hit_flash(target_node.position)
		if int(target["hp"]) <= 0:
			_ending = true
			finished.emit(bool(attacker["human"]))
			return

func cleanup() -> void:
	active = false
	for actor in actors:
		var node = actor.get("node")
		if is_instance_valid(node):
			var wings = (node as Node3D).get_node_or_null("DuelWings")
			if is_instance_valid(wings):
				wings.queue_free()
	actors.clear()
	if is_instance_valid(hud):
		hud.queue_free()
	if is_instance_valid(camera):
		camera.queue_free()

func _create_actor(player_index: int, human: bool, spawn_position: Vector3) -> Dictionary:
	var player: Dictionary = game.players[player_index]
	var node := player["node"] as Node3D
	node.position = spawn_position
	node.rotation_degrees = Vector3.ZERO
	node.scale = Vector3.ONE
	_add_wings(node, Color(0.34, 0.76, 1.0) if human else Color(1.0, 0.34, 0.24))
	var maximum_hp := clampi(int(player.get("max_hp", Constants.PLAYER_MAX_HP)), 1, 5)
	return {
		"player_index": player_index,
		"node": node,
		"human": human,
		"hp": maximum_hp,
		"max_hp": maximum_hp,
		"airborne": false,
		"vertical_velocity": 0.0,
		"move_axis": 0.0,
		"glide": false,
		"dive_request": false,
		"diving": false,
		"lava_charge": 0.0,
		"hit_cooldown": 0.0,
	}

func _update_player_controls(actor: Dictionary) -> void:
	actor["move_axis"] = float(int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)))
	actor["glide"] = Input.is_key_pressed(KEY_W)
	actor["dive_request"] = Input.is_key_pressed(KEY_S)

func _update_ai_controls(actor: Dictionary, target: Dictionary) -> void:
	var node := actor["node"] as Node3D
	var target_node := target["node"] as Node3D
	if not bool(actor["airborne"]):
		var lava_x: float = arena.nearest_lava_x(node.position.x)
		actor["move_axis"] = signf(lava_x - node.position.x) if absf(lava_x - node.position.x) > 0.10 else 0.0
		actor["glide"] = false
		actor["dive_request"] = false
		return
	actor["move_axis"] = signf(target_node.position.x - node.position.x) if absf(target_node.position.x - node.position.x) > 0.10 else 0.0
	actor["glide"] = node.position.y < target_node.position.y + 1.8 and float(actor["vertical_velocity"]) < 1.0
	actor["dive_request"] = node.position.y > target_node.position.y + 0.75 and absf(target_node.position.x - node.position.x) < 1.15

func _advance_actor(actor: Dictionary, delta: float) -> void:
	var node := actor["node"] as Node3D
	actor["hit_cooldown"] = maxf(float(actor["hit_cooldown"]) - delta, 0.0)
	var speed := AIR_SPEED if bool(actor["airborne"]) else GROUND_SPEED
	node.position.x = clampf(node.position.x + float(actor["move_axis"]) * speed * delta, arena.left_bound(), arena.right_bound())
	node.position.z = arena.origin.z
	if absf(float(actor["move_axis"])) > 0.01:
		node.rotation_degrees.y = -18.0 * signf(float(actor["move_axis"]))

	if not bool(actor["airborne"]):
		node.position.y = arena.floor_y()
		if arena.is_lava_x(node.position.x):
			actor["lava_charge"] = float(actor["lava_charge"]) + delta
			if float(actor["lava_charge"]) >= LAVA_CHARGE_TIME:
				actor["airborne"] = true
				actor["vertical_velocity"] = LAVA_LAUNCH_VELOCITY
				actor["lava_charge"] = 0.0
				_spawn_lava_burst(node.position)
		else:
			actor["lava_charge"] = 0.0
		return

	if bool(actor["dive_request"]) and not bool(actor["diving"]):
		actor["diving"] = true
		actor["vertical_velocity"] = DIVE_VELOCITY
	elif bool(actor["glide"]) and not bool(actor["diving"]):
		actor["vertical_velocity"] = minf(float(actor["vertical_velocity"]) + GLIDE_LIFT * delta, 3.4)
	actor["vertical_velocity"] = float(actor["vertical_velocity"]) - WING_GRAVITY * delta
	node.position.y += float(actor["vertical_velocity"]) * delta
	if node.position.y <= arena.floor_y():
		node.position.y = arena.floor_y()
		actor["airborne"] = false
		actor["diving"] = false
		actor["vertical_velocity"] = 0.0

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Fit the complete 16-tile arena even at the project's 4:3 base aspect ratio.
	camera.size = 12.0
	camera.position = arena.origin + Vector3(0, 5.2, 12.5)
	add_child(camera)
	camera.look_at_from_position(camera.position, arena.origin + Vector3(0, 4.0, 0), Vector3.UP)
	camera.current = true

func _add_wings(node: Node3D, color: Color) -> void:
	var old_wings := node.get_node_or_null("DuelWings")
	if is_instance_valid(old_wings):
		old_wings.queue_free()
	var wings := Node3D.new()
	wings.name = "DuelWings"
	wings.position = Vector3(0, 0.56, 0.18)
	var material := MeshHelpers.make_mat(color, true)
	for side in [-1.0, 1.0]:
		var wing := MeshHelpers.box(Vector3(0.52, 0.11, 0.32), material)
		wing.position = Vector3(side * 0.46, 0, 0)
		wing.rotation_degrees.z = side * 28.0
		wings.add_child(wing)
	node.add_child(wings)

func _spawn_lava_burst(position: Vector3) -> void:
	var burst := MeshHelpers.cylinder(0.28, 0.16, game.art.mat_lava_glow)
	burst.position = position + Vector3(0, 0.08, 0)
	arena.add_child(burst)
	var tween := create_tween().bind_node(self).set_parallel()
	tween.tween_property(burst, "scale", Vector3(1.5, 10.0, 1.5), 0.20)
	tween.tween_property(burst, "transparency", 1.0, 0.34)
	tween.set_parallel(false)
	tween.tween_callback(burst.queue_free)

func _spawn_hit_flash(position: Vector3) -> void:
	var flash := MeshHelpers.sphere(0.28, MeshHelpers.make_mat(Color(1.0, 0.82, 0.18), true))
	flash.position = position + Vector3(0, 0.45, 0)
	arena.add_child(flash)
	var tween := create_tween().bind_node(self).set_parallel()
	tween.tween_property(flash, "scale", Vector3(2.4, 2.4, 2.4), 0.18)
	tween.tween_property(flash, "transparency", 1.0, 0.18)
	tween.set_parallel(false)
	tween.tween_callback(flash.queue_free)

func _update_hud() -> void:
	if not is_instance_valid(hud) or actors.size() < 2:
		return
	hud.update_display(
		int(actors[0]["hp"]), int(actors[0]["max_hp"]),
		int(actors[1]["hp"]), int(actors[1]["max_hp"]),
		lava_refresh_timer
	)
