extends Control

var current_gender := "male"
var current_head := 0
var preview_sprites: Array = []

var tex_male_head = preload("res://assets/art/sprites/male_head.png")
var tex_male_body = preload("res://assets/art/sprites/male_body.png")
var tex_male_legs = preload("res://assets/art/sprites/male_legs.png")
var tex_female_head = preload("res://assets/art/sprites/female_head.png")
var tex_female_body = preload("res://assets/art/sprites/female_body.png")
var tex_female_legs = preload("res://assets/art/sprites/female_legs.png")

func _ready():
	var title := Label.new()
	title.text = "Player Editor"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(100, 40)
	title.size = Vector2(600, 60)
	add_child(title)

	# preview area
	var preview_bg := ColorRect.new()
	preview_bg.color = Color(0.1, 0.1, 0.1)
	preview_bg.position = Vector2(300, 140)
	preview_bg.size = Vector2(200, 300)
	add_child(preview_bg)

	_refresh_preview()

	# gender switch
	var male_btn := Button.new()
	male_btn.text = "Male"
	male_btn.position = Vector2(100, 160)
	male_btn.size = Vector2(120, 40)
	male_btn.pressed.connect(func(): current_gender = "male"; _refresh_preview())
	add_child(male_btn)

	var female_btn := Button.new()
	female_btn.text = "Female"
	female_btn.position = Vector2(100, 220)
	female_btn.size = Vector2(120, 40)
	female_btn.pressed.connect(func(): current_gender = "female"; _refresh_preview())
	add_child(female_btn)

	# bomb preview
	var bomb_label := Label.new()
	bomb_label.text = "Bomb Preview"
	bomb_label.add_theme_font_size_override("font_size", 24)
	bomb_label.add_theme_color_override("font_color", Color.WHITE)
	bomb_label.position = Vector2(100, 300)
	bomb_label.size = Vector2(200, 30)
	add_child(bomb_label)

	var bomb_sprite := Sprite2D.new()
	bomb_sprite.texture = preload("res://assets/art/sprites/bomb.png")
	bomb_sprite.position = Vector2(160, 380)
	bomb_sprite.centered = true
	bomb_sprite.scale = Vector2(2, 2)
	add_child(bomb_sprite)

	var info := Label.new()
	info.text = "Head + Body + Legs parts swap support."
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	info.position = Vector2(100, 430)
	info.size = Vector2(600, 30)
	add_child(info)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.position = Vector2(350, 480)
	back_btn.size = Vector2(120, 40)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	add_child(back_btn)

func _refresh_preview():
	for s in preview_sprites:
		if is_instance_valid(s): s.queue_free()
	preview_sprites.clear()

	var head_tex = tex_male_head if current_gender == "male" else tex_female_head
	var body_tex = tex_male_body if current_gender == "male" else tex_female_body
	var legs_tex = tex_male_legs if current_gender == "male" else tex_female_legs

	var center := Vector2(400, 290)

	var head_s := Sprite2D.new()
	head_s.texture = head_tex
	head_s.position = center + Vector2(0, -16)
	head_s.centered = true
	head_s.scale = Vector2(2, 2)
	add_child(head_s)
	preview_sprites.append(head_s)

	var body_s := Sprite2D.new()
	body_s.texture = body_tex
	body_s.position = center + Vector2(0, 0)
	body_s.centered = true
	body_s.scale = Vector2(2, 2)
	add_child(body_s)
	preview_sprites.append(body_s)

	var legs_s := Sprite2D.new()
	legs_s.texture = legs_tex
	legs_s.position = center + Vector2(0, 16)
	legs_s.centered = true
	legs_s.scale = Vector2(2, 2)
	add_child(legs_s)
	preview_sprites.append(legs_s)
