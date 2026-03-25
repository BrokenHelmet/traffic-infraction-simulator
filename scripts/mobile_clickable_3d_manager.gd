extends Node3D  # Node3D is required to access get_world_3d()

@export var ray_length: float = 1000.0
@export var long_press_threshold: float = 0.5  # seconds
@export var drag_threshold: float = 10.0       # pixels

# -----------------------------
# Touch state
# -----------------------------
var active_touch: bool = false
var active_touch_id: int = -1
var touch_start_position: Vector2 = Vector2.ZERO
var touch_elapsed_time: float = 0.0

# Camera reference
var camera: Camera3D = null

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	if camera == null:
		push_warning("MobileClickable3DManager: No Camera3D found in viewport!")

func _input(event: InputEvent) -> void:
	if camera == null:
		return

	# Touch start
	if event is InputEventScreenTouch and event.pressed:
		active_touch = true
		active_touch_id = event.index
		touch_start_position = event.position
		touch_elapsed_time = 0.0  # Reset timer for this touch

	# Touch end
	elif event is InputEventScreenTouch and not event.pressed:
		if not active_touch or event.index != active_touch_id:
			return

		# Measure distance moved
		var distance: float = event.position.distance_to(touch_start_position)

		if distance < drag_threshold:
			var clickable: Clickable3D = _raycast_to_clickable(event.position)
			if clickable != null:
				var hit_position: Vector3 = _get_hit_position(event.position)
				if touch_elapsed_time < long_press_threshold:
					clickable.on_click(hit_position)
				else:
					clickable.on_long_press(hit_position)
		else:
			# No clickable hit - register false positive
			var score_manager = get_tree().get_first_node_in_group("score_manager")
			if score_manager:
				score_manager.register_false_positive()

		# Reset touch state
		active_touch = false
		active_touch_id = -1
		touch_elapsed_time = 0.0

	# Optional: camera drag handled elsewhere
	# if event is InputEventScreenDrag:
	#     $CameraRig.handle_drag(event.relative)

# -----------------------------
# Track time for long press
# -----------------------------
func _physics_process(delta: float) -> void:
	if active_touch:
		touch_elapsed_time += delta

# -----------------------------
# Raycast helpers
# -----------------------------
func _raycast_to_clickable(screen_pos: Vector2) -> Clickable3D:
	if camera == null:
		push_error("No camera has been found")
		return null

	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * ray_length

	var world = get_world_3d()
	var space_state = world.direct_space_state

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return null

	var collider: Node = result["collider"] as Node
	var parent_node: Clickable3D = collider.get_parent() as Clickable3D
	if parent_node != null:
		return parent_node
	return null

func _get_hit_position(screen_pos: Vector2) -> Vector3:
	if camera == null:
		return Vector3.ZERO

	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * ray_length

	var world = get_world_3d()
	var space_state = world.direct_space_state

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return Vector3.ZERO

	return result["position"] as Vector3
