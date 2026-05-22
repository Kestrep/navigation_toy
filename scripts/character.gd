extends CharacterBody3D

@export var move_speed: float = 4.0
@export var pause_duration: float = 1.0
## Rayon d'évitement RVO : distance minimale entre centres = 2× cette valeur (~1 m d'écart entre cylindres).
@export var avoidance_separation_radius: float = 1.0

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


func _ready() -> void:
	add_to_group("selectable_character")

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var identity: Dictionary = CharacterIdentity.create(rng)
	_first_name = identity["first_name"]
	_last_name = identity["last_name"]
	_description_text = identity["description"]

	_material_normal = StandardMaterial3D.new()
	_material_normal.albedo_color = Color(0.2, 0.5, 1.0)

	_material_selected = StandardMaterial3D.new()
	_material_selected.albedo_color = Color(1.0, 0.9, 0.1)

	mesh_instance.set_surface_override_material(0, _material_normal)

	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	navigation_agent.radius = avoidance_separation_radius
	navigation_agent.max_speed = move_speed

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
	navigation_agent.set_velocity(desired_velocity)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	move_and_slide()


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
