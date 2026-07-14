extends SceneTree

func _init() -> void:
	var map_state := MapState.new(5, 5, Constants.Cell.EMPTY, Constants.Cell.WALL)
	if not _check(map_state.is_wall(Vector2i.ZERO), "MapState did not build its border"):
		return
	if not _check(map_state.is_walkable(Vector2i(2, 2)), "MapState interior is not walkable"):
		return
	if not _check(map_state.set_cell(Vector2i(2, 2), Constants.Cell.LAVA) and map_state.is_lava(Vector2i(2, 2)), "MapState did not own cell mutation"):
		return
	if not _check(not map_state.set_cell(Vector2i(-1, 2), Constants.Cell.CRATE), "MapState accepted an out-of-bounds write"):
		return
	var editor_document := MapEditorDocument.new(5, 5, "user://domain_model_editor_map.json")
	if not _check(not editor_document.paint(Vector2i.ZERO, Constants.Cell.LAVA), "MapEditorDocument changed the protected border"):
		return
	if not _check(editor_document.paint(Vector2i(2, 2), Constants.Cell.FOREST) and editor_document.map_state.is_forest(Vector2i(2, 2)), "MapEditorDocument did not paint an interior cell"):
		return
	if not _check(editor_document.erase(Vector2i(2, 2)) and editor_document.map_state.cell_at(Vector2i(2, 2)) == Constants.Cell.EMPTY, "MapEditorDocument did not erase an interior cell"):
		return
	editor_document.paint(Vector2i(2, 2), Constants.Cell.FOREST)
	if not _check(editor_document.save(), "MapEditorDocument did not save its map"):
		return
	var loaded_editor_document := MapEditorDocument.new(5, 5, "user://domain_model_editor_map.json")
	if not _check(loaded_editor_document.load() == MapEditorDocument.LoadResult.LOADED and loaded_editor_document.map_state.is_forest(Vector2i(2, 2)), "MapEditorDocument did not restore its saved map"):
		return
	loaded_editor_document.reset_and_delete_saved_map()

	var data := {
		"id": 7,
		"grid_pos": Vector2i(3, 3),
		"alive": true,
		"downed": false,
		"downed_timer": 0.0,
		"ai": false,
		"airborne": false,
		"boss_id": "",
		"is_minion": false,
		"shield": 0,
		"shield_timer": 0.0,
		"invincible_timer": 0.0,
		"duel_pending": false,
		"hp": 3,
		"max_hp": 3,
		"status": "Ready",
		"is_moving": false,
	}
	var state := CharacterState.new(data)
	var rules := CombatRules.new()
	state.begin_grid_move(Vector2i(3, 3), Vector2i(4, 3), Vector3(1, 0, 0), 4.5)
	if not _check(state.is_moving() and state.is_grid_motion_active() and state.move_target_cell() == Vector2i(4, 3), "Grid movement did not begin atomically"):
		return
	state.complete_grid_move()
	if not _check(not state.is_moving() and state.cell() == Vector2i(4, 3), "Grid movement did not complete atomically"):
		return
	state.effects.grant_wings(1.0)
	state.effects.apply_slow(0.5)
	var expired_effects := state.effects.tick_active(0.6)
	if not _check(state.effects.has_wings() and not state.effects.is_slowed() and not bool(expired_effects["wings_expired"]), "Timed effects did not advance through CharacterEffectState"):
		return
	state.effects.tick_active(0.5)
	if not _check(not state.effects.has_wings(), "Wings did not expire through CharacterEffectState"):
		return
	state.begin_airborne(3.0, "Airborne")
	state.elevation.mark_stomped(9)
	if not _check(state.is_airborne() and state.elevation.has_stomped(9), "Airborne state did not own the stomp registry"):
		return
	state.finish_airborne(Vector2i(4, 3))
	if not _check(not state.is_airborne() and not state.elevation.has_stomped(9), "Landing did not reset airborne state atomically"):
		return
	state.bombs.configure(2, 3)
	state.bombs.record_placed(Vector2i(4, 3), 10.0, 0.3)
	state.bombs.record_placed(Vector2i(4, 4), 10.2, 0.3)
	if not _check(state.bombs.placed_count() == 2 and state.bombs.blast_range() == 3 and state.bombs.can_pass_hop_bomb(Vector2i(4, 3), 10.25), "Bomb placement state did not preserve the hop window"):
		return
	state.bombs.record_removed()
	if not _check(state.bombs.placed_count() == 1 and state.bombs.can_place(), "Bomb removal did not restore capacity"):
		return
	data["ai"] = true
	data["move_timer"] = 0.0
	data["move_interval"] = 0.25
	data["bomb_timer"] = 0.0
	data["bomb_interval"] = 0.5
	data["bomb_placed_count"] = 0
	data["bomb_max"] = 1
	state.advance_ai_clocks(0.5)
	if not _check(state.is_ai_move_ready() and state.is_ai_bomb_ready(), "AI clocks are not owned by CharacterState"):
		return
	if not _check(rules.damage_route(state, "blast") == CombatRules.DamageRoute.ENTER_DOWNED, "Normal damage route changed"):
		return
	data["shield"] = 1
	if not _check(rules.damage_route(state, "blast") == CombatRules.DamageRoute.ABSORB_SHIELD, "Shield damage route changed"):
		return
	state.consume_shield()
	state.enter_downed("test", 1.0)
	if not _check(state.is_downed() and rules.damage_route(state, "blast") == CombatRules.DamageRoute.EXECUTE_DOWNED, "Downed blast route changed"):
		return
	if not _check(not state.tick_downed(0.5) and state.tick_downed(0.6), "Downed timer transition changed"):
		return
	state.revive()
	if not _check(state.is_alive() and not state.is_downed() and int(data["hp"]) == 2, "Character revive transition changed"):
		return
	data["boss_id"] = "blast_king"
	if not _check(rules.damage_route(state, "blast") == CombatRules.DamageRoute.DAMAGE_HEALTH, "Boss health route changed"):
		return
	state.defeat()
	if not _check(not state.is_alive(), "Character defeat transition changed"):
		return
	var registry := CharacterRegistry.new()
	if not _check(registry.register(state) and not registry.register(state), "CharacterRegistry accepted a duplicate id"):
		return
	var compatibility_view := registry.data_view()
	compatibility_view.clear()
	if not _check(registry.count() == 1 and registry.state_at(0) == state and registry.by_id(7) == state, "CharacterRegistry exposed mutable collection ownership"):
		return
	if not _check(registry.unregister_last() == state and registry.is_empty(), "CharacterRegistry did not remove all indexes atomically"):
		return

	print("DOMAIN_MODEL_SMOKE_OK map_state map_editor_document character_state character_registry combat_rules")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
