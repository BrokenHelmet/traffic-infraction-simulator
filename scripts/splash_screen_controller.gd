extends ColorRect

# =============================================================================
# SPLASH SCREEN CONTROLLER
# =============================================================================
# Handles splash screen video playback with fade in/out transitions
# Integrates with MainController for seamless app flow
# =============================================================================

signal splash_completed
signal splash_skipped

# Node references (now defined in scene)
@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var skip_label: Label = $SkipLabel

# Configuration
@export_group("Splash Settings")
@export var video_file_asset: VideoStreamTheora  # Direct video asset reference
@export var video_file_path: String = "res://assets/video-clip/splash_video.ogv"  # Fallback path if asset not set
@export var fade_in_duration: float = 1.0       # Fade in duration in seconds
@export var fade_out_duration: float = 1.0      # Fade out duration in seconds
@export var show_skip_after: float = 2.0        # Show skip option after X seconds
@export var skip_enabled: bool = true           # Allow skipping the splash screen
@export var auto_loop_video: bool = false       # Whether to loop the video
@export var fallback_duration: float = 5.0      # Duration to show splash if no video
@export_group("Debug Settings")
@export var debug_mode: bool = false            # Enable all debug logging
@export var debug_video: bool = false           # Enable video-specific debug output
@export var debug_fade: bool = false            # Enable fade transition debug output

# State tracking
var is_playing: bool = false
var can_skip: bool = false
var skip_timer: float = 0.0
var fade_tween: Tween
var video_ended: bool = false  # Prevent multiple end calls

func _ready():
	debug_print("Initializing splash screen")
	
	# Verify all nodes are available (they should be defined in scene)
	if not video_player:
		push_error("SplashScreenController: VideoStreamPlayer node not found in scene!")
		return
	if not fade_overlay:
		push_error("SplashScreenController: FadeOverlay node not found in scene!")
		return
	if not skip_label:
		push_error("SplashScreenController: SkipLabel node not found in scene!")
		return
	
	# Set initial state
	fade_overlay.color = Color(0, 0, 0, 1.0)  # Start fully black
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Configure components
	setup_video_player()
	setup_skip_label()
	
	# Hide initially
	visible = false
	
	# Ensure everything is ready
	debug_print("Initialization complete")

func setup_video_player():
	if not video_player:
		push_error("SplashScreenController: VideoStreamPlayer not found!")
		return
	
	debug_print("Setting up video player...", "video")
	
	# Priority 1: Use direct asset reference if available
	if video_file_asset:
		debug_print("Using direct video asset reference", "video")
		video_player.stream = video_file_asset
		debug_print("Video stream loaded from asset successfully", "video")
		debug_print("Video stream type: " + str(video_file_asset.get_class()), "video")
		if video_file_asset.has_method("get_length"):
			debug_print("Video length: " + str(video_file_asset.get_length()) + " seconds", "video")
	# Priority 2: Fallback to loading from file path
	elif FileAccess.file_exists(video_file_path):
		debug_print("Video asset not set, loading from path: " + video_file_path, "video")
		var video_stream = load(video_file_path)
		if video_stream:
			video_player.stream = video_stream
			debug_print("Video stream loaded from path successfully", "video")
			debug_print("Video stream type: " + str(video_stream.get_class()), "video")
			if video_stream.has_method("get_length"):
				debug_print("Video length: " + str(video_stream.get_length()) + " seconds", "video")
		else:
			debug_print("Failed to load video resource: " + video_file_path, "video")
			debug_print("Make sure the video file is imported correctly in Godot", "video")
	else:
		debug_print("No video asset set and file not found: " + video_file_path, "video")
		debug_print("Please assign a VideoStreamTheora asset to video_file_asset or check file path", "video")
		debug_print("Available video formats: .ogv, .webm", "video")
	
	# Configure video player settings
	video_player.autoplay = false
	video_player.loop = auto_loop_video
	video_player.expand = true
	video_player.volume_db = 0.0  # Set volume
	
	# Connect signals
	if not video_player.finished.is_connected(_on_video_finished):
		video_player.finished.connect(_on_video_finished)
		debug_print("Video finished signal connected", "video")

func setup_skip_label():
	if not skip_label:
		return
	
	# Label text and alignment are set in scene file, just configure styling
	skip_label.add_theme_color_override("font_color", Color.WHITE)
	skip_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	skip_label.add_theme_constant_override("shadow_offset_x", 2)
	skip_label.add_theme_constant_override("shadow_offset_y", 2)
	skip_label.modulate.a = 0.0  # Start invisible
	
	debug_print("Skip label positioned at bottom-right with z_index 10")

# =============================================================================
# PUBLIC API
# =============================================================================

# Start the splash screen sequence
func start_splash():
	if is_playing:
		debug_print("Splash already playing")
		return
	
	# Wait for ready if not ready yet
	if not fade_overlay or not video_player:
		debug_print("Waiting for initialization to complete...")
		await get_tree().process_frame
	
	debug_print("Starting splash screen sequence")
	visible = true
	is_playing = true
	can_skip = false
	skip_timer = 0.0
	
	# Reset fade overlay to full black
	if fade_overlay:
		fade_overlay.color = Color(0, 0, 0, 1.0)
	if skip_label:
		skip_label.modulate.a = 0.0
	
	# Start video playback
	if video_player and video_player.stream:
		debug_print("Starting video playback...", "video")
		video_player.play()
		await get_tree().process_frame  # Wait one frame
		if video_player.is_playing():
			debug_print("Video playback confirmed active", "video")
		else:
			debug_print("WARNING: Video failed to start playing!", "video")
			start_fallback_timer()
	else:
		debug_print("No video to play, using fallback timer", "video")
		start_fallback_timer()
	
	# Start fade in
	start_fade_in()

# Stop the splash screen and transition
func stop_splash():
	if not is_playing:
		return
	
	debug_print("Stopping splash screen")
	is_playing = false
	can_skip = false
	video_ended = false  # Reset for next time
	
	# Stop video
	if video_player:
		video_player.stop()
	
	# Start fade out
	start_fade_out()

# Skip the splash screen immediately
func skip_splash():
	if not can_skip or not is_playing:
		return
	
	debug_print("Splash screen skipped by user")
	splash_skipped.emit()
	stop_splash()

# Enable or disable the splash screen
func set_enabled(enabled: bool):
	visible = enabled
	if not enabled and is_playing:
		stop_splash()

# =============================================================================
# FADE SYSTEM
# =============================================================================

func start_fade_in():
	if not fade_overlay:
		debug_print("No fade overlay available for fade in", "fade")
		_on_fade_in_complete()
		return
	
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Fade from black to transparent
	fade_tween.tween_property(fade_overlay, "color:a", 0.0, fade_in_duration)
	fade_tween.tween_callback(_on_fade_in_complete)
	
	debug_print("Fade in started (" + str(fade_in_duration) + "s)", "fade")

func start_fade_out():
	if not fade_overlay:
		debug_print("No fade overlay available for fade out", "fade")
		_on_fade_out_complete()
		return
	
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Fade from transparent to black
	fade_tween.tween_property(fade_overlay, "color:a", 1.0, fade_out_duration)
	fade_tween.tween_callback(_on_fade_out_complete)
	
	debug_print("Fade out started (" + str(fade_out_duration) + "s)", "fade")

func _on_fade_in_complete():
	debug_print("Fade in complete", "fade")
	# Fade in is done, video should be visible

func _on_fade_out_complete():
	debug_print("Fade out complete", "fade")
	visible = false
	splash_completed.emit()

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event):
	if not is_playing or not skip_enabled:
		return
	
	# Handle skip input
	if can_skip:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE:
				skip_splash()
		elif event is InputEventScreenTouch and event.pressed:
			skip_splash()
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				skip_splash()

# =============================================================================
# UPDATE LOOP
# =============================================================================

func _process(delta):
	if not is_playing:
		return
	
	# Update skip timer
	if skip_enabled and not can_skip:
		skip_timer += delta
		if skip_timer >= show_skip_after:
			can_skip = true
			show_skip_label()
	
	# Note: Removed periodic video status logging to reduce console spam
	# Enable debug_mode and add manual checks if detailed video debugging needed
	
	# Auto-complete if video ends and no loop
	if video_player and video_player.stream and not auto_loop_video and not video_ended:
		if not video_player.is_playing() and skip_timer > 1.0:  # Give video time to start
			debug_print("Video stopped playing, ending splash", "video")
			video_ended = true
			_on_video_finished()

func show_skip_label():
	if not skip_label:
		return
	
	debug_print("Showing skip option")
	
	# Fade in skip label
	var skip_tween = create_tween()
	skip_tween.set_ease(Tween.EASE_OUT)
	skip_tween.tween_property(skip_label, "modulate:a", 0.8, 0.5)

# =============================================================================
# VIDEO EVENT HANDLERS
# =============================================================================

func _on_video_finished():
	if not is_playing or video_ended:
		return
	
	video_ended = true
	debug_print("Video playback finished", "video")
	
	# Small delay before starting fade out
	await get_tree().create_timer(0.5).timeout
	
	if is_playing:  # Check if still playing after delay
		stop_splash()

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Check if splash screen is currently active
func is_splash_active() -> bool:
	return is_playing and visible

# Get remaining video duration (if available)
func get_video_remaining_time() -> float:
	if not video_player or not video_player.stream:
		return 0.0
	
	var total_length = video_player.stream.get_length()
	var current_position = video_player.stream_position
	return max(0.0, total_length - current_position)

# Get information about the video source
func get_video_source_info() -> Dictionary:
	var info = {
		"has_asset": video_file_asset != null,
		"has_stream": video_player != null and video_player.stream != null,
		"source_type": "none",
		"file_path": video_file_path
	}
	
	if video_file_asset:
		info.source_type = "direct_asset"
	elif video_player and video_player.stream:
		info.source_type = "loaded_from_path"
	
	return info

# Debug helper function with category support
func debug_print(message: String, category: String = ""):
	var should_print = false
	
	match category.to_upper():
		"VIDEO":
			should_print = debug_mode or debug_video
		"FADE":
			should_print = debug_mode or debug_fade
		_:
			should_print = debug_mode
	
	if should_print:
		var prefix = "SplashScreenController"
		if category != "":
			prefix += " [" + category.to_upper() + "]"
		print(prefix + ": " + message)

# Fallback timer for when video doesn't work
func start_fallback_timer():
	debug_print("Starting fallback timer (" + str(fallback_duration) + "s)")
	await get_tree().create_timer(fallback_duration).timeout
	if is_playing:  # Check if still playing
		debug_print("Fallback timer completed")
		stop_splash()

# NOTE: Nodes are now defined in the scene file with proper hierarchy and z-indexing:
# - ColorRect (SplashScreen) with z_index = 9 (background)
# - VideoStreamPlayer with z_index = 10 (content layer)
# - FadeOverlay (ColorRect) with z_index = 10 (transition layer)
# - SkipLabel positioned at bottom-right with z_index = 10 (UI layer)

# Cleanup function
func cleanup():
	if fade_tween:
		fade_tween.kill()
	
	if video_player:
		video_player.stop()
	
	is_playing = false
	visible = false
	
	debug_print("Cleanup completed")
