# =============================================================================
# LEVEL CONTROLLER
# =============================================================================
# Manages 3D gameplay interaction within a specific level.
# Handles Raycasting to distinguish between Environment (Layer 1) and Infractions (Layer 2).
# Includes drag-detection logic to prevent accidental penalties during camera movement.
# =============================================================================
extends Node3D

# Signals to communicate results back to the MainController
signal infraction_found(data: Infraction)
signal penalty_triggered

@export_group("Input Calibration")
@export var drag_threshold: float = 5.0 # Max pixels moved to still count as a 'click'

# Internal state tracking for input
var _mouse_down_pos: Vector2 = Vector2.ZERO
var _is_mouse_down: bool = false

func _input(event: InputEvent) -> void:
	# Filter for mouse button actions
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Record starting position to check against drag threshold later
				_mouse_down_pos = event.position
				_is_mouse_down = true
			else:
				_is_mouse_down = false
				# Calculate if the movement was a 'click' or a 'drag'
				var drag_distance = event.position.distance_to(_mouse_down_pos)
				
				if drag_distance < drag_threshold:
					# Player clicked intentionally, proceed to raycast
					_perform_raycast(event.position)
				else:
					# Player was likely rotating the camera; ignore the release
					print_debug("Drag detected (", drag_distance, "px). Raycast suppressed.")

# Projects a ray from the camera into 3D space based on mouse coordinates
func _perform_raycast(screen_pos: Vector2) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		push_warning("No active camera found in LevelController")
		return

	# Determine ray start (camera) and end (1000 units into the world)
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	
	# Access the physics state for this 3D world
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	# Set collision mask: Layer 1 (Env) + Layer 2 (Infraction) = Mask 3
	query.collision_mask = 3 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		_process_hit_result(result.collider)
	else:
		# Clicked into the void/skybox (Optional: handle as penalty or ignore)
		print("Raycast hit nothing.")
	
	# Add this inside _perform_raycast() to debug the click coordinates
	print("Attempting Raycast from: ", screen_pos)

# Analyzes what the raycast hit and triggers the appropriate signal
func _process_hit_result(collider: Object) -> void:
	# Try to find the Infraction component on the hit object
	var infraction_data = collider.get_node_or_null("Infraction")
	
	if infraction_data is Infraction:
		# SUCCESS: Layer 2 object with Infraction script found
		print_debug("HIT: Infraction - ", infraction_data.infraction_name)
		infraction_found.emit(infraction_data)
		
		# Disable collider to prevent duplicate scoring
		collider.set_deferred("collision_layer", 0) 
	else:
		# PENALTY: Layer 1 object hit, or object lacks Infraction script
		print_debug("HIT: Environment (Penalty)")
		penalty_triggered.emit()
