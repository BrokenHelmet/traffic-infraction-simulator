extends Node3D
class_name Clickable3D

signal clicked(hit_position: Vector3)
signal long_pressed(hit_position: Vector3)

func on_click(hit_position: Vector3) -> void:
	print("Clicked:", name)
	clicked.emit(hit_position)

func on_long_press(hit_position: Vector3) -> void:
	print("Long pressed:", name)
	long_pressed.emit(hit_position)
