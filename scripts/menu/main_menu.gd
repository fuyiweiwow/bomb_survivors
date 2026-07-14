extends Control

const GAME_GUIDE_OVERLAY := preload("res://scripts/menu/game_guide_overlay.gd")
const GAME_CONFIG_REPOSITORY_SCRIPT := preload("res://scripts/config/game_config_repository.gd")

var config_repository: GameConfigRepository = GAME_CONFIG_REPOSITORY_SCRIPT.new()
var difficulty_option: OptionButton = null
var difficulty_ids := ["easy", "normal", "hard"]
var guide_button: Button = null
var guide_overlay = null

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size.x = 420
	center.add_child(box)

	var label := Label.new()
	label.text = "Demo"
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(420, 80)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(label)

	var ver := Label.new()
	ver.text = "Single Player vs AI"
	ver.add_theme_font_size_override("font_size", 24)
	ver.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.custom_minimum_size = Vector2(420, 40)
	ver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	guide_button = _add_button(box, "Game Guide", _show_guide)

	_add_difficulty_picker(box)

	_add_button(box, "Exit", func():
		get_tree().quit()
	)
	_create_guide_overlay()

func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 50)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

func _create_guide_overlay() -> void:
	guide_overlay = GAME_GUIDE_OVERLAY.new()
	add_child(guide_overlay)
	guide_overlay.closed.connect(func(): guide_button.grab_focus())

func _show_guide() -> void:
	guide_overlay.open()

func _hide_guide() -> void:
	guide_overlay.close()

func _add_difficulty_picker(parent: Node):
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(row)

	var label := Label.new()
	label.text = "AI"
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	row.add_child(label)

	difficulty_option = OptionButton.new()
	difficulty_option.custom_minimum_size = Vector2(210, 42)
	difficulty_option.alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	return config_repository.load_ai_difficulty()

func _save_ai_difficulty(value: String) -> void:
	config_repository.save_ai_difficulty(value)
