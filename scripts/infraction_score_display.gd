extends Control
class_name InfractionScoreDisplay

# infraction_score_display.gd
# Displays real-time scoring information for the infraction identification game mode

@export var debug_score_ui: bool = false

# UI element references
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var infractions_progress: Label = $VBoxContainer/InfractionsProgress
@onready var battery_label: Label = $VBoxContainer/BatteryLabel
@onready var star_display: Label = $VBoxContainer/StarDisplay

# ScoreManager reference
var score_manager: Node = null

func _ready():
	_find_score_manager()
	_connect_signals()
	_refresh_display()

func _find_score_manager():
	score_manager = get_tree().get_first_node_in_group("score_manager")
	if score_manager:
		debug_print("Connected to InfractionScoreManager at: " + str(score_manager.get_path()))
	else:
		debug_print("WARNING: InfractionScoreManager not found")

func _connect_signals():
	if not score_manager:
		return
	score_manager.score_updated.connect(_on_score_updated)
	score_manager.infraction_found.connect(_on_infraction_found)
	score_manager.false_positive_flagged.connect(_on_false_positive_flagged)
	debug_print("Signals connected")

func _refresh_display():
	if not score_manager or not score_manager.has_method("get_scoring_stats"):
		_show_placeholder_values()
		return
	
	var stats = score_manager.get_scoring_stats()
	_update_score(stats.get("total_score", 0))
	_update_infractions(stats.get("found_infractions", 0), stats.get("total_infractions", 0))
	_update_battery(stats.get("false_positives", 0))
	_update_stars(stats.get("current_stars", 1))

# --- Signal handlers ---

func _on_score_updated(new_score: int):
	_update_score(new_score)
	if score_manager and score_manager.has_method("get_scoring_stats"):
		var stats = score_manager.get_scoring_stats()
		_update_stars(stats.get("current_stars", 1))
	debug_print("Score updated: %d" % new_score)

func _on_infraction_found(infraction_id: String, points_earned: int):
	if score_manager and score_manager.has_method("get_scoring_stats"):
		var stats = score_manager.get_scoring_stats()
		_update_infractions(stats.get("found_infractions", 0), stats.get("total_infractions", 0))
	debug_print("Infraction found: %s (+%d)" % [infraction_id, points_earned])

func _on_false_positive_flagged(penalty: int):
	if score_manager and score_manager.has_method("get_scoring_stats"):
		var stats = score_manager.get_scoring_stats()
		_update_battery(stats.get("false_positives", 0))
	debug_print("False positive flagged (-%d)" % penalty)

# --- Display update helpers ---

func _update_score(score: int):
	if score_label:
		score_label.text = "Score: %d" % score

func _update_infractions(found: int, total: int):
	if infractions_progress:
		infractions_progress.text = "Infractions: %d/%d" % [found, total]

func _update_battery(false_positives: int):
	if battery_label and score_manager:
		var remaining = score_manager.max_false_positives - false_positives
		battery_label.text = "Battery: %d/%d" % [remaining, score_manager.max_false_positives]

func _update_stars(stars: int):
	if star_display:
		star_display.text = "★".repeat(stars) + "☆".repeat(3 - stars)

func _show_placeholder_values():
	if score_label:
		score_label.text = "Score: --"
	if infractions_progress:
		infractions_progress.text = "Infractions: --/--"
	if battery_label:
		battery_label.text = "Battery: --/--"
	if star_display:
		star_display.text = "☆☆☆"

# --- Public API ---

func show_display():
	visible = true

func hide_display():
	visible = false

# --- Debug ---

func debug_print(message: String):
	if debug_score_ui:
		print("[InfractionScoreDisplay] ", message)
