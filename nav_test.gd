extends Node3D

@onready var nav_inner: NavigationRegion3D = $NavInner
@onready var nav_outer: NavigationRegion3D = $NavOuter
@onready var nav_disconnected: NavigationRegion3D = $NavDisconnected
@onready var enter_cost: SpinBox = $"UI/EnterCost"

@onready var hflow_container: HFlowContainer = $UI/HFlowContainer
const AStarNode = preload("res://AStarNode.gd")
@onready var astar_node: AStarNode = %AStarNode
@onready var visualizer: AStarVisualizer = preload("res://AStarVisualizer.gd").new()

var showing_polygons: bool = false
var showing_grid: bool = false
var selected_regions: Dictionary = {}

func _ready() -> void:
	add_child(visualizer)
	enter_cost.value = nav_inner.get_meta("enter_cost", 1.0)

	astar_node.astar.connect("_on_map_updated", func():
		print("map updated")
		# Clear existing buttons
		for child in hflow_container.get_children():
			child.queue_free()
		
		visualizer.clear_polygons()
		for region in astar_node.astar.regions:
			visualizer.draw_navigation_polygons(region, true if region.get_name() == "NavInner" else false)
			if not selected_regions.has(region):
				selected_regions[region.get_rid()] = true

		# Create new buttons for each region
		for region in astar_node.astar.regions:
			var button = Button.new()
			button.text = "Toggle " + region.name
			button.custom_minimum_size = Vector2(262, 67)
			hflow_container.add_child(button)
			button.pressed.connect(_on_region_toggled.bind(region.get_rid()))

		_on_toggle_polygons_pressed()
		_on_toggle_grid_pressed()
	)

func _on_region_toggled(rid: RID) -> void:
	visualizer.clear_polygons()
	selected_regions[rid] = not selected_regions[rid]
	for selected_region in selected_regions:
		if selected_regions[selected_region]:
			var region = astar_node.astar.get_region_for_rid(selected_region)
			visualizer.draw_navigation_polygons(region, true if region.get_name() == "NavInner" else false)

	if showing_grid:
		_on_toggle_grid_pressed(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()

func _on_disable_pressed() -> void:
	print("disabling inner")
	NavigationServer3D.region_set_enabled(nav_inner.get_rid(), false)
	print("inner disabled")

func _on_enable_pressed() -> void:
	print("enabling inner")
	NavigationServer3D.region_set_enabled(nav_inner.get_rid(), true)
	print("inner enabled")

func _on_update_enter_cost_pressed() -> void:
	print("enter cost changed", enter_cost.value)
	nav_inner.set_meta("enter_cost", enter_cost.value)
	nav_inner.enter_cost = enter_cost.value

func _on_toggle_polygons_pressed() -> void:
	if showing_polygons:
		# Get and free all nodes in the polygon_mesh group
		visualizer.clear_polygons()
		showing_polygons = false
		for region in selected_regions:
			selected_regions[region] = false
		if showing_grid:
			_on_toggle_grid_pressed(true)
	else:
		for region in selected_regions:
			selected_regions[region] = true
		for region in astar_node.astar.regions:
			visualizer.draw_navigation_polygons(region, true if region.get_name() == "NavInner" else false)
		showing_polygons = true
		if showing_grid:
			_on_toggle_grid_pressed(true)

func _on_toggle_grid_pressed(force_redraw: bool = false) -> void:
	var full_color = false
	var only_showing_disconnected = not selected_regions[nav_inner.get_rid()] and not selected_regions[nav_outer.get_rid()] and selected_regions[nav_disconnected.get_rid()]
	if not showing_polygons or only_showing_disconnected:
		full_color = true
	if force_redraw:
		visualizer.clear_grid()
		visualizer.draw_grid(full_color)
		return

	if showing_grid:
		visualizer.clear_grid()
		showing_grid = false
	else:
		visualizer.draw_grid(full_color)
		showing_grid = true
