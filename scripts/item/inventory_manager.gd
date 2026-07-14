class_name InventoryManager
extends RefCounted

const MAX_ITEMS := 3

func selected_item(owner: Variant) -> String:
	var player := _data_for(owner)
	var items := _items_for(player)
	if items.is_empty():
		return ""
	_normalize_selection(player)
	return str(items[int(player["selected_consumable_index"])])

func cycle(owner: Variant) -> String:
	var player := _data_for(owner)
	var items := _items_for(player)
	if items.is_empty():
		player["selected_consumable_index"] = 0
		return ""
	player["selected_consumable_index"] = (int(player.get("selected_consumable_index", 0)) + 1) % items.size()
	return str(items[int(player["selected_consumable_index"])])

func select_slot(owner: Variant, slot_index: int) -> String:
	var player := _data_for(owner)
	var items := _items_for(player)
	if slot_index < 0 or slot_index >= items.size():
		return ""
	player["selected_consumable_index"] = slot_index
	return str(items[slot_index])

func add_item(owner: Variant, item_id: String) -> bool:
	if not owner is CharacterState and not owner is Dictionary:
		return false
	var player := _data_for(owner)
	var items := _items_for(player)
	var selected := int(player.get("selected_consumable_index", 0))
	while items.size() >= MAX_ITEMS:
		items.pop_front()
		selected = maxi(selected - 1, 0)
	items.append(item_id)
	player["selected_consumable_index"] = selected
	_normalize_selection(player)
	return true

func consume_selected(owner: Variant) -> String:
	var player := _data_for(owner)
	var items := _items_for(player)
	if items.is_empty():
		return ""
	_normalize_selection(player)
	var selected := int(player["selected_consumable_index"])
	var item_id := str(items[selected])
	items.remove_at(selected)
	_normalize_selection(player)
	return item_id

func consume_item(owner: Variant, item_id: String) -> bool:
	var player := _data_for(owner)
	var items := _items_for(player)
	var index := items.find(item_id)
	if index < 0:
		return false
	items.remove_at(index)
	_normalize_selection(player)
	return true

func _normalize_selection(player: Dictionary):
	var items := _items_for(player)
	player["selected_consumable_index"] = clampi(
		int(player.get("selected_consumable_index", 0)),
		0,
		maxi(items.size() - 1, 0)
	)

func _data_for(owner: Variant) -> Dictionary:
	if owner is CharacterState:
		return (owner as CharacterState).data
	return owner as Dictionary if owner is Dictionary else {}

func _items_for(player: Dictionary) -> Array:
	var stored_items = player.get("consumables")
	if stored_items is Array:
		return stored_items as Array
	var items: Array = []
	player["consumables"] = items
	return items
