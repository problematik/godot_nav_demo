extends Node3D

@onready var nav_inner: NavigationRegion3D = $NavInner
@onready var nav_outer: NavigationRegion3D = $NavOuter
@onready var timer: Timer = $Timer
@onready var enter_cost: TextEdit = $EnterCost

func _ready() -> void:
    enter_cost.text = str(nav_inner.enter_cost)

func _on_disable_pressed() -> void:
    print("disabling inner")
    NavigationServer3D.region_set_enabled(nav_inner.get_rid(), false)

func _on_enable_pressed() -> void:
    print("enabling inner")
    NavigationServer3D.region_set_enabled(nav_inner.get_rid(), true)

func _on_update_enter_cost_pressed() -> void:
    nav_inner.enter_cost = int(enter_cost.text)
    print("updated enter cost to ", nav_inner.enter_cost)