class_name CustomPoint
extends Node3D

@onready var label3d: Label3D = $Label3D
var point_material: StandardMaterial3D

func _ready() -> void:
    
    # Create and set up the material
    point_material = StandardMaterial3D.new()
    point_material.albedo_color = Color.WHITE  # Default color
    $CSGSphere3D.material_override = point_material

func update_label(region_name: String) -> void:
    label3d.text = "POINT POSITION\n" + str(global_position) + "\n" + region_name

func reset_color() -> void:
    point_material.albedo_color = Color.WHITE

func point_owned() -> void:
    point_material.albedo_color = Color.GREEN

func point_not_owned() -> void:
    point_material.albedo_color = Color.RED
    