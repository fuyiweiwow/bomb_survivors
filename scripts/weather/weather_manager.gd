class_name WeatherManager
extends Node

signal weather_changed(weather_type: String)
signal thunder_requested

const WEATHER_TYPES := ["clear", "rain", "fog", "wind", "thunder", "snow"]

var current_weather := "clear"
var wind_direction := Vector2i.RIGHT
var snow_cells: Dictionary = {}
var _thunder_timer := 0.0

func start_wave(wave_number: int, walkable_cells: Array) -> void:
	var choices := WEATHER_TYPES.duplicate()
	if wave_number <= 1:
		current_weather = "clear"
	elif choices.size() > 1:
		choices.erase(current_weather)
		current_weather = str(choices.pick_random())
	wind_direction = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT].pick_random()
	snow_cells.clear()
	if current_weather == "snow":
		var shuffled := walkable_cells.duplicate()
		shuffled.shuffle()
		var snow_count := mini(mini(maxi(roundi(float(shuffled.size()) * 0.10), 18), 28), shuffled.size())
		for i in range(snow_count):
			snow_cells[shuffled[i]] = true
	_thunder_timer = randf_range(3.5, 5.5)
	weather_changed.emit(current_weather)

func process_weather(delta: float) -> void:
	if current_weather != "thunder":
		return
	_thunder_timer -= delta
	if _thunder_timer <= 0.0:
		_thunder_timer = randf_range(4.0, 7.0)
		thunder_requested.emit()

func movement_duration_multiplier(cell: Vector2i) -> float:
	if current_weather == "rain":
		return 1.12
	if current_weather == "snow" and snow_cells.has(cell):
		return 1.30
	return 1.0

func can_see(observer: Vector2i, target: Vector2i) -> bool:
	if current_weather != "fog":
		return true
	return abs(observer.x - target.x) + abs(observer.y - target.y) <= 5

func should_extend_wind(direction: Vector2i) -> bool:
	return current_weather == "wind" and direction == wind_direction and randf() < 0.30

func display_name() -> String:
	match current_weather:
		"rain": return "Rain"
		"fog": return "Fog"
		"wind": return "Wind %s" % _direction_name(wind_direction)
		"thunder": return "Thunder"
		"snow": return "Snow"
		_: return "Clear"

func _direction_name(direction: Vector2i) -> String:
	if direction == Vector2i.UP: return "N"
	if direction == Vector2i.DOWN: return "S"
	if direction == Vector2i.LEFT: return "W"
	return "E"
