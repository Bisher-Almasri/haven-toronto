class_name ToyBoulder
extends RigidBody2D

@export var radius := 45.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	gravity_scale = ToyHog.GRAVITY_SCALE
	mass = 3.0
	can_sleep = false
	var material := PhysicsMaterial.new()
	material.friction = 0.8
	material.bounce = 0.2
	physics_material_override = material
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.48, 0.42, 0.38))
	draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.45, Color(0.6, 0.54, 0.49))
	draw_line(Vector2(-radius * 0.6, radius * 0.1), Vector2(radius * 0.1, radius * 0.7), Color(0.3, 0.26, 0.24), 4.0)
	draw_line(Vector2(radius * 0.2, -radius * 0.7), Vector2(radius * 0.55, -radius * 0.1), Color(0.3, 0.26, 0.24), 4.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.28, 0.24, 0.22), 4.0)
