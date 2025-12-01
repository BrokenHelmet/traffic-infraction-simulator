##
## WorldSpaceButton - A 2D UI button that follows a 3D world position
##
## This control creates a button that appears at a specific 3D world position
## when viewed through the camera. It automatically updates its screen position
## to follow the world position as the camera moves.
##
## Features:
## - Automatically positions itself based on 3D world coordinates
## - Supports active/inactive states with different textures and colors
## - Hold detection for long-press interactions
## - Visibility culling when position is behind the camera
## - Mouse input passthrough to allow 3D camera controls to work
##

extends Control
class_name WorldSpaceButton

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#    Components and References
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

@onready var button: TextureButton = $TextureButton
@onready var camera: Camera3D  # Reference to the 3D camera for position calculations

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#    Exported Properties
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
@export var button_name: String

## The 3D world position where this button should appear
@export var world_position: Vector3 = Vector3.ZERO

## Screen offset from the calculated position (useful for fine-tuning)
@export var screen_offset: Vector2 = Vector2.ZERO

## Whether the button is in an active state
@export var is_active: bool = false : set = set_active_state

## Texture to display when the button is active
@export var active_texture: Texture2D

## Texture to display when the button is inactive
@export var inactive_texture: Texture2D

## Color tint when the button is active
@export var active_color: Color = Color.GREEN

## Color tint when the button is inactive
@export var inactive_color: Color = Color.RED

## Time in seconds required to register a "hold" interaction
@export var hold_threshold: float = 0.5

## Font size for debug display
@export var debug_font_size: int = 12

## Whether to show debug display
@export var show_debug: bool = true

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#    Internal Variables
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

# Hold detection state
var is_being_held: bool = false
var hold_timer: float = 0.0

# Performance optimization - reduce update frequency
var position_update_timer: float = 0.0
var position_update_interval: float = 0.016  # Update ~60 times per second

# Debug display
var debug_label: Label

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#    Signals
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

## Emitted when the button is pressed (short tap)
signal pressed

## Emitted when the button is held for the threshold duration
signal held

## Emitted when the button is released
signal released

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#    Core Functions
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

func _ready():
	name = button_name
	$TextureButton.name = button_name+"Texture"
	
	# Debug: Print initial button information
	print("\n=== WorldSpaceButton Debug: ", button_name, " ===")
	print("Initial world_position: ", world_position)
	print("Parent node: ", get_parent().name if get_parent() else "None")
	if get_parent():
		# Check if parent is a Node3D or CanvasLayer/Control
		var parent = get_parent()
		if parent is Node3D:
			print("Parent global position: ", parent.global_position)
			print("Parent transform: ", parent.global_transform)
		elif parent is CanvasLayer:
			print("Parent is a CanvasLayer - no global_position available")
		else:
			print("Parent type: ", parent.get_class())
	
	# Find the camera in the scene - delay to ensure camera system is ready
	await get_tree().process_frame
	camera = get_viewport().get_camera_3d()

	if not camera:
		push_error("WorldSpaceButton: No Camera3D found in scene!")
		return
	else:
		print("WorldSpaceButton initialized with camera: ", camera.name)
		print("Camera position: ", camera.global_position)
		print("Camera transform: ", camera.global_transform)
	
	# Set up the button if it doesn't exist
	if not button:
		button = TextureButton.new()
		add_child(button)
	
	# Configure mouse input behavior
	# Use STOP to properly capture touch events
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Connect button interaction signals
	button.button_down.connect(_on_button_down)
	button.button_up.connect(_on_button_up)
	# Don't connect pressed signal - we'll handle it manually
	
	# Apply initial visual state
	set_active_state(is_active)
	
	# Create debug display
	create_debug_display()

func _process(delta):
	"""Update button position and handle hold detection every frame"""
	# Try to get camera reference if we lost it
	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera:
			visible = false  # Hide button if no camera available
			return
	
	# Update button position to follow world position
	update_screen_position()
	
	# Handle hold timer for long-press detection
	if is_being_held:
		hold_timer += delta
	if hold_timer >= hold_threshold:
		#print("Button held for ", hold_timer, " seconds - long press detected")
		held.emit()
		is_being_held = false  # Prevent multiple hold signals
		hold_timer = 0
		

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#    Position and Visibility Management
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

func update_screen_position():
	"""Convert 3D world position to 2D screen position and update button placement"""
	# Project 3D world position to 2D screen position
	var screen_pos = camera.unproject_position(world_position)
	
	# Perform visibility culling - hide button if position is behind camera
	var local_pos = camera.to_local(world_position)
	if local_pos.z > 0:  # Position is behind camera
		visible = false
		return
	else:
		visible = true
	
	# Apply screen offset and center the button at the calculated position
	screen_pos += screen_offset
	button.position = screen_pos - button.size / 2
	
	# Update debug display
	update_debug_display()

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#    State Management
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

func set_active_state(new_state: bool):
	"""Update the button's visual appearance based on active state"""
	is_active = new_state
	
	if not button:
		return
	
	# Update texture based on state
	if is_active and active_texture:
		button.texture_normal = active_texture
	elif not is_active and inactive_texture:
		button.texture_normal = inactive_texture
	
	# Update color tint based on state
	button.modulate = active_color if is_active else inactive_color

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#    Input Event Handlers
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

func _on_button_down():
	"""Handle button press start - begin hold detection"""
	is_being_held = true
	hold_timer = 0.0

func _on_button_up():
	"""Handle button release - emit released signal and reset hold state"""
	if is_being_held:
		is_being_held = false
		hold_timer = 0.0
		#print("Button released")
		released.emit()

func _on_button_pressed():
	"""Handle button press completion - emit pressed signal for tap/click"""
	# Only emit pressed signal if it wasn't a hold (hold_timer would be 0 if hold wasn't triggered)
	if hold_timer < hold_threshold:
		#print("Button pressed - short tap/click detected")
		pressed.emit()

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#    Public API / Utility Functions
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

func set_world_position(new_pos: Vector3):
	"""Update the 3D world position that this button should follow"""
	world_position = new_pos

func set_button_size(new_size: Vector2):
	"""Set the button's minimum size"""
	if button:
		button.custom_minimum_size = new_size

func set_textures(normal: Texture2D, active: Texture2D = null):
	"""Set the button textures for inactive and optionally active states"""
	inactive_texture = normal
	if active:
		active_texture = active
	set_active_state(is_active)

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#    Debug Functions
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

func create_debug_display():
	"""Create debug label to show button transform info"""
	if not show_debug:
		return
	
	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", debug_font_size)
	debug_label.add_theme_color_override("font_color", Color.YELLOW)
	debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	debug_label.add_theme_constant_override("shadow_offset_x", 1)
	debug_label.add_theme_constant_override("shadow_offset_y", 1)
	debug_label.z_index = 101  # Ensure it's on top
	add_child(debug_label)

func update_debug_display():
	"""Update debug label with current transform information"""
	if not debug_label:
		return
	
	var screen_pos = Vector2.ZERO
	if camera:
		screen_pos = camera.unproject_position(world_position)
	
	# Round world position to 3 decimal places
	var world_rounded = Vector3(
		round(world_position.x * 1000.0) / 1000.0,
		round(world_position.y * 1000.0) / 1000.0,
		round(world_position.z * 1000.0) / 1000.0
	)
	
	# Round screen position to 1 decimal place
	var screen_rounded = Vector2(
		round(screen_pos.x * 10.0) / 10.0,
		round(screen_pos.y * 10.0) / 10.0
	)
	
	# Round screen offset to 1 decimal place
	var offset_rounded = Vector2(
		round(screen_offset.x * 10.0) / 10.0,
		round(screen_offset.y * 10.0) / 10.0
	)
	
	var debug_text = "%s\nWorld: %s\nScreen: %s\nOffset: %s\nVisible: %s" % [
		button_name,
		str(world_rounded),
		str(screen_rounded),
		str(offset_rounded),
		str(visible)
	]
	
	debug_label.text = debug_text
	# Position debug label above the button
	debug_label.position = button.position + Vector2(0, -debug_label.size.y - 5)
