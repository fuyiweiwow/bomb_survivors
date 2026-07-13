class_name ItemIconRenderer
extends SubViewportContainer

const MODEL_FACTORY := preload("res://scripts/item/powerup_model_factory.gd")
const ART_CATALOG := preload("res://scripts/core/game_art_catalog.gd")

var item_id := ""
var icon_viewport: SubViewport = null
var icon_model: Node3D = null

func setup(value: String, display_name: String) -> void:
	item_id = value
	tooltip_text = display_name
	custom_minimum_size = Vector2(68, 68)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_PASS

	icon_viewport = SubViewport.new()
	icon_viewport.size = Vector2i(112, 112)
	icon_viewport.transparent_bg = true
	icon_viewport.own_world_3d = true
	icon_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(icon_viewport)

	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.84, 0.92)
	environment.ambient_light_energy = 1.4
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	icon_viewport.add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.light_energy = 1.8
	light.rotation_degrees = Vector3(-52, -35, 0)
	icon_viewport.add_child(light)

	icon_model = MODEL_FACTORY.create(item_id, ART_CATALOG.new())
	icon_model.rotation_degrees = Vector3(0, -24, 0)
	icon_viewport.add_child(icon_model)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.35
	camera.position = Vector3(1.35, 1.05, 2.10)
	icon_viewport.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0, 0.14, 0), Vector3.UP)
	camera.current = true
