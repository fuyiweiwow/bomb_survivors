class_name BossCatalog
extends RefCounted

const DEFAULT_BOSS_ID := "blast_king"
const _PROFILES := {
	"blast_king": {
		"name": "Blast King",
		"hp": 8,
		"speed": 5,
		"range": 5,
		"bomb_max": 3,
		"move_interval": 0.28,
		"bomb_interval": 0.75,
		"skill_interval": 3.5,
	},
	"frost_giant": {
		"name": "Frost Giant",
		"hp": 12,
		"speed": 3,
		"range": 1,
		"bomb_max": 0,
		"move_interval": 0.48,
		"bomb_interval": 99.0,
		"skill_interval": 4.5,
	},
	"clone_demon": {
		"name": "Clone Demon",
		"hp": 6,
		"speed": 6,
		"range": 2,
		"bomb_max": 2,
		"move_interval": 0.20,
		"bomb_interval": 1.4,
		"skill_interval": 5.0,
	},
}

var _art_catalog: GameArtCatalog

func _init(art_catalog: GameArtCatalog = null) -> void:
	_art_catalog = art_catalog

func setup(art_catalog: GameArtCatalog) -> void:
	_art_catalog = art_catalog

func boss_ids() -> Array[String]:
	var ids: Array[String] = []
	for boss_id in _PROFILES.keys():
		ids.append(str(boss_id))
	return ids

func has_profile(boss_id: String) -> bool:
	return _PROFILES.has(boss_id)

func profile(boss_id: String) -> Dictionary:
	var resolved_id := boss_id if has_profile(boss_id) else DEFAULT_BOSS_ID
	var result := (_PROFILES[resolved_id] as Dictionary).duplicate(true)
	result["material"] = _material_for(resolved_id)
	return result

func _material_for(boss_id: String) -> Material:
	if _art_catalog == null:
		return null
	match boss_id:
		"frost_giant":
			return _art_catalog.mat_boss_frost
		"clone_demon":
			return _art_catalog.mat_boss_clone
		_:
			return _art_catalog.mat_boss_blast
