extends Node3D
class_name TrafficControlExample

# This script demonstrates how to use WorldSpaceButton for traffic control

@export var button_scene: PackedScene
var traffic_light_buttons: Array[WorldSpaceButton] = []

func _ready():
	create_traffic_light_buttons()

func create_traffic_light_buttons():
	# Example: Create buttons for traffic lights at different intersections
	var traffic_light_positions = [
		Vector3(0, 2, 0),      # Intersection 1
		Vector3(10, 2, 0),     # Intersection 2
		Vector3(0, 2, 10),     # Intersection 3
		Vector3(10, 2, 10)     # Intersection 4
	]
	
	# Create a CanvasLayer to hold all world space buttons
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	for i in range(traffic_light_positions.size()):
		var button = create_traffic_button(traffic_light_positions[i], i)
		canvas_layer.add_child(button)
		traffic_light_buttons.append(button)

func create_traffic_button(pos: Vector3, index: int) -> WorldSpaceButton:
	# Create the WorldSpaceButton
	var world_button = WorldSpaceButton.new()
	
	# Create the TextureButton child
	var texture_button = TextureButton.new()
	texture_button.name = "TextureButton"
	world_button.add_child(texture_button)
	
	# Set up the button properties
	world_button.world_position = pos
	world_button.name = "TrafficButton_" + str(index)
	
	# Set button size
	world_button.set_button_size(Vector2(64, 64))
	
	# Load textures (you'll need to create these or use placeholder textures)
	# For now, using a simple colored texture approach
	var inactive_tex = create_colored_texture(Color.RED, Vector2i(64, 64))
	var active_tex = create_colored_texture(Color.GREEN, Vector2i(64, 64))
	
	world_button.inactive_texture = inactive_tex
	world_button.active_texture = active_tex
	world_button.active_color = Color.WHITE
	world_button.inactive_color = Color.WHITE
	
	# Connect signals
	world_button.pressed.connect(_on_traffic_button_pressed.bind(index))
	world_button.held.connect(_on_traffic_button_held.bind(index))
	world_button.released.connect(_on_traffic_button_released.bind(index))
	
	return world_button

func create_colored_texture(color: Color, size: Vector2i) -> ImageTexture:
	# Helper function to create a simple colored texture
	var image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

# Signal handlers
func _on_traffic_button_pressed(button_index: int):
	print("Traffic button ", button_index, " was pressed!")
	
	# Toggle the traffic light state
	var button = traffic_light_buttons[button_index]
	button.is_active = !button.is_active
	
	# Add your traffic control logic here
	toggle_traffic_light(button_index, button.is_active)

func _on_traffic_button_held(button_index: int):
	print("Traffic button ", button_index, " is being held!")
	
	# You could implement special hold behavior here
	# For example, emergency override or manual control mode
	enter_manual_control_mode(button_index)

func _on_traffic_button_released(button_index: int):
	print("Traffic button ", button_index, " was released!")
	
	# Exit manual control if needed
	exit_manual_control_mode(button_index)

# Your traffic control logic methods
func toggle_traffic_light(light_index: int, is_green: bool):
	print("Setting traffic light ", light_index, " to ", "GREEN" if is_green else "RED")
	# Implement your actual traffic light control here
	# This might involve changing 3D models, affecting vehicle AI, etc.

func enter_manual_control_mode(light_index: int):
	print("Entering manual control mode for light ", light_index)
	# Implement manual control logic

func exit_manual_control_mode(light_index: int):
	print("Exiting manual control mode for light ", light_index)
	# Restore automatic control

# Utility function to update button states from code
func set_traffic_light_state(light_index: int, is_active: bool):
	if light_index < traffic_light_buttons.size():
		traffic_light_buttons[light_index].is_active = is_active

# Example of how you might call this from your traffic simulation logic
func _on_traffic_simulation_state_changed(light_index: int, new_state: bool):
	set_traffic_light_state(light_index, new_state)
