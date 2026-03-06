# =============================================================================
# GAME HUD CONTROLLER
# =============================================================================
# Manages the on-screen heads-up display during gameplay.
# Updates score counters, infraction lists, and penalty warnings.
# Designed to be updated via the MainController.
# =============================================================================
extends CanvasLayer

@onready var score_label = %ScoreLabel
@onready var message_label = %MessageLabel
@onready var animation_player = $Control/AnimationPlayer

func _ready() -> void:
	# Clear placeholder text on start
	update_score(0)
	message_label.text = "Find the safety infractions!"

# Updates the visual score display
func update_score(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score
	# Optional: Trigger a small "pop" animation
	if animation_player.has_animation("score_update"):
		animation_player.play("score_update")

# Displays a temporary message (e.g., "Unsecured Load Found!")
func display_infraction_msg(infraction_name: String, points: int) -> void:
	message_label.text = "+%d: %s Identified!" % [points, infraction_name]
	message_label.modulate = Color.GREEN
	_flash_message()

# Displays a penalty warning
func display_penalty_msg() -> void:
	message_label.text = "Penalty: False Alarm! -50"
	message_label.modulate = Color.RED
	_flash_message()

func _flash_message() -> void:
	# Resets and plays a fade-out animation if you have one
	if animation_player.has_animation("message_fade"):
		animation_player.stop()
		animation_player.play("message_fade")
