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

func consume_dummy_if_available(character: Variant) -> bool:
	return _consume_dummy_if_available(character)

func cancel_player_movement(character: Variant) -> void:
	_cancel_player_movement(character)

func force_down_player(player_index: int, source: String) -> void:
	var state := _game.character_state_at(player_index) as CharacterState
	if state != null and state.is_alive() and not state.is_downed():
		_enter_downed(player_index, source)

func process_downed(delta: float):
	for i in range(_game.character_registry.count()):
		var state := _game.character_state_at(i) as CharacterState
		if state == null or not state.is_alive() or not state.is_downed():
			continue
		var expired := state.tick_downed(delta)
		if _consume_dummy_if_available(state):
			_revive_player(i)
		elif expired:
			_kill_player(i)

func process_character_overlaps():
	for downed_index in range(_game.character_registry.count()):
		var downed_state := _game.character_state_at(downed_index) as CharacterState
		if downed_state == null or not downed_state.is_alive() or not downed_state.is_downed():
			continue
		if downed_state.effects.duel_return_grace_time() > 0.0:
			continue
		for other_index in range(_game.character_registry.count()):
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

	for i in range(_game.character_registry.count()):
		var state := _game.character_state_at(i) as CharacterState
		if hit_registry.has(i) or state == null or not state.is_alive() or not rules.is_in_attack_cells(state, cells, min_height, max_height):
			continue
		hit_registry[i] = true
		if i == explosion_owner and _game.wall_mechanics.try_bomb_boost(i):
			continue
		_damage_player(i, 1, "blast")

func is_player_in_attack_cells(state: CharacterState, cells: Array, min_height: float, max_height: float) -> bool:
	if state == null:
		return false
	return rules.is_in_attack_cells(state, cells, min_height, max_height)

func damage_player(index: int, amount: int, source: String):
	var state := _game.character_state_at(index) as CharacterState
	if state == null:
		return
	match rules.damage_route(state, source):
		CombatRules.DamageRoute.DUEL_IMMUNE:
			state.set_status("Duel immunity")
		CombatRules.DamageRoute.INVINCIBLE:
			state.set_status("Invincible")
		CombatRules.DamageRoute.EXECUTE_DOWNED:
			_kill_player(index)
		CombatRules.DamageRoute.ABSORB_SHIELD:
			state.consume_shield()
			_game.character_presentation.flash_shield(state)
			_game.audio_manager.play("shield")
		CombatRules.DamageRoute.DAMAGE_HEALTH:
			var defeated := state.damage_health(amount)
			_game.character_presentation.flash_damage(state)
			_game.audio_manager.play("hit")
			if defeated:
				if state.boss_id() != "" or state.is_minion():
					_kill_player(index)
				else:
					_enter_downed(index, source)

func _enter_downed(index: int, source: String):
	var state := _game.character_state_at(index) as CharacterState
	if state == null or not state.is_alive():
		return
	state.enter_downed(source, Constants.DOWNED_DURATION)
	_game.audio_manager.play("down")
	if _game.airborne_controller:
		_game.airborne_controller.force_land(index)
	_cancel_player_movement(state)
	if index == 0:
		_game.bomb_pressed = false
	_game.character_presentation.show_downed(state)

func _revive_player(index: int):
	var state := _game.character_state_at(index) as CharacterState
	if state == null:
		return
	state.revive()
	_game.character_presentation.show_revived(state)

func _kill_player(index: int):
	var state := _game.character_state_at(index) as CharacterState
	if state == null or not state.is_alive():
		return
	var was_downed := state.defeat()
	if not was_downed:
		_game.audio_manager.play("down")
	if _game.airborne_controller:
		_game.airborne_controller.force_land(index)
	_cancel_player_movement(state)
	if state.boss_id() != "":
		_game.powerup_manager.spawn_boss_reward(state.cell())
	if state.node() == null:
		check_game_over()
		return
	_game.character_presentation.show_defeated(state, Callable(self, "check_game_over"))

func check_game_over():
	if _game.character_registry.is_empty():
		return
	var player_state := _game.character_registry.state_at(0) as CharacterState
	if player_state == null or not player_state.is_alive():
		_game.game_over = true
		_game.game_ui.show_result(2)
		return
	var hostile_count := 0
	for i in range(1, _game.character_registry.count()):
		var state := _game.character_registry.state_at(i) as CharacterState
		if state != null and state.is_alive():
			hostile_count += 1
	if _game.wave_manager and _game.wave_manager.is_final_wave() and hostile_count == 0:
		_game.game_over = true
		_game.complete_current_level()
		_game.game_ui.show_result(1)

func _cancel_player_movement(character: Variant):
	var state := character as CharacterState if character is CharacterState else null
	if state == null and character is Dictionary:
		state = _game.character_state_by_id(int((character as Dictionary).get("id", -1)))
	if state == null:
		return
	var move_tween := state.move_tween()
	if move_tween != null:
		move_tween.kill()
	_game.movement_controller.cancel_move(state.data)

func _damage_player(index: int, amount: int, source: String):
	damage_player(index, amount, source)

func grant_shield(index: int, amount := 1):
	var state := _game.character_state_at(index) as CharacterState
	if state == null:
		return
	state.effects.grant_shield(amount, Constants.SHIELD_DURATION)
	state.set_status("Shield %.1fs" % Constants.SHIELD_DURATION)
	_game.audio_manager.play("shield")
	if state.is_ai() and _game.ai_controller:
		_game.ai_controller.on_shield_granted(index)
	if _game.consumable_effects and _game.consumable_effects.status_visuals:
		_game.consumable_effects.status_visuals.refresh_player(state.data)

func _consume_dummy_if_available(character: Variant) -> bool:
	return _game.inventory_manager.consume_item(character, "dummy")
