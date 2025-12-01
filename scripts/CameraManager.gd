extends Node
# Note: Avoiding class_name due to environment compatibility issues

# =============================================================================
# CAMERA MANAGER
# =============================================================================
# Dedicated system for managing camera positioning, navigation, and transitions
# Handles FlyCamera integration, UI creation, and smooth transitions
# 
# Usage:
#   var camera_manager = CameraManager.new()
#   add_child(camera_manager)
#   camera_manager.setup_camera_system(fly_camera, level_config)
# =============================================================================

# Camera system references
var fly_camera: CharacterBody3D
var level_config: Resource

# UI components
var camera_nav_container: Control
var prev_camera_button: Button
var next_camera_button: Button
var reset_camera_button: Button
var camera_position_label: Label

# Navigation state
var current_camera_index: int = 0
var is_camera_transitioning: bool = false
var camera_transition_tween: Tween

# Enhanced camera position system
var all_camera_positions: Array[Dictionary] = []  # Combined config + traffic light positions
var config_camera_count: int = 0  # Number from config
var traffic_light_camera_count: int = 0  # Number from detected traffic lights

# Camera positioning settings for traffic lights
@export var traffic_light_camera_height: float = 15.0  # Height above traffic light
@export var traffic_light_camera_distance: float = 20.0  # Distance back from traffic light
@export var traffic_light_look_down_angle: float = -45.0  # Downward angle in degrees

# Camera focus system
@export var focus_mode_enabled: bool = true  # Toggle between free and focused camera modes
@export var use_raycast_focus: bool = false  # Use raycast to determine focus point dynamically
@export var raycast_length: float = 100.0  # Maximum raycast distance for focus detection
var current_focus_target: Vector3  # Current point the camera should look at
var has_focus_target: bool = false  # Whether we have a valid focus target
var focus_toggle_button: Button  # UI button to toggle focus mode

# Transition settings (configurable from parent)
@export var camera_transition_duration: float = 2.0
@export var camera_transition_easing: CameraEasingType = CameraEasingType.EASE_IN_OUT

# =============================================================================
# ORBIT CAMERA CONTROL SYSTEM
# =============================================================================

# Orbit control settings
@export var orbit_enabled: bool = true
@export var zoom_min: float = 5.0
@export var zoom_max: float = 50.0  
@export var zoom_speed: float = 2.0
@export var rotation_speed: float = 1.0
@export var orbit_damping: float = 0.1

# Orbit state tracking
var is_in_manual_orbit_mode: bool = false
var current_orbit_center: Vector3
var current_orbit_distance: float = 15.0  # Default distance
var current_orbit_yaw: float = 0.0
var current_orbit_pitch: float = -30.0
var is_dragging: bool = false

# Touch/Mouse input tracking
var touch_points: Dictionary = {}
var last_mouse_position: Vector2
var initial_pinch_distance: float = 0.0

# Camera easing types enum
enum CameraEasingType {
	EASE_LINEAR,
	EASE_IN,
	EASE_OUT,
	EASE_IN_OUT,
	EASE_IN_OUT_SINE,
	EASE_IN_OUT_CUBIC,
	EASE_IN_OUT_BACK
}

# =============================================================================
# PUBLIC API
# =============================================================================

# Initialize the camera system with FlyCamera and level configuration
func setup_camera_system(camera: CharacterBody3D, config: Resource):
	#print("CameraManager: setup_camera_system called")
	#print("CameraManager: FlyCamera provided: ", camera != null)
	#print("CameraManager: Config provided: ", config != null)
	
	fly_camera = camera
	level_config = config
	current_camera_index = 0
	is_camera_transitioning = false
	
	# Build comprehensive camera position list (traffic lights first, then config)
	build_complete_camera_position_list()
	
	var total_camera_count = all_camera_positions.size()
	#print("CameraManager: Total camera positions available: ", total_camera_count)
	#print("CameraManager: - From traffic lights (prioritized): ", traffic_light_camera_count)
	#print("CameraManager: - From config: ", config_camera_count)
	
	if total_camera_count > 0:
		#print("CameraManager: Moving to first camera position (prioritizing traffic lights)...")
		# Move to first camera position (traffic light positions come first)
		move_to_camera_position_immediately(0)
		
		# Create navigation UI if multiple positions exist
		if total_camera_count > 1:
			#print("CameraManager: Creating navigation UI for ", total_camera_count, " positions")
			create_camera_navigation_ui()
	else:
		#print("CameraManager: No camera positions available")\
		pass

# Move camera to specific position without animation
func move_to_camera_position_immediately(index: int):
	#print("CameraManager: move_to_camera_position_immediately called with index: ", index)
	
	if not _validate_camera_index(index):
		#print("CameraManager: ERROR - Failed validation for index: ", index)
		return
	
	#print("CameraManager: Validation passed, proceeding with camera move")
	
	current_camera_index = index
	var camera_data = all_camera_positions[index]
	var target_pos = camera_data["position"]
	var target_rot = camera_data["rotation"]
	var position_source = camera_data.get("source", "unknown")
	
	#print("CameraManager: Target position (", position_source, "): ", target_pos)
	#print("CameraManager: Target rotation: ", target_rot)
	#print("CameraManager: FlyCamera current position: ", fly_camera.global_position)
	#print("CameraManager: FlyCamera current rotation: ", fly_camera.get_rot())
	
	#print("CameraManager: Setting FlyCamera position...")
	fly_camera.global_position = target_pos
	#print("CameraManager: Setting FlyCamera rotation...")
	fly_camera.set_rot(target_rot)
	
	#print("CameraManager: After setting - Position: ", fly_camera.global_position, ", Rotation: ", fly_camera.get_rot())
	
# Initialize orbit system for this camera position (simplified)
	initialize_orbit_from_position_simple(target_pos, target_rot)
	
	# Update UI if it exists
	if camera_nav_container:
		#print("CameraManager: Updating navigation UI")
		update_camera_navigation_ui()
	else:
		#print("CameraManager: No navigation UI to update")
		pass

# Navigate to camera position with smooth transition
func navigate_to_camera_position(index: int):
	if not _validate_camera_index(index) or is_camera_transitioning:
		return
	
	current_camera_index = index
	var camera_data = all_camera_positions[index]
	var target_pos = camera_data["position"]
	var target_rot = camera_data["rotation"]
	var position_source = camera_data.get("source", "unknown")
	
	#print("CameraManager: Navigating to position ", index + 1, " (", position_source, "): ", target_pos, ", rotation: ", target_rot)
	
	_start_smooth_transition(target_pos, target_rot)
	update_camera_navigation_ui()

# Navigate to next camera position (with looping)
func navigate_next():
	if is_camera_transitioning:
		return
	
	var total_camera_count = all_camera_positions.size()
	if total_camera_count == 0:
		return
	
	if current_camera_index < (total_camera_count - 1):
		navigate_to_camera_position(current_camera_index + 1)
	else:
		# Loop to first position
		#print("CameraManager: Looping to first camera position")
		navigate_to_camera_position(0)

# Navigate to previous camera position (with looping)
func navigate_previous():
	if is_camera_transitioning:
		return
	
	var total_camera_count = all_camera_positions.size()
	if total_camera_count == 0:
		return
	
	if current_camera_index > 0:
		navigate_to_camera_position(current_camera_index - 1)
	else:
		# Loop to last position
		var last_index = total_camera_count - 1
		#print("CameraManager: Looping to last camera position")
		navigate_to_camera_position(last_index)

# Get current camera position index
func get_current_camera_index() -> int:
	return current_camera_index

# Check if camera is currently transitioning
func is_transitioning() -> bool:
	return is_camera_transitioning

# Clean up the camera system
func cleanup():
	_cleanup_camera_navigation_ui()
	if camera_transition_tween:
		camera_transition_tween.kill()
		camera_transition_tween = null
	fly_camera = null
	level_config = null
	is_camera_transitioning = false
	current_camera_index = 0
	#print("CameraManager: System cleaned up")

# =============================================================================
# UI MANAGEMENT
# =============================================================================

# Create the camera navigation UI
func create_camera_navigation_ui():
	var total_camera_count = all_camera_positions.size()
	if total_camera_count <= 1:
		#print("CameraManager: Navigation UI requires multiple camera positions")
		return
	
	# Clean up existing UI
	_cleanup_camera_navigation_ui()
	
	# Create main container
	camera_nav_container = Control.new()
	camera_nav_container.name = "CameraNavigationUI"
	camera_nav_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	
	#if get_viewport():
		#camera_nav_container.size = get_viewport().get_visible_rect().size
	
	camera_nav_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camera_nav_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	camera_nav_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create horizontal container for buttons and label
	var h_container = HBoxContainer.new()
	h_container.add_theme_constant_override("separation", 10)
	h_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	
	# Create Focus Mode Toggle button
	focus_toggle_button = Button.new()
	update_focus_button_appearance()
	focus_toggle_button.custom_minimum_size = Vector2(128, 128)
	focus_toggle_button.add_theme_font_size_override("font_size", 36)
	focus_toggle_button.pressed.connect(_on_focus_toggle_pressed)
	h_container.add_child(focus_toggle_button)
	
	# Create Previous button
	prev_camera_button = Button.new()
	prev_camera_button.text = "◀"
	prev_camera_button.custom_minimum_size = Vector2(128, 128)
	prev_camera_button.add_theme_font_size_override("font_size", 48)
	prev_camera_button.pressed.connect(_on_previous_camera_pressed)
	h_container.add_child(prev_camera_button)
	
	# Create position label
	camera_position_label = Label.new()
	camera_position_label.text = "1/" + str(total_camera_count)
	camera_position_label.custom_minimum_size = Vector2(180, 128)  # Wider for source info
	camera_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	camera_position_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	camera_position_label.add_theme_font_size_override("font_size", 32)
	camera_position_label.add_theme_color_override("font_color", Color.WHITE)
	camera_position_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	camera_position_label.add_theme_constant_override("shadow_offset_x", 1)
	camera_position_label.add_theme_constant_override("shadow_offset_y", 1)
	h_container.add_child(camera_position_label)
	
	# Create Next button
	next_camera_button = Button.new()
	next_camera_button.text = "▶"
	next_camera_button.custom_minimum_size = Vector2(128, 128)
	next_camera_button.add_theme_font_size_override("font_size", 48)
	next_camera_button.pressed.connect(_on_next_camera_pressed)
	h_container.add_child(next_camera_button)
	
	# Create Reset button
	reset_camera_button = Button.new()
	reset_camera_button.text = "⟲"
	reset_camera_button.custom_minimum_size = Vector2(128, 128)
	reset_camera_button.add_theme_font_size_override("font_size", 48)
	reset_camera_button.pressed.connect(_on_reset_camera_pressed)
	h_container.add_child(reset_camera_button)
	
	# Add container to camera_nav_container FIRST
	camera_nav_container.add_child(h_container)
	# Add to scene tree
	get_tree().current_scene.add_child(camera_nav_container)
	camera_nav_container.z_index = 99
	
	# THEN set position (after population)
	h_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	#h_container.position.y -= 25
	
	# Update initial button states
	update_camera_navigation_ui()
	
	#print("CameraManager: Navigation UI created with ", total_camera_count, " positions")

# Update the camera navigation UI state
func update_camera_navigation_ui():
	var total_camera_count = all_camera_positions.size()
	if not camera_position_label or not prev_camera_button or not next_camera_button or not reset_camera_button:
		return
	
	# Update position label with source info
	var current_source = "Unknown"
	if current_camera_index >= 0 and current_camera_index < all_camera_positions.size():
		current_source = all_camera_positions[current_camera_index].get("source", "Unknown")
	
	camera_position_label.text = str(current_camera_index + 1) + "/" + str(total_camera_count) + "\n(" + current_source + ")"
	
	# Update button states - with looping, buttons are always enabled when not transitioning
	var can_navigate = not is_camera_transitioning
	prev_camera_button.disabled = not can_navigate
	next_camera_button.disabled = not can_navigate
	reset_camera_button.disabled = not can_navigate
	
	# Visual feedback for disabled state
	if is_camera_transitioning:
		prev_camera_button.modulate = Color.GRAY
		next_camera_button.modulate = Color.GRAY
		reset_camera_button.modulate = Color.GRAY
		if focus_toggle_button: focus_toggle_button.modulate = Color.GRAY
	else:
		prev_camera_button.modulate = Color.WHITE
		next_camera_button.modulate = Color.WHITE
		reset_camera_button.modulate = Color.WHITE
		if focus_toggle_button: focus_toggle_button.modulate = Color.WHITE
	
	# Update focus button appearance
	update_focus_button_appearance()

# =============================================================================
# TRANSITION SYSTEM
# =============================================================================

# Start smooth camera transition with proper rotation capture
func _start_smooth_transition(target_position: Vector3, target_rotation: Vector3):
	# Set transition protection
	is_camera_transitioning = true
	update_camera_navigation_ui()
	
	# Clean up previous tween if it exists
	if camera_transition_tween:
		camera_transition_tween.kill()
	
	camera_transition_tween = create_tween()
	camera_transition_tween.set_parallel(true)
	
	# ENHANCED FIX: Get current rotation directly from FlyCamera's internal nodes
	var current_position = fly_camera.global_position
	var current_rotation = _get_actual_camera_rotation()
	
	# TRANSITION FIX: Ensure target rotation is in the same format as current rotation
	# Don't use raw config rotation - convert it through the FlyCamera system first
	fly_camera.set_rot(Vector3(deg_to_rad(target_rotation.x), deg_to_rad(target_rotation.y), deg_to_rad(target_rotation.z)))
	var normalized_target_rotation = _get_actual_camera_rotation()
	fly_camera.set_rot(Vector3(deg_to_rad(current_rotation.x), deg_to_rad(current_rotation.y), deg_to_rad(current_rotation.z)))
	
	# Debug rotation values
	#print("CameraManager: Starting transition from ", current_position, " to ", target_position)
	#print("CameraManager: Rotating from ", current_rotation, " (degrees) to ", target_rotation, " (degrees)")
	#print("CameraManager: Duration: ", camera_transition_duration, "s, Easing: ", CameraEasingType.keys()[camera_transition_easing])
	
	# Additional debug info
	_debug_camera_state()
	
	# Convert easing type to Godot's Tween types
	var ease_type = _get_godot_ease_type(camera_transition_easing)
	var trans_type = _get_godot_transition_type(camera_transition_easing)
	
	# Animate position
	var pos_tween = camera_transition_tween.tween_method(
		func(pos): fly_camera.global_position = pos,
		current_position,
		target_position,
		camera_transition_duration
	)
	pos_tween.set_ease(ease_type)
	pos_tween.set_trans(trans_type)
	
	# Animate rotation - using normalized rotations to prevent weird intermediate positions
	var rot_tween = camera_transition_tween.tween_method(
		func(rot): fly_camera.set_rot(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))),
		current_rotation,  # Start from actual current rotation (in degrees)
		normalized_target_rotation,  # Use normalized target rotation (in degrees)
		camera_transition_duration
	)
	rot_tween.set_ease(ease_type)
	rot_tween.set_trans(trans_type)
	
	# Calculate 90% completion time for protection release
	var protection_release_time = camera_transition_duration * 0.9
	
	# Release protection when 90% complete
	camera_transition_tween.tween_callback(func(): _release_transition_protection()).set_delay(protection_release_time)
	
	# Final completion callback with orbit initialization
	camera_transition_tween.tween_callback(func(): _on_transition_completed(target_position, target_rotation)).set_delay(camera_transition_duration)

# Release camera transition protection
func _release_transition_protection():
	is_camera_transitioning = false
	update_camera_navigation_ui()
	#print("CameraManager: Transition 90% complete - navigation re-enabled")

# =============================================================================
# PRIVATE HELPERS
# =============================================================================

# Validate camera index
func _validate_camera_index(index: int) -> bool:
	var total_camera_count = all_camera_positions.size()
	if total_camera_count == 0:
		#print("CameraManager: No camera positions available")
		return false
	
	if index < 0 or index >= total_camera_count:
		#print("CameraManager: Camera index ", index, " out of range (0-", total_camera_count - 1, ")")
		return false
	
	if not fly_camera:
		#print("CameraManager: No FlyCamera reference")
		return false
	
	return true

# Clean up navigation UI
func _cleanup_camera_navigation_ui():
	if camera_nav_container:
		camera_nav_container.queue_free()
		camera_nav_container = null
		prev_camera_button = null
		next_camera_button = null
		reset_camera_button = null
		camera_position_label = null
		focus_toggle_button = null

# Button signal handlers
func _on_previous_camera_pressed():
	if is_camera_transitioning:
		#print("CameraManager: Navigation blocked - transition in progress")
		return
	navigate_previous()

func _on_next_camera_pressed():
	if is_camera_transitioning:
		#print("CameraManager: Navigation blocked - transition in progress")
		return
	navigate_next()

func _on_reset_camera_pressed():
	if is_camera_transitioning:
		#print("CameraManager: Reset blocked - transition in progress")
		return
	#print("CameraManager: Reset button pressed")
	reset_to_original_position()

func _on_focus_toggle_pressed():
	if is_camera_transitioning:
		#print("CameraManager: Focus toggle blocked - transition in progress")
		return
	
	focus_mode_enabled = !focus_mode_enabled
	#print("CameraManager: Focus mode ", "ENABLED" if focus_mode_enabled else "DISABLED")
	
	# Update button appearance
	update_focus_button_appearance()
	
	# If focus mode was just enabled, establish focus target
	if focus_mode_enabled:
		establish_focus_target()
		apply_focus_if_enabled()
	else:
		# Focus mode disabled - camera is now free
		has_focus_target = false
		#print("CameraManager: Camera now operates in FREE mode")

# =============================================================================
# EASING CONVERSION HELPERS
# =============================================================================

# Convert custom CameraEasingType to Godot's Tween.EaseType
func _get_godot_ease_type(camera_easing: CameraEasingType) -> Tween.EaseType:
	match camera_easing:
		CameraEasingType.EASE_LINEAR:
			return Tween.EASE_IN  # Linear uses EASE_IN with TRANS_LINEAR
		CameraEasingType.EASE_IN:
			return Tween.EASE_IN
		CameraEasingType.EASE_OUT:
			return Tween.EASE_OUT
		CameraEasingType.EASE_IN_OUT:
			return Tween.EASE_IN_OUT
		CameraEasingType.EASE_IN_OUT_SINE:
			return Tween.EASE_IN_OUT
		CameraEasingType.EASE_IN_OUT_CUBIC:
			return Tween.EASE_IN_OUT
		CameraEasingType.EASE_IN_OUT_BACK:
			return Tween.EASE_IN_OUT
		_:
			return Tween.EASE_IN_OUT

# Convert custom CameraEasingType to Godot's Tween.TransitionType
func _get_godot_transition_type(camera_easing: CameraEasingType) -> Tween.TransitionType:
	match camera_easing:
		CameraEasingType.EASE_LINEAR:
			return Tween.TRANS_LINEAR
		CameraEasingType.EASE_IN:
			return Tween.TRANS_QUART
		CameraEasingType.EASE_OUT:
			return Tween.TRANS_QUART
		CameraEasingType.EASE_IN_OUT:
			return Tween.TRANS_QUART
		CameraEasingType.EASE_IN_OUT_SINE:
			return Tween.TRANS_SINE
		CameraEasingType.EASE_IN_OUT_CUBIC:
			return Tween.TRANS_CUBIC
		CameraEasingType.EASE_IN_OUT_BACK:
			return Tween.TRANS_BACK
		_:
			return Tween.TRANS_QUART

# =============================================================================
# ROTATION DEBUGGING AND CAPTURE
# =============================================================================

# Get actual camera rotation by accessing FlyCamera's internal nodes directly
func _get_actual_camera_rotation() -> Vector3:
	# FlyCamera structure: CharacterBody3D -> _cam_pivot (Node3D) -> _camera (Camera3D)
	# Try to access the internal nodes directly
	var cam_pivot = null
	var camera_node = null
	
	# Search for the pivot node (Node3D child of FlyCamera)
	for child in fly_camera.get_children():
		if child is Node3D and not child is Camera3D:
			cam_pivot = child
			# Find the camera within the pivot
			for grandchild in child.get_children():
				if grandchild is Camera3D:
					camera_node = grandchild
					break
			break
	
	if cam_pivot and camera_node:
		# Get rotations directly from internal nodes (in degrees)
		var yaw = rad_to_deg(cam_pivot.rotation.y)
		var pitch = rad_to_deg(camera_node.rotation.x)
		var roll = 0.0  # FlyCamera doesn't use roll
		
		var actual_rotation = Vector3(pitch, yaw, roll)
		#print("CameraManager DEBUG: Direct node rotation - Pivot Y: ", yaw, "°, Camera X: ", pitch, "°")
		return actual_rotation
	else:
		# Fallback to get_rot() if we can't access internal nodes
		#print("CameraManager WARNING: Could not access FlyCamera internal nodes, using get_rot()")
		var get_rot_result = fly_camera.get_rot()
		return Vector3(rad_to_deg(get_rot_result.x), rad_to_deg(get_rot_result.y), rad_to_deg(get_rot_result.z))

# Debug the current camera state
func _debug_camera_state():
	#print("CameraManager DEBUG: === Camera State Debug ===")
	
	# Method 1: get_rot() (what we were using before)
	var get_rot_result = fly_camera.get_rot()
	var get_rot_degrees = Vector3(rad_to_deg(get_rot_result.x), rad_to_deg(get_rot_result.y), rad_to_deg(get_rot_result.z))
	#print("CameraManager DEBUG: get_rot() returns: ", get_rot_result, " (radians) = ", get_rot_degrees, " (degrees)")
	
	# Method 2: Direct rotation access
	var fly_cam_rotation = fly_camera.rotation_degrees
	#print("CameraManager DEBUG: fly_camera.rotation_degrees: ", fly_cam_rotation)
	
	# Method 3: Internal node access
	for child in fly_camera.get_children():
		#print("CameraManager DEBUG: FlyCamera child: ", child.name, " (", child.get_class(), ") rotation_degrees: ", child.rotation_degrees)
		if child is Node3D:
			for grandchild in child.get_children():
				#print("CameraManager DEBUG:   -> Grandchild: ", grandchild.name, " (", grandchild.get_class(), ") rotation_degrees: ", grandchild.rotation_degrees)
				pass
	
	#print("CameraManager DEBUG: === End Camera State Debug ===")

# =============================================================================
# ORBIT CAMERA CONTROL SYSTEM
# =============================================================================

# Simple orbit initialization without conflicting with camera positioning
func initialize_orbit_from_position_simple(position: Vector3, rotation: Vector3):
	#print("CameraManager: Initializing simple orbit system - Position: ", position, ", Rotation: ", rotation)
	
	# Set orbit center to current camera position (will be used for rotation pivot)
	current_orbit_center = position
	
	# Use the config rotation directly for initial orbit angles (no complex extraction)
	current_orbit_yaw = rotation.y
	current_orbit_pitch = rotation.x
	current_orbit_distance = 15.0  # Default distance
	
	# Clamp values
	current_orbit_distance = clamp(current_orbit_distance, zoom_min, zoom_max)
	current_orbit_pitch = clamp(current_orbit_pitch, -89.0, 89.0)
	
	# Reset manual orbit mode
	is_in_manual_orbit_mode = false
	is_dragging = false
	touch_points.clear()
	
	# Set focus target for traffic lights if available
	if current_camera_index >= 0 and current_camera_index < all_camera_positions.size():
		var camera_data = all_camera_positions[current_camera_index]
		if camera_data.has("target_position"):
			current_focus_target = camera_data["target_position"]
			has_focus_target = true
			#print("CameraManager: Focus target set to: ", current_focus_target)
		else:
			has_focus_target = false
	else:
		has_focus_target = false
	
	#print("CameraManager: Simple orbit initialized - Yaw: ", current_orbit_yaw, "°, Pitch: ", current_orbit_pitch, "°, Distance: ", current_orbit_distance)

# Handle input events for orbit controls
func _input(event):
	# Only process input when orbit is enabled and not transitioning
	if not orbit_enabled or is_camera_transitioning or not fly_camera:
		return
	
	# Mobile touch controls
	if event is InputEventScreenTouch:
		handle_touch_event(event)
	elif event is InputEventScreenDrag:
		handle_touch_drag(event)
	
	# Desktop mouse controls
	elif event is InputEventMouseButton:
		handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(event)

# Handle touch start/end events
func handle_touch_event(event: InputEventScreenTouch):
	if event.pressed:
		touch_points[event.index] = event.position
		#print("CameraManager: Touch started - ID: ", event.index, ", Position: ", event.position)
	else:
		touch_points.erase(event.index)
		#print("CameraManager: Touch ended - ID: ", event.index)
		
		# Reset pinch zoom when touches are released
		if touch_points.size() < 2:
			initial_pinch_distance = 0.0

# Handle touch drag for rotation and pinch zoom
func handle_touch_drag(event: InputEventScreenDrag):
	if not touch_points.has(event.index):
		return
	
	touch_points[event.index] = event.position
	
	if touch_points.size() == 1:
		# Single finger drag = rotate
		apply_orbit_rotation(event.relative)
		is_in_manual_orbit_mode = true
	elif touch_points.size() == 2:
		# Two finger gesture = pinch zoom
		handle_pinch_zoom()

# Handle mouse button events
func handle_mouse_button(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			last_mouse_position = event.position
			#print("CameraManager: Mouse drag started at: ", event.position)
		else:
			is_dragging = false
			#print("CameraManager: Mouse drag ended")
	
	elif event.pressed:
		# Mouse wheel zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			apply_zoom(-zoom_speed)
			is_in_manual_orbit_mode = true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			apply_zoom(zoom_speed)
			is_in_manual_orbit_mode = true

# Handle mouse motion for rotation
func handle_mouse_motion(event: InputEventMouseMotion):
	if is_dragging:
		(event.relative)
		is_in_manual_orbit_mode = true
		last_mouse_position = event.position

# Apply rotation based on input delta
func apply_orbit_rotation(delta: Vector2):
	# Convert screen delta to rotation (inverted Y for natural feel)
	current_orbit_yaw -= delta.x * rotation_speed * 0.1
	current_orbit_pitch += delta.y * rotation_speed * 0.1  # Inverted for natural camera feel
	
	# Clamp pitch to prevent camera flipping
	current_orbit_pitch = clamp(current_orbit_pitch, -89.0, 89.0)
	
	# Wrap yaw to 0-360 range
	if current_orbit_yaw > 360.0:
		current_orbit_yaw -= 360.0
	elif current_orbit_yaw < 0.0:
		current_orbit_yaw += 360.0
	
	# Update camera position
	update_camera_orbit_position()

# Apply zoom based on input delta
func apply_zoom(delta: float):
	current_orbit_distance += delta
	current_orbit_distance = clamp(current_orbit_distance, zoom_min, zoom_max)
	update_camera_orbit_position()

# Handle pinch-to-zoom with two fingers
func handle_pinch_zoom():
	if touch_points.size() != 2:
		return
	
	# Get the two touch positions
	var touch_positions = touch_points.values()
	var current_pinch_distance = touch_positions[0].distance_to(touch_positions[1])
	
	if initial_pinch_distance == 0.0:
		initial_pinch_distance = current_pinch_distance
		return
	
	# Calculate zoom delta based on pinch distance change
	var distance_delta = initial_pinch_distance - current_pinch_distance
	var zoom_delta = distance_delta * zoom_speed * 0.01  # Scale factor for sensitivity
	
	apply_zoom(zoom_delta)
	is_in_manual_orbit_mode = true
	
	# Update initial distance for next frame
	initial_pinch_distance = current_pinch_distance

# Update camera position based on orbit parameters
func update_camera_orbit_position():
	# Convert spherical coordinates to cartesian position
	var yaw_rad = deg_to_rad(current_orbit_yaw)
	var pitch_rad = deg_to_rad(current_orbit_pitch)
	
	# Calculate position using spherical coordinates
	var x = current_orbit_distance * cos(pitch_rad) * cos(yaw_rad)
	var y = current_orbit_distance * sin(pitch_rad)
	var z = current_orbit_distance * cos(pitch_rad) * sin(yaw_rad)
	
	var new_position = current_orbit_center + Vector3(x, y, z)
	
	# Apply position to FlyCamera
	fly_camera.global_position = new_position
	
	# Apply focus logic based on current mode
	apply_focus_if_enabled()

# Calculate look-at rotation from position to target
func calculate_look_at_rotation(from_pos: Vector3, to_pos: Vector3) -> Vector3:
	var direction = (to_pos - from_pos).normalized()
	
	# Calculate pitch (X rotation)
	var pitch = rad_to_deg(asin(-direction.y))
	
	# Calculate yaw (Y rotation)
	var yaw = rad_to_deg(atan2(direction.x, direction.z))
	
	# Roll is typically 0 for camera look-at
	var roll = 0.0
	
	return Vector3(pitch, yaw, roll)

# Reset orbit to original camera position from current index
func reset_to_original_position():
	if current_camera_index < 0 or current_camera_index >= all_camera_positions.size():
		#print("CameraManager: Cannot reset - invalid camera index")
		return
	
	if is_camera_transitioning:
		#print("CameraManager: Cannot reset during transition")
		return
	
	# Get original position from current camera data
	var camera_data = all_camera_positions[current_camera_index]
	var original_pos = camera_data["position"]
	var original_rot = camera_data["rotation"]
	var position_source = camera_data.get("source", "unknown")
	
	#print("CameraManager: Resetting to original position (", position_source, "): ", original_pos, ", rotation: ", original_rot)
	
	# Start smooth transition back to original position
	_start_smooth_transition(original_pos, original_rot)

# Callback when transition is completed
func _on_transition_completed(target_position: Vector3, target_rotation: Vector3):
	#print("CameraManager: Transition completed to ", target_position)
	
	# Initialize orbit system for new position (simplified)
	initialize_orbit_from_position_simple(target_position, target_rotation)

# =============================================================================
# CAMERA POSITION BUILDING SYSTEM
# =============================================================================

# Build comprehensive camera position list (traffic lights first, then config)
func build_complete_camera_position_list():
	all_camera_positions.clear()
	config_camera_count = 0
	traffic_light_camera_count = 0
	
	#print("CameraManager: Building complete camera position list...")
	
	# PRIORITY 1: Detect and add traffic light positions FIRST
	detect_and_add_traffic_light_positions()
	
	# PRIORITY 2: Add config-based camera positions AFTER traffic lights
	if level_config and level_config.has_method("get_camera_count"):
		config_camera_count = level_config.get_camera_count()
		#print("CameraManager: Adding ", config_camera_count, " positions from level config")
		
		for i in range(config_camera_count):
			var pos = level_config.get_camera_position(i)
			var rot = level_config.get_camera_rotation(i)
			all_camera_positions.append({
				"position": pos,
				"rotation": rot,
				"source": "Config",
				"config_index": i
			})
			#print("CameraManager: - Config position ", i + 1, ": ", pos)
	else:
		#print("CameraManager: No valid level config for camera positions")
		pass
	
	#print("CameraManager: Complete camera position list built:")
	#print("CameraManager: - Total positions: ", all_camera_positions.size())
	#print("CameraManager: - Traffic light positions (priority): ", traffic_light_camera_count)
	#print("CameraManager: - Config positions: ", config_camera_count)

# Detect all TrafficLight nodes and add overhead camera positions
func detect_and_add_traffic_light_positions():
	#print("CameraManager: Detecting TrafficLight nodes in scene...")
	
	# Get the current scene tree
	var current_scene = get_tree().current_scene
	if not current_scene:
		#print("CameraManager: No current scene found")
		return
	
	# Search for all nodes with TrafficLight.gd script
	var traffic_lights = find_traffic_light_nodes(current_scene)
	
	#print("CameraManager: Found ", traffic_lights.size(), " TrafficLight nodes")
	
	for i in range(traffic_lights.size()):
		var traffic_light = traffic_lights[i]
		var light_position = traffic_light.global_position
		
		# Calculate optimal overhead camera position for this traffic light
		# Position camera elevated and at distance to provide good intersection overview
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
		#print("CameraManager: - Traffic light ", i + 1, " (", traffic_light.name, "): Camera at ", camera_position, " looking at ", light_position)

# Calculate optimal overhead camera position for a traffic light
func calculate_overhead_camera_position(traffic_light_pos: Vector3) -> Vector3:
	# Create offset vector (back and up from traffic light)
	var back_offset = Vector3(0, 0, traffic_light_camera_distance)  # Move back
	var up_offset = Vector3(0, traffic_light_camera_height, 0)      # Move up
	
	# Combine offsets for final camera position
	var camera_position = traffic_light_pos + back_offset + up_offset
	
	#print("CameraManager: Calculated overhead position - Traffic light: ", traffic_light_pos, ", Camera: ", camera_position)
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
	#print("CameraManager: Calculated look-down rotation - Pitch: ", pitch, "°, Yaw: ", yaw, "°")
	
	return final_rotation

# Recursively search for nodes with TrafficLight.gd script
func find_traffic_light_nodes(node: Node) -> Array[Node]:
	var traffic_lights: Array[Node] = []
	
	# Check if current node has TrafficLight.gd script
	if node.get_script() != null:
		var script_path = node.get_script().resource_path
		if script_path.ends_with("TrafficLight.gd"):
			traffic_lights.append(node)
			#print("CameraManager: Found TrafficLight node: ", node.name, " at ", node.global_position)
	
	# Recursively search children
	for child in node.get_children():
		traffic_lights.append_array(find_traffic_light_nodes(child))
	
	return traffic_lights

# =============================================================================
# FOCUS MODE SYSTEM
# =============================================================================

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

# Apply focus behavior if focus mode is enabled
func apply_focus_if_enabled():
	if not focus_mode_enabled or not fly_camera:
		return
	
	# Determine focus target
	var focus_target = current_focus_target
	
	# If using raycast focus, cast a ray to find focus point
	if use_raycast_focus:
		focus_target = get_raycast_focus_point()
		if focus_target == Vector3.ZERO:
			# Raycast failed, fall back to current focus target
			focus_target = current_focus_target
	
	# Only apply focus if we have a valid target
	if has_focus_target and focus_target != Vector3.ZERO:
		apply_look_at_to_flycamera(fly_camera.global_position, focus_target)

# Establish focus target based on current camera position
func establish_focus_target():
	# Try to get focus from current camera position data first
	if current_camera_index >= 0 and current_camera_index < all_camera_positions.size():
		var camera_data = all_camera_positions[current_camera_index]
		if camera_data.has("target_position"):
			current_focus_target = camera_data["target_position"]
			has_focus_target = true
			#print("CameraManager: Established focus target from camera data: ", current_focus_target)
			return
	
	# If no camera data target, try raycast
	var raycast_target = get_raycast_focus_point()
	if raycast_target != Vector3.ZERO:
		current_focus_target = raycast_target
		has_focus_target = true
		#print("CameraManager: Established focus target from raycast: ", current_focus_target)
		return
	
	# No valid focus found
	has_focus_target = false
	#print("CameraManager: Could not establish valid focus target")

# Use raycast to determine what the camera should focus on
func get_raycast_focus_point() -> Vector3:
	if not fly_camera:
		return Vector3.ZERO
	
	# Get the camera's current direction
	var camera_transform = fly_camera.global_transform
	return get_raycast_focus_point_from_transform(camera_transform.origin, camera_transform.basis.get_euler())

# Use raycast from a specific transform to find a focus point
func get_raycast_focus_point_from_transform(p_pos: Vector3, p_rot_deg: Vector3) -> Vector3:
	if not fly_camera:
		return Vector3.ZERO
	
	# Create a transform from the position and rotation
	var basis = Basis()
	basis = basis.rotated(Vector3.RIGHT, deg_to_rad(p_rot_deg.x))
	basis = basis.rotated(Vector3.UP, deg_to_rad(p_rot_deg.y))
	basis = basis.rotated(Vector3.FORWARD, deg_to_rad(p_rot_deg.z))
	var camera_transform = Transform3D(basis, p_pos)
	
	var ray_start = camera_transform.origin
	var ray_direction = -camera_transform.basis.z  # Forward direction
	var ray_end = ray_start + (ray_direction * raycast_length)
	
	# Create raycast query
	var space_state = fly_camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [fly_camera]  # Don't hit the camera itself
	
	# Perform raycast
	var result = space_state.intersect_ray(query)
	
	if result:
		#print("CameraManager: Raycast hit: ", result.position, " on ", result.collider.name)
		return result.position
	else:
		#print("CameraManager: Raycast missed - no focus point found")
		return Vector3.ZERO

# Apply look_at() to FlyCamera while respecting its internal structure
func apply_look_at_to_flycamera(camera_pos: Vector3, target_pos: Vector3):
	# CRITICAL FIX: Prevent look_at() if camera and target are at the same position
	if camera_pos.is_equal_approx(target_pos):
		#print("CameraManager: WARNING - look_at() failed. Camera and target positions are identical.")
		return
	
	# FlyCamera has a complex internal structure, so we need to work with it properly
	#print("CameraManager: Applying look_at - Camera: ", camera_pos, ", Target: ", target_pos)
	
	# Method 1: Try to use FlyCamera's internal camera node directly
	var internal_camera = get_flycamera_internal_camera()
	if internal_camera:
		#print("CameraManager: Using internal camera node for look_at")
		# Position the internal camera and use look_at
		internal_camera.global_position = camera_pos
		internal_camera.look_at(target_pos, Vector3.UP)
		return
	
	# Method 2: Fallback to calculating rotation and using set_rot()
	#print("CameraManager: Fallback to manual rotation calculation")
	var look_at_rotation = calculate_look_at_rotation(camera_pos, target_pos)
	fly_camera.set_rot(Vector3(deg_to_rad(look_at_rotation.x), deg_to_rad(look_at_rotation.y), deg_to_rad(look_at_rotation.z)))

# Get FlyCamera's internal Camera3D node for direct look_at usage
func get_flycamera_internal_camera() -> Camera3D:
	if not fly_camera:
		return null
	
	# Search through FlyCamera's structure to find the Camera3D
	for child in fly_camera.get_children():
		if child is Node3D and not child is Camera3D:
			# This might be the _cam_pivot
			for grandchild in child.get_children():
				if grandchild is Camera3D:
					#print("CameraManager: Found internal camera: ", grandchild.name)
					return grandchild
		# Also check direct Camera3D children
		elif child is Camera3D:
			#print("CameraManager: Found direct camera child: ", child.name)
			return child
	
	#print("CameraManager: Could not find internal Camera3D node")
	return null

func _process(_delta):
	# Continuously apply focus if focus mode is enabled and we're not transitioning
	if focus_mode_enabled and not is_camera_transitioning and has_focus_target:
		# Only apply focus if the camera has been manually moved (orbit mode)
		if is_in_manual_orbit_mode:
			apply_focus_if_enabled()
