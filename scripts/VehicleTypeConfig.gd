extends Resource

# =============================================================================
# VEHICLE TYPE CONFIGURATION SYSTEM
# =============================================================================
# Data-driven vehicle type configuration for Traffic Control Simulator
# Each vehicle type has its own .tres resource file using this script
# =============================================================================

# =============================================================================
# GROUP 1: VEHICLE IDENTITY
# =============================================================================
@export_group("Vehicle Identity")
@export var vehicle_name: String = "Generic Vehicle" ## Display name for this vehicle type
@export_enum("sedan", "truck", "bus", "emergency", "motorcycle", "van") var vehicle_category: String = "sedan" ## Vehicle category - affects behavior and spawning
@export var is_emergency_vehicle: bool = false ## Emergency vehicles can ignore some traffic rules
@export_range(1, 3) var priority_level: int = 1 ## Traffic priority: 1=Normal, 2=High (Emergency), 3=Highest (Fire/Ambulance)

# =============================================================================
# GROUP 2: MOVEMENT PHYSICS
# =============================================================================
@export_group("Movement Physics")
@export_range(1.0, 50.0, 0.1) var base_speed_min: float = 2.0 ## Minimum speed when moving (units/sec)
@export_range(1.0, 50.0, 0.1) var base_speed_max: float = 5.0 ## Maximum speed when moving (units/sec)
@export_range(0.1, 20.0, 0.1) var acceleration: float = 2.0 ## How fast vehicle speeds up (units/sec²)
@export_range(0.1, 30.0, 0.1) var braking_force: float = 4.0 ## How fast vehicle slows down (units/sec²)
@export_range(1.0, 50.0, 0.1) var following_distance: float = 2.5 ## Safe distance to maintain behind other vehicles (units)

# =============================================================================
# GROUP 3: GAME BALANCE
# =============================================================================
@export_group("Game Balance")
@export_range(0.0, 5.0, 0.1) var spawn_weight: float = 1.0 ## Spawn probability weight - higher values = more common (0 = never spawns)
@export_enum("easy", "medium", "hard", "expert") var unlocked_at_difficulty: String = "easy" ## Minimum difficulty level where this vehicle appears

# =============================================================================
# UNUSED/LEGACY SETTINGS (Kept for compatibility)
# =============================================================================
@export_group("Legacy Settings (Unused)", "legacy_")
@export var legacy_collision_box_size: Vector3 = Vector3(1.0, 1.0, 2.0) ## [UNUSED] Collision shape dimensions - kept for compatibility
@export var legacy_can_change_lanes: bool = true ## [UNUSED] Lane changing capability - not implemented
@export_range(0.0, 50.0, 0.1) var legacy_stopping_distance: float = 2.0 ## [UNUSED] Old stopping distance - following_distance used instead
@export_range(0.0, 1.0, 0.01) var legacy_honk_probability: float = 0.1 ## [UNUSED] Chance to honk - audio system not implemented
@export_range(0.1, 3.0, 0.1) var legacy_engine_sound_pitch: float = 1.0 ## [UNUSED] Engine sound pitch - audio system not implemented
@export var legacy_horn_sound: String = "default_horn" ## [UNUSED] Horn sound file - audio system not implemented

func get_random_speed() -> float:
	"""Get a random speed within this vehicle type's range"""
	return randf_range(base_speed_min, base_speed_max)


func is_available_for_difficulty(difficulty: String) -> bool:
	"""Check if this vehicle type should be available for the given difficulty"""
	var difficulty_levels = ["easy", "medium", "hard", "expert"]
	var required_index = difficulty_levels.find(unlocked_at_difficulty.to_lower())
	var current_index = difficulty_levels.find(difficulty.to_lower())
	
	return current_index >= required_index if required_index >= 0 else true

func print_config():
	"""Debug function to print vehicle configuration"""
	print("=== Vehicle Type: ", vehicle_name, " ===")
	print("")
	
	print("VEHICLE IDENTITY:")
	print("  • Category: ", vehicle_category)
	print("  • Emergency: ", "Yes" if is_emergency_vehicle else "No")
	print("  • Priority: ", priority_level, " (1=normal, 2=high, 3=highest)")
	print("")
	
	print("MOVEMENT PHYSICS:")
	print("  • Speed range: ", base_speed_min, "-", base_speed_max, " units/sec")
	print("  • Acceleration: ", acceleration, " units/sec²")
	print("  • Braking force: ", braking_force, " units/sec²")
	print("  • Following distance: ", following_distance, " units")
	print("")
	
	print("GAME BALANCE:")
	print("  • Spawn weight: ", spawn_weight, " (higher = more common)")
	print("  • Available from: ", unlocked_at_difficulty, " difficulty")
	print("")
	
	print("LEGACY SETTINGS (Unused):")
	print("  • Collision box: ", legacy_collision_box_size, " (UNUSED)")
	print("  • Can change lanes: ", legacy_can_change_lanes, " (UNUSED)")
	print("  • Stopping distance: ", legacy_stopping_distance, " (UNUSED - following_distance used)")
	print("  • Audio settings: ", legacy_horn_sound, " @ ", legacy_engine_sound_pitch, " pitch (UNUSED)")
	print("=".repeat(60))
