class_name GameHUD
extends CanvasLayer

const MAX_INVENTORY_SLOTS := 3

var hud_label: Label
var player_card_panel: PanelContainer
var player_card_label: Label
var enemy_card_panel: PanelContainer
var enemy_card_label: Label
var inventory_slot_labels: Array[Label] = []

func _ready() -> void:
	_build()

func update_display(
	players: Array,
	wave_number: int,
	wave_time: float,
	weather_text: String,
	difficulty_text: String,
	camera: Camera3D,
	grid_width: int,
	grid_to_world: Callable,
	item_display_name: Callable
) -> void:
	if players.is_empty() or hud_label == null:
		return
	var player: Dictionary = players[0]
	var wave_text := "Wave -" if wave_number <= 0 else "Wave %d/7  %.0fs" % [wave_number, wave_time]
	hud_label.text = "%s  |  %s  |  AI %s  |  SPD %d  BOMB %d/%d  RNG %d  SH %d  BAG %d/%d" % [
		wave_text,
		weather_text,
		difficulty_text,
		player["speed"],
		player["bomb_placed_count"],
		player["bomb_max"],
		player["bomb_range"],
		player["shield"],
		(player["consumables"] as Array).size(),
		MAX_INVENTORY_SLOTS
	]
	_update_inventory(player, item_display_name)
	player_card_label.text = _player_card_text(player)
	var featured := _featured_enemy(players)
	enemy_card_label.text = _player_card_text(featured) if not featured.is_empty() else "No enemies\nNext wave"
	_position_status_cards(camera, grid_width, grid_to_world)

func _build():
	var player_card := _make_status_card("YOU", Color(0.18, 0.48, 0.95))
	player_card_panel = player_card["panel"]
	player_card_label = player_card["label"]
	var enemy_card := _make_status_card("AI", Color(0.95, 0.27, 0.22))
	enemy_card_panel = enemy_card["panel"]
	enemy_card_label = enemy_card["label"]

	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.5)
	background.position = Vector2(0, 548)
	background.size = Vector2(800, 52)
	add_child(background)
	hud_label = Label.new()
	hud_label.position = Vector2(12, 560)
	hud_label.size = Vector2(780, 30)
	hud_label.add_theme_font_size_override("font_size", 16)
	hud_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(hud_label)
	_build_inventory_bar()

func _build_inventory_bar():
	var panel := PanelContainer.new()
	panel.position = Vector2(446, 500)
	panel.custom_minimum_size = Vector2(342, 42)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	for i in range(MAX_INVENTORY_SLOTS):
		var slot := Label.new()
		slot.custom_minimum_size = Vector2(110, 36)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 11)
		row.add_child(slot)
		inventory_slot_labels.append(slot)

func _make_status_card(avatar_text: String, color: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(156, 46)
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
	avatar.custom_minimum_size = Vector2(34, 34)
	avatar.add_theme_font_size_override("font_size", 13)
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
	label.custom_minimum_size = Vector2(92, 36)
	row.add_child(label)
	return {"panel": panel, "label": label}

func _update_inventory(player: Dictionary, item_display_name: Callable):
	var items: Array = player.get("consumables", [])
	var selected := clampi(int(player.get("selected_consumable_index", 0)), 0, maxi(items.size() - 1, 0))
	for i in range(inventory_slot_labels.size()):
		var slot := inventory_slot_labels[i]
		slot.text = str(item_display_name.call(str(items[i]))) if i < items.size() else "-"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.42, 0.50, 0.92) if i == selected and i < items.size() else Color(0.08, 0.09, 0.11, 0.86)
		style.set_border_width_all(2)
		style.border_color = Color(0.40, 0.95, 0.78) if i == selected and i < items.size() else Color(0.25, 0.28, 0.32)
		slot.add_theme_stylebox_override("normal", style)

func _player_card_text(player: Dictionary) -> String:
	if not player["alive"]:
		return "HP 0/%d\nDown" % int(player["max_hp"])
	if bool(player.get("downed", false)):
		return "HP %d/%d\nDown %.1fs" % [int(player["hp"]), int(player["max_hp"]), float(player["downed_timer"])]
	var title := str(player.get("boss_name", ""))
	if title != "":
		return "%s  HP %d/%d\n%s" % [title, int(player["hp"]), int(player["max_hp"]), str(player["status"])]
	return "HP %d/%d\n%s" % [int(player["hp"]), int(player["max_hp"]), str(player["status"])]

func _featured_enemy(players: Array) -> Dictionary:
	for i in range(1, players.size()):
		if players[i]["alive"] and str(players[i].get("boss_id", "")) != "":
			return players[i]
	for i in range(1, players.size()):
		if players[i]["alive"]:
			return players[i]
	return {}

func _position_status_cards(camera: Camera3D, grid_width: int, grid_to_world: Callable):
	if camera == null:
		return
	var player_pos := camera.unproject_position(grid_to_world.call(Vector2i(2, 0)) + Vector3(0, 1.05, 0))
	player_card_panel.position = player_pos + Vector2(-78, -22)
	var enemy_pos := camera.unproject_position(grid_to_world.call(Vector2i(grid_width - 3, 0)) + Vector3(0, 1.05, 0))
	enemy_card_panel.position = enemy_pos + Vector2(-78, -22)
