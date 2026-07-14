extends SceneTree

const AIRBORNE_CONTROLLER_SCRIPT := preload("res://scripts/character/airborne_controller.gd")
const AIRBORNE_COLLISION_RESOLVER_SCRIPT := preload("res://scripts/character/airborne_collision_resolver.gd")

class TestAudio:
	extends RefCounted

	func play(_event_id: String) -> bool:
		return true

class TestCombat:
	extends RefCounted

	var damage_calls := 0

	func damage_player(_index: int, _amount: int, _source: String) -> void:
		damage_calls += 1

class TestGame:
	extends Node

	var character_registry := CharacterRegistry.new()
	var map_state := MapState.new(Constants.GRID_W, Constants.GRID_H, Constants.Cell.EMPTY, Constants.Cell.WALL)
	var occupied_cells: Dictionary = {}
	var audio_manager := TestAudio.new()
	var combat_manager := TestCombat.new()

	func character_state_at(index: int) -> CharacterState:
		return character_registry.state_at(index)

	func is_cell_walkable(x: int, y: int, _player_index := -1) -> bool:
		var cell := Vector2i(x, y)
		return map_state.is_walkable(cell) and not occupied_cells.has(cell)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _test_inventory_boundaries():
		return
	if not _test_attack_boundaries():
		return
	if not _test_airborne_boundaries():
		return
	print("BOUNDARY_RULES_SMOKE_OK inventory_fifo attack_height attack_footprint landing_bfs stomp_crossing")
	quit(0)

func _test_inventory_boundaries() -> bool:
	var inventory := InventoryManager.new()
	var missing_storage := {"selected_consumable_index": 0}
	if not _check(inventory.add_item(missing_storage, "shield_potion") and missing_storage["consumables"] == ["shield_potion"], "Inventory did not initialize missing item storage"):
		return false
	if not _check(not inventory.add_item(null, "shield_potion"), "Inventory accepted an invalid owner"):
		return false

	var fifo_owner := {
		"consumables": ["detonator", "glue", "shield_potion", "wings", "dummy"],
		"selected_consumable_index": 4,
	}
	inventory.add_item(fifo_owner, "oil_barrel")
	if not _check(fifo_owner["consumables"] == ["wings", "dummy", "oil_barrel"], "Inventory did not reduce malformed over-capacity data with FIFO order"):
		return false
	if not _check(int(fifo_owner["selected_consumable_index"]) == 1, "FIFO overwrite did not preserve the selected surviving item"):
		return false

	var duplicate_owner := {
		"consumables": ["shield_potion", "shield_potion", "wings"],
		"selected_consumable_index": 2,
	}
	if not _check(inventory.consume_item(duplicate_owner, "shield_potion") and duplicate_owner["consumables"] == ["shield_potion", "wings"], "Consuming a duplicate did not remove only the oldest matching item"):
		return false
	if not _check(int(duplicate_owner["selected_consumable_index"]) == 1 and inventory.consume_selected(duplicate_owner) == "wings", "Selected slot did not clamp after removing earlier or final items"):
		return false
	if not _check(duplicate_owner["consumables"] == ["shield_potion"] and int(duplicate_owner["selected_consumable_index"]) == 0, "Inventory selection was invalid after consuming the final slot"):
		return false
	if not _check(inventory.select_slot(duplicate_owner, 3) == "" and inventory.cycle({}) == "", "Empty or invalid inventory selection was accepted"):
		return false
	return true

func _test_attack_boundaries() -> bool:
	var rules := CombatRules.new()
	var cell := Vector2i(10, 10)
	var character_node := Node3D.new()
	root.add_child(character_node)
	var state := CharacterState.new({"node": character_node, "grid_pos": cell})
	var cells: Array = [cell]
	var center := Constants.grid_to_world(cell)

	character_node.position = center + Vector3(0.0, Constants.GROUND_ATTACK_MIN_HEIGHT, 0.0)
	if not _check(rules.is_in_attack_cells(state, cells, Constants.GROUND_ATTACK_MIN_HEIGHT, Constants.GROUND_ATTACK_MAX_HEIGHT), "Ground attack excluded its minimum height"):
		return false
	character_node.position.y = Constants.GROUND_ATTACK_MIN_HEIGHT - 0.001
	if not _check(not rules.is_in_attack_cells(state, cells, Constants.GROUND_ATTACK_MIN_HEIGHT, Constants.GROUND_ATTACK_MAX_HEIGHT), "Ground attack reached below its minimum height"):
		return false
	character_node.position.y = Constants.GROUND_ATTACK_MAX_HEIGHT
	if not _check(rules.is_in_attack_cells(state, cells, Constants.GROUND_ATTACK_MIN_HEIGHT, Constants.GROUND_ATTACK_MAX_HEIGHT), "Ground attack excluded its maximum height"):
		return false
	if not _check(
		rules.is_in_attack_cells(state, cells, Constants.AERIAL_ATTACK_MIN_HEIGHT, Constants.AERIAL_ATTACK_MAX_HEIGHT),
		"Ground and aerial attacks do not share their declared boundary: position=%s min=%.6f max=%.6f" % [state.world_position(), Constants.AERIAL_ATTACK_MIN_HEIGHT, Constants.AERIAL_ATTACK_MAX_HEIGHT]
	):
		return false
	character_node.position.y = Constants.GROUND_ATTACK_MAX_HEIGHT + 0.001
	if not _check(not rules.is_in_attack_cells(state, cells, Constants.GROUND_ATTACK_MIN_HEIGHT, Constants.GROUND_ATTACK_MAX_HEIGHT), "Ground attack reached above its maximum height"):
		return false

	character_node.position = center + Vector3(Constants.BLAST_HIT_RADIUS - 0.002, 0.0, 0.0)
	if not _check(rules.is_in_attack_cells(state, cells, Constants.GROUND_ATTACK_MIN_HEIGHT, Constants.GROUND_ATTACK_MAX_HEIGHT), "Attack missed a position inside the logical cell"):
		return false
	character_node.position = center + Vector3(Constants.BLAST_HIT_RADIUS, 0.0, 0.0)
	if not _check(not rules.is_in_attack_cells(state, cells, Constants.GROUND_ATTACK_MIN_HEIGHT, Constants.GROUND_ATTACK_MAX_HEIGHT), "Attack crossed the logical cell boundary"):
		return false
	character_node.queue_free()
	return true

func _test_airborne_boundaries() -> bool:
	var game := TestGame.new()
	root.add_child(game)
	var airborne_controller := AIRBORNE_CONTROLLER_SCRIPT.new()
	var collision_resolver := AIRBORNE_COLLISION_RESOLVER_SCRIPT.new()
	game.add_child(airborne_controller)
	game.add_child(collision_resolver)
	airborne_controller.setup(game)
	collision_resolver.setup(game)

	var landing_origin := Vector2i(12, 12)
	game.map_state.set_cell(landing_origin, Constants.Cell.LAVA)
	game.map_state.set_cell(landing_origin + Vector2i.UP, Constants.Cell.WALL)
	game.map_state.set_cell(landing_origin + Vector2i.DOWN, Constants.Cell.EMPTY)
	if not _check(airborne_controller._find_safe_landing_cell(landing_origin, 0) == landing_origin + Vector2i.DOWN, "Landing search did not choose the first safe breadth-first cell"):
		return false
	if not _check(airborne_controller._find_safe_landing_cell(Vector2i(-100, -100), 0) == Constants.PLAYER_START_CELL, "Landing search did not use its fallback for an unreachable origin"):
		return false

	var contact_cell := Vector2i(15, 12)
	var attacker_node := Node3D.new()
	var target_node := Node3D.new()
	game.add_child(attacker_node)
	game.add_child(target_node)
	var attacker := CharacterState.new({
		"id": 1,
		"node": attacker_node,
		"grid_pos": contact_cell,
		"alive": true,
		"downed": false,
		"ai": false,
		"airborne": true,
		"airborne_stomped": {},
	})
	var target := CharacterState.new({
		"id": 2,
		"node": target_node,
		"grid_pos": contact_cell,
		"alive": true,
		"downed": false,
		"ai": true,
	})
	game.character_registry.register(attacker)
	game.character_registry.register(target)
	var center := Constants.grid_to_world(contact_cell)
	target_node.position = center
	var contact_height := Constants.STOMP_CONTACT_HEIGHT

	attacker_node.position = center + Vector3(Constants.STOMP_HORIZONTAL_RADIUS + 0.001, contact_height, 0.0)
	var outside_result: Dictionary = collision_resolver.try_stomp(0, contact_height + 0.1, contact_height - 0.1)
	if not _check(not bool(outside_result["hit"]), "Stomp crossed its horizontal radius"):
		return false
	attacker_node.position = center + Vector3(Constants.STOMP_HORIZONTAL_RADIUS, contact_height, 0.0)
	var ascending_result: Dictionary = collision_resolver.try_stomp(0, contact_height - 0.1, contact_height + 0.1)
	if not _check(not bool(ascending_result["hit"]), "Ascending movement triggered a stomp"):
		return false
	var edge_result: Dictionary = collision_resolver.try_stomp(0, contact_height, contact_height - 0.1)
	if not _check(bool(edge_result["hit"]) and int(edge_result["target_index"]) == 1, "Descending stomp excluded its contact or horizontal boundary"):
		return false
	if not _check(int(game.combat_manager.damage_calls) == 1 and attacker.elevation.has_stomped(1), "Stomp boundary hit was not committed exactly once"):
		return false
	return true

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
