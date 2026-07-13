class_name PlayerInputController
extends Node

signal action_requested(action: String)

# Long enough to preserve a quick turn request until the current grid step ends.
const INPUT_BUFFER_SECONDS := 0.38

const _ACTION_DIRECTIONS := {
	"p1_up": Vector2i.UP,
	"p1_down": Vector2i.DOWN,
	"p1_left": Vector2i.LEFT,
	"p1_right": Vector2i.RIGHT,
}

var _buffered_direction := Vector2i.ZERO
var _buffered_until := -1.0
var _pressed_sources: Dictionary = {}
var _direction_priority: Array[Vector2i] = []

func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)

func _process(_delta: float) -> void:
	_sync_action_sources()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	var keycode := key_event.physical_keycode
	if keycode == KEY_NONE:
		keycode = key_event.keycode
	var movement_direction := _direction_for_key(keycode)
	if movement_direction != Vector2i.ZERO:
		var source := StringName("key_%d" % int(keycode))
		if key_event.pressed:
			_set_source_pressed(source, movement_direction, true)
			if not key_event.echo:
				_buffer_direction(movement_direction)
		else:
			_set_source_released(source)
		return
	if not key_event.pressed or key_event.echo:
		return
	match keycode:
		KEY_SPACE: action_requested.emit("bomb")
		KEY_E: action_requested.emit("use_item")
		KEY_Q: action_requested.emit("cycle_item")
		KEY_1: action_requested.emit("select_item_0")
		KEY_2: action_requested.emit("select_item_1")
		KEY_3: action_requested.emit("select_item_2")
		KEY_ESCAPE: action_requested.emit("menu")
		KEY_R: action_requested.emit("restart")

# Returns held directions from newest to oldest. There is deliberately no
# acceleration, deceleration, or velocity carry-over in the input layer.
func read_move_direction() -> Vector2i:
	_sync_action_sources()
	var held := _held_directions_by_priority()
	return held[0] if not held.is_empty() else Vector2i.ZERO

# Returns one decision set for a grid step. A recently tapped direction is
# attempted first, followed by every direction that is still held. This lets
# blocked turns fall back to the previous held direction without adding inertia.
func consume_move_candidates() -> Array[Vector2i]:
	_sync_action_sources()
	var candidates: Array[Vector2i] = []
	var buffered := consume_buffered_direction()
	if buffered != Vector2i.ZERO:
		candidates.append(buffered)
	for direction in _held_directions_by_priority():
		if not candidates.has(direction):
			candidates.append(direction)
	return candidates

func consume_buffered_direction() -> Vector2i:
	if Time.get_ticks_msec() / 1000.0 > _buffered_until:
		_clear_buffer()
		return Vector2i.ZERO
	var result := _buffered_direction
	_clear_buffer()
	return result

func _buffer_direction(direction: Vector2i) -> void:
	_buffered_direction = direction
	_buffered_until = Time.get_ticks_msec() / 1000.0 + INPUT_BUFFER_SECONDS

func _clear_buffer() -> void:
	_buffered_direction = Vector2i.ZERO
	_buffered_until = -1.0

func _sync_action_sources() -> void:
	for action_name in _ACTION_DIRECTIONS:
		var source := StringName("action_%s" % action_name)
		var direction: Vector2i = _ACTION_DIRECTIONS[action_name]
		if Input.is_action_pressed(action_name):
			# Keyboard events already provide the exact press order. Only promote
			# an action source when it is the first source holding this direction.
			_set_source_pressed(source, direction, not _direction_is_held(direction))
		else:
			_set_source_released(source)

func _set_source_pressed(source: StringName, direction: Vector2i, promote: bool) -> void:
	var already_pressed := _pressed_sources.has(source)
	var previous_direction: Vector2i = _pressed_sources.get(source, Vector2i.ZERO)
	if already_pressed and previous_direction == direction:
		return
	if already_pressed:
		_pressed_sources.erase(source)
		_remove_priority_if_released(previous_direction)
	_pressed_sources[source] = direction
	if promote:
		_promote_direction(direction)
	elif not _direction_priority.has(direction):
		_direction_priority.append(direction)

func _set_source_released(source: StringName) -> void:
	if not _pressed_sources.has(source):
		return
	var direction: Vector2i = _pressed_sources[source]
	_pressed_sources.erase(source)
	_remove_priority_if_released(direction)

func _promote_direction(direction: Vector2i) -> void:
	_direction_priority.erase(direction)
	_direction_priority.append(direction)

func _remove_priority_if_released(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO or _direction_is_held(direction):
		return
	_direction_priority.erase(direction)

func _direction_is_held(direction: Vector2i) -> bool:
	for held_direction in _pressed_sources.values():
		if held_direction == direction:
			return true
	return false

func _held_directions_by_priority() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index in range(_direction_priority.size() - 1, -1, -1):
		var direction := _direction_priority[index]
		if _direction_is_held(direction):
			result.append(direction)
	return result

func _direction_for_key(keycode: Key) -> Vector2i:
	match keycode:
		KEY_W, KEY_UP: return Vector2i.UP
		KEY_S, KEY_DOWN: return Vector2i.DOWN
		KEY_A, KEY_LEFT: return Vector2i.LEFT
		KEY_D, KEY_RIGHT: return Vector2i.RIGHT
	return Vector2i.ZERO
