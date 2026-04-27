@tool
class_name VirtualJoystick
extends Control

@onready var base: TextureRect = get_node_or_null("Base")
@onready var knob: TextureRect = get_node_or_null("Base/Knob")

var action_left: String = "ui_left"
var action_right: String = "ui_right"
var action_up: String = "ui_up"
var action_down: String = "ui_down"

@export_group("Textures")
@export var base_texture: Texture2D:
	set(v): base_texture = v; if base: base.texture = v; update_configuration_warnings()
@export var knob_texture: Texture2D:
	set(v): knob_texture = v; if knob: knob.texture = v; update_configuration_warnings()

@export_group("Settings")
@export var disabled := false:
	set(v): disabled = v; if disabled: _reset_knob()

@export_subgroup("Metrics Control")
@export var use_manual_metrics := false:
	set(v): use_manual_metrics = v; notify_property_list_changed()

var deadzone_percent := 0.05
var max_distance_percent := 0.4

var deadzone_px := 5.0
var max_distance_px := 100.0

var finger_id : int = -1
var output_vector := Vector2.ZERO
var _deadzone: float
var _max_dist: float

func _get_property_list():
	var actions = InputMap.get_actions()
	var action_list = ",".join(actions)
	var props = []
	
	for a in ["action_left", "action_right", "action_up", "action_down"]:
		props.append({"name": a, "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": action_list})
	
	if use_manual_metrics:
		props.append({"name": "deadzone_px", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0, 500, 0.5"})
		props.append({"name": "max_distance_px", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "1, 1000, 0.5"})
	else:
		props.append({"name": "deadzone_percent", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0, 0.5, 0.01"})
		props.append({"name": "max_distance_percent", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.1, 1.0, 0.01"})
		
	return props

func _get_configuration_warnings():
	var warnings = []
	if get_node_or_null("Base") == null:
		warnings.append("Cấu trúc: Cần Node 'Base' (TextureRect) làm con.")
	elif get_node_or_null("Base/Knob") == null:
		warnings.append("Cấu trúc: Cần Node 'Knob' (TextureRect) làm con của 'Base'.")
	if base_texture == null or knob_texture == null:
		warnings.append("Tài nguyên: Chưa dán Texture cho Joystick.")
	return warnings

func _ready():
	update_configuration_warnings()
	if base and base_texture: base.texture = base_texture
	if knob and knob_texture: knob.texture = knob_texture
	if Engine.is_editor_hint(): return
	
	if base and knob:
		base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_STOP 
	_calculate_metrics()
	_reset_knob()

func _calculate_metrics():
	if use_manual_metrics:
		_deadzone = deadzone_px
		_max_dist = max_distance_px
	else:
		var reference_size = min(size.x, size.y)
		_deadzone = reference_size * deadzone_percent
		_max_dist = reference_size * max_distance_percent

func _gui_input(event: InputEvent):
	if Engine.is_editor_hint() or disabled or base == null: return
	if event is InputEventScreenTouch:
		if event.pressed:
			finger_id = event.index
			_update_joystick(event.position)
		elif event.index == finger_id:
			_reset_knob()
	if event is InputEventScreenDrag and event.index == finger_id:
		_update_joystick(event.position)

func _update_joystick(input_pos: Vector2):
	_calculate_metrics()
	var center = size / 2
	var direction = (input_pos - center).normalized()
	var distance = input_pos.distance_to(center)
	var clamped_dist = min(distance, _max_dist)
	
	if knob:
		knob.position = center + (direction * clamped_dist) - (knob.size / 2)
	
	if distance > _deadzone:
		output_vector = direction * (clamped_dist / _max_dist)
	else:
		output_vector = Vector2.ZERO
	_feed_input_system()

func _reset_knob():
	output_vector = Vector2.ZERO
	if not Engine.is_editor_hint(): _feed_input_system()
	finger_id = -1
	if base and knob: knob.position = (size / 2) - (knob.size / 2)

func _feed_input_system():
	_handle_action(action_right, max(0, output_vector.x))
	_handle_action(action_left, max(0, -output_vector.x))
	_handle_action(action_down, max(0, output_vector.y))
	_handle_action(action_up, max(0, -output_vector.y))

func _handle_action(action_name: String, strength: float):
	if action_name == "" or Engine.is_editor_hint(): return
	var is_pressed = strength > 0.1
	var ev = InputEventAction.new()
	ev.action = action_name
	ev.pressed = is_pressed
	ev.strength = strength
	Input.parse_input_event(ev)
	if is_pressed: Input.action_press(action_name, strength)
	else: Input.action_release(action_name)
