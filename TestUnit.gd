extends CharacterBody3D

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

const AStarNode = preload("res://AStarNode.gd")
@onready var astar_node: AStarNode = %AStarNode

var navigation_agent_path_to_follow: PackedVector3Array = []

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

func create_path_sphere(point: Vector3, is_new: bool = false) -> void:
	var sphere = CSGSphere3D.new()
	sphere.radius = 0.2
	sphere.position = point
	sphere.material = StandardMaterial3D.new()
	sphere.material.albedo_color = Color.GREEN if is_new else Color.BLUE
	get_parent().add_child(sphere)
	sphere.add_to_group("nav_points")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		var current_mouse_position: Vector2 = get_viewport().get_mouse_position()
		# cast to world position
		var target_position: Vector3 = get_vector3_from_camera_raycast(get_viewport().get_camera_3d(), current_mouse_position)
		# get our path
		var result = astar_node.astar.get_path_from_point_to_point(global_position, target_position)
		navigation_agent_path_to_follow = result.path

		# Create spheres for each point in the path
		# but first clear the existing spheres
		for mesh in get_parent().get_tree().get_nodes_in_group("nav_points"):
			mesh.queue_free()
		for point in result.path:
			create_path_sphere(point, true)

		# now lets get the navigation via the base server
		var start_position = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, global_position)
		var end_position = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, target_position)

		navigation_agent_3d.target_position = navigation_agent_path_to_follow[0]

		# query it
		var base_path: PackedVector3Array = NavigationServer3D.map_get_path(
			get_world_3d().navigation_map,  # The navigation map
			start_position,                 # Starting position
			end_position,                   # Target position
			true,                          # Optimize path (optional)
			1
		)

		for point in base_path:
			# create blue spheres
			create_path_sphere(point, false)

func _process(_delta: float) -> void:
	if navigation_agent_3d.is_target_reached():
		if navigation_agent_path_to_follow.size() == 0:
			return
		# Remove the reached point and set next target if available
		navigation_agent_path_to_follow.remove_at(0)
		if navigation_agent_path_to_follow.size() > 0:
			navigation_agent_3d.target_position = navigation_agent_path_to_follow[0]
		else:
			return

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
