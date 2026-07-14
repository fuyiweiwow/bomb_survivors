extends Node

const CELL_WALL := Constants.Cell.WALL
const STATUS_EFFECT_VISUALS := preload("res://scripts/item/status_effect_visuals.gd")
const AREA_EFFECT_CONTROLLER := preload("res://scripts/item/item_area_effect_controller.gd")
const ACTIVATION_PRESENTATION := preload("res://scripts/item/consumable_activation_presentation.gd")

var game: Node
var status_visuals: Node
var area_effects: ItemAreaEffectController
var activation_presentation: ConsumableActivationPresentation

func setup(game_manager: Node):
	game = game_manager
	status_visuals = STATUS_EFFECT_VISUALS.new()
	add_child(status_visuals)
	status_visuals.setup(game)
	area_effects = AREA_EFFECT_CONTROLLER.new()
	add_child(area_effects)
	area_effects.setup(game)
	activation_presentation = ACTIVATION_PRESENTATION.new()
	add_child(activation_presentation)
	activation_presentation.setup(game)

func use(player_index: int, item_id: String) -> bool:
	var state := game.character_state_at(player_index) as CharacterState
	if state == null:
		return false
	if game.duel_manager and game.duel_manager.active:
		state.set_status("Backpack locked during duel")
		return false
	match item_id:
		"detonator":
			return _complete_use(state, item_id, _use_detonator(state))
		"glue":
			return _complete_use(state, item_id, area_effects.place_glue(player_index))
		"shield_potion":
			game.combat_manager.grant_shield(player_index)
			return _complete_use(state, item_id, true)
		"invincible_star":
			state.effects.grant_invincibility(5.0)
			state.set_status("Invincible 5s")
			status_visuals.refresh_player(state.data)
			return _complete_use(state, item_id, true)
		"oil_barrel":
			return _complete_use(state, item_id, area_effects.place_oil_barrel(player_index))
		"wings":
			state.effects.grant_wings(Constants.WINGS_DURATION)
			state.set_status("Wings %.0fs" % Constants.WINGS_DURATION)
			if state.is_ai() and game.ai_controller:
				game.ai_controller.on_wings_granted(player_index)
			status_visuals.refresh_player(state.data)
			return _complete_use(state, item_id, true)
		"football_shoes":
			state.effects.grant_football(8.0)
			state.set_status("Football shoes 8s")
			status_visuals.refresh_player(state.data)
			return _complete_use(state, item_id, true)
		"prison":
			return _complete_use(state, item_id, _cast_prison(player_index))
		"duel":
			return _complete_use(state, item_id, game.duel_manager.arm(player_index))
	return false

func process(delta: float):
	area_effects.process(delta)

func end_wings(state: CharacterState):
	if state.is_airborne():
		return
	var cell := state.cell()
	if game.map_state.is_walkable(cell) and not game.bomb_map.has(cell) and not game.oil_barrels.has(cell):
		return
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var target: Vector2i = cell + direction
		if target.x < 0 or target.x >= Constants.GRID_W or target.y < 0 or target.y >= Constants.GRID_H:
			continue
		if game.map_state.is_walkable(target) and not game.bomb_map.has(target) and not game.oil_barrels.has(target) and not game.wall_mechanics.is_cell_occupied(target):
			state.set_cell(target)
			var player_node := state.node()
			if player_node != null:
				player_node.position = Constants.grid_to_world(target)
			return

func damage_oil_barrel(cell: Vector2i):
	area_effects.damage_oil_barrel(cell)

func should_ai_avoid_glue(state: CharacterState, cell: Vector2i) -> bool:
	return area_effects.should_ai_avoid_glue(state, cell)

func _complete_use(state: CharacterState, item_id: String, applied: bool) -> bool:
	if applied:
		activation_presentation.play(state, item_id)
	return applied

func _use_detonator(state: CharacterState) -> bool:
	var detonated: int = game.bomb_manager.explode_all_bombs()
	if detonated <= 0:
		state.set_status("No bombs on the map")
		return false
	state.set_status("Detonated %d bombs" % detonated)
	return true

func _cast_prison(player_index: int) -> bool:
	var caster := game.character_state_at(player_index) as CharacterState
	if caster == null:
		return false
	var trapped := 0
	for target_index in range(game.character_registry.count()):
		if target_index == player_index:
			continue
		var target := game.character_state_at(target_index) as CharacterState
		if target == null or not target.is_alive() or target.is_downed() or target.is_ai() == caster.is_ai():
			continue
		var offset := target.cell() - caster.cell()
		if absi(offset.x) > Constants.PRISON_RADIUS or absi(offset.y) > Constants.PRISON_RADIUS:
			continue
		target.effects.imprison(Constants.PRISON_DURATION)
		target.set_status("Prison %.1fs" % Constants.PRISON_DURATION)
		status_visuals.refresh_player(target.data)
		trapped += 1
	caster.set_status("Prison trapped %d enemies" % trapped)
	return trapped > 0
