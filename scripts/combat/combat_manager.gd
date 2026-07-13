extends Node

var _game: Node

func setup(game_manager: Node):
	_game = game_manager

func kill_player(player_index: int) -> void:
	_kill_player(player_index)

func revive_player(player_index: int) -> void:
	_revive_player(player_index)

func consume_dummy_if_available(player: Dictionary) -> bool:
	return _consume_dummy_if_available(player)

func cancel_player_movement(player: Dictionary) -> void:
	_cancel_player_movement(player)

func process_downed(delta: float):
	for i in range(_game.players.size()):
		var p: Dictionary = _game.players[i]
		if not p["alive"] or not bool(p.get("downed", false)):
			continue
		p["downed_timer"] = maxf(float(p["downed_timer"]) - delta, 0.0)
		p["status"] = "Downed %.1fs" % float(p["downed_timer"])
		if _consume_dummy_if_available(p):
			_revive_player(i)
		elif float(p["downed_timer"]) <= 0.0:
			_kill_player(i)

func process_character_overlaps():
	for downed_index in range(_game.players.size()):
		var downed_player: Dictionary = _game.players[downed_index]
		if not downed_player["alive"] or not bool(downed_player.get("downed", false)):
			continue
		for other_index in range(_game.players.size()):
			if other_index == downed_index:
				continue
			var other: Dictionary = _game.players[other_index]
			if not other["alive"] or bool(other.get("downed", false)):
				continue
			if bool(other.get("ai", false)) == bool(downed_player.get("ai", false)):
				continue
			if other["grid_pos"] == downed_player["grid_pos"] and _character_nodes_overlap(downed_player, other):
				_kill_player(downed_index)
				break

func _character_nodes_overlap(first: Dictionary, second: Dictionary) -> bool:
	var first_node = first.get("node")
	var second_node = second.get("node")
	if not is_instance_valid(first_node) or not is_instance_valid(second_node):
		return false
	var first_position := (first_node as Node3D).global_position
	var second_position := (second_node as Node3D).global_position
	return (
		absf(first_position.y - second_position.y) <= 0.8
		and Vector2(first_position.x, first_position.z).distance_to(Vector2(second_position.x, second_position.z)) <= 0.72
	)

func process_terrain_effects(delta: float):
	for i in range(_game.players.size()):
		var p: Dictionary = _game.players[i]
		if not p["alive"]:
			continue
		if int(p.get("shield", 0)) > 0:
			p["shield_timer"] = maxf(float(p.get("shield_timer", Constants.SHIELD_DURATION)) - delta, 0.0)
			if float(p["shield_timer"]) <= 0.0:
				p["shield"] = 0
		else:
			p["shield_timer"] = 0.0
		if bool(p.get("downed", false)):
			continue
		var had_wings := float(p.get("wings_timer", 0.0)) > 0.0
		p["invincible_timer"] = maxf(float(p.get("invincible_timer", 0.0)) - delta, 0.0)
		p["wings_timer"] = maxf(float(p.get("wings_timer", 0.0)) - delta, 0.0)
		p["football_timer"] = maxf(float(p.get("football_timer", 0.0)) - delta, 0.0)
		p["slow_timer"] = maxf(float(p.get("slow_timer", 0.0)) - delta, 0.0)
		if had_wings and float(p["wings_timer"]) <= 0.0:
			_game.consumable_effects.end_wings(p)
		p["frozen_timer"] = maxf(float(p.get("frozen_timer", 0.0)) - delta, 0.0)
		var cell: Vector2i = p["grid_pos"]
		var cell_type: int = _game.grid[cell.y][cell.x]
		var status_parts: Array = []

		if bool(p.get("airborne", false)):
			p["lava_time"] = 0.0
			p["lava_eruption_time"] = 0.0
			status_parts.append("Airborne %.1fm" % Constants.player_world_height(p))
		elif cell_type == Constants.Cell.FOREST:
			status_parts.append("Hidden")
		if not bool(p.get("airborne", false)) and cell_type == Constants.Cell.LAVA:
			if _has_lava_lift_protection(p):
				p["lava_time"] = 0.0
				p["lava_eruption_time"] = float(p.get("lava_eruption_time", 0.0)) + delta
				status_parts.append("Lava pressure %.1fs" % maxf(Constants.LAVA_ERUPTION_TIME - float(p["lava_eruption_time"]), 0.0))
				if float(p["lava_eruption_time"]) >= Constants.LAVA_ERUPTION_TIME and _game.airborne_controller:
					if _game.airborne_controller.launch_from_lava(i):
						status_parts.clear()
						status_parts.append("Airborne %.1fm" % Constants.player_world_height(p))
			else:
				p["lava_eruption_time"] = 0.0
				p["lava_time"] = float(p["lava_time"]) + delta
				status_parts.append("Burning %.1fs" % maxf(Constants.LAVA_DAMAGE_TIME - float(p["lava_time"]), 0.0))
				if float(p["lava_time"]) >= Constants.LAVA_DAMAGE_TIME:
					p["lava_time"] = 0.0
					_damage_player(i, 1, "lava")
		elif not bool(p.get("airborne", false)):
			p["lava_time"] = 0.0
			p["lava_eruption_time"] = 0.0

		if int(p.get("shield", 0)) > 0:
			status_parts.append("Shield %d %.1fs" % [int(p["shield"]), float(p["shield_timer"])])
		if float(p.get("frozen_timer", 0.0)) > 0.0:
			status_parts.append("Frozen %.1fs" % float(p["frozen_timer"]))
		if float(p["invincible_timer"]) > 0.0:
			status_parts.append("Invincible %.1fs" % float(p["invincible_timer"]))
		if float(p["wings_timer"]) > 0.0:
			status_parts.append("Wings %.1fs" % float(p["wings_timer"]))
		if float(p["football_timer"]) > 0.0:
			status_parts.append("Football %.1fs" % float(p["football_timer"]))
		if float(p["slow_timer"]) > 0.0:
			status_parts.append("Glued %.1fs" % float(p["slow_timer"]))
		if status_parts.is_empty():
			p["status"] = "Ready"
		else:
			p["status"] = " / ".join(status_parts)

func _has_lava_lift_protection(player: Dictionary) -> bool:
	return int(player.get("shield", 0)) > 0 or float(player.get("wings_timer", 0.0)) > 0.0

func apply_explosion_damage(
	cells: Array,
	explosion_owner := -1,
	exploding_cell := Vector2i(-1, -1),
	hit_players: Variant = null,
	affect_obstacles := true,
	min_height := Constants.GROUND_ATTACK_MIN_HEIGHT,
	max_height := Constants.GROUND_ATTACK_MAX_HEIGHT
):
	var hit_registry: Dictionary = hit_players as Dictionary if hit_players is Dictionary else {}
	if affect_obstacles:
		for raw_cell in cells:
			var cell := raw_cell as Vector2i
			if _game.grid[cell.y][cell.x] == Constants.Cell.CRATE:
				_game.grid_manager.destroy_crate(cell)
				_game.powerup_manager.spawn_powerup(cell)
			if _game.oil_barrels.has(cell):
				_game.consumable_effects.damage_oil_barrel(cell)

	for i in range(_game.players.size()):
		var p: Dictionary = _game.players[i]
		if hit_registry.has(i) or not p["alive"] or not is_player_in_attack_cells(p, cells, min_height, max_height):
			continue
		hit_registry[i] = true
		if i == explosion_owner and _game.wall_mechanics.try_bomb_boost(i):
			continue
		_damage_player(i, 1, "blast")

func is_player_in_attack_cells(player: Dictionary, cells: Array, min_height: float, max_height: float) -> bool:
	var world_position := Constants.grid_to_world(player["grid_pos"])
	var player_node = player.get("node")
	if is_instance_valid(player_node):
		world_position = (player_node as Node3D).position
	if not Constants.is_height_in_attack_range(world_position.y, min_height, max_height):
		return false
	for raw_cell in cells:
		if Constants.is_world_position_in_blast_cell(world_position, raw_cell as Vector2i):
			return true
	return false

func damage_player(index: int, amount: int, source: String):
	if index < 0 or index >= _game.players.size():
		return
	var p: Dictionary = _game.players[index]
	if not p["alive"]:
		return
	if float(p.get("invincible_timer", 0.0)) > 0.0:
		p["status"] = "Invincible"
		return
	if bool(p.get("downed", false)):
		if source == "blast":
			_kill_player(index)
		return
	if int(p.get("shield", 0)) > 0:
		p["shield"] = int(p["shield"]) - 1
		if int(p["shield"]) <= 0:
			p["shield_timer"] = 0.0
		_flash_player_shield(p)
		_game.audio_manager.play("shield")
		return
	if str(p.get("boss_id", "")) != "" or bool(p.get("is_minion", false)):
		p["hp"] = maxi(int(p["hp"]) - amount, 0)
		p["status"] = "HP %d" % int(p["hp"])
		_flash_player_damage(p)
		_game.audio_manager.play("hit")
		if int(p["hp"]) <= 0:
			_kill_player(index)
		return
	p["hp"] = maxi(int(p["hp"]), 1)
	p["status"] = "Downed"
	_enter_downed(index, source)

func _enter_downed(index: int, source: String):
	var p: Dictionary = _game.players[index]
	if not p["alive"]:
		return
	p["downed"] = true
	p["downed_timer"] = Constants.DOWNED_DURATION
	p["status"] = "Downed by %s" % source
	_game.audio_manager.play("down")
	if _game.airborne_controller:
		_game.airborne_controller.force_land(index)
	_cancel_player_movement(p)
	_cancel_player_state_animation(p)
	if index == 0:
		_game.bomb_pressed = false
	var node: Node3D = p["node"]
	if is_instance_valid(node):
		var tw := create_tween().bind_node(node)
		p["state_tween"] = tw
		tw.tween_property(node, "scale", Vector3(1.0, 0.35, 1.0), 0.18)

func _revive_player(index: int):
	var p: Dictionary = _game.players[index]
	p["downed"] = false
	p["downed_timer"] = 0.0
	p["hp"] = mini(2, int(p["max_hp"]))
	p["status"] = "Revived"
	p["is_moving"] = false
	_cancel_player_state_animation(p)
	var node: Node3D = p["node"]
	if is_instance_valid(node):
		var tw := create_tween().bind_node(node)
		p["state_tween"] = tw
		tw.tween_property(node, "scale", Vector3(1.12, 1.12, 1.12), 0.12)
		tw.tween_property(node, "scale", Vector3.ONE, 0.16)

func _kill_player(index: int):
	var p: Dictionary = _game.players[index]
	if not p["alive"]:
		return
	var was_downed := bool(p.get("downed", false))
	p["alive"] = false
	p["downed"] = false
	p["downed_timer"] = 0.0
	p["status"] = "Defeated"
	if not was_downed:
		_game.audio_manager.play("down")
	if _game.airborne_controller:
		_game.airborne_controller.force_land(index)
	_cancel_player_movement(p)
	_cancel_player_state_animation(p)
	if str(p.get("boss_id", "")) != "":
		_game.powerup_manager.spawn_boss_reward(p["grid_pos"])
	var node = p.get("node")
	if not is_instance_valid(node):
		check_game_over()
		return
	var tw := create_tween().bind_node(node)
	p["state_tween"] = tw
	tw.tween_property(node, "scale", Vector3(1.0, 0.05, 1.0), 0.35)
	tw.tween_callback(func():
		if is_instance_valid(node):
			p["node"] = null
			node.queue_free()
		p["state_tween"] = null
		check_game_over()
	)

func check_game_over():
	if _game.players.is_empty():
		return
	if not _game.players[0]["alive"]:
		_game.game_over = true
		_game.game_ui.show_result(2)
		return
	var hostile_count := 0
	for i in range(1, _game.players.size()):
		if _game.players[i]["alive"]:
			hostile_count += 1
	if _game.wave_manager and _game.wave_manager.is_final_wave() and hostile_count == 0:
		_game.game_over = true
		_game.game_ui.show_result(1)

func _cancel_player_movement(p: Dictionary):
	var move_tween = p.get("move_tween")
	if move_tween is Tween and is_instance_valid(move_tween):
		(move_tween as Tween).kill()
	_game.movement_controller.cancel_move(p)

func _cancel_player_state_animation(p: Dictionary):
	var state_tween = p.get("state_tween")
	if state_tween is Tween and is_instance_valid(state_tween):
		(state_tween as Tween).kill()
	p["state_tween"] = null

func _flash_player_damage(p: Dictionary):
	var node: Node3D = p["node"]
	if not is_instance_valid(node):
		return
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3(1.12, 0.88, 1.12), 0.08)
	tw.tween_property(node, "scale", Vector3.ONE, 0.10)

func _flash_player_shield(p: Dictionary):
	var node: Node3D = p["node"]
	if not is_instance_valid(node):
		return
	var shield := MeshHelpers.sphere(0.62, _game.art.mat_shield)
	shield.transparency = 0.35
	node.add_child(shield)
	var tw := create_tween()
	tw.tween_property(shield, "scale", Vector3(1.35, 1.35, 1.35), 0.18)
	tw.tween_property(shield, "transparency", 1.0, 0.18)
	tw.tween_callback(shield.queue_free)

func _damage_player(index: int, amount: int, source: String):
	damage_player(index, amount, source)

func grant_shield(index: int, amount := 1):
	if index < 0 or index >= _game.players.size():
		return
	var player: Dictionary = _game.players[index]
	player["shield"] = clampi(int(player.get("shield", 0)) + amount, 0, 5)
	player["shield_timer"] = Constants.SHIELD_DURATION
	player["status"] = "Shield %.1fs" % Constants.SHIELD_DURATION
	_game.audio_manager.play("shield")
	if bool(player.get("ai", false)) and _game.ai_controller:
		_game.ai_controller.on_shield_granted(index)
	if _game.consumable_effects and _game.consumable_effects.status_visuals:
		_game.consumable_effects.status_visuals.refresh_player(player)

func _consume_dummy_if_available(p: Dictionary) -> bool:
	return _game.inventory_manager.consume_item(p, "dummy")
