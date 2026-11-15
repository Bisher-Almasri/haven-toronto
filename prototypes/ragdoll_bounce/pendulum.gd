class_name ToyPendulum
extends Node2D

@export var length := 400.0
@export var start_angle := 0.9
@export var ball_radius := 44.0


class Swinger extends RigidBody2D:
	var length := 400.0
	var ball_radius := 44.0

	func _draw() -> void:
		draw_line(Vector2.ZERO, Vector2(0.0, length), Color(0.30, 0.17, 0.08), 26.0)
		draw_line(Vector2.ZERO, Vector2(0.0, length), Color(0.52, 0.33, 0.16), 20.0)
		var y := 10.0
		while y < length:
			draw_line(Vector2(-10.0, y), Vector2(10.0, y + 12.0), Color(0.34, 0.2, 0.09), 3.0)
			y += 16.0
		var c := Vector2(0.0, length)
		for i in 18:
			var a := TAU * float(i) / 18.0
			draw_line(c + Vector2(cos(a), sin(a)) * ball_radius * 0.7, c + Vector2(cos(a), sin(a)) * (ball_radius + 16.0), Color(0.45, 0.2, 0.08), 6.0)
		draw_circle(c, ball_radius, Color(0.55, 0.3, 0.12))
		draw_circle(c + Vector2(-12.0, -12.0), ball_radius * 0.4, Color(0.75, 0.5, 0.25))


func _draw() -> void:
	draw_circle(Vector2.ZERO, 16.0, Color(0.25, 0.14, 0.07))


func _ready() -> void:
	var pivot := StaticBody2D.new()
	pivot.collision_layer = 0
	pivot.collision_mask = 0
	add_child(pivot)

	var swinger := Swinger.new()
	swinger.length = length
	swinger.ball_radius = ball_radius
	swinger.collision_layer = 4
	swinger.collision_mask = 1 | 2 | 4
	swinger.mass = 6.0
	swinger.gravity_scale = ToyHog.GRAVITY_SCALE
	swinger.can_sleep = false
	swinger.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	swinger.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	swinger.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	swinger.linear_damp = 0.0
	swinger.angular_damp = 0.0
	swinger.rotation = start_angle
	var rod_shape := RectangleShape2D.new()
	rod_shape.size = Vector2(26.0, length)
	var rod := CollisionShape2D.new()
	rod.shape = rod_shape
	rod.position = Vector2(0.0, length * 0.5)
	swinger.add_child(rod)
	var ball_shape := CircleShape2D.new()
	ball_shape.radius = ball_radius
	var ball := CollisionShape2D.new()
	ball.shape = ball_shape
	ball.position = Vector2(0.0, length)
	swinger.add_child(ball)
	add_child(swinger)

	var joint := PinJoint2D.new()
	add_child(joint)
	joint.node_a = joint.get_path_to(pivot)
	joint.node_b = joint.get_path_to(swinger)
