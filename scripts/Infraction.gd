# =============================================================================
# INFRACTION DATA COMPONENT
# =============================================================================
# Attached to CollisionObject3D nodes on Physics Layer 2 (Infractions).
# Acts as a data container for specific safety violations.
# Allows the LevelController to identify what was clicked and its value.
# =============================================================================
extends Node
class_name Infraction

@export_group("Infraction Details")
@export var infraction_name: String = "Unsecured Load"
@export var point_value: int = 100
@export var description: String = "Hazardous material not properly tied down."

func _ready() -> void:
	# Debug print to confirm infraction is loaded in the scene
	print_debug("Infraction initialized: ", infraction_name)

# Triggered when the LevelController successfully identifies this object
func play_found_effect() -> void:
	# Future logic for highlights, shaders, or sound effects
	print("Found infraction: ", infraction_name)
