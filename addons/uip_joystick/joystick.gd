@tool
class_name VirtualJoystick
extends Control

enum JoystickMode { STATIC, DYNAMIC, FOLLOWING }
enum VisibilityMode { ALWAYS, HIDDEN_FREE }

@onready var base: TextureRect = get_node_or_null("Base")
@onready var knob: TextureRect = get_node_or_null("Base/Knob")

@export_group("Modes")
@export var joystick_mode: JoystickMode = JoystickMode.STATIC:
	set(v):
		joystick_mode = v
		notify_property_list_changed()

@export var visibility_mode: VisibilityMode = VisibilityMode.ALWAYS
@export_custom(PROPERTY_HINT_RANGE, "50, 1000, 50") var dynamic_range_px: float = 50.0 

@export_group("Colors")
@export var use_color_is_pressed: bool = false
@export var pressed_color: Color = Color.AQUAMARINE

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

var action_left: String = "ui_left"
var action_right: String = "ui_right"
var action_up: String = "ui_up"
var action_down: String = "ui_down"
var deadzone_percent := 0.05
var max_distance_percent := 0.4
var deadzone_px := 5.0
var max_distance_px := 100.0

var finger_id : int = -1
var output_vector := Vector2.ZERO
var _deadzone: float
var _max_dist: float
var _original_base_pos: Vector2 
var _touch_start_pos: Vector2 

func _set(property: StringName, value: Variant) -> bool:
	match property:
		"action_left": action_left = value
		"action_right": action_right = value
		"action_up": action_up = value
		"action_down": action_down = value
		"deadzone_px": deadzone_px = value
		"max_distance_px": max_distance_px = value
		"deadzone_percent": deadzone_percent = value
		"max_distance_percent": max_distance_percent = value
		_: return false
	return true

func _get(property: StringName) -> Variant:
	match property:
		"action_left": return action_left
		"action_right": return action_right
		"action_up": return action_up
		"action_down": return action_down
		"deadzone_px": return deadzone_px
		"max_distance_px": return max_distance_px
		"deadzone_percent": return deadzone_percent
		"max_distance_percent": return max_distance_percent
		_: return null

func _get_property_list():
	var props = []
	
	var actions = InputMap.get_actions()
	var action_list = ",".join(actions)
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
	if base == null: warnings.append("Missing 'Base' node.")
	elif knob == null: warnings.append("Missing 'Knob' node.")
	return warnings

func _ready():
	if base: 
		_original_base_pos = base.position
		if visibility_mode == VisibilityMode.HIDDEN_FREE and not Engine.is_editor_hint():
			base.hide()
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
			if finger_id == -1:
				finger_id = event.index
				_touch_start_pos = event.position
				if joystick_mode != JoystickMode.STATIC:
					base.position = event.position - (base.size / 2)
				if visibility_mode == VisibilityMode.HIDDEN_FREE: base.show()
				if use_color_is_pressed: base.modulate = pressed_color
				_update_joystick(event.position)
		elif event.index == finger_id:
			_reset_knob()
	if event is InputEventScreenDrag and event.index == finger_id:
		_update_joystick(event.position)

func _update_joystick(input_pos: Vector2):
	_calculate_metrics()
	var center = base.position + (base.size / 2)
	var distance = input_pos.distance_to(center)
	var direction = (input_pos - center).normalized()
	
	if joystick_mode == JoystickMode.FOLLOWING and distance > _max_dist:
		base.position += direction * (distance - _max_dist)
		center = base.position + (base.size / 2)
	elif joystick_mode == JoystickMode.DYNAMIC and distance > _max_dist:
		var target_base_pos = base.position + direction * (distance - _max_dist)
		var base_center_after_move = target_base_pos + (base.size / 2)
		if base_center_after_move.distance_to(_touch_start_pos) <= dynamic_range_px:
			base.position = target_base_pos
			center = base_center_after_move
		else:
			var wall_direction = (base_center_after_move - _touch_start_pos).normalized()
			base.position = _touch_start_pos + (wall_direction * dynamic_range_px) - (base.size / 2)
			center = base.position + (base.size / 2)

	var clamped_dist = min(input_pos.distance_to(center), _max_dist)
	if knob:
		knob.position = (base.size / 2) + (direction * clamped_dist) - (knob.size / 2)
	
	if input_pos.distance_to(center) > _deadzone:
		output_vector = direction * (clamped_dist / _max_dist)
	else:
		output_vector = Vector2.ZERO
	_feed_input_system()

func _reset_knob():
	output_vector = Vector2.ZERO
	if not Engine.is_editor_hint(): _feed_input_system()
	finger_id = -1
	if base:
		base.position = _original_base_pos
		if visibility_mode == VisibilityMode.HIDDEN_FREE and not Engine.is_editor_hint(): 
			base.hide()
		base.modulate = Color.WHITE
		if knob: knob.position = (base.size / 2) - (knob.size / 2)

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
