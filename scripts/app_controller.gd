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

func _on_landing_screen_start_game_requested() -> void:
	print("Main Controller: Start request received from Landing Screen.")
	transition_to_main_game()

func transition_to_main_game() -> void:
	print("Main Controller: Commencing transition...")
	
	# Double check that we aren't trying to instantiate ourselves
	if level_scene.resource_path == get_tree().current_scene.scene_file_path:
		push_error("CRITICAL: main_game_scene is pointing to the Main scene itself!")
		return

	if is_instance_valid(landing_screen):
		landing_screen.queue_free()
	
	await get_tree().process_frame
	
	## Instantiate the ACTUAL level
	#current_level_instance = level_scene.instantiate()
	#
	## If LandingMain.tscn ALSO has a node named 'Main' inside it, 
	## Godot will throw the error you saw.
	#add_child(current_level_instance)
	
	# 1. Clean up existing landing UI/Screen
	if is_instance_valid(landing_screen):
		landing_screen.queue_free()
	
	# Wait a frame to ensure the tree is clean
	await get_tree().process_frame
	
	# 2. Instantiate the level (LevelController)
	current_level_instance = level_scene.instantiate()
	
	# 4. Add the level to the scene tree as a child of Main
	add_child(current_level_instance)
	print("Main Controller: Level loaded and signals connected successfully.")
	
	# =============================================================================
	# NODE ADOPTION LOGIC
	# =============================================================================
	# Ensures the new level instance is an 'orphan' before adding it to Main.
	# This prevents "already has a parent" or "already in tree" errors.
	# =============================================================================

	# 1. Check if the instance even exists
	if is_instance_valid(current_level_instance):
		
		# 2. Check if the level is already a child of Main to avoid duplicates
		if not is_ancestor_of(current_level_instance):
			
			# 3. If it has a parent elsewhere, remove it first (Safe Orphan)
			if current_level_instance.get_parent():
				current_level_instance.get_parent().remove_child(current_level_instance)
			
			# 4. Finally, add it to the Main scene tree
			add_child(current_level_instance)
			print("Main: Successfully added level instance: ", current_level_instance.name)
		else:
			print("Main: Level is already a child, skipping add_child.")
		
	hud.show() 
	hud.update_score(total_score)
	
func _on_start_game_requested() -> void:
	print("AppController: Signal received. Starting transition...")
	_transition_to_gameplay()

# region --- Level Lifecycle ---

# This function is called once the Landing Screen is gone
func _transition_to_gameplay() -> void:
	if is_instance_valid(landing_screen):
		landing_screen.queue_free()
	
	await get_tree().process_frame
	
	#if level_scene:
		#current_level_instance = level_scene.instantiate()
		#level_container.add_child(current_level_instance)
		#
		## --- THE HANDOVER ---
		## Look for the First Mate (GameplayManager) inside the new level
		## Note: Ensure the node inside game_level_base.tscn is named "GameplayManager"
		#var gameplay_mgr = current_level_instance.get_node_or_null("GameplayManager")
		#
		#if gameplay_mgr:
			## The Captain ONLY listens for the end-of-session report
			#gameplay_mgr.level_completed.connect(_on_level_session_complete)
			#print("AppController: Connection to GameplayManager established.")
		#
		#if hud:
			#hud.show()
	#else:
		#push_error("AppController: No level_scene assigned in Inspector!")

# endregion

# region --- High-Level Handlers ---

func _on_level_session_complete(summary: Dictionary) -> void:
	var final_score = summary.get("score", 0)
	total_score += final_score
	
	print("AppController: Session ended. Final Level Score: ", final_score)
	print("AppController: Global Total Score: ", total_score)
	
	# Future: Show a summary screen or return to menu
	
# endregion

# app_controller.gd
func _on_level_instantiated(level_node):
	# Find the Gameplay Manager inside the level
	var gameplay_manager = level_node.get_node("GameplayManager")

	# The Captain only listens for the END of the mission
	gameplay_manager.session_complete.connect(_on_session_complete)

func _on_session_complete(summary: Dictionary):
	print("Captain: Level finished. Final Score: ", summary["score"])
	# Here is where the Captain does the 'Macro' work:
	# Save to leaderboard, unlock next level, etc.

#endregion

#region --- Global Input ---

func _input(event: InputEvent) -> void:
	# Handle Android 'Back' button and Desktop 'ESC' key
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_BACK):
		print("Main Controller: Escape/Back pressed. Quitting application.")
		get_tree().quit()

#endregion
