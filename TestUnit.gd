extends CharacterBody3D

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

func get_vector3_from_camera_raycast(camera: Camera3D, camera_2D_Coords: Vector2) -> Vector3:
	var result: Dictionary = fire_raycast_from_camera(camera, camera_2D_Coords)

	if result:
		return result.position
	else:
		return Vector3.ZERO

func fire_raycast_from_camera(camera: Camera3D, camera_2D_Coords: Vector2) -> Dictionary:
	var ray_from: Vector3 = camera.project_ray_origin(camera_2D_Coords)
	var ray_to: Vector3 = ray_from + camera.project_ray_normal(camera_2D_Coords) * 1000
	var ray_parameters: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	return camera.get_world_3d().get_direct_space_state().intersect_ray(ray_parameters)

func _ready() -> void:
	navigation_agent_3d.velocity_computed.connect(nav_velocity_calculated)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()
	if event.is_action_pressed("select"):
		var current_mouse_position: Vector2 = get_viewport().get_mouse_position()
		navigation_agent_3d.target_position = get_vector3_from_camera_raycast(get_viewport().get_camera_3d(), current_mouse_position)
		print("target acquired", current_mouse_position)

func _physics_process(delta: float) -> void:
	if navigation_agent_3d.is_navigation_finished():
		return
	handle_normal_movement(navigation_agent_3d.get_next_path_position(), delta)

func handle_normal_movement(next_position: Vector3, delta: float) -> void:
	var distance_to_target = global_position.distance_to(next_position)
	
	if navigation_agent_3d.is_navigation_finished() or distance_to_target < 0.2:
		velocity = velocity.move_toward(Vector3.ZERO, delta * 20.0)
		navigation_agent_3d.velocity = velocity
	else:
		var direction = global_position.direction_to(next_position)
		direction.y = 0
		
		var target_speed = 5.0 
		var desired_velocity = direction * target_speed
		
		velocity = velocity.move_toward(desired_velocity, delta * 10.0)
		navigation_agent_3d.velocity = velocity

func nav_velocity_calculated(calculated_velocity: Vector3) -> void:
	velocity = calculated_velocity
	move_and_slide()
