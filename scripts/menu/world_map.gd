class_name WorldMap
extends Control

const LEVEL_CATALOG := preload("res://scripts/level/level_catalog.gd")
const LEVEL_SESSION := preload("res://scripts/level/level_session.gd")
const LEVEL_PROGRESS_REPOSITORY := preload("res://scripts/level/level_progress_repository.gd")

class MapCanvas:
	extends Control

	var profiles: Array[Dictionary] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var bounds := get_rect()
		draw_rect(bounds, Color(0.035, 0.18, 0.27))
		var island := PackedVector2Array([
			_point(Vector2(0.05, 0.80)), _point(Vector2(0.10, 0.48)),
			_point(Vector2(0.26, 0.28)), _point(Vector2(0.48, 0.34)),
			_point(Vector2(0.64, 0.16)), _point(Vector2(0.91, 0.12)),
			_point(Vector2(0.96, 0.46)), _point(Vector2(0.83, 0.78)),
			_point(Vector2(0.57, 0.88)), _point(Vector2(0.31, 0.81)),
		])
		draw_colored_polygon(island, Color(0.16, 0.34, 0.22))
		draw_polyline(island + PackedVector2Array([island[0]]), Color(0.45, 0.66, 0.43), 5.0, true)
		var path := PackedVector2Array()
		for profile in profiles:
			path.append(_point(profile["map_position"] as Vector2))
		if path.size() > 1:
			draw_polyline(path, Color(0.92, 0.74, 0.34, 0.80), 7.0, true)
		for marker in [Vector2(0.23, 0.43), Vector2(0.28, 0.38), Vector2(0.69, 0.31), Vector2(0.74, 0.34)]:
			draw_circle(_point(marker), 13.0, Color(0.08, 0.25, 0.14))
		for marker in [Vector2(0.48, 0.70), Vector2(0.54, 0.73), Vector2(0.82, 0.45)]:
			draw_circle(_point(marker), 16.0, Color(0.72, 0.18, 0.06))
			draw_circle(_point(marker), 8.0, Color(1.0, 0.48, 0.08))

	func _point(normalized: Vector2) -> Vector2:
		return Vector2(normalized.x * size.x, normalized.y * size.y)

var catalog := LEVEL_CATALOG.new() as LevelCatalog
var progress_repository := LEVEL_PROGRESS_REPOSITORY.new() as LevelProgressRepository
var level_buttons: Dictionary = {}
var detail_label: Label
var back_button: Button
var map_canvas: MapCanvas

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	map_canvas = MapCanvas.new()
	map_canvas.name = "WorldMapCanvas"
	map_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_canvas.profiles = catalog.levels()
	add_child(map_canvas)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.20)
	shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shade.offset_bottom = 76.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := Label.new()
	title.text = "WORLD MAP"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 12.0
	title.offset_bottom = 62.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36))
	add_child(title)

	back_button = Button.new()
	back_button.text = "Back"
	back_button.position = Vector2(16, 16)
	back_button.custom_minimum_size = Vector2(100, 40)
	back_button.add_theme_font_size_override("font_size", 18)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	add_child(back_button)

	for profile in catalog.levels():
		_add_level_node(profile)

	var detail_band := ColorRect.new()
	detail_band.color = Color(0.025, 0.045, 0.055, 0.94)
	detail_band.anchor_left = 0.0
	detail_band.anchor_top = 1.0
	detail_band.anchor_right = 1.0
	detail_band.anchor_bottom = 1.0
	detail_band.offset_top = -92.0
	detail_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(detail_band)

	detail_label = Label.new()
	detail_label.anchor_left = 0.0
	detail_label.anchor_top = 1.0
	detail_label.anchor_right = 1.0
	detail_label.anchor_bottom = 1.0
	detail_label.offset_left = 24.0
	detail_label.offset_top = -82.0
	detail_label.offset_right = -24.0
	detail_label.offset_bottom = -10.0
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 18)
	detail_label.add_theme_color_override("font_color", Color(0.90, 0.94, 0.96))
	add_child(detail_label)
	var levels := catalog.levels()
	if not levels.is_empty():
		_show_profile(levels[0])

func _add_level_node(profile: Dictionary) -> void:
	var level_id := str(profile["id"])
	var unlocked := progress_repository.is_unlocked(level_id)
	var completed := progress_repository.completed_level_ids().has(level_id)
	var position_ratio := profile["map_position"] as Vector2
	var button := Button.new()
	button.name = "Level_%d" % int(profile["number"])
	button.text = str(profile["number"]) if unlocked else "LOCK"
	button.anchor_left = position_ratio.x
	button.anchor_top = position_ratio.y
	button.anchor_right = position_ratio.x
	button.anchor_bottom = position_ratio.y
	button.offset_left = -31.0
	button.offset_top = -31.0
	button.offset_right = 31.0
	button.offset_bottom = 31.0
	button.add_theme_font_size_override("font_size", 22 if unlocked else 11)
	button.tooltip_text = "%s\n%s" % [str(profile["name"]), str(profile["description"])] if unlocked else "Complete the previous level to unlock"
	button.disabled = not unlocked
	button.add_theme_stylebox_override("normal", _level_style(Color(0.16, 0.52, 0.32) if completed else Color(0.14, 0.34, 0.52)))
	button.add_theme_stylebox_override("hover", _level_style(Color(0.94, 0.62, 0.16)))
	button.add_theme_stylebox_override("disabled", _level_style(Color(0.16, 0.18, 0.20)))
	button.mouse_entered.connect(func(): _show_profile(profile))
	if unlocked:
		button.pressed.connect(func(): _enter_level(level_id))
	map_canvas.add_child(button)
	level_buttons[level_id] = button

func _show_profile(profile: Dictionary) -> void:
	if detail_label == null:
		return
	var state := "COMPLETED" if progress_repository.completed_level_ids().has(str(profile["id"])) else ("READY" if progress_repository.is_unlocked(str(profile["id"])) else "LOCKED")
	detail_label.text = "LEVEL %d  %s  |  %s\n%s  |  %d waves" % [int(profile["number"]), str(profile["name"]), state, str(profile["description"]), int(profile["max_waves"])]

func _enter_level(level_id: String) -> void:
	if not progress_repository.is_unlocked(level_id) or not LEVEL_SESSION.select_level(level_id):
		return
	get_tree().change_scene_to_file("res://scenes/game/main_3d.tscn")

func _level_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.86, 0.91, 0.82)
	style.set_border_width_all(3)
	style.set_corner_radius_all(31)
	return style
