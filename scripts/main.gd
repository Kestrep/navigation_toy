extends Node3D

const Ball = preload("res://scripts/ball.gd")
const NavigationLayersLib = preload("res://scripts/navigation_layers.gd")
const NavigationUtilsLib = preload("res://scripts/navigation_utils.gd")
const DefaultPNJScene: PackedScene = preload("res://scenes/DefaultPNJ.tscn")

const RAY_LENGTH := 1000.0
const NAV_POINT_MAX_DISTANCE := 1.0
const INVALID_WORLD_POINT := Vector3(INF, INF, INF)
const THROW_MIN_DRAG_PIXELS := 8.0
const THROW_SPEED_PER_PIXEL := 0.07
const THROW_MIN_SPEED := 2.0
const THROW_MAX_SPEED := 22.0

@onready var navigation_region: NavigationRegion3D = $NavigationRegion3D
@onready var paths_nav_region: PathsNavRegion = $NavigationRegion3D/Ground/DevWorldLayout/PathsNavRegion
@onready var _info_panel: PanelContainer = $CanvasLayer/CharacterInfoPanel
@onready var _spawn_toolbar: Control = $CanvasLayer/SpawnToolbar
@onready var _throw_feedback: Label = $CanvasLayer/ThrowFeedbackLabel
@onready var _cube_build_mode: Node3D = $CubeBuildMode
@onready var _ramp_build_mode: Node3D = $RampBuildMode
@onready var _path_build_mode: Node3D = $PathBuildMode
@onready var _characters: Node3D = $Characters

var _selected_character: CharacterBody3D = null
var _selected_ball: Ball = null
var _throw_dragging: bool = false
var _throw_drag_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	_spawn_toolbar.cube_build_requested.connect(_on_cube_build_requested)
	_spawn_toolbar.ramp_build_requested.connect(_on_ramp_build_requested)
	_spawn_toolbar.path_build_requested.connect(_on_path_build_requested)
	_spawn_toolbar.pnj_spawn_requested.connect(_on_pnj_spawn_requested)
	_cube_build_mode.mode_exited.connect(_on_cube_build_mode_exited)
	_ramp_build_mode.mode_exited.connect(_on_ramp_build_mode_exited)
	_path_build_mode.mode_exited.connect(_on_path_build_mode_exited)

	var region := _get_navigation_region()
	if region == null:
		return
	region.navigation_layers = NavigationLayersLib.LAYER_GROUND
	region.travel_cost = NavigationLayersLib.GROUND_TRAVEL_COST
	region.enter_cost = NavigationLayersLib.GROUND_ENTER_COST
	region.use_edge_connections = true

	await get_tree().physics_frame
	sync_navigation()


func _process(_delta: float) -> void:
	if _selected_ball == null or _get_active_build_mode() or _throw_dragging:
		return
	if _selected_ball.is_thrown() or not _selected_ball.should_follow_cursor():
		return

	var world_point: Vector3 = _get_world_point_from_mouse(1)
	if world_point == INVALID_WORLD_POINT:
		return

	_selected_ball.follow_cursor(world_point)


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

	if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed and _throw_dragging:
		_finish_throw_drag(mouse_event.position)
		_throw_dragging = false
		get_viewport().set_input_as_handled()
		return

	var active_build_mode := _get_active_build_mode()
	if active_build_mode:
		active_build_mode.handle_mouse_button(mouse_event.button_index, mouse_event.pressed)
		get_viewport().set_input_as_handled()
		return

	if not mouse_event.pressed:
		return

	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		_handle_right_click()
		get_viewport().set_input_as_handled()
		return

	if _selected_ball and mouse_event.button_index == MOUSE_BUTTON_LEFT and not _selected_ball.is_thrown():
		_throw_dragging = true
		_throw_drag_start = mouse_event.position

		var hit := _raycast_from_screen(mouse_event.position, 0xffffffff)
		if not hit.is_empty():
			var ball := _get_ball_from_collider(hit.collider)
			if ball == _selected_ball:
				_selected_ball.prepare_for_next_throw()

		get_viewport().set_input_as_handled()
		return

	if not mouse_event.pressed:
		return

	match mouse_event.button_index:
		MOUSE_BUTTON_LEFT:
			_handle_left_click()


func _finish_throw_drag(end_position: Vector2) -> void:
	if _selected_ball == null:
		return

	var screen_delta := end_position - _throw_drag_start
	if screen_delta.length() < THROW_MIN_DRAG_PIXELS:
		return

	var ball_pos := _selected_ball.global_position
	var end_world := _get_ground_point_from_screen(end_position)
	if end_world == INVALID_WORLD_POINT:
		return

	var world_delta := Vector3(end_world.x - ball_pos.x, 0.0, end_world.z - ball_pos.z)
	if world_delta.length_squared() < 0.0001:
		return

	var normalized := world_delta.normalized()
	var speed := clampf(screen_delta.length() * THROW_SPEED_PER_PIXEL, THROW_MIN_SPEED, THROW_MAX_SPEED)
	_throw_feedback.show_throw(normalized, speed)
	_selected_ball.launch(normalized, speed)


func _get_ground_point_from_screen(screen_pos: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return INVALID_WORLD_POINT

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_direction := camera.project_ray_normal(screen_pos)
	if absf(ray_direction.y) < 0.001:
		return INVALID_WORLD_POINT

	var t := -ray_origin.y / ray_direction.y
	if t < 0.0:
		return INVALID_WORLD_POINT

	return ray_origin + ray_direction * t


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


func _on_path_build_requested() -> void:
	if _path_build_mode.is_active():
		return
	_exit_all_build_modes()
	_deselect_all()
	_spawn_toolbar.set_path_build_active(true)
	_path_build_mode.enter()


func _on_pnj_spawn_requested() -> void:
	_exit_all_build_modes()
	_deselect_all()

	var pnj := DefaultPNJScene.instantiate() as DefaultPNJ
	_characters.add_child(pnj)
	var spawn_pos := _get_pnj_spawn_position()
	spawn_pos = NavigationServer3D.map_get_closest_point(
		navigation_region.get_navigation_map(),
		spawn_pos
	)
	if spawn_pos != Vector3.ZERO:
		pnj.global_position = spawn_pos


func _get_pnj_spawn_position() -> Vector3:
	var nav_map := navigation_region.get_navigation_map()
	var spawn_point := NavigationUtilsLib.pick_random_point_on_map(
		nav_map,
		NavigationLayersLib.LAYER_PATH,
		Vector3.ZERO,
		0.0,
		8
	)
	if spawn_point == Vector3.ZERO:
		spawn_point = NavigationUtilsLib.pick_random_point_on_map(
			nav_map,
			NavigationLayersLib.AGENT_LAYERS,
			Vector3.ZERO,
			0.0,
			4
		)
	if spawn_point == Vector3.ZERO:
		return Vector3.ZERO
	return NavigationUtilsLib.snap_to_navmesh(nav_map, spawn_point)


func _on_cube_build_mode_exited() -> void:
	_spawn_toolbar.set_cube_build_active(false)


func _on_ramp_build_mode_exited() -> void:
	_spawn_toolbar.set_ramp_build_active(false)


func _on_path_build_mode_exited() -> void:
	_spawn_toolbar.set_path_build_active(false)


func sync_navigation() -> void:
	var region := _get_navigation_region()
	if region == null or not is_instance_valid(region):
		return
	var paths_region := _get_paths_nav_region()
	if paths_region:
		paths_region.rebake_from_placed_paths()
	rebake_navigation_mesh()


func rebake_navigation_mesh() -> void:
	var region := _get_navigation_region()
	if region == null or not is_instance_valid(region):
		return
	if region.is_baking():
		return
	if not region.navigation_mesh_changed.is_connected(_on_navigation_mesh_changed):
		region.navigation_mesh_changed.connect(_on_navigation_mesh_changed, CONNECT_ONE_SHOT)
	region.bake_navigation_mesh(true)


func _on_navigation_mesh_changed() -> void:
	var region := _get_navigation_region()
	if region == null:
		return
	NavigationUtilsLib.force_map_update(region.get_navigation_map())


func _get_navigation_region() -> NavigationRegion3D:
	if navigation_region != null:
		return navigation_region
	return get_node_or_null("NavigationRegion3D") as NavigationRegion3D


func _get_paths_nav_region() -> PathsNavRegion:
	if paths_nav_region != null:
		return paths_nav_region
	return get_node_or_null("NavigationRegion3D/Ground/DevWorldLayout/PathsNavRegion") as PathsNavRegion


func _get_active_build_mode() -> Node3D:
	if _cube_build_mode.is_active():
		return _cube_build_mode
	if _ramp_build_mode.is_active():
		return _ramp_build_mode
	if _path_build_mode.is_active():
		return _path_build_mode
	return null


func _exit_all_build_modes() -> void:
	if _cube_build_mode.is_active():
		_cube_build_mode.exit()
	if _ramp_build_mode.is_active():
		_ramp_build_mode.exit()
	if _path_build_mode.is_active():
		_path_build_mode.exit()
	_spawn_toolbar.set_cube_build_active(false)
	_spawn_toolbar.set_ramp_build_active(false)
	_spawn_toolbar.set_path_build_active(false)


func _handle_left_click() -> void:
	var hit := _raycast_from_mouse(0xffffffff)
	if hit.is_empty():
		_deselect_all()
		return

	var collider: Object = hit.collider
	var ball := _get_ball_from_collider(collider)
	if ball:
		_select_ball(ball)
		return

	var character := _get_character_from_collider(collider)
	if character:
		_select_character(character)
	else:
		_deselect_all()


func _handle_right_click() -> void:
	if _selected_ball:
		_throw_dragging = false
		_deselect_ball()
		return

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


func _raycast_from_screen(screen_pos: Vector2, collision_mask: int = 0xffffffff) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_end := ray_origin + camera.project_ray_normal(screen_pos) * RAY_LENGTH

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = collision_mask

	return space_state.intersect_ray(query)


func _raycast_from_mouse(collision_mask: int = 0xffffffff) -> Dictionary:
	return _raycast_from_screen(get_viewport().get_mouse_position(), collision_mask)


func _get_world_point_from_mouse(collision_mask: int = 0xffffffff) -> Vector3:
	var hit := _raycast_from_mouse(collision_mask)
	if not hit.is_empty():
		return hit.position as Vector3

	return _get_ground_point_from_screen(get_viewport().get_mouse_position())


func _get_character_from_collider(collider: Object) -> CharacterBody3D:
	var node: Node = collider as Node
	while node:
		if node.is_in_group("selectable_character") and node is CharacterBody3D:
			return node as CharacterBody3D
		node = node.get_parent()
	return null


func _get_ball_from_collider(collider: Object) -> Ball:
	var node: Node = collider as Node
	while node:
		if node is Ball:
			return node as Ball
		node = node.get_parent()
	return null


func _select_character(character: CharacterBody3D) -> void:
	if _selected_character == character:
		return

	_deselect_all()
	_selected_character = character
	character.select()
	_info_panel.show_character(character)


func _select_ball(ball: Ball) -> void:
	if _selected_ball == ball:
		if not ball.is_thrown():
			ball.prepare_for_next_throw()
		return

	_deselect_all()
	_throw_dragging = false
	_selected_ball = ball
	ball.select()
	_info_panel.show_ball(ball)


func _deselect_ball() -> void:
	if _selected_ball:
		_selected_ball.deselect()
		_selected_ball = null
	if _info_panel:
		_info_panel.hide_panel()


func _deselect_all() -> void:
	_throw_dragging = false
	if _selected_character:
		_selected_character.deselect()
		_selected_character = null
	if _selected_ball:
		_selected_ball.deselect()
		_selected_ball = null
	if _info_panel:
		_info_panel.hide_panel()
