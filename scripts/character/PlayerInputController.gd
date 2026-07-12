class_name PlayerInputController
extends Node

signal action_requested(action: String)
signal movement_released

func _ready() -> void:
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed and key_event.physical_keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
		movement_released.emit()
		return
	if not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_SPACE: action_requested.emit("bomb")
		KEY_E: action_requested.emit("use_item")
		KEY_Q: action_requested.emit("cycle_item")
		KEY_ESCAPE: action_requested.emit("menu")
		KEY_R: action_requested.emit("restart")

func read_move_direction() -> Vector2i:
	var direction := Vector2i.ZERO
	if Input.is_action_pressed("p1_up"):
		direction.y -= 1
	if Input.is_action_pressed("p1_down"):
		direction.y += 1
	if Input.is_action_pressed("p1_left"):
		direction.x -= 1
	if Input.is_action_pressed("p1_right"):
		direction.x += 1
	if direction.x != 0:
		direction.y = 0
	return direction
