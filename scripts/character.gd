extends CharacterBody3D

@export var move_speed: float = 4.0
@export var pause_duration: float = 1.0
@export var avoidance_separation_radius: float = 0.35
@export var rvo_activation_distance: float = 2.0
@export var stuck_bypass_duration: float = 0.75

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _material_normal: StandardMaterial3D
var _material_selected: StandardMaterial3D
var _is_selected: bool = false
var _is_pausing: bool = false
var _pause_time_left: float = 0.0
var _first_name: String = ""
var _last_name: String = ""
var _description_text: String = ""
var _last_desired_velocity: Vector3 = Vector3.ZERO
var _bypass_avoidance_time_left: float = 0.0
var _bypass_velocity: Vector3 = Vector3.ZERO
var _stuck_frames: int = 0
var _yield_side_sign: float = 1.0
var _rvo_activation_distance_sq: float = 0.0


func _ready() -> void:
	add_to_group("selectable_character")

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var identity: Dictionary = CharacterIdentity.create(rng)
	_first_name = identity["first_name"]
	_last_name = identity["last_name"]
	_description_text = identity["description"]
	_yield_side_sign = 1.0 if rng.randf() >= 0.5 else -1.0

	_material_normal = StandardMaterial3D.new()
	_material_normal.albedo_color = Color(0.2, 0.5, 1.0)

	_material_selected = StandardMaterial3D.new()
	_material_selected.albedo_color = Color(1.0, 0.9, 0.1)

	mesh_instance.set_surface_override_material(0, _material_normal)

	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	navigation_agent.radius = avoidance_separation_radius
	navigation_agent.max_speed = move_speed
	navigation_agent.avoidance_priority = rng.randf_range(0.2, 0.8)
	_rvo_activation_distance_sq = rvo_activation_distance * rvo_activation_distance

	await get_tree().physics_frame
	_pick_random_wander_target()


func select() -> void:
	_is_selected = true
	mesh_instance.set_surface_override_material(0, _material_selected)


func deselect() -> void:
	_is_selected = false
	mesh_instance.set_surface_override_material(0, _material_normal)


func is_selected() -> bool:
	return _is_selected


func get_display_name() -> String:
	return "%s %s" % [_first_name, _last_name]


func get_description_text() -> String:
	return _description_text


func set_move_target(world_pos: Vector3) -> void:
	_cancel_pause()
	_reset_unstuck_state()
	navigation_agent.target_position = world_pos


func _physics_process(delta: float) -> void:
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) == 0:
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
	_last_desired_velocity = desired_velocity

	if _bypass_avoidance_time_left > 0.0:
		_bypass_avoidance_time_left -= delta
		velocity = _bypass_velocity
		move_and_slide()
		return

	if _should_use_rvo():
		navigation_agent.set_velocity(desired_velocity)
		return

	_stuck_frames = 0
	velocity = desired_velocity
	move_and_slide()


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if _bypass_avoidance_time_left > 0.0:
		return

	var desired_speed := _last_desired_velocity.length()
	var safe_speed := safe_velocity.length()
	if desired_speed > move_speed * 0.25 and safe_speed < 0.15:
		_stuck_frames += 1
		if _stuck_frames >= 6:
			_start_unstuck()
	else:
		_stuck_frames = 0

	velocity = safe_velocity
	move_and_slide()


func _should_use_rvo() -> bool:
	for node in get_tree().get_nodes_in_group("selectable_character"):
		if node == self:
			continue
		if not node is Node3D:
			continue
		var other := node as Node3D
		if global_position.distance_squared_to(other.global_position) <= _rvo_activation_distance_sq:
			return true
	return false


func _start_unstuck() -> void:
	_bypass_velocity = _compute_sidestep_velocity(_last_desired_velocity)
	_bypass_avoidance_time_left = stuck_bypass_duration
	_stuck_frames = 0


func _compute_sidestep_velocity(desired: Vector3) -> Vector3:
	var flat := Vector3(desired.x, 0.0, desired.z)
	if flat.length_squared() < 0.0001:
		return Vector3.ZERO
	flat = flat.normalized()
	var side := Vector3.UP.cross(flat) * _yield_side_sign
	return (flat * 0.3 + side).normalized() * move_speed


func _reset_unstuck_state() -> void:
	_bypass_avoidance_time_left = 0.0
	_bypass_velocity = Vector3.ZERO
	_stuck_frames = 0


func _start_pause() -> void:
	if _is_pausing:
		return
	_is_pausing = true
	_pause_time_left = pause_duration


func _cancel_pause() -> void:
	_is_pausing = false
	_pause_time_left = 0.0


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
