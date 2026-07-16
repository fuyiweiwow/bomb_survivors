class_name LevelSession
extends RefCounted

const LEVEL_CATALOG := preload("res://scripts/level/level_catalog.gd")

static var _selected_level_id := ""

static func select_level(level_id: String) -> bool:
	var catalog := LEVEL_CATALOG.new() as LevelCatalog
	if not catalog.contains(level_id):
		return false
	_selected_level_id = level_id
	return true

static func clear() -> void:
	_selected_level_id = ""

static func has_selected_level() -> bool:
	return not _selected_level_id.is_empty()

static func selected_level_id() -> String:
	return _selected_level_id

static func current_profile() -> Dictionary:
	var catalog := LEVEL_CATALOG.new() as LevelCatalog
	return catalog.profile(_selected_level_id) if has_selected_level() else catalog.standalone_profile()
