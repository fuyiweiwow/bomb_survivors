class_name PlayerCommandHandler
extends Node

const INPUT_CONTROLLER := preload("res://scripts/character/player_input_controller.gd")

var _game: Node
var input: Node

func setup(game: Node) -> void:
	_game = game
	input = INPUT_CONTROLLER.new()
	add_child(input)
	input.action_requested.connect(handle_action)
	_game.input_controller = input

func handle_action(action: String) -> void:
	if _game.game_over:
		match action:
			"restart": _game.get_tree().reload_current_scene()
			"menu": _game.get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
			"cycle_item": _game.get_tree().quit()
		return
	if action.begins_with("select_item_"):
		select_consumable(int(action.trim_prefix("select_item_")))
		return
	match action:
		"bomb": _game.bomb_pressed = true
		"use_item": use_consumable()
		"cycle_item": cycle_consumable()
		"menu": _game.get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func process_player_input() -> void:
	if _game.character_registry.is_empty():
		return
	var state := _game.character_state_at(0) as CharacterState
	if state == null or not state.is_alive() or state.is_downed():
		_game.bomb_pressed = false
		return
	if _game.bomb_pressed or Input.is_action_just_pressed("p1_bomb"):
		_game.bomb_pressed = false
		handle_bomb_action()
	else:
		_game.bomb_pressed = false
	if not state.is_moving():
		try_move_from_input(0)

func try_move_from_input(player_index: int) -> bool:
	for direction in input.consume_move_candidates():
		if _game.movement_controller.try_move(player_index, direction):
			return true
	return false

func read_move_direction() -> Vector2i:
	return input.read_move_direction() if input else Vector2i.ZERO

func handle_bomb_action() -> void:
	var state := _game.character_state_at(0) as CharacterState
	if state == null:
		return
	if state.is_airborne():
		if state.effects.has_wings() and state.effects.has_rock():
			_game.rock_attack_controller.try_drop_rock(0)
		elif state.effects.has_wings():
			state.set_status("Rock is required for an aerial drop")
		else:
			state.set_status("Cannot use a ground attack in the air")
		return
	if state.effects.has_rock():
		_game.rock_attack_controller.try_shoot_rock(0)
	elif state.effects.has_football():
		_game.bomb_manager.kick_bomb_in_direction(state)
	elif state.bombs.can_place():
		_game.bomb_manager.try_place_bomb(0)

func use_consumable() -> void:
	if _game.duel_manager and _game.duel_manager.active and _game.duel_manager.round:
		_game.duel_manager.round.use_selected_item()
		return
	if _game.character_registry.is_empty():
		return
	var state := _game.character_state_at(0) as CharacterState
	if state == null:
		return
	if state.is_downed():
		if _game.combat_manager.consume_dummy_if_available(state):
			_game.combat_manager.revive_player(0)
		return
	if not state.is_alive():
		return
	var items: Array = state.data["consumables"]
	if items.is_empty():
		state.set_status("Bag empty")
		return
	var item_id := str(_game.inventory_manager.selected_item(state))
	if item_id == "dummy":
		state.set_status("Dummy is passive")
		return
	if _game.consumable_effects.use(0, item_id):
		if item_id != "shield_potion":
			_game.audio_manager.play("confirm")
		_game.inventory_manager.consume_selected(state)

func cycle_consumable() -> void:
	if _game.duel_manager and _game.duel_manager.active and _game.duel_manager.round:
		_game.duel_manager.round.cycle_item()
		return
	var state := _game.character_state_at(0) as CharacterState
	if state == null or not state.is_alive():
		return
	var items: Array = state.data["consumables"]
	if items.is_empty():
		state.set_status("Bag empty")
		return
	var item_id := str(_game.inventory_manager.cycle(state))
	state.set_status("Selected %s" % _game.powerup_manager.item_display_name(item_id))
	_game.audio_manager.play("ui_select")

func select_consumable(slot_index: int) -> void:
	if _game.duel_manager and _game.duel_manager.active and _game.duel_manager.round:
		_game.duel_manager.round.select_item(slot_index)
		return
	var state := _game.character_state_at(0) as CharacterState
	if state == null or not state.is_alive():
		return
	var item_id: String = _game.inventory_manager.select_slot(state, slot_index)
	if item_id.is_empty():
		state.set_status("Bag slot %d empty" % (slot_index + 1))
		return
	state.set_status("Selected %s" % _game.powerup_manager.item_display_name(item_id))
	_game.audio_manager.play("ui_select")
