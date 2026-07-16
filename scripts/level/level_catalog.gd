class_name LevelCatalog
extends RefCounted

const STANDALONE_PROFILE := {
	"id": "",
	"number": 0,
	"name": "Survival",
	"description": "Classic seven-wave survival mode.",
	"max_waves": 7,
	"wave_duration": 30.0,
	"tutorial": false,
	"difficulty_override": "",
	"map_position": Vector2(0.0, 0.0),
}

const LEVELS := [
	{
		"id": "tutorial_meadow",
		"number": 1,
		"name": "Tutorial Meadow",
		"description": "Learn movement, bombs, and backpack items in two short waves.",
		"max_waves": 2,
		"wave_duration": 18.0,
		"tutorial": true,
		"difficulty_override": "easy",
		"map_position": Vector2(0.16, 0.70),
	},
	{
		"id": "forest_path",
		"number": 2,
		"name": "Forest Path",
		"description": "Track hidden enemies through three waves of dense cover.",
		"max_waves": 3,
		"wave_duration": 24.0,
		"tutorial": false,
		"difficulty_override": "",
		"map_position": Vector2(0.32, 0.54),
	},
	{
		"id": "lava_basin",
		"number": 3,
		"name": "Lava Basin",
		"description": "Use shields and wings to survive four hazardous waves.",
		"max_waves": 4,
		"wave_duration": 26.0,
		"tutorial": false,
		"difficulty_override": "",
		"map_position": Vector2(0.50, 0.63),
	},
	{
		"id": "storm_ruins",
		"number": 4,
		"name": "Storm Ruins",
		"description": "Five waves where weather and broken sightlines shape every fight.",
		"max_waves": 5,
		"wave_duration": 27.0,
		"tutorial": false,
		"difficulty_override": "",
		"map_position": Vector2(0.64, 0.43),
	},
	{
		"id": "iron_labyrinth",
		"number": 5,
		"name": "Iron Labyrinth",
		"description": "Break through crowded routes and endure six escalating waves.",
		"max_waves": 6,
		"wave_duration": 28.0,
		"tutorial": false,
		"difficulty_override": "",
		"map_position": Vector2(0.78, 0.55),
	},
	{
		"id": "final_rift",
		"number": 6,
		"name": "Final Rift",
		"description": "The complete seven-wave survival run and every boss encounter.",
		"max_waves": 7,
		"wave_duration": 30.0,
		"tutorial": false,
		"difficulty_override": "",
		"map_position": Vector2(0.88, 0.28),
	},
]

func levels() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_profile in LEVELS:
		result.append((raw_profile as Dictionary).duplicate(true))
	return result

func profile(level_id: String) -> Dictionary:
	for raw_profile in LEVELS:
		var level := raw_profile as Dictionary
		if str(level["id"]) == level_id:
			return level.duplicate(true)
	return STANDALONE_PROFILE.duplicate(true)

func standalone_profile() -> Dictionary:
	return STANDALONE_PROFILE.duplicate(true)

func contains(level_id: String) -> bool:
	return not level_id.is_empty() and not profile(level_id)["id"].is_empty()

func next_level_id(level_id: String) -> String:
	for index in range(LEVELS.size() - 1):
		if str((LEVELS[index] as Dictionary)["id"]) == level_id:
			return str((LEVELS[index + 1] as Dictionary)["id"])
	return ""
