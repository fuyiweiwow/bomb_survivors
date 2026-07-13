class_name GameGuideOverlay
extends Control

const ITEM_ICON_RENDERER := preload("res://scripts/menu/item_icon_renderer.gd")

signal closed

var guide_panel: PanelContainer = null
var guide_tabs: TabContainer = null
var operation_text: RichTextLabel = null
var item_list: VBoxContainer = null
var item_icon_ids: Array[String] = []
var item_icon_renderers: Array[Control] = []
var close_button: Button = null

func _ready() -> void:
	name = "GameGuideOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	get_viewport().size_changed.connect(_resize_panel)
	_resize_panel()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	guide_tabs.current_tab = 0
	close_button.grab_focus()

func close() -> void:
	visible = false
	closed.emit()

func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.01, 0.015, 0.02, 0.84)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	guide_panel = PanelContainer.new()
	guide_panel.name = "GameGuidePanel"
	guide_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(guide_panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	guide_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var title := Label.new()
	title.text = "Game Guide"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.24))
	content.add_child(title)

	guide_tabs = TabContainer.new()
	guide_tabs.name = "GuideTabs"
	guide_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guide_tabs.add_theme_font_size_override("font_size", 20)
	content.add_child(guide_tabs)
	operation_text = _add_text_page("Controls & Rules", _operation_guide_text())
	_build_item_page()

	close_button = Button.new()
	close_button.text = "Back to Main Menu"
	close_button.custom_minimum_size = Vector2(220, 44)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(close)
	content.add_child(close_button)

func _add_text_page(page_name: String, text: String) -> RichTextLabel:
	var page := MarginContainer.new()
	page.name = page_name
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		page.add_theme_constant_override(side, 16)
	guide_tabs.add_child(page)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = text
	label.scroll_active = true
	label.selection_enabled = true
	label.add_theme_font_size_override("normal_font_size", 18)
	label.add_theme_font_size_override("bold_font_size", 19)
	label.add_theme_color_override("default_color", Color(0.88, 0.91, 0.94))
	page.add_child(label)
	return label

func _build_item_page() -> void:
	var page := MarginContainer.new()
	page.name = "Items"
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		page.add_theme_constant_override(side, 12)
	guide_tabs.add_child(page)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	page.add_child(scroll)

	item_list = VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.add_theme_constant_override("separation", 5)
	scroll.add_child(item_list)
	_add_item_section("Stat Pickups", [
		{"id": "speed", "name": "Speed", "description": "Move faster."},
		{"id": "bomb", "name": "Bomb", "description": "Place more bombs at the same time."},
		{"id": "range", "name": "Range", "description": "Extend blast distance."},
		{"id": "shield", "name": "Shield", "description": "Store a Shield Potion in the backpack."},
	])
	_add_item_section("Consumable Items", [
		{"id": "detonator", "name": "Detonator", "description": "Detonate the first bomb in the direction you face."},
		{"id": "glue", "name": "Glue", "description": "Leave a slowing area under your feet."},
		{"id": "shield_potion", "name": "Shield Potion", "description": "Block one hit for 5 seconds and enable a lava launch."},
		{"id": "invincible_star", "name": "Invincible Star", "description": "Ignore damage and control effects for 5 seconds."},
		{"id": "dummy", "name": "Dummy", "description": "Passive item consumed automatically to revive you from Down."},
		{"id": "oil_barrel", "name": "Oil Barrel", "description": "Place a breakable barrel ahead; it explodes when destroyed."},
		{"id": "wings", "name": "Wings", "description": "Cross ground obstacles for 8 seconds and gain a longer lava-powered flight."},
		{"id": "football_shoes", "name": "Football Shoes", "description": "Replace bomb placement with a bomb kick for 8 seconds."},
		{"id": "tianlao", "name": "Prison", "description": "Create a delayed cross-shaped bomb formation ahead."},
		{"id": "duel", "name": "Duel Token", "description": "Gain immunity until you touch an enemy, then enter a separate wing duel."},
	])
	_add_section_title("Backpack")
	var backpack := Label.new()
	backpack.text = "3 slots; duplicate items are allowed. When full, a new pickup replaces the oldest item."
	backpack.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	backpack.add_theme_font_size_override("font_size", 16)
	backpack.add_theme_color_override("font_color", Color(0.82, 0.86, 0.90))
	item_list.add_child(backpack)

func _add_item_section(title: String, items: Array) -> void:
	_add_section_title(title)
	for item: Dictionary in items:
		_add_item_row(str(item["id"]), str(item["name"]), str(item["description"]))

func _add_section_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	item_list.add_child(label)

func _add_item_row(item_id: String, display_name: String, description: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 74
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	item_list.add_child(row)

	var icon = ITEM_ICON_RENDERER.new()
	icon.setup(item_id, display_name)
	row.add_child(icon)
	item_icon_ids.append(item_id)
	item_icon_renderers.append(icon)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(copy)
	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	copy.add_child(name_label)
	var description_label := Label.new()
	description_label.text = description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label.add_theme_font_size_override("font_size", 15)
	description_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.83))
	copy.add_child(description_label)
	item_list.add_child(HSeparator.new())

func _operation_guide_text() -> String:
	return """[b][color=#ffd45a]Basic Controls[/color][/b]
[b]W / A / S / D[/b]  Move; you can turn at any of the three substeps inside a tile
[b]Space[/b]  Place a bomb; while Football Shoes are active, kick the bomb ahead
[b]1 / 2 / 3[/b]  Select a backpack slot    [b]Q[/b]  Cycle items    [b]E[/b]  Use item
[b]Esc[/b]  Return to the main menu

[b][color=#ffd45a]Combat Rules[/color][/b]
Explosions travel in four directions. Walls block flames; crates can break and drop items.
Only the center third of an explosion tile deals damage, so precise positioning can avoid a hit.
Forests hide grounded characters. Lava burns unless a shield or wings trigger an eruption.
You can steer while airborne. Ground attacks miss high targets, but aerial attacks still hit.
At zero health, a character enters Down. The timer, another blast, or an enemy stomp defeats them.

[b][color=#ffd45a]Duel Controls[/color][/b]
The original map, bombs, and backpack are frozen during a duel.
[b]A / D[/b]  Move    [b]W[/b]  Glide while airborne    [b]S[/b]  Dive into the opponent
Stand on shifting lava to launch. The duel has no time limit and ends when either fighter reaches 0 HP.

[b][color=#ffd45a]Result Screen[/color][/b]
[b]R[/b]  Restart    [b]Esc[/b]  Main Menu    [b]Q[/b]  Quit Game"""

func _resize_panel() -> void:
	if guide_panel == null:
		return
	var viewport_size := get_viewport_rect().size
	guide_panel.custom_minimum_size = Vector2(
		minf(820.0, maxf(300.0, viewport_size.x - 40.0)),
		minf(580.0, maxf(320.0, viewport_size.y - 40.0))
	)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.07, 0.085, 0.98)
	style.border_color = Color(0.33, 0.40, 0.48, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
