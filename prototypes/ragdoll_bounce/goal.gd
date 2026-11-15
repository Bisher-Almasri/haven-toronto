class_name ToyGoal
extends Area2D

signal reached

@export var size := Vector2(600.0, 160.0)
var _done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func _physics_process(_delta: float) -> void:
	if _done:
		return
	for body in get_overlapping_bodies():
		if body is ToyHog and not body.ko:
			_done = true
			reached.emit()
