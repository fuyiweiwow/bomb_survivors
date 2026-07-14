class_name CharacterEffectState
extends RefCounted

var data: Dictionary

func _init(character_data: Dictionary) -> void:
	data = character_data

func shield_count() -> int:
	return int(data.get("shield", 0))

func shield_time_left() -> float:
	return float(data.get("shield_timer", 0.0))

func has_shield() -> bool:
	return shield_count() > 0

func grant_shield(amount: int, duration: float, maximum := 5) -> void:
	data["shield"] = clampi(shield_count() + amount, 0, maximum)
	data["shield_timer"] = duration if has_shield() else 0.0

func consume_shield() -> void:
	data["shield"] = maxi(shield_count() - 1, 0)
	if not has_shield():
		data["shield_timer"] = 0.0

func tick_shield(delta: float) -> bool:
	if not has_shield():
		data["shield_timer"] = 0.0
		return false
	data["shield_timer"] = maxf(shield_time_left() - delta, 0.0)
	if shield_time_left() > 0.0:
		return false
	data["shield"] = 0
	return true

func grant_invincibility(duration: float) -> void:
	data["invincible_timer"] = maxf(duration, 0.0)

func invincibility_time_left() -> float:
	return float(data.get("invincible_timer", 0.0))

func is_invincible() -> bool:
	return invincibility_time_left() > 0.0

func grant_wings(duration: float) -> void:
	data["wings_timer"] = maxf(duration, 0.0)

func wings_time_left() -> float:
	return float(data.get("wings_timer", 0.0))

func has_wings() -> bool:
	return wings_time_left() > 0.0

func grant_football(duration: float) -> void:
	data["football_timer"] = maxf(duration, 0.0)

func football_time_left() -> float:
	return float(data.get("football_timer", 0.0))

func has_football() -> bool:
	return football_time_left() > 0.0

func apply_slow(duration: float) -> void:
	data["slow_timer"] = maxf(float(data.get("slow_timer", 0.0)), duration)

func slow_time_left() -> float:
	return float(data.get("slow_timer", 0.0))

func is_slowed() -> bool:
	return slow_time_left() > 0.0

func freeze(duration: float) -> void:
	data["frozen_timer"] = maxf(float(data.get("frozen_timer", 0.0)), duration)

func frozen_time_left() -> float:
	return float(data.get("frozen_timer", 0.0))

func is_frozen() -> bool:
	return frozen_time_left() > 0.0

func imprison(duration: float) -> void:
	data["prison_timer"] = maxf(float(data.get("prison_timer", 0.0)), duration)
	freeze(duration)

func prison_time_left() -> float:
	return float(data.get("prison_timer", 0.0))

func is_imprisoned() -> bool:
	return prison_time_left() > 0.0

func duel_return_grace_time() -> float:
	return float(data.get("duel_return_grace", 0.0))

func grant_duel_return_grace(duration: float) -> void:
	data["duel_return_grace"] = maxf(duration, 0.0)

func tick_global(delta: float) -> void:
	data["duel_return_grace"] = maxf(duel_return_grace_time() - delta, 0.0)
	tick_shield(delta)

func tick_active(delta: float) -> Dictionary:
	var had_wings := has_wings()
	data["invincible_timer"] = maxf(invincibility_time_left() - delta, 0.0)
	data["wings_timer"] = maxf(wings_time_left() - delta, 0.0)
	data["football_timer"] = maxf(football_time_left() - delta, 0.0)
	data["slow_timer"] = maxf(slow_time_left() - delta, 0.0)
	data["frozen_timer"] = maxf(frozen_time_left() - delta, 0.0)
	data["prison_timer"] = maxf(prison_time_left() - delta, 0.0)
	return {"wings_expired": had_wings and not has_wings()}

func advance_fire_exposure(delta: float) -> float:
	data["fire_exposure_time"] = float(data.get("fire_exposure_time", 0.0)) + delta
	return float(data["fire_exposure_time"])

func reset_fire_exposure() -> void:
	data["fire_exposure_time"] = 0.0

func fire_exposure_time() -> float:
	return float(data.get("fire_exposure_time", 0.0))

func reset_lava_exposure() -> void:
	data["lava_time"] = 0.0
	data["lava_eruption_time"] = 0.0

func reset_lava_burn() -> void:
	data["lava_time"] = 0.0

func reset_lava_pressure() -> void:
	data["lava_eruption_time"] = 0.0

func advance_lava_burn(delta: float) -> float:
	data["lava_time"] = float(data.get("lava_time", 0.0)) + delta
	return float(data["lava_time"])

func lava_burn_time() -> float:
	return float(data.get("lava_time", 0.0))

func advance_lava_pressure(delta: float) -> float:
	data["lava_eruption_time"] = float(data.get("lava_eruption_time", 0.0)) + delta
	return float(data["lava_eruption_time"])

func lava_pressure_time() -> float:
	return float(data.get("lava_eruption_time", 0.0))
