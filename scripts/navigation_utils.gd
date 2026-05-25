extends RefCounted
class_name NavigationUtils

const NavigationLayersLib = preload("res://scripts/navigation_layers.gd")


static func get_nav_map_from_region(region: NavigationRegion3D) -> RID:
	if region == null:
		return RID()
	return region.get_navigation_map()


static func snap_to_navmesh(nav_map: RID, world_pos: Vector3) -> Vector3:
	if nav_map == RID():
		return world_pos

	var closest := NavigationServer3D.map_get_closest_point(nav_map, world_pos)
	if closest == Vector3.ZERO:
		return world_pos
	return closest


static func pick_random_point_on_map(
	nav_map: RID,
	layers: int,
	from_position: Vector3,
	min_distance: float = 0.0,
	attempts: int = 12
) -> Vector3:
	if nav_map == RID():
		return Vector3.ZERO

	var best_point := Vector3.ZERO
	var best_distance_sq := -1.0
	var min_distance_sq := min_distance * min_distance

	for _i in range(attempts):
		var candidate := NavigationServer3D.map_get_random_point(nav_map, layers, false)
		if candidate == Vector3.ZERO:
			continue

		var distance_sq := from_position.distance_squared_to(candidate)
		if min_distance_sq > 0.0 and distance_sq < min_distance_sq:
			continue

		if distance_sq > best_distance_sq:
			best_distance_sq = distance_sq
			best_point = candidate

	if best_point != Vector3.ZERO:
		return best_point

	return NavigationServer3D.map_get_random_point(nav_map, layers, false)


static func force_map_update(nav_map: RID) -> void:
	if nav_map == RID():
		return
	NavigationServer3D.map_force_update(nav_map)


static func is_near_path_tile(tree: SceneTree, world_pos: Vector3) -> bool:
	if tree == null:
		return false

	var placed_paths := tree.root.find_child("PlacedPaths", true, false)
	if placed_paths == null:
		return false

	var proximity_sq := NavigationLayersLib.PATH_TILE_PROXIMITY * NavigationLayersLib.PATH_TILE_PROXIMITY
	for child in placed_paths.get_children():
		if not child is Node3D:
			continue
		var path_node := child as Node3D
		var flat_offset := Vector2(
			path_node.global_position.x - world_pos.x,
			path_node.global_position.z - world_pos.z
		)
		if flat_offset.length_squared() <= proximity_sq:
			return true

	return false
