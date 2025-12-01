# Test script to verify Enhanced Smooth Movement System
# This script can be run in Godot's script runner to test our implementation

extends MainLoop

func test_vehicle_configuration():
	print("=== TESTING ENHANCED SMOOTH MOVEMENT SYSTEM ===")
	
	# Test vehicle configuration loading
	var sedan_config = load("res://configs/vehicle_types/SedanConfig.tres")
	var truck_config = load("res://configs/vehicle_types/TruckConfig.tres")
	
	if sedan_config:
		print("✅ Sedan Config Loaded:")
		print("   - Acceleration: ", sedan_config.acceleration)
		print("   - Braking Force: ", sedan_config.braking_force)
		print("   - Following Distance: ", sedan_config.following_distance)
		
		# Calculate derived values like our Vehicle.gd does
		var comfort_braking = sedan_config.braking_force * 0.6
		var braking_zone = max(sedan_config.following_distance * 2.5, 6.0)
		print("   - Computed Comfort Braking: ", comfort_braking)
		print("   - Computed Braking Zone: ", braking_zone)
	else:
		print("❌ Failed to load Sedan Config")
	
	if truck_config:
		print("✅ Truck Config Loaded:")
		print("   - Acceleration: ", truck_config.acceleration)
		print("   - Braking Force: ", truck_config.braking_force)
		print("   - Following Distance: ", truck_config.following_distance)
		
		# Calculate derived values
		var comfort_braking = truck_config.braking_force * 0.6
		var braking_zone = max(truck_config.following_distance * 2.5, 6.0)
		print("   - Computed Comfort Braking: ", comfort_braking)
		print("   - Computed Braking Zone: ", braking_zone)
	else:
		print("❌ Failed to load Truck Config")
	
	print("\n=== TESTING SMOOTH MOVEMENT CALCULATIONS ===")
	test_speed_calculations()

func test_speed_calculations():
	# Simulate the smooth movement calculations from Vehicle.gd
	var max_speed = 5.0
	var braking_zone_distance = 7.0
	var follow_distance = 2.5
	
	# Test different distances
	var test_distances = [10.0, 7.0, 5.0, 3.0, 2.0, 1.0]
	
	for distance in test_distances:
		var target_speed = calculate_target_speed_simulation(distance, max_speed, braking_zone_distance, follow_distance)
		print("Distance: ", distance, " → Target Speed: ", "%.2f" % target_speed, " (", "%.1f" % (target_speed/max_speed*100), "%)")

func calculate_target_speed_simulation(cached_distance_to_obstacle: float, max_speed: float, braking_zone_distance: float, follow_distance: float) -> float:
	# Replicate the NEW simplified distance-based speed control from Vehicle.gd
	
	# Distance-based speed calculation: Linear relationship between distance and speed
	# At follow_distance: speed = 0
	# At 8.0 units (raycast range): speed = max_speed
	var speed_range = 8.0 - follow_distance
	var distance_above_minimum = max(0.0, cached_distance_to_obstacle - follow_distance)
	
	# Linear interpolation: further = faster
	var speed_factor = distance_above_minimum / speed_range
	speed_factor = clamp(speed_factor, 0.0, 1.0)
	
	return max_speed * speed_factor

# MainLoop override functions
func _initialize():
	test_vehicle_configuration()
	# Exit after test

func _process(_delta):
	return true  # Exit the loop
