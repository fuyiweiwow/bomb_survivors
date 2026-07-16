class_name TutorialController
extends CanvasLayer

signal completed

const STEP_MOVE := 0
const STEP_BOMB := 1
const STEP_ITEM := 2
const STEP_COMBAT := 3

var game: Node
var level_profile: Dictionary
var tutorial_step := STEP_MOVE
var initial_cell := Vector2i.ZERO
var prompt_label: Label
var prompt_panel: PanelContainer
var completion_time := 0.0

func setup(game_manager: Node, profile: Dictionary) -> void:
	game = game_manager
	level_profile = profile.duplicate(true)
	layer = 70
	var player := game.character_state_at(0) as CharacterState
	initial_cell = player.cell() if player != null else Constants.PLAYER_START_CELL
	_build_prompt()
	_update_prompt()

func _process(delta: float) -> void:
	if game == null or game.game_over or prompt_panel == null:
		return
	var player := game.character_state_at(0) as CharacterState
	if player == null:
		return
	match tutorial_step:
		STEP_MOVE:
			if player.cell() != initial_cell:
				_advance()
		STEP_BOMB:
			if player.bombs.placed_count() > 0 or not game.bomb_map.is_empty():
				_advance()
		STEP_ITEM:
			if not player.query().has_consumable("shield_potion"):
				_advance()
		STEP_COMBAT:
			completion_time += delta
			if completion_time >= 6.0:
				prompt_panel.visible = false

func prompt_text() -> String:
	return prompt_label.text if prompt_label != null else ""

func _advance() -> void:
	var previous_step := tutorial_step
	tutorial_step = mini(tutorial_step + 1, STEP_COMBAT)
	completion_time = 0.0
	_update_prompt()
	if previous_step != STEP_COMBAT and tutorial_step == STEP_COMBAT:
		completed.emit()

func _build_prompt() -> void:
	prompt_panel = PanelContainer.new()
	prompt_panel.name = "TutorialPrompt"
	prompt_panel.anchor_left = 0.5
	prompt_panel.anchor_top = 0.0
	prompt_panel.anchor_right = 0.5
	prompt_panel.anchor_bottom = 0.0
	prompt_panel.offset_left = -270.0
	prompt_panel.offset_top = 70.0
	prompt_panel.offset_right = 270.0
	prompt_panel.offset_bottom = 132.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.065, 0.94)
	style.border_color = Color(1.0, 0.78, 0.24)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	prompt_panel.add_theme_stylebox_override("panel", style)
	add_child(prompt_panel)

	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_font_size_override("font_size", 17)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	prompt_panel.add_child(prompt_label)

func _update_prompt() -> void:
	if prompt_label == null:
		return
	match tutorial_step:
		STEP_MOVE:
			prompt_label.text = "TUTORIAL 1/3  Move with W / A / S / D or the arrow keys."
		STEP_BOMB:
			prompt_label.text = "TUTORIAL 2/3  Press Space to place a bomb, then move out of its blast tiles."
		STEP_ITEM:
			prompt_label.text = "TUTORIAL 3/3  Press E to use the selected Shield Potion from your backpack."
		STEP_COMBAT:
			prompt_label.text = "TUTORIAL COMPLETE  Defeat the enemies and survive both waves."
