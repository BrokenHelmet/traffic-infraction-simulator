extends Node

# ScoreManager.gd - "Time is Money" Scoring System
# Manages point-based scoring for vehicles and pedestrians with time decay

# Debug control - Set to false by default to reduce console clutter
@export var debug_scoring: bool = false
@export var debug_completion: bool = false
@export var debug_time_decay: bool = false

# Scoring constants
const VEHICLE_START_POINTS: int = 10
const PEDESTRIAN_START_POINTS: int = 5
const VEHICLE_MIN_POINTS: int = -10
const PEDESTRIAN_MIN_POINTS: int = -5

# Time decay parameters (points per second of waiting)
@export var vehicle_decay_rate: float = 0.5  # Points lost per second waiting
@export var pedestrian_decay_rate: float = 0.3  # Slower decay for pedestrians

# Score tracking
var total_score: int = 0
var completed_vehicles: int = 0
var completed_pedestrians: int = 0

# Level requirements (loaded from LevelConfig)
var required_vehicles: int = 0
var required_pedestrians: int = 0
var target_score: int = 0

# Agent tracking for active scoring
var active_agents: Dictionary = {}  # agent_id -> agent_data

# Score thresholds for star rating
var star_thresholds: Array[int] = [0, 50, 100]  # 1-star, 2-star, 3-star

# Signals for UI updates
signal score_updated(new_score: int)
signal agent_completed(agent_type: String, points_earned: int)
signal completion_progress_updated(vehicles: int, pedestrians: int)
signal level_completed(success: bool, final_score: int, stars: int)

func _ready():
	debug_print("ScoreManager initialized", debug_scoring)

# Initialize scoring system with level configuration
func initialize_scoring(level_config: Resource):
	if not level_config:
		debug_print("ERROR: No level config provided to ScoreManager", true)
		return
	
	# Load completion requirements from config
	if level_config.has_method("get_required_vehicles"):
		required_vehicles = level_config.get_required_vehicles()
	else:
		required_vehicles = level_config.get("target_vehicles_passed") if "target_vehicles_passed" in level_config else 10
	
	if level_config.has_method("get_required_pedestrians"):
		required_pedestrians = level_config.get_required_pedestrians()
	else:
		required_pedestrians = level_config.get("target_pedestrians_passed") if "target_pedestrians_passed" in level_config else 5
	
	# Load target score if available
	if level_config.has_method("get_target_score"):
		target_score = level_config.get_target_score()
	else:
		# Calculate reasonable target based on perfect efficiency
		target_score = (required_vehicles * VEHICLE_START_POINTS) + (required_pedestrians * PEDESTRIAN_START_POINTS)
	
	# Load star thresholds if available
	if level_config.has_method("get_star_thresholds"):
		star_thresholds = level_config.get_star_thresholds()
	else:
		# Default thresholds: 50% target for 1-star, 75% for 2-star, 100% for 3-star
		star_thresholds = [
			int(target_score * 0.3),   # 1-star (30% efficiency)
			int(target_score * 0.6),   # 2-star (60% efficiency)  
			target_score               # 3-star (100% efficiency)
		]
	
	# Reset scoring state
	total_score = 0
	completed_vehicles = 0
	completed_pedestrians = 0
	active_agents.clear()
	
	debug_print("Scoring initialized - Vehicles: %d, Pedestrians: %d, Target: %d" % [required_vehicles, required_pedestrians, target_score], debug_scoring)

# Register a new agent (vehicle or pedestrian) for scoring
func register_agent(agent_id: String, agent_type: String, spawn_time: float):
	var agent_data = {
		"id": agent_id,
		"type": agent_type,
		"spawn_time": spawn_time,
		"wait_time": 0.0,
		"wait_start_time": 0.0,
		"current_points": VEHICLE_START_POINTS if agent_type == "vehicle" else PEDESTRIAN_START_POINTS,
		"is_waiting": false
	}
	
	active_agents[agent_id] = agent_data
	debug_print("Registered %s: %s (starts with %d points)" % [agent_type, agent_id, agent_data.current_points], debug_scoring)

# Update agent waiting status (called when agent stops/starts moving)
func set_agent_waiting(agent_id: String, is_waiting: bool):
	if agent_id not in active_agents:
		debug_print("WARNING: Unknown agent %s" % agent_id, debug_scoring)
		return
	
	var agent = active_agents[agent_id]
	if agent.is_waiting != is_waiting:
		# If starting to wait, record the start time
		if is_waiting and not agent.is_waiting:
			agent.wait_start_time = Time.get_unix_time_from_system()
			debug_print("Agent %s started waiting at %f" % [agent_id, agent.wait_start_time], debug_time_decay)
		# If stopping waiting, accumulate the wait time
		elif not is_waiting and agent.is_waiting:
			var wait_duration = Time.get_unix_time_from_system() - agent.get("wait_start_time", 0.0)
			agent.wait_time += wait_duration
			debug_print("Agent %s stopped waiting, accumulated %f seconds (total: %f)" % [agent_id, wait_duration, agent.wait_time], debug_time_decay)
		
		agent.is_waiting = is_waiting
		debug_print("Agent %s waiting status: %s" % [agent_id, "WAITING" if is_waiting else "MOVING"], debug_time_decay)

# Calculate current points for an agent based on accumulated wait time
func calculate_agent_points(agent_id: String) -> int:
	if agent_id not in active_agents:
		return 0
	
	var agent = active_agents[agent_id]
	var decay_rate = vehicle_decay_rate if agent.type == "vehicle" else pedestrian_decay_rate
	var min_points = VEHICLE_MIN_POINTS if agent.type == "vehicle" else PEDESTRIAN_MIN_POINTS
	var start_points = VEHICLE_START_POINTS if agent.type == "vehicle" else PEDESTRIAN_START_POINTS
	
	var points_lost = agent.wait_time * decay_rate
	var current_points = start_points - points_lost
	
	# Clamp to minimum (negative) value
	current_points = max(current_points, min_points)
	
	return int(current_points)

# Complete an agent's journey and award points
func complete_agent(agent_id: String):
	if agent_id not in active_agents:
		debug_print("WARNING: Trying to complete unknown agent %s" % agent_id, debug_scoring)
		return
	
	var agent = active_agents[agent_id]
	
	# Handle final wait time if agent is currently waiting
	if agent.is_waiting and agent.get("wait_start_time", 0.0) > 0.0:
		var final_wait_duration = Time.get_unix_time_from_system() - agent.wait_start_time
		agent.wait_time += final_wait_duration
		debug_print("Agent %s completed while waiting, added final %f seconds (total: %f)" % [agent_id, final_wait_duration, agent.wait_time], debug_time_decay)
	
	var points_earned = calculate_agent_points(agent_id)
	
	# Add to totals
	total_score += points_earned
	if agent.type == "vehicle":
		completed_vehicles += 1
	else:
		completed_pedestrians += 1
	
	# Remove from active tracking
	active_agents.erase(agent_id)
	
	debug_print("Completed %s %s: earned %d points (total: %d)" % [agent.type, agent_id, points_earned, total_score], debug_scoring)
	
	# Emit signals for UI updates
	agent_completed.emit(agent.type, points_earned)
	score_updated.emit(total_score)
	completion_progress_updated.emit(completed_vehicles, completed_pedestrians)
	
	# Check for level completion
	check_level_completion()

# Update wait times for all waiting agents (called by timer instead of _process)
# Note: Wait time tracking is now handled by manual updates when agents change state
# This eliminates the need for continuous _process() updates

# Check if level completion requirements are met
func check_level_completion():
	var vehicles_complete = completed_vehicles >= required_vehicles
	var pedestrians_complete = completed_pedestrians >= required_pedestrians
	
	if vehicles_complete and pedestrians_complete:
		var stars = calculate_star_rating()
		debug_print("LEVEL COMPLETED! Score: %d, Stars: %d" % [total_score, stars], debug_completion)
		level_completed.emit(true, total_score, stars)

# Check if level has failed (called when timer expires)
func check_level_failure():
	var vehicles_incomplete = completed_vehicles < required_vehicles
	var pedestrians_incomplete = completed_pedestrians < required_pedestrians
	
	if vehicles_incomplete or pedestrians_incomplete:
		debug_print("LEVEL FAILED - Vehicles: %d/%d, Pedestrians: %d/%d" % [completed_vehicles, required_vehicles, completed_pedestrians, required_pedestrians], debug_completion)
		level_completed.emit(false, total_score, 0)

# Calculate star rating based on current score
func calculate_star_rating() -> int:
	for i in range(star_thresholds.size() - 1, -1, -1):
		if total_score >= star_thresholds[i]:
			return i + 1
	return 1  # Minimum 1 star for completion

# Get completion progress as percentages
func get_completion_progress() -> Dictionary:
	return {
		"vehicles_percent": float(completed_vehicles) / float(required_vehicles) * 100.0,
		"pedestrians_percent": float(completed_pedestrians) / float(required_pedestrians) * 100.0,
		"score_percent": float(total_score) / float(target_score) * 100.0
	}

# Get current scoring statistics
func get_scoring_stats() -> Dictionary:
	return {
		"total_score": total_score,
		"completed_vehicles": completed_vehicles,
		"completed_pedestrians": completed_pedestrians,
		"required_vehicles": required_vehicles,
		"required_pedestrians": required_pedestrians,
		"target_score": target_score,
		"active_agents": active_agents.size(),
		"current_stars": calculate_star_rating()
	}

# Debug helper function
func debug_print(message: String, enabled: bool):
	if enabled:
		print("[ScoreManager] ", message)

# Public API methods for UI
func get_total_score() -> int:
	return total_score

func get_completion_counts() -> Array[int]:
	return [completed_vehicles, completed_pedestrians]

func get_requirement_counts() -> Array[int]:
	return [required_vehicles, required_pedestrians]

func get_active_agent_count() -> int:
	return active_agents.size()
