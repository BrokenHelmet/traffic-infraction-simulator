# ZoneUtils.gd
# Utility: build a world-space AABB that encloses a Node3D's MeshInstance3D geometry
extends Node
class_name ZoneUtils

static func get_aabb_from_node(node: Node3D, grow_margin: float = 0.0) -> AABB:
	# Use an explicit DFS to avoid type-inference issues and to include the node itself
	var found_any: bool = false
	var min_v: Vector3 = Vector3.ZERO
	var max_v: Vector3 = Vector3.ZERO

	var stack: Array = [node]

	while stack.size() > 0:
		var cur_node: Node = stack.pop_back()
		if not (cur_node is Node3D):
			continue

		var cur3: Node3D = cur_node as Node3D

		# If this node is a MeshInstance3D and has a mesh, compute its world-space AABB
		if cur3 is MeshInstance3D:
			var mesh_inst: MeshInstance3D = cur3 as MeshInstance3D
			var mesh: Mesh = mesh_inst.mesh
			if mesh != null:
				var local_aabb: AABB = mesh.get_aabb()

				# local min & max corners
				var local_min: Vector3 = local_aabb.position
				var local_max: Vector3 = local_aabb.position + local_aabb.size

				# build the 8 corners and transform to world space
				var corners: Array = [
					Vector3(local_min.x, local_min.y, local_min.z),
					Vector3(local_max.x, local_min.y, local_min.z),
					Vector3(local_min.x, local_max.y, local_min.z),
					Vector3(local_max.x, local_max.y, local_min.z),
					Vector3(local_min.x, local_min.y, local_max.z),
					Vector3(local_max.x, local_min.y, local_max.z),
					Vector3(local_min.x, local_max.y, local_max.z),
					Vector3(local_max.x, local_max.y, local_max.z)
				]

				for c in corners:
					# Transform corner to world space (Godot 4 style)
					var world_pt: Vector3 = mesh_inst.global_transform * c
					if not found_any:
						min_v = world_pt
						max_v = world_pt
						found_any = true
					else:
						min_v.x = min(min_v.x, world_pt.x)
						min_v.y = min(min_v.y, world_pt.y)
						min_v.z = min(min_v.z, world_pt.z)

						max_v.x = max(max_v.x, world_pt.x)
						max_v.y = max(max_v.y, world_pt.y)
						max_v.z = max(max_v.z, world_pt.z)


		# push children for processing
		for child in cur3.get_children():
			stack.push_back(child)

	# If nothing found, return empty AABB
	if not found_any:
		return AABB()

	# build the merged AABB
	var position: Vector3 = min_v
	var size: Vector3 = max_v - min_v
	var result_aabb: AABB = AABB(position, size)

	# apply grow margin (manual, avoids depending on AABB.grow availability)
	if grow_margin != 0.0:
		result_aabb.position -= Vector3.ONE * grow_margin
		result_aabb.size += Vector3.ONE * (grow_margin * 2.0)

	return result_aabb

func _draw_zone(aabb: AABB):
	var debug_box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = aabb.size
	debug_box.mesh = mesh
	debug_box.global_transform.origin = aabb.position + aabb.size * 0.5
	get_tree().current_scene.add_child(debug_box)

static func get_zone_vertices(aabb: AABB) -> PackedVector3Array:
	var verts := PackedVector3Array()
	var min := aabb.position
	var max := aabb.position + aabb.size

	# bottom rectangle (y = min.y)
	verts.append(Vector3(min.x, min.y, min.z)) # 0
	verts.append(Vector3(max.x, min.y, min.z)) # 1
	verts.append(Vector3(max.x, min.y, max.z)) # 2
	verts.append(Vector3(min.x, min.y, max.z)) # 3

	# top rectangle (y = max.y)
	verts.append(Vector3(min.x, max.y, min.z)) # 4
	verts.append(Vector3(max.x, max.y, min.z)) # 5
	verts.append(Vector3(max.x, max.y, max.z)) # 6
	verts.append(Vector3(min.x, max.y, max.z)) # 7

	return verts


static func make_zone_mesh(aabb: AABB, color: Color = Color(1, 0, 0, 1)) -> MeshInstance3D:
	# Create MeshInstance3D
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: ArrayMesh = ArrayMesh.new()

	# Get world-space corners (PackedVector3Array)
	var global_verts: PackedVector3Array = ZoneUtils.get_zone_vertices(aabb)
	# We'll make the mesh local to its center so the MeshInstance3D can be positioned easily
	var center: Vector3 = aabb.position + aabb.size * 0.5
	var local_verts: PackedVector3Array = PackedVector3Array()
	local_verts.resize(0)

	# edges defined by corner indices
	var edges := [
		[0,1], [1,2], [2,3], [3,0],  # bottom ring
		[4,5], [5,6], [6,7], [7,4],  # top ring
		[0,4], [1,5], [2,6], [3,7]   # verticals
	]

	# Build vertex list for PRIMITIVE_LINES (pairs of vertices per line)
	for e in edges:
		var a_idx: int = e[0]
		var b_idx: int = e[1]
		# convert to local (relative to center)
		local_verts.append(global_verts[a_idx] - center)
		local_verts.append(global_verts[b_idx] - center)

	# Prepare arrays container and put our vertices into the correct slot
	var arrays := [] 
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = local_verts

	# Create the line surface
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	# Simple material that uses a uniform color
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	# Optional: make it unlit so color isn't affected much by lighting
	mat.unshaded = true
	# Assign mesh + material
	mi.mesh = mesh
	mi.material_override = mat

	# Place the MeshInstance at the AABB center (world-space)
	# Using global_transform ensures correct world placement regardless of parent.
	var t := Transform3D.IDENTITY
	t.origin = center
	mi.global_transform = t

	return mi

static func create_debug_zone(aabb: AABB, color: Color = Color(1, 0, 0, 0.5)) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	
	# Start surface
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	# Extract corners
	var corners = ZoneUtils._get_aabb_corners(aabb)
	for edge in ZoneUtils._get_aabb_edges():
		mesh.surface_add_vertex(corners[edge[0]])
		mesh.surface_add_vertex(corners[edge[1]])
	mesh.surface_end()

	# Wrap in a MeshInstance3D
	var instance := MeshInstance3D.new()
	instance.mesh = mesh

	# Assign debug material
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.set_surface_override_material(0, material)

	return instance


static func _get_aabb_corners(aabb: AABB) -> Array:
	var pos = aabb.position
	var size = aabb.size
	return [
		pos,
		pos + Vector3(size.x, 0, 0),
		pos + Vector3(0, size.y, 0),
		pos + Vector3(0, 0, size.z),
		pos + Vector3(size.x, size.y, 0),
		pos + Vector3(size.x, 0, size.z),
		pos + Vector3(0, size.y, size.z),
		pos + size
	]

static func _get_aabb_edges() -> Array:
	return [
		[0,1],[0,2],[0,3],
		[7,6],[7,5],[7,4],
		[1,4],[1,5],
		[2,4],[2,6],
		[3,5],[3,6]
	]
