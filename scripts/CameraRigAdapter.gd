extends Node

# =============================================================================
# CAMERA RIG ADAPTER
# =============================================================================
# Adapter class to integrate the new CameraRig system with existing Main.gd code
# Provides the same interface as the old CameraManager but uses the new CameraRig internally
# =============================================================================

# Reference to the camera rig instance
var camera_rig: Node3D
var camera_rig_scene = preload("res://scenes/cameras/CameraRig.tscn")

# Compatibility properties (from old CameraManager interface)
var camera_transition_duration: float = 1.5
var camera_transition_easing: int = 2

func _ready():
	print("CameraRigAdapter: Initializing adapter for new camera system")

# =============================================================================
# COMPATIBILITY INTERFACE (matches old CameraManager)
# =============================================================================

# Setup camera system - matches old CameraManager interface
func setup_camera_system(fly_camera: Node, level_config: Resource):
	print("CameraRigAdapter: Setting up camera system (replacing FlyCamera)")
	
	# Disable/hide the old FlyCamera if it exists
	if fly_camera and is_instance_valid(fly_camera):
		if fly_camera.has_method("get_camera"):
			var old_camera = fly_camera.get_camera()
			if old_camera:
				old_camera.current = false
		fly_camera.set_process(false)
		fly_camera.visible = false
		print("CameraRigAdapter: Disabled old FlyCamera")
	
	# Create new CameraRig instance
	camera_rig = camera_rig_scene.instantiate()
	camera_rig.name = "CameraRig"
	
	# Configure transition settings
	camera_rig.transition_duration = camera_transition_duration
	
	# Add to scene
	var main_scene = get_tree().current_scene
	main_scene.add_child(camera_rig)
	
	# Wait a frame for the camera rig to initialize
	await get_tree().process_frame
	
	# Load camera positions from level config
	if level_config and level_config.has_method("get_camera_count"):
		var positions = []
		for i in range(level_config.get_camera_count()):
			var pos_data = {
				"position": level_config.get_camera_position(i),
				"rotation": level_config.get_camera_rotation(i)
			}
			positions.append(pos_data)
		
		print("CameraRigAdapter: Loading ", positions.size(), " camera positions from config")
		camera_rig.setup_camera_positions(positions)
	else:
		print("CameraRigAdapter: No camera positions available in level config")
	
	print("CameraRigAdapter: Camera system setup complete")

# Cleanup function - matches old CameraManager interface
func cleanup():
	print("CameraRigAdapter: Cleaning up camera system")
	
	if camera_rig and is_instance_valid(camera_rig):
		camera_rig.cleanup()
		camera_rig.queue_free()
		camera_rig = null
	
	print("CameraRigAdapter: Cleanup complete")

# =============================================================================
# DIRECT CAMERA RIG ACCESS (New functionality)
# =============================================================================

# Get direct access to the camera rig for advanced usage
func get_camera_rig() -> Node3D:
	return camera_rig

# Check if camera rig is ready
func is_camera_rig_ready() -> bool:
	return camera_rig != null and is_instance_valid(camera_rig)

# Get the actual Camera3D from the rig
func get_camera() -> Camera3D:
	if is_camera_rig_ready():
		return camera_rig.get_camera()
	return null

# =============================================================================
# ADDITIONAL UTILITY METHODS
# =============================================================================

# Navigate to specific camera position
func move_to_position(index: int, smooth: bool = true):
	if not is_camera_rig_ready():
		return
	
	if smooth:
		camera_rig.move_to_position_smoothly(index)
	else:
		camera_rig.move_to_position_immediately(index)

# Set zoom level
func set_zoom(zoom_level: float):
	if is_camera_rig_ready():
		camera_rig.set_zoom(zoom_level)

# Enable/disable orbit controls
func set_orbit_enabled(enabled: bool):
	if is_camera_rig_ready():
		camera_rig.orbit_enabled = enabled
