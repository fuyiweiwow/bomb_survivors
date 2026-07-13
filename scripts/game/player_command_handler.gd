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
	if _game.players.is_empty():
		return
	var player: Dictionary = _game.players[0]
	if not player["alive"] or bool(player.get("downed", false)):
		_game.bomb_pressed = false
		return
	if _game.bomb_pressed or Input.is_action_just_pressed("p1_bomb"):
		_game.bomb_pressed = false
		handle_bomb_action()
	else:
		_game.bomb_pressed = false
	if not player["is_moving"]:
		try_move_from_input(0)

func try_move_from_input(player_index: int) -> bool:
	for direction in input.consume_move_candidates():
		if _game.movement_controller.try_move(player_index, direction):
			return true
	return false

func read_move_direction() -> Vector2i:
	return input.read_move_direction() if input else Vector2i.ZERO

func handle_bomb_action() -> void:
	var player: Dictionary = _game.players[0]
	if bool(player.get("airborne", false)):
		player["status"] = "Cannot place a ground bomb in the air"
		return
	if float(player.get("football_timer", 0.0)) > 0.0:
		_game.bomb_manager.kick_bomb_in_direction(player)
	elif int(player["bomb_placed_count"]) < int(player["bomb_max"]):
		_game.bomb_manager.try_place_bomb(0)

func use_consumable() -> void:
	if _game.players.is_empty():
		return
	var player: Dictionary = _game.players[0]
	if bool(player.get("downed", false)):
		if _game.combat_manager.consume_dummy_if_available(player):
			_game.combat_manager.revive_player(0)
		return
	if not player["alive"]:
		return
	var items: Array = player["consumables"]
	if items.is_empty():
		player["status"] = "Bag empty"
		return
	var item_id := str(_game.inventory_manager.selected_item(player))
	if item_id == "dummy":
		player["status"] = "Dummy is passive"
		return
	if _game.consumable_effects.use(0, item_id):
		if item_id != "shield_potion":
			_game.audio_manager.play("confirm")
		_game.inventory_manager.consume_selected(player)

func cycle_consumable() -> void:
	if _game.players.is_empty() or not _game.players[0]["alive"]:
		return
	var player: Dictionary = _game.players[0]
	var items: Array = player["consumables"]
	if items.is_empty():
		player["status"] = "Bag empty"
		return
	var item_id := str(_game.inventory_manager.cycle(player))
	player["status"] = "Selected %s" % _game.powerup_manager.item_display_name(item_id)
	_game.audio_manager.play("ui_select")

func select_consumable(slot_index: int) -> void:
	if _game.players.is_empty() or not _game.players[0]["alive"]:
		return
	var player: Dictionary = _game.players[0]
	var item_id: String = _game.inventory_manager.select_slot(player, slot_index)
	if item_id.is_empty():
		player["status"] = "Bag slot %d empty" % (slot_index + 1)
		return
	player["status"] = "Selected %s" % _game.powerup_manager.item_display_name(item_id)
	_game.audio_manager.play("ui_select")
