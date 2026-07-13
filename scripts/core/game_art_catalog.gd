class_name GameArtCatalog
extends RefCounted

var tex_floor: Texture2D = load("res://assets/art/3d/floor_tile.png")
var tex_wall: Texture2D = load("res://assets/art/3d/wall_block.png")
var tex_crate: Texture2D = load("res://assets/art/3d/crate_wood.png")
var tex_bomb: Texture2D = load("res://assets/art/3d/bomb_shell.png")
var tex_powerup: Texture2D = load("res://assets/art/3d/powerup_energy.png")
var tex_lava: Texture2D = load("res://assets/art/3d/lava_cracked.png")

var mat_floor_a := TerrainArtFactory.brushed_material(tex_floor, Color(0.70, 0.78, 0.66), TerrainArtFactory.PATCH_BRUSH)
var mat_floor_b := TerrainArtFactory.brushed_material(tex_floor, Color(0.82, 0.88, 0.76), TerrainArtFactory.PATCH_BRUSH)
var mat_wall := TerrainArtFactory.brushed_material(tex_wall, Color(0.72, 0.76, 0.82), TerrainArtFactory.PATCH_BRUSH)
var mat_crate := TerrainArtFactory.brushed_material(tex_crate, Color(1.0, 0.88, 0.70), TerrainArtFactory.PATCH_BRUSH)
var mat_bomb := MeshHelpers.make_mat(Color(0.75, 0.75, 0.78), false, tex_bomb)
var mat_fire := MeshHelpers.make_mat(Color(1.0, 0.48, 0.08), true)
var mat_forest_floor := TerrainArtFactory.brushed_material(tex_floor, Color(0.18, 0.36, 0.18), TerrainArtFactory.DOTS_BRUSH)
var mat_leaf := MeshHelpers.make_mat(Color(0.10, 0.48, 0.16))
var mat_trunk := MeshHelpers.make_mat(Color(0.42, 0.24, 0.11))
var mat_lava := TerrainArtFactory.brushed_material(tex_lava, Color(0.95, 0.18, 0.04), TerrainArtFactory.LAVA_BRUSH, 0.8)
var mat_lava_glow := TerrainArtFactory.brushed_material(tex_lava, Color(1.0, 0.65, 0.08), TerrainArtFactory.LAVA_BRUSH, 1.5)
var mat_speed := MeshHelpers.make_mat(Color(0.2, 0.95, 0.85), true, tex_powerup)
var mat_bomb_power := MeshHelpers.make_mat(Color(0.95, 0.92, 0.25), true, tex_powerup)
var mat_range := MeshHelpers.make_mat(Color(1.0, 0.22, 0.12), true, tex_powerup)
var mat_shield := MeshHelpers.make_mat(Color(0.35, 0.55, 1.0), true, tex_powerup)
var mat_dummy := MeshHelpers.make_mat(Color(0.92, 0.78, 0.46), true, tex_powerup)
var mat_consumable := MeshHelpers.make_mat(Color(0.25, 0.92, 0.72), true, tex_powerup)
var mat_glue := MeshHelpers.make_mat(Color(0.92, 0.34, 0.78), true)
var mat_oil := MeshHelpers.make_mat(Color(0.18, 0.20, 0.22))
var mat_ai := MeshHelpers.make_mat(Color(0.95, 0.27, 0.22))
var mat_boss_blast := MeshHelpers.make_mat(Color(0.52, 0.08, 0.04), true)
var mat_boss_frost := MeshHelpers.make_mat(Color(0.40, 0.82, 1.0), true)
var mat_boss_clone := MeshHelpers.make_mat(Color(0.62, 0.22, 0.88), true)

func terrain_materials() -> Dictionary:
	return {
		"floor_a": mat_floor_a,
		"floor_b": mat_floor_b,
		"wall": mat_wall,
		"crate": mat_crate,
		"forest_floor": mat_forest_floor,
		"trunk": mat_trunk,
		"leaf": mat_leaf,
		"lava": mat_lava_glow,
	}
