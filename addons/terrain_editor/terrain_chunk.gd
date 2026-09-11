@tool
class_name TerrainChunk
extends MeshInstance3D

## Clockwise winding mesh, splat shader or material override, adaptive collision.

const SPLAT_SHADER = preload("res://addons/terrain_editor/shaders/terrain_splat.gdshader")

@export var flip_winding: bool = false:
	set(v):
		flip_winding = v
		_mark_dirty()

var override_material: Material = null:
	set(v):
		override_material = v
		_update_material()

var uv_scale: Vector2 = Vector2.ONE
var uv_offset: Vector2 = Vector2.ZERO
var use_splat: bool = false
var splat_textures: Array = [null, null, null, null]
var splat_map_texture: Texture2D = null

var chunk_x: int = 0
var chunk_z: int = 0
var resolution: int = 32
var terrain_data: TerrainData = null
var chunk_world_size: float = 32.0
var has_collision: bool = false

var _static_body: StaticBody3D = null
var _collision_shape: CollisionShape3D = null
var _dirty: bool = true
var _default_material: StandardMaterial3D = null
var _splat_material: ShaderMaterial = null
var last_rebuild_frame: int = -999

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED

func configure(p_data: TerrainData, p_chunk_x: int, p_chunk_z: int, p_resolution: int, p_chunk_world_size: float) -> void:
	terrain_data = p_data
	chunk_x = p_chunk_x
	chunk_z = p_chunk_z
	resolution = p_resolution
	chunk_world_size = p_chunk_world_size
	position = Vector3(chunk_x * chunk_world_size, 0.0, chunk_z * chunk_world_size)
	_mark_dirty()

func set_uv_params(scale: Vector2, offset: Vector2) -> void:
	uv_scale = scale
	uv_offset = offset
	_update_material()
	if mesh:
		rebuild_mesh()

func set_splat_params(enabled: bool, map_tex: Texture2D, textures: Array) -> void:
	use_splat = enabled
	splat_map_texture = map_tex
	splat_textures = textures
	_update_material()

func _mark_dirty() -> void:
	_dirty = true

func is_dirty() -> bool:
	return _dirty

func rebuild_mesh() -> void:
	if terrain_data == null or terrain_data.height_image == null:
		return
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var res := resolution
	var inv_res := 1.0 / float(res)
	var data_size := terrain_data.size
	var scale_y := terrain_data.world_scale.y
	var px0 := chunk_x * res
	var pz0 := chunk_z * res
	for iz in range(res + 1):
		for ix in range(res + 1):
			var px := clampi(px0 + ix, 0, data_size - 1)
			var pz := clampi(pz0 + iz, 0, data_size - 1)
			var h := terrain_data.get_height(px, pz) * scale_y
			verts.append(Vector3(float(ix) * inv_res * chunk_world_size, h, float(iz) * inv_res * chunk_world_size))
			uvs.append(Vector2(float(px) / float(data_size), float(pz) / float(data_size)))
			var h_l := terrain_data.get_height(clampi(px - 1, 0, data_size - 1), pz) * scale_y
			var h_r := terrain_data.get_height(clampi(px + 1, 0, data_size - 1), pz) * scale_y
			var h_d := terrain_data.get_height(px, clampi(pz - 1, 0, data_size - 1)) * scale_y
			var h_u := terrain_data.get_height(px, clampi(pz + 1, 0, data_size - 1)) * scale_y
			normals.append(Vector3(h_l - h_r, 2.0 * terrain_data.pixel_world_size, h_d - h_u).normalized())
	for iz in range(res):
		for ix in range(res):
			var i0 := iz * (res + 1) + ix
			var i1 := i0 + 1
			var i2 := i0 + (res + 1)
			var i3 := i2 + 1
			if flip_winding:
				indices.append(i0); indices.append(i2); indices.append(i1)
				indices.append(i1); indices.append(i2); indices.append(i3)
			else:
				indices.append(i0); indices.append(i1); indices.append(i2)
				indices.append(i1); indices.append(i3); indices.append(i2)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var max_h := 50.0
	for v in verts:
		max_h = maxf(max_h, absf(v.y))
	arr_mesh.custom_aabb = AABB(
		Vector3(-chunk_world_size * 0.5, -max_h * 2.0, -chunk_world_size * 0.5),
		Vector3(chunk_world_size * 2.0, max_h * 4.0, chunk_world_size * 2.0)
	)
	mesh = arr_mesh
	_update_material()
	_dirty = false

func _update_material() -> void:
	if use_splat:
		if _splat_material == null:
			_splat_material = ShaderMaterial.new()
			_splat_material.shader = SPLAT_SHADER
		_splat_material.set_shader_parameter("uv_scale", uv_scale)
		_splat_material.set_shader_parameter("uv_offset", uv_offset)
		if splat_map_texture:
			_splat_material.set_shader_parameter("splatmap", splat_map_texture)
		for i in range(4):
			var tex = splat_textures[i] if i < splat_textures.size() else null
			_splat_material.set_shader_parameter("tex%d" % i, tex)
		material_override = _splat_material
		return
	if override_material != null:
		if override_material is BaseMaterial3D:
			var bm := override_material as BaseMaterial3D
			bm.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
			bm.uv1_offset = Vector3(uv_offset.x, uv_offset.y, 0.0)
		material_override = override_material
		return
	if _default_material == null:
		_default_material = StandardMaterial3D.new()
		_default_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_default_material.cull_mode = BaseMaterial3D.CULL_BACK
		_default_material.albedo_color = Color(0.35, 0.55, 0.25)
	_default_material.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	_default_material.uv1_offset = Vector3(uv_offset.x, uv_offset.y, 0.0)
	material_override = _default_material

func enable_collision() -> void:
	if has_collision or terrain_data == null:
		return
	_static_body = StaticBody3D.new()
	_static_body.name = "CollisionBody"
	add_child(_static_body)
	_collision_shape = CollisionShape3D.new()
	_static_body.add_child(_collision_shape)
	var shape := HeightMapShape3D.new()
	var res := resolution
	var map_w := res + 1
	var map_d := res + 1
	shape.map_width = map_w
	shape.map_depth = map_d
	var heights := PackedFloat32Array()
	heights.resize(map_w * map_d)
	var px0 := chunk_x * res
	var pz0 := chunk_z * res
	var data_size := terrain_data.size
	var scale_y := terrain_data.world_scale.y
	var idx := 0
	for iz in range(map_d):
		for ix in range(map_w):
			heights[idx] = terrain_data.get_height(clampi(px0 + ix, 0, data_size - 1), clampi(pz0 + iz, 0, data_size - 1)) * scale_y
			idx += 1
	shape.map_data = heights
	var cell := chunk_world_size / float(res)
	_collision_shape.scale = Vector3(cell, 1.0, cell)
	_collision_shape.shape = shape
	_collision_shape.position = Vector3(chunk_world_size * 0.5, 0.0, chunk_world_size * 0.5)
	has_collision = true

func disable_collision() -> void:
	if not has_collision:
		return
	if _static_body and is_instance_valid(_static_body):
		_static_body.queue_free()
	_static_body = null
	_collision_shape = null
	has_collision = false

func update_collision_heights() -> void:
	if not has_collision or _collision_shape == null:
		return
	var shape := _collision_shape.shape as HeightMapShape3D
	if shape == null:
		return
	var res := resolution
	var map_w := res + 1
	var map_d := res + 1
	var heights := PackedFloat32Array()
	heights.resize(map_w * map_d)
	var px0 := chunk_x * res
	var pz0 := chunk_z * res
	var data_size := terrain_data.size
	var scale_y := terrain_data.world_scale.y
	var idx := 0
	for iz in range(map_d):
		for ix in range(map_w):
			heights[idx] = terrain_data.get_height(clampi(px0 + ix, 0, data_size - 1), clampi(pz0 + iz, 0, data_size - 1)) * scale_y
			idx += 1
	shape.map_data = heights
