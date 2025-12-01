extends Control

# =============================================================================
# START COUNTDOWN CONTROLLER
# =============================================================================
# Manages the animated "3-2-1 START!" countdown sequence before level begins
# Provides smooth scaling/fade animations and integration hooks
# =============================================================================

signal countdown_completed
signal countdown_number_displayed(number: int)

# Node references
@onready var countdown_label: Label = $CountdownLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Countdown configuration
@export_group("Countdown Settings")
@export var countdown_sequence: Array[String] = ["3", "2", "1", "START!"]
@export var number_duration: float = 1.0  # Duration for each number
@export var start_delay: float = 0.5  # Delay before starting countdown

# Animation configuration
@export_group("Animation Settings")
@export var scale_start: Vector2 = Vector2(0.3, 0.3)
@export var scale_peak: Vector2 = Vector2(1.2, 1.2)
@export var scale_end: Vector2 = Vector2(1.0, 1.0)
@export var start_color: Color = Color.WHITE
@export var final_color: Color = Color.GREEN  # Color for "START!"

# State tracking
var current_index: int = 0
var is_active: bool = false
var was_paused: bool = false

# Debug settings
@export_group("Debug Settings")
@export var debug_mode: bool = false

# Pause manager integration
var pause_manager: PauseManager = null

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	debug_print("StartCountdown initialized")
	
	# Hide initially
	visible = false
	
	# Validate animation player
	if not animation_player:
		push_error("StartCountdown: AnimationPlayer not found!")
		return
	
	# Connect animation finished signal
	if animation_player.animation_finished.is_connected(_on_animation_finished):
		return
	animation_player.animation_finished.connect(_on_animation_finished)
	
	# Connect to PauseManager if available
	pause_manager = get_node_or_null("/root/Main/PauseManager")
	if pause_manager:
		pause_manager.pause.connect(_on_game_paused)
		pause_manager.resume.connect(_on_game_resumed)
		debug_print("Connected to PauseManager")

# =============================================================================
# PUBLIC API
# =============================================================================

# Start the countdown sequence
func start_countdown():
	if is_active:
		debug_print("Countdown already active")
		return
	
	debug_print("Starting countdown sequence")
	
	# Reset state
	current_index = 0
	is_active = true
	visible = true
	
	# Initial setup
	if countdown_label:
		countdown_label.modulate = start_color
		countdown_label.scale = scale_start
	
	# Start after brief delay
	await get_tree().create_timer(start_delay).timeout
	
	if is_active:  # Check if still active after delay
		show_next_number()

# Stop the countdown (emergency stop)
func stop_countdown():
	if not is_active:
		return
	
	debug_print("Countdown stopped")
	
	is_active = false
	visible = false
	
	if animation_player:
		animation_player.stop()

# Check if countdown is currently active
func is_countdown_active() -> bool:
	return is_active

# Set countdown visibility (for integration with other systems)
func set_countdown_visible(is_visible: bool):
	if not is_active:
		visible = is_visible

# =============================================================================
# COUNTDOWN LOGIC
# =============================================================================

# Display the next number in the sequence
func show_next_number():
	if not is_active or current_index >= countdown_sequence.size():
		return
	
	var current_text = countdown_sequence[current_index]
	debug_print("Displaying: " + current_text)
	
	# Update label text
	if countdown_label:
		countdown_label.text = current_text
		
		# Special color for "START!"
		if current_text == "START!":
			countdown_label.modulate = final_color
		else:
			countdown_label.modulate = start_color
	
	# Emit signal for external systems
	if current_text.is_valid_int():
		countdown_number_displayed.emit(int(current_text))
	else:
		countdown_number_displayed.emit(0)  # For "START!"
	
	# Play animation
	if animation_player:
		animation_player.play("countdown_number")
	else:
		# Fallback without animation
		await get_tree().create_timer(number_duration).timeout
		_on_animation_finished("countdown_number")

# Handle animation completion
func _on_animation_finished(animation_name: String):
	if not is_active or animation_name != "countdown_number":
		return
	
	debug_print("Animation finished for: " + countdown_sequence[current_index])
	
	# Move to next number
	current_index += 1
	
	# Check if countdown is complete
	if current_index >= countdown_sequence.size():
		_on_countdown_complete()
	else:
		# Show next number after brief pause
		await get_tree().create_timer(0.1).timeout
		if is_active:  # Check if still active
			show_next_number()

# Handle countdown completion
func _on_countdown_complete():
	debug_print("Countdown sequence completed")
	
	is_active = false
	
	# Fade out the entire countdown
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_on_fadeout_complete)

# Handle fadeout completion
func _on_fadeout_complete():
	visible = false
	modulate.a = 1.0  # Reset for next use
	
	debug_print("Countdown fully complete - emitting signal")
	countdown_completed.emit()

# =============================================================================
# ANIMATION CUSTOMIZATION
# =============================================================================

# Create custom animation (if default doesn't exist)
func create_default_animation():
	if not animation_player:
		return
	
	debug_print("Creating default countdown animation")
	
	# This would be called if the animation doesn't exist in the scene
	# For now, we rely on the scene having the animation defined
	# But this could be expanded to create animations dynamically

# Update animation properties at runtime
func update_animation_properties():
	if not animation_player or not animation_player.has_animation("countdown_number"):
		return
	
	# Could modify animation properties here if needed
	debug_print("Animation properties updated")

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Pause manager event handlers
func _on_game_paused():
	if is_active and animation_player:
		animation_player.pause()
		was_paused = true
		debug_print("Countdown paused by PauseManager")

func _on_game_resumed():
	if was_paused and animation_player:
		animation_player.play()
		was_paused = false
		debug_print("Countdown resumed by PauseManager")

# Debug helper function
func debug_print(message: String):
	if debug_mode:
		print("[StartCountdown] " + message)

# Get current countdown progress (0.0 to 1.0)
func get_countdown_progress() -> float:
	if not is_active:
		return 0.0
	
	return float(current_index) / float(countdown_sequence.size())

# Get time remaining in current countdown
func get_estimated_time_remaining() -> float:
	if not is_active:
		return 0.0
	
	var remaining_numbers = countdown_sequence.size() - current_index
	return remaining_numbers * number_duration

# Customize countdown sequence
func set_countdown_sequence(new_sequence: Array[String]):
	if is_active:
		debug_print("Cannot change sequence while countdown is active")
		return
	
	countdown_sequence = new_sequence
	debug_print("Countdown sequence updated: " + str(countdown_sequence))
