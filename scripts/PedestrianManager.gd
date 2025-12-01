extends Node

# PedestrianManager: minimal pedestrian spawner from NavigationRegion3D edges.
# - No NodePath/Path3D usage
# - Uses region.get_bounds() (with safe fallback) to aim pedestrians inward
# - Spawns along navmesh boundary edges
# - Randomized spawn interval between min/max
# - Caches active NPCs in `population`
# - Kept concise per request

@export_group("Setup")
@export var pedestrian_scene: PackedScene = preload("res://scenes/pedestrians/PedestrianBase.tscn")

@export_group("Spawning")
@export var auto_start: bool = true
@export var spawn_interval_min: float = 1.5
@export var spawn_interval_max: float = 3.5
@export var max_pedestrians: int = 20

@export_group("Spawn Points")
@export var spawn_points: Array[NodePath] = []

@export_group("AI Spawning")
@export var crossing_probability: float = 0.5
@export var target_crossings: int = 0

@export_group("Scene properties")
@export var avoid_areas_parent_node: Node3D
var forbidden_zone: AABB

@export_group("Debug")
@export var debug_spawning: bool = false
@export var debug_errors: bool = true

# Optional cache (kept for potential future use)
var _spawn_points: Array[Vector3] = []

# Boundary edge segments: dictionaries with {region, a, b, center}
var _edge_segments: Array = []

# Active NPCs
var population: Array[Node3D] = []
# Optional alias to mirror external patterns
var pedestrians: Array[Node3D] = population

# Internals for crossing intent budgeting
var _crossings_assigned: int = 0
var _crossings_done: int = 0

var _timer: Timer
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("pedestrian_manager")
	if avoid_areas_parent_node:
		forbidden_zone = ZoneUtils.get_aabb_from_node(avoid_areas_parent_node, 5.0)
		var aabb := ZoneUtils.get_aabb_from_node(avoid_areas_parent_node, 1.0)
		var debug_box := ZoneUtils.create_debug_zone(aabb, Color(0,1,0,0.5)) #ZoneUtils.make_zone_mesh(aabb, Color(0.8, 0.2, 0.2))
		debug_box.name = "Forbidden zone"
		add_child(debug_box)  # for example, add to the current node

		print("Generated an avoid area!")

	
	_rng.randomize()
	# Initialize population cache
	population.clear()
	_crossings_assigned = 0
	_crossings_done = 0
	_debug("Population cache initialized")
	# Setup timer
	_timer = Timer.new()
	#_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_spawn_tick)
	if auto_start:
		_timer.wait_time = _next_interval()
		_timer.start()
		_debug("Spawner started; first in " + str(_timer.wait_time))

func _next_interval() -> float:
	var lo: float = max(0.05, min(spawn_interval_min, spawn_interval_max))
	var hi: float = max(lo, max(spawn_interval_min, spawn_interval_max))
	return _rng.randf_range(lo, hi)

func start() -> void:
	_timer.wait_time = _next_interval()
	_timer.start()
	_debug("Spawner started; next in " + str(_timer.wait_time))

func stop() -> void:
	if _timer:
		_timer.stop()
		_debug("Spawner stopped")

func spawn_one() -> Node3D:
	if pedestrian_scene == null:
		_debug_err("pedestrian_scene is not set")
		return null
	if max_pedestrians > 0 and population.size() >= max_pedestrians:
		_debug("Max pedestrians reached: " + str(population.size()))
		return null

	# Instantiate pedestrian
	var inst := pedestrian_scene.instantiate()
	if not (inst is Node3D):
		_debug_err("Spawned scene root must be Node3D")
		return null
	
	# Add to scene tree
	add_child(inst)
	var ped: Node3D = inst
	
	# Prefer explicit spawn points if configured; fallback to navmesh edge
	var nodes := _get_spawn_nodes()
	if not nodes.is_empty():
		var spawn_node: Node3D = nodes[randi() % nodes.size()]
		ped.global_position = spawn_node.global_position
# Side from spawn metadata, else infer
		if spawn_node.has_meta("side"):
			ped.side = str(spawn_node.get_meta("side"))
		elif ped.has_method("assign_side_by_regions_and_links"):
			ped.assign_side_by_regions_and_links()
		elif ped.has_method("assign_side_by_nearest_link"):
			ped.assign_side_by_nearest_link()
		# Intent sampling with target cap
		var p_cross := _effective_crossing_probability()
		var do_cross := randf() < p_cross
		if ped.has_method("assign_side_by_nearest_link"):
			# Safe proxy that this is our Pedestrian script with enums
			ped.intent = ped.Intent.CROSSING if do_cross else ped.Intent.WANDER
			ped.state = ped.State.CROSSING if do_cross else ped.State.WANDER
		else:
			# Fallback for unknown actors: 2=CROSSING, 1=WANDER
			ped.set("intent", 2 if do_cross else 1)
		if do_cross and target_crossings > 0:
			_crossings_assigned += 1
		_debug("Spawned at spawn_point '" + spawn_node.name + "' side=" + (ped.side if ped.get("side") != null else "?") + 
			" intent=" + ("CROSSING" if do_cross else "WANDER") + 
			" p=" + str(snapped(p_cross, 0.01)) + " assigned=" + str(_crossings_assigned) + "/" + str(target_crossings))
	else:
		ped.global_position = NavUtils.get_spawn_along_edge(get_available_navigation_region())
		if ped.has_method("assign_side_by_regions_and_links"):
			ped.assign_side_by_regions_and_links()
		elif ped.has_method("assign_side_by_nearest_link"):
			ped.assign_side_by_nearest_link()
		_debug("Spawned at edge; side=" + (ped.side if ped.get("side") != null else "?"))
	
	# Add to population cache
	population.append(ped)
	
	# Clean up cache when pedestrian is removed
	inst.tree_exited.connect(func(): 
		population.erase(ped)
		_debug("Pedestrian removed from cache. Population: " + str(population.size()))
	)
	
	_debug("Spawned pedestrian. Population: " + str(population.size()))
	return ped

# Helpers
func _get_spawn_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for p in spawn_points:
		var n = get_node_or_null(p)
		if n and n is Node3D:
			nodes.append(n)
	return nodes

func _effective_crossing_probability() -> float:
	if target_crossings > 0 and (_crossings_done >= target_crossings or _crossings_assigned >= target_crossings):
		return 0.0
	return clamp(crossing_probability, 0.0, 1.0)

# Callback from pedestrians when a crossing completes
func on_pedestrian_crossed(_ped: Node) -> void:
	if target_crossings <= 0:
		return
	_crossings_done += 1
	_debug("Crossing completed: " + str(_crossings_done) + "/" + str(target_crossings))

func _on_spawn_tick() -> void:
	if max_pedestrians == 0 or population.size() < max_pedestrians:
		spawn_one()
	if _timer:
		_timer.wait_time = _next_interval()
		_timer.start()

func _debug(msg: String) -> void:
	if debug_spawning:
		print("[PedestrianManager-", name, "] ", msg)

func get_available_navigation_region() -> NavigationRegion3D:
	"""Find and return one available NavigationRegion3D from the active scene"""
	var regions: Array[NavigationRegion3D] = get_all_navigation_regions()
	if regions.is_empty():
		_debug_err("No NavigationRegion3D found in active scene")
		return null
	
	# Return the first valid region with a navigation mesh
	for region in regions:
		if region.navigation_mesh != null:
			_debug("Found navigation region: " + region.name)
			return region
	
	_debug_err("No NavigationRegion3D with valid navigation mesh found")
	return null

func get_all_navigation_regions() -> Array[NavigationRegion3D]:
	"""Get all NavigationRegion3D nodes from the active scene"""
	var regions: Array[NavigationRegion3D] = []
	var root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	
	if root == null:
		_debug_err("No scene tree root available")
		return regions
	
	# Recursively search for NavigationRegion3D nodes
	_collect_navigation_regions(root, regions)
	_debug("Found " + str(regions.size()) + " navigation region(s)")
	return regions

func _collect_navigation_regions(node: Node, regions: Array[NavigationRegion3D]) -> void:
	"""Recursively collect NavigationRegion3D nodes"""
	if node is NavigationRegion3D:
		regions.append(node as NavigationRegion3D)
	
	for child in node.get_children():
		_collect_navigation_regions(child, regions)

func _debug_err(msg: String) -> void:
	if debug_errors:
		print("[PedestrianManager-", name, "] ERROR: ", msg)
