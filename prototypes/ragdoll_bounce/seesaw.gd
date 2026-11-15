class_name ToySeesaw
extends Node2D

@export var length := 380.0
@export var max_tilt_deg := 20.0
@export var support_depth := 650.0


class Plank extends RigidBody2D:
	var size := Vector2(380.0, 22.0)

	func _draw() -> void:
		draw_rect(Rect2(-size * 0.5, size), Color(0.55, 0.33, 0.16))
		draw_rect(Rect2(-size.x * 0.5, -size.y * 0.5, size.x, 5.0), Color(0.78, 0.52, 0.26))
		for i in 6:
			draw_circle(Vector2(-size.x * 0.5 + 24.0 + i * (size.x - 48.0) / 5.0, 2.0), 2.5, Color(0.25, 0.14, 0.07))


func _draw() -> void:
	draw_rect(Rect2(-9.0, 8.0, 18.0, support_depth), Color(0.38, 0.22, 0.11))
	draw_circle(Vector2.ZERO, 14.0, Color(0.25, 0.14, 0.07))


func _ready() -> void:
	var pivot := StaticBody2D.new()
	pivot.collision_layer = 0
	pivot.collision_mask = 0
	add_child(pivot)

	var plank := Plank.new()
	plank.size = Vector2(length, 22.0)
	plank.collision_layer = 4
	plank.collision_mask = 1 | 2 | 4
	plank.mass = 4.0
	plank.gravity_scale = ToyHog.GRAVITY_SCALE
	plank.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	plank.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	plank.linear_damp = 0.1
	plank.angular_damp = 2.5
	plank.can_sleep = false
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	plank.physics_material_override = material
	var shape := RectangleShape2D.new()
	shape.size = plank.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	plank.add_child(collision)
	add_child(plank)

	var joint := PinJoint2D.new()
	add_child(joint)
	joint.node_a = joint.get_path_to(pivot)
	joint.node_b = joint.get_path_to(plank)

	var half := length * 0.5 - 20.0
	var stop_top := sin(deg_to_rad(max_tilt_deg)) * half + 12.0
	for side in [-1.0, 1.0]:
		var stopper := StaticBody2D.new()
		stopper.collision_layer = 1
		stopper.collision_mask = 0
		var stopper_shape := RectangleShape2D.new()
		stopper_shape.size = Vector2(40.0, 200.0)
		var stopper_collision := CollisionShape2D.new()
		stopper_collision.shape = stopper_shape
		stopper.add_child(stopper_collision)
		stopper.position = Vector2(side * half, stop_top + 100.0)
		add_child(stopper)
