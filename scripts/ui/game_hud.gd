class_name GameHUD
extends CanvasLayer

const MAX_INVENTORY_SLOTS := 3

var hud_label: Label
var player_card_panel: PanelContainer
var player_card_label: Label
var enemy_card_panel: PanelContainer
var enemy_card_label: Label
var inventory_count_label: Label
var inventory_slot_labels: Array[Label] = []

func _ready() -> void:
	_build()

func update_display(
	characters: Array[CharacterQuery],
	wave_number: int,
	wave_time: float,
	weather_text: String,
	difficulty_text: String,
	camera: Camera3D,
	item_display_name: Callable
) -> void:
	if characters.is_empty() or hud_label == null:
		return
	var player := characters[0]
	var wave_text := "W -" if wave_number <= 0 else "W %d/7 %.0fs" % [wave_number, wave_time]
	hud_label.text = "%s  |  %s  |  AI %s  |  SPD %d  BOMB %d/%d  RNG %d  SH %d" % [
		wave_text,
		weather_text,
		difficulty_text,
		player.speed(),
		player.bomb_placed_count(),
		player.bomb_capacity(),
		player.bomb_range(),
		player.shield_count(),
	]
	_update_inventory(player, item_display_name)
	player_card_label.text = _player_card_text(player)
	var featured := _featured_enemy(characters)
	enemy_card_label.text = _player_card_text(featured) if featured != null else "No enemies\nNext wave"
	_position_status_cards(camera)

func _build():
	var player_card := _make_status_card("YOU", Color(0.18, 0.48, 0.95))
	player_card_panel = player_card["panel"]
	player_card_label = player_card["label"]
	var enemy_card := _make_status_card("AI", Color(0.95, 0.27, 0.22))
	enemy_card_panel = enemy_card["panel"]
	enemy_card_label = enemy_card["label"]

	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.5)
	background.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	background.offset_top = -38.0
	background.offset_bottom = 0.0
	add_child(background)
	hud_label = Label.new()
	hud_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hud_label.offset_left = 12.0
	hud_label.offset_top = -30.0
	hud_label.offset_right = -12.0
	hud_label.offset_bottom = -5.0
	hud_label.add_theme_font_size_override("font_size", 12)
	hud_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(hud_label)
	_build_inventory_bar()

func _build_inventory_bar():
	var panel := PanelContainer.new()
	panel.name = "BackpackPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -204.0
	panel.offset_top = -92.0
	panel.offset_right = 204.0
	panel.offset_bottom = -44.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.045, 0.055, 0.94)
	panel_style.border_color = Color(0.32, 0.38, 0.43)
	panel_style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	panel.add_child(content)
	inventory_count_label = Label.new()
	inventory_count_label.text = "BACKPACK  0/3"
	inventory_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_count_label.add_theme_font_size_override("font_size", 11)
	inventory_count_label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.88))
	content.add_child(inventory_count_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	content.add_child(row)
	for i in range(MAX_INVENTORY_SLOTS):
		var slot := Label.new()
		slot.custom_minimum_size = Vector2(130, 28)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 11)
		row.add_child(slot)
		inventory_slot_labels.append(slot)

func _make_status_card(avatar_text: String, color: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(148, 42)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var avatar := Label.new()
	avatar.text = avatar_text
	avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.custom_minimum_size = Vector2(30, 30)
	avatar.add_theme_font_size_override("font_size", 12)
	avatar.add_theme_color_override("font_color", Color.WHITE)
	var avatar_style := StyleBoxFlat.new()
	avatar_style.bg_color = color
	avatar_style.corner_radius_top_left = 6
	avatar_style.corner_radius_top_right = 6
	avatar_style.corner_radius_bottom_left = 6
	avatar_style.corner_radius_bottom_right = 6
	avatar.add_theme_stylebox_override("normal", avatar_style)
	row.add_child(avatar)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.custom_minimum_size = Vector2(88, 32)
	row.add_child(label)
	return {"panel": panel, "label": label}

func _update_inventory(player: CharacterQuery, item_display_name: Callable):
	var items := player.consumables()
	var selected := player.selected_consumable_index()
	if inventory_count_label:
		inventory_count_label.text = "BACKPACK  %d/%d" % [items.size(), MAX_INVENTORY_SLOTS]
	for i in range(inventory_slot_labels.size()):
		var slot := inventory_slot_labels[i]
		slot.text = "%d  %s" % [i + 1, str(item_display_name.call(str(items[i])))] if i < items.size() else "%d  Empty" % [i + 1]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.42, 0.50, 0.92) if i == selected and i < items.size() else Color(0.08, 0.09, 0.11, 0.86)
		style.set_border_width_all(2)
		style.border_color = Color(0.40, 0.95, 0.78) if i == selected and i < items.size() else Color(0.25, 0.28, 0.32)
		slot.add_theme_stylebox_override("normal", style)

func _player_card_text(character: CharacterQuery) -> String:
	if not character.is_alive():
		return "HP 0/%d\nDown" % character.max_health()
	if character.is_downed():
		return "HP %d/%d\nDown %.1fs" % [character.health(), character.max_health(), character.downed_time_left()]
	if not character.boss_name().is_empty():
		return "%s  HP %d/%d\n%s" % [character.boss_name(), character.health(), character.max_health(), character.status()]
	return "HP %d/%d\n%s" % [character.health(), character.max_health(), character.status()]

func _featured_enemy(characters: Array[CharacterQuery]) -> CharacterQuery:
	for i in range(1, characters.size()):
		if characters[i].is_alive() and characters[i].is_boss():
			return characters[i]
	for i in range(1, characters.size()):
		if characters[i].is_alive():
			return characters[i]
	return null

func _position_status_cards(camera: Camera3D):
	if camera == null:
		return
	var viewport_size := camera.get_viewport().get_visible_rect().size
	player_card_panel.position = Vector2(10.0, 8.0)
	var enemy_size := enemy_card_panel.get_combined_minimum_size()
	enemy_card_panel.position = Vector2(maxf(viewport_size.x - enemy_size.x - 10.0, 10.0), 8.0)
