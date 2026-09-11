@tool
class_name SculptBrush
extends RefCounted

## Localized height sculpt + splat texture paint.

enum Mode {
	RAISE,
	LOWER,
	SMOOTH,
	FLATTEN,
	PAINT
}

var mode: Mode = Mode.RAISE
var radius_px: int = 16
var strength: float = 0.15
var falloff: float = 0.5
var flatten_target: float = 0.0
var paint_layer: int = 0  # 0-3 for splat channels

func world_to_pixel(data: TerrainData, world_pos: Vector3) -> Vector2i:
	var u := (world_pos.x / data.world_scale.x) * data.size
	var v := (world_pos.z / data.world_scale.z) * data.size
	return Vector2i(int(u), int(v))

func apply(data: TerrainData, world_pos: Vector3, pressure: float = 1.0) -> Rect2i:
	if data == null or data.height_image == null:
		return Rect2i()

	var center := world_to_pixel(data, world_pos)
	var rect := data.brush_rect(center, radius_px)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return Rect2i()

	if mode == Mode.PAINT:
		var paint_str := clampf(strength * pressure * 2.0, 0.01, 1.0)
		data.paint_splat_rect(rect, center, radius_px, paint_layer, paint_str, falloff)
		return rect

	var deltas := PackedFloat32Array()
	deltas.resize(rect.size.x * rect.size.y)
	var r2 := float(radius_px * radius_px)
	var inv_r := 1.0 / float(maxi(radius_px, 1))
	var effective_str := strength * pressure

	match mode:
		Mode.RAISE, Mode.LOWER:
			var sign := 1.0 if mode == Mode.RAISE else -1.0
			var i := 0
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				for x in range(rect.position.x, rect.position.x + rect.size.x):
					var dx := float(x - center.x)
					var dy := float(y - center.y)
					var dist2 := dx * dx + dy * dy
					if dist2 > r2:
						deltas[i] = 0.0
					else:
						var t := 1.0 - sqrt(dist2) * inv_r
						var w := lerpf(t, t * t, falloff)
						deltas[i] = sign * effective_str * w
					i += 1
			data.apply_delta_rect(rect, deltas)

		Mode.SMOOTH:
			var i := 0
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				for x in range(rect.position.x, rect.position.x + rect.size.x):
					var dx := float(x - center.x)
					var dy := float(y - center.y)
					var dist2 := dx * dx + dy * dy
					if dist2 > r2:
						deltas[i] = 0.0
					else:
						var avg := _sample_average(data, x, y, 1)
						var cur := data.get_height(x, y)
						var t := 1.0 - sqrt(dist2) * inv_r
						var w := lerpf(t, t * t, falloff) * effective_str
						deltas[i] = (avg - cur) * w
					i += 1
			data.apply_delta_rect(rect, deltas)

		Mode.FLATTEN:
			var i := 0
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				for x in range(rect.position.x, rect.position.x + rect.size.x):
					var dx := float(x - center.x)
					var dy := float(y - center.y)
					var dist2 := dx * dx + dy * dy
					if dist2 > r2:
						deltas[i] = 0.0
					else:
						var cur := data.get_height(x, y)
						var t := 1.0 - sqrt(dist2) * inv_r
						var w := lerpf(t, t * t, falloff) * effective_str
						deltas[i] = (flatten_target - cur) * w
					i += 1
			data.apply_delta_rect(rect, deltas)

	return rect

func _sample_average(data: TerrainData, cx: int, cy: int, radius: int) -> float:
	var sum := 0.0
	var count := 0
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			sum += data.get_height(x, y)
			count += 1
	return sum / float(maxi(count, 1))

func apply_settings(s: Dictionary) -> void:
	if s.has("mode"):
		mode = int(s["mode"]) as Mode
	if s.has("radius"):
		radius_px = clampi(int(s["radius"]), 1, 128)
	if s.has("strength"):
		strength = clampf(float(s["strength"]), 0.001, 2.0)
	if s.has("falloff"):
		falloff = clampf(float(s["falloff"]), 0.0, 1.0)
	if s.has("flatten_target"):
		flatten_target = float(s["flatten_target"])
	if s.has("paint_layer"):
		paint_layer = clampi(int(s["paint_layer"]), 0, 3)
