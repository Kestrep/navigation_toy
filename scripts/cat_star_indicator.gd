extends Control

const DURATION_SEC := 5.0
const PIXEL_SIZE := Vector2(50, 50)
const HEIGHT_OFFSET := 1.0

var _target: Node3D = null
var _time_left := DURATION_SEC


func setup(target: Node3D) -> void:
	_target = target
	custom_minimum_size = PIXEL_SIZE
	size = PIXEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var canvas := target.get_tree().current_scene.get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas:
		canvas.add_child(self)

	_update_screen_position()


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return

	if _target == null or not is_instance_valid(_target):
		queue_free()
		return

	_update_screen_position()


func _update_screen_position() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var world_pos := _target.global_position + Vector3(0.0, HEIGHT_OFFSET, 0.0)
	if camera.is_position_behind(world_pos):
		visible = false
		return

	visible = true
	var screen_pos := camera.unproject_position(world_pos)
	position = Vector2(screen_pos.x - size.x * 0.5, screen_pos.y - size.y)
