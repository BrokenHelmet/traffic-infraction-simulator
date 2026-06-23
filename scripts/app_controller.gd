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
@export var level_scene: PackedScene # Should point to game_level_base.tscn

# Nodes expected to be children of Main in the editor
@export_group("Node References")
@export var level_container: Node3D
@export var splash_screen: Node
@export var landing_screen: Control
@export var hud: CanvasLayer

var game_camera: Node3D

@export_group("Level Configuration")
@export var level_configs: Array[Resource] # The list of levels from your old Main.gd
@export var debug_mode: bool = false       # To keep your debug toggle

# Global Game State - Lives here so it persists when levels change
var current_level_instance: Node = null
var total_score: int = 0
var infractions_found: Array[String] = []

func _ready() -> void:
	# 1. Ensure only the Splash/Landing is visible at launch
	if hud:
		hud.hide()
	
	# 2. Connect the signal from LandingScreen
	# [cite_start]This uses the signal 'start_game_requested' we saw in screen_landing.gd [cite: 10]
	if landing_screen:
		#landing_screen.is_transitioning = true
		landing_screen.start_game_requested.connect(_on_start_game_requested)
	
	print("AppController: Ready. Waiting for Landing Screen signal...")
	
	# Start the introductory splash sequence
	if splash_screen:
		splash_screen.start_splash()
		
		# Connect splash completion using a lambda for brevity
		splash_screen.splash_completed.connect(
			func(): if landing_screen: landing_screen.is_transitioning = false,
			CONNECT_ONE_SHOT
		)
	
	print("Main Controller: Initialized. Waiting for Splash...")

#region --- Scene Management ---

func transition_to_main_game() -> void:
	print("AppController: Commencing transition...")
	
	if not level_scene:
		push_error("AppController: level_scene is null!")
		return

	# Clean up existing landing UI/Screen
	if is_instance_valid(landing_screen):
		landing_screen.queue_free()
		landing_screen = null
	
	# Wait a frame to ensure the tree is clean
	await get_tree().process_frame
	
	# Instantiate the ACTUAL level
	current_level_instance = level_scene.instantiate()
	
	# Add the level to the level_container
	if level_container:
		level_container.add_child(current_level_instance)
	else:
		add_child(current_level_instance)
		
	print("AppController: Level loaded and signals connected successfully.")
	
	_setup_level_signals(current_level_instance)
		
	if hud:
		hud.show() 
		hud.update_score(total_score)

func _setup_level_signals(level_node: Node) -> void:
	# Find the Gameplay Manager inside the level
	var gameplay_manager: Node = level_node.get_node_or_null("GameplayManager")
	if gameplay_manager:
		if gameplay_manager.has_signal("session_complete"):
			gameplay_manager.session_complete.connect(_on_session_complete)
		if gameplay_manager.has_signal("level_completed"):
			gameplay_manager.level_completed.connect(_on_level_session_complete)
		print("AppController: Connection to GameplayManager established.")

func _on_start_game_requested() -> void:
	print("AppController: Signal received. Starting transition...")
	transition_to_main_game()

#endregion

# region --- High-Level Handlers ---

func _on_level_session_complete(success: bool) -> void:
	print("AppController: Level session complete. Success: ", success)
	# Logic for level completion summary can go here

func _on_session_complete(summary: Dictionary) -> void:
	var final_score: int = summary.get("score", 0)
	total_score += final_score
	
	print("AppController: Session ended. Final Level Score: ", final_score)
	print("AppController: Global Total Score: ", total_score)
	
# endregion


#endregion

#region --- Global Input ---

func _input(event: InputEvent) -> void:
	# Handle Android 'Back' button and Desktop 'ESC' key
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_BACK):
		print("Main Controller: Escape/Back pressed. Quitting application.")
		get_tree().quit()

#endregion
