@tool
class_name TerrainData
extends RefCounted

## Half-precision (FORMAT_RH) heightmap storage.
## 2 bytes per sample – critical for staying under the 3–4 GB limit of 32-bit armv7.

const DEFAULT_SIZE: int = 256
const DEFAULT_HEIGHT: float = 0.0

var size: int = DEFAULT_SIZE
var height_image: Image = null
var world_scale: Vector3 = Vector3(1.0, 1.0, 1.0)

## Pixel spacing in world units (derived from world_scale.x / size)
var pixel_world_size: float = 1.0

func _init(p_size: int = DEFAULT_SIZE, p_scale: Vector3 = Vector3.ONE, existing: Image = null) -> void:
	size = maxi(p_size, 8)
	world_scale = p_scale
	_recalc_pixel_size()
	if existing != null and not existing.is_empty():
		_adopt_image(existing)
	else:
		_create_image()

func _recalc_pixel_size() -> void:
	pixel_world_size = world_scale.x / float(maxi(size, 1))

func _create_image() -> void:
	height_image = Image.create(size, size, false, Image.FORMAT_RH)
	height_image.fill(Color(DEFAULT_HEIGHT, 0.0, 0.0, 1.0))

## Take ownership of an existing Image (e.g. one exported on TerrainManager)
func _adopt_image(img: Image) -> void:
	if img.get_format() != Image.FORMAT_RH:
		img.convert(Image.FORMAT_RH)
	height_image = img
	size = height_image.get_width()
	# Force square
	if height_image.get_height() != size:
		height_image.resize(size, size, Image.INTERPOLATE_NEAREST)
	_recalc_pixel_size()

func set_image(img: Image) -> void:
	if img == null or img.is_empty():
		_create_image()
	else:
		_adopt_image(img)

func resize(new_size: int) -> void:
	new_size = maxi(new_size, 8)
	if new_size == size and height_image != null:
		return
	var old := height_image
	size = new_size
	_recalc_pixel_size()
	height_image = Image.create(size, size, false, Image.FORMAT_RH)
	if old != null and not old.is_empty():
		height_image.blit_rect(old, Rect2i(0, 0, old.get_width(), old.get_height()), Vector2i.ZERO)
		if old.get_width() != size or old.get_height() != size:
			height_image.resize(size, size, Image.INTERPOLATE_NEAREST)
	else:
		height_image.fill(Color(DEFAULT_HEIGHT, 0.0, 0.0, 1.0))

func set_world_scale(s: Vector3) -> void:
	world_scale = s
	_recalc_pixel_size()

# ---------------------------------------------------------------------------
# Height accessors (half-float safe)
# ---------------------------------------------------------------------------

func get_height(x: int, z: int) -> float:
	if height_image == null:
		return 0.0
	x = clampi(x, 0, size - 1)
	z = clampi(z, 0, size - 1)
	return height_image.get_pixel(x, z).r

func set_height(x: int, z: int, h: float) -> void:
	if height_image == null:
		return
	x = clampi(x, 0, size - 1)
	z = clampi(z, 0, size - 1)
	height_image.set_pixel(x, z, Color(h, 0.0, 0.0, 1.0))

func get_height_world(wx: float, wz: float) -> float:
	var px := int((wx / world_scale.x) * size)
	var pz := int((wz / world_scale.z) * size)
	return get_height(px, pz) * world_scale.y

func get_average_height() -> float:
	if height_image == null:
		return 0.0
	var sum := 0.0
	var step := maxi(size / 8, 1)
	var count := 0
	for z in range(0, size, step):
		for x in range(0, size, step):
			sum += get_height(x, z)
			count += 1
	return (sum / float(maxi(count, 1))) * world_scale.y

# ---------------------------------------------------------------------------
# Bulk operations used by the sculpt brush
# ---------------------------------------------------------------------------

func brush_rect(center_px: Vector2i, radius_px: int) -> Rect2i:
	var r := radius_px
	var x0 := clampi(center_px.x - r, 0, size - 1)
	var y0 := clampi(center_px.y - r, 0, size - 1)
	var x1 := clampi(center_px.x + r, 0, size - 1)
	var y1 := clampi(center_px.y + r, 0, size - 1)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)

func apply_delta_rect(rect: Rect2i, deltas: PackedFloat32Array) -> void:
	if height_image == null:
		return
	if deltas.size() != rect.size.x * rect.size.y:
		push_error("TerrainData.apply_delta_rect: size mismatch")
		return
	var i := 0
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var h := height_image.get_pixel(x, y).r + deltas[i]
			height_image.set_pixel(x, y, Color(h, 0.0, 0.0, 1.0))
			i += 1

func fill_flat(height: float = 0.0) -> void:
	if height_image:
		height_image.fill(Color(height, 0.0, 0.0, 1.0))

# ---------------------------------------------------------------------------
# Serialization helpers
# ---------------------------------------------------------------------------

func save_to_path(path: String) -> Error:
	if height_image == null:
		return ERR_INVALID_DATA
	return height_image.save_exr(path, false)

func load_from_path(path: String) -> Error:
	var img := Image.load_from_file(path)
	if img == null:
		return ERR_FILE_CANT_OPEN
	_adopt_image(img)
	return OK

func duplicate_data() -> TerrainData:
	var td := TerrainData.new(size, world_scale)
	if height_image:
		td.height_image = height_image.duplicate()
	return td
