extends Control

# This script handles the display of the camera's global position and rotation.
# Updated to work with any Camera3D in the scene.

@export var debug_font_size: int = 14  # Font size for the debug text
@onready var camera_debug_label: Label = $CameraDebugLabel  # Reference to existing label
var camera_reference: Camera3D  # Camera3D reference

func _ready() -> void:
	# Set this Control node to stretch to fill the parent
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Apply theme overrides to the existing label
	camera_debug_label.add_theme_font_size_override("font_size", debug_font_size)
	camera_debug_label.add_theme_color_override("font_color", Color.WHITE)
	camera_debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	camera_debug_label.add_theme_constant_override("shadow_offset_x", 1)
	camera_debug_label.add_theme_constant_override("shadow_offset_y", 1)
	camera_debug_label.z_index = 100  # Ensure it's on top
	
	# Find camera in scene instead of relying on specific parent
	camera_reference = get_viewport().get_camera_3d()
	if not visible:
		if camera_reference:
			print("CameraDebugDisplay: Successfully found Camera3D: ", camera_reference.name)
		else:
			print("CameraDebugDisplay: Warning - No Camera3D found in scene")
	
	# Update the label each frame
	set_process(true)

func _process(_delta: float) -> void:
	# Skip processing if not visible
	if not visible:
		return
	
	if not camera_debug_label:
		return
	
	# Try to get camera if we don't have one
	if not camera_reference:
		camera_reference = get_viewport().get_camera_3d()
		if not camera_reference:
			camera_debug_label.text = "Camera Debug:\nNo camera found"
			return
	
	# Get position directly from Camera3D (rounded to 3 decimal places)
	var _position = camera_reference.global_position
	var pos_rounded = Vector3(
		round(_position.x * 1000.0) / 1000.0,
		round(_position.y * 1000.0) / 1000.0,
		round(_position.z * 1000.0) / 1000.0
	)
	
	# Get rotation from Camera3D (rounded to 2 decimal places)
	var _rotation = camera_reference.rotation
	var rot_rounded = Vector3(
		round(rad_to_deg(_rotation.x) * 100.0) / 100.0,
		round(rad_to_deg(_rotation.y) * 100.0) / 100.0,
		round(rad_to_deg(_rotation.z) * 100.0) / 100.0
	)
	
	# Update the label text
	camera_debug_label.text = "Camera Debug:\nPos: " + str(pos_rounded) + "\nRot: " + str(rot_rounded) + "°"
