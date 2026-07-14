class_name DuelManager
extends Node

const ARENA_CATALOG := preload("res://scripts/duel/duel_arena_catalog.gd")
const ROUND_CONTROLLER := preload("res://scripts/duel/duel_round_controller.gd")
const DUEL_ORIGIN := Vector3(0, 0, 50)

var game: Node
var active := false
var pending_player_index := -1
var current_enemy_index := -1
var current_arena_id := ""
var arena_catalog: RefCounted = ARENA_CATALOG.new()
var arena: Node3D = null
var round: Node = null
var _original_states: Dictionary = {}
var _hud_was_visible := true
var _finishing := false

func setup(game_manager: Node) -> void:
	game = game_manager
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	if game == null or active or pending_player_index < 0 or get_tree().paused:
		return
	process_pending_contact()

func arm(player_index: int) -> bool:
	if active or pending_player_index >= 0:
		var busy_state := game.character_state_at(player_index) as CharacterState
		if busy_state != null:
			busy_state.set_status("Duel already armed")
		return false
	var state := game.character_state_at(player_index) as CharacterState
	if state == null or not _has_eligible_enemy(player_index):
		return false
	if not state.is_alive() or state.is_downed():
		return false
	pending_player_index = player_index
	state.arm_duel()
	return true

func process_pending_contact() -> bool:
	if active or pending_player_index < 0:
		return false
	var challenger := game.character_state_at(pending_player_index) as CharacterState
	if challenger == null or not challenger.is_alive() or challenger.is_downed():
		cancel_pending()
		return false
	for enemy_index in range(game.character_states.size()):
		if enemy_index == pending_player_index or not _is_eligible_enemy(pending_player_index, enemy_index):
			continue
		if _nodes_overlap(challenger, game.character_state_at(enemy_index)):
			return start_duel_with_enemy(pending_player_index, enemy_index)
	return false

func start_duel_with_enemy(player_index: int, enemy_index: int) -> bool:
	if active or not _is_eligible_enemy(player_index, enemy_index):
		return false
	var player_state := game.character_state_at(player_index) as CharacterState
	var enemy_state := game.character_state_at(enemy_index) as CharacterState
	if player_state == null or enemy_state == null or player_state.node() == null or enemy_state.node() == null:
		return false

	active = true
	_finishing = false
	pending_player_index = -1
	current_enemy_index = enemy_index
	player_state.disarm_duel()
	_original_states.clear()
	_store_actor_state(player_index)
	_store_actor_state(enemy_index)
	get_tree().paused = true
	if game.game_hud:
		_hud_was_visible = bool(game.game_hud.visible)
		game.game_hud.visible = false
	if game.game_ui.game_camera:
		game.game_ui.game_camera.current = false

	var arena_data: Dictionary = arena_catalog.create_random(game.art, DUEL_ORIGIN)
	if arena_data.is_empty():
		_restore_world(true)
		return false
	current_arena_id = str(arena_data["id"])
	arena = arena_data["node"] as Node3D
	add_child(arena)
	round = ROUND_CONTROLLER.new()
	add_child(round)
	round.finished.connect(_on_round_finished)
	round.setup(game, arena, player_index, enemy_index)
	game.audio_manager.play("boss_spawn")
	return true

func resolve_current_duel(player_won: bool) -> void:
	if active:
		_on_round_finished(player_won)

func cancel_pending() -> void:
	var state := game.character_state_at(pending_player_index) as CharacterState
	if state != null:
		state.disarm_duel()
	pending_player_index = -1

func _on_round_finished(player_won: bool) -> void:
	if not active or _finishing:
		return
	_finishing = true
	call_deferred("_finish_duel", player_won)

func _finish_duel(player_won: bool) -> void:
	if not active:
		return
	var player_index := int(round.actors[0]["player_index"]) if round and not round.actors.is_empty() else 0
	var enemy_index := current_enemy_index
	_restore_world(true)
	if player_won:
		var player_state := game.character_state_at(player_index) as CharacterState
		var enemy_state := game.character_state_at(enemy_index) as CharacterState
		player_state.set_status("Duel won")
		enemy_state.effects.grant_duel_return_grace(1.25)
		game.combat_manager.force_down_player(enemy_index, "duel")
	else:
		game.combat_manager.kill_player(player_index)

func _restore_world(restore_actor_states: bool) -> void:
	if is_instance_valid(round):
		round.cleanup()
		round.queue_free()
	round = null
	if is_instance_valid(arena):
		arena.queue_free()
	arena = null
	if restore_actor_states:
		for raw_index in _original_states.keys():
				var index := int(raw_index)
				var state: Dictionary = _original_states[index]
				var character := game.character_state_at(index) as CharacterState
				var player_node := character.node() if character != null else null
				if player_node != null:
					player_node.transform = state["transform"]
					player_node.visible = bool(state["visible"])
				if character != null:
					character.set_status(str(state["status"]))
	_original_states.clear()
	if game.game_hud:
		game.game_hud.visible = _hud_was_visible
	if game.game_ui.game_camera:
		game.game_ui.game_camera.current = true
	active = false
	_finishing = false
	current_arena_id = ""
	current_enemy_index = -1
	get_tree().paused = false

func _store_actor_state(player_index: int) -> void:
	var state := game.character_state_at(player_index) as CharacterState
	var node := state.node()
	_original_states[player_index] = {
		"transform": node.transform,
		"visible": node.visible,
		"status": state.status(),
	}

func _has_eligible_enemy(player_index: int) -> bool:
	for enemy_index in range(game.character_states.size()):
		if _is_eligible_enemy(player_index, enemy_index):
			return true
	return false

func _is_eligible_enemy(player_index: int, enemy_index: int) -> bool:
	if player_index == enemy_index:
		return false
	var player := game.character_state_at(player_index) as CharacterState
	var enemy := game.character_state_at(enemy_index) as CharacterState
	if player == null or enemy == null:
		return false
	return (
		player.is_alive()
		and enemy.is_alive()
		and not player.is_downed()
		and not enemy.is_downed()
		and player.is_ai() != enemy.is_ai()
	)

func _nodes_overlap(first: CharacterState, second: CharacterState) -> bool:
	return game.combat_manager.rules.characters_overlap(first, second)

func _exit_tree() -> void:
	if get_tree() and get_tree().paused:
		get_tree().paused = false
