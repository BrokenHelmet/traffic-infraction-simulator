extends Node3D

# =============================================================================
# TRAFFIC LIGHT CONTROLLER
# =============================================================================
# Interactive traffic light system with 3D world-space buttons
# Supports hold-to-change mechanics and visual state management
# 
# ✅ IMPLEMENTED: Vehicle collision detection and traffic light interaction
# ✅ IMPLEMENTED: User-controlled traffic light switching via WorldSpaceButton
# TODO: Add traffic light timing patterns (automatic cycling)
# TODO: Implement intersection coordination (multiple lights)
# TODO: Add traffic light failure/malfunction simulation  
# TODO: Create traffic light sound effects
# TODO: Add emergency vehicle override functionality
# TODO: Implement pedestrian crossing lights integration
# =============================================================================

# Traffic Light State System - Enhanced Detection
enum LightState {
	RED,
	AMBER,      # Prepare to stop (shown during button press)
	GREEN
}

signal light_changed(new_state: String) # "red", "amber", or "green" for compatibility

# DEBUG SETTINGS - Set to false by default to reduce console clutter
@export_group("Debug Settings")
@export var debug_light_changes: bool = false
@export var debug_vehicle_detection: bool = false
@export var debug_button_events: bool = false
@export var debug_violations: bool = false

# Current state tracking
var current_light_state: LightState = LightState.RED
var is_showing_amber: bool = false  # Track when amber is being shown during button press

@export_group("Traffic Light Settings")
@export var is_red := true  # Keep existing boolean for compatibility
@export var pedestrian_light_on := false
@onready var red_light: MeshInstance3D = $RootNode/RedLight
@onready var amber_light: MeshInstance3D = $RootNode/AmberLight
@onready var green_light: MeshInstance3D = $RootNode/GreenLight
@onready var pedestrian_light: MeshInstance3D = $RootNode/PedestrianLight
@onready var red_light_sensor: Area3D = $RedLightSensor

# =============================================================================
# DEBUG HELPER FUNCTIONS
# =============================================================================

func debug_print(message: String, enabled: bool):
	if enabled:
		print("[TrafficLight-", name, "] ", message)

func dbg_light(message: String):
	debug_print(message, debug_light_changes)

func dbg_vehicle(message: String):
	debug_print(message, debug_vehicle_detection)

func dbg_button(message: String):
	debug_print(message, debug_button_events)

func dbg_violation(message: String):
	debug_print(message, debug_violations)

func _ready():
	update_visual()
	
	if red_light_sensor:
		dbg_vehicle("RedLightSensor found - connecting intersection detection signals")
		# Connect signals for intersection detection
		red_light_sensor.body_entered.connect(_on_vehicle_entered_intersection)
		red_light_sensor.body_exited.connect(_on_vehicle_exited_intersection)
	else:
		dbg_light("Warning: RedLightSensor not found")
	
	# Wait for WorldSpaceButtons to rename themselves
	await get_tree().process_frame
	
	# Connect WorldSpaceButton signals using their renamed node names
	var vehicle_traffic_button = get_node_or_null("CanvasLayer/VehicleTrafficButton")
	var pedestrian_button = get_node_or_null("CanvasLayer/PedestrianButton")
	
	# Connect VehicleTrafficButton (WorldSpaceButton) signals
	if vehicle_traffic_button:
		var vehicle_texture_button = vehicle_traffic_button.get_node_or_null("VehicleTrafficButtonTexture")
		if vehicle_texture_button:
			vehicle_texture_button.button_down.connect(_on_vehicle_traffic_button_pressed)
			vehicle_traffic_button.held.connect(_on_vehicle_traffic_button_held)
			vehicle_traffic_button.released.connect(_on_vehicle_traffic_button_released)
			dbg_button("Vehicle button connected successfully")
		else:
			dbg_button("Warning: VehicleTrafficButtonTexture child not found")
	else:
		dbg_button("Warning: VehicleTrafficButton not found")
	
	# Connect PedestrianButton (WorldSpaceButton) signals
	if pedestrian_button:
		var pedestrian_texture_button = pedestrian_button.get_node_or_null("PedestrianButtonTexture")
		if pedestrian_texture_button:
			pedestrian_texture_button.button_down.connect(_on_pedestrian_button_pressed)
			pedestrian_button.held.connect(_on_pedestrian_button_held)
			pedestrian_button.released.connect(_on_pedestrian_button_released)
			dbg_button("Pedestrian button connected successfully")
		else:
			dbg_button("Warning: PedestrianButtonTexture child not found")
	else:
		dbg_button("Warning: PedestrianButton not found")

func _on_vehicle_traffic_button_pressed():
	# Button pressed - start amber light (hold detection begins)
	dbg_button("Vehicle button pressed - amber light ON")
	is_showing_amber = true
	set_light_emission(amber_light, Color.YELLOW)
	# Emit signal for state change
	emit_signal("light_changed", "amber")

func _on_vehicle_traffic_button_held():
	# Hold threshold reached - toggle the traffic light state and turn off amber
	var vehicle_button = get_node_or_null("CanvasLayer/VehicleTrafficButton")
	dbg_button("Vehicle button held - toggling light state")
	
	if vehicle_button and vehicle_button.is_being_held:
		# Toggle the main light state
		is_red = !is_red
		current_light_state = LightState.RED if is_red else LightState.GREEN
		
		# Turn off amber state
		is_showing_amber = false
		
		update_visual()  # This will show proper red/green state
		
		# Emit signal for the new state
		var new_state = "red" if is_red else "green"
		emit_signal("light_changed", new_state)

func _on_vehicle_traffic_button_released():
	# Button released - turn off amber light and return to proper red/green state
	var vehicle_button = get_node_or_null("CanvasLayer/VehicleTrafficButton")
	dbg_button("Vehicle button released - returning to normal state")
	
	# Only turn off amber if the button is not being held (i.e., it was a short press)
	if vehicle_button and not vehicle_button.is_being_held:
		is_showing_amber = false
		update_visual()  # This will turn off amber and show the correct red/green state
		
		# Emit signal to return to proper state
		var current_state_name = "red" if is_red else "green"
		emit_signal("light_changed", current_state_name)

func _on_pedestrian_button_pressed():
	# Could show a different visual state for pedestrian button press
	dbg_button("Pedestrian button pressed")

func _on_pedestrian_button_held():
	# Toggle pedestrian light on hold
	dbg_button("Pedestrian button held")

func _on_pedestrian_button_released():
	toggle_pedestrian_light()
	# Handle pedestrian button release
	dbg_button("Pedestrian button released")

func toggle_pedestrian_light():
	"""Toggle the pedestrian light state"""
	if pedestrian_light:
		# Toggle the boolean state
		pedestrian_light_on = !pedestrian_light_on
		
		# Get pedestrian button safely
		var pedestrian_button = get_node_or_null("CanvasLayer/PedestrianButton")
		if not pedestrian_button:
			dbg_button("Warning: PedestrianButton not found for color reference")
			return
		
		if pedestrian_light_on:
			# Turn on pedestrian light (white/cyan for pedestrian crossing)
			set_light_emission(pedestrian_light, pedestrian_button.active_color)
			#print("Pedestrian light turned ON")
		else:
			# Turn off pedestrian light
			set_light_emission(pedestrian_light, pedestrian_button.inactive_color)
			#print("Pedestrian light turned OFF")

func update_visual():
	# Make sure nodes exist before trying to access them
	if not red_light or not amber_light or not green_light:
		dbg_light("Warning: Light node(s) not found")
		return
	
	if is_red:
		# Red light ON - set emission to red
		set_light_emission(red_light, Color.RED)
		set_light_emission(green_light, Color.TRANSPARENT)
		set_light_emission(amber_light, Color.TRANSPARENT)
	else:
		# Green light ON - set emission to green
		set_light_emission(red_light, Color.TRANSPARENT)
		set_light_emission(green_light, Color.GREEN)
		set_light_emission(amber_light, Color.TRANSPARENT)

func set_light_emission(light_node: MeshInstance3D, emission_color: Color):
	"""Helper function to consistently set emission color on a light node"""
	if not light_node:
		return
		
	# Create material override if it doesn't exist
	if not light_node.material_override:
		# Get the original material if it exists
		var original_material = null
		if light_node.mesh and light_node.mesh.get_surface_count() > 0:
			original_material = light_node.mesh.surface_get_material(0)
		
		# Create new StandardMaterial3D
		var new_material = StandardMaterial3D.new()
		
		# Copy properties from original material if it exists
		if original_material:
			new_material.albedo_color = original_material.albedo_color
			new_material.albedo_texture = original_material.albedo_texture
			# Copy other properties as needed
		
		# Enable emission
		new_material.emission_enabled = emission_color != Color.TRANSPARENT
		new_material.emission = emission_color
		
		light_node.material_override = new_material
	else:
		# Update existing material override
		var material = light_node.material_override as StandardMaterial3D
		if material:
			material.emission_enabled = emission_color != Color.TRANSPARENT
			material.emission = emission_color


# =============================================================================
# LIGHT STATE DETECTION METHODS - For Vehicle Usage
# =============================================================================

func get_light_state() -> LightState:
	"""Get the current traffic light state"""
	if is_showing_amber:
		return LightState.AMBER
	elif is_red:
		return LightState.RED
	else:
		return LightState.GREEN

func is_light_red() -> bool:
	"""Check if light is red (vehicles must stop)"""
	return is_red and not is_showing_amber

func is_light_amber() -> bool:
	"""Check if light is amber (prepare to stop)"""
	return is_showing_amber

func is_light_green() -> bool:
	"""Check if light is green (vehicles can proceed)"""
	return not is_red and not is_showing_amber

func should_vehicle_stop_at_line() -> bool:
	"""Check if approaching vehicles should stop before entering intersection"""
	# Stop on red or amber (amber means prepare to stop for approaching vehicles)
	return is_red or is_showing_amber

func should_vehicles_in_area_continue() -> bool:
	"""Check if vehicles already in intersection should continue (clear the way)"""
	# COMPLETE CLEARANCE: Vehicles already in intersection should ALWAYS continue
	# to clear the crosswalk, even on red lights. Stopping in crosswalk is dangerous.
	return true  # Always allow vehicles in crosswalk to continue


func get_crosswalk_boundaries() -> Dictionary:
	"""Get the crosswalk area boundaries for position calculations
	
	Returns a dictionary with boundary information from RedLightSensor
	"""
	var boundaries = {"valid": false, "center": Vector3.ZERO, "size": Vector3.ZERO}
	
	if red_light_sensor:
		var collision_shape = red_light_sensor.get_node_or_null("CollisionShape3D")
		if collision_shape and collision_shape.shape:
			boundaries.valid = true
			boundaries.center = red_light_sensor.global_position
			# Get size from BoxShape3D
			if collision_shape.shape is BoxShape3D:
				boundaries.size = collision_shape.shape.size
			else:
				boundaries.size = Vector3(6, 1, 3)  # Fallback default size
	
	return boundaries

# =============================================================================
# INTERSECTION DETECTION SIGNAL HANDLERS
# =============================================================================

func _on_vehicle_entered_intersection(body: Node3D):
	"""Handle vehicle entering intersection area"""
	if body.has_method("set_in_intersection"):
		body.set_in_intersection(true)
		dbg_vehicle("Vehicle " + body.name + " ENTERED intersection")

func _on_vehicle_exited_intersection(body: Node3D):
	"""Handle vehicle exiting intersection area"""
	if body.has_method("set_in_intersection"):
		body.set_in_intersection(false)
		dbg_vehicle("Vehicle " + body.name + " EXITED intersection")
