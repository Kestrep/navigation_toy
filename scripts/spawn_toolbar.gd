extends Control

signal cube_build_requested
signal ramp_build_requested
signal path_build_requested
signal pnj_spawn_requested

@onready var _cube_button: Button = %CubeButton
@onready var _ramp_button: Button = %RampButton
@onready var _path_button: Button = %PathButton
@onready var _pnj_button: Button = $CenterContainer/MarginContainer/HBoxContainer/PNJButton

var _style_normal: StyleBoxFlat
var _style_active: StyleBoxFlat


func _ready() -> void:
	_style_normal = _cube_button.get_theme_stylebox("normal") as StyleBoxFlat
	_style_active = _style_normal.duplicate() as StyleBoxFlat
	_style_active.bg_color = Color(0.85, 0.82, 0.72, 1)

	_cube_button.focus_mode = Control.FOCUS_NONE
	_ramp_button.focus_mode = Control.FOCUS_NONE
	_path_button.focus_mode = Control.FOCUS_NONE
	_pnj_button.focus_mode = Control.FOCUS_NONE
	_cube_button.pressed.connect(_on_cube_button_pressed)
	_ramp_button.pressed.connect(_on_ramp_button_pressed)
	_path_button.pressed.connect(_on_path_button_pressed)
	_pnj_button.pressed.connect(_on_pnj_button_pressed)


func set_cube_build_active(active: bool) -> void:
	_set_button_active(_cube_button, active)


func set_ramp_build_active(active: bool) -> void:
	_set_button_active(_ramp_button, active)


func set_path_build_active(active: bool) -> void:
	_set_button_active(_path_button, active)


func _on_cube_button_pressed() -> void:
	cube_build_requested.emit()


func _on_ramp_button_pressed() -> void:
	ramp_build_requested.emit()


func _on_path_button_pressed() -> void:
	path_build_requested.emit()


func _on_pnj_button_pressed() -> void:
	pnj_spawn_requested.emit()


func _set_button_active(button: Button, active: bool) -> void:
	var style: StyleBoxFlat = _style_active if active else _style_normal
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
