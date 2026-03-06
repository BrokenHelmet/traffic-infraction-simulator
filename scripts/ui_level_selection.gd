extends Control

# Level Selection Controller
# Manages the level selection menu UI and level loading

signal level_selected(level_index: int, config_file: Resource)
signal menu_closed()

# References to UI components
@onready var level_buttons_container: VBoxContainer = $ScrollContainer/VBoxContainer/LevelButtonsContainer
@onready var close_button: Button = $ScrollContainer/VBoxContainer/CloseButton

# Level data
var level_configs: Array[Resource] = []
var level_buttons: Array[Button] = []

# Debug settings
@export_group("Debug Settings")
@export var debug_mode: bool = false

func _ready():
	# Connect close button
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Initially hidden
	visible = false
	z_index = 40
	
	debug_print("Level Selection Menu initialized")

func initialize_levels(level_configurations: Array[Resource]):
	"""Initialize the menu with level configs"""
	level_configs = level_configurations
	_create_level_buttons()
	debug_print("Initialized with " + str(level_configs.size()) + " level configs")

func _create_level_buttons():
	"""Create level buttons dynamically from configs"""
	# Clear existing buttons
	for button in level_buttons:
		if button and is_instance_valid(button):
			button.queue_free()
	level_buttons.clear()
	
	# Create level buttons dynamically from configs
	for level_config in level_configs:
		
		print ("Level config path " + level_config.resource_path)
		# Load config to get level info
		if not level_config or not level_config.is_valid():
			debug_print("Skipping invalid config: " + level_config.resource_name)
			continue
		
		# Create level button
		var level_button = Button.new()
		level_button.custom_minimum_size = Vector2(800, 80)
		level_button.add_theme_font_size_override("font_size", 36)
		level_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# Set button text with level info
		var level_name = level_config.level_name if level_config.has_method("get") else "Unknown Level"
		var difficulty = level_config.difficulty if level_config.has_method("get") else "Unknown"
		var description = level_config.level_description if level_config.has_method("get") else "No description available"
		
		# Create rich text for button
		level_button.text = "● " + level_name + " (" + difficulty + ")"
		
		# Color code by difficulty
		match difficulty.to_lower():
			"easy":
				level_button.add_theme_color_override("font_color", Color.LIGHT_GREEN)
			"medium":
				level_button.add_theme_color_override("font_color", Color.YELLOW)
			"hard":
				level_button.add_theme_color_override("font_color", Color.ORANGE_RED)
			_:
				level_button.add_theme_color_override("font_color", Color.WHITE)
		
		# Connect to level loading function
		level_button.pressed.connect(_on_level_button_pressed.bind(level_configs.find(level_config), level_config))
		level_buttons.append(level_button)
		level_buttons_container.add_child(level_button)

func show_menu():
	"""Show the level selection menu"""
	visible = true
	debug_print("Level selection menu shown")

func hide_menu():
	"""Hide the level selection menu"""
	visible = false
	debug_print("Level selection menu hidden")

func toggle_menu():
	"""Toggle menu visibility"""
	if visible:
		hide_menu()
	else:
		show_menu()

func _on_level_button_pressed(level_index: int, config_file: Resource):
	"""Handle level button press"""
	debug_print("Level selected - Index: " + str(level_index) + ", Config: " + config_file.resource_path)
	level_selected.emit(level_index, config_file)
	hide_menu()

func _on_close_pressed():
	"""Handle close button press"""
	debug_print("Close button pressed")
	menu_closed.emit()
	hide_menu()

# Debug helper function
func debug_print(message: String):
	if debug_mode:
		print("LevelSelectionController: " + message)
