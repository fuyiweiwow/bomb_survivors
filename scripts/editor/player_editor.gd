extends Control

var current_gender := "male"
var start_speed := 5
var start_bombs := 1
var start_range := 2
var start_shields := 0
var preview_viewport: SubViewport = null
var preview_root: Node3D = null
var player_body: MeshInstance3D = null
var player_visor: MeshInstance3D = null
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
	content.custom_minimum_size = Vector2(700, 390)
	page.add_child(content)

	var controls_panel := PanelContainer.new()
	controls_panel.custom_minimum_size = Vector2(180, 390)
	content.add_child(controls_panel)

	var controls_margin := MarginContainer.new()
	controls_margin.add_theme_constant_override("margin_left", 14)
	controls_margin.add_theme_constant_override("margin_top", 14)
	controls_margin.add_theme_constant_override("margin_right", 14)
	controls_margin.add_theme_constant_override("margin_bottom", 14)
	controls_panel.add_child(controls_margin)

	var controls := VBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	controls_margin.add_child(controls)

	var gender_label := Label.new()
	gender_label.text = "Character"
	gender_label.add_theme_font_size_override("font_size", 22)
	gender_label.add_theme_color_override("font_color", Color.WHITE)
	gender_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(gender_label)

	var male_btn := Button.new()
	male_btn.text = "Blue Suit"
	male_btn.custom_minimum_size = Vector2(140, 36)
	male_btn.pressed.connect(func(): current_gender = "male"; _refresh_preview())
	controls.add_child(male_btn)

	var female_btn := Button.new()
	female_btn.text = "Red Suit"
	female_btn.custom_minimum_size = Vector2(140, 36)
	female_btn.pressed.connect(func(): current_gender = "female"; _refresh_preview())
	controls.add_child(female_btn)

	var hint := Label.new()
	hint.text = "Saved stats and suit style are used by the next match."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.custom_minimum_size = Vector2(150, 54)
	controls.add_child(hint)

	speed_spin = _add_stat_spin(controls, "Start Speed", start_speed, 1, 10)
	bombs_spin = _add_stat_spin(controls, "Start Bombs", start_bombs, 1, 8)
	range_spin = _add_stat_spin(controls, "Start Range", start_range, 1, 10)
	shields_spin = _add_stat_spin(controls, "Start Shields", start_shields, 0, 3)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(300, 390)
	content.add_child(preview_panel)

	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 10)
	preview_margin.add_theme_constant_override("margin_top", 10)
	preview_margin.add_theme_constant_override("margin_right", 10)
	preview_margin.add_theme_constant_override("margin_bottom", 10)
	preview_panel.add_child(preview_margin)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(280, 370)
	viewport_container.stretch = true
	preview_margin.add_child(viewport_container)

	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(280, 370)
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(preview_viewport)
	_build_preview_scene()

	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(180, 390)
	content.add_child(info_panel)

	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 14)
	info_margin.add_theme_constant_override("margin_top", 14)
	info_margin.add_theme_constant_override("margin_right", 14)
	info_margin.add_theme_constant_override("margin_bottom", 14)
	info_panel.add_child(info_margin)

	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 12)
	info_margin.add_child(info)

	var bomb_label := Label.new()
	bomb_label.text = "Bomb Style"
	bomb_label.add_theme_font_size_override("font_size", 22)
	bomb_label.add_theme_color_override("font_color", Color.WHITE)
	bomb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(bomb_label)

	var note := Label.new()
	note.text = "Powerups can raise speed, bomb count, blast range, or add a shield."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	note.custom_minimum_size = Vector2(150, 110)
	info.add_child(note)

func _add_action_buttons(parent: Node):
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	parent.add_child(actions)

	var save_btn := Button.new()
	save_btn.text = "保存"
	save_btn.custom_minimum_size = Vector2(150, 42)
	save_btn.pressed.connect(_save_player)
	actions.add_child(save_btn)

	var exit_btn := Button.new()
	exit_btn.text = "退出"
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

	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = 1.35
	capsule.radial_segments = 32
	capsule.rings = 10
	player_body = MeshInstance3D.new()
	player_body.mesh = capsule
	player_body.position = Vector3(0, 0.8, 0)
	preview_root.add_child(player_body)

	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.58, 0.14, 0.09)
	player_visor = MeshInstance3D.new()
	player_visor.mesh = visor_mesh
	player_visor.position = Vector3(0, 1.02, -0.40)
	player_visor.material_override = _make_mat(Color(0.02, 0.03, 0.04))
	preview_root.add_child(player_visor)

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
	if player_body == null:
		return
	if current_gender == "female":
		player_body.material_override = _make_mat(Color(0.95, 0.27, 0.22))
		player_body.scale = Vector3(0.90, 0.93, 0.90)
		player_visor.material_override = _make_mat(Color(1.0, 0.58, 0.25), true)
	else:
		player_body.material_override = _make_mat(Color(0.18, 0.48, 0.95))
		player_body.scale = Vector3.ONE
		player_visor.material_override = _make_mat(Color(0.2, 0.85, 1.0), true)

func _load_player():
	if not FileAccess.file_exists("user://player_config.json"):
		return
	var file := FileAccess.open("user://player_config.json", FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		current_gender = str(data.get("gender", current_gender))
		start_speed = clampi(int(data.get("start_speed", start_speed)), 1, 10)
		start_bombs = clampi(int(data.get("start_bombs", start_bombs)), 1, 8)
		start_range = clampi(int(data.get("start_range", start_range)), 1, 10)
		start_shields = clampi(int(data.get("start_shields", start_shields)), 0, 3)
	file.close()

func _save_player():
	var file := FileAccess.open("user://player_config.json", FileAccess.WRITE)
	if file:
		start_speed = int(speed_spin.value) if speed_spin else start_speed
		start_bombs = int(bombs_spin.value) if bombs_spin else start_bombs
		start_range = int(range_spin.value) if range_spin else start_range
		start_shields = int(shields_spin.value) if shields_spin else start_shields
		var data := {
			"gender": current_gender,
			"start_speed": start_speed,
			"start_bombs": start_bombs,
			"start_range": start_range,
			"start_shields": start_shields
		}
		file.store_string(JSON.stringify(data))
		file.close()
		print("Player saved!")
