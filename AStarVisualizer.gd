class_name AStarVisualizer
extends Node

var total_area_bounds: Array[Vector3] = [
	Vector3(-6.0, 0,  3.0), # bottom left
	Vector3(-6.0, 0, -9.0), # top left
	Vector3(  14, 0, -9.0), # top right
	Vector3(  14, 0,  3.0), # bottom right
]

var debug_colors: Array[Color] = [
	Color.from_string("#40004B", Color.WHITE),  # Darkest purple
	Color.from_string("#762A83", Color.WHITE),  # Dark purple
	Color.from_string("#9970AB", Color.WHITE),  # Medium purple
	Color.from_string("#C2A5CF", Color.WHITE),  # Light purple
	Color.from_string("#E7D4E8", Color.WHITE),  # Very light purple
	Color.from_string("#F7F7F7", Color.WHITE),  # White/neutral
	Color.from_string("#D9F0D3", Color.WHITE),  # Very light green
	Color.from_string("#A6DBA0", Color.WHITE),  # Light green
	Color.from_string("#5AAE61", Color.WHITE),  # Medium green
	Color.from_string("#1B7837", Color.WHITE),  # Dark green
	Color.from_string("#00441B", Color.WHITE),  # Darkest green
]

var current_color_index: int= 0
var cell_size: float = 0.25

func draw_navigation_polygons(nav_region: NavigationRegion3D, draw_bounds: bool = false) -> void:
	var vertices = nav_region.navigation_mesh.get_vertices()
	
	if draw_bounds:
		var bounds = nav_region.get_bounds()
		
		# Draw vertical lines at total_area_bounds corners
		var cylinder_height = 3.0
		var cylinder_radius = 0.05
		var radial_segments = 8
		
		# Create cylinders at each corner of the total_area_bounds
		var corners = [
			Vector3(bounds.position.x, 0, bounds.position.z),
			Vector3(bounds.position.x + bounds.size.x, 0, bounds.position.z),
			Vector3(bounds.position.x, 0, bounds.position.z + bounds.size.z),
			Vector3(bounds.position.x + bounds.size.x, 0, bounds.position.z + bounds.size.z)
		]
		
		for corner in corners:
			var cylinder = CSGCylinder3D.new()
			Engine.get_main_loop().root.add_child(cylinder)
			cylinder.radius = cylinder_radius
			cylinder.height = cylinder_height
			cylinder.sides = radial_segments
			cylinder.position = corner + Vector3(0, cylinder_height/2, 0)  # Center the cylinder vertically
			
			# Set material for visibility
			var material = StandardMaterial3D.new()
			material.albedo_color = Color.WHITE
			cylinder.material = material
			cylinder.add_to_group("polygon_mesh")

	for i in nav_region.navigation_mesh.get_polygon_count():
		var polygon = nav_region.navigation_mesh.get_polygon(i)
		
		# Create a MeshInstance3D for the polygon
		var mesh_instance = MeshInstance3D.new()
		var mesh = ImmediateMesh.new()
		mesh_instance.mesh = mesh
		Engine.get_main_loop().root.add_child(mesh_instance)
		
		# Set up material with current color
		current_color_index = (current_color_index + 1) % debug_colors.size()
		var polygon_color = debug_colors[current_color_index]
		var material = StandardMaterial3D.new()
		material.albedo_color = polygon_color
		mesh_instance.material_override = material
		
		# Draw the polygon
		mesh.clear_surfaces()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		# Create triangle fan
		var first_vertex = vertices[polygon[0]]
		for vertex_pos in range(1, polygon.size() - 1):
			mesh.surface_add_vertex(first_vertex)
			mesh.surface_add_vertex(vertices[polygon[vertex_pos]])
			mesh.surface_add_vertex(vertices[polygon[vertex_pos + 1]])
		mesh.surface_end()
		
		mesh_instance.add_to_group("polygon_mesh")

func draw_grid(full_color: bool = false) -> void:
	assert(cell_size > 0, "Cell size must be greater than 0")
	
	# Visualize grid points
	for point in get_parent().astar_node.astar.point_to_id.keys():
		var debug_box = BoxMesh.new()
		var mesh_instance = MeshInstance3D.new()
		
		# Set box properties
		debug_box.size = Vector3(0.1, 0.1, 0.1)
		mesh_instance.mesh = debug_box
		mesh_instance.position = point
		
		# Create red material
		var material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1, 0, 0, 1.0 if full_color else 0.3)
		mesh_instance.material_override = material
		
		Engine.get_main_loop().root.add_child(mesh_instance)
		mesh_instance.add_to_group("grid_mesh")

func clear_grid() -> void:
	for mesh in Engine.get_main_loop().root.get_tree().get_nodes_in_group("grid_mesh"):
		mesh.queue_free()

func clear_polygons() -> void:
	for mesh in Engine.get_main_loop().root.get_tree().get_nodes_in_group("polygon_mesh"):
		mesh.queue_free()
