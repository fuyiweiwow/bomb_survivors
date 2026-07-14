extends SceneTree

func _init() -> void:
	var player_config_path := "user://domain_model_player_config.json"
	var ai_settings_path := "user://domain_model_ai_settings.json"
	_remove_file(player_config_path)
	_remove_file(ai_settings_path)
	var config_repository := GameConfigRepository.new(player_config_path, ai_settings_path)
	var defaults := config_repository.load_player_config()
	if not _check(defaults["gender"] == "male" and defaults["start_speed"] == 5, "GameConfigRepository defaults changed"):
		return
	var sanitized := config_repository.sanitize_player_config({"gender": "robot", "start_speed": 99, "start_bombs": 0, "start_range": 99, "start_shields": -1})
	if not _check(sanitized["gender"] == "male" and sanitized["start_speed"] == 10 and sanitized["start_bombs"] == 1 and sanitized["start_range"] == 10 and sanitized["start_shields"] == 0, "GameConfigRepository did not constrain invalid player settings"):
		return
	if not _check(config_repository.save_player_config({"gender": "female", "start_speed": 7, "start_bombs": 3, "start_range": 4, "start_shields": 2}), "GameConfigRepository did not save player settings"):
		return
	var loaded_config := config_repository.load_player_config()
	if not _check(loaded_config["gender"] == "female" and loaded_config["start_speed"] == 7 and loaded_config["start_bombs"] == 3 and loaded_config["start_range"] == 4 and loaded_config["start_shields"] == 2, "GameConfigRepository did not restore player settings"):
		return
	if not _check(config_repository.save_ai_difficulty("hard") and config_repository.load_ai_difficulty() == "hard", "GameConfigRepository did not restore AI difficulty"):
		return
	if not _check(config_repository.save_ai_difficulty("impossible") and config_repository.load_ai_difficulty() == "normal", "GameConfigRepository accepted an invalid AI difficulty"):
		return
	_remove_file(player_config_path)
	_remove_file(ai_settings_path)

	var boss_catalog := BossCatalog.new()
	var frost_profile := boss_catalog.profile("frost_giant")
	if not _check(boss_catalog.boss_ids().size() == 3 and frost_profile["name"] == "Frost Giant" and frost_profile["hp"] == 12, "BossCatalog profiles changed"):
		return
	frost_profile["hp"] = 0
	if not _check(boss_catalog.profile("frost_giant")["hp"] == 12, "BossCatalog exposed its mutable profile template"):
		return
	if not _check(boss_catalog.profile("missing")["name"] == "Blast King", "BossCatalog fallback changed"):
		return
	var duel_actor := DuelActorState.new(4, null, true, 3)
	duel_actor.hit_cooldown = 0.5
	duel_actor.tick_hit_cooldown(0.2)
	if not _check(duel_actor.health == 3 and not duel_actor.take_damage(1) and duel_actor.health == 2 and is_equal_approx(duel_actor.hit_cooldown, 0.3), "DuelActorState did not own duel health and cooldown state"):
		return
	var boss_timer_state := CharacterState.new({"skill_timer": 0.0, "skill_interval": 0.0})
	boss_timer_state.configure_boss("blast_king", "Blast King", 8, 5, 3, 5, 0.28, 0.75, 3.5)
	if not _check(not boss_timer_state.advance_boss_skill_timer(3.0) and boss_timer_state.advance_boss_skill_timer(0.5), "CharacterState did not own the Boss skill countdown"):
		return
	boss_timer_state.reset_boss_skill_timer()
	if not _check(is_equal_approx(boss_timer_state.boss_skill_interval(), 3.5) and is_equal_approx(boss_timer_state.boss_skill_time_left(), 3.5), "CharacterState did not restore the catalog Boss cooldown"):
		return

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
		"speed": 5,
		"bomb_max": 1,
		"bomb_range": 2,
		"bomb_placed_count": 0,
		"consumables": ["shield_potion", "dummy"],
		"selected_consumable_index": 1,
		"status": "Ready",
		"is_moving": false,
	}
	var state := CharacterState.new(data)
	var query := state.query()
	if not _check(query is CharacterQuery and state.query() == query and query.id() == 7 and query.cell() == Vector2i(3, 3), "CharacterState did not expose a stable typed query"):
		return
	data["hp"] = 2
	if not _check(query.health() == 2 and query.max_health() == 3 and query.selected_consumable_index() == 1, "CharacterQuery did not reflect live character state"):
		return
	var detached_consumables := query.consumables()
	detached_consumables.clear()
	if not _check(query.consumables().size() == 2 and query.has_consumable("dummy"), "CharacterQuery exposed mutable inventory storage"):
		return
	data["hp"] = 3
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
	if not _check(registry.query_at(0) == query and registry.queries().size() == 1 and registry.queries()[0] == query, "CharacterRegistry typed queries lost state order or identity"):
		return
	var compatibility_view := registry.data_view()
	compatibility_view.clear()
	if not _check(registry.count() == 1 and registry.state_at(0) == state and registry.by_id(7) == state, "CharacterRegistry exposed mutable collection ownership"):
		return
	if not _check(registry.unregister_last() == state and registry.is_empty(), "CharacterRegistry did not remove all indexes atomically"):
		return

	print("DOMAIN_MODEL_SMOKE_OK config_repository boss_catalog boss_skill_timer duel_actor_state map_state map_editor_document character_query character_state character_registry combat_rules")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false

func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
