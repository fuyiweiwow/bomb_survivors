extends Node

const COMBAT_RULES_SCRIPT := preload("res://scripts/combat/combat_rules.gd")
const TERRAIN_EFFECT_PROCESSOR_SCRIPT := preload("res://scripts/combat/terrain_effect_processor.gd")

var _game: Node
var rules: CombatRules = COMBAT_RULES_SCRIPT.new()
var terrain_effects: TerrainEffectProcessor

func setup(game_manager: Node):
	_game = game_manager
	terrain_effects = TERRAIN_EFFECT_PROCESSOR_SCRIPT.new()
	add_child(terrain_effects)
	terrain_effects.setup(_game, self)

func kill_player(player_index: int) -> void:
	_kill_player(player_index)

func revive_player(player_index: int) -> void:
	_revive_player(player_index)

func consume_dummy_if_available(player: Dictionary) -> bool:
	return _consume_dummy_if_available(player)

func cancel_player_movement(player: Dictionary) -> void:
	_cancel_player_movement(player)

func force_down_player(player_index: int, source: String) -> void:
	var state := _game.character_state_at(player_index) as CharacterState
	if state != null and state.is_alive() and not state.is_downed():
		_enter_downed(player_index, source)

func process_downed(delta: float):
	for i in range(_game.players.size()):
		var state := _game.character_state_at(i) as CharacterState
		if state == null or not state.is_alive() or not state.is_downed():
			continue
		var p := state.data
		var expired := state.tick_downed(delta)
		if _consume_dummy_if_available(p):
			_revive_player(i)
		elif expired:
			_kill_player(i)

func process_character_overlaps():
	for downed_index in range(_game.players.size()):
		var downed_state := _game.character_state_at(downed_index) as CharacterState
		if downed_state == null or not downed_state.is_alive() or not downed_state.is_downed():
			continue
		var downed_player := downed_state.data
		if float(downed_player.get("duel_return_grace", 0.0)) > 0.0:
			continue
		for other_index in range(_game.players.size()):
			if other_index == downed_index:
				continue
			var other_state := _game.character_state_at(other_index) as CharacterState
			if other_state == null or not other_state.is_alive() or other_state.is_downed():
				continue
			if other_state.is_ai() == downed_state.is_ai():
				continue
			if other_state.cell() == downed_state.cell() and rules.characters_overlap(downed_state, other_state):
				_kill_player(downed_index)
				break

func process_terrain_effects(delta: float):
	terrain_effects.process(delta)

func apply_explosion_damage(
	cells: Array,
	explosion_owner := -1,
	exploding_cell := Vector2i(-1, -1),
	hit_players: Variant = null,
	affect_obstacles := true,
	min_height := Constants.GROUND_ATTACK_MIN_HEIGHT,
	max_height := Constants.GROUND_ATTACK_MAX_HEIGHT
):
	var hit_registry: Dictionary = hit_players as Dictionary if hit_players is Dictionary else {}
	if affect_obstacles:
		for raw_cell in cells:
			var cell := raw_cell as Vector2i
			if _game.map_state.is_crate(cell):
				_game.grid_manager.destroy_crate(cell)
				_game.powerup_manager.spawn_powerup(cell)
			if _game.oil_barrels.has(cell):
				_game.consumable_effects.damage_oil_barrel(cell)

	for i in range(_game.players.size()):
		var state := _game.character_state_at(i) as CharacterState
		if hit_registry.has(i) or state == null or not state.is_alive() or not rules.is_in_attack_cells(state, cells, min_height, max_height):
			continue
		hit_registry[i] = true
		if i == explosion_owner and _game.wall_mechanics.try_bomb_boost(i):
			continue
		_damage_player(i, 1, "blast")

func is_player_in_attack_cells(player: Dictionary, cells: Array, min_height: float, max_height: float) -> bool:
	var state := _game.character_state_by_id(int(player.get("id", -1))) as CharacterState
	if state == null:
		state = CharacterState.new(player)
	return rules.is_in_attack_cells(state, cells, min_height, max_height)

func damage_player(index: int, amount: int, source: String):
	var state := _game.character_state_at(index) as CharacterState
	if state == null:
		return
	var p := state.data
	match rules.damage_route(state, source):
		CombatRules.DamageRoute.DUEL_IMMUNE:
			p["status"] = "Duel immunity"
		CombatRules.DamageRoute.INVINCIBLE:
			p["status"] = "Invincible"
		CombatRules.DamageRoute.EXECUTE_DOWNED:
			_kill_player(index)
		CombatRules.DamageRoute.ABSORB_SHIELD:
			state.consume_shield()
			_flash_player_shield(p)
			_game.audio_manager.play("shield")
		CombatRules.DamageRoute.DAMAGE_HEALTH:
			var defeated := state.damage_health(amount)
			_flash_player_damage(p)
			_game.audio_manager.play("hit")
			if defeated:
				_kill_player(index)
		CombatRules.DamageRoute.ENTER_DOWNED:
			p["hp"] = maxi(int(p["hp"]), 1)
			_enter_downed(index, source)

func _enter_downed(index: int, source: String):
	var state := _game.character_state_at(index) as CharacterState
	if state == null or not state.is_alive():
		return
	var p := state.data
	state.enter_downed(source, Constants.DOWNED_DURATION)
	_game.audio_manager.play("down")
	if _game.airborne_controller:
		_game.airborne_controller.force_land(index)
	_cancel_player_movement(p)
	_cancel_player_state_animation(p)
	if index == 0:
		_game.bomb_pressed = false
	var node: Node3D = p["node"]
	if is_instance_valid(node):
		var visual := _player_visual(p)
		var tw := create_tween().bind_node(visual)
		p["state_tween"] = tw
		tw.tween_property(visual, "rotation_degrees:x", -78.0, 0.18)

func _revive_player(index: int):
	var state := _game.character_state_at(index) as CharacterState
	if state == null:
		return
	var p := state.data
	state.revive()
	_cancel_player_state_animation(p)
	var node: Node3D = p["node"]
	if is_instance_valid(node):
		var visual := _player_visual(p)
		var tw := create_tween().bind_node(visual)
		p["state_tween"] = tw
		tw.set_parallel()
		tw.tween_property(visual, "rotation_degrees:x", 0.0, 0.16)
		tw.tween_property(visual, "scale", Vector3(1.12, 1.12, 1.12), 0.12)
		tw.set_parallel(false)
		tw.tween_property(visual, "scale", Vector3.ONE, 0.16)

func _kill_player(index: int):
	var state := _game.character_state_at(index) as CharacterState
	if state == null or not state.is_alive():
		return
	var p := state.data
	var was_downed := state.defeat()
	if not was_downed:
		_game.audio_manager.play("down")
	if _game.airborne_controller:
		_game.airborne_controller.force_land(index)
	_cancel_player_movement(p)
	_cancel_player_state_animation(p)
	if str(p.get("boss_id", "")) != "":
		_game.powerup_manager.spawn_boss_reward(p["grid_pos"])
	var node = p.get("node")
	if not is_instance_valid(node):
		check_game_over()
		return
	var visual := _player_visual(p)
	var tw := create_tween().bind_node(visual)
	p["state_tween"] = tw
	tw.tween_property(visual, "scale", Vector3.ONE * 0.05, 0.35)
	tw.tween_callback(func():
		if is_instance_valid(node):
			p["node"] = null
			node.queue_free()
		p["state_tween"] = null
		check_game_over()
	)

func check_game_over():
	if _game.players.is_empty():
		return
	if not _game.players[0]["alive"]:
		_game.game_over = true
		_game.game_ui.show_result(2)
		return
	var hostile_count := 0
	for i in range(1, _game.players.size()):
		if _game.players[i]["alive"]:
			hostile_count += 1
	if _game.wave_manager and _game.wave_manager.is_final_wave() and hostile_count == 0:
		_game.game_over = true
		_game.game_ui.show_result(1)

func _cancel_player_movement(p: Dictionary):
	var move_tween = p.get("move_tween")
	if move_tween is Tween and is_instance_valid(move_tween):
		(move_tween as Tween).kill()
	_game.movement_controller.cancel_move(p)

func _cancel_player_state_animation(p: Dictionary):
	var state_tween = p.get("state_tween")
	if state_tween is Tween and is_instance_valid(state_tween):
		(state_tween as Tween).kill()
	p["state_tween"] = null

func _flash_player_damage(p: Dictionary):
	var node: Node3D = p["node"]
	if not is_instance_valid(node):
		return
	var visual := _player_visual(p)
	var tw := create_tween().bind_node(visual)
	tw.tween_property(visual, "scale", Vector3.ONE * 1.12, 0.08)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.10)

func _player_visual(player: Dictionary) -> Node3D:
	var visual = player.get("visual_node")
	if is_instance_valid(visual):
		return visual as Node3D
	return player["node"] as Node3D

func _flash_player_shield(p: Dictionary):
	var node: Node3D = p["node"]
	if not is_instance_valid(node):
		return
	var shield := MeshHelpers.sphere(0.62, _game.art.mat_shield)
	shield.transparency = 0.35
	node.add_child(shield)
	var tw := create_tween()
	tw.tween_property(shield, "scale", Vector3(1.35, 1.35, 1.35), 0.18)
	tw.tween_property(shield, "transparency", 1.0, 0.18)
	tw.tween_callback(shield.queue_free)

func _damage_player(index: int, amount: int, source: String):
	damage_player(index, amount, source)

func grant_shield(index: int, amount := 1):
	if index < 0 or index >= _game.players.size():
		return
	var player: Dictionary = _game.players[index]
	player["shield"] = clampi(int(player.get("shield", 0)) + amount, 0, 5)
	player["shield_timer"] = Constants.SHIELD_DURATION
	player["status"] = "Shield %.1fs" % Constants.SHIELD_DURATION
	_game.audio_manager.play("shield")
	if bool(player.get("ai", false)) and _game.ai_controller:
		_game.ai_controller.on_shield_granted(index)
	if _game.consumable_effects and _game.consumable_effects.status_visuals:
		_game.consumable_effects.status_visuals.refresh_player(player)

func _consume_dummy_if_available(p: Dictionary) -> bool:
	return _game.inventory_manager.consume_item(p, "dummy")
