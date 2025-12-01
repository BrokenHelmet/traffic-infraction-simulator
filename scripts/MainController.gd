extends Node

# =============================================================================
# MAIN APPLICATION CONTROLLER
# =============================================================================
# Manages the overall application flow from landing screen to main game
# Handles scene transitions and maintains game state
# =============================================================================

@onready var landing_screen = $LandingScreen

# Reference to the main game scene
var main_game_scene = preload("res://scenes/intersection/LandingMain.tscn")
var current_game_instance = null

func _ready():
	landing_screen.is_transitioning = true
	get_node("SplashScreen").start_splash()
	
	get_node("SplashScreen").splash_completed.connect(
		func(): 
			landing_screen.is_transitioning = false,
		CONNECT_ONE_SHOT)
	
	print("Main Controller initialized - Landing screen active")

func _on_landing_screen_start_game_requested():
	print("Main Controller: Received start game request from landing screen")
	transition_to_main_game()

func transition_to_main_game():
	print("Main Controller: Starting transition to main game...")
	
	# Remove the landing screen
	if landing_screen:
		landing_screen.queue_free()
	
	# Wait a frame to ensure clean removal
	await get_tree().process_frame
	
	# Instantiate and add the main game scene
	current_game_instance = main_game_scene.instantiate()
	if current_game_instance:
		add_child(current_game_instance)
		print("Main Controller: Main game scene loaded successfully")
	else:
		print("ERROR: Failed to instantiate main game scene")

func _input(event):
	# Handle Android back button globally
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
			print("Back button pressed - quitting application")
			get_tree().quit()
