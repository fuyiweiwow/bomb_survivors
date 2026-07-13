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
		if player_index >= 0 and player_index < game.players.size():
			game.players[player_index]["status"] = "Duel already armed"
		return false
	if player_index < 0 or player_index >= game.players.size() or not _has_eligible_enemy(player_index):
		return false
	var player: Dictionary = game.players[player_index]
	if not player["alive"] or bool(player.get("downed", false)):
		return false
	pending_player_index = player_index
	player["duel_pending"] = true
	player["status"] = "Duel ready: touch an enemy"
	return true

func process_pending_contact() -> bool:
	if active or pending_player_index < 0 or pending_player_index >= game.players.size():
		return false
	var challenger: Dictionary = game.players[pending_player_index]
	if not challenger["alive"] or bool(challenger.get("downed", false)):
		cancel_pending()
		return false
	for enemy_index in range(game.players.size()):
		if enemy_index == pending_player_index or not _is_eligible_enemy(pending_player_index, enemy_index):
			continue
		if _nodes_overlap(challenger, game.players[enemy_index]):
			return start_duel_with_enemy(pending_player_index, enemy_index)
	return false

func start_duel_with_enemy(player_index: int, enemy_index: int) -> bool:
	if active or not _is_eligible_enemy(player_index, enemy_index):
		return false
	var player_node = game.players[player_index].get("node")
	var enemy_node = game.players[enemy_index].get("node")
	if not is_instance_valid(player_node) or not is_instance_valid(enemy_node):
		return false

	active = true
	_finishing = false
	pending_player_index = -1
	current_enemy_index = enemy_index
	game.players[player_index]["duel_pending"] = false
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
	if pending_player_index >= 0 and pending_player_index < game.players.size():
		game.players[pending_player_index]["duel_pending"] = false
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
		game.players[player_index]["status"] = "Duel won"
		game.players[enemy_index]["duel_return_grace"] = 1.25
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
			var node = game.players[index].get("node")
			if is_instance_valid(node):
				(node as Node3D).transform = state["transform"]
				(node as Node3D).visible = bool(state["visible"])
			game.players[index]["status"] = str(state["status"])
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
	var player: Dictionary = game.players[player_index]
	var node := player["node"] as Node3D
	_original_states[player_index] = {
		"transform": node.transform,
		"visible": node.visible,
		"status": player["status"],
	}

func _has_eligible_enemy(player_index: int) -> bool:
	for enemy_index in range(game.players.size()):
		if _is_eligible_enemy(player_index, enemy_index):
			return true
	return false

func _is_eligible_enemy(player_index: int, enemy_index: int) -> bool:
	if player_index < 0 or enemy_index < 0 or player_index >= game.players.size() or enemy_index >= game.players.size() or player_index == enemy_index:
		return false
	var player: Dictionary = game.players[player_index]
	var enemy: Dictionary = game.players[enemy_index]
	return (
		player["alive"]
		and enemy["alive"]
		and not bool(player.get("downed", false))
		and not bool(enemy.get("downed", false))
		and bool(player.get("ai", false)) != bool(enemy.get("ai", false))
	)

func _nodes_overlap(first: Dictionary, second: Dictionary) -> bool:
	var first_node = first.get("node")
	var second_node = second.get("node")
	if not is_instance_valid(first_node) or not is_instance_valid(second_node):
		return false
	var first_position := (first_node as Node3D).global_position
	var second_position := (second_node as Node3D).global_position
	return absf(first_position.y - second_position.y) <= 0.8 and Vector2(first_position.x, first_position.z).distance_to(Vector2(second_position.x, second_position.z)) <= 0.72

func _exit_tree() -> void:
	if get_tree() and get_tree().paused:
		get_tree().paused = false
