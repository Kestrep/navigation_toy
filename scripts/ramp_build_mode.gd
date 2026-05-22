extends Node3D

const RAMP_SCENE: PackedScene = preload("res://scenes/Ramp.tscn")
const _PlacementUtils = preload("res://scripts/placement_utils.gd")
const PREVIEW_COLOR := Color(0.0050146226, 0.6246298, 9.433627e-06, 0.55)
const ROTATION_STEP := PI * 0.5

signal mode_entered
signal mode_exited

@onready var _ground: Node3D = $"../NavigationRegion3D/Ground"
@onready var _main: Node3D = get_parent()

var _preview: MeshInstance3D
var _active: bool = false
var _y_rotation_steps: int = 0


func is_active() -> bool:
	return _active


func enter() -> void:
	if _active:
		return
	_active = true
	_y_rotation_steps = 0
	_create_preview()
	mode_entered.emit()


func exit() -> void:
	if not _active:
		return
	_active = false
	if _preview:
		_preview.queue_free()
		_preview = null
	mode_exited.emit()


func rotate_y_90() -> void:
	if not _active:
		return
	_y_rotation_steps = (_y_rotation_steps + 1) % 4
	_update_preview_rotation()


func handle_mouse_button(button_index: int) -> void:
	if not _active:
		return

	match button_index:
		MOUSE_BUTTON_LEFT:
			_place_ramp()
		MOUSE_BUTTON_RIGHT:
			exit()


func _process(_delta: float) -> void:
	if not _active or _preview == null:
		return

	var world_point := _get_placement_point()
	if world_point == Vector3.INF:
		_preview.visible = false
		return

	_preview.visible = true
	_preview.global_position = _PlacementUtils.snap_position_to_grid(world_point)
	_update_preview_rotation()


func _create_preview() -> void:
	var temp_ramp: Node = RAMP_SCENE.instantiate()
	var source_mesh: MeshInstance3D = temp_ramp.get_node("MeshInstance3D") as MeshInstance3D
	var preview_mesh: Mesh = source_mesh.mesh.duplicate()
	temp_ramp.free()

	_preview = MeshInstance3D.new()
	_preview.mesh = preview_mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = PREVIEW_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview.material_override = material

	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview)
	_update_preview_rotation()


func _update_preview_rotation() -> void:
	if _preview:
		_preview.rotation.y = _y_rotation_steps * ROTATION_STEP


func _place_ramp() -> void:
	var world_point := _get_placement_point()
	if world_point == Vector3.INF:
		return

	var ramp := RAMP_SCENE.instantiate()
	_ground.add_child(ramp)
	ramp.global_position = _PlacementUtils.snap_position_to_grid(world_point)
	ramp.rotation.y = _y_rotation_steps * ROTATION_STEP
	_main.rebake_navigation_mesh()


func _get_placement_point() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.INF

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * 1000.0
	)
	query.collision_mask = 1
	query.collide_with_bodies = true

	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position as Vector3

	if absf(ray_direction.y) < 0.001:
		return Vector3.INF

	var t := -ray_origin.y / ray_direction.y
	if t < 0.0:
		return Vector3.INF

	return ray_origin + ray_direction * t
