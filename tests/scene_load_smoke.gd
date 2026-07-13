extends SceneTree

const SCENES := [
	"res://scenes/menu/main_menu.tscn",
	"res://scenes/game/main_3d.tscn",
	"res://scenes/editor/map_editor.tscn",
	"res://scenes/editor/player_editor.tscn",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for scene_path in SCENES:
		var packed := load(scene_path) as PackedScene
		if packed == null:
			_fail("Could not load %s" % scene_path)
			return
		var scene := packed.instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		if scene_path.ends_with("main_menu.tscn"):
			if scene.get("guide_button") == null or scene.get("guide_overlay") == null:
				_fail("Main menu did not expose the game guide")
				return
		elif scene_path.ends_with("main_3d.tscn"):
			var game = scene.get_node_or_null("GameManager3D")
			if game == null or game.player_commands == null or game.progression_coordinator == null or game.audio_manager == null or game.duel_manager == null:
				_fail("Game scene did not expose the modular runtime")
				return
		elif scene_path.ends_with("map_editor.tscn"):
			if scene.get("art") == null or scene.get("art").mat_wall == null:
				_fail("Map editor did not use the shared art catalog")
				return
		scene.queue_free()
		await process_frame
	print("SCENE_LOAD_SMOKE_OK menu game map_editor player_editor")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
