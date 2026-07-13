extends Node

var _game: Node

func setup(game_manager: Node):
	_game = game_manager

func spawn_powerup(cell: Vector2i):
	var r := randf()
	var ptype := ""
	var mat: Material = null
	if r < 0.23:
		ptype = "speed"
		mat = _game.art.mat_speed
	elif r < 0.46:
		ptype = "bomb"
		mat = _game.art.mat_bomb_power
	elif r < 0.66:
		ptype = "range"
		mat = _game.art.mat_range
	elif r < 0.79:
		ptype = "shield"
		mat = _game.art.mat_shield
	elif r < 0.95:
		ptype = str(Constants.CONSUMABLE_IDS.pick_random())
		mat = _game.art.mat_dummy if ptype == "dummy" else _game.art.mat_consumable
	else:
		return

	var node := _create_powerup_model(ptype, mat)
	node.position = Constants.grid_to_world(cell) + Vector3(0, 0.32, 0)
	_game.add_child(node)
	_game.powerups[cell] = {"node": node, "type": ptype}

func check_powerup_pickup(index: int):
	var p: Dictionary = _game.players[index]
	var cell: Vector2i = p["grid_pos"]
	if not _game.powerups.has(cell):
		return

	var data: Dictionary = _game.powerups[cell]
	var node: Node3D = data["node"]
	if is_instance_valid(node):
		node.queue_free()

	match data["type"]:
		"speed":
			p["speed"] = clampi(p["speed"] + 1, 1, 10)
		"bomb":
			p["bomb_max"] = clampi(p["bomb_max"] + 1, 1, 8)
		"range":
			p["bomb_range"] = clampi(p["bomb_range"] + 2, 1, 10)
		"shield":
			if bool(p.get("ai", false)):
				_game.combat_manager.grant_shield(index)
			else:
				_add_consumable(p, "shield_potion")
		_:
			if Constants.CONSUMABLE_IDS.has(str(data["type"])):
				_add_consumable(p, str(data["type"]))
	_game.powerups.erase(cell)

func spawn_boss_reward(cell: Vector2i):
	if _game.powerups.has(cell):
		return
	var node := _create_powerup_model("dummy", _game.art.mat_dummy)
	node.position = Constants.grid_to_world(cell) + Vector3(0, 0.32, 0)
	_game.add_child(node)
	_game.powerups[cell] = {"node": node, "type": "dummy"}

func _add_consumable(p: Dictionary, item_id: String) -> bool:
	_game.inventory_manager.add_item(p, item_id)
	p["status"] = "Picked %s" % _item_display_name(item_id)
	return true

func item_display_name(item_id: String) -> String:
	return _item_display_name(item_id)

func _item_display_name(item_id: String) -> String:
	match item_id:
		"detonator": return "Detonator"
		"glue": return "Glue"
		"shield_potion": return "Shield Potion"
		"invincible_star": return "Invincible Star"
		"dummy": return "Dummy"
		"oil_barrel": return "Oil Barrel"
		"wings": return "Wings"
		"football_shoes": return "Football Shoes"
		"tianlao": return "Tianlao"
	return item_id.capitalize()

func _create_powerup_model(ptype: String, mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Powerup_%s" % ptype

	var base := MeshHelpers.cylinder(0.32, 0.10, MeshHelpers.make_mat(Color(0.08, 0.09, 0.10)))
	base.position = Vector3(0, -0.20, 0)
	root.add_child(base)

	match ptype:
		"speed":
			var arrow_body := MeshHelpers.box(Vector3(0.18, 0.12, 0.48), mat)
			arrow_body.position = Vector3(0, 0.02, 0.02)
			root.add_child(arrow_body)

			var arrow_head := MeshHelpers.box(Vector3(0.42, 0.14, 0.22), mat)
			arrow_head.position = Vector3(0, 0.04, -0.30)
			arrow_head.rotation_degrees = Vector3(0, 45, 0)
			root.add_child(arrow_head)

			var trail := MeshHelpers.box(Vector3(0.36, 0.08, 0.12), MeshHelpers.make_mat(Color(0.45, 1.0, 0.95), true))
			trail.position = Vector3(0, -0.02, 0.34)
			root.add_child(trail)
		"bomb":
			var mini_bomb := MeshHelpers.sphere(0.26, _game.art.mat_bomb)
			mini_bomb.position = Vector3(0, 0.05, 0)
			root.add_child(mini_bomb)

			var fuse := MeshHelpers.cylinder(0.045, 0.28, MeshHelpers.make_mat(Color(0.95, 0.65, 0.18), true))
			fuse.position = Vector3(0.12, 0.30, -0.08)
			fuse.rotation_degrees = Vector3(0, 0, 35)
			root.add_child(fuse)

			var spark := MeshHelpers.sphere(0.08, MeshHelpers.make_mat(Color(1.0, 0.85, 0.20), true))
			spark.position = Vector3(0.22, 0.42, -0.12)
			root.add_child(spark)
		"range":
			var core := MeshHelpers.cylinder(0.18, 0.52, mat)
			core.position = Vector3(0, 0.10, 0)
			root.add_child(core)

			var flame_top := MeshHelpers.sphere(0.20, MeshHelpers.make_mat(Color(1.0, 0.40, 0.08), true))
			flame_top.position = Vector3(0, 0.42, 0)
			flame_top.scale = Vector3(0.75, 1.25, 0.75)
			root.add_child(flame_top)

			var glow := MeshHelpers.sphere(0.34, MeshHelpers.make_mat(Color(1.0, 0.18, 0.05), true, _game.art.tex_powerup))
			glow.position = Vector3(0, 0.12, 0)
			glow.scale = Vector3(1.0, 0.45, 1.0)
			root.add_child(glow)
		"shield":
			var core := MeshHelpers.sphere(0.20, mat)
			core.position = Vector3(0, 0.12, 0)
			root.add_child(core)

			var front := MeshHelpers.box(Vector3(0.46, 0.08, 0.12), mat)
			front.position = Vector3(0, 0.12, -0.34)
			root.add_child(front)

			var back := MeshHelpers.box(Vector3(0.46, 0.08, 0.12), mat)
			back.position = Vector3(0, 0.12, 0.34)
			root.add_child(back)

			var left := MeshHelpers.box(Vector3(0.12, 0.08, 0.46), mat)
			left.position = Vector3(-0.34, 0.12, 0)
			root.add_child(left)

			var right := MeshHelpers.box(Vector3(0.12, 0.08, 0.46), mat)
			right.position = Vector3(0.34, 0.12, 0)
			root.add_child(right)
		"dummy":
			var body := MeshHelpers.capsule(0.18, 0.54, mat)
			body.position = Vector3(0, 0.15, 0)
			root.add_child(body)

			var head := MeshHelpers.sphere(0.16, mat)
			head.position = Vector3(0, 0.50, 0)
			root.add_child(head)

			var face := MeshHelpers.box(Vector3(0.18, 0.04, 0.04), MeshHelpers.make_mat(Color(0.12, 0.08, 0.04)))
			face.position = Vector3(0, 0.52, -0.15)
			root.add_child(face)
		"oil_barrel":
			var barrel := MeshHelpers.cylinder(0.25, 0.58, _game.art.mat_oil)
			barrel.position = Vector3(0, 0.12, 0)
			root.add_child(barrel)
			var band := MeshHelpers.cylinder(0.27, 0.08, _game.art.mat_bomb_power)
			band.position = Vector3(0, 0.14, 0)
			root.add_child(band)
		"wings":
			var left_wing := MeshHelpers.box(Vector3(0.10, 0.40, 0.34), mat)
			left_wing.position = Vector3(-0.22, 0.20, 0)
			left_wing.rotation_degrees.z = -25
			root.add_child(left_wing)
			var right_wing := MeshHelpers.box(Vector3(0.10, 0.40, 0.34), mat)
			right_wing.position = Vector3(0.22, 0.20, 0)
			right_wing.rotation_degrees.z = 25
			root.add_child(right_wing)
		_:
			var orb := MeshHelpers.sphere(0.28, mat)
			root.add_child(orb)

	var tw := create_tween().set_loops()
	tw.tween_property(root, "rotation_degrees:y", 360.0, 2.4).as_relative()
	return root
