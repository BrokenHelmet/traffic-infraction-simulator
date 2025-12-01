extends CharacterBody3D

# =============================================================================
# PEDESTRIAN CONTROLLER
# =============================================================================
# Simplified pedestrian movement system with walk signal integration:
# - Simple walking speed (no acceleration/braking)
# - Walk signal detection for crosswalk behavior
# - Instant stop/start movement
# - Pedestrian-specific collision detection
# - Scoring system integration for "pedestrian" agent type
# =============================================================================

# DEBUG SETTINGS - Set to false by default to reduce console clutter
@export_group("Debug Settings")
@export var debug_movement: bool = false
@export var debug_walk_signals: bool = false
@export var debug_collision_detection: bool = false
@export var debug_configuration: bool = false
@export var debug_ai: bool = false
@export var debug_crossing: bool = false
@export var debug_exit: bool = false

# STATE AND INTENT
enum State { IDLE, WANDER, CROSSING, AT_POI }
enum Intent { IDLE, WANDER, CROSSING, AT_POI }
var state: State = State.IDLE
var intent: Intent = Intent.WANDER

# CORE PEDESTRIAN PROPERTIES
@export_group("Pedestrian Properties")
@export var walking_speed: float = 1.5  # Pedestrian walking speed (slower than vehicles)
@export var path: PathFollow3D  # Path3D to follow (crosswalk paths)
@export var detection_range: float = 1.0  # Range for detecting walk signals and obstacles
@export var side: String = "A"  # "A" or "B" based on nearest NavigationLink3D endpoint
var regions_by_label: Dictionary = {}

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@export var destination_position: Vector3

# AI TUNING
@export_group("AI")
@export var intent_recheck_min_s: float = 2.0
@export var intent_recheck_max_s: float = 5.0
var _ai_time_left: float = 0.0

# IDLE SETTINGS
@export_group("Idle")
@export var idle_min_s: float = 0.8
@export var idle_max_s: float = 2.2
var _idle_time_left: float = 0.0

# EXIT SETTINGS
@export_group("Exit")
@export var enable_exit_cycle: bool = true
@export var exit_probability: float = 0.15
@export var exit_margin: float = 2.5
var _exiting: bool = false
var _exit_outward: Vector3 = Vector3.ZERO

# ANIMATION PROPERTIES
@onready var animation_player: AnimationPlayer = $"character-b/AnimationPlayer"

# PEDESTRIAN TYPE SYSTEM
var pedestrian_type: String = "normal"  # normal, elderly, child (affects walking speed)
var original_scale: Vector3  # Scale before any modifications

# MOVEMENT CONTROL
var current_speed: float = 0.0  # Current walking speed
var can_cross: bool = true  # Whether pedestrian can cross based on walk signals

# OBSTACLE DETECTION FLAGS
var is_blocked_by_obstacle: bool = false  # Blocked by other pedestrians or obstacles
var waiting_for_walk_signal: bool = false  # Waiting for walk signal to cross

# COLLISION DETECTION COMPONENTS
var forward_raycast: RayCast3D  # Detection for obstacles ahead
var collision_shape: CollisionShape3D  # Pedestrian collision shape

# SCORING SYSTEM INTEGRATION
var agent_id: String = ""  # Unique identifier for scoring system
var spawn_time: float = 0.0  # When this pedestrian was spawned
var score_manager: Node = null  # Reference to ScoreManager
var last_movement_state: bool = true  # Track if pedestrian was moving last frame

# COMPLETION SIGNAL
signal journey_completed(pedestrian: CharacterBody3D, agent_id: String)

# PATH FOLLOWING
var current_progress: float = 0.0  # Current position on path

func _ready():
	animation_player.current_animation = "idle"
	# Initialize AI timer and randomize initial intent
	_ai_time_left = randf_range(intent_recheck_min_s, intent_recheck_max_s)
	intent = Intent.WANDER
	state = State.IDLE
# Set pedestrian-specific properties
	detection_range = 1.0  # Closer detection range than vehicles
	# Detect side via regions/links if available
	assign_side_by_regions_and_links()
	# Prime first target
	set_new_target()

# =============================================================================
# DEBUG HELPER FUNCTIONS
# =============================================================================

func debug_print(message: String, debug_flag: bool):
	"""Print debug message only if the corresponding debug flag is enabled"""
	if debug_flag:
		print("[Pedestrian-", name, "] ", message)

func debug_move(message: String):
	"""Print movement-related debug message"""
	debug_print(message, debug_movement)

func debug_walk_signal(message: String):
	"""Print walk signal-related debug message"""
	debug_print(message, debug_walk_signals)

func debug_collision(message: String):
	"""Print collision-related debug message"""
	debug_print(message, debug_collision_detection)

func debug_config(message: String):
	"""Print configuration-related debug message"""
	debug_print(message, debug_configuration)

func debug_cross(message: String):
	"""Print crossing-related debug message"""
	debug_print(message, debug_crossing)

func debug_exit_log(message: String):
	"""Print exit/despawn-related debug message"""
	debug_print(message, debug_exit)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		set_new_position()
	
func set_new_position():
	var random_position := Vector3.ZERO
	random_position.x = randf_range(-10.0, 10.0)
	random_position.z = randf_range(-35.0, 10.0)
	
	navigation_agent_3d.target_position = random_position
		
func _physics_process(delta):
	# Periodic AI update and intent reevaluation
	_update_ai(delta)
	
	if path:
		# Crossing via explicit PathFollow3D
		state = State.CROSSING
		# Check for obstacles and walk signals
		_update_collision_detection()
		# Update walking behavior based on signals and obstacles
		_update_walking_movement(delta)
		# Update scoring system with movement status
		_update_movement_scoring(delta)
		# Apply movement if allowed
		if current_speed > 0.01:  # Only move if we have meaningful speed
			current_progress += current_speed * delta
			path.progress = current_progress
			global_position = path.global_position
			# Check if pedestrian has completed journey
			if path.progress_ratio >= 0.99:
				_handle_journey_completion()
				return  # Stop processing once completed
			# Simple look-at for pedestrian direction
			var look_direction = path.transform.basis.z.normalized()
			if look_direction.length() > 0:
				var target_position = path.global_position + look_direction
				look_at(target_position, Vector3.UP)
	else:
			_process_pathfinding_movement(delta)
# =============================================================================
# PEDESTRIAN MOVEMENT SYSTEM
# =============================================================================

func _process_pathfinding_movement(delta: float):
	# Respect state for navigation-agent based control
	if state == State.IDLE:
		_idle_time_left -= delta
		velocity = Vector3.ZERO
		if animation_player.current_animation != "idle":
			animation_player.current_animation = "idle"
		if _idle_time_left > 0.0:
			return
		# Idle finished → pick next target from current intent
		set_new_target()
		return

	# If finished, handle crossing completion and re-target
	if navigation_agent_3d.is_navigation_finished():
		# Handle pending exit first
		if _exiting:
			debug_exit_log("Despawn at edge; walking off")
			global_position += _exit_outward * exit_margin
			queue_free()
			return
		if state == State.CROSSING:
			var prev_side: String = side
			_update_side_from_regions()
			debug_cross("Crossed road: " + prev_side + " -> " + side)
			intent = Intent.WANDER
			get_tree().call_group("pedestrian_manager", "on_pedestrian_crossed", self)
			_enter_idle()
			return
		elif state == State.WANDER:
			_enter_idle()
			return

	# Ensure we have a target when wandering/crossing without a PathFollow3D
	if (state == State.WANDER or state == State.CROSSING) and (navigation_agent_3d.target_position == Vector3.ZERO):
		set_new_target()

	if not navigation_agent_3d.is_navigation_finished() and navigation_agent_3d.target_position:
		destination_position = navigation_agent_3d.get_next_path_position()
		var local_destination = destination_position - global_position
		var direction = local_destination.normalized()
		velocity = direction * walking_speed
		var current_forward_angle = -global_transform.basis.z.normalized()
		var look_at_angle = rad_to_deg(current_forward_angle.angle_to(direction))
		if look_at_angle > 1.0 and global_position != destination_position:
			look_at(destination_position)
		else:
			move_and_slide()
		if animation_player.current_animation != "walk":
			animation_player.current_animation = "walk"
	elif navigation_agent_3d.navigation_finished and animation_player.current_animation != "idle":
		animation_player.current_animation = "idle"
	
func _update_walking_movement(_delta: float):
	"""Update pedestrian movement - simple walking with instant stop/start"""
	
	# Check if pedestrian can move
	if is_blocked_by_obstacle or waiting_for_walk_signal:
		# Instant stop when blocked or waiting for walk signal
		current_speed = 0.0
		debug_move("Pedestrian stopped - blocked: " + str(is_blocked_by_obstacle) + ", waiting for signal: " + str(waiting_for_walk_signal))
	else:
		# Instant start at walking speed when clear
		current_speed = walking_speed
		debug_move("Pedestrian walking at speed: " + str(current_speed))

func can_move() -> bool:
	"""Check if pedestrian can move"""
	return not is_blocked_by_obstacle and not waiting_for_walk_signal

# =============================================================================
# COLLISION DETECTION SYSTEM
# =============================================================================

func _setup_collision_detection():
	"""Initialize collision detection components"""
	# Find collision shape (should be a direct child)
	collision_shape = get_node_or_null("CollisionShape3D")
	if not collision_shape:
		debug_config("Warning: No CollisionShape3D found for pedestrian")
		return
	
	# Find forward raycast (should be child of collision shape)
	forward_raycast = collision_shape.get_node_or_null("RayCast3D")
	if not forward_raycast:
		debug_config("Warning: No RayCast3D found for pedestrian collision detection")
		return
	
	# Configure raycast for pedestrian detection
	forward_raycast.enabled = true
	# Set collision mask to detect:
	# Bit 0 (Layer 1): Vehicle = 1
	# Bit 2 (Layer 3): Pedestrian = 4  
	# Bit 4 (Layer 5): Walk Signal = 16
	forward_raycast.collision_mask = 1 + 4 + 16  # Layers 1, 3, and 5
	forward_raycast.collide_with_areas = true  # Detect walk signal areas
	forward_raycast.collide_with_bodies = true
	# Shorter detection range for pedestrians
	forward_raycast.target_position = Vector3(0, 0, detection_range)
	debug_config("Pedestrian collision detection initialized with range: " + str(detection_range))

func _update_collision_detection():
	"""Update collision detection for pedestrians"""
	
	# Safety check: ensure raycast is available and enabled
	if not forward_raycast or not forward_raycast.is_enabled():
		is_blocked_by_obstacle = false
		waiting_for_walk_signal = false
		return
	
	# Reset blocking states
	is_blocked_by_obstacle = false
	waiting_for_walk_signal = false
	
	# Check for collisions
	if forward_raycast.is_colliding():
		var collider = forward_raycast.get_collider()
		var collision_point = forward_raycast.get_collision_point()
		var distance_to_collision = global_position.distance_to(collision_point)
		
		# Only react to close obstacles
		if distance_to_collision <= detection_range:
			# TYPE 1: PEDESTRIAN DETECTION
			if collider and collider != self and collider.has_method("get_pedestrian_type"):
				is_blocked_by_obstacle = true
				debug_collision("Blocked by another pedestrian")
			
			# TYPE 2: VEHICLE DETECTION (pedestrians wait for vehicles)
			elif collider and collider != self and collider.has_method("get_vehicle_type_config"):
				is_blocked_by_obstacle = true
				debug_collision("Blocked by vehicle - waiting")
			
			# TYPE 3: WALK SIGNAL DETECTION
			elif collider is Area3D and collider.name.contains("WalkSignal"):
				_check_walk_signal(collider)
			
			# TYPE 4: STATIC OBSTACLE DETECTION
			else:
				is_blocked_by_obstacle = true
				debug_collision("Blocked by static obstacle")

func _check_walk_signal(walk_signal_area: Area3D):
	"""Check walk signal status for crossing permission"""
	var traffic_light = walk_signal_area.get_parent()
	
	if traffic_light and traffic_light.has_method("can_pedestrian_cross"):
		# Use modern traffic light API if available
		if traffic_light.can_pedestrian_cross():
			waiting_for_walk_signal = false
			can_cross = true
			debug_walk_signal("🚶 Walk signal active - can cross")
		else:
			waiting_for_walk_signal = true
			can_cross = false
			debug_walk_signal("🛑 Don't walk signal - waiting to cross")
	elif traffic_light and traffic_light.has_method("is_red"):
		# Fallback: pedestrians can cross when traffic light is red (vehicles stopped)
		if traffic_light.is_red:
			waiting_for_walk_signal = false
			can_cross = true
			debug_walk_signal("🚶 Traffic light red - can cross (fallback)")
		else:
			waiting_for_walk_signal = true
			can_cross = false
			debug_walk_signal("🛑 Traffic light not red - waiting (fallback)")
	else:
		# No signal detected or unknown signal type
		waiting_for_walk_signal = false
		can_cross = true
		debug_walk_signal("No walk signal detected - proceeding")

# =============================================================================
# PEDESTRIAN TYPE CONFIGURATION
# =============================================================================

func set_pedestrian_type(type: String):
	"""Set pedestrian type which affects walking speed"""
	pedestrian_type = type
	
	match type:
		"elderly":
			walking_speed = 1.0  # Slower walking speed
			debug_config("Pedestrian configured as elderly - speed: " + str(walking_speed))
		"child":
			walking_speed = 1.2  # Slightly faster than elderly, slower than normal
			original_scale = scale
			scale = original_scale * 0.7  # Smaller size
			debug_config("Pedestrian configured as child - speed: " + str(walking_speed) + ", scale: 0.7")
		"normal":
			walking_speed = 1.5  # Normal walking speed
			debug_config("Pedestrian configured as normal - speed: " + str(walking_speed))
		_:
			walking_speed = 1.5  # Default to normal
			debug_config("Unknown pedestrian type, using normal - speed: " + str(walking_speed))

func get_pedestrian_type() -> String:
	"""Get the current pedestrian type"""
	return pedestrian_type

func is_child() -> bool:
	"""Check if this is a child pedestrian"""
	return pedestrian_type == "child"

func is_elderly() -> bool:
	"""Check if this is an elderly pedestrian"""
	return pedestrian_type == "elderly"

# =============================================================================
# SCORING SYSTEM INTEGRATION
# =============================================================================

func _initialize_scoring():
	"""Initialize scoring system integration"""
	# Generate unique agent ID
	agent_id = "pedestrian_" + str(get_instance_id())
	spawn_time = Time.get_unix_time_from_system()
	
	# Find ScoreManager in the scene
	score_manager = get_node_or_null("/root/Main/ScoreManager")
	if not score_manager:
		# Try alternative paths
		score_manager = get_tree().get_first_node_in_group("score_manager")
	
	if score_manager and score_manager.has_method("register_agent"):
		score_manager.register_agent(agent_id, "pedestrian", spawn_time)
		debug_config("Pedestrian registered with ScoreManager: " + agent_id)
	else:
		debug_config("WARNING: ScoreManager not found - scoring disabled")

func _update_movement_scoring(delta: float):
	"""Update scoring system with movement status"""
	if not score_manager or not score_manager.has_method("set_agent_waiting"):
		return
	
	# Determine current movement state
	var is_currently_moving = can_move() and current_speed > 0.01
	
	# Only update scoring if movement state changed
	if is_currently_moving != last_movement_state:
		score_manager.set_agent_waiting(agent_id, not is_currently_moving)
		last_movement_state = is_currently_moving

func _handle_journey_completion():
	"""Handle pedestrian journey completion - emit signal and notify scoring system"""
	# Emit signal for any systems that need to know about completion
	journey_completed.emit(self, agent_id)
	
	# Notify scoring system directly
	if score_manager and score_manager.has_method("complete_agent"):
		score_manager.complete_agent(agent_id)
		debug_config("Pedestrian journey completed - scored: " + agent_id)

func get_scoring_info() -> Dictionary:
	"""Get current scoring information for this pedestrian"""
	if score_manager and score_manager.has_method("calculate_agent_points"):
		return {
			"agent_id": agent_id,
			"current_points": score_manager.calculate_agent_points(agent_id),
			"spawn_time": spawn_time,
			"is_moving": can_move() and current_speed > 0.01,
			"pedestrian_type": pedestrian_type
		}
	else:
		return {
			"agent_id": agent_id,
			"current_points": 0,
			"spawn_time": spawn_time,
			"is_moving": false,
			"pedestrian_type": pedestrian_type
		}

# =============================================================================
# LEGACY COMPATIBILITY METHODS
# =============================================================================

func complete_journey():
	"""Legacy method for external completion calls"""
	_handle_journey_completion()

func get_blocking_status() -> Dictionary:
	"""Get detailed information about what's blocking this pedestrian"""
	return {
		"blocked_by_obstacle": is_blocked_by_obstacle,
		"waiting_for_walk_signal": waiting_for_walk_signal,
		"can_move": can_move(),
		"can_cross": can_cross,
		"current_speed": current_speed,
		"pedestrian_type": pedestrian_type
	}

# =============================================================================
# AI HELPERS
# =============================================================================

func _update_ai(delta: float) -> void:
	_ai_time_left -= delta
	if _ai_time_left <= 0.0:
		_ai_time_left = randf_range(intent_recheck_min_s, intent_recheck_max_s)
		_reevaluate_intent()

func _reevaluate_intent() -> void:
	# If currently on a crossing path, keep crossing
	if path:
		intent = Intent.CROSSING
		state = State.CROSSING
		return
	# Simple heuristic: occasionally switch between WANDER and CROSSING
	var r = randf()
	if state == State.WANDER and r < 0.25:
		intent = Intent.CROSSING
	elif state in [State.IDLE, State.AT_POI] and r < 0.6:
		intent = Intent.WANDER
	elif state == State.CROSSING and r < 0.2:
		intent = Intent.WANDER
	else:
		intent = Intent.WANDER if state == State.WANDER else intent
	_set_state_from_intent()
	if debug_ai:
		print("[Pedestrian-", name, "] intent→state:", str(intent), "→", str(state))

func _set_state_from_intent() -> void:
	match intent:
		Intent.IDLE:
			state = State.IDLE
		Intent.WANDER:
			state = State.WANDER
		Intent.CROSSING:
			state = State.CROSSING
		Intent.AT_POI:
			state = State.AT_POI

# Target selection per requested logic
func set_new_target() -> void:
	if intent == Intent.CROSSING:
		# Prefer using NavigationLink3D endpoints if present
		var link_target := _pick_crossing_target()
		if link_target != Vector3.ZERO:
			navigation_agent_3d.target_position = link_target
			state = State.CROSSING
			return
		# Fallback to side-point system if links unavailable
		var target = _pick_opposite_side_destination()
		if target != Vector3.ZERO:
			navigation_agent_3d.target_position = target
			state = State.CROSSING
			return
	# Optionally plan an exit on wander
	if enable_exit_cycle and randf() < exit_probability:
		if _plan_exit():
			return
	# Default WANDER target
	var tgt = _pick_local_wander_target()
	navigation_agent_3d.target_position = tgt
	state = State.WANDER

func _pick_opposite_side_destination() -> Vector3:
	var target_side := ("B" if side == "A" else "A")
	return _pick_side_target(target_side)

func _pick_side_target(side_label: String) -> Vector3:
	var base := get_node_or_null("/root/NavigationPoints/Side" + side_label)
	if base and base.get_child_count() > 0:
		var kids := base.get_children()
		var chosen: Node3D = kids[randi() % kids.size()] as Node3D
		if chosen:
			return chosen.global_transform.origin
	return Vector3.ZERO

func _get_side_region() -> NavigationRegion3D:
	if not regions_by_label.is_empty() and regions_by_label.has(side):
		return regions_by_label[side]
	var regions: Array[NavigationRegion3D] = _get_nav_regions()
	if regions.is_empty():
		return null
	return _closest_region_to_point(global_position, regions)

func _pick_local_wander_target() -> Vector3:
	var radius: float = 6.0
	var attempts: int = 8
	var region: NavigationRegion3D = _get_side_region()
	var nav_map: RID = RID()
	if region:
		nav_map = NavigationServer3D.region_get_map(region.get_rid())
	var aabb: AABB = AABB()
	if region:
		aabb = NavUtils.get_nav_bounds(region)
	for i in range(attempts):
		var offset: Vector3 = Vector3(randf_range(-radius, radius), 0.0, randf_range(-radius, radius))
		var candidate: Vector3 = global_position + offset
		var on_nav: Vector3 = candidate
		if nav_map.is_valid():
			on_nav = NavigationServer3D.map_get_closest_point(nav_map, candidate)
		var in_bounds: bool = (aabb.size != Vector3.ZERO and _aabb_contains_point(aabb, on_nav)) or aabb == AABB()
		if not in_bounds:
			continue
		var ok: bool = true
		if nav_map.is_valid():
			var path: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, global_position, on_nav, true)
			ok = path.size() >= 2
		if ok:
			return on_nav
		radius *= 1.15
	# Fallbacks
	if nav_map.is_valid():
		return NavigationServer3D.map_get_closest_point(nav_map, global_position)
	return global_position

func _find_nearest_link() -> NavigationLink3D:
	var nearest: NavigationLink3D = null
	var best_d := INF
	var root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	if root == null:
		return null
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is NavigationLink3D:
			var link := n as NavigationLink3D
			var a := link.to_global(link.start_position)
			var b := link.to_global(link.end_position)
			var d: float = min(global_position.distance_to(a), global_position.distance_to(b))
			if d < best_d:
				best_d = d
				nearest = link
		for c in (n as Node).get_children():
			stack.append(c)
	return nearest

func _pick_crossing_target() -> Vector3:
	# Aim for the far endpoint of the nearest NavigationLink3D
	var link := _find_nearest_link()
	if link == null:
		return _pick_local_wander_target()
	var a := link.to_global(link.start_position)
	var b := link.to_global(link.end_position)
	var near_is_a := global_position.distance_to(a) <= global_position.distance_to(b)
	return b if near_is_a else a

func assign_side_by_nearest_link() -> void:
	var link := _find_nearest_link()
	if link == null:
		return
	var a := link.to_global(link.start_position)
	var b := link.to_global(link.end_position)
	side = "A" if global_position.distance_to(a) <= global_position.distance_to(b) else "B"

func assign_side_by_regions_and_links() -> void:
	_build_regions_by_label()
	_update_side_from_regions()
	if side == "A" or side == "B":
		return
	# If label not resolved, fallback to nearest link heuristic
	assign_side_by_nearest_link()

func _build_regions_by_label() -> void:
	if not regions_by_label.is_empty():
		return
	var regions := _get_nav_regions()
	# Heuristic: use region metadata or name to fill labels
	for r in regions:
		var label := ""
		if r.has_meta("side"):
			label = str(r.get_meta("side"))
		elif r.has_meta("label"):
			label = str(r.get_meta("label"))
		else:
			var nm := r.name
			for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
				if ("Side" + c) in nm or nm.ends_with("_" + c):
					label = c
					break
		if label != "" and not regions_by_label.has(label):
			regions_by_label[label] = r
	# If still fewer than 2 and a link exists, assign A/B by nearest endpoints
	if regions_by_label.size() < 2:
		var link := _find_nearest_link()
		if link:
			var a := link.to_global(link.start_position)
			var b := link.to_global(link.end_position)
			var regA := _closest_region_to_point(a, regions)
			var regB := _closest_region_to_point(b, regions)
			if regA and regB and regA != regB:
				if not regions_by_label.has("A"):
					regions_by_label["A"] = regA
				if not regions_by_label.has("B"):
					regions_by_label["B"] = regB

func _update_side_from_regions() -> void:
	if regions_by_label.is_empty():
		_build_regions_by_label()
	if regions_by_label.is_empty():
		return
	# Containment check first
	for k in regions_by_label.keys():
		var r: NavigationRegion3D = regions_by_label[k]
		if _aabb_contains_point(NavUtils.get_nav_bounds(r), global_position):
			side = k
			return
	# Fallback: nearest region by AABB distance
	var best_k := side
	var best_d := INF
	for k in regions_by_label.keys():
		var r: NavigationRegion3D = regions_by_label[k]
		var d := _aabb_distance_to_point(NavUtils.get_nav_bounds(r), global_position)
		if d < best_d:
			best_d = d
			best_k = k
	side = best_k

func _get_nav_regions() -> Array[NavigationRegion3D]:
	var list: Array[NavigationRegion3D] = []
	var root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	if root == null:
		return list
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is NavigationRegion3D:
			list.append(n as NavigationRegion3D)
		for c in n.get_children():
			stack.append(c)
	return list

func _closest_region_to_point(p: Vector3, regions: Array[NavigationRegion3D]) -> NavigationRegion3D:
	var best: NavigationRegion3D = null
	var best_d := INF
	for r in regions:
		var d := _aabb_distance_to_point(NavUtils.get_nav_bounds(r), p)
		if d < best_d:
			best_d = d
			best = r
	return best

func _aabb_contains_point(aabb: AABB, p: Vector3) -> bool:
	return p.x >= aabb.position.x and p.x <= aabb.position.x + aabb.size.x and \
		   p.y >= aabb.position.y - 1.0 and p.y <= aabb.position.y + aabb.size.y + 1.0 and \
		   p.z >= aabb.position.z and p.z <= aabb.position.z + aabb.size.z

func _aabb_distance_to_point(aabb: AABB, p: Vector3) -> float:
	var cx: float = clamp(p.x, aabb.position.x, aabb.position.x + aabb.size.x)
	var cy: float = clamp(p.y, aabb.position.y, aabb.position.y + aabb.size.y)
	var cz: float = clamp(p.z, aabb.position.z, aabb.position.z + aabb.size.z)
	return Vector3(cx, cy, cz).distance_to(p)

func _plan_exit() -> bool:
	var region: NavigationRegion3D = _get_side_region()
	if region == null:
		return false
	var edges: Array = NavUtils.get_navmesh_edges(region)
	if edges.is_empty():
		return false
	var edge: Array = edges[randi() % edges.size()]
	var a: Vector3 = edge[0]
	var b: Vector3 = edge[1]
	var edge_dir: Vector3 = (b - a).normalized()
	var outward: Vector3 = Vector3(-edge_dir.z, 0.0, edge_dir.x)
	var t: float = randf()
	var point_on_edge: Vector3 = a.lerp(b, t)
	var target_inside: Vector3 = point_on_edge - outward * 0.75
	navigation_agent_3d.target_position = target_inside
	_exiting = true
	_exit_outward = outward
	state = State.WANDER
	debug_exit_log("Exit planned toward edge")
	return true

# Enter IDLE state for a randomized or specified duration
func _enter_idle(duration: float = -1.0) -> void:
	state = State.IDLE
	var lo: float = max(0.0, min(idle_min_s, idle_max_s))
	var hi: float = max(lo, max(idle_min_s, idle_max_s))
	_idle_time_left = (randf_range(lo, hi) if duration < 0.0 else max(0.0, duration))
	current_speed = 0.0
	if animation_player.current_animation != "idle":
		animation_player.current_animation = "idle"
	if debug_ai:
		print("[Pedestrian-", name, "] idle for ", str(snapped(_idle_time_left, 0.01)), "s")
