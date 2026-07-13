class_name GameAudioManager
extends Node

const POOL_SIZE := 16

const EVENT_STREAMS := {
	"bomb_place": [preload("res://assets/audio/kenney_impact/impactMetal_light_001.ogg")],
	"explosion": [preload("res://assets/audio/kenney_scifi/explosionCrunch_002.ogg")],
	"shield": [preload("res://assets/audio/kenney_scifi/forceField_000.ogg")],
	"hit": [preload("res://assets/audio/kenney_impact/impactPunch_heavy_001.ogg")],
	"stomp": [preload("res://assets/audio/kenney_impact/impactPunch_medium_000.ogg")],
	"crate_break": [preload("res://assets/audio/kenney_impact/impactWood_heavy_001.ogg")],
	"wall_break": [preload("res://assets/audio/kenney_impact/impactMining_002.ogg")],
	"boss_spawn": [preload("res://assets/audio/kenney_scifi/lowFrequency_explosion_000.ogg")],
	"thunder": [preload("res://assets/audio/kenney_scifi/lowFrequency_explosion_000.ogg")],
	"pickup": [preload("res://assets/audio/kenney_digital/powerUp4.ogg")],
	"down": [preload("res://assets/audio/kenney_digital/lowDown.ogg")],
	"ui_select": [preload("res://assets/audio/kenney_interface/select_001.wav")],
	"confirm": [preload("res://assets/audio/kenney_interface/confirmation_001.wav")],
	"footstep": [
		preload("res://assets/audio/kenney_impact/footstep_grass_000.ogg"),
		preload("res://assets/audio/kenney_impact/footstep_grass_001.ogg"),
		preload("res://assets/audio/kenney_impact/footstep_grass_002.ogg"),
	],
}

const EVENT_VOLUME_DB := {
	"bomb_place": -9.0,
	"explosion": -4.0,
	"shield": -7.0,
	"hit": -7.0,
	"stomp": -5.0,
	"crate_break": -5.0,
	"wall_break": -5.0,
	"boss_spawn": -3.0,
	"thunder": -5.0,
	"pickup": -7.0,
	"down": -8.0,
	"ui_select": -12.0,
	"confirm": -10.0,
	"footstep": -15.0,
}

const EVENT_PITCH_VARIANCE := {
	"bomb_place": 0.06,
	"explosion": 0.08,
	"hit": 0.06,
	"stomp": 0.04,
	"crate_break": 0.08,
	"wall_break": 0.06,
	"pickup": 0.04,
	"footstep": 0.08,
}

const EVENT_COOLDOWN := {
	"explosion": 0.045,
	"footstep": 0.07,
}

var played_events: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _last_played_at: Dictionary = {}

func setup(_game: Node) -> void:
	for index in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%02d" % index
		add_child(player)
		_players.append(player)

func play(event_id: String) -> bool:
	if not EVENT_STREAMS.has(event_id):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	var cooldown := float(EVENT_COOLDOWN.get(event_id, 0.0))
	if now - float(_last_played_at.get(event_id, -1000.0)) < cooldown:
		return false
	_last_played_at[event_id] = now

	var streams: Array = EVENT_STREAMS[event_id]
	var player := _available_player()
	player.stream = streams.pick_random() as AudioStream
	player.volume_db = float(EVENT_VOLUME_DB.get(event_id, -8.0))
	var variance := float(EVENT_PITCH_VARIANCE.get(event_id, 0.0))
	player.pitch_scale = randf_range(1.0 - variance, 1.0 + variance)
	player.play()
	played_events[event_id] = int(played_events.get(event_id, 0)) + 1
	return true

func event_stream(event_id: String) -> AudioStream:
	if not EVENT_STREAMS.has(event_id):
		return null
	var streams: Array = EVENT_STREAMS[event_id]
	return streams.front() as AudioStream if not streams.is_empty() else null

func _available_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	return player
