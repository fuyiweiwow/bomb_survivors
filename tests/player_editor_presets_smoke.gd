extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/editor/player_editor.tscn") as PackedScene
	if packed == null:
		_fail("Could not load player editor scene")
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	for preset_id in PlayerCustomizationStrategy.PRESET_ORDER:
		var index := PlayerCustomizationStrategy.PRESET_ORDER.find(preset_id)
		scene.call("_on_preset_selected", index)
		await process_frame
		var preview = scene.get("preview_character_root")
		if not is_instance_valid(preview):
			_fail("Preset %s did not create a preview character" % preset_id)
			return
	scene.queue_free()
	await process_frame
	print("PLAYER_EDITOR_PRESETS_SMOKE_OK all_presets_preview")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
