@tool
extends EditorPlugin

## Terrain Editor – Mobile-optimized pure GDScript plugin for Godot 4.x
## Registers the TerrainManager type and captures multi-touch sculpting input.

const TerrainManager = preload("res://addons/terrain_editor/terrain_manager.gd")
const TerrainChunk = preload("res://addons/terrain_editor/terrain_chunk.gd")
const OverlayScene = preload("res://addons/terrain_editor/ui/terrain_editor_overlay.tscn")

var _overlay: Control = null
var _terrain_manager: TerrainManager = null
var _is_sculpting: bool = false
var _last_drag_pos: Vector2 = Vector2.ZERO

func _enter_tree() -> void:
	# Register custom types so they appear in the Create dialog
	add_custom_type(
		"TerrainManager",
		"Node3D",
		TerrainManager,
		null
	)
	add_custom_type(
		"TerrainChunk",
		"MeshInstance3D",
		TerrainChunk,
		null
	)

	# Mobile overlay panel (right-side sidebar)
	_overlay = OverlayScene.instantiate()
	_overlay.name = "TerrainEditorOverlay"
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, _overlay)
	_overlay.hide()

	# Forward signals from UI → manager
	if _overlay.has_signal("brush_settings_changed"):
		_overlay.brush_settings_changed.connect(_on_brush_settings_changed)
	if _overlay.has_signal("terrain_settings_changed"):
		_overlay.terrain_settings_changed.connect(_on_terrain_settings_changed)
	if _overlay.has_signal("utility_action"):
		_overlay.utility_action.connect(_on_utility_action)

func _exit_tree() -> void:
	if _overlay:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, _overlay)
		_overlay.queue_free()
		_overlay = null
	remove_custom_type("TerrainManager")
	remove_custom_type("TerrainChunk")

func _handles(object: Object) -> bool:
	return object is TerrainManager or (object is Node and object.get_parent() is TerrainManager)

func _edit(object: Object) -> void:
	if object is TerrainManager:
		_terrain_manager = object as TerrainManager
		if _overlay:
			_overlay.show()
			_overlay.bind_manager(_terrain_manager)
	else:
		_terrain_manager = null
		if _overlay:
			_overlay.hide()

func _make_visible(visible: bool) -> void:
	if _overlay:
		_overlay.visible = visible and _terrain_manager != null

# ---------------------------------------------------------------------------
# Multi-touch / mouse input forwarding via camera raycast
# ---------------------------------------------------------------------------

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _terrain_manager == null or not is_instance_valid(_terrain_manager):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	# Accept both mouse (desktop testing) and touch (mobile)
	var is_press := false
	var is_release := false
	var is_drag := false
	var screen_pos := Vector2.ZERO
	var pressure := 1.0

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		screen_pos = st.position
		is_press = st.pressed
		is_release = not st.pressed
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		screen_pos = sd.position
		is_drag = true
		pressure = sd.pressure if sd.pressure > 0.0 else 1.0
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		screen_pos = mb.position
		is_press = mb.pressed
		is_release = not mb.pressed
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		screen_pos = mm.position
		is_drag = true
	else:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	# Raycast from camera through screen position onto the XZ plane (y = 0 base)
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	# Intersect with the terrain's average height plane for better accuracy
	var plane_y := 0.0
	if _terrain_manager.has_method("get_average_height"):
		plane_y = _terrain_manager.get_average_height()
	var t := (plane_y - from.y) / dir.y
	if t < 0.0:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var world_pos := from + dir * t

	if is_press:
		_is_sculpting = true
		_last_drag_pos = screen_pos
		_terrain_manager.begin_stroke(world_pos)
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	if is_release:
		_is_sculpting = false
		_terrain_manager.end_stroke()
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	if is_drag and _is_sculpting:
		_terrain_manager.continue_stroke(world_pos, pressure)
		_last_drag_pos = screen_pos
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS

# ---------------------------------------------------------------------------
# UI → Manager signal bridges
# ---------------------------------------------------------------------------

func _on_brush_settings_changed(settings: Dictionary) -> void:
	if _terrain_manager:
		_terrain_manager.apply_brush_settings(settings)

func _on_terrain_settings_changed(settings: Dictionary) -> void:
	if _terrain_manager:
		_terrain_manager.apply_terrain_settings(settings)

func _on_utility_action(action: String) -> void:
	if _terrain_manager == null:
		return
	match action:
		"save":
			_terrain_manager.save_heightmap()
		"clear":
			_terrain_manager.clear_terrain()
		"undo":
			_terrain_manager.undo()
		"redo":
			_terrain_manager.redo()
		"generate":
			_terrain_manager.generate_random_terrain()
		"minimize":
			if _overlay:
				_overlay.set_minimized(true)
