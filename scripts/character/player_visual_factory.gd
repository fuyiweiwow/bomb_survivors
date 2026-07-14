class_name PlayerVisualFactory
extends RefCounted

func create(id: int, cell: Vector2i, material: Material, style: String) -> Dictionary:
	var style_data := _style_data(style)
	var root := Area3D.new()
	root.name = "Player%d_3D" % id
	root.position = Constants.grid_to_world(cell)
	root.collision_layer = 2
	root.collision_mask = 2
	root.monitoring = true
	root.monitorable = true

	var collision_shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = style_data["radius"]
	capsule_shape.height = style_data["height"]
	collision_shape.shape = capsule_shape
	collision_shape.position = Vector3(0, style_data["body_y"], 0)
	root.add_child(collision_shape)

	var visual_root := Node3D.new()
	visual_root.name = "PlayerVisuals"
	root.add_child(visual_root)

	var body := MeshHelpers.capsule(style_data["radius"], style_data["height"], material)
	body.position = Vector3(0, style_data["body_y"], 0)
	visual_root.add_child(body)

	var visor_material := MeshHelpers.make_mat(style_data["visor_color"], true)
	var visor := MeshHelpers.box(Vector3(style_data["visor_w"], 0.12, 0.08), visor_material)
	visor.position = Vector3(0, style_data["visor_y"], -0.34)
	visual_root.add_child(visor)
	return {"root": root, "visual": visual_root}

func material_from_config(config: Dictionary) -> Material:
	var color := Color(0.18, 0.48, 0.95)
	if str(config.get("gender", "male")) == "female":
		color = Color(0.95, 0.27, 0.22)
	return MeshHelpers.make_mat(color)

func _style_data(style: String) -> Dictionary:
	match style:
		"female":
			return {"radius": 0.31, "height": 0.98, "body_y": 0.58, "visor_y": 0.78, "visor_w": 0.52, "visor_color": Color(1.0, 0.58, 0.25)}
		"ai":
			return {"radius": 0.36, "height": 1.08, "body_y": 0.63, "visor_y": 0.83, "visor_w": 0.48, "visor_color": Color(0.02, 0.03, 0.04)}
		"boss":
			return {"radius": 0.40, "height": 1.18, "body_y": 0.68, "visor_y": 0.90, "visor_w": 0.56, "visor_color": Color(1.0, 0.82, 0.18)}
		_:
			return {"radius": 0.35, "height": 1.05, "body_y": 0.62, "visor_y": 0.82, "visor_w": 0.46, "visor_color": Color(0.2, 0.85, 1.0)}
