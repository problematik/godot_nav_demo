class_name AStarCustom
extends AStar3D

var point_to_id = {}  # Vector3 -> int
var id_to_point = {}  # int -> Vector3
var point_to_region = {}  # Vector3 -> RID
var cell_size = 0.25

var regions: Array[NavigationRegion3D] = []
var regions_by_rid: Dictionary = {}  # RID -> NavigationRegion3D
var regions_to_find: Array[RID] = []
var regions_found: Array[NavigationRegion3D] = []

var current_point_id = 0


@export var x_size: float = 500.0
@export var z_size: float = 500.0

signal _on_map_updated()

func _find_all_regions(parent: Node) -> Array[NavigationRegion3D]:
	var found: Array[NavigationRegion3D] = []
	var root = parent
	while root.get_parent() != null:
		root = root.get_parent()

	found.append_array(_search_children(root))
	return found

func _search_children(node: Node) -> Array[NavigationRegion3D]:
	var found: Array[NavigationRegion3D] = []
	for child in node.get_children():
		if is_instance_of(child, NavigationRegion3D):
			found.append(child)
		found.append_array(_search_children(child))
	return found

func init(parent) -> void:
	var found_regions = _find_all_regions(parent)
	for region in found_regions:
		regions_to_find.append(region.get_region_rid())
	
	NavigationServer3D.map_changed.connect(_regions_changed)

func _on_all_regions_updated() -> void:
	assert(NavigationServer3D.get_maps().size() == 1, "Invalid number of NavigationMaps found")

	var map = NavigationServer3D.get_maps()[0]
	assert(map != null, "Invalid map found")

	var rids = NavigationServer3D.map_get_regions(map)
	assert(rids.size() != 0, "No regions found")

	assert(rids.size() == regions_to_find.size(), "Invalid number of regions found")

	regions.clear()

	for rid in rids:
		regions.append(_get_region_for_rid(rid))
		regions_by_rid[rid] = regions[-1]
	
	_populate_astar_grid()

func _get_region_for_rid(rid: RID) -> NavigationRegion3D:
	return instance_from_id(NavigationServer3D.region_get_owner_id(rid))

func get_region_for_rid(rid: RID) -> NavigationRegion3D:
	return regions_by_rid.get(rid)

func _populate_astar_grid() -> void:
	point_to_id = {}  # Vector3 -> int
	id_to_point = {}  # int -> Vector3
	point_to_region = {}  # Vector3 -> RID

	# First pass: Add points from all region meshes
	for region in regions:
		var enabled = NavigationServer3D.region_get_enabled(region.get_rid())
		if not enabled:
			continue
		var nav_mesh = region.navigation_mesh
		var vertices = nav_mesh.get_vertices()

		# Process each polygon in the navigation mesh
		for i in nav_mesh.get_polygon_count():
			var polygon_indices = nav_mesh.get_polygon(i)
			var polygon_points = []
			for idx in polygon_indices:
				polygon_points.append(vertices[idx])
			
			# Generate grid points within polygon bounds
			var bounds = _get_polygon_bounds(polygon_points)
			var x_start = int(bounds.position.x / cell_size)
			var x_end = int(bounds.end.x / cell_size)
			var z_start = int(bounds.position.y / cell_size)
			var z_end = int(bounds.end.y / cell_size)
			
			for x in range(x_start, x_end + 1):
				for z in range(z_start, z_end + 1):
					var point = Vector3(x * cell_size, 1, z * cell_size)
					
					# Check if point is inside polygon
					if _is_point_in_polygon_2d(Vector2(point.x, point.z), _convert_to_2d_points(polygon_points)):
						if not point in point_to_id:  # Avoid duplicates
							# Store point mappings
							point_to_id[point] = current_point_id
							id_to_point[current_point_id] = point
							point_to_region[point] = region.get_rid()
							
							# Add point to A* grid
							add_point(current_point_id, point)
							current_point_id += 1

	# Second pass: Connect neighboring points
	for point in point_to_id:
		var point_id = point_to_id[point]

		# Check all 8 neighbors
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue

				var neighbor = point + Vector3(dx * cell_size, 0, dz * cell_size)
				if neighbor in point_to_id:
					var neighbor_id = point_to_id[neighbor]

					# Only connect if they're in the same region
					# if point_to_region[point] == point_to_region[neighbor]:
						# Use diagonal weight for diagonal connections
					var weight = 1.0 if dx == 0 or dz == 0 else 1.414
					connect_points(point_id, neighbor_id, weight)
	
	emit_signal("_on_map_updated")

func _get_polygon_bounds(points: Array) -> Rect2:
	var min_x = INF
	var min_z = INF
	var max_x = -INF
	var max_z = -INF
	
	for point in points:
		min_x = min(min_x, point.x)
		min_z = min(min_z, point.z)
		max_x = max(max_x, point.x)
		max_z = max(max_z, point.z)
	
	return Rect2(Vector2(min_x, min_z), Vector2(max_x - min_x, max_z - min_z))

func _convert_to_2d_points(points3d: Array) -> Array:
	var points2d = []
	for p in points3d:
		points2d.append(Vector2(p.x, p.z))
	return points2d

func _is_point_in_polygon_2d(point: Vector2, polygon: Array) -> bool:
	var inside = false
	var j = polygon.size() - 1
	
	# First check if point is on any edge
	for i in polygon.size():
		var edge_start = polygon[i]
		var edge_end = polygon[j]
		
		# Check if point lies on an edge using distance comparison
		var line_vec = edge_end - edge_start
		var point_vec = point - edge_start
		var line_len = line_vec.length()

		if line_len > 0:  # Avoid division by zero
			var t = point_vec.dot(line_vec) / (line_len * line_len)
			if t >= 0 and t <= 1:
				var projection = edge_start + line_vec * t
				if (projection - point).length() < 0.001:  # Small epsilon for floating point comparison
					return true
		
		# Update for next iteration
		j = i
	
	# If not on edge, check if inside using ray casting
	j = polygon.size() - 1
	for i in polygon.size():
		if ((polygon[i].y > point.y) != (polygon[j].y > point.y) and
			point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / 
			(polygon[j].y - polygon[i].y) + polygon[i].x):
			inside = !inside
		j = i
	
	return inside

func check_if_point_is_owned_by_any_region(point: Vector3) -> NavigationRegion3D:
	# Snap point to grid
	var snapped_x = round(point.x / cell_size) * cell_size
	var snapped_z = round(point.z / cell_size) * cell_size
	var snapped_point = Vector3(snapped_x, 1, snapped_z)
	
	return point_to_region.get(snapped_point)

func is_point_in_polygon(point: Vector3, polygon_points: Array) -> bool:
	var inside = true
	var plane_normal = (polygon_points[1] - polygon_points[0]).cross(polygon_points[2] - polygon_points[0])
	var previous = polygon_points[-1]  # Last point
	
	for current in polygon_points:
		var edge = current - previous
		var to_point = point - previous
		var edge_to_point_normal = edge.cross(to_point)
		# Check if point is on the correct side of the edge
		if edge_to_point_normal.dot(plane_normal) <= 0:
			inside = false
			break
		previous = current
	
	return inside

## returns a dictionary with the path and the points
## {
## 	"path": Array[Vector3],
## 	"start": Vector3,
## 	"end": Vector3,
##  "start_id": int,
##  "end_id": int
## }

func get_path_from_point_to_point(from: Vector3, to: Vector3) -> Dictionary:
	# Snap points to grid
	var snapped_from = Vector3(
		round(from.x / cell_size) * cell_size,
		1,
		round(from.z / cell_size) * cell_size
	)
	var snapped_to = Vector3(
		round(to.x / cell_size) * cell_size,
		1,
		round(to.z / cell_size) * cell_size
	)
	
	# Check if points exist in our grid
	if not (snapped_from in point_to_id and snapped_to in point_to_id):
		return {
			"path": [],
			"start": snapped_from,
			"end": snapped_to,
			"start_id": null,
			"end_id": null
		}

	var start_id = point_to_id[snapped_from]
	var end_id = point_to_id[snapped_to]
	var path = get_point_path(start_id, end_id)
	return {
		"path": path,
		"start": snapped_from,
		"end": snapped_to,
		"start_id": start_id,
		"end_id": end_id
	}
func _regions_changed(_rid: RID) -> void:
	_on_all_regions_updated()

func _estimate_cost(from_id: int, to_id: int) -> float:
	var from_point = id_to_point.get(from_id)
	if from_point == null:
		push_error("Can't estimate cost. Point with id: %d doesn't exist." % from_id)
		return 0.0
	
	var to_point = id_to_point.get(to_id)
	if to_point == null:
		push_error("Can't estimate cost. Point with id: %d doesn't exist." % to_id)
		return 0.0
	
	var cost = from_point.distance_to(to_point)
	var from_region = get_region_for_rid(point_to_region[from_point])
	var to_region = get_region_for_rid(point_to_region[to_point])
	if from_region != to_region:
		cost += to_region.get_meta("enter_cost", 1)
	return cost

func _compute_cost(from_id: int, to_id: int) -> float:
	var from_point = id_to_point.get(from_id)
	if from_point == null:
		push_error("Can't compute cost. Point with id: %d doesn't exist." % from_id)
		return 0.0
	
	var to_point = id_to_point.get(to_id)
	if to_point == null:
		push_error("Can't compute cost. Point with id: %d doesn't exist." % to_id)
		return 0.0
	
	var cost = from_point.distance_to(to_point)
	var from_region = get_region_for_rid(point_to_region[from_point])
	var to_region = get_region_for_rid(point_to_region[to_point])
	if from_region != to_region:
		cost += to_region.get_meta("enter_cost", 1)
	return cost
