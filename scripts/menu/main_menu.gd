extends Control

var difficulty_option: OptionButton = null
var difficulty_ids := ["easy", "normal", "hard"]

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

	_add_difficulty_picker(box)

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

func _add_difficulty_picker(parent: Node):
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label := Label.new()
	label.text = "AI"
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	row.add_child(label)

	difficulty_option = OptionButton.new()
	difficulty_option.custom_minimum_size = Vector2(210, 42)
	difficulty_option.add_theme_font_size_override("font_size", 20)
	difficulty_option.add_item("Easy", 0)
	difficulty_option.add_item("Normal", 1)
	difficulty_option.add_item("Hard", 2)
	difficulty_option.selected = difficulty_ids.find(_load_ai_difficulty())
	if difficulty_option.selected < 0:
		difficulty_option.selected = 1
	difficulty_option.item_selected.connect(func(index): _save_ai_difficulty(difficulty_ids[index]))
	row.add_child(difficulty_option)

func _load_ai_difficulty() -> String:
	if not FileAccess.file_exists("user://ai_settings.json"):
		return "normal"
	var file := FileAccess.open("user://ai_settings.json", FileAccess.READ)
	if file == null:
		return "normal"
	var result := "normal"
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		result = str(data.get("difficulty", "normal"))
	file.close()
	if not difficulty_ids.has(result):
		result = "normal"
	return result

func _save_ai_difficulty(value: String):
	var file := FileAccess.open("user://ai_settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"difficulty": value}))
		file.close()
