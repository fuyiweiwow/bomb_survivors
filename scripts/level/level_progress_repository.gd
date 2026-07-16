class_name LevelProgressRepository
extends RefCounted

const DEFAULT_PATH := "user://level_progress.json"
const LEVEL_CATALOG := preload("res://scripts/level/level_catalog.gd")

var progress_path: String
var catalog := LEVEL_CATALOG.new() as LevelCatalog

func _init(path := DEFAULT_PATH) -> void:
	progress_path = path

func completed_level_ids() -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = _read_json()
	if not raw is Dictionary:
		return result
	var stored: Variant = (raw as Dictionary).get("completed", [])
	if not stored is Array:
		return result
	for raw_id in stored:
		var level_id := str(raw_id)
		if catalog.contains(level_id) and not result.has(level_id):
			result.append(level_id)
	return result

func is_unlocked(level_id: String) -> bool:
	var levels := catalog.levels()
	if levels.is_empty() or not catalog.contains(level_id):
		return false
	if str(levels[0]["id"]) == level_id:
		return true
	var completed := completed_level_ids()
	for completed_id in completed:
		if catalog.next_level_id(completed_id) == level_id:
			return true
	return completed.has(level_id)

func complete_level(level_id: String) -> bool:
	if not catalog.contains(level_id):
		return false
	var completed := completed_level_ids()
	if not completed.has(level_id):
		completed.append(level_id)
	return _write_json({"version": 1, "completed": completed})

func _read_json() -> Variant:
	if not FileAccess.file_exists(progress_path):
		return null
	var file := FileAccess.open(progress_path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	return json.get_data() if result == OK else null

func _write_json(data: Dictionary) -> bool:
	var file := FileAccess.open(progress_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true
