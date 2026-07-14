class_name GameConfigRepository
extends RefCounted

const DEFAULT_PLAYER_CONFIG_PATH := "user://player_config.json"
const DEFAULT_AI_SETTINGS_PATH := "user://ai_settings.json"
const VALID_GENDERS := ["male", "female"]
const VALID_DIFFICULTIES := ["easy", "normal", "hard"]

var player_config_path: String
var ai_settings_path: String

func _init(
	p_player_config_path: String = DEFAULT_PLAYER_CONFIG_PATH,
	p_ai_settings_path: String = DEFAULT_AI_SETTINGS_PATH
) -> void:
	player_config_path = p_player_config_path
	ai_settings_path = p_ai_settings_path

func default_player_config() -> Dictionary:
	return {
		"gender": "male",
		"start_speed": 5,
		"start_bombs": 1,
		"start_range": 2,
		"start_shields": 0,
	}

func load_player_config() -> Dictionary:
	return sanitize_player_config(_read_json(player_config_path))

func save_player_config(config: Dictionary) -> bool:
	return _write_json(player_config_path, sanitize_player_config(config))

func sanitize_player_config(raw_config: Variant) -> Dictionary:
	var config := default_player_config()
	if not raw_config is Dictionary:
		return config
	var source := raw_config as Dictionary
	var gender := str(source.get("gender", config["gender"]))
	config["gender"] = gender if VALID_GENDERS.has(gender) else config["gender"]
	config["start_speed"] = clampi(int(source.get("start_speed", config["start_speed"])), 1, 10)
	config["start_bombs"] = clampi(int(source.get("start_bombs", config["start_bombs"])), 1, 8)
	config["start_range"] = clampi(int(source.get("start_range", config["start_range"])), 1, 10)
	config["start_shields"] = clampi(int(source.get("start_shields", config["start_shields"])), 0, 3)
	return config

func load_ai_difficulty() -> String:
	var settings: Variant = _read_json(ai_settings_path)
	if not settings is Dictionary:
		return "normal"
	return sanitize_ai_difficulty(str((settings as Dictionary).get("difficulty", "normal")))

func save_ai_difficulty(difficulty: String) -> bool:
	return _write_json(ai_settings_path, {"difficulty": sanitize_ai_difficulty(difficulty)})

func sanitize_ai_difficulty(difficulty: String) -> String:
	return difficulty if VALID_DIFFICULTIES.has(difficulty) else "normal"

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	return json.get_data() if parse_result == OK else null

func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true
