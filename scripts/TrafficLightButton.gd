extends Button

signal light_tapped(light_name: String)
signal light_held(light_name: String)

@export var light_name: String = ""
@export var hold_threshold: float = 0.5
@export var normal_texture: Texture2D
@export var pressed_texture: Texture2D
@export var hover_texture: Texture2D

var press_start_time: float = 0.0
var button_is_pressed: bool = false  # Renamed to avoid shadowing
var hold_triggered: bool = false
var is_mobile: bool = false

func _ready():
	# Detect platform
	is_mobile = OS.get_name() == "Android" or OS.get_name() == "iOS"
	
	# Set up the button appearance
	flat = false
	expand_icon = true
	
	# Set textures if provided
	if normal_texture:
		icon = normal_texture
	
	# Connect signals for cross-platform support
	gui_input.connect(_on_gui_input)
	
	# Connect traditional button signals as backup
	button_down.connect(_on_button_pressed)
	button_up.connect(_on_button_released)
	
	# Mouse events for desktop/WebGL
	if not is_mobile:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)

func _on_gui_input(event: InputEvent):
	# Handle both touch and mouse input
	if event is InputEventScreenTouch:
		_handle_touch_event(event)
	elif event is InputEventMouseButton:
		_handle_mouse_event(event)

func _handle_touch_event(event: InputEventScreenTouch):
	if event.pressed:
		_start_press()
	else:
		_end_press()

func _handle_mouse_event(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_press()
		else:
			_end_press()

func _start_press():
	if button_is_pressed:
		return
		
	button_is_pressed = true
	hold_triggered = false
	press_start_time = Time.get_unix_time_from_system()
	
	# Change texture when pressed
	if pressed_texture:
		icon = pressed_texture
	
	# Start checking for hold
	var timer = get_tree().create_timer(hold_threshold)
	timer.timeout.connect(_check_hold)

func _end_press():
	if button_is_pressed and not hold_triggered:
		# It was a tap, not a hold
		light_tapped.emit(light_name)
	
	button_is_pressed = false
	hold_triggered = false
	
	# Return to normal texture
	if normal_texture:
		icon = normal_texture

func _on_button_pressed():
	# Fallback for traditional button signals
	_start_press()

func _on_button_released():
	# Fallback for traditional button signals
	_end_press()

func _on_mouse_entered():
	if not button_is_pressed and hover_texture:
		icon = hover_texture

func _on_mouse_exited():
	if not button_is_pressed and normal_texture:
		icon = normal_texture

func _check_hold():
	if button_is_pressed and not hold_triggered:
		hold_triggered = true
		light_held.emit(light_name)

func set_button_texture(texture: Texture2D):
	"""Update the normal texture and current icon"""
	normal_texture = texture
	if not button_is_pressed:
		icon = texture

func set_button_textures(normal: Texture2D, btn_pressed: Texture2D = null, hover: Texture2D = null):
	"""Set all button textures at once"""
	normal_texture = normal
	pressed_texture = btn_pressed  # Renamed parameter to avoid shadowing
	hover_texture = hover
	
	if not button_is_pressed:
		icon = normal_texture
