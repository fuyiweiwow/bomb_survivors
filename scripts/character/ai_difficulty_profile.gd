class_name AIDifficultyProfile
extends RefCounted

const PROFILES := {
	"easy": {
		"speed": 3,
		"bomb_capacity": 1,
		"bomb_range": 1,
		"move_interval": Vector2(0.50, 0.75),
		"bomb_interval": Vector2(3.0, 4.2),
		"aggression_score": 9.0,
	},
	"normal": {
		"speed": 5,
		"bomb_capacity": 2,
		"bomb_range": 2,
		"move_interval": Vector2(0.22, 0.40),
		"bomb_interval": Vector2(1.6, 2.6),
		"aggression_score": 26.0,
	},
	"hard": {
		"speed": 6,
		"bomb_capacity": 3,
		"bomb_range": 3,
		"move_interval": Vector2(0.14, 0.24),
		"bomb_interval": Vector2(0.85, 1.35),
		"aggression_score": 40.0,
	},
}

static func profile(difficulty: String) -> Dictionary:
	return (PROFILES.get(difficulty, PROFILES["normal"]) as Dictionary).duplicate(true)

static func aggression_score(difficulty: String) -> float:
	return float(profile(difficulty)["aggression_score"])

static func random_interval(profile_data: Dictionary, key: String) -> float:
	var bounds := profile_data[key] as Vector2
	return randf_range(bounds.x, bounds.y)
