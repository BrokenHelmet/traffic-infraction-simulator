extends CharacterBody3D

# =============================================================================
# IMMEDIATE RESPONSE VEHICLE CONTROLLER
# =============================================================================
# Restored to immediate detection and acceleration behavior:
# - No speed smoothing mechanics
# - Immediate stop when obstacle detected
# - Immediate acceleration when clear
# - Simple binary movement state (moving or stopped)
# =============================================================================

# DEBUG SETTINGS - Set to false by default to reduce console clutter
@export_group("Debug Settings")
@export var debug_collision_detection: bool = false
@export var debug_traffic_lights: bool = false
@export var debug_movement: bool = false
@export var debug_configuration: bool = false
@export var debug_raycast: bool = false

# CORE VEHICLE PROPERTIES (configured by VehicleTypeConfig)
@export_group("Vehicle Properties")
@export var speed: float = 4.0  # Legacy - use max_speed instead
@export var path: PathFollow3D  # Path3D to follow
@export var follow_distance: float = 2.5  # Minimum distance to maintain behind obstacles
@export var acceleration: float = 3.0  # Speed increase rate (units/sec²)
@export var braking_force: float = 5.0  # Speed decrease rate (units/sec²)

# VEHICLE TYPE SYSTEM
var vehicle_type_config: Resource  # VehicleTypeConfig resource

# DISTANCE-BASED SPEED CONTROL SYSTEM
var current_speed: float = 0.0  # Actual current speed
var max_speed: float = 4.0  # Maximum allowed speed
var cached_distance_to_obstacle: float = 99.0  # Distance to nearest obstacle

# OBSTACLE DETECTION FLAGS
var is_blocked_by_vehicle: bool = false  # True when vehicle/obstacle detected by raycast
var blocked_by_traffic_light: bool = false  # True when in red light sensor area

# INTERSECTION STATE - Updated by RedLightSensor signals
var is_in_intersection: bool = false  # True when vehicle is inside intersection area

# COLLISION DETECTION COMPONENTS
var forward_raycast: RayCast3D  # 15-unit forward detection
var collision_shape: CollisionShape3D  # Vehicle collision shape

# RAYCAST DEBUG TRACKING
var last_detected_object: Node = null  # Track last object hit by raycast
var last_detected_name: String = ""    # Track last object name for comparison

# SCORING SYSTEM INTEGRATION
var agent_id: String = ""  # Unique identifier for scoring system
var spawn_time: float = 0.0  # When this vehicle was spawned
var score_manager: Node = null  # Reference to ScoreManager
var last_movement_state: bool = true  # Track if vehicle was moving last frame

# COMPLETION SIGNAL
signal journey_completed(vehicle: CharacterBody3D, agent_id: String)

# IMMEDIATE DETECTION - NO PERFORMANCE OPTIMIZATION NEEDED

# PATH FOLLOWING
var current_progress: float = 0.0  # Current position on path

# LEGACY/UNUSED VARIABLES (remove if confirmed unused)
@export var stop_distance: float = 1.5  # ⚠️ UNUSED - remove if not needed elsewhere
@export var is_waiting: bool = false  # ⚠️ UNUSED - remove if not needed elsewhere
var braking_zone_distance: float = 6.0  # ⚠️ LEGACY - only used in adaptive frequency
var comfort_braking_force: float = 2.0  # ⚠️ LEGACY - not used in simplified system
var target_speed: float = 0.0  # ⚠️ LEGACY - calculated in real-time now
var cached_can_move: bool = true  # ⚠️ UNUSED - remove

func _ready():
	if path == null:
		debug_print("No path set for vehicle!", debug_configuration)
	
	# Get references to collision components
	_setup_collision_detection()
	
	# Initialize scoring system integration
	_initialize_scoring()

# =============================================================================
# DEBUG HELPER FUNCTIONS
# =============================================================================

func debug_print(message: String, debug_flag: bool):
	"""Print debug message only if the corresponding debug flag is enabled"""
	if debug_flag:
		print("[Vehicle-", name, "] ", message)

func debug_collision(message: String):
	"""Print collision-related debug message"""
	debug_print(message, debug_collision_detection)

func debug_traffic(message: String):
	"""Print traffic light-related debug message"""
	debug_print(message, debug_traffic_lights)

func debug_move(message: String):
	"""Print movement-related debug message"""
	debug_print(message, debug_movement)

func debug_config(message: String):
	"""Print configuration-related debug message"""
	debug_print(message, debug_configuration)

func debug_raycast_hit(message: String):
	"""Print raycast-related debug message"""
	debug_print(message, debug_raycast)

func _physics_process(delta):
	if path:
		# Check collision detection every frame for immediate response
		_update_collision_detection()
		
		# Apply immediate movement based on blocking status
		_update_immediate_movement(delta)
		
		# Update scoring system with movement status
		_update_movement_scoring(delta)
		
		# Apply movement if not blocked
		if current_speed > 0.01:  # Only move if we have meaningful speed
			current_progress += current_speed * delta
			path.progress = current_progress
			global_position = path.global_position
			
			# Check if vehicle has completed its journey
			if path.progress_ratio >= 0.99:
				_handle_journey_completion()
				return  # Stop processing once completed
			
			# Safe look_at calculation with null checks
			var look_direction = path.transform.basis.z.normalized()
			if look_direction.length() > 0:
				var target_position = path.global_position + look_direction
				look_at(target_position, Vector3.UP)

# =============================================================================
# IMMEDIATE RESPONSE MOVEMENT SYSTEM
# =============================================================================
# Simple binary movement: move at full speed or stop completely

func _update_immediate_movement(_delta: float):
	"""Apply immediate movement response - no smoothing"""
	# Simple binary logic: either blocked or not
	if is_blocked_by_vehicle or blocked_by_traffic_light:
		# Immediate stop when any obstacle detected
		current_speed = 0.0
	else:
		# Immediate acceleration to full speed when clear
		current_speed = max_speed

func can_move() -> bool:
	"""Simple check if vehicle can move"""
	return not is_blocked_by_vehicle and not blocked_by_traffic_light

# =============================================================================
# INTERSECTION STATE MANAGEMENT - Signal-based approach
# =============================================================================

func set_in_intersection(in_intersection: bool):
	"""Called by RedLightSensor when vehicle enters/exits intersection area"""
	if is_in_intersection != in_intersection:
		is_in_intersection = in_intersection
		var state = "ENTERED" if in_intersection else "EXITED"
		debug_traffic("🗺️ " + state + " intersection - clearance mode: " + str(in_intersection))
	

func _get_effective_braking_force() -> float:
	"""Return braking force (kept for compatibility)"""
	return braking_force

# =============================================================================
# COLLISION DETECTION SYSTEM
# =============================================================================

func _setup_collision_detection():
	"""Initialize collision detection components"""
	# Find collision shape (should be a direct child)
	collision_shape = get_node_or_null("CollisionShape3D")
	if not collision_shape:
		debug_config("Warning: No CollisionShape3D found for vehicle")
		return
	
	# Find forward raycast (should be child of collision shape)
	forward_raycast = get_node_or_null("RayCast3D")
	if not forward_raycast:
		debug_config("Warning: No RayCast3D found for vehicle collision detection")
		return
	else:
		debug_config("Warning: RayCast3D found for vehicle collision detection")
	
	# Configure raycast for vehicle detection with increased range for early detection
	forward_raycast.enabled = true
	# Set collision mask to detect:
	# Using scene's collision_mask (31) which includes all traffic entities:
	# Layer 1: Vehicle, Layer 2: Traffic_Light_Sensor, Layer 3: Pedestrian
	# Layer 4: Static_Obstacle, Layer 5: Emergency_Vehicle
	# forward_raycast.collision_mask = 1 + 2 + 8  # Commented out - using scene's mask (31)
	forward_raycast.collide_with_areas = true  # Detect traffic light areas
	forward_raycast.collide_with_bodies = true
	# Set raycast length for better detection at current vehicle speeds
	# Extended range to detect crosswalk boundaries before vehicles get too close
	#forward_raycast.target_position = Vector3(0, 0, 15.0)  # Extended for crosswalk clearance
	
	# Debug raycast configuration
	debug_config("Raycast config - Mask: " + str(forward_raycast.collision_mask) + ", Range: " + str(forward_raycast.target_position.z) + ", Areas: " + str(forward_raycast.collide_with_areas))
	debug_config("Raycast position: " + str(forward_raycast.global_position) + " -> " + str(forward_raycast.global_position + forward_raycast.target_position))
	
	# Debug: Scan for traffic light sensors in scene
	if debug_raycast:
		_scan_for_traffic_light_sensors()

func _update_collision_detection():
	"""IMMEDIATE OBSTACLE DETECTION: Stop immediately when obstacles within follow distance
	
	Simplified detection: Only blocks vehicle when obstacle is within follow_distance.
	No complex distance calculations - simple binary blocked/not blocked.
	"""
	
	# IMMEDIATE DETECTION LOGIC
	if forward_raycast.is_colliding():
		# Get collision details
		var collider = forward_raycast.get_collider()
		var collision_point = forward_raycast.get_collision_point()
		var distance_to_collision = global_position.distance_to(collision_point)
		
		# Debug NULL collider issue
		if collider == null and debug_raycast:
			debug_raycast_hit("⚠️ NULL COLLIDER BUG: Raycast reports collision but collider is null!")
			debug_raycast_hit("  Point: " + str(collision_point))
			debug_raycast_hit("  Normal: " + str(forward_raycast.get_collision_normal()))
			debug_raycast_hit("  Distance: " + str("%.2f" % distance_to_collision))
			debug_raycast_hit("  Raycast from: " + str(forward_raycast.global_position))
			debug_raycast_hit("  Raycast to: " + str(forward_raycast.global_position + forward_raycast.target_position))
		
		# Cache distance for debugging/info purposes
		cached_distance_to_obstacle = distance_to_collision
		
		# RAYCAST DEBUG: Track new detectable objects
		var current_object_name = _get_object_debug_name(collider)
		if collider != last_detected_object or current_object_name != last_detected_name:
			last_detected_object = collider
			last_detected_name = current_object_name
			var object_type = _get_object_type(collider)
			
			# Special highlight for traffic light sensors
			var detection_icon = "🎯"
			if collider is Area3D and collider.name == "RedLightSensor":
				detection_icon = "🚦🎯"  # Traffic light + target icon
			
			debug_raycast_hit(detection_icon + " NEW DETECTION: " + current_object_name + " (" + object_type + ") at " + str("%.1f" % distance_to_collision) + " units")
		
		# SAFETY CHECK: Skip processing if collider is null
		if collider == null:
			# Still process the debug tracking for NULL detection
			var null_object_name = "NULL"
			if null_object_name != last_detected_name:
				last_detected_object = null
				last_detected_name = null_object_name
				debug_raycast_hit("🎯 NEW DETECTION: NULL (unknown_freed_object) at " + str("%.1f" % distance_to_collision) + " units")
			# Skip all collision logic for null colliders
			return
		
		
		# DETECTION ZONE: Use different ranges for different obstacle types
		var detection_range = follow_distance
		# Traffic lights need much longer stopping distance due to sensor size
		if collider is Area3D and collider.name == "RedLightSensor":
			detection_range = 16.0  # Extended range to cover full sensor reach
		
		# Debug: Show detection range calculations
		if debug_raycast and collider is Area3D and collider.name == "RedLightSensor":
			debug_raycast_hit("🎯 Traffic light detection: distance=" + str("%.1f" % distance_to_collision) + ", range=" + str(detection_range) + ", will_process=" + str(distance_to_collision <= detection_range))
		
		if distance_to_collision <= detection_range:
			# TYPE 1: VEHICLE DETECTION
			if collider and collider != self and collider.has_method("get_vehicle_type_config"):
				is_blocked_by_vehicle = true
				
			# TYPE 2: TRAFFIC LIGHT SENSOR DETECTION (Clearance Mode vs Approach Mode)
			elif collider is Area3D and collider.name == "RedLightSensor":
				var traffic_light = collider.get_parent()
				if traffic_light and traffic_light.has_method("should_vehicle_stop_at_line"):
					# Check if vehicle is currently in intersection area
					if is_in_intersection:
						# CLEARANCE MODE: Vehicle in intersection - ignore light state, avoid other obstacles only
						if blocked_by_traffic_light:  # Only print on state change
							debug_traffic("🗺️ CLEARANCE MODE: In intersection - ignoring light state")
						blocked_by_traffic_light = false  # Always clear for traffic lights in clearance mode
					else:
						# APPROACH MODE: Vehicle approaching intersection - respect light state
						if traffic_light.should_vehicle_stop_at_line():
							if not blocked_by_traffic_light:  # Only print on state change
								var state = "red" if traffic_light.is_light_red() else "amber"
								debug_traffic("⛔ APPROACH MODE: " + state.to_upper() + " light - must stop")
							blocked_by_traffic_light = true
						else:
							if blocked_by_traffic_light:  # Only print on state change
								debug_traffic("✅ APPROACH MODE: GREEN light - can proceed")
							blocked_by_traffic_light = false  # Green light, can proceed
				else:
					# Fallback to old system if new methods don't exist
					if traffic_light and traffic_light.has_method("is_red") and traffic_light.is_red:
						if not blocked_by_traffic_light:  # Only print on state change
							debug_traffic("🔴 Stopped at red light sensor (fallback)")
						blocked_by_traffic_light = true
					else:
						blocked_by_traffic_light = false
				
			# TYPE 3: STATIC OBSTACLE DETECTION
			else:
				is_blocked_by_vehicle = true
		else:
			# Obstacle detected but outside immediate stop zone
			is_blocked_by_vehicle = false
	else:
		# CLEAR ROAD: No obstacles detected
		is_blocked_by_vehicle = false
		cached_distance_to_obstacle = 99.0
		
		# RAYCAST DEBUG: Track when detection clears
		if last_detected_object != null:
			debug_raycast_hit("✅ DETECTION CLEARED: " + last_detected_name + " no longer detected")
			last_detected_object = null
			last_detected_name = ""


func get_blocking_status() -> Dictionary:
	"""Get detailed information about what's blocking this vehicle"""
	return {
		"blocked_by_vehicle": is_blocked_by_vehicle,
		"blocked_by_traffic_light": blocked_by_traffic_light,
		"can_move": not is_blocked_by_vehicle and not blocked_by_traffic_light,
		"follow_distance": follow_distance,
		"current_speed": current_speed
	}

# =============================================================================
# RAYCAST DEBUG HELPER FUNCTIONS
# =============================================================================

func _get_object_debug_name(collider: Node) -> String:
	"""Get a descriptive name for raycast debug messages"""
	if not collider:
		return "NULL"
	
	# For Area3D traffic light sensors, show parent traffic light name
	if collider is Area3D and collider.name == "RedLightSensor":
		var parent = collider.get_parent()
		return "TrafficLight[" + (parent.name if parent else "unknown") + "].RedLightSensor"
	
	# For any Area3D, show more details
	if collider is Area3D:
		var parent = collider.get_parent()
		return "Area3D[" + collider.name + "] parent:" + (parent.name if parent else "none")
	
	# For vehicles, show vehicle name and type
	if collider.has_method("get_vehicle_type_config"):
		var config = collider.get_vehicle_type_config()
		var type_name = config.vehicle_name if config and "vehicle_name" in config else "Vehicle"
		return type_name + "[" + collider.name + "]"
	
	# For other objects, show class and name
	return collider.get_class() + "[" + collider.name + "]"

func _get_object_type(collider: Node) -> String:
	"""Get object type category for raycast debug"""
	if not collider:
		return "null"
	
	if collider is Area3D and collider.name == "RedLightSensor":
		return "traffic_light_sensor"
	
	if collider.has_method("get_vehicle_type_config"):
		return "vehicle"
	
	if collider is StaticBody3D:
		return "static_obstacle"
	
	if collider is CharacterBody3D:
		return "character"
	
	if collider is Area3D:
		return "area"
	
	return "unknown"

func _scan_for_traffic_light_sensors():
	"""Debug function to find all RedLightSensor nodes in the scene"""
	var sensors = get_tree().get_nodes_in_group("RedLightSensor")
	if sensors.is_empty():
		# Try finding by name instead
		var root = get_tree().current_scene
		sensors = _find_nodes_by_name(root, "RedLightSensor")
	
	if sensors.is_empty():
		debug_raycast_hit("⚠️ NO RedLightSensor nodes found in scene!")
	else:
		debug_raycast_hit("🚦 Found " + str(sensors.size()) + " RedLightSensor(s):")
		for i in sensors.size():
			var sensor = sensors[i]
			debug_raycast_hit("  [" + str(i) + "] " + sensor.name + " at " + str(sensor.global_position) + " layer:" + str(sensor.collision_layer))

func _find_nodes_by_name(node: Node, target_name: String) -> Array:
	"""Recursively find nodes by name"""
	var found_nodes = []
	if node.name == target_name:
		found_nodes.append(node)
	
	for child in node.get_children():
		found_nodes.append_array(_find_nodes_by_name(child, target_name))
	
	return found_nodes

# =============================================================================
# VEHICLE TYPE CONFIGURATION
# =============================================================================

func configure_with_type(config: Resource):
	"""Configure this vehicle instance with a VehicleTypeConfig"""
	if not config:
		debug_config("Warning: No vehicle type config provided")
		return
	
	vehicle_type_config = config
	
	
	# Apply speed from config
	if config.has_method("get_random_speed"):
		max_speed = config.get_random_speed()
	else:
		# Fallback to config properties if methods aren't available
		if "base_speed_min" in config and "base_speed_max" in config:
			max_speed = randf_range(config.base_speed_min, config.base_speed_max)
	
	# Apply acceleration and braking forces from config
	if "acceleration" in config:
		acceleration = config.acceleration
	if "braking_force" in config:
		braking_force = config.braking_force
	
	# Apply following distance (critical for distance-based speed control)
	if "following_distance" in config:
		follow_distance = config.following_distance
	
	# ⚠️ LEGACY BLOAT: Initialize unused legacy parameters for compatibility
	# These are set but not used in the simplified distance-based system
	if "legacy_stopping_distance" in config:
		stop_distance = config.legacy_stopping_distance  # ⚠️ UNUSED
	comfort_braking_force = braking_force * 0.6  # ⚠️ UNUSED 
	braking_zone_distance = max(follow_distance * 2.5, 6.0)  # ⚠️ Only used for adaptive frequency
	
	debug_config("Vehicle configured: " + str(config.vehicle_name))
	debug_config("	• Max Speed: " + str(max_speed) + " | Follow Distance: " + str(follow_distance))
	debug_config("	• Acceleration: " + str(acceleration) + " | Braking Force: " + str(braking_force))

func get_vehicle_type_config() -> Resource:
	"""Get the current vehicle type configuration"""
	return vehicle_type_config

func is_emergency_vehicle() -> bool:
	"""Check if this vehicle is an emergency vehicle"""
	if vehicle_type_config and "is_emergency_vehicle" in vehicle_type_config:
		return vehicle_type_config.is_emergency_vehicle
	return false

func get_priority_level() -> int:
	"""Get the priority level of this vehicle (higher = more important)"""
	if vehicle_type_config and "priority_level" in vehicle_type_config:
		return vehicle_type_config.priority_level
	return 1  # Normal priority

# =============================================================================
# SCORING SYSTEM INTEGRATION
# =============================================================================

func _initialize_scoring():
	"""Initialize scoring system integration"""
	# Generate unique agent ID
	agent_id = "vehicle_" + str(get_instance_id())
	spawn_time = Time.get_unix_time_from_system()
	
	# Find ScoreManager in the scene
	score_manager = get_node_or_null("/root/Main/ScoreManager")
	if not score_manager:
		# Try alternative paths
		score_manager = get_tree().get_first_node_in_group("score_manager")
	
	if score_manager and score_manager.has_method("register_agent"):
		score_manager.register_agent(agent_id, "vehicle", spawn_time)
		debug_config("Vehicle registered with ScoreManager: " + agent_id)
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
	"""Handle vehicle journey completion - emit signal and notify scoring system"""
	# Emit signal for any systems that need to know about completion
	journey_completed.emit(self, agent_id)
	
	# Notify scoring system directly
	if score_manager and score_manager.has_method("complete_agent"):
		score_manager.complete_agent(agent_id)
		debug_config("Vehicle journey completed - scored: " + agent_id)

func complete_journey():
	"""Legacy method for external completion calls - use _handle_journey_completion instead"""
	_handle_journey_completion()

func get_scoring_info() -> Dictionary:
	"""Get current scoring information for this vehicle"""
	if score_manager and score_manager.has_method("calculate_agent_points"):
		return {
			"agent_id": agent_id,
			"current_points": score_manager.calculate_agent_points(agent_id),
			"spawn_time": spawn_time,
			"is_moving": can_move() and current_speed > 0.01
		}
	else:
		return {
			"agent_id": agent_id,
			"current_points": 0,
			"spawn_time": spawn_time,
			"is_moving": false
		}
