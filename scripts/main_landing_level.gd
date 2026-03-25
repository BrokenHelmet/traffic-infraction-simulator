extends Node2D

# =============================================================================
# MAIN GAME CONTROLLER
# =============================================================================
# Central coordinator for the Traffic Control Simulator
# Handles level loading, configuration management, and game flow
# 
# TODO: Implement level progression system
# TODO: Add save/load functionality for player progress
# TODO: Create main menu and level selection UI
# TODO: Add scoring system integration
# =============================================================================


var current_level_config: Resource  # Can hold any resource type
var current_level

@export var level_configs: Array[Resource] # An array to hold your PackedScene level sections


# Config testing system
var config_test_panel: Control
var config_test_visible: bool = false
var available_configs: Array[Resource]

@onready var start_game_button: Button = $"UI Menu/StartGameButton"

# Level selection menu (now scene-based)
var level_selection_menu: Control
var level_selection_visible: bool = false

# Version display
var version_label: Label
@export var version_font_size: int = 16  # Adjustable font size for version display

# Config debug display
var config_debug_label: Label

# Camera debug display
var camera_debug_label: Label

# Camera rig control (newer system)
@export var camera_rig: Node3D  # Reference to CameraRig in level scene

# Timer system control
var game_timer: Control  # Reference to GameTimer in UI
var start_countdown: Control  # Reference to StartCountdown in UI
var level_over: Control  # Reference to LevelOver popup in UI

# Scoring system control
var score_manager: Node  # ScoreManager for "Time is Money" scoring
var score_display: Control  # ScoreDisplay UI for real-time scoring

# Game management system
var game_manager: Node

# Pause system
var pause_manager: PauseManager

# Navigation system
var pause_button: Button
var is_level_loaded: bool = false

# Debug settings
@export_group("Debug Settings")
@export var debug_mode: bool = false            # Enable all debug logging
@export var debug_ui: bool = false              # Enable UI creation debug output
@export var debug_level: bool = false           # Enable level loading debug output
@export var debug_camera: bool = false          # Enable camera system debug output
@export var debug_config: bool = false          # Enable config system debug output
@export var debug_timer: bool = false            # Enable timer system debug output
@export var debug_scoring: bool = false          # Enable scoring system debug output
@export var debug_game: bool = false             # Enable game manager debug output
@export var debug_font_size: int = 14

func _ready():
	# Get reference to PauseManager
	pause_manager = get_node_or_null("PauseManager")
		
	set_camera_rig_enabled(false)
	
		
	if not pause_manager:
		debug_print("WARNING: PauseManager not found", "ui")
	
	# Create and display version label
	create_version_display()
	
	# Setup level selection menu (scene-based)
	_setup_level_selection_menu()
	
	# Create config testing panel
	create_config_test_panel()
	
	# Create pause button (hidden initially)
	create_pause_button()
	
	# Connect pause overlay signals
	connect_pause_overlay_signals()
	
	# Handle Android back button input
	if OS.get_name() == "Android":
		debug_print("Android detected - back button will quit app")

func create_version_display():
	# Only create debug labels if debugging is enabled
	if not (debug_mode or debug_ui or debug_config):
		return
	
	debug_print("Creating version and config debug displays", "ui")
	
	# Create version label
	version_label = Label.new()
	version_label.text = "v" + ProjectSettings.get_setting("application/config/version", "1.01")
	version_label.position = Vector2(10, 10)
	version_label.add_theme_color_override("font_color", Color.WHITE)
	version_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	version_label.add_theme_constant_override("shadow_offset_x", 1)
	version_label.add_theme_constant_override("shadow_offset_y", 1)
	version_label.add_theme_font_size_override("font_size", version_font_size)
	version_label.z_index = 100  # Ensure it's on top
	
	# Add to scene
	add_child(version_label)
	debug_print("Version display added: " + version_label.text + " (Font size: " + str(version_font_size) + ")", "ui")
	
	# Create config debug label
	config_debug_label = Label.new()
	config_debug_label.text = "Config: None Loaded"
	config_debug_label.position = Vector2(10, 50)  # Below version label
	config_debug_label.add_theme_color_override("font_color", Color.CYAN)
	config_debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	config_debug_label.add_theme_constant_override("shadow_offset_x", 1)
	config_debug_label.add_theme_constant_override("shadow_offset_y", 1)
	config_debug_label.add_theme_font_size_override("font_size", version_font_size)
	config_debug_label.z_index = 100  # Ensure it's on top
	
	# Add to scene
	add_child(config_debug_label)
	debug_print("Config debug label added", "ui")

# Connect pause overlay signals for restart and menu actions
func connect_pause_overlay_signals():
	var pause_overlay = get_node_or_null("UI Menu/PauseOverlay")
	if pause_overlay:
		if pause_overlay.has_signal("restart_requested"):
			pause_overlay.restart_requested.connect(_on_pause_restart_requested)
			debug_print("PauseOverlay restart signal connected", "ui")
		if pause_overlay.has_signal("menu_requested"):
			pause_overlay.menu_requested.connect(_on_pause_menu_requested)
			debug_print("PauseOverlay menu signal connected", "ui")
	else:
		debug_print("PauseOverlay not found for signal connection", "ui")

# Handle pause overlay restart request
func _on_pause_restart_requested():
	debug_print("Pause menu: Restart level requested")
	_on_level_retry_requested()

# Handle pause overlay menu request  
func _on_pause_menu_requested():
	debug_print("Pause menu: Return to menu requested")
	_on_return_to_menu_pressed()

func _input(event):
	# Handle Android back button and escape key
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
			# If a level is loaded, return to menu instead of quitting
			if is_level_loaded:
				debug_print("Back button pressed - returning to main menu")
				_on_return_to_menu_pressed()
			else:
				debug_print("Back button pressed - quitting application")
				get_tree().quit()
		# Toggle config test panel with T key
		elif event.keycode == KEY_T:
			toggle_config_test_panel()

# TODO: Replace hardcoded level loading with dynamic system
# TODO: Add level selection UI instead of single button
# TODO: Implement level progression (unlock system)
func _on_start_game_button_pressed() -> void:
	debug_print("Loading level...", "level")
	
	# TODO: Replace hardcoded config path with level-specific configs
	# TODO: Use level_configs array instead of fixed path
	var config_path = "res://configs/levels/test_config.tres"
	debug_print("Attempting to load test config: " + config_path, "level")
	
	# Load the working level config
	var config_resource = ResourceLoader.load(config_path)
	
	if config_resource and config_resource.has_method("print_config"):
		debug_print("SUCCESS: Loaded working level config!", "level")
		if debug_mode or debug_config:
			config_resource.print_config()
		set_level_config(config_resource) # Use set_level_config to update debug label
	else:
		debug_print("FAILED: Could not load the level config", "level")

func _load_level(_new_lvl) -> void:
	current_level = _new_lvl
	
	debug_print("Loaded level: " + _new_lvl.name, "level")
	
	# Validate level configuration 
	if current_level_config and current_level_config.has_method("is_valid") and current_level_config.is_valid():
		debug_print("✅ Level loaded with valid configuration", "level")
	else:
		debug_print("⚠️  Warning: No valid level configuration found", "level")
	
	if get_tree().current_scene.get("level_container") != null:
		get_tree().current_scene.level_container.add_child(current_level)
	else:
		get_tree().current_scene.add_child(current_level)
	
	# Show pause button now that level is loaded
	show_pause_button()
	
	# Detect CameraRig in the loaded level
	detect_camera_rig(_new_lvl)
	
	# Initialize timer system
	initialize_timer_system()
	
	# Initialize scoring system
	initialize_scoring_system()
	
	# Initialize GameManager for vehicle spawning and gameplay
	initialize_game_manager(_new_lvl)
	
	# Wait for all systems to be ready, then start level sequence
	await get_tree().process_frame
	start_level_sequence()
	
	# Camera system is now handled by CameraRig in the loaded level
	
# Camera movement is now handled by CameraRig system in loaded levels

# Helper function to get the current level configuration
func get_level_config():
	return current_level_config

# Helper function to set a new level configuration  
func set_level_config(new_config):
	current_level_config = new_config
	if current_level_config and current_level_config.has_method("is_valid") and current_level_config.is_valid():
		debug_print("Level configuration updated successfully", "config")
		if current_level_config.has_method("print_config") and (debug_mode or debug_config):
			current_level_config.print_config()
		
		# Update config debug label
		if config_debug_label and current_level_config.has_method("get"):
			var config_name = "Unknown"
			if current_level_config.has_method("get") and "level_name" in current_level_config:
				config_name = current_level_config.level_name
			config_debug_label.text = "Config: " + config_name
			config_debug_label.add_theme_color_override("font_color", Color.LIME_GREEN)
	else:
		debug_print("Warning: Invalid level configuration provided", "config")
		if config_debug_label:
			config_debug_label.text = "Config: INVALID"
			config_debug_label.add_theme_color_override("font_color", Color.RED)

# Function to create a default level configuration
func create_default_level_config():
	# Load the script directly to avoid class registration issues
	var LevelConfigScript = load("res://scripts/LevelConfig.gd")
	var config = LevelConfigScript.new()
	return config

# =============================================================================
# CAMERA RIG CONTROL (Newer System)
# =============================================================================

# Detect CameraRig in the loaded level scene
func detect_camera_rig(level_scene: Node):
	# Search for CameraRig node in the level scene
	camera_rig = find_camera_rig_recursive(level_scene)
	
	if camera_rig:
		debug_print("CameraRig detected: " + str(camera_rig.get_path()), "camera")
		# Initially hide CameraRig UI if level selection is visible
		if level_selection_visible:
			set_camera_rig_ui_visible(false)
	else:
		debug_print("No CameraRig found in level scene", "camera")

# Recursively search for CameraRig node
func find_camera_rig_recursive(node: Node) -> Node3D:
	# Check if this node is a CameraRig (has the script or name)
	if node.name == "CameraRig" or (node.get_script() and str(node.get_script()).contains("CameraRig")):
		return node as Node3D
	
	# Search children
	for child in node.get_children():
		var result = find_camera_rig_recursive(child)
		if result:
			return result
	
	return null

# Control CameraRig UI visibility (hide buttons when level selection is open)
func set_camera_rig_ui_visible(show_ui: bool):
	if not camera_rig or not camera_rig.has_method("set_ui_visible"):
		return
	
	camera_rig.set_ui_visible(show_ui)
	debug_print("CameraRig UI visibility set to " + str(show_ui), "camera")

# Enable or disable the entire CameraRig system
func set_camera_rig_enabled(enabled: bool):
	if not camera_rig:
		camera_rig = find_camera_rig_recursive(self)
	
	if not camera_rig or not camera_rig.has_method("set_camera_rig_enabled"):
		return
	
	camera_rig.set_camera_rig_enabled(enabled)
	debug_print("CameraRig system " + ("enabled" if enabled else "disabled"), "camera")

# Get reference to CameraRig
func get_camera_rig() -> Node3D:
	return camera_rig

# Cleanup CameraRig reference
func cleanup_camera_rig():
	camera_rig = null
	debug_print("CameraRig reference cleared", "camera")

# =============================================================================
# TIMER SYSTEM MANAGEMENT
# =============================================================================

# Initialize timer system for level gameplay
func initialize_timer_system():
	debug_print("Initializing timer system...", "timer")
	
	# Create and setup timer components
	create_timer_components()
	
	# Connect timer signals
	connect_timer_signals()
	
	# Configure timer based on level config
	configure_timer_from_level_config()
	
	# Hide timer UI if level selection is visible
	if level_selection_visible:
		set_timer_ui_visible(false)
	
	debug_print("Timer system initialized", "timer")

# Create timer UI components
func create_timer_components():
	# Load timer scenes
	var game_timer_scene = load("res://scenes/ui/GameTimer.tscn")
	var start_countdown_scene = load("res://scenes/ui/StartCountdown.tscn")
	var level_over_scene = load("res://scenes/ui/LevelOver.tscn")
	
	# Create instances
	if game_timer_scene:
		game_timer = game_timer_scene.instantiate()
		game_timer.name = "GameTimer"
		get_node("UI Menu").add_child(game_timer)
		debug_print("GameTimer created", "timer")
	
	if start_countdown_scene:
		start_countdown = start_countdown_scene.instantiate()
		start_countdown.name = "StartCountdown"
		get_node("UI Menu").add_child(start_countdown)
		debug_print("StartCountdown created", "timer")
	
	if level_over_scene:
		level_over = level_over_scene.instantiate()
		level_over.name = "LevelOver"
		get_node("UI Menu").add_child(level_over)
		debug_print("LevelOver created", "timer")

# Connect timer system signals
func connect_timer_signals():
	if game_timer and game_timer.has_signal("timer_expired"):
		game_timer.timer_expired.connect(_on_timer_expired)
		game_timer.timer_warning.connect(_on_timer_warning)
		debug_print("GameTimer signals connected", "timer")
	
	if start_countdown and start_countdown.has_signal("countdown_completed"):
		start_countdown.countdown_completed.connect(_on_countdown_completed)
		debug_print("StartCountdown signals connected", "timer")
	
	if level_over:
		level_over.retry_requested.connect(_on_level_retry_requested)
		level_over.continue_requested.connect(_on_level_continue_requested)
		debug_print("LevelOver signals connected", "timer")

# Configure timer based on level configuration
func configure_timer_from_level_config():
	if not current_level_config or not current_level_config.has_method("has_time_limit"):
		debug_print("No level config or time limit support", "timer")
		return
	
	if current_level_config.has_time_limit():
		var time_limit = current_level_config.get_time_limit()
		debug_print("Level has time limit: " + str(current_level_config.get_formatted_time_limit()), "timer")
		
		if game_timer and game_timer.has_method("set_timer_enabled"):
			game_timer.set_timer_enabled(true)
			# Timer will be started after countdown completes
	else:
		debug_print("Level has no time limit - timer disabled", "timer")
		if game_timer and game_timer.has_method("set_timer_enabled"):
			game_timer.set_timer_enabled(false)

# Start the level sequence (countdown -> timer -> gameplay)
func start_level_sequence():
	debug_print("Starting level sequence...", "timer")
	
	# Initialize all gameplay UI as hidden before starting
	hide_all_gameplay_ui()
	
	# Start with countdown
	if start_countdown and start_countdown.has_method("start_countdown"):
		start_countdown.start_countdown()
	else:
		# Fallback - start directly
		_on_countdown_completed()

# Set timer UI visibility (for level selection integration)
func set_timer_ui_visible(show_ui: bool):
	if game_timer and game_timer.has_method("set_timer_visible"):
		game_timer.set_timer_visible(show_ui)
	
	if not show_ui:
		# Also hide other timer components when hiding
		if start_countdown:
			start_countdown.visible = false
		if level_over:
			level_over.visible = false
	
	debug_print("Timer UI visibility set to " + str(show_ui), "timer")

# Get game statistics for end-of-level reporting
func get_game_statistics() -> Dictionary:
	var stats = {
		"vehicles_passed": 0,
		"collisions": 0,
		"score": 0
	}
	
	# Get stats from GameManager if available
	if game_manager and game_manager.has_method("get_statistics"):
		stats = game_manager.get_statistics()
	
	return stats

# Cleanup timer system
func cleanup_timer_system():
	if game_timer:
		if game_timer.has_method("stop_timer"):
			game_timer.stop_timer()
		game_timer.queue_free()
		game_timer = null
	
	if start_countdown:
		if start_countdown.has_method("stop_countdown"):
			start_countdown.stop_countdown()
		start_countdown.queue_free()
		start_countdown = null
	
	if level_over:
		level_over.queue_free()
		level_over = null
	
	debug_print("Timer system cleaned up", "timer")

# =============================================================================
# UI STATE MANAGEMENT
# =============================================================================

# Hide all gameplay UI elements (called before level starts and when pausing)
func hide_all_gameplay_ui():
	debug_print("Hiding all gameplay UI", "ui")
	
	# Hide camera controls and disable input
	if camera_rig:
		if camera_rig.has_method("set_ui_visible"):
			camera_rig.set_ui_visible(false)
		if camera_rig.has_method("set_input_enabled"):
			camera_rig.set_input_enabled(false)
		debug_print("Camera UI hidden and input disabled", "ui")
	
	# Hide timer (but keep running)
	if game_timer:
		game_timer.visible = false
		debug_print("Timer hidden", "ui")
	
	# Hide score display (but keep tracking)
	if score_display:
		score_display.visible = false
		debug_print("Score display hidden", "ui")
	
	# Hide pause button
	hide_pause_button()

# Show all gameplay UI elements (called when gameplay starts)
func show_all_gameplay_ui():
	debug_print("Showing all gameplay UI", "ui")
	
	# Show camera controls and enable input
	if camera_rig:
		if camera_rig.has_method("set_ui_visible"):
			camera_rig.set_ui_visible(true)
		if camera_rig.has_method("set_input_enabled"):
			camera_rig.set_input_enabled(true)
		debug_print("Camera UI shown and input enabled", "ui")
	
	# Show timer
	if game_timer:
		game_timer.visible = true
		debug_print("Timer shown", "ui")
	
	# Show score display
	if score_display:
		score_display.visible = true
		debug_print("Score display shown", "ui")
	
	# Show pause button
	show_pause_button()

# =============================================================================
# SCORING SYSTEM MANAGEMENT
# =============================================================================

# Initialize scoring system for level gameplay
func initialize_scoring_system():
	debug_print("Initializing scoring system...", "scoring")
	
	# Create ScoreManager
	create_score_manager()
	
	# Create ScoreDisplay UI
	create_score_display()
	
	# Connect scoring system to timer signals for level completion
	connect_scoring_signals()
	
	# Configure scoring based on level config
	configure_scoring_from_level_config()
	
	# Hide scoring UI if level selection is visible
	if level_selection_visible:
		set_scoring_ui_visible(false)
	
	debug_print("Scoring system initialized", "scoring")

# Create ScoreManager instance
func create_score_manager():
	# Load and create ScoreManager
	var ScoreManagerScript = load("res://scripts/infraction_score_manager.gd")
	score_manager = ScoreManagerScript.new()
	score_manager.name = "ScoreManager"
	score_manager.debug_scoring = true
	score_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Add to scene tree
	add_child(score_manager)
	
	# Add to group for easy discovery
	score_manager.add_to_group("score_manager")
	
	debug_print("ScoreManager created and added to group", "scoring")

# Create scoring display UI
func create_score_display():
	# Load ScoreDisplay scene
	var score_display_scene = load("res://scenes/ui/ScoreDisplay.tscn")
	
	# Create instance
	if score_display_scene:
		score_display = score_display_scene.instantiate()
		score_display.name = "ScoreDisplay"
		get_node("UI Menu").add_child(score_display)
		debug_print("ScoreDisplay created", "scoring")
	else:
		debug_print("WARNING - Could not load ScoreDisplay scene", "scoring")

# Connect scoring system signals
func connect_scoring_signals():
	if score_manager and score_manager.has_signal("round_completed"):
		score_manager.round_completed.connect(_on_scoring_level_completed)
		debug_print("ScoreManager signals connected", "scoring")

# Configure scoring system based on level configuration
func configure_scoring_from_level_config():
	if not current_level_config:
		debug_print("No level config for scoring system", "scoring")
		return
	
	if score_manager and score_manager.has_method("initialize_round"):
		score_manager.initialize_round()
		debug_print("Scoring configured from level config", "scoring")
	else:
		debug_print("WARNING - ScoreManager not available for configuration", "scoring")

# Set scoring UI visibility (for level selection integration)
func set_scoring_ui_visible(show_ui: bool):
	if score_display:
		score_display.visible = show_ui
	debug_print("Scoring UI visibility set to " + str(show_ui), "scoring")

# Handle scoring level completion (success or failure)
func _on_scoring_level_completed(success: bool, final_score: int, stars: int):
	debug_print("Scoring level completion - Success: " + str(success) + ", Score: " + str(final_score) + ", Stars: " + str(stars), "scoring")
	
	# Disable gameplay active flag
	if pause_manager and pause_manager.has_method("set_gameplay_active"):
		pause_manager.set_gameplay_active(false)
		debug_print("Gameplay active flag disabled", "scoring")
	
	# Stop game systems
	if game_manager and game_manager.has_method("stop_level"):
		game_manager.stop_level()
	
	# Stop timer system
	if game_timer and game_timer.has_method("stop_timer"):
		game_timer.stop_timer()
	
	# Get final statistics including scoring
	var game_stats = get_game_statistics()
	game_stats["final_score"] = final_score
	game_stats["stars_earned"] = stars
	game_stats["completion_success"] = success
	
	# Show appropriate completion popup
	if level_over:
		if success:
			if level_over.has_method("show_level_completed"):
				level_over.show_level_completed(game_stats)
			else:
				# Fallback method
				level_over.visible = true
		else:
			if level_over.has_method("show_level_failed"):
				level_over.show_level_failed(game_stats)
			else:
				# Fallback - treat as time expired
				if level_over.has_method("show_time_expired"):
					level_over.show_time_expired({}, game_stats)

# Check timer expiration against scoring requirements
func _on_timer_expired_with_scoring():
	debug_print("Timer expired - checking scoring completion requirements", "timer")
	
	# Let scoring system determine if level failed or succeeded
	if score_manager and score_manager.has_method("check_level_failure"):
		score_manager.check_time_expired()
	else:
		# Fallback to original timer expiration behavior
		_on_timer_expired()

# Cleanup scoring system
func cleanup_scoring_system():
	if score_display:
		score_display.queue_free()
		score_display = null
	
	if score_manager:
		score_manager.queue_free()
		score_manager = null
	
	debug_print("Scoring system cleaned up", "scoring")

# =============================================================================
# TIMER EVENT HANDLERS
# =============================================================================

# Handle countdown completion - start the actual gameplay timer
func _on_countdown_completed():
	debug_print("Countdown completed - starting gameplay timer", "timer")
	
	# Enable gameplay active flag for pause on focus loss
	if pause_manager and pause_manager.has_method("set_gameplay_active"):
		pause_manager.set_gameplay_active(true)
		set_camera_rig_enabled(true)
		debug_print("Gameplay active flag enabled", "timer")
	
	# Show all gameplay UI now that level has started
	show_all_gameplay_ui()
	
	if game_timer and current_level_config and current_level_config.has_method("has_time_limit"):
		if current_level_config.has_time_limit():
			var time_limit = current_level_config.get_time_limit()
			game_timer.start_timer(time_limit)
			debug_print("Gameplay timer started with " + str(time_limit) + " seconds", "timer")
	
	# Start vehicle spawning and other game systems
	if game_manager and game_manager.has_method("start_level"):
		game_manager.start_level()

# Handle timer expiration - end the level
func _on_timer_expired():
	debug_print("Timer expired - ending level", "timer")
	
	# Disable gameplay active flag
	if pause_manager and pause_manager.has_method("set_gameplay_active"):
		pause_manager.set_gameplay_active(false)
		set_camera_rig_enabled(false)
		debug_print("Gameplay active flag disabled", "timer")
	
	# Stop game systems
	if game_manager and game_manager.has_method("stop_level"):
		game_manager.stop_level()
	
	# Get final statistics
	var timer_stats = {}
	if game_timer and game_timer.has_method("get_timer_stats"):
		timer_stats = game_timer.get_timer_stats()
	
	var game_stats = get_game_statistics()
	
	# Show time expired popup
	if level_over and level_over.has_method("show_time_expired"):
		level_over.show_time_expired(timer_stats, game_stats)

# Handle timer warnings (30 seconds, 10 seconds remaining)
func _on_timer_warning(seconds_remaining: int):
	debug_print("Timer warning - " + str(seconds_remaining) + " seconds remaining", "timer")
	# Could add sound effects or visual warnings here

# Handle level retry request
func _on_level_retry_requested():
	debug_print("Level retry requested", "timer")
	
	# Reset gameplay active flag before restart
	if pause_manager and pause_manager.has_method("set_gameplay_active"):
		pause_manager.set_gameplay_active(false)
		set_camera_rig_enabled(false)
		debug_print("Gameplay active flag reset for retry", "timer")
	
	# Restart current level
	if current_level_config:
		# Reset timer and restart level sequence
		if game_timer and game_timer.has_method("reset_timer"):
			game_timer.reset_timer()
		
		# Restart game systems
		if game_manager and game_manager.has_method("restart_level"):
			game_manager.restart_level()
		else:
			# Fallback - reinitialize
			await cleanup_game_manager()
			#var current_scene = get_tree().current_scene.get_children().filter(func(child): return child.name.contains("Tutorial") or child.name.contains("Level"))
			if current_level != null:
				initialize_game_manager(current_level)
		
		# Restart level sequence
		start_level_sequence()

# Handle level continue request
func _on_level_continue_requested():
	debug_print("Level continue requested", "timer")
	# Return to menu for now (could implement next level logic later)
	_on_return_to_menu_pressed()

# =============================================================================
# GAME MANAGEMENT SYSTEM
# =============================================================================

# Initialize GameManager for vehicle spawning and gameplay mechanics
func initialize_game_manager(level_scene: Node):
	# Remove existing GameManager if present
	if game_manager:
		game_manager.queue_free()
		game_manager = null
	
	# Create new GameManager instance
	var GameManagerScript = load("res://scripts/gameplay_manager.gd")
	game_manager = GameManagerScript.new()
	game_manager.name = "GameManager"
	game_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Add to scene tree
	add_child(game_manager)
	
	# Initialize with current level config and scene
	if current_level_config and current_level_config.has_method("is_valid") and current_level_config.is_valid():
		debug_print("🎮 Initializing GameManager with level config...", "game")
		game_manager.initialize_level(current_level_config, level_scene)
	else:
		debug_print("⚠️  Warning: Invalid level config, GameManager initialized without config", "game")
		game_manager.initialize_level(null, level_scene)

# Get reference to current GameManager
func get_game_manager() -> Node:
	return game_manager

# Cleanup GameManager when changing levels  
func cleanup_game_manager():
	if game_manager:
		# Stop the level first to properly cleanup vehicles
		if game_manager.has_method("stop_level"):
			debug_print("Stopping current level and cleaning up vehicles...", "game")
			game_manager.stop_level()
			# Wait a frame for vehicles to be properly queued for deletion
			await get_tree().process_frame
		
		# Additional cleanup method if it exists
		if game_manager.has_method("cleanup"):
			game_manager.cleanup()
			
		game_manager.queue_free()
		game_manager = null
		debug_print("GameManager cleanup completed", "game")

# =============================================================================
# PAUSE BUTTON SYSTEM
# =============================================================================

func create_pause_button():
	# Create the pause button
	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "⏸ PAUSE"
	pause_button.visible = false  # Hidden initially
	pause_button.z_index = 45  # Above other UI elements
	
	# Style the button
	pause_button.add_theme_font_size_override("font_size", 36)
	pause_button.add_theme_color_override("font_color", Color.WHITE)
	pause_button.add_theme_color_override("font_hover_color", Color.YELLOW)
	pause_button.add_theme_color_override("font_pressed_color", Color.ORANGE)
	pause_button.custom_minimum_size = Vector2(250, 80)
	
	# Position in top-right corner
	pause_button.anchors_preset = Control.PRESET_TOP_RIGHT
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.anchor_top = 0.0
	pause_button.anchor_bottom = 0.0
	pause_button.offset_left = -270  # 250 width + 20 margin
	pause_button.offset_top = 20
	pause_button.offset_right = -20
	pause_button.offset_bottom = 100
	
	# Connect to pause function
	pause_button.pressed.connect(_on_pause_button_pressed)
	
	# Add to UI Menu layer
	var ui_menu = get_node("UI Menu")
	ui_menu.add_child(pause_button)
	
	debug_print("Pause button created and positioned", "ui")

# Show pause button (called when level loads)
func show_pause_button():
	if pause_button:
		pause_button.visible = true
		debug_print("Pause button shown", "ui")

# Hide pause button (called when returning to menu)
func hide_pause_button():
	if pause_button:
		pause_button.visible = false
		debug_print("Pause button hidden", "ui")

# Handle pause button press
func _on_pause_button_pressed():
	if pause_manager:
		pause_manager._toggle_pause()

func _on_return_to_menu_pressed():
	debug_print("=== RETURNING TO MAIN MENU ===")
	
	# Cleanup current level and systems
	cleanup_current_level()
	
	# Reset the menu state
	reset_menu_state()
	
	debug_print("Returned to main menu - ready for level selection")

func cleanup_current_level():
	debug_print("Cleaning up current level...")
	
	# Reset gameplay active flag
	if pause_manager and pause_manager.has_method("set_gameplay_active"):
		pause_manager.set_gameplay_active(false)
		set_camera_rig_enabled(false)
		debug_print("Gameplay active flag reset", "level")
	
	# Cleanup camera systems
	cleanup_camera_rig()
	
	# Cleanup timer system
	cleanup_timer_system()
	
	# Cleanup scoring system
	cleanup_scoring_system()
	
	# Cleanup game manager (this will stop spawning and remove tracked vehicles)
	await cleanup_game_manager()
	
	# Additional comprehensive vehicle cleanup - remove any remaining vehicles
	await cleanup_all_vehicles()
	
	# Remove any loaded level scenes
	#var current_scene = get_tree().current_scene
	#for child in current_scene.get_children():
		## Remove level scene children (keep core components like Main)
		#if child.name.contains("Tutorial") or child.name.contains("Level") or child.name.contains("Intersection") or child.name.contains("Path"):
			#debug_print("Removing level scene: " + child.name, "level")
			#child.queue_free()
	current_level.queue_free()
	current_level = null
	
	# Clear level config
	current_level_config = null
	if config_debug_label:
		config_debug_label.text = "Config: None Loaded"
		config_debug_label.add_theme_color_override("font_color", Color.CYAN)
	
	is_level_loaded = false
	debug_print("Level cleanup completed", "level")

func cleanup_all_vehicles():
	"""Comprehensive cleanup of all vehicles in the scene tree"""
	debug_print("Starting comprehensive vehicle cleanup...", "game")
	var vehicles_removed = 0
	
	# Search through all nodes in the scene tree to find and remove vehicles
	var current_scene = get_tree().current_scene
	vehicles_removed += _remove_vehicles_recursive(current_scene)
	
	# Also check the main node's direct children
	vehicles_removed += _remove_vehicles_recursive(self)
	
	# Wait a frame to allow all queue_free() calls to be processed
	await get_tree().process_frame
	
	# Force garbage collection to clear up memory
	if vehicles_removed > 0:
		debug_print("Removed " + str(vehicles_removed) + " vehicles from scene", "game")
		# Give additional time for cleanup
		await get_tree().process_frame
	else:
		debug_print("No additional vehicles found to clean up", "game")

func _remove_vehicles_recursive(node: Node) -> int:
	"""Recursively search and remove vehicle nodes"""
	var removed_count = 0
	
	for child in node.get_children():
		# Check if this is a vehicle node (CharacterBody3D with vehicle-like properties)
		if _is_vehicle_node(child):
			debug_print("Found and removing vehicle: " + child.name + " (type: " + child.get_class() + ")", "game")
			child.queue_free()
			removed_count += 1
		else:
			# Recursively check children
			removed_count += _remove_vehicles_recursive(child)
	
	return removed_count

func _is_vehicle_node(node: Node) -> bool:
	"""Determine if a node is likely a vehicle that should be cleaned up"""
	# Check if it's a CharacterBody3D (vehicles are CharacterBody3D)
	if not (node is CharacterBody3D):
		return false
	
	# Check for vehicle-specific properties or naming patterns
	var node_name = node.name.to_lower()
	
	# Common vehicle indicators
	if (node_name.contains("vehicle") or 
		node_name.contains("car") or 
		node_name.contains("truck") or 
		node_name.contains("saloon") or
		node.has_method("configure_with_type") or  # GameManager adds this method to vehicles
		"speed" in node or  # Vehicles have speed property
		"path" in node):  # Vehicles have path property for movement
		return true
	
	# Additional check: if it has a PathFollow3D as a child or in its path
	for child in node.get_children():
		if child is PathFollow3D:
			return true
	
	return false

func reset_menu_state():
	debug_print("Resetting menu state...")
	
	# Show the main menu button
	if start_game_button:
		start_game_button.visible = true
		start_game_button.text = "▼ SELECT LEVEL"
	
	# Hide the return to menu button
	if pause_button:
		pause_button.visible = false
	
	# Hide any open panels
	if level_selection_menu and level_selection_visible:
		toggle_level_selection_menu()
	
	if config_test_panel and config_test_visible:
		toggle_config_test_panel()
	
	# NOTE: CameraRig UI not restored here - no level loaded at menu
	# Camera navigation buttons only appear during active gameplay
	
	debug_print("Menu state reset completed")

func show_return_to_menu_button():
	# Show the return to menu button when a level is loaded
	if pause_button:
		pause_button.visible = true
		is_level_loaded = true
		debug_print("Return to menu button shown", "ui")

func hide_return_to_menu_button():
	# Hide the return to menu button
	if pause_button:
		pause_button.visible = false
		is_level_loaded = false
		debug_print("Return to menu button hidden", "ui")

# =============================================================================
# LEVEL SELECTION SYSTEM (Scene-Based)
# =============================================================================

func _setup_level_selection_menu():
	# Load the LevelSelectionMenu scene
	var level_selection_scene = preload("res://scenes/ui/LevelSelectionMenu.tscn")
	level_selection_menu = level_selection_scene.instantiate()
	level_selection_menu.name = "LevelSelectionMenu"
	level_selection_menu.visible = false
	
	# Add to UI Menu layer
	var ui_menu = get_node("UI Menu")
	ui_menu.add_child(level_selection_menu)
	
	# Connect signals from the level selection controller
	if level_selection_menu:
		level_selection_menu.level_selected.connect(_on_level_selected)
		level_selection_menu.menu_closed.connect(_on_level_selection_menu_closed)
		
		# Initialize the controller with level configs
		level_selection_menu.initialize_levels(level_configs)
		debug_print("Level selection menu (scene-based) initialized", "ui")
	else:
		debug_print("Warning: LevelSelectionController not found in scene", "ui")
	
	# Replace the original single button with level selection
	if start_game_button:
		start_game_button.text = "▼ SELECT LEVEL"
		# Disconnect old signal if connected
		if start_game_button.is_connected("pressed", _on_start_game_button_pressed):
			start_game_button.disconnect("pressed", _on_start_game_button_pressed)
		# Connect to new toggle function
		start_game_button.pressed.connect(toggle_level_selection_menu)

func _on_level_selection_menu_closed():
	debug_print("Level selection menu closed", "ui")
	level_selection_visible = false
	# NOTE: CameraRig UI remains hidden until gameplay starts (after countdown)
	# It will be shown by show_all_gameplay_ui() when countdown completes
	# Restore Timer UI visibility when menu is closed  
	set_timer_ui_visible(true)


func toggle_level_selection_menu():
	level_selection_visible = !level_selection_visible
	if level_selection_menu:
		level_selection_menu.visible = level_selection_visible
		debug_print("Level selection menu " + ("shown" if level_selection_visible else "hidden"), "ui")
		
		# Toggle CameraRig when level selection is shown/hidden
		set_camera_rig_ui_visible(not level_selection_visible)
		
		# Toggle Timer UI when level selection is shown/hidden
		set_timer_ui_visible(not level_selection_visible)

func _on_level_selected(level_index: int, config_file: Resource):
	debug_print("=== LOADING SELECTED LEVEL ===", "level")
	debug_print("Level index: " + str(level_index), "level")
	debug_print("Config path: " + config_file.resource_path, "level")
	
	# Load the selected config
	if config_file and config_file.has_method("print_config"):
		debug_print("✅ SUCCESS: Loaded selected level config!", "level")
		if debug_mode or debug_config:
			config_file.print_config()
		set_level_config(config_file)
	else:
		debug_print("❌ FAILED: Could not load selected config, using default", "level")
		# Fallback to test config
		config_file = ResourceLoader.load("res://configs/levels/test_config.tres")
		if config_file:
			set_level_config(config_file)
	
	# Hide level selection menu
	toggle_level_selection_menu()
	
	# Choose scene by config path when known; fallback to section index
	var scene_path := ""
	
	var new_level: Node = null
	if scene_path != "":
		var packed: PackedScene = ResourceLoader.load(scene_path)
		if packed:
			new_level = packed.instantiate()
	else:
		# Validate level index against level_configs
		if level_index >= level_configs.size():
			debug_print("Warning: Config index " + str(level_index) + " exceeds level_configs size. Using level 0.", "level")
			level_index = 0
		if level_index >= 0 and level_index < level_configs.size() and level_configs[level_index]:
			new_level = config_file.level_scene.instantiate()
		else:
			debug_print("❌ Invalid level index or missing level section: " + str(level_index), "level")
	
	if new_level:
		_load_level(new_level)
		# Hide main menu button
		if start_game_button:
			start_game_button.visible = false
	else:
		debug_print("❌ Failed to instantiate level for selection", "level")
	
	debug_print("=== END LEVEL LOADING ===", "level")

# =============================================================================
# CONFIG TESTING SYSTEM
# =============================================================================

func create_config_test_panel():
	# Create the main config test panel
	config_test_panel = Control.new()
	config_test_panel.name = "ConfigTestPanel"
	config_test_panel.visible = false
	config_test_panel.z_index = 50
	
	# Set panel size and position (left side of screen)
	config_test_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	config_test_panel.size = Vector2(550, get_viewport().size.y)
	
	# Add background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	config_test_panel.add_child(background)
	
	# Create scroll container for buttons
	var scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.custom_minimum_size = Vector2(380, 0)
	config_test_panel.add_child(scroll_container)
	
	# Create VBox for buttons
	var vbox = VBoxContainer.new()
	scroll_container.add_child(vbox)
	
	# Add title
	var title_label = Label.new()
	title_label.text = "CONFIG TESTING PANEL\nPress T to toggle"
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# Add separator
	var separator1 = HSeparator.new()
	vbox.add_child(separator1)
	
	# Add test all button
	var test_all_button = Button.new()
	test_all_button.text = "🧪 TEST ALL CONFIGS"
	test_all_button.add_theme_font_size_override("font_size", 36)
	test_all_button.add_theme_color_override("font_color", Color.YELLOW)
	test_all_button.custom_minimum_size = Vector2(360, 80)
	test_all_button.pressed.connect(_on_test_all_configs)
	vbox.add_child(test_all_button)
	
	# Add separator
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# Create buttons for each config
	for i in range(available_configs.size()):
		var config_path = available_configs[i]
		var config_name = config_path.get_file().get_basename()
		
		var button = Button.new()
		button.text = config_name
		button.add_theme_font_size_override("font_size", 32)
		button.custom_minimum_size = Vector2(360, 80)
		
		# Connect button to test function
		button.pressed.connect(_on_test_config.bind(config_path))
		vbox.add_child(button)
	
	# Add close button at bottom
	var close_button = Button.new()
	close_button.text = "❌ CLOSE PANEL"
	close_button.add_theme_font_size_override("font_size", 36)
	close_button.add_theme_color_override("font_color", Color.RED)
	close_button.custom_minimum_size = Vector2(360, 80)
	close_button.pressed.connect(toggle_config_test_panel)
	vbox.add_child(close_button)
	
	# Add to UI Menu layer
	var ui_menu = get_node("UI Menu")
	ui_menu.add_child(config_test_panel)
	
	debug_print("Config test panel created with " + str(available_configs.size()) + " configs", "config")

func toggle_config_test_panel():
	config_test_visible = !config_test_visible
	if config_test_panel:
		config_test_panel.visible = config_test_visible
		debug_print("Config test panel " + ("shown" if config_test_visible else "hidden"), "config")

func _on_test_config(config_path: String):
	debug_print("=== TESTING CONFIG: " + config_path + " ===", "config")
	
	# Load the config
	var config = ResourceLoader.load(config_path)
	
	if config:
		if config.has_method("print_config") and config.has_method("is_valid"):
			if config.is_valid():
				debug_print("✅ SUCCESS: Config loaded and validated!", "config")
				if debug_mode or debug_config:
					config.print_config()
				
				# Update current level config for camera testing
				set_level_config(config)
				
				# Note: Camera system testing requires loading a level with CameraRig
			else:
				debug_print("❌ FAILED: Config loaded but validation failed", "config")
		else:
			debug_print("❌ FAILED: Config missing required methods (print_config, is_valid)", "config")
	else:
		debug_print("❌ FAILED: Could not load config file", "config")
	
	debug_print("=== END CONFIG TEST ===", "config")

func _on_test_all_configs():
	debug_print("🧪 === TESTING ALL CONFIGS === 🧪", "config")
	
	var successful_loads = 0
	var total_files = available_configs.size()
	
	for config in available_configs:
		debug_print("Testing: " + config.resource_path, "config")
		
		if config:
			if config.has_method("print_config") and config.has_method("is_valid"):
				if config.is_valid():
					debug_print("✅ SUCCESS: " + config.resource_path, "config")
					successful_loads += 1
				else:
					debug_print("❌ VALIDATION FAILED: " + config.get_file(), "config")
			else:
				debug_print("❌ MISSING METHODS: " + config.get_file(), "config")
		else:
			debug_print("❌ LOAD FAILED: " + config.get_file(), "config")
	
	debug_print("=== TEST SUMMARY ===", "config")
	debug_print("Successful loads: " + str(successful_loads) + "/" + str(total_files), "config")
	if successful_loads == total_files:
		debug_print("🎉 ALL CONFIG FILES WORKING PERFECTLY!", "config")
	else:
		debug_print("⚠️  " + str(total_files - successful_loads) + " config files need attention", "config")

# Debug helper function with category support
func debug_print(message: String, category: String = ""):
	var should_print = false
	
	match category.to_upper():
		"UI":
			should_print = debug_mode or debug_ui
		"LEVEL":
			should_print = debug_mode or debug_level
		"CAMERA":
			should_print = debug_mode or debug_camera
		"CONFIG":
			should_print = debug_mode or debug_config
		"TIMER":
			should_print = debug_mode or debug_timer
		"SCORING":
			should_print = debug_mode or debug_scoring
		"GAME":
			should_print = debug_mode or debug_game
		_:
			should_print = debug_mode
	
	if should_print:
		var prefix = "Main"
		if category != "":
			prefix += " [" + category.to_upper() + "]"
		print(prefix + ": " + message)
