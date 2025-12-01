# NavUtils.gd
# Utility functions for working with NavigationRegion3D
# Drop in res://scripts/NavUtils.gd

extends Node
class_name NavUtils

# Return the AABB (already transformed to global) of a NavigationRegion3D
static func get_nav_bounds(nav_region: NavigationRegion3D) -> AABB:
	var bounds: AABB = nav_region.get_bounds() # NavigationRegion3D provides this method
	return bounds

# Returns a random spawn position slightly outside the navmesh bounding box
static func get_spawn_outside_bounds(nav_region: NavigationRegion3D, margin: float = 5.0) -> Vector3:
	var bounds: AABB = get_nav_bounds(nav_region)
	if bounds.size == Vector3.ZERO:
		return nav_region.global_transform.origin

	var pos: Vector3 = Vector3.ZERO
	var side: int = randi() % 4

	match side:
		0: # +X
			pos = Vector3(bounds.position.x + bounds.size.x + margin,
						  randf_range(bounds.position.y, bounds.position.y + bounds.size.y),
						  randf_range(bounds.position.z, bounds.position.z + bounds.size.z))
		1: # -X
			pos = Vector3(bounds.position.x - margin,
						  randf_range(bounds.position.y, bounds.position.y + bounds.size.y),
						  randf_range(bounds.position.z, bounds.position.z + bounds.size.z))
		2: # +Z
			pos = Vector3(randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
						  randf_range(bounds.position.y, bounds.position.y + bounds.size.y),
						  bounds.position.z + bounds.size.z + margin)
		3: # -Z
			pos = Vector3(randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
						  randf_range(bounds.position.y, bounds.position.y + bounds.size.y),
						  bounds.position.z - margin)

	return pos


# Returns boundary edges as pairs of global Vector3 points
static func get_navmesh_edges(nav_region: NavigationRegion3D) -> Array:
	var nav_mesh: NavigationMesh = nav_region.navigation_mesh
	if nav_mesh == null:
		return []

	# vertices positions
	var vertices: PackedVector3Array = nav_mesh.get_vertices()
	var edge_map: Dictionary = {}

	# NOTE: use get_polygon(i) (returns IntArray / PackedInt32Array of indices)
	var poly_count: int = nav_mesh.get_polygon_count()
	for i in range(poly_count):
		var poly: PackedInt32Array = nav_mesh.get_polygon(i)
		var poly_size: int = poly.size()
		for j in range(poly_size):
			var a_idx: int = poly[j]
			var b_idx: int = poly[(j + 1) % poly_size]

			# canonicalize edge ordering so the same undirected edge maps to a single key
			var edge_key: Vector2i = Vector2i(a_idx, b_idx) if a_idx < b_idx else Vector2i(b_idx, a_idx)

			if edge_key in edge_map:
				edge_map[edge_key] = edge_map[edge_key] + 1
			else:
				edge_map[edge_key] = 1

	# boundary edges are those seen exactly once
	var edges: Array = []
	for edge_key in edge_map.keys():
		if edge_map[edge_key] == 1:
			var a_pos: Vector3 = vertices[edge_key.x]
			var b_pos: Vector3 = vertices[edge_key.y]
			edges.append([nav_region.to_global(a_pos), nav_region.to_global(b_pos)])

	return edges


# Returns a random spawn position along a navmesh boundary edge, offset outward (XZ-plane offset)
static func get_spawn_along_edge(nav_region: NavigationRegion3D, margin: float = 5.0) -> Vector3:
	var edges: Array = get_navmesh_edges(nav_region)
	if edges.is_empty():
		return get_spawn_outside_bounds(nav_region, margin)

	var edge: Array = edges[randi() % edges.size()]
	var a: Vector3 = edge[0]
	var b: Vector3 = edge[1]

	# random point on edge
	var t: float = randf()
	var point_on_edge: Vector3 = a.lerp(b, t)

	# outward in XZ-plane (rotate edge dir 90 degrees)
	var edge_dir: Vector3 = (b - a).normalized()
	var outward: Vector3 = Vector3(-edge_dir.z, 0.0, edge_dir.x)

	return point_on_edge + outward * margin
