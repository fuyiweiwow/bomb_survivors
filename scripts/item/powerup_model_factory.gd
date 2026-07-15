class_name PowerupModelFactory
extends RefCounted

static func create(item_id: String, art) -> Node3D:
	var root := Node3D.new()
	root.name = "Powerup_%s" % item_id
	_add_cylinder(root, 0.32, 0.10, Vector3(0, -0.20, 0), MeshHelpers.make_mat(Color(0.08, 0.09, 0.10)))
	var material: Material = _material_for(item_id, art)

	match item_id:
		"speed":
			_add_box(root, Vector3(0.18, 0.12, 0.48), Vector3(0, 0.02, 0.02), material)
			_add_box(root, Vector3(0.42, 0.14, 0.22), Vector3(0, 0.04, -0.30), material, Vector3(0, 45, 0))
			_add_box(root, Vector3(0.36, 0.08, 0.12), Vector3(0, -0.02, 0.34), MeshHelpers.make_mat(Color(0.45, 1.0, 0.95), true))
		"bomb":
			_add_sphere(root, 0.26, Vector3(0, 0.05, 0), art.mat_bomb)
			_add_cylinder(root, 0.045, 0.28, Vector3(0.12, 0.30, -0.08), MeshHelpers.make_mat(Color(0.95, 0.65, 0.18), true), Vector3(0, 0, 35))
			_add_sphere(root, 0.08, Vector3(0.22, 0.42, -0.12), MeshHelpers.make_mat(Color(1.0, 0.85, 0.20), true))
		"range":
			_add_cylinder(root, 0.18, 0.52, Vector3(0, 0.10, 0), material)
			var flame := _add_sphere(root, 0.20, Vector3(0, 0.42, 0), MeshHelpers.make_mat(Color(1.0, 0.40, 0.08), true))
			flame.scale = Vector3(0.75, 1.25, 0.75)
			var glow := _add_sphere(root, 0.34, Vector3(0, 0.12, 0), MeshHelpers.make_mat(Color(1.0, 0.18, 0.05), true, art.tex_powerup))
			glow.scale = Vector3(1.0, 0.45, 1.0)
		"shield":
			_add_sphere(root, 0.20, Vector3(0, 0.12, 0), material)
			_add_box(root, Vector3(0.46, 0.08, 0.12), Vector3(0, 0.12, -0.34), material)
			_add_box(root, Vector3(0.46, 0.08, 0.12), Vector3(0, 0.12, 0.34), material)
			_add_box(root, Vector3(0.12, 0.08, 0.46), Vector3(-0.34, 0.12, 0), material)
			_add_box(root, Vector3(0.12, 0.08, 0.46), Vector3(0.34, 0.12, 0), material)
		"detonator":
			_add_box(root, Vector3(0.42, 0.18, 0.30), Vector3(0, 0.12, 0), MeshHelpers.make_mat(Color(0.34, 0.38, 0.42)))
			_add_box(root, Vector3(0.28, 0.20, 0.18), Vector3(0, 0.28, -0.02), art.mat_range)
			_add_sphere(root, 0.09, Vector3(0, 0.42, -0.02), art.mat_bomb_power)
		"glue":
			var puddle := _add_cylinder(root, 0.34, 0.04, Vector3(0, -0.10, 0), art.mat_glue)
			puddle.scale = Vector3(1.0, 1.0, 0.72)
			_add_cylinder(root, 0.16, 0.42, Vector3(0, 0.18, 0), art.mat_glue)
			_add_cylinder(root, 0.09, 0.14, Vector3(0, 0.46, 0), art.mat_consumable)
		"shield_potion":
			_add_cylinder(root, 0.18, 0.34, Vector3(0, 0.14, 0), art.mat_shield)
			_add_sphere(root, 0.18, Vector3(0, 0.08, 0), art.mat_shield)
			_add_cylinder(root, 0.10, 0.14, Vector3(0, 0.39, 0), art.mat_bomb_power)
			_add_box(root, Vector3(0.28, 0.07, 0.08), Vector3(0, 0.15, -0.18), MeshHelpers.make_mat(Color(0.78, 0.92, 1.0), true))
		"invincible_star":
			_add_sphere(root, 0.20, Vector3(0, 0.18, 0), art.mat_bomb_power)
			for angle in range(0, 360, 72):
				var radians := deg_to_rad(float(angle))
				_add_box(root, Vector3(0.13, 0.30, 0.10), Vector3(cos(radians) * 0.27, 0.18 + sin(radians) * 0.27, 0), art.mat_bomb_power, Vector3(0, 0, 90.0 - angle))
		"dummy":
			_add_capsule(root, 0.18, 0.54, Vector3(0, 0.15, 0), material)
			_add_sphere(root, 0.16, Vector3(0, 0.50, 0), material)
			_add_box(root, Vector3(0.18, 0.04, 0.04), Vector3(0, 0.52, -0.15), MeshHelpers.make_mat(Color(0.12, 0.08, 0.04)))
		"oil_barrel":
			_add_cylinder(root, 0.25, 0.58, Vector3(0, 0.12, 0), art.mat_oil)
			_add_cylinder(root, 0.27, 0.08, Vector3(0, 0.14, 0), art.mat_bomb_power)
		"rock":
			var rock := _add_sphere(root, 0.28, Vector3(0, 0.12, 0), art.mat_wall)
			rock.scale = Vector3(1.0, 0.78, 0.92)
			_add_sphere(root, 0.08, Vector3(0.18, 0.24, -0.08), art.mat_wall)
			_add_sphere(root, 0.07, Vector3(-0.16, 0.05, 0.12), art.mat_wall)
		"wings":
			_add_box(root, Vector3(0.10, 0.40, 0.34), Vector3(-0.22, 0.20, 0), material, Vector3(0, 0, -25))
			_add_box(root, Vector3(0.10, 0.40, 0.34), Vector3(0.22, 0.20, 0), material, Vector3(0, 0, 25))
			_add_sphere(root, 0.12, Vector3(0, 0.18, 0), art.mat_bomb_power)
		"football_shoes":
			for x in [-0.18, 0.18]:
				_add_box(root, Vector3(0.22, 0.16, 0.42), Vector3(x, 0.02, -0.05), art.mat_bomb_power)
				_add_box(root, Vector3(0.22, 0.30, 0.18), Vector3(x, 0.20, 0.08), art.mat_consumable)
		"prison":
			_add_sphere(root, 0.15, Vector3(0, 0.18, 0), art.mat_range)
			_add_box(root, Vector3(0.70, 0.10, 0.13), Vector3(0, 0.18, 0), art.mat_bomb_power)
			_add_box(root, Vector3(0.13, 0.10, 0.70), Vector3(0, 0.18, 0), art.mat_bomb_power)
			for offset in [Vector3(0.34, 0.18, 0), Vector3(-0.34, 0.18, 0), Vector3(0, 0.18, 0.34), Vector3(0, 0.18, -0.34)]:
				_add_sphere(root, 0.09, offset, art.mat_range)
		"duel":
			_add_capsule(root, 0.14, 0.44, Vector3(-0.15, 0.18, 0), art.mat_shield)
			_add_capsule(root, 0.14, 0.44, Vector3(0.15, 0.18, 0), art.mat_range)
			_add_box(root, Vector3(0.58, 0.08, 0.10), Vector3(0, 0.18, 0), art.mat_bomb_power, Vector3(0, 0, 45))
			_add_box(root, Vector3(0.58, 0.08, 0.10), Vector3(0, 0.18, 0), art.mat_bomb_power, Vector3(0, 0, -45))
		_:
			_add_sphere(root, 0.28, Vector3.ZERO, material)
	return root

static func _material_for(item_id: String, art) -> Material:
	match item_id:
		"speed": return art.mat_speed
		"bomb": return art.mat_bomb_power
		"range": return art.mat_range
		"shield", "shield_potion": return art.mat_shield
		"dummy": return art.mat_dummy
	return art.mat_consumable

static func _add_box(root: Node3D, size: Vector3, position: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshHelpers.box(size, material)
	node.position = position
	node.rotation_degrees = rotation
	root.add_child(node)
	return node

static func _add_sphere(root: Node3D, radius: float, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshHelpers.sphere(radius, material)
	node.position = position
	root.add_child(node)
	return node

static func _add_capsule(root: Node3D, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshHelpers.capsule(radius, height, material)
	node.position = position
	root.add_child(node)
	return node

static func _add_cylinder(root: Node3D, radius: float, height: float, position: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshHelpers.cylinder(radius, height, material)
	node.position = position
	node.rotation_degrees = rotation
	root.add_child(node)
	return node
