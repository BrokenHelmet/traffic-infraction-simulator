extends Control

# ScoreDisplayController.gd - "Time is Money" Scoring UI
# Displays real-time scoring information during gameplay

# Debug control
@export var debug_score_ui: bool = true

# UI References (to be set in editor or found at runtime)
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var vehicles_progress: Label = $VBoxContainer/VehiclesProgress
@onready var pedestrians_progress: Label = $VBoxContainer/PedestriansProgress
@onready var star_display: Label = $VBoxContainer/StarDisplay
@onready var efficiency_bar: ProgressBar = $VBoxContainer/EfficiencyBar

# ScoreManager reference
var score_manager: Node = null
var score_manager_search_attempts: int = 0
const MAX_SEARCH_ATTEMPTS: int = 50  # Try for about 5 seconds (50 * 0.1s)

# UI Update frequency control
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1  # Update UI every 100ms for smooth display

func _ready():
	debug_print("ScoreDisplay initialized", debug_score_ui)
	
	# Initialize UI visibility first
	_setup_ui_layout()
	
	# Defer ScoreManager search until next frame to ensure all nodes are ready
	call_deferred("_find_score_manager_and_connect")

func _find_score_manager_and_connect():
	"""Find ScoreManager and connect signals - called deferred after ready"""
	_find_score_manager()
	_connect_score_signals()

func _find_score_manager():
	"""Find and connect to ScoreManager"""
	# Debug: Show our current path
	debug_print("ScoreDisplay path: " + str(get_path()), debug_score_ui)
	
	# Try group first (most reliable method)
	score_manager = get_tree().get_first_node_in_group("score_manager")
	debug_print("Tried score_manager group: " + ("FOUND" if score_manager else "NOT FOUND"), debug_score_ui)
	
	if not score_manager:
		# Try primary path
		score_manager = get_node_or_null("/root/Main/ScoreManager")
		debug_print("Tried /root/Main/ScoreManager: " + ("FOUND" if score_manager else "NOT FOUND"), debug_score_ui)
	
	# Try searching for any ScoreManager nodes
	if not score_manager:
		var root = get_tree().root
		var found_managers = []
		_find_score_managers_recursive(root, found_managers)
		debug_print("Found ScoreManager nodes at paths: " + str(found_managers), debug_score_ui)
	
	if score_manager:
		debug_print("Connected to ScoreManager at: " + str(score_manager.get_path()), debug_score_ui)
	else:
		debug_print("WARNING: ScoreManager not found - UI will show placeholder values", true)

func _connect_score_signals():
	"""Connect to ScoreManager signals for real-time updates"""
	if not score_manager:
		return
		
	if score_manager.has_signal("score_updated"):
		score_manager.score_updated.connect(_on_score_updated)
	
	if score_manager.has_signal("completion_progress_updated"):
		score_manager.completion_progress_updated.connect(_on_completion_progress_updated)
	
	if score_manager.has_signal("agent_completed"):
		score_manager.agent_completed.connect(_on_agent_completed)
	
	debug_print("Connected to ScoreManager signals", debug_score_ui)

func _setup_ui_layout():
	"""Initialize UI layout and styling"""
	# Position scoring display in top-right area (complementing timer)
	#anchor_left = 0.7
	#anchor_top = 0.1
	#anchor_right = 0.98
	#anchor_bottom = 0.4
	
	# Ensure UI elements exist (create if not found)
	_create_ui_elements_if_needed()

func _create_ui_elements_if_needed():
	"""Create UI elements if they don't exist in the scene"""
	if not score_label:
		score_label = Label.new()
		score_label.name = "ScoreLabel"
		add_child(score_label)
	
	if not vehicles_progress:
		vehicles_progress = Label.new()
		vehicles_progress.name = "VehiclesProgress"
		add_child(vehicles_progress)
	
	if not pedestrians_progress:
		pedestrians_progress = Label.new()
		pedestrians_progress.name = "PedestriansProgress"
		add_child(pedestrians_progress)
	
	if not star_display:
		star_display = Label.new()
		star_display.name = "StarDisplay"
		add_child(star_display)
	
	if not efficiency_bar:
		efficiency_bar = ProgressBar.new()
		efficiency_bar.name = "EfficiencyBar"
		add_child(efficiency_bar)
	
	# Apply basic styling
	_apply_ui_styling()

func _apply_ui_styling():
	"""Apply consistent styling to UI elements"""
	# Score label styling
	if score_label:
		#score_label.add_theme_font_size_override("font_size", 24)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
	# Progress labels styling
	for label in [vehicles_progress, pedestrians_progress]:
		if label:
			#label.add_theme_font_size_override("font_size", 16)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Star display styling
	if star_display:
		#star_display.add_theme_font_size_override("font_size", 20)
		star_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Efficiency bar styling
	if efficiency_bar:
		efficiency_bar.max_value = 100.0
		efficiency_bar.step = 1.0
		efficiency_bar.show_percentage = false

func _process(delta: float):
	"""Update UI periodically"""
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		_update_scoring_display()
		update_timer = 0.0

func _update_scoring_display():
	"""Update all scoring UI elements"""
	if not score_manager:
		# Try to find ScoreManager again if we haven't exceeded attempts
		if score_manager_search_attempts < MAX_SEARCH_ATTEMPTS:
			score_manager_search_attempts += 1
			debug_print("Retry attempt " + str(score_manager_search_attempts) + " to find ScoreManager", debug_score_ui)
			_find_score_manager()
			if score_manager:
				debug_print("ScoreManager found on retry attempt " + str(score_manager_search_attempts), debug_score_ui)
				_connect_score_signals()
		
		if not score_manager:
			if score_manager_search_attempts >= MAX_SEARCH_ATTEMPTS:
				debug_print("No score_manager found after " + str(MAX_SEARCH_ATTEMPTS) + " attempts - showing placeholders", debug_score_ui)
			else:
				debug_print("No score_manager found (attempt " + str(score_manager_search_attempts) + ") - showing placeholders", debug_score_ui)
			_show_placeholder_values()
			return
	
	# Get current scoring statistics
	var stats = {}
	if score_manager.has_method("get_scoring_stats"):
		stats = score_manager.get_scoring_stats()
		debug_print("Got stats from ScoreManager: " + str(stats), debug_score_ui)
	else:
		debug_print("ScoreManager missing get_scoring_stats method", true)
		_show_placeholder_values()
		return
	
	# Update score display
	if score_label:
		var new_text = "Score: %d" % stats.get("total_score", 0)
		score_label.text = new_text
		debug_print("Updated score label: " + new_text, debug_score_ui)
	
	# Update completion progress
	if vehicles_progress:
		var new_vehicles_text = "Vehicles: %d/%d" % [
			stats.get("completed_vehicles", 0),
			stats.get("required_vehicles", 0)
		]
		vehicles_progress.text = new_vehicles_text
		debug_print("Updated vehicles progress: " + new_vehicles_text, debug_score_ui)
	
	if pedestrians_progress:
		var new_pedestrians_text = "Pedestrians: %d/%d" % [
			stats.get("completed_pedestrians", 0),
			stats.get("required_pedestrians", 0)
		]
		pedestrians_progress.text = new_pedestrians_text
		debug_print("Updated pedestrians progress: " + new_pedestrians_text, debug_score_ui)
	
	# Update star rating
	if star_display:
		var stars = stats.get("current_stars", 1)
		var star_text = "★".repeat(stars) + "☆".repeat(3 - stars)
		star_display.text = star_text
	
	# Update efficiency bar
	if efficiency_bar:
		var progress = score_manager.get_completion_progress() if score_manager.has_method("get_completion_progress") else {}
		var efficiency = progress.get("score_percent", 0.0)
		efficiency_bar.value = min(efficiency, 100.0)

func _show_placeholder_values():
	"""Show placeholder values when ScoreManager not available"""
	if score_label:
		score_label.text = "Score: --"
	if vehicles_progress:
		vehicles_progress.text = "Vehicles: --/--"
	if pedestrians_progress:
		pedestrians_progress.text = "Pedestrians: --/--"
	if star_display:
		star_display.text = "☆☆☆"
	if efficiency_bar:
		efficiency_bar.value = 0

# Signal handlers for real-time updates
func _on_score_updated(new_score: int):
	"""Handle real-time score updates"""
	if score_label:
		score_label.text = "Score: %d" % new_score
	debug_print("Score updated: %d" % new_score, debug_score_ui)

func _on_completion_progress_updated(vehicles: int, pedestrians: int):
	"""Handle completion progress updates"""
	debug_print("Progress updated - Vehicles: %d, Pedestrians: %d" % [vehicles, pedestrians], debug_score_ui)

func _on_agent_completed(agent_type: String, points_earned: int):
	"""Handle individual agent completion"""
	var color_code = "🚗" if agent_type == "vehicle" else "🚶"
	debug_print("%s completed for %d points" % [color_code, points_earned], debug_score_ui)
	
	# TODO: Add visual feedback for agent completion (particles, animation, etc.)

# Public API for external control
func show_scoring_ui():
	"""Show the scoring UI"""
	visible = true

func hide_scoring_ui():
	"""Hide the scoring UI"""
	visible = false

func get_current_display_stats() -> Dictionary:
	"""Get current UI display values"""
	if not score_manager or not score_manager.has_method("get_scoring_stats"):
		return {}
	
	return score_manager.get_scoring_stats()

# Debug helper
func debug_print(message: String, enabled: bool = false) -> void:
	if enabled:
		print("[ScoreDisplay] ", message)

func _find_score_managers_recursive(node: Node, found_list: Array):
	"""Recursively search for nodes with ScoreManager script"""
	if node.get_script() and node.get_script().get_path().ends_with("ScoreManager.gd"):
		found_list.append(str(node.get_path()))
	for child in node.get_children():
		_find_score_managers_recursive(child, found_list)
