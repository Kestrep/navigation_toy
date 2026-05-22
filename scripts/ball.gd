extends RigidBody3D

signal movement_started
signal movement_stopped

const DISPLAY_NAME := "Balle de course"
const GROUND_Y := 0.0
const GROUND_SNAP_EPSILON := 0.02
const REST_VELOCITY := 0.15
const PLATFORM_CENTER_X := -0.5
const PLATFORM_CENTER_Z := -0.5
const PLATFORM_HALF_SIZE := 15.0

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _is_selected: bool = false
var _is_thrown: bool = false
var _follow_cursor: bool = false
var _normal_material: Material
var _selected_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("selectable_ball")
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = 2.0
	angular_damp = 2.5

	_normal_material = _mesh.get_surface_override_material(0)
	if _normal_material == null:
		_normal_material = _mesh.mesh.surface_get_material(0)

	_selected_material = StandardMaterial3D.new()
	if _normal_material is StandardMaterial3D:
		var base := _normal_material as StandardMaterial3D
		_selected_material.albedo_color = base.albedo_color.lightened(0.25)
	else:
		_selected_material.albedo_color = Color(0.4, 1.0, 0.85, 1)


func get_display_name() -> String:
	return DISPLAY_NAME


func is_selected() -> bool:
	return _is_selected


func is_thrown() -> bool:
	return _is_thrown


func should_follow_cursor() -> bool:
	return _is_selected and _follow_cursor and not _is_thrown


func prepare_for_next_throw() -> void:
	if not _is_selected or _is_thrown:
		return

	_follow_cursor = true
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func select() -> void:
	var was_thrown := _is_thrown
	_is_selected = true
	_is_thrown = false
	_follow_cursor = not was_thrown
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_mesh.set_surface_override_material(0, _selected_material)
	if was_thrown:
		movement_stopped.emit()


func deselect() -> void:
	_is_selected = false
	_follow_cursor = false
	if _normal_material:
		_mesh.set_surface_override_material(0, _normal_material)

	if _is_thrown:
		freeze = false
		return

	freeze = false
	_snap_to_ground()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func follow_cursor(ground_point: Vector3) -> void:
	global_position = Vector3(ground_point.x, _get_body_y_on_ground(), ground_point.z)


func launch(direction: Vector3, speed: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001 or speed <= 0.0:
		return

	_is_thrown = true
	_follow_cursor = false
	freeze = false
	_snap_to_ground()
	linear_velocity = flat.normalized() * speed
	angular_velocity = Vector3.ZERO
	movement_started.emit()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _is_thrown:
		return

	var transform := state.transform
	var pos := transform.origin
	var vel := state.linear_velocity
	var min_body_y := _get_min_body_y()
	if pos.y < min_body_y:
		pos.y = min_body_y
		if vel.y < 0.0:
			vel.y = 0.0

	var bounds := _get_platform_bounds()
	var clamped_x := clampf(pos.x, bounds.min_x, bounds.max_x)
	var clamped_z := clampf(pos.z, bounds.min_z, bounds.max_z)
	var hit_edge := clamped_x != pos.x or clamped_z != pos.z
	pos.x = clamped_x
	pos.z = clamped_z

	if hit_edge:
		vel = Vector3.ZERO

	transform.origin = pos
	state.transform = transform
	state.linear_velocity = vel

	if hit_edge:
		state.angular_velocity = Vector3.ZERO
		call_deferred("_finish_throw")


func _physics_process(_delta: float) -> void:
	if _is_thrown:
		_clamp_to_platform_bounds()
		if linear_velocity.length() <= REST_VELOCITY:
			_finish_throw()
		return

	if _is_selected:
		return

	_enforce_ground_contact()


func _finish_throw() -> void:
	if not _is_thrown:
		return
	_is_thrown = false
	_follow_cursor = false
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_clamp_to_platform_bounds()
	_snap_to_ground()
	if _is_selected:
		freeze = true
	movement_stopped.emit()


func _clamp_to_platform_bounds() -> void:
	var bounds := _get_platform_bounds()
	var pos := global_position
	pos.x = clampf(pos.x, bounds.min_x, bounds.max_x)
	pos.z = clampf(pos.z, bounds.min_z, bounds.max_z)
	global_position = pos


func _get_platform_bounds() -> Dictionary:
	var radius := _get_sphere_radius()
	return {
		"min_x": PLATFORM_CENTER_X - PLATFORM_HALF_SIZE + radius,
		"max_x": PLATFORM_CENTER_X + PLATFORM_HALF_SIZE - radius,
		"min_z": PLATFORM_CENTER_Z - PLATFORM_HALF_SIZE + radius,
		"max_z": PLATFORM_CENTER_Z + PLATFORM_HALF_SIZE - radius,
	}


func _enforce_ground_contact() -> void:
	var min_body_y := _get_body_y_on_ground()
	if global_position.y < min_body_y:
		global_position.y = min_body_y
		if linear_velocity.y < 0.0:
			linear_velocity.y = 0.0

	if global_position.y <= min_body_y + GROUND_SNAP_EPSILON and linear_velocity.y <= 0.0:
		global_position.y = min_body_y
		if linear_velocity.length() <= REST_VELOCITY:
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO


func _snap_to_ground() -> void:
	global_position.y = _get_body_y_on_ground()


func _get_sphere_radius() -> float:
	var shape := _collision.shape as SphereShape3D
	if shape == null:
		return 0.1
	return shape.radius * absf(_collision.global_basis.get_scale().y)


func _get_body_y_on_ground() -> float:
	return _get_min_body_y()


func _get_min_body_y() -> float:
	var shape := _collision.shape as SphereShape3D
	if shape == null:
		return GROUND_Y

	var scale_y := absf(global_basis.get_scale().y)
	var radius := shape.radius * scale_y
	return GROUND_Y - _collision.position.y * scale_y + radius
