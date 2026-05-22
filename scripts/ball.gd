extends RigidBody3D

const DISPLAY_NAME := "Balle de course"
const GROUND_Y := 0.0
const GROUND_SNAP_EPSILON := 0.02
const REST_VELOCITY := 0.15

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _is_selected: bool = false
var _normal_material: Material
var _selected_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("selectable_ball")
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4

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


func select() -> void:
	_is_selected = true
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_mesh.set_surface_override_material(0, _selected_material)


func deselect() -> void:
	_is_selected = false
	freeze = false
	_snap_to_ground()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if _normal_material:
		_mesh.set_surface_override_material(0, _normal_material)


func follow_cursor(ground_point: Vector3) -> void:
	global_position = Vector3(ground_point.x, _get_body_y_on_ground(), ground_point.z)


func _physics_process(_delta: float) -> void:
	if _is_selected:
		return
	_enforce_ground_contact()


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


func _get_body_y_on_ground() -> float:
	var shape := _collision.shape as SphereShape3D
	if shape == null:
		return GROUND_Y

	var local_center_y := _collision.position.y
	var radius := shape.radius * absf(_collision.basis.get_scale().y)
	return GROUND_Y - local_center_y + radius
