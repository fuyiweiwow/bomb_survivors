extends Node

const MODEL_FACTORY := preload("res://scripts/item/powerup_model_factory.gd")
const DROP_TABLE := preload("res://scripts/item/powerup_drop_table.gd")

var _game: Node
var drop_table := DROP_TABLE.new()

func setup(game_manager: Node):
	_game = game_manager

func spawn_powerup(cell: Vector2i):
	var ptype := drop_table.pick(randf())
	if ptype.is_empty():
		return

	var node := _create_powerup_model(ptype)
	node.position = Constants.grid_to_world(cell) + Vector3(0, 0.32, 0)
	_game.add_child(node)
	_game.powerups[cell] = {"node": node, "type": ptype}

func check_powerup_pickup(index: int):
	var state := _game.character_state_at(index) as CharacterState
	if state == null:
		return
	var cell := state.cell()
	if not _game.powerups.has(cell):
		return

	var data: Dictionary = _game.powerups[cell]
	var node: Node3D = data["node"]
	if is_instance_valid(node):
		node.queue_free()

	match data["type"]:
		"speed":
			if not state.increase_speed():
				state.set_status("Speed at maximum")
		"bomb":
			if not state.bombs.increase_capacity():
				state.set_status("Bomb capacity at maximum")
		"range":
			if not state.bombs.increase_range(2):
				state.set_status("Bomb range at maximum")
		"shield":
			if state.is_ai():
				_game.combat_manager.grant_shield(index)
			else:
				_add_consumable(state, "shield_potion")
		_:
			if Constants.CONSUMABLE_IDS.has(str(data["type"])):
				_add_consumable(state, str(data["type"]))
	_game.audio_manager.play("pickup")
	_game.powerups.erase(cell)

func spawn_boss_reward(cell: Vector2i):
	if _game.powerups.has(cell):
		return
	var node := _create_powerup_model("dummy")
	node.position = Constants.grid_to_world(cell) + Vector3(0, 0.32, 0)
	_game.add_child(node)
	_game.powerups[cell] = {"node": node, "type": "dummy"}

func _add_consumable(state: CharacterState, item_id: String) -> bool:
	_game.inventory_manager.add_item(state, item_id)
	state.set_status("Picked %s" % _item_display_name(item_id))
	return true

func item_display_name(item_id: String) -> String:
	return _item_display_name(item_id)

func _item_display_name(item_id: String) -> String:
	match item_id:
		"detonator": return "Detonator"
		"glue": return "Glue"
		"shield_potion": return "Shield Potion"
		"invincible_star": return "Invincible Star"
		"dummy": return "Dummy"
		"oil_barrel": return "Oil Barrel"
		"rock": return "Rock"
		"wings": return "Wings"
		"football_shoes": return "Football Shoes"
		"prison": return "Prison"
		"duel": return "Duel Token"
	return item_id.capitalize()

func _create_powerup_model(ptype: String) -> Node3D:
	var root := MODEL_FACTORY.create(ptype, _game.art)
	var tw := create_tween().set_loops()
	tw.tween_property(root, "rotation_degrees:y", 360.0, 2.4).as_relative()
	return root
