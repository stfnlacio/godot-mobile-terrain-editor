@tool
class_name TerrainData
extends RefCounted

## Half-precision heightmap + RGBA8 splatmap (4 texture layers).

const DEFAULT_SIZE: int = 256
const DEFAULT_HEIGHT: float = 0.0

var size: int = DEFAULT_SIZE
var height_image: Image = null
var splat_image: Image = null
var world_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
var pixel_world_size: float = 1.0

func _init(p_size: int = DEFAULT_SIZE, p_scale: Vector3 = Vector3.ONE, existing: Image = null) -> void:
	size = maxi(p_size, 8)
	world_scale = p_scale
	_recalc_pixel_size()
	if existing != null and not existing.is_empty():
		_adopt_image(existing)
	else:
		_create_image()
	_ensure_splat()

func _recalc_pixel_size() -> void:
	pixel_world_size = world_scale.x / float(maxi(size, 1))

func _create_image() -> void:
	height_image = Image.create(size, size, false, Image.FORMAT_RH)
	height_image.fill(Color(DEFAULT_HEIGHT, 0.0, 0.0, 1.0))

func _ensure_splat() -> void:
	if splat_image != null and splat_image.get_width() == size and splat_image.get_height() == size:
		return
	splat_image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	# Default: full weight on layer 0 (red channel)
	splat_image.fill(Color(1.0, 0.0, 0.0, 0.0))

func _adopt_image(img: Image) -> void:
	if img.get_format() != Image.FORMAT_RH:
		img.convert(Image.FORMAT_RH)
	height_image = img
	size = height_image.get_width()
	if height_image.get_height() != size:
		height_image.resize(size, size, Image.INTERPOLATE_NEAREST)
	_recalc_pixel_size()
	_ensure_splat()

func set_image(img: Image) -> void:
	if img == null or img.is_empty():
		_create_image()
	else:
		_adopt_image(img)
	_ensure_splat()

func set_splat_image(img: Image) -> void:
	if img == null or img.is_empty():
		_ensure_splat()
		return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != size or img.get_height() != size:
		img.resize(size, size, Image.INTERPOLATE_BILINEAR)
	splat_image = img

func resize(new_size: int) -> void:
	new_size = maxi(new_size, 8)
	if new_size == size and height_image != null:
		return
	var old_h := height_image
	var old_s := splat_image
	size = new_size
	_recalc_pixel_size()
	height_image = Image.create(size, size, false, Image.FORMAT_RH)
	if old_h != null and not old_h.is_empty():
		height_image.blit_rect(old_h, Rect2i(0, 0, old_h.get_width(), old_h.get_height()), Vector2i.ZERO)
		if old_h.get_width() != size or old_h.get_height() != size:
			height_image.resize(size, size, Image.INTERPOLATE_NEAREST)
	else:
		height_image.fill(Color(DEFAULT_HEIGHT, 0.0, 0.0, 1.0))
	splat_image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	if old_s != null and not old_s.is_empty():
		splat_image.blit_rect(old_s, Rect2i(0, 0, old_s.get_width(), old_s.get_height()), Vector2i.ZERO)
		if old_s.get_width() != size or old_s.get_height() != size:
			splat_image.resize(size, size, Image.INTERPOLATE_BILINEAR)
	else:
		splat_image.fill(Color(1.0, 0.0, 0.0, 0.0))

func set_world_scale(s: Vector3) -> void:
	world_scale = s
	_recalc_pixel_size()

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

## Paint splat layer (0-3). strength 0-1 how much to lean toward that layer.
func paint_splat_rect(rect: Rect2i, center: Vector2i, radius_px: int, layer: int, strength: float, falloff: float) -> void:
	_ensure_splat()
	layer = clampi(layer, 0, 3)
	var r2 := float(radius_px * radius_px)
	var inv_r := 1.0 / float(maxi(radius_px, 1))
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var dx := float(x - center.x)
			var dy := float(y - center.y)
			var dist2 := dx * dx + dy * dy
			if dist2 > r2:
				continue
			var t := 1.0 - sqrt(dist2) * inv_r
			var w := lerpf(t, t * t, falloff) * strength
			w = clampf(w, 0.0, 1.0)
			var c := splat_image.get_pixel(x, y)
			var weights := Vector4(c.r, c.g, c.b, c.a)
			# Softly move mass toward target layer
			var target := Vector4.ZERO
			match layer:
				0: target.x = 1.0
				1: target.y = 1.0
				2: target.z = 1.0
				3: target.w = 1.0
			weights = weights.lerp(target, w)
			var s := weights.x + weights.y + weights.z + weights.w
			if s > 0.0001:
				weights /= s
			splat_image.set_pixel(x, y, Color(weights.x, weights.y, weights.z, weights.w))

func fill_flat(height: float = 0.0) -> void:
	if height_image:
		height_image.fill(Color(height, 0.0, 0.0, 1.0))

func fill_splat_layer(layer: int = 0) -> void:
	_ensure_splat()
	var c := Color(0, 0, 0, 0)
	match clampi(layer, 0, 3):
		0: c = Color(1, 0, 0, 0)
		1: c = Color(0, 1, 0, 0)
		2: c = Color(0, 0, 1, 0)
		3: c = Color(0, 0, 0, 1)
	splat_image.fill(c)

func save_to_path(path: String) -> Error:
	if height_image == null:
		return ERR_INVALID_DATA
	return height_image.save_exr(path, false)

func save_splat_to_path(path: String) -> Error:
	_ensure_splat()
	return splat_image.save_png(path)

func load_from_path(path: String) -> Error:
	var img := Image.load_from_file(path)
	if img == null:
		return ERR_FILE_CANT_OPEN
	_adopt_image(img)
	return OK

func load_splat_from_path(path: String) -> Error:
	var img := Image.load_from_file(path)
	if img == null:
		return ERR_FILE_CANT_OPEN
	set_splat_image(img)
	return OK
