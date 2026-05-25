@tool
extends NavigationRegion3D
class_name PathsNavRegion

const NavigationLayersLib = preload("res://scripts/navigation_layers.gd")
const NavigationUtilsLib = preload("res://scripts/navigation_utils.gd")

const PATH_NAV_GEOMETRY_GROUP := &"path_nav_geometry"

@export var placed_paths_path: NodePath = ^"../PlacedPaths"


func _ready() -> void:
	_apply_region_settings()
	if not Engine.is_editor_hint():
		call_deferred("rebake_from_placed_paths")


func _apply_region_settings() -> void:
	navigation_layers = NavigationLayersLib.LAYER_PATH
	travel_cost = NavigationLayersLib.PATH_TRAVEL_COST
	enter_cost = NavigationLayersLib.PATH_ENTER_COST
	use_edge_connections = true


func rebake_from_placed_paths() -> void:
	var placed_paths := get_node_or_null(placed_paths_path) as Node3D
	if placed_paths == null:
		return

	var bake_mesh := _ensure_navigation_mesh()
	var source_data := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(bake_mesh, source_data, placed_paths)
	NavigationServer3D.bake_from_source_geometry_data(bake_mesh, source_data)
	navigation_mesh = bake_mesh

	var nav_map := get_navigation_map()
	if nav_map != RID():
		NavigationUtilsLib.force_map_update(nav_map)


func _ensure_navigation_mesh() -> NavigationMesh:
	if navigation_mesh != null:
		var duplicate_mesh := navigation_mesh.duplicate() as NavigationMesh
		_configure_bake_mesh(duplicate_mesh)
		return duplicate_mesh

	var bake_mesh := NavigationMesh.new()
	_configure_bake_mesh(bake_mesh)
	return bake_mesh


func _configure_bake_mesh(bake_mesh: NavigationMesh) -> void:
	bake_mesh.agent_radius = 0.25
	bake_mesh.agent_height = 2.0
	bake_mesh.agent_max_slope = 50.0
	bake_mesh.cell_size = 0.25
	bake_mesh.cell_height = 0.25
	bake_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	bake_mesh.geometry_source_group_name = PATH_NAV_GEOMETRY_GROUP
	bake_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
