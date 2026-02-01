extends Node

# =============================================================================
# GAME MANAGER
# =============================================================================
# Handles vehicle spawning, game state, objectives, and level configuration integration
# Connects level configuration properties to actual gameplay mechanics
# =============================================================================

# DEBUG SETTINGS - Set to false by default to reduce console clutter
@export_group("Debug Settings")
@export var debug_spawning: bool = false
@export var debug_pedestrian_spawning: bool = false
@export var debug_path_management: bool = false
@export var debug_level_objectives: bool = false
@export var debug_vehicle_cleanup: bool = false
@export var debug_pedestrian_cleanup: bool = false

# References to main systems
var main_controller: Node2D
var level_config: Resource
var spawn_timer: Timer

# Vehicle management
var active_vehicles: Array[CharacterBody3D] = []
var vehicle_prefab: PackedScene
var vehicle_paths: Array[Path3D] = []
var occupied_paths: Dictionary = {}  # Track which paths have active vehicles (path -> Array[vehicles])
var available_vehicle_types: Array[Resource] = []

# Pedestrian management
var active_pedestrians: Array[CharacterBody3D] = []
var pedestrian_prefab: PackedScene
var pedestrian_paths: Array[Path3D] = []
var occupied_pedestrian_paths: Dictionary = {}  # Track which paths have active pedestrians
var pedestrian_spawn_timer: Timer

# Game state
var vehicles_passed: int = 0
var pedestrians_passed: int = 0
var collisions_count: int = 0
var level_start_time: float = 0.0
var is_level_active: bool = false

# Spawning control
var can_spawn_vehicles: bool = true
var can_spawn_pedestrians: bool = true

signal vehicle_passed
signal pedestrian_passed
signal vehicle_collision
signal level_completed(success: bool)

# =============================================================================
# DEBUG HELPER FUNCTIONS
# =============================================================================

func debug_print(message: String, enabled: bool):
	if enabled:
		print("[GameManager] ", message)

func dbg_spawn(message: String):
	debug_print(message, debug_spawning)

func dbg_pedestrian_spawn(message: String):
	debug_print(message, debug_pedestrian_spawning)

func dbg_path(message: String):
	debug_print(message, debug_path_management)

func dbg_objective(message: String):
	debug_print(message, debug_level_objectives)

func dbg_cleanup(message: String):
	debug_print(message, debug_vehicle_cleanup)

func dbg_pedestrian_cleanup(message: String):
	debug_print(message, debug_pedestrian_cleanup)

func _ready():	
	# Find main controller
	main_controller = get_parent()
	
	# Create vehicle spawn timer
	spawn_timer = Timer.new()
	spawn_timer.name = "VehicleSpawnTimer"
	spawn_timer.autostart = false
	spawn_timer.one_shot = false
	add_child(spawn_timer)
	
	# Create pedestrian spawn timer
	pedestrian_spawn_timer = Timer.new()
	pedestrian_spawn_timer.name = "PedestrianSpawnTimer"
	pedestrian_spawn_timer.autostart = false
	pedestrian_spawn_timer.one_shot = false
	add_child(pedestrian_spawn_timer)

func initialize_level(config: Resource, level_scene: Node3D):
	"""Initialize the level with configuration and start vehicle spawning"""
	level_config = config
	is_level_active = true
	level_start_time = Time.get_unix_time_from_system()
	vehicles_passed = 0
	pedestrians_passed = 0
	collisions_count = 0
	occupied_paths.clear()  # Reset path tracking
	occupied_pedestrian_paths.clear()  # Reset pedestrian path tracking
	
	dbg_spawn("Initializing level with config")
	
	if not level_config:
		dbg_spawn("Warning - No level config provided")
		return

func _process(_delta):
	pass

func _input(event: InputEvent) -> void:
	# Add a raycast from the camera center point to the scene and work out what is hit
	
	var _viewport = get_viewport()
	var _camera = _viewport.get_camera_3d()
	#var _raycast = 
	var _ray_origin = _camera.project_ray_origin(_viewport.get_mouse_position())
	var _ray_end = _ray_origin + _camera.project_ray_normal(_viewport.get_mouse_position()) * 1000
	
	#var space_state = get_world_3d().direct_space_state
	
	#if event.is_pressed():
		#if event is InputEventScreenTouch:
			#print ("Target incident has been hit via touch screen")
		#
		#elif event is InputEventMouseButton:
			#if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
				#print ("Target incident has been hit via mouse", event.button_index)

func _check_level_objectives():
	"""Check if level objectives have been met"""
	if not level_config:
		return
	
	# PRESENTATION MODE: Game over functionality suspended for continuous traffic flow
	# This allows for uninterrupted demonstration of the traffic control system
	
	var current_time = Time.get_unix_time_from_system()
	var elapsed_time = current_time - level_start_time
	
	# SUSPENDED: Check win condition - vehicles will continue spawning indefinitely
	# if vehicles_passed >= level_config.target_vehicles_passed:
	#	_complete_level(true)
	#	return
	
	# SUSPENDED: Check fail conditions - no time limit or collision limits
	# if elapsed_time >= level_config.time_limit:
	#	print("GameManager: Time limit reached")
	#	_complete_level(false)
	#	return
	
	# if collisions_count >= level_config.max_collisions_allowed:
	#	print("GameManager: Too many collisions")
	#	_complete_level(false)
	#	return
	
	# Optional: Print status updates for monitoring during presentation
	if int(elapsed_time) % 30 == 0 and int(elapsed_time) > 0:  # Every 30 seconds
		dbg_objective("😦 Traffic Status - Vehicles passed: " + str(vehicles_passed) + ", Pedestrians passed: " + str(pedestrians_passed) + ", Active V/P: " + str(active_vehicles.size()) + "/" + str(active_pedestrians.size()) + ", Collisions: " + str(collisions_count))

func _complete_level(success: bool):
	"""Complete the level with success or failure"""
	if not is_level_active:
		return
	
	is_level_active = false
	can_spawn_vehicles = false
	
	if spawn_timer:
		spawn_timer.stop()
	
	var result = "SUCCESS" if success else "FAILED"
	dbg_objective("Level " + str(result))
	dbg_objective("	• Vehicles passed: " + str(vehicles_passed) + "/" + str(level_config.target_vehicles_passed))
	dbg_objective("	• Collisions: " + str(collisions_count) + "/" + str(level_config.max_collisions_allowed))
	
	level_completed.emit(success)

func get_level_status() -> Dictionary:
	"""Get current level status for UI display"""
	var current_time = Time.get_unix_time_from_system()
	var elapsed_time = current_time - level_start_time
	var remaining_time = level_config.time_limit - elapsed_time if level_config else 0.0
	
	return {
		"vehicles_passed": vehicles_passed,
		"target_vehicles": level_config.target_vehicles_passed if level_config else 0,
		"collisions": collisions_count,
		"max_collisions": level_config.max_collisions_allowed if level_config else 0,
		"remaining_time": max(0.0, remaining_time),
		"active_vehicles": active_vehicles.size(),
		"max_vehicles": level_config.max_vehicles if level_config else 0
	}

func stop_level():
	"""Stop the current level and perform comprehensive cleanup"""
	dbg_spawn("Stopping level and cleaning up all vehicles...")
	
	# Immediately stop all game processes
	is_level_active = false
	can_spawn_vehicles = false
	can_spawn_pedestrians = false
	
	# Stop both spawn timers immediately
	if spawn_timer:
		spawn_timer.stop()
		dbg_spawn("Vehicle spawn timer stopped")
	
	if pedestrian_spawn_timer:
		pedestrian_spawn_timer.stop()
		dbg_pedestrian_spawn("Pedestrian spawn timer stopped")
	
	# Clean up all active vehicles immediately
	var vehicle_count = active_vehicles.size()
	for vehicle in active_vehicles:
		if is_instance_valid(vehicle):
			# Remove PathFollow3D nodes created for this vehicle
			if vehicle.has_method("get") and "path" in vehicle and vehicle.path:
				if is_instance_valid(vehicle.path):
					vehicle.path.queue_free()
			
			# Queue the vehicle for deletion
			vehicle.queue_free()
			dbg_cleanup("Queued vehicle for deletion: " + vehicle.name)
	
	# Clean up all active pedestrians immediately
	var pedestrian_count = active_pedestrians.size()
	for pedestrian in active_pedestrians:
		if is_instance_valid(pedestrian):
			# Remove PathFollow3D nodes created for this pedestrian
			if pedestrian.has_method("get") and "path" in pedestrian and pedestrian.path:
				if is_instance_valid(pedestrian.path):
					pedestrian.path.queue_free()
			
			# Queue the pedestrian for deletion
			pedestrian.queue_free()
			dbg_pedestrian_cleanup("Queued pedestrian for deletion: " + pedestrian.name)
	
	# Clear all tracking arrays and dictionaries
	active_vehicles.clear()
	active_pedestrians.clear()
	occupied_paths.clear()
	occupied_pedestrian_paths.clear()
	vehicle_paths.clear()
	pedestrian_paths.clear()
	
	# Reset game state
	vehicles_passed = 0
	pedestrians_passed = 0
	collisions_count = 0
	level_start_time = 0.0
	
	dbg_spawn("Level stopped - cleaned up " + str(vehicle_count) + " vehicles and " + str(pedestrian_count) + " pedestrians")
	dbg_spawn("All tracking arrays cleared")

func cleanup():
	"""Additional cleanup method for when GameManager is being destroyed"""
	dbg_spawn("Performing final cleanup...")
	
	# Stop the level if still active
	if is_level_active:
		stop_level()
	
	# Clean up spawn timers
	if spawn_timer and is_instance_valid(spawn_timer):
		spawn_timer.stop()
		spawn_timer.queue_free()
		spawn_timer = null
	
	if pedestrian_spawn_timer and is_instance_valid(pedestrian_spawn_timer):
		pedestrian_spawn_timer.stop()
		pedestrian_spawn_timer.queue_free()
		pedestrian_spawn_timer = null
	
	# Final cleanup of any remaining references
	active_vehicles.clear()
	active_pedestrians.clear()
	occupied_paths.clear()
	occupied_pedestrian_paths.clear()
	vehicle_paths.clear()
	pedestrian_paths.clear()
	available_vehicle_types.clear()
	
	level_config = null
	main_controller = null
	
	dbg_spawn("Final cleanup completed")

# =============================================================================
# STATISTICS AND REPORTING
# =============================================================================

func get_statistics() -> Dictionary:
	"""Get current game statistics for UI and level completion reporting"""
	var current_time = Time.get_unix_time_from_system()
	var elapsed_time = current_time - level_start_time if level_start_time > 0.0 else 0.0
	
	var stats = {
		"elapsed_time": elapsed_time,
		"elapsed_time_formatted": _format_time(elapsed_time),
		"spawn_rate": level_config.vehicle_spawn_rate if level_config else 0.0,
		"pedestrian_spawn_rate": level_config.pedestrian_spawn_rate if level_config else 0.0,
		"level_active": is_level_active,
		"score": 0  # Base score, will be updated by ScoreManager if available
	}
	
	dbg_objective("Statistics requested - Vehicles: %d, Pedestrians: %d, Collisions: %d, Active V/P: %d/%d, Time: %s" % [vehicles_passed, pedestrians_passed, collisions_count, active_vehicles.size(), active_pedestrians.size(), stats.elapsed_time_formatted])
	
	return stats

# Format elapsed time as MM:SS
func _format_time(time_seconds: float) -> String:
	var minutes = int(time_seconds) / 60
	var seconds = int(time_seconds) % 60
	return "%02d:%02d" % [minutes, seconds]
