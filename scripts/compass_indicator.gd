extends Control

## Nord monde : quadrant +X / +Z — équivalent à Vector3(1, 0, 1).normalized().
const WORLD_NORTH := Vector3(0.70710677, 0.0, 0.70710677)
const NORTH_PROBE_DISTANCE := 8.0
const GROUND_Y := 0.05
const ARROW_COLOR := Color(0.15, 0.2, 0.35, 0.95)

@export var camera_path: NodePath = NodePath("../../CameraPivot/Camera3D")
@export var camera_pivot_path: NodePath = NodePath("../../CameraPivot")

var _camera: Camera3D
var _camera_pivot: Node3D
var _arrow_angle: float = 0.0
var _arrow_points: PackedVector2Array = PackedVector2Array([
	Vector2(0.0, -12.0),
	Vector2(-7.0, 8.0),
	Vector2(7.0, 8.0),
])


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	if _camera == null:
		_camera = get_viewport().get_camera_3d()
	_camera_pivot = get_node_or_null(camera_pivot_path) as Node3D
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_reset_camera_to_north()
			accept_event()


func _process(_delta: float) -> void:
	if _camera == null:
		return

	var dir := _get_screen_north_direction()
	if dir.length_squared() < 0.01:
		return

	var new_angle := dir.angle() + PI * 0.5
	if not is_equal_approx(new_angle, _arrow_angle):
		_arrow_angle = new_angle
		queue_redraw()


func _get_screen_north_direction() -> Vector2:
	var ref := _world_point_on_ground()
	var target := ref + WORLD_NORTH * NORTH_PROBE_DISTANCE

	if not _camera.is_position_behind(ref) and not _camera.is_position_behind(target):
		var p0 := _camera.unproject_position(ref)
		var p1 := _camera.unproject_position(target)
		var dir := p1 - p0
		if dir.length_squared() >= 0.01:
			return dir

	return _screen_north_from_camera_basis()


func _world_point_on_ground() -> Vector3:
	var from := _camera.global_position
	var ray_dir := -_camera.global_transform.basis.z
	if ray_dir.length_squared() < 0.0001:
		return Vector3(from.x, GROUND_Y, from.z)

	ray_dir = ray_dir.normalized()
	var t := (GROUND_Y - from.y) / ray_dir.y
	if t <= 0.0:
		t = 10.0
	return from + ray_dir * t


func _screen_north_from_camera_basis() -> Vector2:
	var basis := _camera.global_transform.basis
	var right := Vector2(basis.x.x, basis.x.z)
	var forward := Vector2(-basis.z.x, -basis.z.z)
	if right.length_squared() < 0.0001 or forward.length_squared() < 0.0001:
		return Vector2.ZERO

	right = right.normalized()
	forward = forward.normalized()
	var north_xz := Vector2(WORLD_NORTH.x, WORLD_NORTH.z)
	return Vector2(north_xz.dot(right), north_xz.dot(forward))


func _reset_camera_to_north() -> void:
	if _camera_pivot != null and _camera_pivot.has_method("reset_to_north"):
		_camera_pivot.call("reset_to_north")


func _draw() -> void:
	var center := size * 0.5
	draw_set_transform(center, _arrow_angle, Vector2.ONE)
	draw_colored_polygon(_arrow_points, ARROW_COLOR)
