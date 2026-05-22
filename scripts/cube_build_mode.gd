extends Node3D

const CUBE_SCENE: PackedScene = preload("res://scenes/Cube.tscn")
const _PlacementUtils = preload("res://scripts/placement_utils.gd")
const PREVIEW_COLOR := Color(0.9882353, 0.7058824, 0.11372549, 0.55)

signal mode_entered
signal mode_exited

@onready var _ground: Node3D = $"../NavigationRegion3D/Ground"
@onready var _main: Node3D = get_parent()

var _preview: MeshInstance3D
var _active: bool = false


func is_active() -> bool:
	return _active


func enter() -> void:
	if _active:
		return
	_active = true
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


func handle_mouse_button(button_index: int) -> void:
	if not _active:
		return

	match button_index:
		MOUSE_BUTTON_LEFT:
			_place_cube()
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


func _create_preview() -> void:
	var temp_cube: Node = CUBE_SCENE.instantiate()
	var source_mesh: MeshInstance3D = temp_cube.get_node("MeshInstance3D") as MeshInstance3D
	var preview_mesh: Mesh = source_mesh.mesh.duplicate()
	temp_cube.free()

	_preview = MeshInstance3D.new()
	_preview.mesh = preview_mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = PREVIEW_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview.material_override = material

	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview)


func _place_cube() -> void:
	var world_point := _get_placement_point()
	if world_point == Vector3.INF:
		return

	var cube := CUBE_SCENE.instantiate()
	_ground.add_child(cube)
	cube.global_position = _PlacementUtils.snap_position_to_grid(world_point)
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
