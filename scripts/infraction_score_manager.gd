extends Node
class_name InfractionScoreManager

# infraction_score_manager.gd
# Manages scoring for the infraction identification game mode

# Debug controls
@export var debug_scoring: bool = false
@export var debug_completion: bool = false

# Scoring constants
@export var max_false_positives: int = 3
const INFRACTION_POINTS: int = 10
const FALSE_POSITIVE_PENALTY: int = 5

# Score tracking
var total_score: int = 0
var false_positives: int = 0
var found_infractions: Dictionary = {}  # infraction_id -> points_earned

# Round requirements (auto-detected from scene)
var total_infractions: int = 0

# Star thresholds (calculated at round init)
var star_thresholds: Array[int] = [0, 0, 0]

# Signals
signal score_updated(new_score: int)
signal infraction_found(infraction_id: String, points_earned: int)
signal false_positive_flagged(penalty: int)
signal round_completed(success: bool, final_score: int, stars: int, message: String)

func _ready():
	initialize_round()

func initialize_round():
	# Auto-detect infractions in the scene by class name
	var infraction_nodes = _get_infraction_nodes()
	total_infractions = infraction_nodes.size()
	
	# Reset state
	total_score = 0
	false_positives = 0
	found_infractions.clear()
	
	# Calculate star thresholds from perfect score
	var perfect_score = total_infractions * INFRACTION_POINTS
	star_thresholds = [
		int(perfect_score * 0.4),   # 1 star
		int(perfect_score * 0.7),   # 2 stars
		perfect_score               # 3 stars
	]
	
	debug_print("Round initialized - Infractions in scene: %d, Perfect score: %d" % [total_infractions, perfect_score], debug_scoring)

func register_infraction_found(infraction_id: String):
	if infraction_id in found_infractions:
		debug_print("Infraction %s already found, ignoring" % infraction_id, debug_scoring)
		return
	
	found_infractions[infraction_id] = INFRACTION_POINTS
	total_score += INFRACTION_POINTS
	
	debug_print("Infraction found: %s (+%d points, total: %d)" % [infraction_id, INFRACTION_POINTS, total_score], debug_scoring)
	
	infraction_found.emit(infraction_id, INFRACTION_POINTS)
	score_updated.emit(total_score)
	
	check_round_complete()

func register_false_positive():
	false_positives += 1
	total_score -= FALSE_POSITIVE_PENALTY

	debug_print("False positive #%d (-%d points, total: %d)" % [false_positives, FALSE_POSITIVE_PENALTY, total_score], debug_scoring)

	false_positive_flagged.emit(FALSE_POSITIVE_PENALTY)
	score_updated.emit(total_score)

	if false_positives >= max_false_positives:
		debug_print("False positive limit reached - round failed", debug_completion)
		round_completed.emit(false, total_score, 0, "Too many incorrect identifications. Battery depleted.")

func check_round_complete():
	if found_infractions.size() >= total_infractions:
		var stars = calculate_star_rating()
		var message = _get_success_message(stars)
		debug_print("ROUND COMPLETE - Score: %d, Stars: %d" % [total_score, stars], debug_completion)
		round_completed.emit(true, total_score, stars, message)

func check_time_expired():
	if found_infractions.size() < total_infractions:
		debug_print("Time expired - round failed", debug_completion)
		round_completed.emit(false, total_score, 0, "Investigation time ran out.")
		
func _get_success_message(stars: int) -> String:
	match stars:
		3: return "Outstanding work, officer!"
		2: return "Good eye, keep it up."
		_: return "Case closed. Keep practising."

func calculate_star_rating() -> int:
	for i in range(star_thresholds.size() - 1, -1, -1):
		if total_score >= star_thresholds[i]:
			return i + 1
	return 1

# --- Public API ---

func get_total_score() -> int:
	return total_score

func get_found_count() -> int:
	return found_infractions.size()

func get_total_infractions() -> int:
	return total_infractions

func get_false_positive_count() -> int:
	return false_positives

func get_scoring_stats() -> Dictionary:
	return {
		"total_score": total_score,
		"found_infractions": found_infractions.size(),
		"total_infractions": total_infractions,
		"false_positives": false_positives,
		"current_stars": calculate_star_rating()
	}

# --- Internal ---

func _get_infraction_nodes() -> Array:
	var results = []
	_find_infractions_recursive(get_tree().root, results)
	return results

func _find_infractions_recursive(node: Node, results: Array):
	if node is IncidentInspectionAction:
		results.append(node)
	for child in node.get_children():
		_find_infractions_recursive(child, results)

func debug_print(message: String, enabled: bool):
	if enabled:
		print("[InfractionScoreManager] ", message)
