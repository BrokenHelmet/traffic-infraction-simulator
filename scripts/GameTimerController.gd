extends Control

# =============================================================================
# GAME TIMER CONTROLLER
# =============================================================================
# Manages level time limits with visual countdown and color-coded warnings
# Integrates with LevelConfig for time_limit values and provides end-of-level hooks
# =============================================================================

signal timer_expired
signal timer_warning(seconds_remaining: int)
signal timer_updated(seconds_remaining: int)

# Node references
@onready var progress_ring: TextureProgressBar = $TimerBackground/TimerContainer/ProgressRing
@onready var timer_label: Label = $TimerBackground/TimerContainer/TimerLabel
@onready var warning_animation: AnimationPlayer = $WarningAnimation
@onready var pulse_timer: Timer = $PulseTimer

# Timer configuration
@export_group("Timer Settings")
@export var total_time: float = 180.0  # Default 3 minutes (overridden by level config)
@export var warning_threshold: float = 0.3  # Yellow at 30% remaining
@export var critical_threshold: float = 0.1  # Red at 10% remaining

# Timer state
var current_time: float = 0.0
var is_running: bool = false
var is_paused: bool = false
var timer_enabled: bool = true

# Color configuration
var color_normal: Color = Color.GREEN
var color_warning: Color = Color.YELLOW  
var color_critical: Color = Color.RED

# Debug settings
@export_group("Debug Settings")
@export var debug_mode: bool = false

# Pause manager integration
var pause_manager: PauseManager = null

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	debug_print("GameTimer initialized")
	
	# Initialize timer display
	reset_timer()
	
	# Connect pulse timer for critical warning effect
	if pulse_timer:
		pulse_timer.timeout.connect(_on_pulse_timeout)
	
	# Connect to PauseManager if available
	pause_manager = get_node_or_null("/root/Main/PauseManager")
	if pause_manager:
		pause_manager.pause.connect(_on_game_paused)
		pause_manager.resume.connect(_on_game_resumed)
		debug_print("Connected to PauseManager")
	
	# Hide initially (will be shown when level starts)
	visible = false

# =============================================================================
# PUBLIC API
# =============================================================================

# Start the timer countdown
func start_timer(time_limit: float = -1):
	if time_limit > 0:
		total_time = time_limit
	
	current_time = total_time
	is_running = true
	is_paused = false
	visible = true
	
	debug_print("Timer started with " + str(total_time) + " seconds")
	update_display()

# Pause the timer
func pause_timer():
	is_paused = true
	is_running = false
	debug_print("Timer paused")
	
	# Stop pulsing effect if active
	if pulse_timer:
		pulse_timer.stop()

# Resume the timer (with optional delay for smooth transition)
func resume_timer(delay: float = 0.5):
	debug_print("Timer resuming in " + str(delay) + " seconds")
	
	# Brief delay to prevent jarring immediate resumption
	await get_tree().create_timer(delay).timeout
	
	is_paused = false
	is_running = true
	debug_print("Timer resumed")

# Stop and reset the timer
func stop_timer():
	is_running = false
	is_paused = false
	if pulse_timer:
		pulse_timer.stop()
	
	reset_timer()
	debug_print("Timer stopped")

# Reset timer to initial state
func reset_timer():
	current_time = total_time
	is_running = false
	is_paused = false
	update_display()
	
	# Reset to normal color
	set_timer_color(color_normal)
	debug_print("Timer reset")

# Set timer visibility (for level selection integration)
func set_timer_visible(is_visible: bool):
	visible = is_visible and timer_enabled
	debug_print("Timer visibility set to " + str(visible))

# Enable/disable timer system entirely
func set_timer_enabled(enabled: bool):
	timer_enabled = enabled
	if not enabled:
		visible = false
		stop_timer()
	debug_print("Timer system " + ("enabled" if enabled else "disabled"))

# Get current time remaining
func get_time_remaining() -> float:
	return current_time

# Get time remaining as formatted string (MM:SS)
func get_time_string() -> String:
	var minutes = int(current_time) / 60
	var seconds = int(current_time) % 60
	return "%02d:%02d" % [minutes, seconds]

# Check if timer is in critical state
func is_critical() -> bool:
	return current_time <= (total_time * critical_threshold)

# Check if timer is in warning state  
func is_warning() -> bool:
	return current_time <= (total_time * warning_threshold)

# =============================================================================
# TIMER UPDATE LOGIC
# =============================================================================

func _process(delta):
	if not is_running or is_paused:
		return
	
	# Countdown
	current_time -= delta
	
	# Check for timer expiration
	if current_time <= 0:
		current_time = 0
		_on_timer_expired()
		return
	
	# Update display
	update_display()
	
	# Emit signals for external systems
	timer_updated.emit(int(current_time))
	
	# Check for warning thresholds
	var seconds_remaining = int(current_time)
	if seconds_remaining == 30 or seconds_remaining == 10:
		timer_warning.emit(seconds_remaining)
		debug_print("Timer warning: " + str(seconds_remaining) + " seconds remaining")

# Update the visual display
func update_display():
	if not timer_label or not progress_ring:
		return
	
	# Update timer text
	timer_label.text = get_time_string()
	
	# Update progress ring
	var progress_percent = (current_time / total_time) * 100.0
	progress_ring.value = progress_percent
	
	# Update colors based on time remaining
	update_timer_colors()

# Update timer colors based on remaining time
func update_timer_colors():
	var time_ratio = current_time / total_time
	
	if time_ratio <= critical_threshold:
		set_timer_color(color_critical)
		# Start pulsing effect in critical state
		if pulse_timer and not pulse_timer.is_stopped():
			return  # Already pulsing
		elif pulse_timer:
			pulse_timer.start()
	elif time_ratio <= warning_threshold:
		set_timer_color(color_warning)
		# Stop pulsing in warning state
		if pulse_timer:
			pulse_timer.stop()
	else:
		set_timer_color(color_normal)
		# Stop pulsing in normal state
		if pulse_timer:
			pulse_timer.stop()

# Set timer UI colors
func set_timer_color(color: Color):
	if timer_label:
		timer_label.modulate = color
	if progress_ring:
		progress_ring.modulate = color

# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_timer_expired():
	is_running = false
	debug_print("Timer expired!")
	
	# Stop pulsing effect
	if pulse_timer:
		pulse_timer.stop()
	
	# Set to critical color
	set_timer_color(color_critical)
	
	# Emit signal for external handling
	timer_expired.emit()

func _on_pulse_timeout():
	# Pulsing effect for critical time
	if timer_label:
		var tween = create_tween()
		tween.set_loops(2)
		tween.tween_property(timer_label, "modulate:a", 0.3, 0.25)
		tween.tween_property(timer_label, "modulate:a", 1.0, 0.25)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Pause manager event handlers
func _on_game_paused():
	if is_running:
		pause_timer()
		debug_print("Timer auto-paused by PauseManager")

func _on_game_resumed():
	if is_paused:
		resume_timer(0.0)  # No delay for automatic resume
		debug_print("Timer auto-resumed by PauseManager")

# Debug helper function
func debug_print(message: String):
	if debug_mode:
		print("[GameTimer] " + message)

# Get timer statistics for end-of-level reporting
func get_timer_stats() -> Dictionary:
	return {
		"total_time": total_time,
		"time_used": total_time - current_time,
		"time_remaining": current_time,
		"completion_ratio": (total_time - current_time) / total_time,
		"was_expired": current_time <= 0
	}
