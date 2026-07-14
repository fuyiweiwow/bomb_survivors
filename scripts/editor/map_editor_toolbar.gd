class_name MapEditorToolbar
extends CanvasLayer

signal tool_selected(cell_type: int)
signal save_requested
signal exit_requested

const TOP_BAND_HEIGHT := 56.0
const BOTTOM_BAND_HEIGHT := 72.0

var selected_cell := Constants.Cell.WALL
var selected_label: Label

func setup(initial_cell: int) -> void:
	selected_cell = initial_cell
	_build_ui()
	_update_selected_label()

func set_selected_cell(cell_type: int) -> void:
	selected_cell = cell_type
	_update_selected_label()

func handles_pointer(screen_position: Vector2, viewport_height: float) -> bool:
	return screen_position.y <= TOP_BAND_HEIGHT or screen_position.y >= viewport_height - BOTTOM_BAND_HEIGHT

func _build_ui() -> void:
	var top_band := ColorRect.new()
	top_band.color = Color(0.025, 0.032, 0.040, 0.96)
	top_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_band.offset_bottom = TOP_BAND_HEIGHT
	add_child(top_band)

	var bottom_band := ColorRect.new()
	bottom_band.color = Color(0.025, 0.032, 0.040, 0.96)
	bottom_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_band.offset_top = -BOTTOM_BAND_HEIGHT
	add_child(bottom_band)

	var top_center := CenterContainer.new()
	top_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_center.offset_top = 8.0
	top_center.offset_bottom = 50.0
	add_child(top_center)

	var top_bar := PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(180, 38)
	top_center.add_child(top_bar)

	var top_margin := MarginContainer.new()
	_set_margins(top_margin, 12, 5, 12, 5)
	top_bar.add_child(top_margin)

	var title := Label.new()
	title.text = "Map Editor"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(150, 26)
	top_margin.add_child(title)

	var bottom_center := CenterContainer.new()
	bottom_center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_center.offset_top = -66.0
	bottom_center.offset_bottom = -10.0
	add_child(bottom_center)

	var bottom_bar := PanelContainer.new()
	bottom_bar.custom_minimum_size = Vector2(438, 44)
	bottom_center.add_child(bottom_bar)

	var bottom_margin := MarginContainer.new()
	_set_margins(bottom_margin, 10, 8, 10, 8)
	bottom_bar.add_child(bottom_margin)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 6)
	bottom_margin.add_child(controls)

	selected_label = Label.new()
	selected_label.add_theme_font_size_override("font_size", 16)
	selected_label.add_theme_color_override("font_color", Color.YELLOW)
	selected_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selected_label.custom_minimum_size = Vector2(92, 30)
	controls.add_child(selected_label)

	_add_tool_button(controls, Constants.Cell.WALL, "Wall / 1")
	_add_tool_button(controls, Constants.Cell.CRATE, "Crate / 2")
	_add_tool_button(controls, Constants.Cell.FOREST, "Forest: hides players / 3")
	_add_tool_button(controls, Constants.Cell.LAVA, "Lava: damages over time / 4")
	_add_tool_button(controls, Constants.Cell.EMPTY, "Empty / 5")

	var save_button := Button.new()
	save_button.text = "S"
	save_button.tooltip_text = "Save"
	save_button.custom_minimum_size = Vector2(42, 30)
	save_button.pressed.connect(func(): save_requested.emit())
	controls.add_child(save_button)

	var exit_button := Button.new()
	exit_button.text = "X"
	exit_button.tooltip_text = "Exit"
	exit_button.custom_minimum_size = Vector2(42, 30)
	exit_button.pressed.connect(func(): exit_requested.emit())
	controls.add_child(exit_button)

func _set_margins(container: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_bottom", bottom)

func _add_tool_button(parent: Node, cell_type: int, tooltip: String) -> void:
	var button := Button.new()
	button.icon = _make_cell_icon(cell_type)
	button.expand_icon = true
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(32, 30)
	button.pressed.connect(func(): tool_selected.emit(cell_type))
	parent.add_child(button)

func _make_cell_icon(cell_type: int) -> Texture2D:
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	var background := Color(0.20, 0.22, 0.24)
	var foreground := Color.WHITE
	match cell_type:
		Constants.Cell.WALL:
			background = Color(0.58, 0.62, 0.68)
			foreground = Color(0.32, 0.35, 0.40)
		Constants.Cell.CRATE:
			background = Color(0.78, 0.50, 0.24)
			foreground = Color(0.42, 0.24, 0.10)
		Constants.Cell.FOREST:
			background = Color(0.10, 0.42, 0.16)
			foreground = Color(0.40, 0.78, 0.28)
		Constants.Cell.LAVA:
			background = Color(0.82, 0.14, 0.04)
			foreground = Color(1.0, 0.72, 0.10)
		Constants.Cell.EMPTY:
			background = Color(0.70, 0.78, 0.66)
			foreground = Color(0.82, 0.88, 0.76)
	image.fill(background)
	for i in range(24):
		image.set_pixel(i, 0, Color(0.05, 0.06, 0.07))
		image.set_pixel(i, 23, Color(0.05, 0.06, 0.07))
		image.set_pixel(0, i, Color(0.05, 0.06, 0.07))
		image.set_pixel(23, i, Color(0.05, 0.06, 0.07))
	match cell_type:
		Constants.Cell.WALL:
			for y in range(5, 19, 6):
				for x in range(3, 21):
					image.set_pixel(x, y, foreground)
			for x in range(6, 21, 7):
				for y in range(3, 21):
					image.set_pixel(x, y, foreground)
		Constants.Cell.CRATE:
			for i in range(4, 20):
				image.set_pixel(i, i, foreground)
				image.set_pixel(23 - i, i, foreground)
			for i in range(5, 19):
				image.set_pixel(i, 5, foreground)
				image.set_pixel(i, 18, foreground)
				image.set_pixel(5, i, foreground)
				image.set_pixel(18, i, foreground)
		Constants.Cell.FOREST:
			for y in range(5, 17):
				for x in range(7, 17):
					if abs(x - 12) + abs(y - 11) < 8:
						image.set_pixel(x, y, foreground)
			for y in range(14, 21):
				image.set_pixel(11, y, Color(0.38, 0.20, 0.08))
				image.set_pixel(12, y, Color(0.38, 0.20, 0.08))
		Constants.Cell.LAVA:
			for x in range(4, 20):
				var y := 12 + int(sin(float(x) * 0.8) * 3.0)
				for fill_y in range(y, 20):
					image.set_pixel(x, fill_y, foreground)
		Constants.Cell.EMPTY:
			for y in range(4, 20, 5):
				for x in range(4, 20, 5):
					image.set_pixel(x, y, foreground)
	return ImageTexture.create_from_image(image)

func _update_selected_label() -> void:
	if selected_label == null:
		return
	var names := {
		Constants.Cell.WALL: "Wall",
		Constants.Cell.CRATE: "Crate",
		Constants.Cell.FOREST: "Forest",
		Constants.Cell.LAVA: "Lava",
		Constants.Cell.EMPTY: "Empty",
	}
	selected_label.text = "Sel: " + names.get(selected_cell, "?")
