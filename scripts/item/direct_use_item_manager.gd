class_name DirectUseItemManager
extends Node

var game: Node

func setup(game_manager: Node) -> void:
	game = game_manager

func is_direct_use_item(item_id: String) -> bool:
	return Constants.DIRECT_USE_ITEM_IDS.has(item_id)

func equipped_item(owner: Variant) -> String:
	var state := owner as CharacterState if owner is CharacterState else null
	if state != null:
		return state.direct_use_item()
	if owner is Dictionary:
		return str((owner as Dictionary).get("direct_use_item", ""))
	return ""

func equip(state: CharacterState, item_id: String) -> bool:
	if state == null or not state.is_alive() or not is_direct_use_item(item_id):
		return false
	state.set_direct_use_item(item_id)
	state.set_status("Equipped %s" % game.powerup_manager.item_display_name(item_id))
	_refresh_visual(state)
	return true

func discard(state: CharacterState) -> String:
	if state == null or not state.is_alive():
		return ""
	var previous := state.direct_use_item()
	if previous.is_empty():
		state.set_status("No direct-use item equipped")
		return ""
	state.set_direct_use_item("")
	state.set_status("Discarded %s" % game.powerup_manager.item_display_name(previous))
	_refresh_visual(state)
	return previous

func _refresh_visual(state: CharacterState) -> void:
	if game.consumable_effects and game.consumable_effects.status_visuals:
		game.consumable_effects.status_visuals.refresh_player(state.data)
