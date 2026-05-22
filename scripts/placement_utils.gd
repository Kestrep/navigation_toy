extends RefCounted
class_name PlacementUtils


static func snap_position_to_grid(world_point: Vector3) -> Vector3:
	return Vector3(
		snappedf(world_point.x, 1.0),
		world_point.y,
		snappedf(world_point.z, 1.0)
	)
