extends Clickable3D
class_name IncidentInspectionAction

@export_group("Incident Settings")
@export var incident_name: String = "Incident Name"

@onready var static_body_3d: StaticBody3D = $StaticBody3D

func _ready() -> void:
	if static_body_3d == null:
		push_warning("IncidentInspectionAction: No StaticBody3D child found!")

func on_click(hit_position: Vector3) -> void:
	print("SUCCESS: Incident detected -> ", incident_name)
	# Call base class (debug print / signal) if needed
	super.on_click(hit_position)

	# Example: trigger inspection animation
	# if anim_player:
	#     anim_player.play("Inspect")

	# Notify GameManager
	if Engine.has_singleton("GameManager"):
		var gm := Engine.get_singleton("GameManager")
		if "register_incident_clicked" in gm:
			gm.register_incident_clicked(incident_name)

func on_long_press(hit_position: Vector3) -> void:
	# Call base class (debug print / signal) if needed
	super.on_long_press(hit_position)

	# Show hint UI
	_show_hint_ui()

	# Notify GameManager
	if Engine.has_singleton("GameManager"):
		var gm := Engine.get_singleton("GameManager")
		if "register_hint_used" in gm:
			gm.register_hint_used(incident_name)

func _show_hint_ui() -> void:
	print("Showing hint for incident:", incident_name)
