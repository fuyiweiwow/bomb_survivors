class_name InventoryManager
extends RefCounted

const MAX_ITEMS := 3

func selected_item(player: Dictionary) -> String:
	var items: Array = player.get("consumables", [])
	if items.is_empty():
		return ""
	_normalize_selection(player)
	return str(items[int(player["selected_consumable_index"])])

func cycle(player: Dictionary) -> String:
	var items: Array = player.get("consumables", [])
	if items.is_empty():
		player["selected_consumable_index"] = 0
		return ""
	player["selected_consumable_index"] = (int(player.get("selected_consumable_index", 0)) + 1) % items.size()
	return str(items[int(player["selected_consumable_index"])])

func add_item(player: Dictionary, item_id: String) -> bool:
	var items: Array = player.get("consumables", [])
	if items.size() >= MAX_ITEMS:
		return false
	items.append(item_id)
	_normalize_selection(player)
	return true

func consume_selected(player: Dictionary) -> String:
	var items: Array = player.get("consumables", [])
	if items.is_empty():
		return ""
	_normalize_selection(player)
	var selected := int(player["selected_consumable_index"])
	var item_id := str(items[selected])
	items.remove_at(selected)
	_normalize_selection(player)
	return item_id

func consume_item(player: Dictionary, item_id: String) -> bool:
	var items: Array = player.get("consumables", [])
	var index := items.find(item_id)
	if index < 0:
		return false
	items.remove_at(index)
	_normalize_selection(player)
	return true

func _normalize_selection(player: Dictionary):
	var items: Array = player.get("consumables", [])
	player["selected_consumable_index"] = clampi(
		int(player.get("selected_consumable_index", 0)),
		0,
		maxi(items.size() - 1, 0)
	)
