@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("Virtual Joystick", "Control", preload("joystick_instantiator.gd"), preload("res://icon.svg"))

func _exit_tree():
	remove_custom_type("Virtual Joystick")
