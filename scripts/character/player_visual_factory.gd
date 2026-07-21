class_name PlayerVisualFactory
extends RefCounted

const CUSTOMIZATION_STRATEGY := preload("res://scripts/character/player_customization_strategy.gd")

func create(id: int, cell: Vector2i, material: Material, style_config: Variant) -> Dictionary:
	var style_data := CUSTOMIZATION_STRATEGY.style_data(style_config)
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

	var body := MeshHelpers.capsule(float(style_data["radius"]), float(style_data["height"]), material)
	body.position = Vector3(0, float(style_data["body_y"]), 0)
	visual_root.add_child(body)

	_add_head(visual_root, style_data)
	var visor_color: Color = style_data["visor_color"]
	_add_face(visual_root, style_data, visor_color)
	_add_theme_parts(visual_root, style_data)
	return {"root": root, "visual": visual_root}

func material_from_config(config: Dictionary) -> Material:
	var style_data := CUSTOMIZATION_STRATEGY.style_data(config)
	var body_color: Color = style_data["body_color"]
	return MeshHelpers.make_mat(body_color)

func style_id_from_config(config_or_style: Variant) -> String:
	return CUSTOMIZATION_STRATEGY.style_id(config_or_style)

func _add_head(parent: Node3D, style_data: Dictionary) -> void:
	var body_color: Color = style_data["body_color"]
	var head := MeshHelpers.sphere(float(style_data["radius"]) * 0.82, MeshHelpers.make_mat(body_color.lightened(0.10)))
	head.name = "Head"
	head.position = Vector3(0, float(style_data["body_y"]) + float(style_data["height"]) * 0.43, 0)
	parent.add_child(head)

func _add_face(parent: Node3D, style_data: Dictionary, face_color: Color) -> void:
	var theme := str(style_data.get("theme", "pilot"))
	if theme == "pilot":
		var visor_material := MeshHelpers.make_mat(face_color, true)
		var visor := MeshHelpers.box(Vector3(float(style_data["visor_w"]), 0.12, 0.08), visor_material)
		visor.name = "Visor"
		visor.position = Vector3(0, float(style_data["visor_y"]) + 0.17, -0.34)
		parent.add_child(visor)
		return
	var eye_material := MeshHelpers.make_mat(face_color, true)
	for x in [-0.12, 0.12]:
		var eye := MeshHelpers.sphere(0.045, eye_material)
		eye.name = "Eye"
		eye.scale.z = 0.36
		eye.position = Vector3(x, float(style_data["visor_y"]) + 0.16, -0.30)
		parent.add_child(eye)
	var nose_material := MeshHelpers.make_mat(Color(0.04, 0.035, 0.03))
	var nose := MeshHelpers.box(Vector3(0.08, 0.045, 0.035), nose_material)
	nose.name = "Nose"
	nose.position = Vector3(0, float(style_data["visor_y"]) + 0.08, -0.33)
	parent.add_child(nose)

func _add_theme_parts(parent: Node3D, style_data: Dictionary) -> void:
	var theme := str(style_data.get("theme", "pilot"))
	var accent: Color = style_data.get("accent_color", Color.WHITE)
	var body: Color = style_data.get("body_color", Color.WHITE)
	match theme:
		"fox":
			_add_ears(parent, accent, body, true)
			_add_tail(parent, body, accent, 0.28)
		"monkey":
			_add_round_ears(parent, body.lightened(0.20), accent)
			_add_tail(parent, body.darkened(0.10), accent, 0.18)
		"titan":
			_add_helmet(parent, accent)
			_add_backpack(parent, body.darkened(0.22), accent)
			_add_shoulder_pads(parent, accent.darkened(0.15))
		"scarf":
			_add_scarf(parent, accent)
			_add_hair_crest(parent, body.darkened(0.15))
		"firework":
			_add_hair_crest(parent, accent)
			_add_orbit_gems(parent, accent)
		"healer":
			_add_halo(parent, accent)
			_add_backpack(parent, body.lightened(0.12), accent)
		_:
			_add_backpack(parent, body.darkened(0.18), accent)

func _add_ears(parent: Node3D, outer: Color, inner: Color, pointed: bool) -> void:
	for x in [-0.20, 0.20]:
		var ear := _cone(0.12, 0.30, MeshHelpers.make_mat(outer))
		ear.name = "Ear"
		ear.position = Vector3(x, 1.24, -0.02)
		ear.rotation_degrees = Vector3(0, 0, -18 if x < 0 else 18)
		parent.add_child(ear)
		if pointed:
			var inset := _cone(0.055, 0.17, MeshHelpers.make_mat(inner.lightened(0.24)))
			inset.name = "EarInset"
			inset.position = Vector3(x, 1.23, -0.085)
			inset.rotation_degrees = ear.rotation_degrees
			parent.add_child(inset)

func _add_round_ears(parent: Node3D, outer: Color, inner: Color) -> void:
	for x in [-0.25, 0.25]:
		var ear := MeshHelpers.sphere(0.13, MeshHelpers.make_mat(outer))
		ear.name = "RoundEar"
		ear.scale.z = 0.36
		ear.position = Vector3(x, 1.11, -0.01)
		parent.add_child(ear)
		var inset := MeshHelpers.sphere(0.075, MeshHelpers.make_mat(inner.lightened(0.20)))
		inset.name = "RoundEarInset"
		inset.scale.z = 0.24
		inset.position = Vector3(x, 1.11, -0.08)
		parent.add_child(inset)

func _add_tail(parent: Node3D, tail_color: Color, tip_color: Color, width: float) -> void:
	var tail := MeshHelpers.capsule(width * 0.35, 0.72, MeshHelpers.make_mat(tail_color))
	tail.name = "Tail"
	tail.position = Vector3(0, 0.49, 0.42)
	tail.rotation_degrees = Vector3(72, 0, 0)
	parent.add_child(tail)
	var tip := MeshHelpers.sphere(width * 0.22, MeshHelpers.make_mat(tip_color.lightened(0.18)))
	tip.name = "TailTip"
	tip.position = Vector3(0, 0.35, 0.78)
	parent.add_child(tip)

func _add_helmet(parent: Node3D, color: Color) -> void:
	var helmet := MeshHelpers.sphere(0.34, MeshHelpers.make_mat(color.darkened(0.08)))
	helmet.name = "Helmet"
	helmet.scale.y = 0.62
	helmet.position = Vector3(0, 1.13, 0.01)
	parent.add_child(helmet)
	var ridge := MeshHelpers.box(Vector3(0.10, 0.12, 0.44), MeshHelpers.make_mat(color.lightened(0.10)))
	ridge.name = "HelmetRidge"
	ridge.position = Vector3(0, 1.25, -0.01)
	parent.add_child(ridge)

func _add_backpack(parent: Node3D, color: Color, accent: Color) -> void:
	var pack := MeshHelpers.box(Vector3(0.42, 0.46, 0.18), MeshHelpers.make_mat(color))
	pack.name = "Backpack"
	pack.position = Vector3(0, 0.68, 0.37)
	parent.add_child(pack)
	var latch := MeshHelpers.box(Vector3(0.22, 0.08, 0.035), MeshHelpers.make_mat(accent, true))
	latch.name = "BackpackLatch"
	latch.position = Vector3(0, 0.72, 0.47)
	parent.add_child(latch)

func _add_shoulder_pads(parent: Node3D, color: Color) -> void:
	for x in [-0.36, 0.36]:
		var pad := MeshHelpers.sphere(0.13, MeshHelpers.make_mat(color))
		pad.name = "ShoulderPad"
		pad.scale = Vector3(1.2, 0.55, 0.75)
		pad.position = Vector3(x, 0.87, -0.02)
		parent.add_child(pad)

func _add_scarf(parent: Node3D, color: Color) -> void:
	var wrap := MeshHelpers.box(Vector3(0.54, 0.08, 0.12), MeshHelpers.make_mat(color))
	wrap.name = "Scarf"
	wrap.position = Vector3(0, 0.94, -0.02)
	parent.add_child(wrap)
	var tail := MeshHelpers.box(Vector3(0.12, 0.32, 0.07), MeshHelpers.make_mat(color.darkened(0.08)))
	tail.name = "ScarfTail"
	tail.position = Vector3(-0.25, 0.80, 0.17)
	tail.rotation_degrees = Vector3(18, 0, -16)
	parent.add_child(tail)

func _add_hair_crest(parent: Node3D, color: Color) -> void:
	for index in range(3):
		var crest := _cone(0.075, 0.25 - index * 0.035, MeshHelpers.make_mat(color.lightened(index * 0.05)))
		crest.name = "HairCrest"
		crest.position = Vector3((index - 1) * 0.09, 1.30 - index * 0.02, -0.08 + index * 0.035)
		crest.rotation_degrees = Vector3(-12, 0, (index - 1) * 8)
		parent.add_child(crest)

func _add_orbit_gems(parent: Node3D, color: Color) -> void:
	var gem_colors := [color.lightened(0.14), color, color.darkened(0.12)]
	for index in range(3):
		var gem_color: Color = gem_colors[index]
		var gem := MeshHelpers.sphere(0.055, MeshHelpers.make_mat(gem_color, true))
		gem.name = "FireworkGem"
		var angle := TAU * float(index) / 3.0
		gem.position = Vector3(cos(angle) * 0.34, 1.05 + 0.05 * index, sin(angle) * 0.22)
		parent.add_child(gem)

func _add_halo(parent: Node3D, color: Color) -> void:
	var material := MeshHelpers.make_mat(color, true)
	for index in range(16):
		var bead := MeshHelpers.sphere(0.028, material)
		bead.name = "Halo"
		var angle := TAU * float(index) / 16.0
		bead.position = Vector3(cos(angle) * 0.28, 1.38, sin(angle) * 0.11)
		parent.add_child(bead)

func _cone(radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = 0.0
	mesh.height = height
	mesh.radial_segments = 18
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	return node
