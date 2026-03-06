extends Control

# =============================================================================
# LANDING SCREEN CONTROLLER
# =============================================================================
# Professional landing screen for Traffic Control Simulator
# Handles touch/click input to transition to main game
# Features thematic styling and smooth animations
# =============================================================================

signal start_game_requested

@onready var touch_prompt: Label = $MainContainer/PromptContainer/TouchPrompt
@onready var version_label: Label = $VersionLabel

var is_transitioning: bool = false
var fade_tween: Tween
var pulse_tween: Tween

func _ready():
	
	await get_node("../SplashScreen").splash_completed
	
	visible = true
	
	# Set version from project settings
	var version = ProjectSettings.get_setting("application/config/version", "1.05")
	version_label.text = "v" + version
	
	# Start the pulsing animation for the touch prompt
	start_pulse_animation()
	
	print("Landing screen ready - waiting for user input")

func start_pulse_animation():
	# Create a simple tween-based pulsing animation
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(touch_prompt, "modulate", Color(1, 1, 1, 0.6), 1.0)
	pulse_tween.tween_property(touch_prompt, "modulate", Color(1, 1, 1, 1.0), 1.0)

func _input(event):
	# Handle touch, mouse click, or key press to start game
	if is_transitioning or not visible:
		return
	
	var should_start = false
	
	if event is InputEventScreenTouch and event.pressed:
		should_start = true
		print("Touch detected - starting game")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		should_start = true
		print("Mouse click detected - starting game")
	elif event is InputEventKey and event.pressed:
		# Allow any key to start (space, enter, etc.)
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			should_start = true
			print("Key press detected - starting game: ", event.keycode)
	
	if should_start:
		start_transition_to_game()

func start_transition_to_game():
	if is_transitioning:
		return
		
	is_transitioning = true
	
	# Stop the pulsing animation
	if pulse_tween:
		pulse_tween.kill()
	
	# Update prompt text
	touch_prompt.text = "LOADING..."
	touch_prompt.modulate = Color.WHITE
	
	# Create fade out effect
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Fade out the entire screen
	fade_tween.tween_property(self, "modulate", Color.TRANSPARENT, 1.0)
	
	# Wait for fade to complete, then emit signal
	await fade_tween.finished
	
	print("Landing screen transition complete - emitting start game signal")
	start_game_requested.emit()

# Function to be called externally if needed
func trigger_start_game():
	start_transition_to_game()
