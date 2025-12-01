extends Node

# Test script for "Time is Money" scoring system
# Run this to validate scoring functionality

func test_scoring_system():
	print("=== TESTING 'TIME IS MONEY' SCORING SYSTEM ===")
	
	# Test 1: LevelConfig scoring properties
	print("\n1. Testing LevelConfig scoring properties...")
	var config = load("res://configs/levels/tutorial_01_easy.tres")
	if config and config.has_method("get_required_vehicles"):
		print("✅ LevelConfig has required_vehicles: ", config.get_required_vehicles())
		print("✅ LevelConfig has required_pedestrians: ", config.get_required_pedestrians())
		print("✅ LevelConfig has target_score: ", config.get_target_score())
		var thresholds = config.get_star_thresholds()
		print("✅ LevelConfig has star_thresholds: ", thresholds)
	else:
		print("❌ LevelConfig scoring methods not found")
		return false
	
	# Test 2: ScoreManager creation and initialization
	print("\n2. Testing ScoreManager creation...")
	var ScoreManagerScript = load("res://scripts/ScoreManager.gd")
	if ScoreManagerScript:
		var score_manager = ScoreManagerScript.new()
		score_manager.name = "TestScoreManager"
		add_child(score_manager)
		
		# Initialize with test config
		score_manager.initialize_scoring(config)
		
		# Test agent registration
		score_manager.register_agent("test_vehicle_1", "vehicle", Time.get_unix_time_from_system())
		
		# Test scoring calculation
		var initial_points = score_manager.calculate_agent_points("test_vehicle_1")
		print("✅ Vehicle starts with ", initial_points, " points")
		
		# Simulate waiting
		score_manager.set_agent_waiting("test_vehicle_1", true)
		await get_tree().create_timer(1.0).timeout  # Wait 1 second
		
		var after_wait_points = score_manager.calculate_agent_points("test_vehicle_1")
		print("✅ After 1 second wait: ", after_wait_points, " points")
		
		if after_wait_points < initial_points:
			print("✅ Point decay working correctly")
		else:
			print("❌ Point decay not working")
			return false
		
		# Test completion
		score_manager.complete_agent("test_vehicle_1")
		var stats = score_manager.get_scoring_stats()
		print("✅ After completion - Total Score: ", stats.total_score)
		print("✅ Completed vehicles: ", stats.completed_vehicles, "/", stats.required_vehicles)
		
		score_manager.queue_free()
	else:
		print("❌ Could not load ScoreManager script")
		return false
	
	# Test 3: ScoreDisplay scene loading
	print("\n3. Testing ScoreDisplay scene...")
	var ScoreDisplayScene = load("res://scenes/ui/ScoreDisplay.tscn")
	if ScoreDisplayScene:
		var score_display = ScoreDisplayScene.instantiate()
		if score_display:
			print("✅ ScoreDisplay scene loads and instantiates correctly")
			score_display.queue_free()
		else:
			print("❌ ScoreDisplay scene failed to instantiate")
			return false
	else:
		print("❌ Could not load ScoreDisplay scene")
		return false
	
	# Test 4: Vehicle scoring integration check
	print("\n4. Testing Vehicle scoring integration...")
	var VehicleScript = load("res://scripts/Vehicle.gd")
	if VehicleScript:
		var vehicle_script_content = FileAccess.open("res://scripts/Vehicle.gd", FileAccess.READ).get_as_text()
		if "agent_id" in vehicle_script_content and "score_manager" in vehicle_script_content:
			print("✅ Vehicle.gd has scoring integration variables")
		else:
			print("❌ Vehicle.gd missing scoring integration")
			return false
		
		if "_initialize_scoring" in vehicle_script_content:
			print("✅ Vehicle.gd has _initialize_scoring method")
		else:
			print("❌ Vehicle.gd missing _initialize_scoring method")
			return false
	else:
		print("❌ Could not load Vehicle script")
		return false
	
	print("\n🎉 ALL SCORING SYSTEM TESTS PASSED!")
	print("✅ Scoring system is ready for gameplay testing")
	return true

func _ready():
	test_scoring_system()