class_name ProgressionCoordinator
extends Node

const WEATHER_MANAGER := preload("res://scripts/weather/weather_manager.gd")
const WAVE_MANAGER := preload("res://scripts/wave/wave_manager.gd")

var _game: Node

func setup(game: Node) -> void:
	_game = game
	_game.weather_manager = WEATHER_MANAGER.new()
	add_child(_game.weather_manager)
	_game.weather_manager.weather_changed.connect(_game.game_ui.on_weather_changed)
	_game.weather_manager.thunder_requested.connect(_game.game_ui.request_thunder_strike)

	_game.wave_manager = WAVE_MANAGER.new()
	add_child(_game.wave_manager)
	_game.wave_manager.wave_started.connect(_on_wave_started)
	_game.wave_manager.start()

func process(delta: float) -> void:
	_game.wave_manager.process_wave(delta)
	_game.weather_manager.process_weather(delta)

func _on_wave_started(wave_number: int, enemy_count: int, boss_id: String) -> void:
	_game.weather_manager.start_wave(wave_number, _game.grid_manager.walkable_cells())
	if not boss_id.is_empty():
		_game.grid_manager.refresh_crates_for_boss()
		if _game.player_manager.spawn_boss(boss_id, _game.next_player_id):
			_game.next_player_id += 1
	var spawned_count: int = _game.player_manager.spawn_ai_wave(enemy_count, _game.ai_difficulty, _game.next_player_id)
	_game.next_player_id += spawned_count
