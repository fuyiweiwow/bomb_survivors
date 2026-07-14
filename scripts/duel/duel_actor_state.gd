class_name DuelActorState
extends RefCounted

var player_index: int
var character_node: Node3D
var human: bool
var health: int
var max_health: int
var airborne := false
var vertical_velocity := 0.0
var move_axis := 0.0
var glide := false
var dive_requested := false
var diving := false
var lava_charge := 0.0
var hit_cooldown := 0.0
var shield_count := 0
var shield_timer := 0.0
var invincible_timer := 0.0
var slow_timer := 0.0
var prison_timer := 0.0
var football_timer := 0.0

func _init(
	p_player_index: int,
	p_character_node: Node3D,
	p_human: bool,
	p_max_health: int
) -> void:
	player_index = p_player_index
	character_node = p_character_node
	human = p_human
	max_health = maxi(p_max_health, 1)
	health = max_health

func tick_hit_cooldown(delta: float) -> void:
	hit_cooldown = maxf(hit_cooldown - delta, 0.0)
	shield_timer = maxf(shield_timer - delta, 0.0)
	if shield_timer <= 0.0:
		shield_count = 0
	invincible_timer = maxf(invincible_timer - delta, 0.0)
	slow_timer = maxf(slow_timer - delta, 0.0)
	prison_timer = maxf(prison_timer - delta, 0.0)
	football_timer = maxf(football_timer - delta, 0.0)

func movement_multiplier() -> float:
	if prison_timer > 0.0:
		return 0.0
	var multiplier := 0.55 if slow_timer > 0.0 else 1.0
	if football_timer > 0.0:
		multiplier *= 1.35
	return multiplier

func grant_shield(duration: float) -> void:
	shield_count = mini(shield_count + 1, Constants.MAX_SHIELD_STACKS)
	shield_timer = maxf(duration, shield_timer)

func restore_with_dummy() -> void:
	health = mini(2, max_health)
	hit_cooldown = 1.0

func take_damage(amount: int) -> bool:
	if invincible_timer > 0.0:
		return false
	if shield_count > 0:
		shield_count -= 1
		if shield_count <= 0:
			shield_timer = 0.0
		return false
	health = maxi(health - maxi(amount, 0), 0)
	return health <= 0
