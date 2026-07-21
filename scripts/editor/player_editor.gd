extends Control

const GAME_CONFIG_REPOSITORY_SCRIPT := preload("res://scripts/config/game_config_repository.gd")
const CUSTOMIZATION_STRATEGY := preload("res://scripts/character/player_customization_strategy.gd")
const PLAYER_VISUAL_FACTORY_SCRIPT := preload("res://scripts/character/player_visual_factory.gd")
const PREVIEW_ROTATE_STEP := PI / 8.0
const PREVIEW_DRAG_SENSITIVITY := 0.012

var config_repository: GameConfigRepository = GAME_CONFIG_REPOSITORY_SCRIPT.new()
var visual_factory: PlayerVisualFactory = PLAYER_VISUAL_FACTORY_SCRIPT.new()
var current_gender := "male"
var current_preset := "blue"
var current_body_type := "standard"
var current_body_color := "#2e7af2"
var current_visor_color := "#33d9ff"
var current_accent_color := "#ffffff"
var start_speed := 5
var start_bombs := 1
var start_range := 2
var start_shields := 0
var preview_viewport: SubViewport = null
var preview_root: Node3D = null
var preview_character_root: Node3D = null
var preview_yaw := PI
var preview_dragging := false
var preview_drag_last_x := 0.0
var preset_option: OptionButton = null
var body_type_option: OptionButton = null
var body_color_buttons: Array[Button] = []
var visor_color_buttons: Array[Button] = []
var accent_color_buttons: Array[Button] = []
var speed_spin: SpinBox = null
var bombs_spin: SpinBox = null
var range_spin: SpinBox = null
var shields_spin: SpinBox = null

var tex_bomb: Texture2D = load("res://assets/art/3d/bomb_shell.png")

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_player()
	_build_ui()
	_refresh_preview()

func _build_ui():
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var page := VBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)

	var title := Label.new()
	title.text = "Player Editor"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(620, 44)
	page.add_child(title)

	_add_action_buttons(page)

	var content := HBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 20)
	content.custom_minimum_size = Vector2(520, 390)
	page.add_child(content)

	var controls_panel := PanelContainer.new()
	controls_panel.custom_minimum_size = Vector2(220, 390)
	content.add_child(controls_panel)

	var controls_margin := MarginContainer.new()
	controls_margin.add_theme_constant_override("margin_left", 14)
	controls_margin.add_theme_constant_override("margin_top", 14)
	controls_margin.add_theme_constant_override("margin_right", 14)
	controls_margin.add_theme_constant_override("margin_bottom", 14)
	controls_panel.add_child(controls_margin)

	var controls_scroll := ScrollContainer.new()
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	controls_margin.add_child(controls_scroll)

	var controls := VBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_BEGIN
	controls.add_theme_constant_override("separation", 7)
	controls_scroll.add_child(controls)

	var gender_label := Label.new()
	gender_label.text = "Character"
	gender_label.add_theme_font_size_override("font_size", 22)
	gender_label.add_theme_color_override("font_color", Color.WHITE)
	gender_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(gender_label)

	preset_option = _add_option(controls, "Preset", CUSTOMIZATION_STRATEGY.PRESET_ORDER, current_preset, _on_preset_selected)
	body_type_option = _add_option(controls, "Body Type", CUSTOMIZATION_STRATEGY.BODY_TYPE_ORDER, current_body_type, _on_body_type_selected)
	_add_color_swatches(controls, "Suit Color", ["#2E7AF2", "#F24438", "#32C48D", "#F2A23A", "#965AF2", "#B96D3A"], "body")
	_add_color_swatches(controls, "Face Light", ["#33D9FF", "#FF9440", "#FFE66D", "#5BE7FF", "#F8F4E8", "#11151C"], "visor")
	_add_color_swatches(controls, "Accent", ["#FFFFFF", "#F24438", "#F2C94C", "#FF66A8", "#82F7FF", "#2E7AF2"], "accent")

	speed_spin = _add_stat_spin(controls, "Start Speed", start_speed, 1, Constants.MAX_SPEED)
	bombs_spin = _add_stat_spin(controls, "Start Bombs", start_bombs, 1, Constants.MAX_BOMB_CAPACITY)
	range_spin = _add_stat_spin(controls, "Start Range", start_range, 1, Constants.MAX_BOMB_RANGE)
	shields_spin = _add_stat_spin(controls, "Start Shields", start_shields, 0, Constants.MAX_START_SHIELDS)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(300, 390)
	content.add_child(preview_panel)

	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 10)
	preview_margin.add_theme_constant_override("margin_top", 10)
	preview_margin.add_theme_constant_override("margin_right", 10)
	preview_margin.add_theme_constant_override("margin_bottom", 10)
	preview_panel.add_child(preview_margin)

	var preview_layout := VBoxContainer.new()
	preview_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_layout.add_theme_constant_override("separation", 6)
	preview_margin.add_child(preview_layout)

	var rotate_controls := HBoxContainer.new()
	rotate_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	rotate_controls.add_theme_constant_override("separation", 8)
	preview_layout.add_child(rotate_controls)

	var rotate_left := Button.new()
	rotate_left.text = "<"
	rotate_left.custom_minimum_size = Vector2(44, 28)
	rotate_left.pressed.connect(func(): _rotate_preview(-PREVIEW_ROTATE_STEP))
	rotate_controls.add_child(rotate_left)

	var rotate_right := Button.new()
	rotate_right.text = ">"
	rotate_right.custom_minimum_size = Vector2(44, 28)
	rotate_right.pressed.connect(func(): _rotate_preview(PREVIEW_ROTATE_STEP))
	rotate_controls.add_child(rotate_right)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(280, 336)
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
	viewport_container.gui_input.connect(_on_preview_gui_input)
	preview_layout.add_child(viewport_container)

	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(280, 370)
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(preview_viewport)
	_build_preview_scene()

func _add_action_buttons(parent: Node):
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	parent.add_child(actions)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(150, 42)
	save_btn.pressed.connect(_save_player)
	actions.add_child(save_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Exit"
	exit_btn.custom_minimum_size = Vector2(150, 42)
	exit_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	actions.add_child(exit_btn)

func _add_stat_spin(parent: Node, label_text: String, value: int, min_value: int, max_value: int) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	parent.add_child(label)

	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 1
	spin.value = value
	spin.custom_minimum_size = Vector2(140, 30)
	parent.add_child(spin)
	return spin

func _add_option(parent: Node, label_text: String, values: Array, selected_value: String, callback: Callable) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	parent.add_child(label)

	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(160, 30)
	for value in values:
		var value_text := str(value)
		option.add_item(_display_label(value_text))
		option.set_item_metadata(option.get_item_count() - 1, value_text)
		if value_text == selected_value:
			option.select(option.get_item_count() - 1)
	option.item_selected.connect(callback)
	parent.add_child(option)
	return option

func _add_color_swatches(parent: Node, label_text: String, colors: Array[String], target: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	parent.add_child(label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	for color_hex in colors:
		var button := Button.new()
		button.text = ""
		button.custom_minimum_size = Vector2(22, 22)
		button.modulate = CUSTOMIZATION_STRATEGY.color_from_string(color_hex, Color.WHITE)
		button.pressed.connect(func(): _apply_color(color_hex, target))
		row.add_child(button)
		match target:
			"body": body_color_buttons.append(button)
			"visor": visor_color_buttons.append(button)
			"accent": accent_color_buttons.append(button)

func _display_label(value: String) -> String:
	if CUSTOMIZATION_STRATEGY.PRESETS.has(value):
		return CUSTOMIZATION_STRATEGY.preset_label(value)
	return value.capitalize()

func _build_preview_scene():
	if preview_viewport == null:
		return

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.09, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_energy = 1.0
	world.environment = env
	preview_viewport.add_child(world)

	var light := DirectionalLight3D.new()
	light.light_energy = 2.2
	light.rotation_degrees = Vector3(-48, -30, 0)
	preview_viewport.add_child(light)

	preview_root = Node3D.new()
	preview_viewport.add_child(preview_root)

	var bomb_mesh := SphereMesh.new()
	bomb_mesh.radius = 0.28
	bomb_mesh.height = 0.56
	bomb_mesh.radial_segments = 24
	bomb_mesh.rings = 12
	var bomb := MeshInstance3D.new()
	bomb.mesh = bomb_mesh
	bomb.position = Vector3(0.75, 0.3, 0.2)
	bomb.material_override = _make_mat(Color(0.75, 0.75, 0.78), false, tex_bomb)
	preview_root.add_child(bomb)

	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(2.8, 0.08, 2.1)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.position = Vector3(0, -0.04, 0)
	floor_node.material_override = _make_mat(Color(0.18, 0.24, 0.20))
	preview_root.add_child(floor_node)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.4
	cam.position = Vector3(0, 2.5, 4.0)
	cam.rotation_degrees = Vector3(-28, 0, 0)
	cam.current = true
	preview_viewport.add_child(cam)

func _make_mat(color: Color, emission := false, texture: Texture2D = null) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if texture:
		mat.albedo_texture = texture
	mat.roughness = 0.68
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.3
	return mat

func _refresh_preview():
	if preview_root == null:
		return
	var config := _current_visual_config()
	if is_instance_valid(preview_character_root):
		preview_character_root.queue_free()
	var material := visual_factory.material_from_config(config)
	var visual_data := visual_factory.create(0, Vector2i.ZERO, material, config)
	preview_character_root = visual_data["root"] as Node3D
	preview_character_root.position = Vector3.ZERO
	preview_root.add_child(preview_character_root)
	_apply_preview_rotation()

func _rotate_preview(amount: float) -> void:
	preview_yaw = wrapf(preview_yaw + amount, -PI, PI)
	_apply_preview_rotation()

func _apply_preview_rotation() -> void:
	if is_instance_valid(preview_character_root):
		preview_character_root.rotation.y = preview_yaw

func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			preview_dragging = mouse_button.pressed
			preview_drag_last_x = mouse_button.position.x
			accept_event()
	elif event is InputEventMouseMotion and preview_dragging:
		var motion := event as InputEventMouseMotion
		var delta_x := motion.position.x - preview_drag_last_x
		preview_drag_last_x = motion.position.x
		_rotate_preview(delta_x * PREVIEW_DRAG_SENSITIVITY)
		accept_event()

func _on_preset_selected(index: int) -> void:
	if preset_option == null:
		return
	var preset_id := str(preset_option.get_item_metadata(index))
	var preset := CUSTOMIZATION_STRATEGY.preset_data(preset_id)
	current_preset = preset_id
	current_gender = str(preset["gender"])
	current_body_type = str(preset["body_type"])
	current_body_color = str(preset["body_color"])
	current_visor_color = str(preset["visor_color"])
	current_accent_color = str(preset["accent_color"])
	_select_option_value(body_type_option, current_body_type)
	_refresh_preview()

func _on_body_type_selected(index: int) -> void:
	if body_type_option == null:
		return
	current_body_type = str(body_type_option.get_item_metadata(index))
	_refresh_preview()

func _apply_color(color_hex: String, target: String) -> void:
	match target:
		"body":
			current_body_color = CUSTOMIZATION_STRATEGY.normalized_color_string(color_hex, current_body_color)
		"visor":
			current_visor_color = CUSTOMIZATION_STRATEGY.normalized_color_string(color_hex, current_visor_color)
		"accent":
			current_accent_color = CUSTOMIZATION_STRATEGY.normalized_color_string(color_hex, current_accent_color)
	_refresh_preview()

func _select_option_value(option: OptionButton, value: String) -> void:
	if option == null:
		return
	for index in range(option.get_item_count()):
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			return

func _load_player():
	var config := config_repository.load_player_config()
	current_gender = str(config["gender"])
	current_preset = str(config["character_preset"])
	current_body_type = str(config["body_type"])
	current_body_color = str(config["body_color"])
	current_visor_color = str(config["visor_color"])
	current_accent_color = str(config["accent_color"])
	start_speed = int(config["start_speed"])
	start_bombs = int(config["start_bombs"])
	start_range = int(config["start_range"])
	start_shields = int(config["start_shields"])

func _save_player():
	start_speed = int(speed_spin.value) if speed_spin else start_speed
	start_bombs = int(bombs_spin.value) if bombs_spin else start_bombs
	start_range = int(range_spin.value) if range_spin else start_range
	start_shields = int(shields_spin.value) if shields_spin else start_shields
	var config := {
		"gender": current_gender,
		"character_preset": current_preset,
		"body_type": current_body_type,
		"body_color": current_body_color,
		"visor_color": current_visor_color,
		"accent_color": current_accent_color,
		"start_speed": start_speed,
		"start_bombs": start_bombs,
		"start_range": start_range,
		"start_shields": start_shields,
	}
	if config_repository.save_player_config(config):
		print("Player saved!")

func _current_visual_config() -> Dictionary:
	return {
		"gender": current_gender,
		"character_preset": current_preset,
		"body_type": current_body_type,
		"body_color": current_body_color,
		"visor_color": current_visor_color,
		"accent_color": current_accent_color,
	}
