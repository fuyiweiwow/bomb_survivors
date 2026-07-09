extends Control

func _ready():
	var label := Label.new()
	label.text = "泡泡堂 Demo"
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(100, 100)
	label.size = Vector2(600, 80)
	add_child(label)

	var ver := Label.new()
	ver.text = "Single Player vs AI"
	ver.add_theme_font_size_override("font_size", 24)
	ver.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.position = Vector2(150, 180)
	ver.size = Vector2(500, 40)
	add_child(ver)

	_add_button("Start Game", Vector2(250, 260), func():
		get_tree().change_scene_to_file("res://scenes/game/main.tscn")
	)

	_add_button("Map Editor", Vector2(250, 330), func():
		get_tree().change_scene_to_file("res://scenes/editor/map_editor.tscn")
	)

	_add_button("Player Editor", Vector2(250, 400), func():
		get_tree().change_scene_to_file("res://scenes/editor/player_editor.tscn")
	)

	_add_button("Exit", Vector2(250, 470), func():
		get_tree().quit()
	)

func _add_button(text: String, pos: Vector2, callback: Callable):
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = Vector2(300, 50)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(callback)
	add_child(btn)
