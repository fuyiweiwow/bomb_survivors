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
	if _game.game_hud == null or _game.players.is_empty():
		return
	var wave_number := 0
	var wave_time := 0.0
	var weather_text := "Clear"
	if _game.wave_manager:
		wave_number = int(_game.wave_manager.current_wave)
		wave_time = float(_game.wave_manager.time_remaining())
	if _game.weather_manager:
		weather_text = str(_game.weather_manager.display_name())
	_game.game_hud.update_display(
		_game.players,
		wave_number,
		wave_time,
		weather_text,
		_difficulty_label(),
		game_camera,
		_item_display_name
	)

func show_result(winner_id: int):
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
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.YELLOW)
	box.add_child(label)

	var hint := Label.new()
	hint.text = "Choose your next move"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	box.add_child(hint)

	var restart_btn := _make_result_button("Restart (R)")
	restart_btn.pressed.connect(func(): _game.get_tree().reload_current_scene())
	box.add_child(restart_btn)

	var menu_btn := _make_result_button("Main Menu (Esc)")
	menu_btn.pressed.connect(func(): _game.get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
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
	if _game.players.is_empty() or not _game.weather_manager:
		return
	for i in range(1, _game.players.size()):
		var p: Dictionary = _game.players[i]
		var node = p.get("node")
		if is_instance_valid(node):
			(node as Node3D).visible = (
				p["alive"]
				and not Constants.is_player_hidden(_game.players, i, _game.grid)
				and _game.weather_manager.can_see(_game.players[0]["grid_pos"], p["grid_pos"])
			)

func on_weather_changed(weather_type: String):
	for child in weather_visuals.get_children():
		child.queue_free()
	if _game.world_environment:
		_game.world_environment.fog_enabled = weather_type == "fog"
		_game.world_environment.fog_light_color = Color(0.66, 0.70, 0.72)
		_game.world_environment.fog_density = 0.075 if weather_type == "fog" else 0.0
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
	var warning := MeshHelpers.cylinder(0.58, 0.04, MeshHelpers.make_mat(Color(1.0, 0.82, 0.12), true))
	warning.position = Constants.grid_to_world(cell) + Vector3(0, 0.10, 0)
	weather_visuals.add_child(warning)
	var tw := create_tween().bind_node(warning)
	tw.tween_property(warning, "scale", Vector3(1.4, 1.0, 1.4), 0.35)
	tw.tween_property(warning, "scale", Vector3(0.75, 1.0, 0.75), 0.30)
	tw.tween_callback(func(): _strike_thunder(cell, warning))

func _strike_thunder(cell: Vector2i, warning: Node3D):
	if is_instance_valid(warning):
		warning.queue_free()
	var bolt := MeshHelpers.box(Vector3(0.18, 7.0, 0.18), MeshHelpers.make_mat(Color(0.75, 0.90, 1.0), true))
	bolt.position = Constants.grid_to_world(cell) + Vector3(0, 3.5, 0)
	weather_visuals.add_child(bolt)
	var tw := create_tween().bind_node(bolt)
	tw.tween_property(bolt, "transparency", 1.0, 0.22)
	tw.tween_callback(bolt.queue_free)
	for i in range(_game.players.size()):
		if _game.players[i]["alive"] and _game.players[i]["grid_pos"] == cell:
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
	btn.add_theme_font_size_override("font_size", 18)
	return btn

func _create_rain_visuals():
	var rain_mat := MeshHelpers.make_mat(Color(0.35, 0.68, 0.92), true)
	for i in range(36):
		var drop := MeshHelpers.box(Vector3(0.025, 0.65, 0.025), rain_mat)
		drop.position = Vector3(randf_range(-11.0, 11.0), randf_range(2.0, 8.0), randf_range(-7.5, 7.5))
		weather_visuals.add_child(drop)
		var tw := create_tween().bind_node(drop).set_loops()
		tw.tween_property(drop, "position:y", -0.1, randf_range(0.55, 0.90)).from(8.0)

func _create_wind_visuals():
	var wind_mat := MeshHelpers.make_mat(Color(0.72, 0.92, 0.94), true)
	var dir3 := Vector3(_game.weather_manager.wind_direction.x, 0, _game.weather_manager.wind_direction.y)
	for i in range(12):
		var streak := MeshHelpers.box(Vector3(0.7 if dir3.x != 0 else 0.04, 0.035, 0.7 if dir3.z != 0 else 0.04), wind_mat)
		streak.position = Vector3(randf_range(-10.0, 10.0), randf_range(0.6, 1.8), randf_range(-7.0, 7.0))
		weather_visuals.add_child(streak)
		var tw := create_tween().bind_node(streak).set_loops()
		tw.tween_property(streak, "position", streak.position + dir3 * 4.0, 1.2).from(streak.position - dir3 * 4.0)

func _create_snow_visuals():
	var snow_mat := MeshHelpers.make_mat(Color(0.68, 0.86, 0.96, 0.48))
	snow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	snow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for raw_cell in _game.weather_manager.snow_cells.keys():
		var cell := raw_cell as Vector2i
		var patch := MeshHelpers.box(Vector3(Constants.TILE_SIZE * 0.82, 0.035, Constants.TILE_SIZE * 0.82), snow_mat)
		patch.position = Constants.grid_to_world(cell) + Vector3(0, 0.055, 0)
		weather_visuals.add_child(patch)

func _item_display_name(item_id: String) -> String:
	match item_id:
		"detonator": return "Detonator"
		"glue": return "Glue"
		"shield_potion": return "Shield Potion"
		"invincible_star": return "Invincible Star"
		"dummy": return "Dummy"
		"oil_barrel": return "Oil Barrel"
		"wings": return "Wings"
		"football_shoes": return "Football Shoes"
		"tianlao": return "Tianlao"
	return item_id.capitalize()
