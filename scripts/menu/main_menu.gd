extends Control

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var label := Label.new()
	label.text = "泡泡堂 Demo"
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(520, 80)
	box.add_child(label)

	var ver := Label.new()
	ver.text = "Single Player vs AI"
	ver.add_theme_font_size_override("font_size", 24)
	ver.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.custom_minimum_size = Vector2(520, 40)
	box.add_child(ver)

	_add_button(box, "Start Game", func():
		get_tree().change_scene_to_file("res://scenes/game/main_3d.tscn")
	)

	_add_button(box, "Map Editor", func():
		get_tree().change_scene_to_file("res://scenes/editor/map_editor.tscn")
	)

	_add_button(box, "Player Editor", func():
		get_tree().change_scene_to_file("res://scenes/editor/player_editor.tscn")
	)

	_add_button(box, "Exit", func():
		get_tree().quit()
	)

func _add_button(parent: Node, text: String, callback: Callable):
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 50)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(callback)
	parent.add_child(btn)
