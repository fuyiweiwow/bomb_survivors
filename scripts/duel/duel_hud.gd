class_name DuelHUD
extends CanvasLayer

var player_label: Label = null
var enemy_label: Label = null
var status_label: Label = null

func setup(arena_name: String) -> void:
	layer = 120
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_top = 12
	top.offset_right = -14
	top.offset_bottom = 76
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.025, 0.035, 0.05, 0.94)
	top_style.border_color = Color(0.92, 0.30, 0.18)
	top_style.set_border_width_all(1)
	top.add_theme_stylebox_override("panel", top_style)
	add_child(top)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	top.add_child(row)
	player_label = _make_fighter_label(Color(0.40, 0.72, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	row.add_child(player_label)
	var title := Label.new()
	title.text = "DUEL  ·  %s" % arena_name.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.24))
	row.add_child(title)
	enemy_label = _make_fighter_label(Color(1.0, 0.38, 0.28), HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(enemy_label)

	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 14
	bottom.offset_top = -62
	bottom.offset_right = -14
	bottom.offset_bottom = -12
	var bottom_style := StyleBoxFlat.new()
	bottom_style.bg_color = Color(0.025, 0.035, 0.05, 0.92)
	bottom.add_theme_stylebox_override("panel", bottom_style)
	add_child(bottom)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.85, 0.90, 0.94))
	bottom.add_child(status_label)

func update_display(player_hp: int, player_max_hp: int, enemy_hp: int, enemy_max_hp: int, lava_refresh: float) -> void:
	player_label.text = "YOU  HP %d/%d\nWINGS UNLIMITED" % [player_hp, player_max_hp]
	enemy_label.text = "AI  HP %d/%d\nWINGS UNLIMITED" % [enemy_hp, enemy_max_hp]
	status_label.text = "A/D Move   W Glide   S Dive   ·   Lava shifts in %.1fs   ·   Bombs and backpack disabled" % maxf(lava_refresh, 0.0)

func _make_fighter_label(color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(170, 58)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	return label
