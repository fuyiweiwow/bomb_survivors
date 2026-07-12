class_name PlayerInputController
extends Node

signal action_requested(action: String)

const INPUT_BUFFER_SECONDS := 0.10

var _buffered_direction := Vector2i.ZERO
var _buffered_until := -1.0

func _ready() -> void:
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var movement_direction := _direction_for_key(key_event.physical_keycode)
	if movement_direction != Vector2i.ZERO:
		_buffered_direction = movement_direction
		_buffered_until = Time.get_ticks_msec() / 1000.0 + INPUT_BUFFER_SECONDS
		return
	match key_event.physical_keycode:
		KEY_SPACE: action_requested.emit("bomb")
		KEY_E: action_requested.emit("use_item")
		KEY_Q: action_requested.emit("cycle_item")
		KEY_ESCAPE: action_requested.emit("menu")
		KEY_R: action_requested.emit("restart")

func read_move_direction() -> Vector2i:
	var direction := Vector2i.ZERO
	if Input.is_action_pressed("p1_up") or Input.is_key_pressed(KEY_UP):
		direction.y -= 1
	if Input.is_action_pressed("p1_down") or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1
	if Input.is_action_pressed("p1_left") or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_action_pressed("p1_right") or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1
	if direction.x != 0:
		direction.y = 0
	return direction

func consume_buffered_direction() -> Vector2i:
	if Time.get_ticks_msec() / 1000.0 > _buffered_until:
		_buffered_direction = Vector2i.ZERO
		return Vector2i.ZERO
	var result := _buffered_direction
	_buffered_direction = Vector2i.ZERO
	_buffered_until = -1.0
	return result

func _direction_for_key(keycode: Key) -> Vector2i:
	match keycode:
		KEY_W, KEY_UP: return Vector2i.UP
		KEY_S, KEY_DOWN: return Vector2i.DOWN
		KEY_A, KEY_LEFT: return Vector2i.LEFT
		KEY_D, KEY_RIGHT: return Vector2i.RIGHT
	return Vector2i.ZERO
