class_name DuelArenaCatalog
extends RefCounted

const LAVA_RIFT := preload("res://scripts/duel/lava_rift_arena.gd")
const ARENA_BUILDERS := {
	"lava_rift": LAVA_RIFT,
}

func arena_ids() -> Array[String]:
	var result: Array[String] = []
	for arena_id in ARENA_BUILDERS.keys():
		result.append(str(arena_id))
	return result

func create_random(art, origin: Vector3) -> Dictionary:
	var ids := arena_ids()
	if ids.is_empty():
		return {}
	return create(ids.pick_random(), art, origin)

func create(arena_id: String, art, origin: Vector3) -> Dictionary:
	var script: Script = ARENA_BUILDERS.get(arena_id)
	if script == null:
		return {}
	var arena = script.new()
	arena.setup(art, origin)
	return {"id": arena_id, "node": arena}
