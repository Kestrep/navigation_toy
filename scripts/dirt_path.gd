@tool
extends Node3D
class_name DirtPath

const NavigationLayersLib = preload("res://scripts/navigation_layers.gd")

const PATH_NAV_GEOMETRY_GROUP := &"path_nav_geometry"
const MESH_Y := 0.01

const NEIGHBOR_OFFSETS := {
	"east": Vector2i(1, 0),
	"west": Vector2i(-1, 0),
	"south": Vector2i(0, 1),
	"north": Vector2i(0, -1),
}

@onready var _visuals: Node3D = $Visuals
@onready var _path_navigation: NavigationRegion3D = $PathNavigation
@onready var _nav_ground_cutout: StaticBody3D = $NavGroundCutout


func _ready() -> void:
	_snap_to_grid()
	_register_nav_geometry_groups()
	_apply_path_navigation_settings()


func set_path_navigation_enabled(enabled: bool) -> void:
	if _path_navigation == null:
		_path_navigation = get_node_or_null("PathNavigation") as NavigationRegion3D
	if _path_navigation and not _uses_monolithic_paths():
		_path_navigation.enabled = enabled


func _apply_path_navigation_settings() -> void:
	if _path_navigation == null:
		return

	_path_navigation.navigation_layers = NavigationLayersLib.LAYER_PATH
	_path_navigation.travel_cost = NavigationLayersLib.PATH_TRAVEL_COST
	_path_navigation.enter_cost = NavigationLayersLib.PATH_ENTER_COST
	_path_navigation.use_edge_connections = true
	_path_navigation.enabled = not _uses_monolithic_paths()


func _uses_monolithic_paths() -> bool:
	if not is_inside_tree():
		return true
	return get_tree().root.find_child("PathsNavRegion", true, false) != null


func _register_nav_geometry_groups() -> void:
	for mesh: MeshInstance3D in get_visual_meshes():
		if mesh == null:
			continue
		mesh.add_to_group(PATH_NAV_GEOMETRY_GROUP)


func get_cell() -> Vector2i:
	return Vector2i(roundi(global_position.x), roundi(global_position.z))


func snap_to_grid() -> void:
	_snap_to_grid()


func update_connections(cell_has_path: Callable) -> void:
	var neighbors := gather_neighbors(get_cell(), cell_has_path)
	_apply_neighbors(neighbors)
	_register_nav_geometry_groups()


func get_visual_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if _visuals == null:
		_visuals = get_node_or_null("Visuals") as Node3D
	if _visuals == null:
		return meshes

	for child in _visuals.get_children():
		if child is MeshInstance3D:
			meshes.append(child as MeshInstance3D)
	return meshes


static func gather_neighbors(cell: Vector2i, cell_has_path: Callable) -> Dictionary:
	var neighbors := {}
	for key in NEIGHBOR_OFFSETS:
		neighbors[key] = cell_has_path.call(cell + NEIGHBOR_OFFSETS[key])
	return neighbors


func _snap_to_grid() -> void:
	var cell := Vector2i(roundi(global_position.x), roundi(global_position.z))
	global_position = Vector3(cell.x, global_position.y, cell.y)


func _apply_neighbors(neighbors: Dictionary) -> void:
	var center := _get_mesh("Center")
	var arm_east := _get_mesh("ArmEast")
	var arm_west := _get_mesh("ArmWest")
	var arm_south := _get_mesh("ArmSouth")
	var arm_north := _get_mesh("ArmNorth")

	if center:
		center.visible = true
	if arm_east:
		arm_east.visible = neighbors.get("east", false)
	if arm_west:
		arm_west.visible = neighbors.get("west", false)
	if arm_south:
		arm_south.visible = neighbors.get("south", false)
	if arm_north:
		arm_north.visible = neighbors.get("north", false)


func _get_mesh(part_name: String) -> MeshInstance3D:
	if _visuals == null:
		_visuals = get_node_or_null("Visuals") as Node3D
	if _visuals == null:
		return null
	return _visuals.get_node_or_null(part_name) as MeshInstance3D
