extends Node3D

# =============================================================================
# CAMERA RIG SYSTEM
# =============================================================================
# A clean pivot-based camera system where:
# - CameraRig (this node) handles position and rotation transforms
# - Camera3D child only moves along local Z-axis for zoom
# - Much simpler than legacy camera systems
# =============================================================================

signal camera_position_changed(index: int)
signal zoom_changed(zoom_level: float)

# References
@onready var camera: Camera3D = $Camera3D
var camera_debug_display: Control  # Reference to CameraDebugDisplay for debug info
var ui_container: Control

# Camera positions from level config
var camera_positions: Array = []
var current_position_index: int = 0

# Enhanced camera position system (from CameraManager)
var all_camera_positions: Array[Dictionary] = []  # Combined config + traffic light positions
var config_camera_count: int = 0  # Number from config
var traffic_light_camera_count: int = 0  # Number from detected traffic lights
var level_config: Resource  # Level configuration resource

# Traffic light camera settings
@export_group("Traffic Light Detection")
@export var auto_detect_traffic_lights: bool = true
@export var traffic_light_camera_height: float = 15.0  # Height above traffic light
@export var traffic_light_camera_distance: float = 20.0  # Distance back from traffic light
@export var traffic_light_look_down_angle: float = -45.0  # Downward angle in degrees

# Zoom settings
@export_group("Zoom Settings")
@export var zoom_min: float = 5.0
@export var zoom_max: float = 50.0
@export var zoom_speed: float = 2.0
@export var default_zoom: float = 15.0

# Orbit controls
@export_group("Orbit Controls")
@export var orbit_enabled: bool = true
@export var rotation_speed: float = 1.0
@export var mouse_sensitivity: float = 0.005
@export var touch_sensitivity: float = 0.003

# Focus/Lock-on system
@export_group("Focus System")
@export var focus_enabled: bool = true
@export var focus_transition_duration: float = 1.0
@export var auto_detect_focus_targets: bool = true
@export var focus_target_groups: Array[String] = ["TestObjects"]  # Node groups to detect as focus targets

# Collision avoidance system
@export_group("Collision Avoidance")
@export var collision_enabled: bool = true
@export var collision_layers: int = 1  # Physics layers to check against (bitflag)
@export var collision_radius: float = 1.0  # Collision detection radius around camera
@export var min_ground_height: float = 1.0  # Minimum height above ground
@export var collision_check_distance: float = 50.0  # Maximum raycast distance
@export var collision_smoothing: float = 0.1  # How smoothly to adjust position when colliding

# Transition settings
@export_group("Transitions")
@export var transition_duration: float = 1.5
@export var transition_easing: Tween.EaseType = Tween.EASE_IN_OUT

# State tracking
var current_zoom: float
var is_transitioning: bool = false
var is_dragging: bool = false
var last_mouse_position: Vector2
var transition_tween: Tween

# Enable/disable system
var camera_rig_enabled: bool = true  # Whether the camera rig is active
var ui_visibility_state: bool = true  # Track UI visibility separately from camera state
var input_enabled: bool = true  # Whether camera input (touch/mouse) is enabled

# Spherical coordinate rotation (prevents gimbal lock)
var orbit_yaw: float = 0.0      # Horizontal rotation (around Y axis)
var orbit_pitch: float = -25.0  # Vertical rotation (up/down)
var pitch_min: float = -80.0    # Maximum upward angle
var pitch_max: float = 80.0     # Maximum downward angle

# Touch input tracking
var touch_points: Dictionary = {}
var initial_pinch_distance: float = 0.0

# Focus system state
var focus_targets: Array[Node3D] = []
var current_focus_target: Node3D = null
var is_focus_locked: bool = false
var focus_transition_tween: Tween

# Navigation UI
var nav_ui: Control
var prev_button: Button
var next_button: Button
var reset_button: Button
var position_label: Label
var focus_toggle_button: Button

# Enhanced focus system (from CameraManager)
@export_group("Enhanced Focus System")
@export var focus_mode_enabled: bool = true  # Toggle between free and focused camera modes
@export var use_raycast_focus: bool = false  # Use raycast to determine focus point dynamically
@export var raycast_length: float = 100.0  # Maximum raycast distance for focus detection
var current_focus_target_pos: Vector3  # Current point the camera should look at
var has_focus_target: bool = false  # Whether we have a valid focus target

# Debug settings
@export_group("Debug Settings")
@export var debug_mode: bool = false  # Enable debug console output

func _ready():
	debug_print("Initializing new pivot-based camera system")
	
	# Validate camera child exists
	if not camera:
		push_error("CameraRig: No Camera3D child found!")
		return
	
	# Set initial zoom
	current_zoom = default_zoom
	camera.position.z = current_zoom
	
	# Make this camera current
	camera.current = true
	
	# Create navigation UI
	create_navigation_ui()
	
	nav_ui.visible = false
	
	# Setup debug display based on debug_mode
	setup_debug_display()
	
	debug_print("Initialization complete - Camera at zoom: " + str(current_zoom))

# =============================================================================
# PUBLIC API
# =============================================================================

# CameraManager API Compatibility - Initialize the camera system with level configuration
func setup_camera_system(camera_ref: CharacterBody3D, config: Resource):
	print("CameraRig: setup_camera_system called (CameraManager compatibility mode)")
	print("CameraRig: Legacy camera reference provided (ignored): ", camera_ref != null)
	print("CameraRig: Config provided: ", config != null)
	
	level_config = config
	current_position_index = 0
	is_transitioning = false
	
	# Build comprehensive camera position list (traffic lights first, then config)
	build_complete_camera_position_list()
	
	var total_camera_count = all_camera_positions.size()
	print("CameraRig: Total camera positions available: ", total_camera_count)
	print("CameraRig: - From traffic lights (prioritized): ", traffic_light_camera_count)
	print("CameraRig: - From config: ", config_camera_count)
	
	if total_camera_count > 0:
		print("CameraRig: Moving to first camera position (prioritizing traffic lights)...")
		# Move to first position (traffic light positions come first)
		move_to_enhanced_position_immediately(0)
		
		# Create navigation UI if multiple positions exist
		if total_camera_count > 1:
			print("CameraRig: Creating navigation UI for ", total_camera_count, " positions")
			create_enhanced_navigation_ui()
	else:
		print("CameraRig: No camera positions available")

# Load camera positions from level config
func setup_camera_positions(positions: Array):
	camera_positions = positions
	current_position_index = 0
	
	print("CameraRig: Loaded ", camera_positions.size(), " camera positions")
	
	# Move to first position if available
	if not camera_positions.is_empty():
		move_to_position_immediately(0)
	
	# Update UI
	update_navigation_ui()

# Move to specific camera position immediately (no animation)
func move_to_position_immediately(index: int):
	if not _is_valid_position_index(index):
		return
	
	current_position_index = index
	var pos_data = camera_positions[index]
	
	# Set rig position and rotation
	global_position = pos_data.get("position", Vector3.ZERO)
	rotation_degrees = pos_data.get("rotation", Vector3.ZERO)
	
	# Update spherical coordinates to match the new rotation
	_update_spherical_from_rotation()
	
	# Reset zoom to default
	current_zoom = default_zoom
	camera.position.z = current_zoom
	
	print("CameraRig: Moved to position ", index + 1, " - Pos: ", global_position, ", Rot: ", rotation_degrees)
	
	camera_position_changed.emit(index)
	update_navigation_ui()

# Move to camera position with smooth animation
func move_to_position_smoothly(index: int):
	if not _is_valid_position_index(index) or is_transitioning:
		return
	
	current_position_index = index
	var pos_data = camera_positions[index]
	var target_position = pos_data.get("position", Vector3.ZERO)
	var target_rotation = pos_data.get("rotation", Vector3.ZERO)
	
	print("CameraRig: Smoothly transitioning to position ", index + 1)
	
	_start_smooth_transition(target_position, target_rotation)

# Navigate to next position (with looping)
func navigate_next():
	if not camera_rig_enabled or is_transitioning or camera_positions.is_empty():
		return
	
	var next_index = (current_position_index + 1) % camera_positions.size()
	move_to_position_smoothly(next_index)

# Navigate to previous position (with looping)
func navigate_previous():
	if not camera_rig_enabled or is_transitioning or camera_positions.is_empty():
		return
	
	var prev_index = (current_position_index - 1 + camera_positions.size()) % camera_positions.size()
	move_to_position_smoothly(prev_index)

# Reset to current position (cancels any manual orbit adjustments)
func reset_camera():
	if not camera_rig_enabled or camera_positions.is_empty():
		return
	
	move_to_position_smoothly(current_position_index)

# Set zoom level directly
func set_zoom(zoom_level: float):
	zoom_level = clamp(zoom_level, zoom_min, zoom_max)
	current_zoom = zoom_level
	camera.position.z = zoom_level
	
	zoom_changed.emit(zoom_level)

# Adjust zoom by delta (positive = zoom out, negative = zoom in)
func adjust_zoom(delta: float):
	set_zoom(current_zoom + delta)

# =============================================================================
# ENABLE/DISABLE SYSTEM
# =============================================================================

# Enable or disable the entire camera rig system
func set_camera_rig_enabled(enabled: bool):
	if camera_rig_enabled == enabled:
		return  # No change needed
	
	camera_rig_enabled = enabled
	debug_print("Camera rig " + ("enabled" if enabled else "disabled"))
	
	# Update UI visibility based on enabled state
	update_ui_visibility()
	
	# If disabled while transitioning, stop the transition
	if not enabled and is_transitioning:
		_stop_current_transition()
		
	# Reset input state when disabled
	if not enabled:
		is_dragging = false
		touch_points.clear()
		initial_pinch_distance = 0.0

# Check if the camera rig is currently enabled
func is_camera_rig_enabled() -> bool:
	return camera_rig_enabled

# Set UI visibility (can be controlled separately from camera functionality)
func set_ui_visible(show_ui: bool):
	if ui_visibility_state == show_ui:
		return  # No change needed
	
	ui_visibility_state = show_ui
	debug_print("UI visibility set to " + str(show_ui))
	update_ui_visibility()

# Update the actual UI visibility based on enabled state and visibility setting
func update_ui_visibility():
	var should_show_ui = camera_rig_enabled and ui_visibility_state
	
	if nav_ui and is_instance_valid(nav_ui):
		nav_ui.visible = should_show_ui
		debug_print("Navigation UI " + ("shown" if should_show_ui else "hidden"))

# Enable or disable camera input (touch/mouse controls)
func set_input_enabled(enabled: bool):
	if input_enabled == enabled:
		return  # No change needed
	
	input_enabled = enabled
	debug_print("Camera input " + ("enabled" if enabled else "disabled"))
	
	# Reset input state when disabling
	if not enabled:
		is_dragging = false
		touch_points.clear()
		initial_pinch_distance = 0.0
		debug_print("Input state reset")

# Get current input enabled state
func is_input_enabled() -> bool:
	return input_enabled

# Stop any current transitions (used when disabling)
func _stop_current_transition():
	if transition_tween:
		transition_tween.kill()
		transition_tween = null
	
	if focus_transition_tween:
		focus_transition_tween.kill()
		focus_transition_tween = null
	
	is_transitioning = false
	debug_print("All transitions stopped")

# Debug helper function
func debug_print(message: String):
	if debug_mode:
		print("CameraRig: " + message)

# Setup debug display based on debug_mode setting
func setup_debug_display():
	# Try to find CameraDebugDisplay node (it may be in Main scene as child of CameraRig)
	var debug_display_path = "CameraDebugDisplay"
	camera_debug_display = get_node_or_null(debug_display_path)
	
	if not camera_debug_display:
		# Try alternate path (in case it's in Main scene structure)
		var main_scene = get_tree().current_scene
		if main_scene:
			camera_debug_display = main_scene.find_child("CameraDebugDisplay", true, false)
	
	if camera_debug_display:
		# Set visibility based on debug_mode
		camera_debug_display.visible = debug_mode
		debug_print("CameraDebugDisplay found and set to " + ("visible" if debug_mode else "hidden"))
	else:
		debug_print("CameraDebugDisplay not found in scene")

# Public method to toggle debug display visibility
func set_debug_display_visible(visible_state: bool):
	if camera_debug_display:
		camera_debug_display.visible = visible_state
		debug_print("Debug display visibility set to " + str(visible_state))

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event):
	if not orbit_enabled or not camera_rig_enabled or not input_enabled:
		return
	
	# Mouse input
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	
	# Touch input
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)

func _handle_mouse_button(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			last_mouse_position = event.position
		else:
			is_dragging = false
	
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		adjust_zoom(-zoom_speed)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		adjust_zoom(zoom_speed)

func _handle_mouse_motion(event: InputEventMouseMotion):
	if not is_dragging or is_transitioning:
		return
	
	var delta = (event.position - last_mouse_position) * mouse_sensitivity
	
	# Update spherical coordinates
	orbit_yaw += rad_to_deg(-delta.x)    # Horizontal rotation
	orbit_pitch += rad_to_deg(-delta.y)  # Vertical rotation
	
	# Clamp pitch to prevent flipping
	orbit_pitch = clamp(orbit_pitch, pitch_min, pitch_max)
	
	# Apply rotation using spherical coordinates
	_apply_spherical_rotation()
	
	last_mouse_position = event.position

func _handle_screen_touch(event: InputEventScreenTouch):
	if event.pressed:
		touch_points[event.index] = event.position
		
		if touch_points.size() == 2:
			# Start pinch gesture
			var positions = touch_points.values()
			initial_pinch_distance = positions[0].distance_to(positions[1])
	else:
		touch_points.erase(event.index)

func _handle_screen_drag(event: InputEventScreenDrag):
	if is_transitioning:
		return
	
	touch_points[event.index] = event.position
	
	if touch_points.size() == 1:
		# Single finger drag - rotate camera using spherical coordinates
		var delta = event.relative * touch_sensitivity
		
		# Update spherical coordinates
		orbit_yaw += rad_to_deg(-delta.x)
		orbit_pitch += rad_to_deg(-delta.y)
		
		# Clamp pitch to prevent flipping
		orbit_pitch = clamp(orbit_pitch, pitch_min, pitch_max)
		
		# Apply rotation using spherical coordinates
		_apply_spherical_rotation()
		
	elif touch_points.size() == 2:
		# Two finger pinch - zoom
		var positions = touch_points.values()
		var current_distance = positions[0].distance_to(positions[1])
		
		if initial_pinch_distance > 0:
			var zoom_factor = initial_pinch_distance / current_distance
			var zoom_delta = (zoom_factor - 1.0) * zoom_speed
			adjust_zoom(zoom_delta)
		
		initial_pinch_distance = current_distance

# =============================================================================
# SMOOTH TRANSITIONS
# =============================================================================

func _start_smooth_transition(target_pos: Vector3, target_rot: Vector3):
	if transition_tween:
		transition_tween.kill()
	
	# Validate target position for collision avoidance
	target_pos = _validate_position(target_pos)
	
	is_transitioning = true
	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	
	# Animate position and rotation
	transition_tween.tween_property(self, "global_position", target_pos, transition_duration)
	transition_tween.tween_property(self, "rotation_degrees", target_rot, transition_duration)
	
	# Reset zoom to default
	transition_tween.tween_property(camera, "position:z", default_zoom, transition_duration)
	current_zoom = default_zoom
	
	# Set easing
	transition_tween.tween_callback(_on_transition_complete).set_delay(transition_duration)

func _on_transition_complete():
	is_transitioning = false
	
	# Update spherical coordinates to match final rotation after transition
	_update_spherical_from_rotation()
	
	camera_position_changed.emit(current_position_index)
	update_navigation_ui()
	print("CameraRig: Transition completed to position ", current_position_index + 1)

# =============================================================================
# NAVIGATION UI
# =============================================================================

func create_navigation_ui():
	# Create UI container
	nav_ui = Control.new()
	nav_ui.name = "CameraNavUI"
	nav_ui.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	nav_ui.position = Vector2(20, -120)
	nav_ui.size = Vector2(400, 100)
	
	# Create buttons container
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	nav_ui.add_child(hbox)
	
	# Previous button
	prev_button = Button.new()
	prev_button.text = "◀ PREV"
	prev_button.custom_minimum_size = Vector2(80, 40)
	prev_button.pressed.connect(navigate_previous)
	hbox.add_child(prev_button)
	
	# Position label
	position_label = Label.new()
	position_label.text = "1/1"
	position_label.add_theme_color_override("font_color", Color.WHITE)
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position_label.custom_minimum_size = Vector2(60, 40)
	hbox.add_child(position_label)
	
	# Next button
	next_button = Button.new()
	next_button.text = "NEXT ▶"
	next_button.custom_minimum_size = Vector2(80, 40)
	next_button.pressed.connect(navigate_next)
	hbox.add_child(next_button)
	
	# Reset button
	reset_button = Button.new()
	reset_button.text = "⟲ RESET"
	reset_button.custom_minimum_size = Vector2(80, 40)
	reset_button.pressed.connect(reset_camera)
	hbox.add_child(reset_button)
	
	# Add to scene tree (find UI layer)
	var main_scene = get_tree().current_scene
	var ui_layer = main_scene.get_node_or_null("UI Menu")
	if ui_layer:
		ui_layer.add_child(nav_ui)
	else:
		# Fallback: add to main scene
		main_scene.add_child(nav_ui)
	
	print("CameraRig: Navigation UI created")

func update_navigation_ui():
	if not position_label:
		return
	
	var total = max(1, camera_positions.size())
	position_label.text = str(current_position_index + 1) + "/" + str(total)
	
	# Enable/disable buttons based on availability
	if prev_button:
		prev_button.disabled = is_transitioning
	if next_button:
		next_button.disabled = is_transitioning

# Enhanced navigation UI with focus toggle and source information
func create_enhanced_navigation_ui():
	var total_camera_count = all_camera_positions.size()
	if total_camera_count <= 1:
		print("CameraRig: Enhanced navigation UI requires multiple camera positions")
		return
	
	# Clean up existing UI
	if nav_ui and is_instance_valid(nav_ui):
		nav_ui.queue_free()
		nav_ui = null
	
	# Create main container
	nav_ui = Control.new()
	nav_ui.name = "CameraNavigationUI"
	nav_ui.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	nav_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create horizontal container for buttons and label
	var h_container = HBoxContainer.new()
	h_container.add_theme_constant_override("separation", 10)
	h_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Create Focus Mode Toggle button
	focus_toggle_button = Button.new()
	update_focus_button_appearance()
	focus_toggle_button.custom_minimum_size = Vector2(100, 80)
	focus_toggle_button.add_theme_font_size_override("font_size", 24)
	focus_toggle_button.pressed.connect(_on_focus_toggle_pressed)
	h_container.add_child(focus_toggle_button)
	
	# Create Previous button
	prev_button = Button.new()
	prev_button.text = "◀"
	prev_button.custom_minimum_size = Vector2(80, 80)
	prev_button.add_theme_font_size_override("font_size", 32)
	prev_button.pressed.connect(_on_enhanced_previous_pressed)
	h_container.add_child(prev_button)
	
	# Create position label with source info
	position_label = Label.new()
	position_label.text = "1/" + str(total_camera_count)
	position_label.custom_minimum_size = Vector2(160, 80)  # Wider for source info
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	position_label.add_theme_font_size_override("font_size", 24)
	position_label.add_theme_color_override("font_color", Color.WHITE)
	position_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	position_label.add_theme_constant_override("shadow_offset_x", 2)
	position_label.add_theme_constant_override("shadow_offset_y", 2)
	h_container.add_child(position_label)
	
	# Create Next button
	next_button = Button.new()
	next_button.text = "▶"
	next_button.custom_minimum_size = Vector2(80, 80)
	next_button.add_theme_font_size_override("font_size", 32)
	next_button.pressed.connect(_on_enhanced_next_pressed)
	h_container.add_child(next_button)
	
	# Create Reset button
	reset_button = Button.new()
	reset_button.text = "⟲"
	reset_button.custom_minimum_size = Vector2(80, 80)
	reset_button.add_theme_font_size_override("font_size", 32)
	reset_button.pressed.connect(_on_enhanced_reset_pressed)
	h_container.add_child(reset_button)
	
	# Add container to nav_ui FIRST
	nav_ui.add_child(h_container)
	
	# Add to scene tree
	var main_scene = get_tree().current_scene
	var ui_layer = main_scene.get_node_or_null("UI Menu")
	if ui_layer:
		ui_layer.add_child(nav_ui)
	else:
		# Fallback: add to main scene
		main_scene.add_child(nav_ui)
	nav_ui.z_index = 99
	
	# Position the container after adding to scene tree
	h_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	
	# Update initial button states
	update_enhanced_navigation_ui()
	
	print("CameraRig: Enhanced navigation UI created with ", total_camera_count, " positions")

# Update the enhanced navigation UI state with source information
func update_enhanced_navigation_ui():
	var total_camera_count = all_camera_positions.size()
	if not position_label or not prev_button or not next_button or not reset_button:
		return
	
	# Update position label with source info
	var current_source = "Unknown"
	if current_position_index >= 0 and current_position_index < all_camera_positions.size():
		current_source = all_camera_positions[current_position_index].get("source", "Unknown")
	
	position_label.text = str(current_position_index + 1) + "/" + str(total_camera_count) + "\n(" + current_source + ")"
	
	# Update button states - with looping, buttons are always enabled when not transitioning
	var can_navigate = not is_transitioning
	prev_button.disabled = not can_navigate
	next_button.disabled = not can_navigate
	reset_button.disabled = not can_navigate
	if focus_toggle_button:
		focus_toggle_button.disabled = not can_navigate
	
	# Visual feedback for disabled state
	if is_transitioning:
		prev_button.modulate = Color.GRAY
		next_button.modulate = Color.GRAY
		reset_button.modulate = Color.GRAY
		if focus_toggle_button: focus_toggle_button.modulate = Color.GRAY
	else:
		prev_button.modulate = Color.WHITE
		next_button.modulate = Color.WHITE
		reset_button.modulate = Color.WHITE
		if focus_toggle_button: focus_toggle_button.modulate = Color.WHITE
	
	# Update focus button appearance
	update_focus_button_appearance()

# Update focus button appearance based on current state
func update_focus_button_appearance():
	if not focus_toggle_button:
		return
	
	if focus_mode_enabled:
		focus_toggle_button.text = "><"
		focus_toggle_button.add_theme_color_override("font_color", Color.LIME_GREEN)
		focus_toggle_button.tooltip_text = "Focus Mode: ON\nCamera looks at target\nClick to enable FREE mode"
	else:
		focus_toggle_button.text = "<>"
		focus_toggle_button.add_theme_color_override("font_color", Color.ORANGE)
		focus_toggle_button.tooltip_text = "Focus Mode: OFF\nCamera moves freely\nClick to enable FOCUS mode"

# Enhanced UI button handlers
func _on_enhanced_previous_pressed():
	if is_transitioning:
		print("CameraRig: Navigation blocked - transition in progress")
		return
	navigate_enhanced_previous()

func _on_enhanced_next_pressed():
	if is_transitioning:
		print("CameraRig: Navigation blocked - transition in progress")
		return
	navigate_enhanced_next()

func _on_enhanced_reset_pressed():
	if is_transitioning:
		print("CameraRig: Reset blocked - transition in progress")
		return
	print("CameraRig: Enhanced reset button pressed")
	# Reset to current enhanced position
	if current_position_index >= 0 and current_position_index < all_camera_positions.size():
		move_to_enhanced_position_smoothly(current_position_index)

func _on_focus_toggle_pressed():
	if is_transitioning:
		print("CameraRig: Focus toggle blocked - transition in progress")
		return
	
	focus_mode_enabled = !focus_mode_enabled
	print("CameraRig: Focus mode ", "ENABLED" if focus_mode_enabled else "DISABLED")
	
	# Update button appearance
	update_focus_button_appearance()
	
	# If focus mode was just enabled, establish focus target
	if focus_mode_enabled:
		establish_enhanced_focus_target()
		if has_focus_target:
			apply_enhanced_focus()
	else:
		# Focus mode disabled - camera is now free
		has_focus_target = false
		print("CameraRig: Camera now operates in FREE mode")

# =============================================================================
# SPHERICAL ROTATION SYSTEM
# =============================================================================

# Apply rotation using spherical coordinates to prevent gimbal lock
func _apply_spherical_rotation():
	# Convert spherical coordinates to rotation
	# Yaw is rotation around Y-axis, pitch is rotation around X-axis
	rotation_degrees.y = orbit_yaw
	rotation_degrees.x = orbit_pitch
	rotation_degrees.z = 0.0  # Keep roll at zero

# Update spherical coordinates from current rotation (for position switching)
func _update_spherical_from_rotation():
	orbit_yaw = rotation_degrees.y
	orbit_pitch = rotation_degrees.x

# =============================================================================
# FOCUS/LOCK-ON SYSTEM
# =============================================================================

# Detect and register focus targets in the scene
func detect_focus_targets():
	if not focus_enabled or not auto_detect_focus_targets:
		return
	
	focus_targets.clear()
	
	# Find nodes by group names
	for group_name in focus_target_groups:
		var nodes_in_group = get_tree().get_nodes_in_group(group_name)
		for node in nodes_in_group:
			if node is Node3D:
				focus_targets.append(node as Node3D)
	
	# Fallback: Find nodes by name patterns (for test cubes)
	if focus_targets.is_empty():
		_find_focus_targets_by_name(get_tree().current_scene)
	
	print("CameraRig: Detected ", focus_targets.size(), " focus targets")
	
	# Update UI to show focus targets
	update_focus_ui()

# Recursively find nodes with focus-worthy names
func _find_focus_targets_by_name(node: Node):
	if node is Node3D:
		var node_name = node.name.to_lower()
		if (node_name.contains("cube") or 
			node_name.contains("target") or 
			node_name.contains("object") or
			node_name.contains("interest")):
			focus_targets.append(node as Node3D)
			print("CameraRig: Found focus target: ", node.name)
	
	for child in node.get_children():
		_find_focus_targets_by_name(child)

# Focus on a specific target by index
func focus_on_target(target_index: int):
	if not focus_enabled or target_index < 0 or target_index >= focus_targets.size():
		return
	
	var target = focus_targets[target_index]
	if not is_instance_valid(target):
		print("CameraRig: Focus target is invalid, removing from list")
		focus_targets.erase(target)
		return
	
	focus_on_node(target)

# Focus on a specific Node3D
func focus_on_node(target: Node3D):
	if not focus_enabled or not is_instance_valid(target):
		return
	
	print("CameraRig: Focusing on target: ", target.name, " at position: ", target.global_position)
	
	current_focus_target = target
	is_focus_locked = true
	
	# Calculate optimal position (camera should be offset from target)
	var target_position = target.global_position
	var offset = Vector3(0, 2, 8)  # 2 units up, 8 units back from target
	var camera_position = target_position + offset
	
	# Animate to focus position
	_start_focus_transition(camera_position, target_position)

# Start smooth transition to focus on target
func _start_focus_transition(camera_position: Vector3, target_position: Vector3):
	if focus_transition_tween:
		focus_transition_tween.kill()
	
	is_transitioning = true
	focus_transition_tween = create_tween()
	focus_transition_tween.set_parallel(true)
	
	# Move camera rig to the calculated position
	focus_transition_tween.tween_property(self, "global_position", camera_position, focus_transition_duration)
	
	# Calculate rotation to look at target
	var look_direction = (target_position - camera_position).normalized()
	var target_rotation = _calculate_look_at_rotation(look_direction)
	focus_transition_tween.tween_property(self, "rotation_degrees", target_rotation, focus_transition_duration)
	
	# Reset zoom to a good viewing distance
	var focus_zoom = clamp(8.0, zoom_min, zoom_max)
	focus_transition_tween.tween_property(camera, "position:z", focus_zoom, focus_transition_duration)
	current_zoom = focus_zoom
	
	# Complete the transition
	focus_transition_tween.tween_callback(_on_focus_transition_complete).set_delay(focus_transition_duration)

# Calculate rotation to look at a direction
func _calculate_look_at_rotation(direction: Vector3) -> Vector3:
	# Calculate yaw (horizontal rotation)
	var yaw = rad_to_deg(atan2(-direction.x, -direction.z))
	
	# Calculate pitch (vertical rotation) 
	var horizontal_distance = sqrt(direction.x * direction.x + direction.z * direction.z)
	var pitch = rad_to_deg(atan2(direction.y, horizontal_distance))
	
	return Vector3(pitch, yaw, 0)

func _on_focus_transition_complete():
	is_transitioning = false
	
	# Update spherical coordinates to match final rotation
	_update_spherical_from_rotation()
	
	print("CameraRig: Focus transition completed on target: ", current_focus_target.name if current_focus_target else "None")

# Clear current focus and return to free camera
func clear_focus():
	if not is_focus_locked:
		return
	
	print("CameraRig: Clearing focus lock")
	current_focus_target = null
	is_focus_locked = false

# Navigate to next focus target
func focus_next_target():
	if focus_targets.is_empty():
		return
	
	var current_index = -1
	if current_focus_target:
		current_index = focus_targets.find(current_focus_target)
	
	var next_index = (current_index + 1) % focus_targets.size()
	focus_on_target(next_index)

# Navigate to previous focus target
func focus_previous_target():
	if focus_targets.is_empty():
		return
	
	var current_index = -1
	if current_focus_target:
		current_index = focus_targets.find(current_focus_target)
	
	var prev_index = (current_index - 1 + focus_targets.size()) % focus_targets.size()
	focus_on_target(prev_index)

# Update focus-related UI elements
func update_focus_ui():
	# This could add focus target buttons to the UI
	# For now, we'll use keyboard shortcuts
	pass

# Enhanced focus functions from CameraManager
func establish_enhanced_focus_target():
	# Try to get focus from current camera position data first
	if current_position_index >= 0 and current_position_index < all_camera_positions.size():
		var camera_data = all_camera_positions[current_position_index]
		if camera_data.has("target_position"):
			current_focus_target_pos = camera_data["target_position"]
			has_focus_target = true
			print("CameraRig: Established enhanced focus target from camera data: ", current_focus_target_pos)
			return
	
	# If no camera data target, try raycast
	if use_raycast_focus:
		var raycast_target = get_raycast_focus_point()
		if raycast_target != Vector3.ZERO:
			current_focus_target_pos = raycast_target
			has_focus_target = true
			print("CameraRig: Established enhanced focus target from raycast: ", current_focus_target_pos)
			return
	
	# No valid focus found
	has_focus_target = false
	print("CameraRig: Could not establish valid enhanced focus target")

# Use raycast to determine what the camera should focus on
func get_raycast_focus_point() -> Vector3:
	if not camera:
		return Vector3.ZERO
	
	# Get the camera's current direction from the rig's transform
	var camera_transform = global_transform
	var ray_start = camera_transform.origin
	var ray_direction = -camera_transform.basis.z  # Forward direction
	var ray_end = ray_start + (ray_direction * raycast_length)
	
	# Create raycast query
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [self]  # Don't hit the camera rig itself
	
	# Perform raycast
	var result = space_state.intersect_ray(query)
	
	if not result.is_empty():
		print("CameraRig: Raycast hit: ", result.position, " on ", result.collider.name)
		return result.position
	else:
		print("CameraRig: Raycast missed - no focus point found")
		return Vector3.ZERO

# Apply enhanced focus behavior if focus mode is enabled
func apply_enhanced_focus():
	if not focus_mode_enabled or not camera:
		return
	
	# Determine focus target
	var focus_target = current_focus_target_pos
	
	# If using raycast focus, cast a ray to find focus point
	if use_raycast_focus:
		focus_target = get_raycast_focus_point()
		if focus_target == Vector3.ZERO:
			# Raycast failed, fall back to current focus target
			focus_target = current_focus_target_pos
	
	# Only apply focus if we have a valid target
	if has_focus_target and focus_target != Vector3.ZERO:
		apply_look_at_rotation(global_position, focus_target)

# Apply look_at rotation while respecting CameraRig structure
func apply_look_at_rotation(camera_pos: Vector3, target_pos: Vector3):
	# CRITICAL FIX: Prevent look_at() if camera and target are at the same position
	if camera_pos.is_equal_approx(target_pos):
		print("CameraRig: WARNING - look_at() failed. Camera and target positions are identical.")
		return
	
	print("CameraRig: Applying enhanced look_at - Camera: ", camera_pos, ", Target: ", target_pos)
	
	# Calculate look at rotation and apply it directly to the rig
	var look_at_rotation = calculate_enhanced_look_at_rotation(camera_pos, target_pos)
	rotation_degrees = look_at_rotation
	
	# Update spherical coordinates to match
	_update_spherical_from_rotation()

# Calculate look at rotation from position to target (enhanced version)
func calculate_enhanced_look_at_rotation(from_pos: Vector3, to_pos: Vector3) -> Vector3:
	var direction = (to_pos - from_pos).normalized()
	
	# Calculate pitch (X rotation)
	var pitch = rad_to_deg(asin(-direction.y))
	
	# Calculate yaw (Y rotation)
	var yaw = rad_to_deg(atan2(direction.x, direction.z))
	
	# Roll is typically 0 for camera look-at
	var roll = 0.0
	
	return Vector3(pitch, yaw, roll)

# =============================================================================
# COLLISION AVOIDANCE SYSTEM
# =============================================================================

# Process collision avoidance (called every frame during position updates)
func _process(_delta):
	if collision_enabled and not is_transitioning:
		_check_and_resolve_collisions()

# Check for collisions and adjust camera position if needed
func _check_and_resolve_collisions():
	var world = get_world_3d()
	if not world:
		return
	
	var space_state = world.direct_space_state
	var camera_world_position = camera.global_position
	
	# Check for ground collision (downward raycast)
	_check_ground_collision(space_state, camera_world_position)
	
	# Check for object collisions (sphere cast around camera)
	_check_object_collisions(space_state, camera_world_position)

# Check if camera is too close to the ground
func _check_ground_collision(space_state: PhysicsDirectSpaceState3D, camera_pos: Vector3):
	# Cast ray downward from camera position
	var ray_query = PhysicsRayQueryParameters3D.create(
		camera_pos,
		camera_pos + Vector3.DOWN * collision_check_distance
	)
	ray_query.collision_mask = collision_layers
	
	var result = space_state.intersect_ray(ray_query)
	if result.is_empty():
		return
	
	# Calculate height above ground
	var ground_point = result["position"] as Vector3
	var height_above_ground = camera_pos.y - ground_point.y
	
	# If too close to ground, adjust rig position upward
	if height_above_ground < min_ground_height:
		var adjustment_needed = min_ground_height - height_above_ground
		var new_rig_position = global_position + Vector3.UP * adjustment_needed
		
		# Apply adjustment smoothly
		global_position = global_position.lerp(new_rig_position, collision_smoothing)
		
		# Debug output
		if height_above_ground < min_ground_height * 0.8:  # Only print when very close
			print("CameraRig: Adjusting camera height - too close to ground (height: ", "%.1f" % height_above_ground, ")")

# Check for collisions with objects (buildings, vehicles, etc.)
func _check_object_collisions(space_state: PhysicsDirectSpaceState3D, camera_pos: Vector3):
	# Create sphere query around camera position
	var sphere_query = PhysicsShapeQueryParameters3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = collision_radius
	sphere_query.shape = sphere_shape
	sphere_query.transform.origin = camera_pos
	sphere_query.collision_mask = collision_layers
	
	var collisions = space_state.intersect_shape(sphere_query)
	if collisions.is_empty():
		return
	
	# Find the closest collision and calculate pushback direction
	var closest_collision = null
	var closest_distance = INF
	
	for collision in collisions:
		var collision_point = collision["point"] if "point" in collision else Vector3.ZERO
		var distance = camera_pos.distance_to(collision_point)
		
		if distance < closest_distance:
			closest_distance = distance
			closest_collision = collision
	
	if closest_collision:
		_resolve_object_collision(camera_pos, closest_collision)

# Resolve collision with an object by pushing camera away
func _resolve_object_collision(camera_pos: Vector3, collision: Dictionary):
	var collider = collision["collider"] as Node3D
	var collision_point = collision.get("point", Vector3.ZERO) as Vector3
	
	# Calculate pushback direction (away from collision point)
	var pushback_direction: Vector3
	
	if collision_point != Vector3.ZERO:
		# Use collision point if available
		pushback_direction = (camera_pos - collision_point).normalized()
	else:
		# Fallback: use direction away from collider center
		pushback_direction = (camera_pos - collider.global_position).normalized()
	
	# Calculate how far to push back
	var required_distance = collision_radius + 0.5  # Extra margin
	var current_distance = camera_pos.distance_to(collision_point if collision_point != Vector3.ZERO else collider.global_position)
	var pushback_amount = required_distance - current_distance
	
	if pushback_amount > 0:
		# Calculate new rig position (move rig to move camera)
		var camera_local_offset = camera.position  # Camera's offset from rig
		var new_camera_pos = camera_pos + pushback_direction * pushback_amount
		var new_rig_position = new_camera_pos - transform.basis * camera_local_offset
		
		# Apply adjustment smoothly
		global_position = global_position.lerp(new_rig_position, collision_smoothing)
		
		# Debug output
		print("CameraRig: Avoiding collision with ", collider.name, " (pushback: ", "%.1f" % pushback_amount, ")")

# Validate a position before moving to it (used by transitions)
func _validate_position(target_position: Vector3) -> Vector3:
	if not collision_enabled:
		return target_position
	
	var world = get_world_3d()
	if not world:
		return target_position
	
	var space_state = world.direct_space_state
	
	# Check ground collision for the target position
	var camera_world_pos = target_position + transform.basis * Vector3(0, 0, current_zoom)
	
	# Ground check
	var ray_query = PhysicsRayQueryParameters3D.create(
		camera_world_pos,
		camera_world_pos + Vector3.DOWN * collision_check_distance
	)
	ray_query.collision_mask = collision_layers
	
	var ground_result = space_state.intersect_ray(ray_query)
	if not ground_result.is_empty():
		var ground_point = ground_result["position"] as Vector3
		var height_above_ground = camera_world_pos.y - ground_point.y
		
		if height_above_ground < min_ground_height:
			# Adjust target position upward
			var adjustment = min_ground_height - height_above_ground
			target_position += Vector3.UP * adjustment
			print("CameraRig: Pre-validating position - adjusting for ground clearance")
	
	return target_position

# =============================================================================
# TRAFFIC LIGHT DETECTION & POSITION BUILDING
# =============================================================================

# Build comprehensive camera position list (traffic lights first, then config)
func build_complete_camera_position_list():
	all_camera_positions.clear()
	config_camera_count = 0
	traffic_light_camera_count = 0
	
	print("CameraRig: Building complete camera position list...")
	
	# PRIORITY 1: Detect and add traffic light positions FIRST
	if auto_detect_traffic_lights:
		detect_and_add_traffic_light_positions()
	
	# PRIORITY 2: Add config-based camera positions AFTER traffic lights
	if level_config and level_config.has_method("get_camera_count"):
		config_camera_count = level_config.get_camera_count()
		print("CameraRig: Adding ", config_camera_count, " positions from level config")
		
		for i in range(config_camera_count):
			var pos = level_config.get_camera_position(i)
			var rot = level_config.get_camera_rotation(i)
			all_camera_positions.append({
				"position": pos,
				"rotation": rot,
				"source": "Config",
				"config_index": i
			})
			print("CameraRig: - Config position ", i + 1, ": ", pos)
	else:
		print("CameraRig: No valid level config for camera positions")
	
	# Update the camera_positions array for compatibility
	camera_positions.clear()
	for pos_data in all_camera_positions:
		camera_positions.append(pos_data)
	
	print("CameraRig: Complete camera position list built:")
	print("CameraRig: - Total positions: ", all_camera_positions.size())
	print("CameraRig: - Traffic light positions (priority): ", traffic_light_camera_count)
	print("CameraRig: - Config positions: ", config_camera_count)

# Detect all TrafficLight nodes and add overhead camera positions
func detect_and_add_traffic_light_positions():
	print("CameraRig: Detecting TrafficLight nodes in scene...")
	
	# Get the current scene tree
	var current_scene = get_tree().current_scene
	if not current_scene:
		print("CameraRig: No current scene found")
		return
	
	# Search for all nodes with TrafficLight.gd script
	var traffic_lights = find_traffic_light_nodes(current_scene)
	
	print("CameraRig: Found ", traffic_lights.size(), " TrafficLight nodes")
	
	for i in range(traffic_lights.size()):
		var traffic_light = traffic_lights[i]
		var light_position = traffic_light.global_position
		
		# Calculate optimal overhead camera position for this traffic light
		var camera_position = calculate_overhead_camera_position(light_position)
		
		# Calculate rotation to look down at the traffic light/intersection
		var camera_rotation = calculate_look_down_rotation(camera_position, light_position)
		
		all_camera_positions.append({
			"position": camera_position,
			"rotation": camera_rotation,
			"source": "Traffic Light",
			"traffic_light_node": traffic_light,
			"traffic_light_name": traffic_light.name,
			"target_position": light_position
		})
		
		traffic_light_camera_count += 1
		print("CameraRig: - Traffic light ", i + 1, " (", traffic_light.name, "): Camera at ", camera_position, " looking at ", light_position)

# Calculate optimal overhead camera position for a traffic light
func calculate_overhead_camera_position(traffic_light_pos: Vector3) -> Vector3:
	# Create offset vector (back and up from traffic light)
	var back_offset = Vector3(0, 0, traffic_light_camera_distance)  # Move back
	var up_offset = Vector3(0, traffic_light_camera_height, 0)      # Move up
	
	# Combine offsets for final camera position
	var camera_position = traffic_light_pos + back_offset + up_offset
	
	print("CameraRig: Calculated overhead position - Traffic light: ", traffic_light_pos, ", Camera: ", camera_position)
	return camera_position

# Calculate camera rotation to look down at traffic light intersection
func calculate_look_down_rotation(camera_pos: Vector3, target_pos: Vector3) -> Vector3:
	# Calculate direction from camera to target
	var direction = (target_pos - camera_pos).normalized()
	
	# Calculate pitch (X rotation) - looking down
	var pitch = rad_to_deg(asin(-direction.y))
	
	# Calculate yaw (Y rotation) - horizontal orientation
	var yaw = rad_to_deg(atan2(direction.x, direction.z))
	
	# No roll for standard camera
	var roll = 0.0
	
	# Apply the desired look-down angle for better intersection view
	pitch = clamp(pitch + traffic_light_look_down_angle, -89.0, 89.0)
	
	var final_rotation = Vector3(pitch, yaw, roll)
	print("CameraRig: Calculated look-down rotation - Pitch: ", pitch, "°, Yaw: ", yaw, "°")
	
	return final_rotation

# Recursively search for nodes with TrafficLight.gd script
func find_traffic_light_nodes(node: Node) -> Array[Node]:
	var traffic_lights: Array[Node] = []
	
	# Check if current node has TrafficLight.gd script
	if node.get_script() != null:
		var script_path = node.get_script().resource_path
		if script_path.ends_with("TrafficLight.gd"):
			traffic_lights.append(node)
			print("CameraRig: Found TrafficLight node: ", node.name, " at ", node.global_position)
	
	# Recursively search children
	for child in node.get_children():
		traffic_lights.append_array(find_traffic_light_nodes(child))
	
	return traffic_lights

# Enhanced position movement functions for all_camera_positions array
func move_to_enhanced_position_immediately(index: int):
	if not _is_valid_enhanced_position_index(index):
		return
	
	current_position_index = index
	var pos_data = all_camera_positions[index]
	
	# Set rig position and rotation
	global_position = pos_data.get("position", Vector3.ZERO)
	rotation_degrees = pos_data.get("rotation", Vector3.ZERO)
	
	# Update spherical coordinates to match the new rotation
	_update_spherical_from_rotation()
	
	# Reset zoom to default
	current_zoom = default_zoom
	camera.position.z = current_zoom
	
	var source = pos_data.get("source", "Unknown")
	print("CameraRig: Moved to position ", index + 1, " (", source, ") - Pos: ", global_position, ", Rot: ", rotation_degrees)
	
	camera_position_changed.emit(index)
	update_enhanced_navigation_ui()

func move_to_enhanced_position_smoothly(index: int):
	if not _is_valid_enhanced_position_index(index) or is_transitioning:
		return
	
	current_position_index = index
	var pos_data = all_camera_positions[index]
	var target_position = pos_data.get("position", Vector3.ZERO)
	var target_rotation = pos_data.get("rotation", Vector3.ZERO)
	var source = pos_data.get("source", "Unknown")
	
	print("CameraRig: Smoothly transitioning to position ", index + 1, " (", source, ")")
	
	_start_smooth_transition(target_position, target_rotation)

func navigate_enhanced_next():
	if is_transitioning or all_camera_positions.is_empty():
		return
	
	var next_index = (current_position_index + 1) % all_camera_positions.size()
	move_to_enhanced_position_smoothly(next_index)

func navigate_enhanced_previous():
	if is_transitioning or all_camera_positions.is_empty():
		return
	
	var prev_index = (current_position_index - 1 + all_camera_positions.size()) % all_camera_positions.size()
	move_to_enhanced_position_smoothly(prev_index)

func _is_valid_enhanced_position_index(index: int) -> bool:
	return index >= 0 and index < all_camera_positions.size()

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _is_valid_position_index(index: int) -> bool:
	return index >= 0 and index < camera_positions.size()

# Get current camera for external access
func get_camera() -> Camera3D:
	return camera

# Check if camera system is ready
func is_ready() -> bool:
	return camera != null

# Get current zoom level
func get_zoom_level() -> float:
	return current_zoom

# Get current position index
func get_current_position_index() -> int:
	return current_position_index

# Cleanup function
func cleanup():
	if nav_ui and is_instance_valid(nav_ui):
		nav_ui.queue_free()
	
	if transition_tween:
		transition_tween.kill()
