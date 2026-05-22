extends CharacterBody3D

const Ball = preload("res://scripts/ball.gd")
const CatStarIndicatorScene = preload("res://scenes/CatStarIndicator.tscn")

@export var move_speed: float = 2.5
@export var pause_duration: float = 1.5
@export var ball_chase_radius: float = 10.0
@export var ball_catch_radius: float = 0.5
@export var avoidance_separation_radius: float = 0.15
@export var turn_speed: float = 10.0

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var _is_pausing: bool = false
var _pause_time_left: float = 0.0
var _is_chasing_ball: bool = false
var _ball: Ball = null
var _was_within_catch_radius: bool = false
var _active_star: Control = null


func _ready() -> void:
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	navigation_agent.radius = avoidance_separation_radius
	navigation_agent.max_speed = move_speed

	await get_tree().physics_frame
	_connect_to_ball()
	_pick_random_wander_target()


func _physics_process(delta: float) -> void:
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) == 0:
		return

	_update_catch_star()

	if not _is_chasing_ball and _should_chase_ball():
		_begin_chase()

	if _is_chasing_ball:
		_chase_ball(delta)
		return

	if _is_pausing:
		velocity = Vector3.ZERO
		navigation_agent.set_velocity(Vector3.ZERO)
		_pause_time_left -= delta
		if _pause_time_left <= 0.0:
			_is_pausing = false
			_pick_random_wander_target()
		return

	if navigation_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		navigation_agent.set_velocity(Vector3.ZERO)
		_start_pause()
		return

	var next_position: Vector3 = navigation_agent.get_next_path_position()
	var direction := global_position.direction_to(next_position)
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
	var desired_velocity := direction * move_speed
	_update_facing(direction, delta)
	navigation_agent.set_velocity(desired_velocity)


func _connect_to_ball() -> void:
	for node in get_tree().get_nodes_in_group("selectable_ball"):
		if node is Ball:
			_ball = node as Ball
			break

	if _ball == null:
		return

	if not _ball.movement_stopped.is_connected(_on_ball_movement_stopped):
		_ball.movement_stopped.connect(_on_ball_movement_stopped)


func _should_chase_ball() -> bool:
	if _ball == null or not is_instance_valid(_ball) or not _ball.is_thrown():
		return false
	return _get_ball_distance_squared() <= ball_chase_radius * ball_chase_radius


func _get_ball_distance_squared() -> float:
	var offset := _ball.global_position - global_position
	offset.y = 0.0
	return offset.length_squared()


func _update_catch_star() -> void:
	if _ball == null or not is_instance_valid(_ball):
		_was_within_catch_radius = false
		return

	var catch_radius_sq := ball_catch_radius * ball_catch_radius
	var within := _get_ball_distance_squared() <= catch_radius_sq
	if within and not _was_within_catch_radius:
		_spawn_catch_star()
		_register_catch()
	_was_within_catch_radius = within


func _spawn_catch_star() -> void:
	if _active_star != null and is_instance_valid(_active_star):
		return

	var star: Control = CatStarIndicatorScene.instantiate()
	star.setup(self)
	_active_star = star
	star.tree_exited.connect(_on_catch_star_exited)


func _on_catch_star_exited() -> void:
	_active_star = null


func _register_catch() -> void:
	var main := get_tree().current_scene
	if main and main.has_method("register_cat_catch"):
		main.register_cat_catch()


func _begin_chase() -> void:
	_is_chasing_ball = true
	_is_pausing = false
	_pause_time_left = 0.0


func _end_chase(with_pause: bool) -> void:
	_is_chasing_ball = false
	velocity = Vector3.ZERO
	navigation_agent.set_velocity(Vector3.ZERO)
	if with_pause:
		_start_pause()
	else:
		_pick_random_wander_target()


func _on_ball_movement_stopped() -> void:
	if not _is_chasing_ball:
		return
	_end_chase(true)


func _chase_ball(delta: float) -> void:
	if _ball == null or not is_instance_valid(_ball) or not _ball.is_thrown():
		_end_chase(true)
		return

	if _get_ball_distance_squared() > ball_chase_radius * ball_chase_radius:
		_end_chase(false)
		return

	var nav_map := navigation_agent.get_navigation_map()
	var target := NavigationServer3D.map_get_closest_point(nav_map, _ball.global_position)
	navigation_agent.target_position = target

	var next_position: Vector3 = navigation_agent.get_next_path_position()
	var direction := global_position.direction_to(next_position)
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
	var desired_velocity := direction * move_speed
	_update_facing(direction, delta)
	navigation_agent.set_velocity(desired_velocity)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	move_and_slide()
	if safe_velocity.length_squared() > 0.01:
		_update_facing(safe_velocity, get_physics_process_delta_time())


func _update_facing(flat_direction: Vector3, delta: float) -> void:
	var direction := Vector3(flat_direction.x, 0.0, flat_direction.z)
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)


func _start_pause() -> void:
	if _is_pausing:
		return
	_is_pausing = true
	_pause_time_left = pause_duration


func _pick_random_wander_target() -> void:
	var nav_map := navigation_agent.get_navigation_map()
	if nav_map == RID():
		return

	var random_point := NavigationServer3D.map_get_random_point(
		nav_map,
		navigation_agent.navigation_layers,
		false
	)
	if random_point == Vector3.ZERO:
		return

	navigation_agent.target_position = random_point
