class_name DuelItemController
extends Node

signal changed
signal finished(player_won: bool)
signal lava_relocated

const SHIELD_DURATION := 5.0
const INVINCIBLE_DURATION := 5.0
const SLOW_DURATION := 3.0
const PRISON_DURATION := 4.0
const FOOTBALL_DURATION := 8.0
const WING_BOOST := 4.8
const ACTIVE_ITEM_IDS := ["detonator", "glue", "shield_potion", "invincible_star", "oil_barrel", "rock", "wings", "football_shoes", "prison"]

var game: Node
var arena: Node3D
var actors: Array[DuelActorState] = []
var item_status := ""
var item_status_timer := 0.0

func setup(game_manager: Node, duel_arena: Node3D, duel_actors: Array[DuelActorState]) -> void:
	game = game_manager
	arena = duel_arena
	actors = duel_actors

func tick(delta: float) -> void:
	item_status_timer = maxf(item_status_timer - delta, 0.0)
	if item_status_timer <= 0.0 and not item_status.is_empty():
		item_status = ""
		changed.emit()

func handle_key(keycode: Key) -> bool:
	match keycode:
		KEY_E:
			use_selected_item()
		KEY_Q:
			cycle_item()
		KEY_1, KEY_2, KEY_3:
			select_item(int(keycode) - int(KEY_1))
		_:
			return false
	return true

func use_selected_item() -> bool:
	if actors.is_empty():
		return false
	var state := game.character_state_at(actors[0].player_index) as CharacterState
	var item_id: String = game.inventory_manager.selected_item(state)
	if item_id.is_empty():
		_set_status("Backpack empty")
		return false
	if item_id == "dummy":
		_set_status("Dummy revives you automatically")
		return false
	if item_id == "duel":
		_set_status("Duel Token cannot start a nested duel")
		return false
	if not _apply_item(item_id, actors[0], actors[1]):
		return false
	game.inventory_manager.consume_selected(state)
	game.audio_manager.play("confirm")
	_spawn_activation(actors[0].character_node.position)
	changed.emit()
	return true

func cycle_item() -> String:
	var state := game.character_state_at(actors[0].player_index) as CharacterState
	var item_id: String = game.inventory_manager.cycle(state)
	_set_status("Selected %s" % _item_name(item_id) if not item_id.is_empty() else "Backpack empty")
	return item_id

func select_item(slot_index: int) -> String:
	var state := game.character_state_at(actors[0].player_index) as CharacterState
	var item_id: String = game.inventory_manager.select_slot(state, slot_index)
	_set_status("Selected %s" % _item_name(item_id) if not item_id.is_empty() else "Bag slot %d empty" % (slot_index + 1))
	return item_id

func damage_actor(target: DuelActorState, amount: int) -> bool:
	var health_before := target.health
	var defeated := target.take_damage(amount)
	if target.health == health_before:
		game.audio_manager.play("shield")
		changed.emit()
		return false
	if defeated and _consume_dummy(target):
		return false
	changed.emit()
	return defeated

func backpack_text() -> String:
	var state := game.character_state_at(actors[0].player_index) as CharacterState
	var items := state.query().consumables()
	var selected := state.query().selected_consumable_index()
	var slots: Array[String] = []
	for index in range(InventoryManager.MAX_ITEMS):
		var name := _item_name(str(items[index])) if index < items.size() else "Empty"
		slots.append("[%d %s]" % [index + 1, name] if index == selected and index < items.size() else "%d %s" % [index + 1, name])
	return "  ".join(slots)

func actor_effects(actor: DuelActorState) -> String:
	var effects: Array[String] = ["WINGS UNLIMITED"]
	if actor.shield_count > 0:
		effects.append("SHIELD %d" % actor.shield_count)
	if actor.invincible_timer > 0.0:
		effects.append("STAR %.1fs" % actor.invincible_timer)
	if actor.prison_timer > 0.0:
		effects.append("PRISON %.1fs" % actor.prison_timer)
	return " · ".join(effects)

func _apply_item(item_id: String, actor: DuelActorState, target: DuelActorState) -> bool:
	match item_id:
		"detonator":
			var defeated := damage_actor(target, 1)
			_set_status("Detonator shockwave")
			if defeated:
				finished.emit(actor.human)
			return true
		"glue":
			target.slow_timer = maxf(target.slow_timer, SLOW_DURATION)
			_set_status("Opponent slowed for %.0fs" % SLOW_DURATION)
			return true
		"shield_potion":
			actor.grant_shield(SHIELD_DURATION)
			_set_status("Shield ready for %.0fs" % SHIELD_DURATION)
			return true
		"invincible_star":
			actor.invincible_timer = INVINCIBLE_DURATION
			_set_status("Invincible for %.0fs" % INVINCIBLE_DURATION)
			return true
		"oil_barrel":
			arena.place_lava_near(target.character_node.position.x)
			lava_relocated.emit()
			_set_status("Lava moved near opponent")
			return true
		"rock":
			var rock_defeated := damage_actor(target, 1)
			_set_status("Rock strike")
			if rock_defeated:
				finished.emit(actor.human)
			return true
		"wings":
			actor.airborne = true
			actor.diving = false
			actor.vertical_velocity = maxf(actor.vertical_velocity, WING_BOOST)
			_set_status("Wing boost")
			return true
		"football_shoes":
			actor.football_timer = FOOTBALL_DURATION
			_set_status("Movement boosted for %.0fs" % FOOTBALL_DURATION)
			return true
		"prison":
			target.prison_timer = maxf(target.prison_timer, PRISON_DURATION)
			_set_status("Opponent imprisoned for %.0fs" % PRISON_DURATION)
			return true
	return false

func _consume_dummy(actor: DuelActorState) -> bool:
	var state := game.character_state_at(actor.player_index) as CharacterState
	if state == null or not game.inventory_manager.consume_item(state, "dummy"):
		return false
	actor.restore_with_dummy()
	_set_status("Dummy restored %s" % ("you" if actor.human else "the opponent"))
	game.audio_manager.play("confirm")
	return true

func _set_status(text: String) -> void:
	item_status = text
	item_status_timer = 2.4
	changed.emit()

func _item_name(item_id: String) -> String:
	return game.powerup_manager.item_display_name(item_id)

func _spawn_activation(position: Vector3) -> void:
	var flash := MeshHelpers.sphere(0.38, MeshHelpers.make_mat(Color(0.30, 0.86, 1.0, 0.72), true))
	flash.name = "DuelItemActivation"
	flash.position = position + Vector3(0, 0.50, 0)
	arena.add_child(flash)
	var tween := create_tween().bind_node(flash).set_parallel()
	tween.tween_property(flash, "scale", Vector3(3.0, 3.0, 3.0), 0.24)
	tween.tween_property(flash, "transparency", 1.0, 0.24)
	tween.set_parallel(false)
	tween.tween_callback(flash.queue_free)
