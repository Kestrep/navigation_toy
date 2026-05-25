extends RefCounted
class_name PathNetwork

## Grille des tiles DirtPath (visuels / outil). Pas de pathfinding — utiliser NavigationServer3D.

const INVALID_CELL := Vector2i(999999, 999999)

static var _cells: Dictionary = {}


static func refresh_from_node(start_node: Node) -> void:
	_cells.clear()
	if not start_node.is_inside_tree():
		return

	var placed_paths := start_node.get_tree().root.find_child("PlacedPaths", true, false)
	if placed_paths == null:
		return

	for child in placed_paths.get_children():
		if not child is Node3D:
			continue
		var path_node := child as Node3D
		var cell := cell_from_node(path_node)
		if cell == INVALID_CELL:
			continue
		_cells[cell] = true


static func has_any_cell() -> bool:
	return not _cells.is_empty()


static func has_cell(cell: Vector2i) -> bool:
	return _cells.has(cell)


static func world_to_cell(world_pos: Vector3) -> Vector2i:
	return Vector2i(roundi(world_pos.x), roundi(world_pos.z))


static func cell_from_node(node: Node3D) -> Vector2i:
	if node == null:
		return INVALID_CELL
	if Engine.is_editor_hint():
		return world_to_cell(node.global_position)
	if node.has_method(&"get_cell"):
		return node.call("get_cell") as Vector2i
	return world_to_cell(node.global_position)


static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x, 0.0, cell.y)
