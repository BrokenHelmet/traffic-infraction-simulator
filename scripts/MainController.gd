# =============================================================================
# MAIN APPLICATION CONTROLLER
# =============================================================================
# Persistent root node that manages the game's lifecycle and global state.
# Orchestrates transitions between Splash, Landing, and Level scenes.
# Centrally processes gameplay signals (Success/Penalty) from transient levels.
# =============================================================================
extends Node

@export_group("Scene References")
# Reference to the main game scene/level controller
@export var main_game_scene: PackedScene = preload("res://scenes/intersection/LandingMain.tscn")

# Nodes expected to be children of Main in the editor
@onready var splash_screen = $SplashScreen
@onready var landing_screen = $LandingScreen
@onready var hud = $GameHUD # Make sure GameHUD is a child of Main

# Global Game State - Lives here so it persists when levels change
var current_game_instance: Node = null
var total_score: int = 0
var infractions_found: Array[String] = []

func _ready() -> void:
	
	
	hud.hide() # Hide HUD during Splash/Landing
	# Initialize state: Lock landing screen interaction until splash finishes
	if landing_screen:
		landing_screen.is_transitioning = true
	
	# Start the introductory splash sequence
	if splash_screen:
		splash_screen.start_splash()
		
		# Connect splash completion using a lambda for brevity
		splash_screen.splash_completed.connect(
			func(): if landing_screen: landing_screen.is_transitioning = false,
			CONNECT_ONE_SHOT
		)
	
	print("Main Controller: Initialized. Waiting for Splash...")

# --- Scene Management ---

func _on_landing_screen_start_game_requested() -> void:
	print("Main Controller: Start request received from Landing Screen.")
	transition_to_main_game()

func transition_to_main_game() -> void:
	print("Main Controller: Commencing transition...")
	
	# Double check that we aren't trying to instantiate ourselves
	if main_game_scene.resource_path == get_tree().current_scene.scene_file_path:
		push_error("CRITICAL: main_game_scene is pointing to the Main scene itself!")
		return

	if is_instance_valid(landing_screen):
		landing_screen.queue_free()
	
	await get_tree().process_frame
	
	# Instantiate the ACTUAL level
	current_game_instance = main_game_scene.instantiate()
	
	# If LandingMain.tscn ALSO has a node named 'Main' inside it, 
	# Godot will throw the error you saw.
	add_child(current_game_instance)
	
	# 1. Clean up existing landing UI/Screen
	if is_instance_valid(landing_screen):
		landing_screen.queue_free()
	
	# Wait a frame to ensure the tree is clean
	await get_tree().process_frame
	
	# 2. Instantiate the level (LevelController)
	current_game_instance = main_game_scene.instantiate()
	
	# 3. Connect signals BEFORE adding to tree to ensure no events are missed
	# These signals must be defined in your LevelController.gd
	if current_game_instance.has_signal("infraction_found"):
		current_game_instance.infraction_found.connect(_on_infraction_discovered)
	
	if current_game_instance.has_signal("penalty_triggered"):
		current_game_instance.penalty_triggered.connect(_on_penalty_received)
	
	# 4. Add the level to the scene tree as a child of Main
	add_child(current_game_instance)
	print("Main Controller: Level loaded and signals connected successfully.")
	
	add_child(current_game_instance)
	hud.show() 
	hud.update_score(total_score)

# --- Gameplay Signal Handlers ---

func _on_infraction_discovered(data: Infraction) -> void:
	# SUCCESS: Player correctly identified a safety violation
	total_score += data.point_value
	infractions_found.append(data.infraction_name)
	
	print("LOGIC: Success! '%s' identified. +%d pts. Total: %d" % [data.infraction_name, data.point_value, total_score])
	
	# Update HUD visuals
	hud.update_score(total_score)
	hud.display_infraction_msg(data.infraction_name, data.point_value)
	
	print("HUD Updated: +", data.point_value)

func _on_penalty_received() -> void:
	# PENALTY: Player clicked the environment (Layer 1) instead of an infraction
	total_score -= 50 # Deduct points for a 'false alarm'
	print("LOGIC: Penalty! Misidentified infraction. -50 pts. Total: %d" % total_score)
	
	# Update HUD visuals
	hud.update_score(total_score)
	hud.display_penalty_msg()
	
	print("HUD Updated: Penalty Applied")

# --- Global Input ---

func _input(event: InputEvent) -> void:
	# Handle Android 'Back' button and Desktop 'ESC' key
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_BACK):
		print("Main Controller: Escape/Back pressed. Quitting application.")
		get_tree().quit()
