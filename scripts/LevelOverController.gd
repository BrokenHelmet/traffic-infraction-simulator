extends Control

# =============================================================================
# LEVEL OVER CONTROLLER
# =============================================================================
# Manages end-of-level popup with statistics and action buttons
# Provides hooks for retry, continue, and level completion processing
# =============================================================================

signal retry_requested
signal continue_requested
signal level_results_processed(results: Dictionary)

# Node references
@onready var title_label: Label = $MessagePanel/MessageContainer/TitleLabel
@onready var details_container: VBoxContainer = $MessagePanel/MessageContainer/DetailsContainer
@onready var time_label: Label = $MessagePanel/MessageContainer/DetailsContainer/TimeLabel
@onready var vehicles_label: Label = $MessagePanel/MessageContainer/DetailsContainer/VehiclesLabel
@onready var collisions_label: Label = $MessagePanel/MessageContainer/DetailsContainer/CollisionsLabel
@onready var score_label: Label = $MessagePanel/MessageContainer/DetailsContainer/ScoreLabel
@onready var stars_label: Label = $MessagePanel/MessageContainer/DetailsContainer/StarsLabel
@onready var retry_button: Button = $MessagePanel/MessageContainer/ButtonContainer/RetryButton
@onready var continue_button: Button = $MessagePanel/MessageContainer/ButtonContainer/ContinueButton
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Level over configuration
@export_group("Level Over Settings")
@export var show_duration: float = 1.0  # How long to show the popup initially
@export var auto_hide: bool = false  # Whether to auto-hide after time
@export var auto_hide_duration: float = 5.0  # Time before auto-hide

# Message templates
var time_up_title: String = "TIME'S UP!"
var success_title: String = "LEVEL COMPLETE!"
var failure_title: String = "LEVEL FAILED!"

# State tracking
var is_visible: bool = false
var level_results: Dictionary = {}

# UI references for hiding during popup
var score_display: Node = null
var camera_rig: Node = null
var hidden_ui_elements: Array[Node] = []

# Debug settings
@export_group("Debug Settings")
@export var debug_mode: bool = false
@export var debug_ui_updates: bool = false
@export var debug_statistics: bool = false
@export var debug_scoring_integration: bool = false

func _ready():
	debug_print("LevelOver initialized")
	
	# Hide initially
	visible = false
	is_visible = false
	
	# Connect button signals
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	
	debug_ui("LevelOver ready - buttons connected")

# =============================================================================
# PUBLIC API
# =============================================================================

# Show level over popup with results
func show_level_over(results: Dictionary):
	if is_visible:
		debug_ui("Level over popup already visible")
		return
	
	debug_ui("Showing level over popup")
	level_results = results
	
	# Hide background UI elements
	hide_background_ui()
	
	# Update display content
	update_popup_content(results)
	
	# Show the popup
	visible = true
	is_visible = true
	
	# Animate in (if animation exists)
	if animation_player and animation_player.has_animation("popup_in"):
		animation_player.play("popup_in")
	
	# Auto-hide if configured
	if auto_hide:
		await get_tree().create_timer(auto_hide_duration).timeout
		if is_visible:  # Still visible after delay
			hide_level_over()
	
	# Emit signal for external processing
	level_results_processed.emit(results)

# Hide the level over popup
func hide_level_over():
	if not is_visible:
		return
	
	debug_ui("Hiding level over popup")
	
	# Animate out (if animation exists)
	if animation_player and animation_player.has_animation("popup_out"):
		animation_player.play("popup_out")
		await animation_player.animation_finished
	
	visible = false
	is_visible = false
	
	# Restore background UI elements
	restore_background_ui()

# Show time expired popup
func show_time_expired(timer_stats: Dictionary, game_stats: Dictionary = {}):
	var results = {
		"type": "time_expired",
		"title": time_up_title,
		"timer_stats": timer_stats,
		"game_stats": game_stats,
		"success": false
	}
	
	debug_ui("Showing time expired popup")
	show_level_over(results)

# Show level completed popup (called from Main.gd on successful level completion)
func show_level_completed(game_stats: Dictionary):
	var results = {
		"type": "success",
		"title": success_title,
		"timer_stats": {},  # Timer stats not provided in this call pattern
		"game_stats": game_stats,
		"success": true
	}
	
	debug_ui("Showing level completed popup")
	show_level_over(results)

# Show level failed popup (called from Main.gd on level failure)
func show_level_failed(game_stats: Dictionary):
	var results = {
		"type": "failure",
		"title": failure_title,
		"reason": "Level requirements not met",  # Default reason
		"timer_stats": {},  # Timer stats not provided in this call pattern
		"game_stats": game_stats,
		"success": false
	}
	
	debug_ui("Showing level failed popup")
	show_level_over(results)

# Check if popup is currently visible
func is_level_over_visible() -> bool:
	return is_visible

# Set popup visibility (for integration with other systems)
func set_level_over_visible(show: bool):
	if show:
		# Cannot show without results
		if level_results.is_empty():
			debug_ui("Cannot show level over without results")
			return
		show_level_over(level_results)
	else:
		hide_level_over()

# =============================================================================
# CONTENT UPDATE
# =============================================================================

# Update popup content based on results
func update_popup_content(results: Dictionary):
	debug_ui("Updating popup content with results: " + str(results.keys()))
	
	# Update title
	if title_label and results.has("title"):
		title_label.text = results.title
		
		# Color based on success/failure
		if results.get("success", false):
			title_label.modulate = Color.GREEN
		else:
			title_label.modulate = Color.RED
		debug_ui("Title updated: " + results.title + " (success: " + str(results.get("success", false)) + ")")
	
	# Update individual statistics labels
	update_statistics_labels(results)
	
	# Update button states
	update_button_states(results)

# Update individual statistics labels with results data
func update_statistics_labels(results: Dictionary):
	debug_stats("Updating statistics labels")
	
	# Update time display
	update_time_display(results)
	
	# Update vehicles display
	update_vehicles_display(results)
	
	# Update collisions display
	update_collisions_display(results)
	
	# Update score display (integrating with scoring system)
	update_score_display(results)
	
	# Update stars display
	update_stars_display(results)

func update_time_display(results: Dictionary):
	if not time_label:
		return
	
	var time_text = "⏱️ Time: --:--"
	
	# Try to get time from different sources
	if results.has("timer_stats"):
		var timer_stats = results.timer_stats
		if timer_stats.has("time_used"):
			var time_used = timer_stats.get("time_used", 0)
			var minutes = int(time_used) / 60
			var seconds = int(time_used) % 60
			time_text = "⏱️ Time: %02d:%02d" % [minutes, seconds]
	elif results.has("game_stats"):
		var game_stats = results.game_stats
		if game_stats.has("elapsed_time_formatted"):
			time_text = "⏱️ Time: " + str(game_stats.elapsed_time_formatted)
		elif game_stats.has("elapsed_time"):
			var elapsed = game_stats.elapsed_time
			var minutes = int(elapsed) / 60
			var seconds = int(elapsed) % 60
			time_text = "⏱️ Time: %02d:%02d" % [minutes, seconds]
	
	time_label.text = time_text
	debug_stats("Time display updated: " + time_text)

func update_vehicles_display(results: Dictionary):
	if not vehicles_label:
		return
	
	var vehicles_text = "🚗 Vehicles Passed: 0"
	
	if results.has("game_stats"):
		var game_stats = results.game_stats
		if game_stats.has("vehicles_passed"):
			vehicles_text = "🚗 Vehicles Passed: " + str(game_stats.vehicles_passed)
	
	vehicles_label.text = vehicles_text
	debug_stats("Vehicles display updated: " + vehicles_text)

func update_collisions_display(results: Dictionary):
	if not collisions_label:
		return
	
	var collisions_text = "🚨 Collisions: 0"
	
	if results.has("game_stats"):
		var game_stats = results.game_stats
		if game_stats.has("collisions"):
			var collision_count = game_stats.collisions
			collisions_text = "🚨 Collisions: " + str(collision_count)
			
			# Color based on collision count
			if collision_count == 0:
				collisions_label.modulate = Color.GREEN
			elif collision_count <= 2:
				collisions_label.modulate = Color.YELLOW
			else:
				collisions_label.modulate = Color.RED
	
	collisions_label.text = collisions_text
	debug_stats("Collisions display updated: " + collisions_text)

func update_score_display(results: Dictionary):
	if not score_label:
		return
	
	var score_text = "🏆 Score: 0"
	
	# Try to get score from different sources
	if results.has("game_stats"):
		var game_stats = results.game_stats
		if game_stats.has("final_score"):
			score_text = "🏆 Score: " + str(game_stats.final_score)
			debug_scoring("Using final_score from game_stats: " + str(game_stats.final_score))
		elif game_stats.has("score") and game_stats.score > 0:
			score_text = "🏆 Score: " + str(game_stats.score)
			debug_scoring("Using score from game_stats: " + str(game_stats.score))
	
	# Try to get real-time score from ScoreManager if available
	var score_manager = get_tree().get_first_node_in_group("score_manager")
	if score_manager and score_manager.has_method("get_total_score"):
		var real_time_score = score_manager.get_total_score()
		if real_time_score > 0:
			score_text = "🏆 Score: " + str(real_time_score)
			debug_scoring("Using real-time score from ScoreManager: " + str(real_time_score))
	
	score_label.text = score_text
	debug_stats("Score display updated: " + score_text)

func update_stars_display(results: Dictionary):
	if not stars_label:
		return
	
	var stars_earned = 0
	var stars_text = ""
	
	# Try to get stars from game_stats
	if results.has("game_stats"):
		var game_stats = results.game_stats
		if game_stats.has("stars_earned"):
			stars_earned = game_stats.stars_earned
			debug_scoring("Using stars_earned from game_stats: " + str(stars_earned))
	
	# Try to get stars from ScoreManager if not available in game_stats
	if stars_earned == 0:
		var score_manager = get_tree().get_first_node_in_group("score_manager")
		if score_manager and score_manager.has_method("calculate_star_rating"):
			stars_earned = score_manager.calculate_star_rating()
			debug_scoring("Using real-time stars from ScoreManager: " + str(stars_earned))
	
	# Format stars display
	if stars_earned > 0:
		var filled_stars = "★".repeat(stars_earned)  # ★
		var empty_stars = "☆".repeat(3 - stars_earned)  # ☆
		stars_text = filled_stars + empty_stars
		
		# Color based on performance
		if stars_earned == 3:
			stars_label.modulate = Color.GOLD
		elif stars_earned == 2:
			stars_label.modulate = Color.ORANGE
		else:
			stars_label.modulate = Color.YELLOW
	else:
		stars_text = "No Stars Earned"
		stars_label.modulate = Color.GRAY
	
	stars_label.text = stars_text
	debug_stats("Stars display updated: " + stars_text + " (" + str(stars_earned) + " stars)")

# Update button states based on results
func update_button_states(results: Dictionary):
	if not retry_button or not continue_button:
		return
	
	# Always enable retry
	retry_button.disabled = false
	
	# Continue button logic
	var success = results.get("success", false)
	
	if success:
		continue_button.text = "NEXT LEVEL"
		continue_button.disabled = false
		continue_button.modulate = Color.GREEN
	else:
		continue_button.text = "CONTINUE"
		continue_button.disabled = false
		continue_button.modulate = Color.WHITE

# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_retry_pressed():
	debug_ui("Retry button pressed")
	hide_level_over()
	retry_requested.emit()

func _on_continue_pressed():
	debug_ui("Continue button pressed")
	hide_level_over()
	continue_requested.emit()

# =============================================================================
# ANIMATION HELPERS
# =============================================================================

# Create fade in animation
func create_fade_in_animation():
	if not animation_player:
		return
	
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

# Create fade out animation
func create_fade_out_animation():
	if not animation_player:
		return
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): visible = false)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# =============================================================================
# UI MANAGEMENT FUNCTIONS
# =============================================================================

# Hide background UI elements during level over popup
func hide_background_ui():
	debug_ui("Hiding background UI elements")
	hidden_ui_elements.clear()
	
	# Find and hide ScoreDisplay
	if not score_display:
		score_display = get_tree().get_first_node_in_group("score_display")
		if not score_display:
			# Try finding by name in UI Menu
			var ui_menu = get_node_or_null("/root/Main/UI Menu")
			if ui_menu:
				score_display = ui_menu.get_node_or_null("ScoreDisplay")
	
	if score_display and score_display.visible:
		score_display.visible = false
		hidden_ui_elements.append(score_display)
		debug_ui("Hidden ScoreDisplay")
	
	# Find and hide CameraRig UI
	if not camera_rig:
		camera_rig = get_tree().get_first_node_in_group("camera_rig")
		if not camera_rig:
			# Try alternative search methods
			var current_scene = get_tree().current_scene
			for child in current_scene.get_children():
				if child.name.contains("CameraRig") or child.name.contains("Camera"):
					camera_rig = child
					break
	
	if camera_rig:
		# Hide camera rig UI if it has a method to do so
		if camera_rig.has_method("set_ui_visible"):
			camera_rig.set_ui_visible(false)
			hidden_ui_elements.append(camera_rig)
			debug_ui("Hidden CameraRig UI")
		elif camera_rig.has_method("hide_ui"):
			camera_rig.hide_ui()
			hidden_ui_elements.append(camera_rig)
			debug_ui("Hidden CameraRig UI (via hide_ui)")
	
	# Hide any other UI elements that might be in the way
	hide_additional_ui_elements()

func hide_additional_ui_elements():
	"""Hide additional UI elements that might interfere with level over display"""
	# Look for common UI element names that might be visible
	var ui_menu = get_node_or_null("/root/Main/UI Menu")
	if ui_menu:
		for child in ui_menu.get_children():
			# Skip our own level over elements and essential UI
			if child.name in ["LevelOver", "GameTimer", "StartCountdown", "ReturnToMenuButton"]:
				continue
			
			# Hide other UI elements that are currently visible
			if child.visible and child != self:
				child.visible = false
				hidden_ui_elements.append(child)
				debug_ui("Hidden additional UI element: " + child.name)

# Restore background UI elements after level over popup
func restore_background_ui():
	debug_ui("Restoring background UI elements")
	
	for element in hidden_ui_elements:
		if is_instance_valid(element):
			if element == camera_rig and element.has_method("set_ui_visible"):
				element.set_ui_visible(true)
				debug_ui("Restored CameraRig UI")
			elif element == camera_rig and element.has_method("show_ui"):
				element.show_ui()
				debug_ui("Restored CameraRig UI (via show_ui)")
			else:
				element.visible = true
				debug_ui("Restored UI element: " + element.name)
	
	hidden_ui_elements.clear()
	debug_ui("All background UI elements restored")

# =============================================================================
# DEBUG HELPER FUNCTIONS
# =============================================================================

# Debug helper function with category support
func debug_print(message: String, enabled: bool = true):
	if debug_mode and enabled:
		print("[LevelOverController-" + name + "] " + message)

# Category-specific debug helpers
func debug_ui(message: String):
	debug_print(message, debug_ui_updates)

func debug_stats(message: String):
	debug_print(message, debug_statistics)

func debug_scoring(message: String):
	debug_print(message, debug_scoring_integration)

# Get current results
func get_level_results() -> Dictionary:
	return level_results

# Process end of level (debug function for comprehensive statistics logging)
func process_end_of_level(results: Dictionary):
	debug_stats("=== PROCESSING END OF LEVEL ===")
	debug_stats("Level Type: " + str(results.get("type", "unknown")))
	debug_stats("Success: " + str(results.get("success", false)))
	
	if results.has("timer_stats"):
		var timer_stats = results.timer_stats
		debug_stats("Timer - Total: " + str(timer_stats.get("total_time", 0)) + "s")
		debug_stats("Timer - Used: " + str(timer_stats.get("time_used", 0)) + "s")
		debug_stats("Timer - Remaining: " + str(timer_stats.get("time_remaining", 0)) + "s")
	
	if results.has("game_stats"):
		var game_stats = results.game_stats
		debug_stats("Game Stats: " + str(game_stats))
		
		# Log individual statistics for detailed debugging
		if game_stats.has("vehicles_passed"):
			debug_stats("  Vehicles Passed: " + str(game_stats.vehicles_passed))
		if game_stats.has("collisions"):
			debug_stats("  Collisions: " + str(game_stats.collisions))
		if game_stats.has("elapsed_time_formatted"):
			debug_stats("  Elapsed Time: " + str(game_stats.elapsed_time_formatted))
		if game_stats.has("final_score") or game_stats.has("score"):
			var score = game_stats.get("final_score", game_stats.get("score", 0))
			debug_stats("  Score: " + str(score))
	
	debug_stats("=== END LEVEL PROCESSING COMPLETE ===")

# Set message templates (for customization)
func set_message_templates(time_up: String, success: String, failure: String):
	time_up_title = time_up
	success_title = success
	failure_title = failure
	debug_ui("Message templates updated")
