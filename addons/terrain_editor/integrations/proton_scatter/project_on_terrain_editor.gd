@tool
extends "res://addons/proton_scatter/src/modifiers/base_modifier.gd"

## Project Proton Scatter instances onto Godot Mobile Terrain Editor heightmaps.
##
## INSTALL: copy (or symlink) this file into:
##   res://addons/proton_scatter/src/modifiers/project_on_terrain_editor.gd
## so it appears in the Scatter "Add Modifier" list (Proton discovers scripts there).
##
## Requires: addons/terrain_editor (TerrainManager) + addons/proton_scatter

@export_node_path("Node3D") var terrain_manager: NodePath
@export var height_offset := 0.0
@export var align_with_normal := false
@export_range(0.0, 90.0) var max_slope := 90.0
@export var remove_outside_bounds := true
@export var remove_on_steep_slope := true


func _init() -> void:
	display_name = "Project On Terrain Editor"
	category = "Edit"
	can_restrict_height = false
	global_reference_frame_available = true
	local_reference_frame_available = true
	individual_instances_reference_frame_available = false
	use_global_space_by_default()
	warning_ignore_no_shape = true

	documentation.add_paragraph(
		"Projects each transform onto a TerrainManager heightmap from the Godot Mobile Terrain Editor plugin. Samples height directly (no physics raycasts), which is faster and works even when collision bodies are disabled outside the camera radius.")

	documentation.add_paragraph(
		"Assign a TerrainManager node path, or leave empty to auto-find the first TerrainManager in the scene tree.")

	var p := documentation.add_parameter("Terrain Manager")
	p.set_type("NodePath")
	p.set_description("Path to the TerrainManager node. Relative to the scene root if absolute, or leave empty for auto-detect.")

	p = documentation.add_parameter("Height Offset")
	p.set_type("float")
	p.set_description("Extra vertical offset applied after projection (useful for grass roots / floating fix).")

	p = documentation.add_parameter("Align With Normal")
	p.set_type("bool")
	p.set_description("Rotate instances so their up axis matches the terrain slope.")

	p = documentation.add_parameter("Max Slope")
	p.set_type("float")
	p.set_description("Maximum slope angle in degrees. Steeper points are removed when Remove On Steep Slope is enabled.")


func _process_transforms(transforms, domain, _seed) -> void:
	var terrain := _resolve_terrain(domain)
	if terrain == null:
		warning += "No TerrainManager found. Assign terrain_manager or add a TerrainManager to the scene.\n"
		return

	if not terrain.has_method("sample_height_at_global"):
		warning += "TerrainManager is missing sample_height_at_global(). Update terrain_editor to v0.2.1+.\n"
		return

	var gt: Transform3D = domain.get_global_transform()
	var gt_inverse := gt.affine_inverse()
	var remapped_max_slope := remap(max_slope, 0.0, 90.0, 0.0, 1.0)
	var new_list: Array[Transform3D] = []

	for i in transforms.size():
		if interrupt_update:
			return

		var t: Transform3D = transforms.list[i]
		var global_origin: Vector3 = gt * t.origin

		if remove_outside_bounds and terrain.has_method("is_inside_bounds_global"):
			if not terrain.is_inside_bounds_global(global_origin):
				continue

		var height: float = terrain.sample_height_at_global(global_origin)
		global_origin.y = height + height_offset

		var normal := Vector3.UP
		if align_with_normal or remove_on_steep_slope:
			if terrain.has_method("sample_normal_at_global"):
				normal = terrain.sample_normal_at_global(global_origin)
			var slope_ok := absf(Vector3.UP.dot(normal)) >= (1.0 - remapped_max_slope)
			if remove_on_steep_slope and not slope_ok:
				continue
			if align_with_normal and slope_ok:
				t = _align_with(t, gt_inverse.basis * normal)

		t.origin = gt_inverse * global_origin
		new_list.push_back(t)

	transforms.list.clear()
	transforms.list.append_array(new_list)

	if transforms.is_empty():
		warning += "All points were removed. Check terrain bounds, max slope, or scatter shape placement.\n"


func _resolve_terrain(domain) -> Node:
	var root: Node = domain.get_root()
	if root == null:
		return null

	var tree := root.get_tree()
	if tree == null:
		return null

	if terrain_manager != NodePath() and not terrain_manager.is_empty():
		# Try from scatter node first, then scene root
		var n: Node = root.get_node_or_null(terrain_manager)
		if n == null:
			n = tree.root.get_node_or_null(terrain_manager)
		if n != null:
			return n

	# Auto-find first TerrainManager (class_name or script)
	return _find_terrain_manager(tree.root)


func _find_terrain_manager(node: Node) -> Node:
	if node == null:
		return null
	if node.get_class() == "TerrainManager" or (node.get_script() and str(node.get_script().resource_path).ends_with("terrain_manager.gd")):
		return node
	# class_name TerrainManager
	if node is Node3D and node.has_method("sample_height_at_global") and node.has_method("get_average_height"):
		return node
	for child in node.get_children():
		var found := _find_terrain_manager(child)
		if found:
			return found
	return null


func _align_with(t: Transform3D, normal: Vector3) -> Transform3D:
	var n1 := t.basis.y.normalized()
	var n2 := normal.normalized()
	var cosa := clampf(n1.dot(n2), -1.0, 1.0)
	var alpha := acos(cosa)
	var axis := n1.cross(n2)
	if axis.length_squared() < 0.000001:
		return t
	return t.rotated(axis.normalized(), alpha)
