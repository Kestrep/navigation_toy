extends Label

func show_throw(direction: Vector3, speed: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	text = "Direction: (%.2f, %.2f, %.2f)  Vitesse: %.2f" % [flat.x, flat.y, flat.z, speed]
	visible = true
