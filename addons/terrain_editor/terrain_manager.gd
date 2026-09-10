@tool
class_name TerrainManager
extends Node3D

## Heightmap, chunks, undo/redo, procedural gen, UV tiling, adaptive collision.

const TerrainDataScript = preload("res://addons/terrain_editor/terrain_data.gd")
const TerrainChunkScript = preload("res://addons/terrain_editor/terrain_chunk.gd")
const SculptBrushScript = preload("res://addons/terrain_editor/sculpt_brush.gd")

const MAX_UNDO: int = 16

@export var heightmap_image: Image = null

@export var heightmap_size: int = 256:
	set(v):
		heightmap_size = maxi(v, 32)
		if _data:
			_data.resize(heightmap_size)
			heightmap_image = _data.height_image
			_rebuild_all_chunks()

@export var chunk_resolution: int = 32:
	set(v):
		chunk_resolution = clampi(v, 8, 64)
		_rebuild_all_chunks()

@export var world_scale: Vector3 = Vector3(256.0, 32.0, 256.0):
	set(v):
		world_scale = v
		if _data:
			_data.set_world_scale(v)
			_rebuild_all_chunks()

@export var collision_radius: float = 64.0:
	set(v):
		collision_radius = maxf(v, 8.0)

@export var flip_winding: bool = false:
	set(v):
		flip_winding = v
		for c in _chunks.values():
			if is_instance_valid(c):
				c.flip_winding = v
				c.rebuild_mesh()

## Assign any Material here (StandardMaterial3D, ShaderMaterial, ORMMaterial3D, …)
@export var terrain_material: Material = null:
	set(v):
		terrain_material = v
		for c in _chunks.values():
			if is_instance_valid(c):
				c.override_material = v

@export var uv_scale: Vector2 = Vector2(1.0, 1.0):
	set(v):
		uv_scale = v
		_apply_uv_to_chunks()

@export var uv_offset: Vector2 = Vector2.ZERO:
	set(v):
		uv_offset = v
		_apply_uv_to_chunks()

@export var mesh_rebuild_interval: int = 3:
	set(v):
		mesh_rebuild_interval = clampi(v, 1, 8)

@export_file("*.exr") var heightmap_path: String = ""

@export var noise_seed: int = 42
@export var noise_frequency: float = 4.0
@export var noise_octaves: int = 4
@export var noise_amplitude: float = 1.0
@export var noise_lacunarity: float = 2.0
@export var noise_gain: float = 0.5

var _data: TerrainData = null
var _brush: SculptBrush = null
var _chunks: Dictionary = {}
var _dirty_chunks: Dictionary = {}
var _frame_counter: int = 0
var _is_stroking: bool = false
var _camera: Camera3D = null
var _initialized: bool = false

var _undo_stack: Array[PackedByteArray] = []
var _redo_stack: Array[PackedByteArray] = []
var _stroke_snapshot: PackedByteArray = PackedByteArray()

func _ready() -> void:
	_init_data()
	_brush = SculptBrushScript.new()
	_create_chunk_grid()
	set_process(true)
	_initialized = true

func _init_data() -> void:
	if heightmap_image != null and not heightmap_image.is_empty():
		if heightmap_image.get_format() != Image.FORMAT_RH:
			heightmap_image.convert(Image.FORMAT_RH)
		heightmap_size = heightmap_image.get_width()
		_data = TerrainDataScript.new(heightmap_size, world_scale, heightmap_image)
	elif heightmap_path != "" and FileAccess.file_exists(heightmap_path):
		_data = TerrainDataScript.new(heightmap_size, world_scale)
		if _data.load_from_path(heightmap_path) == OK:
			heightmap_image = _data.height_image
			heightmap_size = _data.size
	else:
		_data = TerrainDataScript.new(heightmap_size, world_scale)
		heightmap_image = _data.height_image

func _process(_delta: float) -> void:
	_frame_counter += 1
	_update_collision_radius()
	_flush_dirty_meshes()

func _chunk_world_size() -> float:
	var n := maxi(heightmap_size / chunk_resolution, 1)
	return world_scale.x / float(n)

func _chunks_per_side() -> int:
	return maxi(heightmap_size / chunk_resolution, 1)

func _create_chunk_grid() -> void:
	for c in _chunks.values():
		if is_instance_valid(c):
			c.queue_free()
	_chunks.clear()
	_dirty_chunks.clear()
	for child in get_children():
		if child is MeshInstance3D and str(child.name).begins_with("Chunk_"):
			child.queue_free()
	if _data == null:
		return
	var n := _chunks_per_side()
	var cws := _chunk_world_size()
	for cz in range(n):
		for cx in range(n):
			var key := Vector2i(cx, cz)
			var chunk: TerrainChunk = TerrainChunkScript.new()
			chunk.name = "Chunk_%d_%d" % [cx, cz]
			add_child(chunk)
			chunk.configure(_data, cx, cz, chunk_resolution, cws)
			chunk.flip_winding = flip_winding
			chunk.override_material = terrain_material
			chunk.set_uv_params(uv_scale, uv_offset)
			chunk.rebuild_mesh()
			_chunks[key] = chunk

func _rebuild_all_chunks() -> void:
	if not is_inside_tree() or _data == null:
		return
	_create_chunk_grid()

func _apply_uv_to_chunks() -> void:
	for c in _chunks.values():
		if is_instance_valid(c):
			c.set_uv_params(uv_scale, uv_offset)

func _mark_all_dirty() -> void:
	for key in _chunks.keys():
		_dirty_chunks[key] = true
		if is_instance_valid(_chunks[key]):
			_chunks[key]._mark_dirty()

# --- Undo / Redo -----------------------------------------------------------

func _snapshot_bytes() -> PackedByteArray:
	if _data == null or _data.height_image == null:
		return PackedByteArray()
	return _data.height_image.get_data()

func _restore_bytes(buf: PackedByteArray) -> void:
	if _data == null or _data.height_image == null or buf.is_empty():
		return
	_data.height_image.set_data(_data.size, _data.size, false, Image.FORMAT_RH, buf)
	heightmap_image = _data.height_image
	_mark_all_dirty()
	_flush_dirty_meshes(true)

func _push_undo(buf: PackedByteArray) -> void:
	if buf.is_empty():
		return
	_undo_stack.push_back(buf)
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()
	_redo_stack.clear()

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

func undo() -> void:
	if not can_undo():
		return
	var current := _snapshot_bytes()
	var prev: PackedByteArray = _undo_stack.pop_back()
	_redo_stack.push_back(current)
	_restore_bytes(prev)
	print("[TerrainEditor] Undo (%d left)" % _undo_stack.size())

func redo() -> void:
	if not can_redo():
		return
	var current := _snapshot_bytes()
	var next: PackedByteArray = _redo_stack.pop_back()
	_undo_stack.push_back(current)
	_restore_bytes(next)
	print("[TerrainEditor] Redo (%d left)" % _redo_stack.size())

# --- Sculpting -------------------------------------------------------------

func begin_stroke(world_pos: Vector3) -> void:
	_is_stroking = true
	_stroke_snapshot = _snapshot_bytes()
	_apply_brush(world_pos, 1.0)

func continue_stroke(world_pos: Vector3, pressure: float = 1.0) -> void:
	if not _is_stroking:
		return
	_apply_brush(world_pos, pressure)

func end_stroke() -> void:
	_is_stroking = false
	_flush_dirty_meshes(true)
	if not _stroke_snapshot.is_empty():
		_push_undo(_stroke_snapshot)
		_stroke_snapshot = PackedByteArray()
	if _data:
		heightmap_image = _data.height_image
		if Engine.is_editor_hint():
			notify_property_list_changed()

func _apply_brush(world_pos: Vector3, pressure: float) -> void:
	if _data == null or _brush == null:
		return
	var rect := _brush.apply(_data, world_pos, pressure)
	if rect.size.x <= 0:
		return
	heightmap_image = _data.height_image
	_mark_chunks_dirty(rect)

func _mark_chunks_dirty(pixel_rect: Rect2i) -> void:
	var res := chunk_resolution
	var x0 := pixel_rect.position.x / res
	var z0 := pixel_rect.position.y / res
	var x1 := (pixel_rect.position.x + pixel_rect.size.x - 1) / res
	var z1 := (pixel_rect.position.y + pixel_rect.size.y - 1) / res
	for cz in range(z0, z1 + 1):
		for cx in range(x0, x1 + 1):
			var key := Vector2i(cx, cz)
			if _chunks.has(key):
				_dirty_chunks[key] = true
				_chunks[key]._mark_dirty()

func _flush_dirty_meshes(force: bool = false) -> void:
	if _dirty_chunks.is_empty():
		return
	var to_rebuild: Array[Vector2i] = []
	for key in _dirty_chunks.keys():
		var chunk: TerrainChunk = _chunks.get(key)
		if chunk == null or not is_instance_valid(chunk):
			continue
		if force or (_frame_counter - chunk.last_rebuild_frame) >= mesh_rebuild_interval:
			to_rebuild.append(key)
	for key in to_rebuild:
		var chunk: TerrainChunk = _chunks[key]
		chunk.rebuild_mesh()
		chunk.last_rebuild_frame = _frame_counter
		if chunk.has_collision:
			chunk.update_collision_heights()
		_dirty_chunks.erase(key)

# --- Procedural FBM --------------------------------------------------------

func generate_random_terrain(
		p_seed: int = -1,
		frequency: float = -1.0,
		octaves: int = -1,
		amplitude: float = -1.0
	) -> void:
	if _data == null or _data.height_image == null:
		return
	_push_undo(_snapshot_bytes())
	if p_seed >= 0:
		noise_seed = p_seed
	if frequency > 0.0:
		noise_frequency = frequency
	if octaves > 0:
		noise_octaves = octaves
	if amplitude > 0.0:
		noise_amplitude = amplitude

	var size := _data.size
	var freq := noise_frequency
	var amp := noise_amplitude
	var oct := clampi(noise_octaves, 1, 8)
	var lac := noise_lacunarity
	var gain := noise_gain
	var s := noise_seed

	for z in range(size):
		for x in range(size):
			var nx := float(x) / float(size)
			var nz := float(z) / float(size)
			var h := _fbm(nx, nz, freq, oct, lac, gain, s) * amp
			_data.set_height(x, z, h)

	heightmap_image = _data.height_image
	_mark_all_dirty()
	_flush_dirty_meshes(true)
	if Engine.is_editor_hint():
		notify_property_list_changed()
	print("[TerrainEditor] Generated seed=%d freq=%.1f oct=%d amp=%.2f" % [
		noise_seed, noise_frequency, noise_octaves, noise_amplitude
	])

func _hash2(x: int, z: int, s: int) -> float:
	var n := x * 374761393 + z * 668265263 + s * 1274126177
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / float(0x7fffffff)

func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

func _value_noise(x: float, z: float, s: int) -> float:
	var x0 := int(floor(x))
	var z0 := int(floor(z))
	var fx := _smooth(x - float(x0))
	var fz := _smooth(z - float(z0))
	var v00 := _hash2(x0, z0, s)
	var v10 := _hash2(x0 + 1, z0, s)
	var v01 := _hash2(x0, z0 + 1, s)
	var v11 := _hash2(x0 + 1, z0 + 1, s)
	var a := lerpf(v00, v10, fx)
	var b := lerpf(v01, v11, fx)
	return lerpf(a, b, fz) * 2.0 - 1.0

func _fbm(x: float, z: float, freq: float, octaves: int, lac: float, gain: float, s: int) -> float:
	var sum := 0.0
	var amp := 1.0
	var f := freq
	var max_amp := 0.0
	for i in range(octaves):
		sum += _value_noise(x * f, z * f, s + i * 1013) * amp
		max_amp += amp
		amp *= gain
		f *= lac
	return sum / maxf(max_amp, 0.0001)

# --- Physics ---------------------------------------------------------------

func _update_collision_radius() -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = _find_camera()
	if _camera == null:
		return
	var cam_pos := _camera.global_position
	var radius_sq := collision_radius * collision_radius
	var cws := _chunk_world_size()
	for key in _chunks.keys():
		var chunk: TerrainChunk = _chunks[key]
		if not is_instance_valid(chunk):
			continue
		var chunk_center := chunk.global_position + Vector3(cws * 0.5, 0.0, cws * 0.5)
		if cam_pos.distance_squared_to(chunk_center) <= radius_sq:
			if not chunk.has_collision:
				chunk.enable_collision()
		else:
			if chunk.has_collision:
				chunk.disable_collision()

func _find_camera() -> Camera3D:
	var viewport := get_viewport()
	if viewport:
		return viewport.get_camera_3d()
	return null

# --- Bridges ---------------------------------------------------------------

func apply_brush_settings(s: Dictionary) -> void:
	if _brush:
		_brush.apply_settings(s)

func apply_terrain_settings(s: Dictionary) -> void:
	if s.has("world_scale"):
		world_scale = s["world_scale"]
	if s.has("collision_radius"):
		collision_radius = float(s["collision_radius"])
	if s.has("terrain_material"):
		terrain_material = s["terrain_material"]
	if s.has("flip_winding"):
		flip_winding = bool(s["flip_winding"])
	if s.has("uv_scale"):
		uv_scale = s["uv_scale"]
	if s.has("uv_offset"):
		uv_offset = s["uv_offset"]
	if s.has("noise_seed"):
		noise_seed = int(s["noise_seed"])
	if s.has("noise_frequency"):
		noise_frequency = float(s["noise_frequency"])
	if s.has("noise_octaves"):
		noise_octaves = int(s["noise_octaves"])
	if s.has("noise_amplitude"):
		noise_amplitude = float(s["noise_amplitude"])

func get_average_height() -> float:
	if _data:
		return _data.get_average_height()
	return 0.0

func save_heightmap(path: String = "res://terrain_heightmap.exr") -> void:
	if _data == null:
		return
	heightmap_image = _data.height_image
	var err := _data.save_to_path(path)
	if err == OK:
		heightmap_path = path
		print("[TerrainEditor] Heightmap saved to ", path)
		if Engine.is_editor_hint():
			notify_property_list_changed()
	else:
		push_error("[TerrainEditor] Failed to save: %s" % error_string(err))

func clear_terrain() -> void:
	if _data == null:
		return
	_push_undo(_snapshot_bytes())
	_data.fill_flat(0.0)
	heightmap_image = _data.height_image
	_mark_all_dirty()
	_flush_dirty_meshes(true)

func load_heightmap(path: String) -> void:
	if _data == null:
		_data = TerrainDataScript.new(heightmap_size, world_scale)
	_push_undo(_snapshot_bytes())
	if _data.load_from_path(path) == OK:
		heightmap_image = _data.height_image
		heightmap_size = _data.size
		heightmap_path = path
		_rebuild_all_chunks()
		print("[TerrainEditor] Loaded ", path)
	else:
		push_error("[TerrainEditor] Failed to load ", path)
