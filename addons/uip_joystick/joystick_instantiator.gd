@tool
extends Control

var scene: Node = null

func _enter_tree():
	var res = preload("res://addons/uip_joystick/joystick.tscn")
	if res:
		scene = res.instantiate()
		add_child(scene)
	
	_check_settings()

func _check_settings():
	if ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"):
		printerr("disabled 'emulate_mouse_from_touch'")
	
	if not ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"):
		printerr("enabled 'emulate_touch_from_mouse'")

func _exit_tree():
	if is_instance_valid(scene):
		scene.free()
		scene = null
