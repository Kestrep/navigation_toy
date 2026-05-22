extends Node3D

const RAY_LENGTH := 1000.0
const NAV_POINT_MAX_DISTANCE := 1.0
const INVALID_WORLD_POINT := Vector3(INF, INF, INF)

@onready var navigation_region: NavigationRegion3D = $NavigationRegion3D
@onready var _info_panel: PanelContainer = $CanvasLayer/CharacterInfoPanel
@onready var _spawn_toolbar: Control = $CanvasLayer/SpawnToolbar
@onready var _cube_build_mode: Node3D = $CubeBuildMode
@onready var _ramp_build_mode: Node3D = $RampBuildMode

var _selected_character: CharacterBody3D = null


func _ready() -> void:
	_spawn_toolbar.cube_build_requested.connect(_on_cube_build_requested)
	_spawn_toolbar.ramp_build_requested.connect(_on_ramp_build_requested)
	_cube_build_mode.mode_exited.connect(_on_cube_build_mode_exited)
	_ramp_build_mode.mode_exited.connect(_on_ramp_build_mode_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _ramp_build_mode.is_active() and event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
			_ramp_build_mode.rotate_y_90()
			get_viewport().set_input_as_handled()
			return

	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	var active_build_mode := _get_active_build_mode()
	if active_build_mode:
		active_build_mode.handle_mouse_button(mouse_event.button_index)
		get_viewport().set_input_as_handled()
		return

	match mouse_event.button_index:
		MOUSE_BUTTON_LEFT:
			_handle_left_click()
		MOUSE_BUTTON_RIGHT:
			_handle_right_click()


func _on_cube_build_requested() -> void:
	if _cube_build_mode.is_active():
		return
	_exit_all_build_modes()
	_deselect_all()
	_spawn_toolbar.set_cube_build_active(true)
	_cube_build_mode.enter()


func _on_ramp_build_requested() -> void:
	if _ramp_build_mode.is_active():
		return
	_exit_all_build_modes()
	_deselect_all()
	_spawn_toolbar.set_ramp_build_active(true)
	_ramp_build_mode.enter()


func _on_cube_build_mode_exited() -> void:
	_spawn_toolbar.set_cube_build_active(false)


func _on_ramp_build_mode_exited() -> void:
	_spawn_toolbar.set_ramp_build_active(false)


func rebake_navigation_mesh() -> void:
	if navigation_region.is_baking():
		return
	navigation_region.bake_navigation_mesh(true)


func _get_active_build_mode() -> Node3D:
	if _cube_build_mode.is_active():
		return _cube_build_mode
	if _ramp_build_mode.is_active():
		return _ramp_build_mode
	return null


func _exit_all_build_modes() -> void:
	if _cube_build_mode.is_active():
		_cube_build_mode.exit()
	if _ramp_build_mode.is_active():
		_ramp_build_mode.exit()
	_spawn_toolbar.set_cube_build_active(false)
	_spawn_toolbar.set_ramp_build_active(false)


func _handle_left_click() -> void:
	var hit := _raycast_from_mouse(0xffffffff)
	if hit.is_empty():
		_deselect_all()
		return

	var collider: Object = hit.collider
	var character := _get_character_from_collider(collider)
	if character:
		_select_character(character)
	else:
		_deselect_all()


func _handle_right_click() -> void:
	if _selected_character == null:
		return

	var world_point: Vector3 = _get_world_point_from_mouse(1)
	if world_point == INVALID_WORLD_POINT:
		return

	var nav_map := navigation_region.get_navigation_map()
	var closest := NavigationServer3D.map_get_closest_point(nav_map, world_point)
	if closest.distance_to(world_point) > NAV_POINT_MAX_DISTANCE:
		return

	_selected_character.set_move_target(closest)


func _raycast_from_mouse(collision_mask: int = 0xffffffff) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_end := ray_origin + camera.project_ray_normal(mouse_pos) * RAY_LENGTH

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = collision_mask

	return space_state.intersect_ray(query)


func _get_world_point_from_mouse(collision_mask: int = 0xffffffff) -> Vector3:
	var hit := _raycast_from_mouse(collision_mask)
	if not hit.is_empty():
		return hit.position as Vector3

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return INVALID_WORLD_POINT

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)

	if absf(ray_direction.y) < 0.001:
		return INVALID_WORLD_POINT

	var t := -ray_origin.y / ray_direction.y
	if t < 0.0:
		return INVALID_WORLD_POINT

	return ray_origin + ray_direction * t


func _get_character_from_collider(collider: Object) -> CharacterBody3D:
	var node: Node = collider as Node
	while node:
		if node.is_in_group("selectable_character") and node is CharacterBody3D:
			return node as CharacterBody3D
		node = node.get_parent()
	return null


func _select_character(character: CharacterBody3D) -> void:
	if _selected_character == character:
		return

	_deselect_all()
	_selected_character = character
	character.select()
	_info_panel.show_character(character)


func _deselect_all() -> void:
	if _selected_character:
		_selected_character.deselect()
		_selected_character = null
	if _info_panel:
		_info_panel.hide_panel()
