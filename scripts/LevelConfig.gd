extends Resource

# =============================================================================
# LEVEL CONFIGURATION SYSTEM
# =============================================================================
# Data-driven level configuration for Traffic Control Simulator
# Uses Godot's Resource system (without class_name due to compatibility issues)
# 
# Phase 2: Visual setup variables (camera positions, UI layout)
@export var camera_positions: Array[Dictionary] = []
# TODO Phase 3: Add environment variables (weather, time of day, lighting)
# TODO Phase 4: Add tutorial system variables (hints, instructions)
# TODO: Create config validation system with detailed error messages
# TODO: Add config versioning for backward compatibility
# TODO: Add pedestrian management properties (pedestrian_count, pedestrian_speed_min/max, pedestrian_spawn_interval)
# TODO: Add vehicle and pedestrian path configuration (vehicle_paths, pedestrian_paths arrays)
# TODO: Add pedestrian crossing logic and traffic light coordination
# =============================================================================

# Traffic Control Simulator Level Configuration

# =============================================================================
# GROUP 1: LEVEL IDENTITY
# =============================================================================
@export_group("🆔 Level Identity")
@export var level_scene: PackedScene
@export var level_name: String = "Default Level"
@export var difficulty: String = "Easy"
@export var level_description: String = "A basic traffic control scenario"
@export var welcome_message: String = "Welcome to the level!"

# =============================================================================
# GROUP 2: VEHICLE TRAFFIC
# =============================================================================
#@export_group("🚗 Vehicle Traffic")
#@export var max_vehicles: int = 5
#@export var vehicles_per_path: int = 1  # Maximum vehicles allowed per path (1 = tutorial, 2+ = advanced)
#@export var vehicle_spawn_rate: float = 2.0  # Vehicles per second
#@export var allow_emergency_vehicles: bool = false

# =============================================================================
# GROUP 3: PEDESTRIAN TRAFFIC
# =============================================================================
#@export_group("🚶 Pedestrian Traffic")
#@export var max_pedestrians: int = 0  # 0 = no pedestrians
#@export var pedestrian_spawn_rate: float = 1.0  # Pedestrians per second
#@export var pedestrian_speed_min: float = 1.0
#@export var pedestrian_speed_max: float = 2.0

# =============================================================================
# GROUP 4: CAMERA SETUP
# =============================================================================
@export_group("🎥 Camera Setup")
# Camera positions handled separately as Array[Dictionary]

# =============================================================================
# GROUP 5: SCORING SYSTEM
# =============================================================================
@export_group("💰 Scoring System")
@export var required_vehicles: int = 0        # Minimum vehicles that must complete (0 = auto-calculate)
@export var required_pedestrians: int = 0    # Minimum pedestrians that must complete (0 = auto-calculate)  
@export var target_score: int = 0            # Target score for 3-star rating (0 = auto-calculate)
@export var score_thresholds: Array[int] = [] # Custom star thresholds [1-star, 2-star, 3-star] (empty = auto-calculate)

# =============================================================================
# DEPRECATED/SUSPENDED SETTINGS (Kept for compatibility but not actively used)
# =============================================================================
#@export_group("⚠️ Legacy Settings (Unused)")
#@export var vehicle_speed_min: float = 2.0   # ⚠️ UNUSED - VehicleTypeConfig overrides
#@export var vehicle_speed_max: float = 5.0   # ⚠️ UNUSED - VehicleTypeConfig overrides
@export var time_limit: float = 60.0         # ⚠️ SUSPENDED - Presentation mode runs indefinitely
#@export var target_vehicles_passed: int = 10 # ⚠️ SUSPENDED - Win condition disabled
#@export var max_collisions_allowed: int = 3  # ⚠️ SUSPENDED - Fail condition disabled
#@export var max_wait_time: float = 15.0      # ⚠️ UNUSED - Not implemented

func print_message():
	print("Test message: ", welcome_message)

func print_config():
	print("🆔 === Traffic Control Level: ", level_name, " ===")
	print("📄 Description: ", level_description)
	print("💬 Welcome: ", welcome_message)
	print("⚙️  Difficulty: ", difficulty)
	print("")
	
	print("💰 SCORING SYSTEM:")
	if required_vehicles > 0 or required_pedestrians > 0:
		print("  • Required vehicles: ", required_vehicles, " (minimum to complete)")
		print("  • Required pedestrians: ", required_pedestrians, " (minimum to complete)")
		print("  • Target score: ", get_target_score(), " points (for 3-star rating)")
		var thresholds = get_star_thresholds()
		print("  • Star thresholds: 1★=", thresholds[0], ", 2★=", thresholds[1], ", 3★=", thresholds[2])
	else:
		print("  • Auto-calculated based on traffic settings")
	print("")
	
	print("🎥 CAMERA POSITIONS (", get_camera_count(), "):")
	if get_camera_count() > 0:
		for i in range(get_camera_count()):
			var pos = get_camera_position(i)
			var rot = get_camera_rotation(i)
			print("  • Camera ", i + 1, ": Position ", pos, ", Rotation ", rot)
	else:
		print("  • No camera positions configured")
	print("")
	
	print("=".repeat(70))

func is_valid() -> bool:
	return not level_name.is_empty() and time_limit > 0

# Camera positioning functions (Phase 2)
func get_camera_count() -> int:
	"""Get the number of configured camera positions"""
	return camera_positions.size()

func get_camera_position(index: int) -> Vector3:
	"""Get camera position by index"""
	if index >= 0 and index < camera_positions.size():
		return camera_positions[index].get("position", Vector3.ZERO)
	return Vector3.ZERO

func get_camera_rotation(index: int) -> Vector3:
	"""Get camera rotation by index"""
	if index >= 0 and index < camera_positions.size():
		return camera_positions[index].get("rotation", Vector3.ZERO)
	return Vector3.ZERO

# Timer-related helper functions
func has_time_limit() -> bool:
	"""Check if level has a time limit configured"""
	return time_limit > 0

func get_time_limit() -> float:
	"""Get the time limit in seconds"""
	return time_limit

func get_formatted_time_limit() -> String:
	"""Get time limit formatted as MM:SS"""
	var minutes = int(time_limit) / 60
	var seconds = int(time_limit) % 60
	return "%02d:%02d" % [minutes, seconds]

func is_time_limit_valid() -> bool:
	"""Validate time limit is reasonable (between 30 seconds and 30 minutes)"""
	return time_limit >= 30.0 and time_limit <= 1800.0

# Scoring system helper functions
func get_required_vehicles() -> int:
	"""Get minimum vehicles required for level completion"""
	return required_vehicles

func get_required_pedestrians() -> int:
	"""Get minimum pedestrians required for level completion"""
	return required_pedestrians

func get_target_score() -> int:
	"""Get target score for perfect (3-star) performance"""
	if target_score > 0:
		return target_score
	else:
		# Auto-calculate based on perfect efficiency: all agents complete with maximum points
		return (required_vehicles * 10) + (required_pedestrians * 5)

func get_star_thresholds() -> Array[int]:
	"""Get score thresholds for 1, 2, and 3-star ratings"""
	if score_thresholds.size() >= 3:
		return score_thresholds
	else:
		# Auto-calculate thresholds based on target score
		var target = get_target_score()
		return [
			int(target * 0.3),   # 1-star: 30% efficiency
			int(target * 0.6),   # 2-star: 60% efficiency
			target               # 3-star: 100% efficiency
		]

func get_completion_requirements() -> Dictionary:
	"""Get all completion requirements in a dictionary"""
	return {
		"vehicles": required_vehicles,
		"pedestrians": required_pedestrians,
		"target_score": get_target_score(),
		"star_thresholds": get_star_thresholds()
	}
