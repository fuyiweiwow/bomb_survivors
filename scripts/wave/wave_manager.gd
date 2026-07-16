class_name WaveManager
extends Node

signal wave_started(wave_number: int, enemy_count: int, boss_id: String)

const DEFAULT_WAVE_DURATION := 30.0
const DEFAULT_MAX_WAVE := 7
const BOSS_WAVES := {
	3: "blast_king",
	5: "frost_giant",
	7: "clone_demon"
}

var current_wave := 0
var elapsed := 0.0
var final_wave_started := false
var wave_duration := DEFAULT_WAVE_DURATION
var max_wave := DEFAULT_MAX_WAVE

func configure(profile: Dictionary) -> void:
	wave_duration = maxf(float(profile.get("wave_duration", DEFAULT_WAVE_DURATION)), 1.0)
	max_wave = maxi(int(profile.get("max_waves", DEFAULT_MAX_WAVE)), 1)

func start() -> void:
	_start_next_wave()

func process_wave(delta: float) -> void:
	if final_wave_started:
		return
	elapsed += delta
	if elapsed >= wave_duration:
		_start_next_wave()

func time_remaining() -> float:
	if final_wave_started:
		return 0.0
	return maxf(wave_duration - elapsed, 0.0)

func is_final_wave() -> bool:
	return final_wave_started

func _start_next_wave() -> void:
	current_wave = mini(current_wave + 1, max_wave)
	elapsed = 0.0
	final_wave_started = current_wave >= max_wave
	wave_started.emit(current_wave, _fibonacci(current_wave), str(BOSS_WAVES.get(current_wave, "")))

func _fibonacci(index: int) -> int:
	if index <= 2:
		return index
	var previous := 1
	var current := 2
	for i in range(3, index + 1):
		var next := previous + current
		previous = current
		current = next
	return current
