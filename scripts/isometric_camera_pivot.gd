extends Node3D

const YAW_STEP_DEG := 90.0
const ZOOM_STEP := 0.08
const ZOOM_MIN := 0.45
const ZOOM_MAX := 1.75

@export var rotate_duration_sec: float = 0.35
@export var pan_speed: float = 14.0
@export var pan_mouse_sensitivity: float = 0.02

@onready var _camera: Camera3D = $Camera3D

var _yaw_deg: float = 0.0
var _zoom_factor: float = 1.0
var _base_camera_position: Vector3
var _rotate_tween: Tween
var _is_middle_drag_pan: bool = false


func _ready() -> void:
	_base_camera_position = _camera.position
	rotation_degrees.y = _yaw_deg
	_apply_zoom()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("camera_rotate_left"):
		_rotate_corner(-1)
	elif Input.is_action_just_pressed("camera_rotate_right"):
		_rotate_corner(1)

	if not _is_ramp_build_active():
		if Input.is_action_just_pressed("camera_zoom_in"):
			_zoom_by_steps(-1)
		elif Input.is_action_just_pressed("camera_zoom_out"):
			_zoom_by_steps(1)

	_apply_pan(delta)


func _apply_pan(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("camera_pan_right") - Input.get_action_strength("camera_pan_left"),
		Input.get_action_strength("camera_pan_forward") - Input.get_action_strength("camera_pan_back"),
	)
	if input.is_zero_approx():
		return

	var axes := _get_pan_axes()
	if axes.is_empty():
		return
	position += (axes[0] * input.x + axes[1] * input.y) * pan_speed * delta


func _get_pan_axes() -> Array[Vector3]:
	var cam_basis := _camera.global_transform.basis
	var right := _flatten_to_xz(cam_basis.x)
	var forward := _flatten_to_xz(-cam_basis.z)
	if right.length_squared() < 0.0001 or forward.length_squared() < 0.0001:
		return []
	return [right, forward]


func _pan_by_screen_delta(screen_delta: Vector2) -> void:
	var axes := _get_pan_axes()
	if axes.is_empty():
		return
	var scale := pan_mouse_sensitivity / _zoom_factor
	position -= (axes[0] * screen_delta.x - axes[1] * screen_delta.y) * scale


func _flatten_to_xz(vector: Vector3) -> Vector3:
	var flat := Vector3(vector.x, 0.0, vector.z)
	return flat.normalized() if flat.length_squared() > 0.0001 else Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_middle_drag_pan = mouse_event.pressed
			if mouse_event.pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			get_viewport().set_input_as_handled()
			return

		if not mouse_event.pressed:
			return

		var strength := mouse_event.factor if mouse_event.factor > 0.0 else 1.0
		match mouse_event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_by_steps(-1, strength)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by_steps(1, strength)
				get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _is_middle_drag_pan:
		var motion_event := event as InputEventMouseMotion
		_pan_by_screen_delta(motion_event.relative)
		get_viewport().set_input_as_handled()


func _rotate_corner(direction: int) -> void:
	if _rotate_tween:
		_rotate_tween.kill()
		_yaw_deg = rotation_degrees.y

	_yaw_deg += float(direction) * YAW_STEP_DEG
	_animate_to_corner()


func _animate_to_corner() -> void:
	_rotate_tween = create_tween()
	_rotate_tween.set_ease(Tween.EASE_IN_OUT)
	_rotate_tween.set_trans(Tween.TRANS_CUBIC)
	_rotate_tween.tween_property(self, "rotation_degrees:y", _yaw_deg, rotate_duration_sec)


func _zoom_by_steps(direction: int, strength: float = 1.0) -> void:
	var delta := ZOOM_STEP * strength * float(direction)
	_zoom_factor = clampf(_zoom_factor + delta, ZOOM_MIN, ZOOM_MAX)
	_apply_zoom()


func _apply_zoom() -> void:
	_camera.position = _base_camera_position * _zoom_factor


func _is_ramp_build_active() -> bool:
	var main := get_parent()
	if main == null:
		return false
	var ramp_mode := main.get_node_or_null("RampBuildMode")
	return ramp_mode != null and ramp_mode.is_active()
