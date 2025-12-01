extends Control

# Pause Overlay Controller
# Manages the pause menu UI and integrates with PauseManager addon

@export_group("Debug Settings")
@export var debug_mode: bool = false

var pause_manager: PauseManager = null

@onready var resume_button: Button = $PausePanel/ButtonContainer/ResumeButton
@onready var restart_button: Button = $PausePanel/ButtonContainer/RestartButton
@onready var menu_button: Button = $PausePanel/ButtonContainer/MenuButton

signal restart_requested
signal menu_requested

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	pause_manager = get_tree().root.find_child("PauseManager", true, false)
	
	if not pause_manager:
		debug_print("ERROR: PauseManager not found")
		return
	
	pause_manager.toggle.connect(_on_pause_toggled)
	pause_manager.pause.connect(_on_paused)
	pause_manager.resume.connect(_on_resumed)
	
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	
	visible = false
	

func _on_pause_toggled(paused: bool):
	visible = paused
	if paused:
		hide_gameplay_ui()
	else:
		show_gameplay_ui()
	debug_print("Pause overlay visibility: " + str(paused))

func _on_paused():
	visible = true
	hide_gameplay_ui()
	debug_print("Game paused")

func _on_resumed():
	visible = false
	show_gameplay_ui()
	debug_print("Game resumed")

# Hide gameplay UI elements when pause menu is shown
func hide_gameplay_ui():
	# Hide camera controls
	var camera_rig = get_camera_rig()
	if camera_rig:
		if camera_rig.has_method("set_ui_visible"):
			camera_rig.set_ui_visible(false)
		if camera_rig.has_method("set_input_enabled"):
			camera_rig.set_input_enabled(false)
		debug_print("Camera UI and input hidden")
	
	# Hide timer
	var game_timer = get_node_or_null("/root/Main/UI Menu/GameTimer")
	if game_timer:
		game_timer.visible = false
		debug_print("Game timer hidden")
	
	# Hide score display
	var score_display = get_node_or_null("/root/Main/UI Menu/ScoreDisplay")
	if score_display:
		score_display.visible = false
		debug_print("Score display hidden")
	
	# Hide pause button
	var pause_button = get_node_or_null("/root/Main/UI Menu/PauseButton")
	if pause_button:
		pause_button.visible = false
		debug_print("Pause button hidden")

func show_gameplay_ui():
	# Show camera controls
	var camera_rig = get_camera_rig()
	if camera_rig:
		if camera_rig.has_method("set_ui_visible"):
			camera_rig.set_ui_visible(true)
		if camera_rig.has_method("set_input_enabled"):
			camera_rig.set_input_enabled(true)
		debug_print("Camera UI and input shown")
	
	# Show timer
	var game_timer = get_node_or_null("/root/Main/UI Menu/GameTimer")
	if game_timer:
		game_timer.visible = true
		debug_print("Game timer shown")
	
	# Show score display
	var score_display = get_node_or_null("/root/Main/UI Menu/ScoreDisplay")
	if score_display:
		score_display.visible = true
		debug_print("Score display shown")
	
	# Show pause button
	var pause_button = get_node_or_null("/root/Main/UI Menu/PauseButton")
	if pause_button:
		pause_button.visible = true
		debug_print("Pause button shown")

# Helper to find CameraRig in the scene
func get_camera_rig():
	var current_scene = get_tree().current_scene
	if not current_scene:
		return null
	
	# Search for CameraRig recursively
	for child in current_scene.get_children():
		var result = find_camera_rig_recursive(child)
		if result:
			return result
	return null

func find_camera_rig_recursive(node: Node):
	if node.name == "CameraRig" or (node.get_script() and str(node.get_script()).contains("CameraRig")):
		return node
	for child in node.get_children():
		var result = find_camera_rig_recursive(child)
		if result:
			return result
	return null

func _on_resume_pressed():
	debug_print("Resume button pressed")
	if pause_manager:
		pause_manager._resume()

func _on_restart_pressed():
	debug_print("Restart button pressed")
	restart_requested.emit()
	if pause_manager:
		pause_manager._resume()

func _on_menu_pressed():
	debug_print("Menu button pressed")
	menu_requested.emit()
	if pause_manager:
		pause_manager._resume()

func debug_print(message: String):
	if debug_mode:
		print("[PauseOverlay] ", message)
