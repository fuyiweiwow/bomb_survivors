class_name TerrainArtFactory
extends RefCounted

const PATCH_BRUSH := "res://addons/terrabrush/Assets/Brushes/patch.png"
const DOTS_BRUSH := "res://addons/terrabrush/Assets/Brushes/small_dots.png"
const LAVA_BRUSH := "res://addons/terrabrush/Assets/Brushes/x_gradient.png"

const TERRAIN_SHADER := """
shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D base_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D brush_texture : source_color, filter_linear;
uniform vec4 tint : source_color = vec4(1.0);
uniform float detail_strength = 0.18;
uniform float emission_strength = 0.0;

void fragment() {
	vec3 base = texture(base_texture, UV * 1.7).rgb * tint.rgb;
	float mask = texture(brush_texture, UV).r;
	float detail = mix(1.0 - detail_strength, 1.0 + detail_strength, mask);
	ALBEDO = base * detail;
	ROUGHNESS = mix(0.48, 0.88, mask);
	EMISSION = base * emission_strength * mix(0.35, 1.0, mask);
}
"""

static var _brush_images: Dictionary = {}
static var _floor_meshes: Dictionary = {}

static func brushed_material(base_texture: Texture2D, tint: Color, brush_path: String, emission := 0.0) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = TERRAIN_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_texture", base_texture)
	material.set_shader_parameter("brush_texture", load(brush_path))
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("emission_strength", emission)
	return material

static func create_rock_wall(cell: Vector2i, tile_size: float, material: Material) -> MeshInstance3D:
	var variation := brush_value(cell, PATCH_BRUSH)
	var mesh := CylinderMesh.new()
	mesh.top_radius = tile_size * lerpf(0.34, 0.43, variation)
	mesh.bottom_radius = tile_size * lerpf(0.42, 0.48, variation)
	mesh.height = lerpf(1.10, 1.42, variation)
	mesh.radial_segments = 7
	var node := MeshInstance3D.new()
	node.name = "Wall_%d_%d" % [cell.x, cell.y]
	node.mesh = mesh
	node.material_override = material
	node.rotation_degrees.y = fmod(float(cell.x * 37 + cell.y * 61), 360.0)
	return node

static func create_floor_cell(cell: Vector2i, world_position: Vector3, tile_size: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "GroundCell_%d_%d" % [cell.x, cell.y]
	node.mesh = _floor_mesh(tile_size)
	node.material_override = material
	node.position = world_position + Vector3(0, -0.04, 0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("logical_cell_size", tile_size)
	return node

static func _floor_mesh(tile_size: float) -> BoxMesh:
	var cache_key := "%0.4f" % tile_size
	if _floor_meshes.has(cache_key):
		return _floor_meshes[cache_key] as BoxMesh
	var mesh := BoxMesh.new()
	mesh.size = Vector3(tile_size * 0.95, 0.08, tile_size * 0.95)
	_floor_meshes[cache_key] = mesh
	return mesh

static func create_forest_tile(cell: Vector2i, world_position: Vector3, tile_size: float, floor_material: Material, trunk_material: Material, leaf_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Forest_%d_%d" % [cell.x, cell.y]
	root.position = world_position
	var art_scale := tile_size / 1.8
	var offsets := [Vector3(-0.36, 0, -0.30), Vector3(0.34, 0, -0.14), Vector3(-0.04, 0, 0.34)]
	for offset in offsets:
		offset *= art_scale
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.08 * art_scale
		trunk_mesh.bottom_radius = 0.10 * art_scale
		trunk_mesh.height = 0.55 * art_scale
		trunk_mesh.radial_segments = 7
		var trunk := MeshInstance3D.new()
		trunk.mesh = trunk_mesh
		trunk.material_override = trunk_material
		trunk.position = offset + Vector3(0, 0.24 * art_scale, 0)
		root.add_child(trunk)
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 0.34 * art_scale
		crown_mesh.height = 0.68 * art_scale
		crown_mesh.radial_segments = 10
		crown_mesh.rings = 6
		var crown := MeshInstance3D.new()
		crown.mesh = crown_mesh
		crown.material_override = leaf_material
		crown.position = offset + Vector3(0, 0.72 * art_scale, 0)
		crown.scale = Vector3(1.0, 0.82, 1.0)
		root.add_child(crown)
	var cover_mesh := BoxMesh.new()
	cover_mesh.size = Vector3(tile_size * 0.88, 0.08, tile_size * 0.88)
	var cover := MeshInstance3D.new()
	cover.mesh = cover_mesh
	cover.material_override = floor_material
	cover.position = Vector3(0, 0.10, 0)
	root.add_child(cover)
	return root

static func create_lava_tile(cell: Vector2i, world_position: Vector3, tile_size: float, lava_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Lava_%d_%d" % [cell.x, cell.y]
	root.position = world_position
	var art_scale := tile_size / 1.8
	var pool_mesh := BoxMesh.new()
	pool_mesh.size = Vector3(tile_size * 0.86, 0.10, tile_size * 0.86)
	var pool := MeshInstance3D.new()
	pool.mesh = pool_mesh
	pool.material_override = lava_material
	pool.position = Vector3(0, 0.03, 0)
	root.add_child(pool)
	for data in [[Vector3(0.28, 0.16, -0.22), 0.16], [Vector3(-0.30, 0.13, 0.26), 0.11]]:
		var bubble_mesh := SphereMesh.new()
		bubble_mesh.radius = float(data[1]) * art_scale
		bubble_mesh.height = float(data[1]) * art_scale * 2.0
		bubble_mesh.radial_segments = 10
		bubble_mesh.rings = 5
		var bubble := MeshInstance3D.new()
		bubble.mesh = bubble_mesh
		bubble.material_override = lava_material
		bubble.position = (data[0] as Vector3) * art_scale
		bubble.scale = Vector3(1.0, 0.45, 1.0)
		root.add_child(bubble)
	return root

static func create_outer_terrain(grid_w: int, grid_h: int, tile_size: float, rock_material: Material, ground_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "TerraBrushOuterTerrain"
	var margin_cells := maxi(2, roundi(3.6 / tile_size))
	for y in range(-margin_cells, grid_h + margin_cells):
		for x in range(-margin_cells, grid_w + margin_cells):
			if x >= 0 and x < grid_w and y >= 0 and y < grid_h:
				continue
			var cell := Vector2i(x, y)
			var value := brush_value(cell, PATCH_BRUSH)
			var ground_mesh := BoxMesh.new()
			ground_mesh.size = Vector3(tile_size, lerpf(0.12, 0.42, value), tile_size)
			var ground := MeshInstance3D.new()
			ground.mesh = ground_mesh
			ground.material_override = ground_material
			ground.position = _grid_to_world(cell, grid_w, grid_h, tile_size) + Vector3(0, -0.18, 0)
			root.add_child(ground)
			if (x + y) % 3 == 0:
				var rock := create_rock_wall(cell, tile_size * lerpf(0.48, 0.72, value), rock_material)
				rock.position = _grid_to_world(cell, grid_w, grid_h, tile_size) + Vector3(0, lerpf(0.10, 0.32, value), 0)
				rock.scale.y = lerpf(0.28, 0.62, value)
				root.add_child(rock)
	return root

static func brush_value(cell: Vector2i, brush_path: String) -> float:
	if not _brush_images.has(brush_path):
		var texture := load(brush_path) as Texture2D
		_brush_images[brush_path] = texture.get_image() if texture != null else null
	var image: Image = _brush_images[brush_path]
	if image == null or image.is_empty():
		return 0.5
	var px := posmod(cell.x * 29 + cell.y * 17, image.get_width())
	var py := posmod(cell.y * 31 - cell.x * 13, image.get_height())
	return image.get_pixel(px, py).get_luminance()

static func _grid_to_world(cell: Vector2i, grid_w: int, grid_h: int, tile_size: float) -> Vector3:
	return Vector3((cell.x - (grid_w - 1) / 2.0) * tile_size, 0.0, (cell.y - (grid_h - 1) / 2.0) * tile_size)
