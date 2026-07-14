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

func take_damage(amount: int) -> bool:
	health = maxi(health - maxi(amount, 0), 0)
	return health <= 0
