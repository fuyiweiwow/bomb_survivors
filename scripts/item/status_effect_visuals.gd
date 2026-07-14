extends Node

const SHIELD_EFFECT := "ShieldEffect"
const INVINCIBLE_EFFECT := "InvincibleEffect"
const WINGS_EFFECT := "WingsEffect"
const FOOTBALL_EFFECT := "FootballEffect"
const PRISON_EFFECT := "PrisonEffect"
const GLUE_EFFECT := "GlueSlowEffect"
const BURNING_EFFECT := "BurningEffect"

var _game: Node
var _elapsed := 0.0


func setup(game_manager: Node):
	_game = game_manager


func _process(delta: float):
	if _game == null:
		return
	_elapsed += delta
	for state: CharacterState in _game.character_registry.states():
		refresh_player(state.data)
		_animate_player_effects(state.data)


func refresh_player(player: Dictionary):
	var player_node = player.get("node")
	if not is_instance_valid(player_node):
		return
	_sync_effect(player_node, SHIELD_EFFECT, int(player.get("shield", 0)) > 0, _create_shield_effect)
	_sync_effect(player_node, INVINCIBLE_EFFECT, float(player.get("invincible_timer", 0.0)) > 0.0, _create_invincible_effect)
	_sync_effect(player_node, WINGS_EFFECT, float(player.get("wings_timer", 0.0)) > 0.0, _create_wings_effect)
	_sync_effect(player_node, FOOTBALL_EFFECT, float(player.get("football_timer", 0.0)) > 0.0, _create_football_effect)
	_sync_effect(player_node, PRISON_EFFECT, float(player.get("prison_timer", 0.0)) > 0.0, _create_prison_effect)
	_sync_effect(player_node, GLUE_EFFECT, float(player.get("slow_timer", 0.0)) > 0.0, _create_glue_effect)
	_sync_effect(player_node, BURNING_EFFECT, float(player.get("fire_exposure_time", 0.0)) > 0.0, _create_burning_effect)


func _sync_effect(parent: Node3D, effect_name: String, active: bool, create_effect: Callable):
	var effect := parent.get_node_or_null(effect_name)
	if active and effect == null:
		var created := create_effect.call() as Node3D
		created.scale = Vector3.ONE * 0.12
		parent.add_child(created)
		create_tween().bind_node(created).tween_property(created, "scale", Vector3.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not active and is_instance_valid(effect):
		effect.queue_free()


func _animate_player_effects(player: Dictionary):
	var player_node = player.get("node")
	if not is_instance_valid(player_node):
		return
	var shield := (player_node as Node3D).get_node_or_null(SHIELD_EFFECT) as Node3D
	if shield:
		var shield_scale := 1.0 + sin(_elapsed * 4.5) * 0.035
		shield.scale = Vector3.ONE * shield_scale
	var invincible := (player_node as Node3D).get_node_or_null(INVINCIBLE_EFFECT) as Node3D
	if invincible:
		invincible.rotation.y = _elapsed * 3.2
		invincible.position.y = 0.62 + sin(_elapsed * 5.0) * 0.05
	var wings := (player_node as Node3D).get_node_or_null(WINGS_EFFECT) as Node3D
	if wings and wings.get_child_count() >= 2:
		var flutter := sin(_elapsed * 9.0) * 0.18
		(wings.get_child(0) as Node3D).rotation.z = 0.35 + flutter
		(wings.get_child(1) as Node3D).rotation.z = -0.35 - flutter
	var football := (player_node as Node3D).get_node_or_null(FOOTBALL_EFFECT) as Node3D
	if football:
		var boot_scale := 1.0 + sin(_elapsed * 8.0) * 0.08
		football.scale = Vector3.ONE * boot_scale
	var glue := (player_node as Node3D).get_node_or_null(GLUE_EFFECT) as Node3D
	if glue and glue.get_child_count() > 0:
		var glue_scale := 1.0 + sin(_elapsed * 5.5) * 0.10
		(glue.get_child(0) as Node3D).scale = Vector3(glue_scale, 1.0, glue_scale)
	var burning := (player_node as Node3D).get_node_or_null(BURNING_EFFECT) as Node3D
	if burning:
		burning.rotation.y = _elapsed * 2.8
		burning.position.y = 0.30 + sin(_elapsed * 7.0) * 0.06


func _create_shield_effect() -> Node3D:
	var root := Node3D.new()
	root.name = SHIELD_EFFECT
	var material := _effect_material(Color(0.20, 0.72, 1.0, 0.22), true)
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	var shell := MeshHelpers.sphere(0.70, material)
	shell.position.y = 0.58
	root.add_child(shell)
	return root


func _create_invincible_effect() -> Node3D:
	var root := Node3D.new()
	root.name = INVINCIBLE_EFFECT
	root.position.y = 0.62
	var material := _effect_material(Color(1.0, 0.86, 0.12, 0.92), false)
	for offset in [Vector3(0.68, 0.0, 0.0), Vector3(-0.68, 0.0, 0.0), Vector3(0.0, 0.0, 0.68), Vector3(0.0, 0.0, -0.68)]:
		var spark := MeshHelpers.sphere(0.10, material)
		spark.position = offset
		root.add_child(spark)
	return root


func _create_wings_effect() -> Node3D:
	var root := Node3D.new()
	root.name = WINGS_EFFECT
	root.position = Vector3(0.0, 0.62, 0.20)
	var material := _effect_material(Color(0.62, 0.94, 1.0, 0.72), false)
	var left := MeshHelpers.box(Vector3(0.48, 0.06, 0.34), material)
	left.position = Vector3(-0.42, 0.0, 0.0)
	root.add_child(left)
	var right := MeshHelpers.box(Vector3(0.48, 0.06, 0.34), material)
	right.position = Vector3(0.42, 0.0, 0.0)
	root.add_child(right)
	return root


func _create_football_effect() -> Node3D:
	var root := Node3D.new()
	root.name = FOOTBALL_EFFECT
	var material := _effect_material(Color(1.0, 0.72, 0.08, 0.90), false)
	for x in [-0.22, 0.22]:
		var boot := MeshHelpers.box(Vector3(0.20, 0.14, 0.38), material)
		boot.position = Vector3(x, 0.10, -0.12)
		root.add_child(boot)
	return root

func _create_prison_effect() -> Node3D:
	var root := Node3D.new()
	root.name = PRISON_EFFECT
	var material := _effect_material(Color(0.66, 0.72, 0.78, 0.92), false)
	for x in [-0.48, 0.48]:
		for z in [-0.48, 0.48]:
			var bar := MeshHelpers.cylinder(0.045, 1.35, material)
			bar.position = Vector3(x, 0.65, z)
			root.add_child(bar)
	for height in [0.08, 1.24]:
		var horizontal := MeshHelpers.box(Vector3(1.08, 0.07, 1.08), material)
		horizontal.position.y = height
		root.add_child(horizontal)
	return root

func _create_glue_effect() -> Node3D:
	var root := Node3D.new()
	root.name = GLUE_EFFECT
	var puddle := MeshHelpers.cylinder(0.46, 0.035, _effect_material(Color(0.22, 0.92, 0.58, 0.68), true))
	puddle.position.y = 0.035
	root.add_child(puddle)
	return root

func _create_burning_effect() -> Node3D:
	var root := Node3D.new()
	root.name = BURNING_EFFECT
	var material := _effect_material(Color(1.0, 0.28, 0.04, 0.88), true)
	for angle_index in range(5):
		var angle := TAU * float(angle_index) / 5.0
		var flame := MeshHelpers.sphere(0.11, material)
		flame.position = Vector3(cos(angle) * 0.42, 0.22 + float(angle_index % 2) * 0.18, sin(angle) * 0.42)
		flame.scale = Vector3(0.70, 1.55, 0.70)
		root.add_child(flame)
	return root


func _effect_material(color: Color, translucent: bool) -> StandardMaterial3D:
	var material := MeshHelpers.make_mat(color, true)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if translucent or color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
