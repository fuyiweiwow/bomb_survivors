extends Node

const GAME_HUD_SCRIPT := preload("res://scripts/ui/game_hud.gd")

var _game: Node
var game_camera: Camera3D = null
var weather_visuals := Node3D.new()

func setup(game_manager: Node):
	_game = game_manager

func setup_camera():
	game_camera = Camera3D.new()
	game_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game_camera.size = 30.0
	game_camera.position = Vector3(0, 16, 12)
	game_camera.rotation_degrees = Vector3(-58, 0, 0)
	game_camera.current = true
	_game.add_child(game_camera)
	weather_visuals.name = "WeatherVisuals"
	_game.add_child(weather_visuals)

func setup_hud():
	_game.game_hud = GAME_HUD_SCRIPT.new()
	_game.add_child(_game.game_hud)
	update_hud()

func update_hud():
	if _game.game_hud == null or _game.character_registry.is_empty():
		return
	var characters: Array[CharacterQuery] = _game.character_registry.queries()
	var wave_number := 0
	var max_wave := 7
	var wave_time := 0.0
	var weather_text := "Clear"
	if _game.wave_manager:
		wave_number = int(_game.wave_manager.current_wave)
		max_wave = int(_game.wave_manager.max_wave)
		wave_time = float(_game.wave_manager.time_remaining())
	if _game.weather_manager:
		weather_text = str(_game.weather_manager.display_name())
	_game.game_hud.update_display(
		characters,
		wave_number,
		max_wave,
		wave_time,
		weather_text,
		_difficulty_label(),
		game_camera,
		Callable(_game.powerup_manager, "item_display_name")
	)

func show_result(winner_id: int):
	_game.audio_manager.play("confirm" if winner_id == 1 else "down")
	var layer := CanvasLayer.new()
	_game.add_child(layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 250)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var label := Label.new()
	if winner_id == 0:
		label.text = "Draw!"
	elif winner_id == 1:
		label.text = "You Win!"
	else:
		label.text = "AI Wins!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.YELLOW)
	box.add_child(label)

	var hint := Label.new()
	hint.text = "Choose your next move"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	box.add_child(hint)

	var restart_btn := _make_result_button("Restart (R)")
	restart_btn.pressed.connect(func(): _game.get_tree().reload_current_scene())
	box.add_child(restart_btn)

	var return_label := "World Map (Esc)" if _game.is_level_run() else "Main Menu (Esc)"
	var menu_btn := _make_result_button(return_label)
	menu_btn.pressed.connect(func(): _game.get_tree().change_scene_to_file(_game.return_scene_path()))
	box.add_child(menu_btn)

	var quit_btn := _make_result_button("Quit Game (Q)")
	quit_btn.pressed.connect(func(): _game.get_tree().quit())
	box.add_child(quit_btn)

func flash_boss_spawn():
	var layer := CanvasLayer.new()
	layer.layer = 90
	_game.add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(0.85, 0.02, 0.01, 0.34)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	var tween := create_tween().bind_node(layer)
	tween.tween_property(flash, "color:a", 0.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(layer.queue_free)

func update_weather_visibility():
	if _game.character_registry.is_empty() or not _game.weather_manager:
		return
	var player_state := _game.character_registry.state_at(0) as CharacterState
	for i in range(1, _game.character_registry.count()):
		var state := _game.character_registry.state_at(i) as CharacterState
		var character_node := state.node() if state != null else null
		if character_node != null:
			character_node.visible = (
				state.is_alive()
				and not state.is_hidden_in(_game.map_state)
				and player_state != null
				and _game.weather_manager.can_see(player_state.cell(), state.cell())
			)

func on_weather_changed(weather_type: String):
	for child in weather_visuals.get_children():
		child.queue_free()
	if _game.world_environment:
		_game.world_environment.fog_enabled = weather_type == "fog"
		_game.world_environment.fog_light_color = Color(0.38, 0.43, 0.46)
		_game.world_environment.fog_density = 0.012 if weather_type == "fog" else 0.0
		_game.world_environment.background_color = Color(0.055, 0.065, 0.08) if weather_type in ["rain", "thunder"] else Color(0.07, 0.09, 0.12)
	match weather_type:
		"rain":
			_create_rain_visuals()
		"wind":
			_create_wind_visuals()
		"snow":
			_create_snow_visuals()

func request_thunder_strike():
	var cells: Array = _game.grid_manager.walkable_cells()
	if cells.is_empty():
		return
	var cell := cells.pick_random() as Vector2i
	var warning := MeshHelpers.cylinder(Constants.TILE_SIZE * 0.40, 0.04, MeshHelpers.make_mat(Color(1.0, 0.82, 0.12), true))
	warning.position = Constants.grid_to_world(cell) + Vector3(0, 0.10, 0)
	weather_visuals.add_child(warning)
	var tw := create_tween().bind_node(warning)
	tw.tween_property(warning, "scale", Vector3(1.4, 1.0, 1.4), 0.35)
	tw.tween_property(warning, "scale", Vector3(0.75, 1.0, 0.75), 0.30)
	tw.tween_callback(func(): _strike_thunder(cell, warning))

func _strike_thunder(cell: Vector2i, warning: Node3D):
	_game.audio_manager.play("thunder")
	if is_instance_valid(warning):
		warning.queue_free()
	var bolt := MeshHelpers.box(Vector3(0.18, 7.0, 0.18), MeshHelpers.make_mat(Color(0.75, 0.90, 1.0), true))
	bolt.position = Constants.grid_to_world(cell) + Vector3(0, 3.5, 0)
	weather_visuals.add_child(bolt)
	var tw := create_tween().bind_node(bolt)
	tw.tween_property(bolt, "transparency", 1.0, 0.22)
	tw.tween_callback(bolt.queue_free)
	for i in range(_game.character_registry.count()):
		var state := _game.character_registry.state_at(i) as CharacterState
		if (
			state != null
			and state.is_alive()
			and _game.combat_manager.is_player_in_attack_cells(
				state,
				[cell],
				Constants.GROUND_ATTACK_MIN_HEIGHT,
				Constants.AERIAL_ATTACK_MAX_HEIGHT
			)
		):
			_game.combat_manager.damage_player(i, 1, "thunder")

func _difficulty_label() -> String:
	match _game.ai_difficulty:
		"easy":
			return "Easy"
		"hard":
			return "Hard"
		_:
			return "Normal"

func _make_result_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 34)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 18)
	return btn

func _create_rain_visuals():
	var rain_mat := MeshHelpers.make_mat(Color(0.55, 0.82, 1.0, 0.62), true)
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_mat.no_depth_test = true
	var extents := _map_half_extents()
	var drop_count := mini(40, maxi(28, roundi(float(Constants.LEGACY_GRID_W * Constants.LEGACY_GRID_H) * 0.14)))
	for i in range(drop_count):
		var drop := MeshHelpers.box(Vector3(0.04, 0.85, 0.04), rain_mat)
		var start_y := randf_range(5.0, 8.5)
		drop.position = Vector3(randf_range(-extents.x, extents.x), start_y, randf_range(-extents.y, extents.y))
		weather_visuals.add_child(drop)
		var tw := create_tween().bind_node(drop).set_loops()
		tw.tween_property(drop, "position:y", -0.1, randf_range(1.20, 1.70)).from(start_y)

	var splash_mat := MeshHelpers.make_mat(Color(0.42, 0.72, 0.95, 0.46), true)
	splash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	splash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var splash_cells: Array = _game.grid_manager.walkable_cells()
	splash_cells.shuffle()
	for i in range(mini(10, splash_cells.size())):
		var splash := MeshHelpers.cylinder(0.11, 0.025, splash_mat)
		var cell := splash_cells[i] as Vector2i
		splash.position = Constants.grid_to_world(cell) + Vector3(randf_range(-0.38, 0.38), 0.10, randf_range(-0.38, 0.38))
		weather_visuals.add_child(splash)
		var splash_tween := create_tween().bind_node(splash).set_loops().set_parallel()
		splash_tween.tween_property(splash, "scale", Vector3(2.2, 1.0, 2.2), 0.80).from(Vector3(0.45, 1.0, 0.45))
		splash_tween.tween_property(splash, "transparency", 0.88, 0.80).from(0.10)

func _create_wind_visuals():
	var wind_mat := MeshHelpers.make_mat(Color(0.72, 0.92, 0.94, 0.48), true)
	wind_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wind_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wind_mat.no_depth_test = true
	var dir3 := Vector3(_game.weather_manager.wind_direction.x, 0, _game.weather_manager.wind_direction.y)
	var extents := _map_half_extents()
	var streak_count := mini(14, maxi(10, roundi(float(Constants.LEGACY_GRID_W * Constants.LEGACY_GRID_H) * 0.05)))
	for i in range(streak_count):
		var streak := MeshHelpers.box(Vector3(0.7 if dir3.x != 0 else 0.04, 0.035, 0.7 if dir3.z != 0 else 0.04), wind_mat)
		streak.position = Vector3(randf_range(-extents.x, extents.x), randf_range(0.6, 1.8), randf_range(-extents.y, extents.y))
		weather_visuals.add_child(streak)
		var tw := create_tween().bind_node(streak).set_loops()
		tw.tween_property(streak, "position", streak.position + dir3 * 3.5, 1.15).from(streak.position - dir3 * 3.5)

func _create_snow_visuals():
	var snow_mat := MeshHelpers.make_mat(Color(0.68, 0.86, 0.96, 0.34))
	snow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	snow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for raw_cell in _game.weather_manager.snow_cells.keys():
		var cell := raw_cell as Vector2i
		var patch := MeshHelpers.box(Vector3(Constants.TILE_SIZE * 0.76, 0.035, Constants.TILE_SIZE * 0.76), snow_mat)
		patch.position = Constants.grid_to_world(cell) + Vector3(0, 0.055, 0)
		weather_visuals.add_child(patch)

func _map_half_extents() -> Vector2:
	return Vector2(
		float(Constants.GRID_W) * Constants.TILE_SIZE * 0.5,
		float(Constants.GRID_H) * Constants.TILE_SIZE * 0.5
	)
