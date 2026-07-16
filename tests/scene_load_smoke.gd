extends SceneTree

const SCENES := [
	"res://scenes/menu/main_menu.tscn",
	"res://scenes/menu/world_map.tscn",
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
			if scene.get("guide_button") == null or scene.get("guide_overlay") == null or not scene.get("config_repository") is GameConfigRepository:
				_fail("Main menu did not expose the game guide")
				return
		elif scene_path.ends_with("world_map.tscn"):
			if not scene is WorldMap or scene.get("level_buttons") == null or (scene.get("level_buttons") as Dictionary).size() != 6:
				_fail("World map did not expose six level nodes")
				return
		elif scene_path.ends_with("main_3d.tscn"):
			var game = scene.get_node_or_null("GameManager3D")
			if game == null or game.player_commands == null or game.progression_coordinator == null or game.audio_manager == null or game.duel_manager == null:
				_fail("Game scene did not expose the modular runtime")
				return
		elif scene_path.ends_with("map_editor.tscn"):
			var editor_document = scene.get("document")
			var editor_picker = scene.get("picker")
			var editor_toolbar = scene.get("toolbar")
			if not editor_document is MapEditorDocument or not editor_picker is MapEditorPicker or not editor_toolbar is MapEditorToolbar:
				_fail("Map editor did not expose its document, picker, and toolbar components")
				return
			if not editor_toolbar.handles_pointer(Vector2(10, 10), 600.0) or editor_toolbar.handles_pointer(Vector2(10, 300), 600.0):
				_fail("Map editor toolbar pointer bounds changed")
				return
			if scene.get("art") == null or scene.get("art").mat_wall == null:
				_fail("Map editor did not use the shared art catalog")
				return
			var editor_map_root := scene.get("map_root") as Node3D
			var editor_ground := editor_map_root.get_node_or_null("GroundCell_1_1") as MeshInstance3D if editor_map_root != null else null
			if editor_ground == null or not is_equal_approx(float(editor_ground.get_meta("logical_cell_size", 0.0)), Constants.TILE_SIZE):
				_fail("Map editor did not expose the refined logical ground cells")
				return
			var editor_grid := scene.get("grid") as Array
			editor_grid[5][5] = Constants.Cell.WALL
			editor_grid[5][6] = Constants.Cell.CRATE
			scene.call("_refresh_view")
			editor_map_root = scene.get("map_root") as Node3D
			var editor_wall := editor_map_root.get_node_or_null("Wall_5_5") as MeshInstance3D
			var editor_crate := editor_map_root.get_node_or_null("Crate_6_5") as MeshInstance3D
			if editor_wall == null or editor_crate == null:
				_fail("Map editor did not refresh one-cell wall and crate elements")
				return
			var editor_wall_mesh := editor_wall.mesh as CylinderMesh
			var editor_crate_mesh := editor_crate.mesh as BoxMesh
			if editor_wall_mesh.bottom_radius * 2.0 > Constants.TILE_SIZE or editor_crate_mesh.size.x > Constants.TILE_SIZE:
				_fail("Map editor elements exceed one refined logical cell")
				return
		elif scene_path.ends_with("player_editor.tscn"):
			if not scene.get("config_repository") is GameConfigRepository:
				_fail("Player editor did not use the shared configuration repository")
				return
		scene.queue_free()
		await process_frame
	print("SCENE_LOAD_SMOKE_OK menu world_map game map_editor player_editor")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
