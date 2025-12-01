# Simple test
extends Control

func _ready():
	#var splash = preload("res://scenes/SplashScreen.tscn").instantiate()
	#add_child(splash)
	#splash.splash_completed.connect(_on_splash_done)
	#splash.start_splash()
	
	#var splash = get_parent()
	#splash.splash_completed.connect(_on_splash_done)
	#splash.start_splash()
	pass
	

func _on_splash_done():
	print("Splash finished!")
