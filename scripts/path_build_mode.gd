extends Node3D

const PATH_SCENE: PackedScene = preload("res://scenes/DirtPath.tscn")
const _PlacementUtils = preload("res://scripts/placement_utils.gd")
const PREVIEW_COLOR := Color(0.68, 0.48, 0.3, 0.55)
const GROUND_Y := 0.0
const _INVALID_CELL := Vector2i(999999, 999999)

const _NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

signal mode_entered
signal mode_exited

@onready var _paths_container: Node3D = $"../NavigationRegion3D/Ground/DevWorldLayout/PlacedPaths"
@onready var _main: Node3D = get_parent()

var _nav_sync_queued: bool = false

var _preview: DirtPath
var _active: bool = false
var _painting: bool = false
var _last_painted_cell := Vector2i(999999, 999999)
var _preview_cell := _INVALID_CELL
var _placed_cells: Dictionary = {}


func is_active() -> bool:
	return _active


func enter() -> void:
	if _active:
		return
	_active = true
	_painting = false
	_last_painted_cell = Vector2i(999999, 999999)
	_preview_cell = _INVALID_CELL
	_rebuild_placed_cells()
	_refresh_all_paths()
	_create_preview()
	mode_entered.emit()


func exit() -> void:
	if not _active:
		return
	_active = false
	_painting = false
	_clear_preview_neighbor_preview()
	if _preview:
		_preview.queue_free()
		_preview = null
	mode_exited.emit()


func handle_mouse_button(button_index: int, pressed: bool = true) -> void:
	if not _active:
		return

	match button_index:
		MOUSE_BUTTON_LEFT:
			if pressed:
				_painting = true
				_try_paint_at_cursor()
			else:
				_painting = false
				_last_painted_cell = Vector2i(999999, 999999)
		MOUSE_BUTTON_RIGHT:
			if pressed:
				exit()


func _process(_delta: float) -> void:
	if not _active or _preview == null:
		return

	var world_point := _get_placement_point()
	if world_point == Vector3.INF:
		_preview.visible = false
		_clear_preview_neighbor_preview()
		return

	var cell := _cell_from_world(world_point)
	if _placed_cells.has(cell):
		_preview.visible = false
		_clear_preview_neighbor_preview()
		if _painting:
			_try_paint_at_cursor()
		return

	if cell != _preview_cell:
		_clear_preview_neighbor_preview()
		_preview_cell = cell

	_preview.visible = true
	_preview.global_position = Vector3(cell.x, GROUND_Y, cell.y)
	_preview.update_connections(_cell_has_path_with_preview)
	_refresh_placed_neighbors(cell, _cell_has_path_with_preview)

	if _painting:
		_try_paint_at_cursor()


func _create_preview() -> void:
	_preview = PATH_SCENE.instantiate() as DirtPath
	_preview.set_path_navigation_enabled(false)
	add_child(_preview)
	_apply_preview_material(_preview)


func _apply_preview_material(path: DirtPath) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = PREVIEW_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for mesh: MeshInstance3D in path.get_visual_meshes():
		if mesh == null:
			continue
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _try_paint_at_cursor() -> void:
	var world_point := _get_placement_point()
	if world_point == Vector3.INF:
		return

	var cell := _cell_from_world(world_point)
	if cell == _last_painted_cell or _placed_cells.has(cell):
		_last_painted_cell = cell
		return

	_place_path_at_cell(cell)
	_last_painted_cell = cell


func _place_path_at_cell(cell: Vector2i) -> void:
	var path := PATH_SCENE.instantiate() as DirtPath
	_paths_container.add_child(path)
	path.global_position = Vector3(cell.x, GROUND_Y, cell.y)
	path.snap_to_grid()
	_placed_cells[cell] = path
	if cell == _preview_cell:
		_preview_cell = _INVALID_CELL
	_refresh_path_and_neighbors(cell)
	_queue_nav_sync()


func _refresh_all_paths() -> void:
	for cell in _placed_cells:
		_refresh_path_at_cell(cell, _cell_has_path)


func _refresh_path_and_neighbors(cell: Vector2i) -> void:
	_refresh_path_at_cell(cell, _cell_has_path)
	for offset in _NEIGHBOR_OFFSETS:
		_refresh_path_at_cell(cell + offset, _cell_has_path)


func _refresh_placed_neighbors(center: Vector2i, cell_has_path: Callable) -> void:
	for offset in _NEIGHBOR_OFFSETS:
		_refresh_path_at_cell(center + offset, cell_has_path)


func _refresh_path_at_cell(cell: Vector2i, cell_has_path: Callable) -> void:
	if not _placed_cells.has(cell):
		return

	var path: DirtPath = _placed_cells[cell] as DirtPath
	path.snap_to_grid()
	path.update_connections(cell_has_path)


func _clear_preview_neighbor_preview() -> void:
	if _preview_cell == _INVALID_CELL:
		return
	_refresh_placed_neighbors(_preview_cell, _cell_has_path)
	_preview_cell = _INVALID_CELL


func _cell_has_path(cell: Vector2i) -> bool:
	return _placed_cells.has(cell)


func _cell_has_path_with_preview(cell: Vector2i) -> bool:
	return _placed_cells.has(cell) or cell == _preview_cell


func _rebuild_placed_cells() -> void:
	_placed_cells.clear()
	for child in _paths_container.get_children():
		if child is DirtPath:
			var path := child as DirtPath
			path.snap_to_grid()
			_placed_cells[path.get_cell()] = path


func _cell_from_world(world_point: Vector3) -> Vector2i:
	var grid_position := _PlacementUtils.snap_position_to_ground_grid(world_point, GROUND_Y)
	return Vector2i(int(grid_position.x), int(grid_position.z))


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

	var t := (GROUND_Y - ray_origin.y) / ray_direction.y
	if t < 0.0:
		return Vector3.INF

	return ray_origin + ray_direction * t


func _queue_nav_sync() -> void:
	if _nav_sync_queued:
		return
	_nav_sync_queued = true
	call_deferred("_run_nav_sync")


func _run_nav_sync() -> void:
	_nav_sync_queued = false
	if _main and _main.has_method(&"sync_navigation"):
		_main.call("sync_navigation")
