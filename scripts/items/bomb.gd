extends Node2D

const TILE_SIZE = 32
const FUSE_TIME = 2.5

var grid_pos := Vector2i.ZERO
var blast_range := 2

@onready var sprite: Sprite2D = $Sprite2D
@onready var timer: Timer = $Timer
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var _game_node = null
func _gm():
	if _game_node == null:
		_game_node = get_tree().get_first_node_in_group("game")
	return _game_node

func setup(pos: Vector2i, brange: int):
	grid_pos = pos
	blast_range = brange
	position = Vector2(pos.x * TILE_SIZE + TILE_SIZE / 2.0, pos.y * TILE_SIZE + TILE_SIZE / 2.0)

func _ready():
	sprite.texture = preload("res://assets/art/sprites/bomb.png")
	_create_blink_anim()

	timer.wait_time = FUSE_TIME
	timer.timeout.connect(_explode)
	timer.start()

func _create_blink_anim():
	var lib := AnimationLibrary.new()
	var anim := Animation.new()
	anim.length = 2.5
	anim.loop_mode = Animation.LOOP_LINEAR
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, ".:modulate")
	anim.track_insert_key(track, 0.0, Color.WHITE)
	anim.track_insert_key(track, 0.35, Color.RED)
	anim.track_insert_key(track, 0.7, Color.WHITE)
	anim.track_insert_key(track, 1.05, Color.RED)
	anim.track_insert_key(track, 1.4, Color.WHITE)
	anim.track_insert_key(track, 1.75, Color.RED)
	anim.track_insert_key(track, 2.1, Color.WHITE)
	anim.track_insert_key(track, 2.45, Color.RED)
	lib.add_animation("blink", anim)
	anim_player.add_animation_library("", lib)
	anim_player.play("blink")

func _explode():
	var gm = _gm()
	if gm:
		gm.unregister_bomb(grid_pos, self)
		var results = gm.get_explosion_cells(grid_pos, blast_range)
		_spawn_vfx(results)
		gm.apply_explosion_damage(results["cells"])
	queue_free()

func _spawn_vfx(results: Dictionary):
	var tex_c := preload("res://assets/art/sprites/explosion_center.png")
	var tex_a := preload("res://assets/art/sprites/explosion_arm.png")
	var tex_t := preload("res://assets/art/sprites/explosion_tip.png")

	var parent := get_parent()

	for cell in results["cells"]:
		var c := cell as Vector2i
		var is_center = c.x == grid_pos.x and c.y == grid_pos.y
		var tex = tex_c if is_center else tex_a

		var s := Sprite2D.new()
		s.texture = tex
		s.position = Vector2(c.x * TILE_SIZE + TILE_SIZE / 2.0, c.y * TILE_SIZE + TILE_SIZE / 2.0)
		s.centered = true
		s.scale = Vector2(0.35, 0.35)
		s.z_index = 10
		parent.add_child(s)

		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "scale", Vector2.ONE, 0.1)
		tw.tween_property(s, "modulate:a", 0.0, 0.4).set_delay(0.25)
		tw.tween_callback(s.queue_free).set_delay(0.5)

	for dir in results["tips"]:
		var cell = results["tips"][dir] as Vector2i
		var s2 := Sprite2D.new()
		s2.texture = tex_t
		s2.position = Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)
		s2.centered = true
		s2.scale = Vector2(0.35, 0.35)
		s2.z_index = 10
		match dir:
			"up": s2.rotation_degrees = -90
			"down": s2.rotation_degrees = 90
			"left": s2.rotation_degrees = 180
		parent.add_child(s2)

		var tw2 := s2.create_tween().set_parallel(true)
		tw2.tween_property(s2, "scale", Vector2.ONE, 0.1)
		tw2.tween_property(s2, "modulate:a", 0.0, 0.4).set_delay(0.25)
		tw2.tween_callback(s2.queue_free).set_delay(0.5)
