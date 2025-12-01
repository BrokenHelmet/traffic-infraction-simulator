extends Node3D

# =============================================================================
# CAMERA RIG TEST CONTROLLER
# =============================================================================
# Demonstrates the new CameraRig system with predefined camera positions
# =============================================================================

@onready var camera_rig = $CameraRig

# Test camera positions
var test_positions = [
	{
		"position": Vector3(0, 10, 20),
		"rotation": Vector3(-25, 0, 0)
	},
	{
		"position": Vector3(15, 8, 15),
		"rotation": Vector3(-30, -45, 0)
	},
	{
		"position": Vector3(-15, 12, 10),
		"rotation": Vector3(-35, 45, 0)
	},
	{
		"position": Vector3(0, 15, 0),
		"rotation": Vector3(-45, 0, 0)
	}
]

func _ready():
	print("CameraRigTestController: Initializing test scene")
	
	# Wait for camera rig to be ready
	await get_tree().process_frame
	
	if camera_rig:
		print("CameraRigTestController: Setting up test camera positions")
		camera_rig.setup_camera_positions(test_positions)
		
		# Connect to camera rig signals
		camera_rig.camera_position_changed.connect(_on_camera_position_changed)
		camera_rig.zoom_changed.connect(_on_zoom_changed)
		
		# Detect focus targets (cubes)
		camera_rig.detect_focus_targets()
		
		print("CameraRigTestController: Test setup complete!")
		print("Controls:")
		print("- Mouse drag: Rotate camera")
		print("- Mouse wheel: Zoom in/out")
		print("- Use navigation buttons to switch positions")
		print("- Touch drag: Rotate (mobile)")
		print("- Two-finger pinch: Zoom (mobile)")
		print("- F key: Focus on next cube")
		print("- Shift+F: Focus on previous cube")
		print("- C key: Clear focus")
	else:
		print("ERROR: CameraRig not found!")

func _on_camera_position_changed(index: int):
	print("CameraRigTestController: Camera moved to position ", index + 1)

func _on_zoom_changed(zoom_level: float):
	print("CameraRigTestController: Zoom changed to ", zoom_level)

func _input(event):
	if event is InputEventKey and event.pressed:
		# Number keys for quick position switching
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var position_index = event.keycode - KEY_1
			if camera_rig and position_index < test_positions.size():
				camera_rig.move_to_position_smoothly(position_index)
		
		# R key to reset camera
		elif event.keycode == KEY_R:
			if camera_rig:
				camera_rig.reset_camera()
		
		# Z key to reset zoom
		elif event.keycode == KEY_Z:
			if camera_rig:
				camera_rig.set_zoom(camera_rig.default_zoom)
		
		# F key for focus controls
		elif event.keycode == KEY_F:
			if camera_rig:
				if event.shift_pressed:
					camera_rig.focus_previous_target()
				else:
					camera_rig.focus_next_target()
		
		# C key to clear focus
		elif event.keycode == KEY_C:
			if camera_rig:
				camera_rig.clear_focus()
