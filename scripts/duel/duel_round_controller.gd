class_name DuelRoundController
extends Node

signal finished(player_won: bool)

const DUEL_HUD := preload("res://scripts/duel/duel_hud.gd")
const DUEL_ITEMS := preload("res://scripts/duel/duel_item_controller.gd")
const GROUND_SPEED := 4.8
const AIR_SPEED := 3.8
const WING_GRAVITY := 0.95
const GLIDE_LIFT := 2.2
const LAVA_CHARGE_TIME := 0.65
const LAVA_LAUNCH_VELOCITY := 6.2
const DUEL_MAX_HEALTH := 3
const DIVE_VELOCITY := -8.5
const DIVE_ACCELERATION := 13.0
const MAX_DIVE_VELOCITY := -12.0
const DIVE_DAMAGE := 1
const HIT_HORIZONTAL_DISTANCE := 0.72
const HIT_VERTICAL_DISTANCE := 0.90
const HIT_COOLDOWN := 0.45
const LAVA_REFRESH_TIME := 4.5
const MAX_FLIGHT_HEIGHT := 6.0

var game: Node
var arena: Node3D
var actors: Array[DuelActorState] = []
var camera: Camera3D = null
var hud: CanvasLayer = null
var item_controller: DuelItemController = null
var active := false
var lava_refresh_timer := LAVA_REFRESH_TIME
var ai_aggression := 0.65
var _ending := false

func setup(game_manager: Node, duel_arena: Node3D, player_index: int, enemy_index: int) -> void:
	game = game_manager
	arena = duel_arena
	process_mode = Node.PROCESS_MODE_ALWAYS
	actors = [
		_create_actor(player_index, true, arena.player_spawn()),
		_create_actor(enemy_index, false, arena.enemy_spawn()),
	]
	var enemy_state := game.character_state_at(enemy_index) as CharacterState
	ai_aggression = aggression_for_difficulty(enemy_state.ai_difficulty() if enemy_state != null else "normal")
	item_controller = DUEL_ITEMS.new() as DuelItemController
	add_child(item_controller)
	item_controller.setup(game, arena, actors)
	item_controller.changed.connect(_update_hud)
	item_controller.finished.connect(_on_item_finished)
	item_controller.lava_relocated.connect(_on_lava_relocated)
	_setup_camera()
	hud = DUEL_HUD.new()
	add_child(hud)
	hud.setup(arena.display_name)
	set_process_unhandled_input(true)
	active = true
	_update_hud()

func _process(delta: float) -> void:
	if not active or _ending:
		return
	process_round(minf(delta, 0.05))

func process_round(delta: float) -> void:
	item_controller.tick(delta)
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
		var attacker := actors[attacker_index]
		var target := actors[target_index]
		if not attacker.diving or attacker.hit_cooldown > 0.0:
			continue
		var attacker_node := attacker.character_node
		var target_node := target.character_node
		if absf(attacker_node.position.x - target_node.position.x) > HIT_HORIZONTAL_DISTANCE:
			continue
		if absf(attacker_node.position.y - target_node.position.y) > HIT_VERTICAL_DISTANCE:
			continue
		var target_defeated := item_controller.damage_actor(target, DIVE_DAMAGE)
		attacker.diving = false
		attacker.vertical_velocity = 3.2
		attacker.hit_cooldown = HIT_COOLDOWN
		target.hit_cooldown = HIT_COOLDOWN
		game.audio_manager.play("stomp")
		_spawn_hit_flash(target_node.position)
		if target_defeated:
			_ending = true
			finished.emit(attacker.human)
			return

func cleanup() -> void:
	active = false
	for actor in actors:
		var node := actor.character_node
		if is_instance_valid(node):
			var wings = (node as Node3D).get_node_or_null("DuelWings")
			if is_instance_valid(wings):
				wings.queue_free()
	actors.clear()
	if is_instance_valid(hud):
		hud.queue_free()
	if is_instance_valid(camera):
		camera.queue_free()

func human_player_index() -> int:
	return actors[0].player_index if not actors.is_empty() else 0

func _create_actor(player_index: int, human: bool, spawn_position: Vector3) -> DuelActorState:
	var character := game.character_registry.query_at(player_index) as CharacterQuery
	var node := character.node()
	node.position = spawn_position
	node.rotation_degrees = Vector3.ZERO
	node.scale = Vector3.ONE
	_add_wings(node, Color(0.34, 0.76, 1.0) if human else Color(1.0, 0.34, 0.24))
	return DuelActorState.new(player_index, node, human, DUEL_MAX_HEALTH)

func _update_player_controls(actor: DuelActorState) -> void:
	if actor.prison_timer > 0.0:
		actor.move_axis = 0.0
		actor.glide = false
		actor.dive_requested = false
		return
	actor.move_axis = float(int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)))
	actor.glide = Input.is_key_pressed(KEY_W)
	actor.dive_requested = Input.is_key_pressed(KEY_S)

func _update_ai_controls(actor: DuelActorState, target: DuelActorState) -> void:
	if actor.prison_timer > 0.0:
		actor.move_axis = 0.0
		actor.glide = false
		actor.dive_requested = false
		return
	var node := actor.character_node
	var target_node := target.character_node
	if not actor.airborne:
		if arena.lava_centers.is_empty():
			var away_axis := signf(node.position.x - target_node.position.x)
			if is_zero_approx(away_axis):
				away_axis = -1.0 if node.position.x >= arena.origin.x else 1.0
			actor.move_axis = away_axis * maxf(ai_aggression, 0.72) if target.airborne else 0.0
			actor.glide = false
			actor.dive_requested = false
			return
		var lava_x: float = arena.nearest_lava_x(node.position.x)
		actor.move_axis = signf(lava_x - node.position.x) * ai_aggression if not arena.lava_centers.is_empty() and absf(lava_x - node.position.x) > 0.10 else 0.0
		actor.glide = false
		actor.dive_requested = false
		return
	var horizontal_distance := absf(target_node.position.x - node.position.x)
	var pursuit_range := lerpf(3.5, 12.0, ai_aggression)
	actor.move_axis = signf(target_node.position.x - node.position.x) * ai_aggression if horizontal_distance <= pursuit_range and horizontal_distance > 0.10 else 0.0
	actor.glide = node.position.y < minf(target_node.position.y + 1.8, arena.floor_y() + MAX_FLIGHT_HEIGHT - 0.25) and actor.vertical_velocity < 1.0
	var dive_height := lerpf(1.35, 0.75, ai_aggression)
	var dive_alignment := lerpf(0.62, 1.15, ai_aggression)
	actor.dive_requested = node.position.y > target_node.position.y + dive_height and horizontal_distance < dive_alignment

func _advance_actor(actor: DuelActorState, delta: float) -> void:
	var node := actor.character_node
	actor.tick_hit_cooldown(delta)
	var speed := (AIR_SPEED if actor.airborne else GROUND_SPEED) * actor.movement_multiplier()
	node.position.x = clampf(node.position.x + actor.move_axis * speed * delta, arena.left_bound(), arena.right_bound())
	node.position.z = arena.origin.z
	if absf(actor.move_axis) > 0.01:
		node.rotation_degrees.y = -18.0 * signf(actor.move_axis)

	if not actor.airborne:
		node.position.y = arena.floor_y()
		if arena.is_lava_x(node.position.x):
			actor.lava_charge += delta
			if actor.lava_charge >= LAVA_CHARGE_TIME:
				if arena.consume_lava_at(node.position.x):
					actor.airborne = true
					actor.vertical_velocity = LAVA_LAUNCH_VELOCITY
					actor.lava_charge = 0.0
					_spawn_lava_burst(node.position)
				else:
					actor.lava_charge = 0.0
		else:
			actor.lava_charge = 0.0
		return

	if actor.dive_requested:
		actor.diving = true
		actor.vertical_velocity = minf(actor.vertical_velocity, DIVE_VELOCITY)
		actor.vertical_velocity = maxf(actor.vertical_velocity - DIVE_ACCELERATION * delta, MAX_DIVE_VELOCITY)
	elif actor.glide and not actor.diving:
		actor.vertical_velocity = minf(actor.vertical_velocity + GLIDE_LIFT * delta, 3.4)
	actor.vertical_velocity -= WING_GRAVITY * delta
	node.position.y += actor.vertical_velocity * delta
	var maximum_height: float = float(arena.floor_y()) + MAX_FLIGHT_HEIGHT
	if node.position.y >= maximum_height:
		node.position.y = maximum_height
		actor.vertical_velocity = minf(actor.vertical_velocity, 0.0)
	if node.position.y <= arena.floor_y():
		node.position.y = arena.floor_y()
		actor.airborne = false
		actor.diving = false
		actor.vertical_velocity = 0.0

static func aggression_for_difficulty(difficulty: String) -> float:
	match difficulty:
		"easy":
			return 0.48
		"hard":
			return 1.0
		_:
			return 0.68

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

func _unhandled_input(event: InputEvent) -> void:
	if not active or _ending or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var keycode := key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
	if item_controller.handle_key(keycode):
		get_viewport().set_input_as_handled()

func use_selected_item() -> bool:
	return item_controller.use_selected_item()

func cycle_item() -> String:
	return item_controller.cycle_item()

func select_item(slot_index: int) -> String:
	return item_controller.select_item(slot_index)

func _on_item_finished(player_won: bool) -> void:
	if _ending:
		return
	_ending = true
	finished.emit(player_won)

func _on_lava_relocated() -> void:
	lava_refresh_timer = LAVA_REFRESH_TIME

func _update_hud() -> void:
	if not is_instance_valid(hud) or actors.size() < 2:
		return
	hud.update_display(
		actors[0].health, actors[0].max_health,
		actors[1].health, actors[1].max_health,
		lava_refresh_timer,
		item_controller.actor_effects(actors[0]),
		item_controller.actor_effects(actors[1]),
		item_controller.backpack_text(),
		item_controller.item_status
	)
