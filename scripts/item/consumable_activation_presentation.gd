class_name ConsumableActivationPresentation
extends Node

var game: Node

func setup(game_manager: Node) -> void:
	game = game_manager

func play(state: CharacterState, item_id: String) -> void:
	if state == null or state.node() == null:
		return
	var radius := _radius_for(item_id)
	var color := _color_for(item_id)
	var root := Node3D.new()
	root.name = "ItemActivation_%s" % item_id
	root.position = Constants.grid_to_world(state.cell()) + Vector3(0, 0.12, 0)
	var material := MeshHelpers.make_mat(color, true)
	var span := float(radius * 2 + 1) * Constants.TILE_SIZE
	var edge_offset := span * 0.5
	var pieces: Array[GeometryInstance3D] = []
	for z in [-edge_offset, edge_offset]:
		var horizontal := MeshHelpers.box(Vector3(span, 0.045, 0.07), material)
		horizontal.position.z = z
		root.add_child(horizontal)
		pieces.append(horizontal)
	for x in [-edge_offset, edge_offset]:
		var vertical := MeshHelpers.box(Vector3(0.07, 0.045, span), material)
		vertical.position.x = x
		root.add_child(vertical)
		pieces.append(vertical)
	for angle_index in range(8):
		var angle := TAU * float(angle_index) / 8.0
		var spark := MeshHelpers.sphere(0.075, material)
		spark.position = Vector3(cos(angle) * edge_offset, 0.10, sin(angle) * edge_offset)
		root.add_child(spark)
		pieces.append(spark)
	game.add_child(root)
	root.scale = Vector3.ONE * 0.08
	var tween := game.create_tween().bind_node(root)
	tween.tween_property(root, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.22)
	tween.set_parallel(true)
	for piece in pieces:
		tween.tween_property(piece, "transparency", 1.0, 0.26)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)

func _radius_for(item_id: String) -> int:
	match item_id:
		"prison":
			return Constants.PRISON_RADIUS
		"glue":
			return Constants.GLUE_AREA_RADIUS
		"detonator":
			return 2
	return 1

func _color_for(item_id: String) -> Color:
	match item_id:
		"detonator":
			return Color(1.0, 0.22, 0.08, 0.90)
		"glue":
			return Color(0.28, 0.92, 0.58, 0.82)
		"oil_barrel":
			return Color(1.0, 0.46, 0.05, 0.86)
		"wings":
			return Color(0.52, 0.90, 1.0, 0.86)
		"prison":
			return Color(0.72, 0.64, 1.0, 0.90)
		"duel":
			return Color(1.0, 0.78, 0.18, 0.90)
	return Color(0.95, 0.95, 1.0, 0.82)
