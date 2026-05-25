@tool
extends Node3D
class_name DevWorldLayout

const PathNetworkLib = preload("res://scripts/path_network.gd")
const PATH_SCENE: PackedScene = preload("res://scenes/DirtPath.tscn")
const HOUSE_SCENE: PackedScene = preload("res://scenes/WoodenHouse.tscn")
const TENT_SCENE: PackedScene = preload("res://scenes/TentSite.tscn")

@export var enabled: bool = true:
	set(value):
		enabled = value
		if Engine.is_editor_hint() and is_inside_tree():
			_sync_layout()


func _ready() -> void:
	if enabled:
		_sync_layout()


func _sync_layout() -> void:
	var paths_parent := _ensure_paths_parent()
	_sync_paths(paths_parent)
	_sync_buildings()
	if Engine.is_editor_hint():
		call_deferred("_finish_paths_sync", paths_parent)
	else:
		_finish_paths_sync(paths_parent)


func _finish_paths_sync(paths_parent: Node3D) -> void:
	refresh_paths(paths_parent)
	PathNetworkLib.refresh_from_node(self)
	var paths_nav := get_node_or_null("PathsNavRegion") as PathsNavRegion
	if paths_nav:
		paths_nav.rebake_from_placed_paths()
	# Le rebake du sol est géré par Main._ready / modes construction (évite l'appel avant @onready).


func request_ground_nav_sync() -> void:
	if Engine.is_editor_hint():
		return
	var main := _find_main_node()
	if main and main.has_method(&"sync_navigation"):
		main.sync_navigation()


func _find_main_node() -> Node:
	var node: Node = self
	while node != null:
		var script_path: String = node.get_script().resource_path if node.get_script() else ""
		if script_path.ends_with("main.gd"):
			return node
		node = node.get_parent()
	return null


func _ensure_paths_parent() -> Node3D:
	var paths_parent := get_node_or_null("PlacedPaths") as Node3D
	if paths_parent != null:
		return paths_parent

	paths_parent = Node3D.new()
	paths_parent.name = "PlacedPaths"
	add_child(paths_parent)
	if Engine.is_editor_hint():
		paths_parent.owner = get_tree().edited_scene_root
	return paths_parent


static func refresh_paths(paths_parent: Node3D) -> void:
	var cells: Dictionary = {}
	for child in paths_parent.get_children():
		if not child is Node3D:
			continue
		var path_node := child as Node3D
		var cell := PathNetworkLib.cell_from_node(path_node)
		cells[cell] = path_node

	var cell_has_path := func(cell: Vector2i) -> bool:
		return cells.has(cell)

	for path_node in cells.values():
		if path_node.has_method(&"update_connections"):
			path_node.call("update_connections", cell_has_path)


func _sync_paths(paths_parent: Node3D) -> void:
	for cell in _collect_route_cells():
		var node_name := "DirtPath_%d_%d" % [cell.x, cell.y]
		if paths_parent.get_node_or_null(NodePath(node_name)) != null:
			continue

		var path := PATH_SCENE.instantiate() as DirtPath
		path.name = node_name
		paths_parent.add_child(path)
		path.global_position = Vector3(cell.x, 0.0, cell.y)
		_set_scene_owner(path)


func _sync_buildings() -> void:
	_ensure_building("WoodenHouse_West", HOUSE_SCENE, Vector3(-9, 0, 3))
	_ensure_building("WoodenHouse_South", HOUSE_SCENE, Vector3(-8, 0, -3))
	_ensure_building("WoodenHouse_NorthEast", HOUSE_SCENE, Vector3(8, 0, 7))
	_ensure_building("TentSite_Main", TENT_SCENE, Vector3(-2, 0, 2))
	_ensure_building("TentSite_South", TENT_SCENE, Vector3(-5, 0, -7))


func _ensure_building(node_name: String, scene: PackedScene, world_position: Vector3) -> void:
	if get_node_or_null(NodePath(node_name)) != null:
		return

	var building := scene.instantiate()
	building.name = node_name
	add_child(building)
	building.global_position = world_position
	_set_scene_owner(building)


func _set_scene_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return

	var scene_root := get_tree().edited_scene_root
	if scene_root == null:
		return

	# Ne pas parcourir les enfants : sinon Godot « éclate » les scènes instanciées dans main.tscn.
	node.owner = scene_root


func _collect_route_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var seen: Dictionary = {}

	for x in range(-10, 9):
		_add_cell(cells, seen, Vector2i(x, 0))

	for z in range(-9, 0):
		_add_cell(cells, seen, Vector2i(-5, z))

	for z in range(1, 7):
		_add_cell(cells, seen, Vector2i(3, z))

	for x in range(4, 10):
		_add_cell(cells, seen, Vector2i(x, 6))

	return cells


func _add_cell(cells: Array[Vector2i], seen: Dictionary, cell: Vector2i) -> void:
	if seen.has(cell):
		return
	seen[cell] = true
	cells.append(cell)
