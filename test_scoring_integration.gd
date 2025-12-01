extends SceneTree

# Simple test to verify ScoreManager and ScoreDisplay can find each other

func _init():
	print("=== Scoring Integration Test ===")
	
	# Create a test scene
	var test_scene = Node.new()
	test_scene.name = "TestScene"
	current_scene = test_scene
	
	# Simulate what Main.gd does - create ScoreManager
	create_score_manager(test_scene)
	
	# Simulate creating ScoreDisplay (like Main.gd)
	create_score_display(test_scene)
	
	# Wait for initialization
	process_frame.connect(_on_process_frame, CONNECT_ONE_SHOT)

func _on_process_frame():
	print("Frame processed - waiting for ScoreDisplay debug messages...")
	get_tree().create_timer(3.0).timeout.connect(func(): quit())

func create_score_manager(parent_scene: Node):
	# Load and create ScoreManager
	var ScoreManagerScript = load("res://scripts/ScoreManager.gd")
	var score_manager = ScoreManagerScript.new()
	score_manager.name = "ScoreManager"
	
	# Add to scene tree
	parent_scene.add_child(score_manager)
	print("Created ScoreManager at: ", score_manager.get_path())

func create_score_display(parent_scene: Node):
	# Load ScoreDisplay scene
	var score_display_scene = load("res://scenes/ui/ScoreDisplay.tscn")
	
	# Create instance
	if score_display_scene:
		var score_display = score_display_scene.instantiate()
		score_display.name = "ScoreDisplay"
		parent_scene.add_child(score_display)
		print("Created ScoreDisplay at: ", score_display.get_path())
	else:
		print("ERROR: Could not load ScoreDisplay scene")
