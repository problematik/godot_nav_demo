class_name AStarSearch
extends Node

@onready var astar: AStarCustom = preload("res://AStarCustom.gd").new()

func _ready() -> void:
	call_deferred("_init")

func _init() -> void:
	# Ensure navigation is processed
	await ready
	await get_tree().physics_frame

	astar.init(self)
