@tool
extends Control

## Compact mobile sidebar – undo/redo, generate, UV tiling.

signal brush_settings_changed(settings: Dictionary)
signal terrain_settings_changed(settings: Dictionary)
signal utility_action(action: String)

const BTN_H := 56
const HEADER_H := 44
const SLIDER_H := 36

var _manager: Node = null
var _minimized: bool = false

var _mode: int = 0
var _radius: float = 16.0
var _strength: float = 0.15
var _falloff: float = 0.5

var _scale_x: float = 256.0
var _scale_y: float = 32.0
var _scale_z: float = 256.0
var _collision_radius: float = 64.0

var _uv_scale: float = 1.0
var _uv_offset_x: float = 0.0
var _uv_offset_y: float = 0.0

var _noise_seed: int = 42
var _noise_freq: float = 4.0
var _noise_octaves: int = 4
var _noise_amp: float = 1.0

@onready var _header_btn: Button = $Panel/Margin/VBox/Header/MinimizeBtn
@onready var _scroll: ScrollContainer = $Panel/Margin/VBox/Scroll
@onready var _content: VBoxContainer = $Panel/Margin/VBox/Scroll/Content

@onready var _brush_header: Button = $Panel/Margin/VBox/Scroll/Content/BrushHeader
@onready var _brush_body: VBoxContainer = $Panel/Margin/VBox/Scroll/Content/BrushBody
@onready var _mode_raise: Button = $Panel/Margin/VBox/Scroll/Content/BrushBody/ModeGrid/Raise
@onready var _mode_lower: Button = $Panel/Margin/VBox/Scroll/Content/BrushBody/ModeGrid/Lower
@onready var _mode_smooth: Button = $Panel/Margin/VBox/Scroll/Content/BrushBody/ModeGrid/Smooth
@onready var _mode_flatten: Button = $Panel/Margin/VBox/Scroll/Content/BrushBody/ModeGrid/Flatten
@onready var _radius_slider: HSlider = $Panel/Margin/VBox/Scroll/Content/BrushBody/RadiusRow/Slider
@onready var _radius_label: Label = $Panel/Margin/VBox/Scroll/Content/BrushBody/RadiusRow/Value
@onready var _strength_slider: HSlider = $Panel/Margin/VBox/Scroll/Content/BrushBody/StrengthRow/Slider
@onready var _strength_label: Label = $Panel/Margin/VBox/Scroll/Content/BrushBody/StrengthRow/Value
@onready var _falloff_slider: HSlider = $Panel/Margin/VBox/Scroll/Content/BrushBody/FalloffRow/Slider
@onready var _falloff_label: Label = $Panel/Margin/VBox/Scroll/Content/BrushBody/FalloffRow/Value

@onready var _terrain_header: Button = $Panel/Margin/VBox/Scroll/Content/TerrainHeader
@onready var _terrain_body: VBoxContainer = $Panel/Margin/VBox/Scroll/Content/TerrainBody
@onready var _sx_slider: HSlider = $Panel/Margin/VBox/Scroll/Content/TerrainBody/ScaleXRow/Slider
@onready var _sx_label: Label = $Panel/Margin/VBox/Scroll/Content/TerrainBody/ScaleXRow/Value
@onready var _sy_slider: HSlider = $Panel/Margin/VBox/Scroll/Content/TerrainBody/ScaleYRow/Slider
@onready var _sy_label: Label = $Panel/Margin/VBox/Scroll/Content/TerrainBody/ScaleYRow/Value
@onready var _sz_slider: HSlider = $Panel/Margin/VBox/Scroll/Content/TerrainBody/ScaleZRow/Slider
@onready var _sz_label: Label = $Panel/Margin/VBox/Scroll/Content/TerrainBody/ScaleZRow/Value
@onready var _col_slider: HSlider = $Panel/Margin/VBox/Scroll/Content/TerrainBody/CollisionRow/Slider
@onready var _col_label: Label = $Panel/Margin/VBox/Scroll/Content/TerrainBody/CollisionRow/Value
@onready var _uvs_slider: HSlider = $Panel/Margin/VBox/Scroll/Content/TerrainBody/UVScaleRow/Slider
@onready var _uvs_label: Label = $Panel/Margin/VBox/Scroll/Content/TerrainBody/UVScaleRow/Value
@onready var _uvox_slider: HSlider = $Panel/Margin/VBox/Scroll/Content/TerrainBody/UVOffXRow/Slider
@onready var _uvox_label: Label = $Panel/Margin/VBox/Scroll/Content/TerrainBody/UVOffXRow/Value
@onready var _uvoy_slider: HSlider = $Panel/Margin/VBox/Scroll/Content/TerrainBody/UVOffYRow/Slider
@onready var _uvoy_label: Label = $Panel/Margin/VBox/Scroll/Content/TerrainBody/UVOffYRow/Value

@onready var _gen_header: Button = $Panel/Margin/VBox/Scroll/Content/GenHeader
@onready var _gen_body: VBoxContainer = $Panel/Margin/VBox/Scroll/Content/GenBody
@onready var _seed_slider: HSlider = $Panel/Margin/VBox/Scroll/Content/GenBody/SeedRow/Slider
@onready var _seed_label: Label = $Panel/Margin/VBox/Scroll/Content/GenBody/SeedRow/Value
@onready var _freq_slider: HSlider = $Panel/Margin/VBox/Scroll/Content/GenBody/FreqRow/Slider
@onready var _freq_label: Label = $Panel/Margin/VBox/Scroll/Content/GenBody/FreqRow/Value
@onready var _oct_slider: HSlider = $Panel/Margin/VBox/Scroll/Content/GenBody/OctRow/Slider
@onready var _oct_label: Label = $Panel/Margin/VBox/Scroll/Content/GenBody/OctRow/Value
@onready var _amp_slider: HSlider = $Panel/Margin/VBox/Scroll/Content/GenBody/AmpRow/Slider
@onready var _amp_label: Label = $Panel/Margin/VBox/Scroll/Content/GenBody/AmpRow/Value
@onready var _gen_btn: Button = $Panel/Margin/VBox/Scroll/Content/GenBody/GenBtn

@onready var _util_header: Button = $Panel/Margin/VBox/Scroll/Content/UtilHeader
@onready var _util_body: VBoxContainer = $Panel/Margin/VBox/Scroll/Content/UtilBody
@onready var _undo_btn: Button = $Panel/Margin/VBox/Scroll/Content/UtilBody/UndoRedoRow/UndoBtn
@onready var _redo_btn: Button = $Panel/Margin/VBox/Scroll/Content/UtilBody/UndoRedoRow/RedoBtn
@onready var _save_btn: Button = $Panel/Margin/VBox/Scroll/Content/UtilBody/SaveBtn
@onready var _clear_btn: Button = $Panel/Margin/VBox/Scroll/Content/UtilBody/ClearBtn

func _ready() -> void:
	custom_minimum_size = Vector2(280, 0)
	_setup_sizes()
	_connect_signals()
	_terrain_body.visible = false
	_gen_body.visible = false
	_util_body.visible = false
	_terrain_header.text = "▶ Terrain Settings"
	_gen_header.text = "▶ Generate"
	_util_header.text = "▶ Utility Actions"
	_update_mode_buttons()
	_refresh_labels()

func bind_manager(mgr: Node) -> void:
	_manager = mgr
	if mgr.get("world_scale"):
		var s: Vector3 = mgr.world_scale
		_scale_x = s.x; _scale_y = s.y; _scale_z = s.z
		_sx_slider.value = _scale_x
		_sy_slider.value = _scale_y
		_sz_slider.value = _scale_z
	if mgr.get("collision_radius"):
		_collision_radius = mgr.collision_radius
		_col_slider.value = _collision_radius
	if mgr.get("uv_scale"):
		_uv_scale = mgr.uv_scale.x
		_uvs_slider.value = _uv_scale
	if mgr.get("uv_offset"):
		_uv_offset_x = mgr.uv_offset.x
		_uv_offset_y = mgr.uv_offset.y
		_uvox_slider.value = _uv_offset_x
		_uvoy_slider.value = _uv_offset_y
	if mgr.get("noise_seed"):
		_noise_seed = mgr.noise_seed
		_seed_slider.value = _noise_seed
	if mgr.get("noise_frequency"):
		_noise_freq = mgr.noise_frequency
		_freq_slider.value = _noise_freq
	if mgr.get("noise_octaves"):
		_noise_octaves = mgr.noise_octaves
		_oct_slider.value = _noise_octaves
	if mgr.get("noise_amplitude"):
		_noise_amp = mgr.noise_amplitude
		_amp_slider.value = _noise_amp
	_refresh_labels()
	_emit_brush()
	_emit_terrain()

func set_minimized(m: bool) -> void:
	_minimized = m
	_scroll.visible = not m
	_header_btn.text = "▶ Terrain" if m else "▼ Terrain Editor"

func _connect_signals() -> void:
	_header_btn.pressed.connect(_on_minimize)
	_brush_header.pressed.connect(_toggle_section.bind(_brush_header, _brush_body, "Brush Settings"))
	_terrain_header.pressed.connect(_toggle_section.bind(_terrain_header, _terrain_body, "Terrain Settings"))
	_gen_header.pressed.connect(_toggle_section.bind(_gen_header, _gen_body, "Generate"))
	_util_header.pressed.connect(_toggle_section.bind(_util_header, _util_body, "Utility Actions"))

	_mode_raise.pressed.connect(func(): _set_mode(0))
	_mode_lower.pressed.connect(func(): _set_mode(1))
	_mode_smooth.pressed.connect(func(): _set_mode(2))
	_mode_flatten.pressed.connect(func(): _set_mode(3))

	_radius_slider.value_changed.connect(_on_radius)
	_strength_slider.value_changed.connect(_on_strength)
	_falloff_slider.value_changed.connect(_on_falloff)
	_sx_slider.value_changed.connect(_on_scale_x)
	_sy_slider.value_changed.connect(_on_scale_y)
	_sz_slider.value_changed.connect(_on_scale_z)
	_col_slider.value_changed.connect(_on_collision)
	_uvs_slider.value_changed.connect(_on_uv_scale)
	_uvox_slider.value_changed.connect(_on_uv_ox)
	_uvoy_slider.value_changed.connect(_on_uv_oy)

	_seed_slider.value_changed.connect(_on_seed)
	_freq_slider.value_changed.connect(_on_freq)
	_oct_slider.value_changed.connect(_on_oct)
	_amp_slider.value_changed.connect(_on_amp)
	_gen_btn.pressed.connect(_on_generate)

	_undo_btn.pressed.connect(func(): utility_action.emit("undo"))
	_redo_btn.pressed.connect(func(): utility_action.emit("redo"))
	_save_btn.pressed.connect(func(): utility_action.emit("save"))
	_clear_btn.pressed.connect(func(): utility_action.emit("clear"))

func _toggle_section(header: Button, body: Control, title: String) -> void:
	body.visible = not body.visible
	header.text = ("▼ " if body.visible else "▶ ") + title

func _on_minimize() -> void:
	set_minimized(not _minimized)
	if _minimized:
		utility_action.emit("minimize")

func _set_mode(m: int) -> void:
	_mode = m
	_update_mode_buttons()
	_emit_brush()

func _on_radius(v: float) -> void:
	_radius = v; _radius_label.text = str(int(v)); _emit_brush()
func _on_strength(v: float) -> void:
	_strength = v; _strength_label.text = "%.2f" % v; _emit_brush()
func _on_falloff(v: float) -> void:
	_falloff = v; _falloff_label.text = "%.2f" % v; _emit_brush()
func _on_scale_x(v: float) -> void:
	_scale_x = v; _sx_label.text = str(int(v)); _emit_terrain()
func _on_scale_y(v: float) -> void:
	_scale_y = v; _sy_label.text = str(int(v)); _emit_terrain()
func _on_scale_z(v: float) -> void:
	_scale_z = v; _sz_label.text = str(int(v)); _emit_terrain()
func _on_collision(v: float) -> void:
	_collision_radius = v; _col_label.text = str(int(v)); _emit_terrain()
func _on_uv_scale(v: float) -> void:
	_uv_scale = v; _uvs_label.text = "%.1f" % v; _emit_terrain()
func _on_uv_ox(v: float) -> void:
	_uv_offset_x = v; _uvox_label.text = "%.2f" % v; _emit_terrain()
func _on_uv_oy(v: float) -> void:
	_uv_offset_y = v; _uvoy_label.text = "%.2f" % v; _emit_terrain()
func _on_seed(v: float) -> void:
	_noise_seed = int(v); _seed_label.text = str(_noise_seed)
func _on_freq(v: float) -> void:
	_noise_freq = v; _freq_label.text = "%.1f" % v
func _on_oct(v: float) -> void:
	_noise_octaves = int(v); _oct_label.text = str(_noise_octaves)
func _on_amp(v: float) -> void:
	_noise_amp = v; _amp_label.text = "%.2f" % v

func _on_generate() -> void:
	# Push noise params then generate
	terrain_settings_changed.emit({
		"noise_seed": _noise_seed,
		"noise_frequency": _noise_freq,
		"noise_octaves": _noise_octaves,
		"noise_amplitude": _noise_amp
	})
	utility_action.emit("generate")

func _emit_brush() -> void:
	brush_settings_changed.emit({
		"mode": _mode, "radius": int(_radius),
		"strength": _strength, "falloff": _falloff
	})

func _emit_terrain() -> void:
	terrain_settings_changed.emit({
		"world_scale": Vector3(_scale_x, _scale_y, _scale_z),
		"collision_radius": _collision_radius,
		"uv_scale": Vector2(_uv_scale, _uv_scale),
		"uv_offset": Vector2(_uv_offset_x, _uv_offset_y)
	})

func _update_mode_buttons() -> void:
	var btns := [_mode_raise, _mode_lower, _mode_smooth, _mode_flatten]
	for i in range(btns.size()):
		btns[i].button_pressed = (i == _mode)
		btns[i].modulate = Color(0.45, 0.85, 1.0) if i == _mode else Color.WHITE

func _refresh_labels() -> void:
	_radius_label.text = str(int(_radius))
	_strength_label.text = "%.2f" % _strength
	_falloff_label.text = "%.2f" % _falloff
	_sx_label.text = str(int(_scale_x))
	_sy_label.text = str(int(_scale_y))
	_sz_label.text = str(int(_scale_z))
	_col_label.text = str(int(_collision_radius))
	_uvs_label.text = "%.1f" % _uv_scale
	_uvox_label.text = "%.2f" % _uv_offset_x
	_uvoy_label.text = "%.2f" % _uv_offset_y
	_seed_label.text = str(_noise_seed)
	_freq_label.text = "%.1f" % _noise_freq
	_oct_label.text = str(_noise_octaves)
	_amp_label.text = "%.2f" % _noise_amp

func _setup_sizes() -> void:
	_header_btn.custom_minimum_size = Vector2(0, HEADER_H)
	for btn in [_mode_raise, _mode_lower, _mode_smooth, _mode_flatten,
			_save_btn, _clear_btn, _gen_btn, _undo_btn, _redo_btn]:
		if btn:
			btn.custom_minimum_size = Vector2(0, BTN_H)
	for h in [_brush_header, _terrain_header, _gen_header, _util_header]:
		if h:
			h.custom_minimum_size = Vector2(0, HEADER_H)
	for slider in [_radius_slider, _strength_slider, _falloff_slider,
			_sx_slider, _sy_slider, _sz_slider, _col_slider,
			_uvs_slider, _uvox_slider, _uvoy_slider,
			_seed_slider, _freq_slider, _oct_slider, _amp_slider]:
		if slider:
			slider.custom_minimum_size = Vector2(0, SLIDER_H)
			slider.scrollable = false
