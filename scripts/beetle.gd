@tool
class_name Beetle
extends Area2D

signal killed

const SHELL := Color(0.30, 0.12, 0.24)
const SHELL_LIGHT := Color(0.50, 0.24, 0.38)
const LEG := Color(0.16, 0.07, 0.12)
const EYE := Color(1.0, 0.82, 0.25)

@export var patrol_range := 90.0
@export var speed := 70.0
@export var pogo_height := 300.0

var _dir := 1.0
var _origin_x := 0.0
var _dying := false
var _shape := RectangleShape2D.new()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_origin_x = position.x
	_shape.size = Vector2(46.0, 30.0)
	var collision := CollisionShape2D.new()
	collision.shape = _shape
	collision.position = Vector2(0.0, -17.0)
	add_child(collision)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _dying:
		return
	position.x += _dir * speed * delta
	if absf(position.x - _origin_x) >= patrol_range:
		position.x = _origin_x + signf(position.x - _origin_x) * patrol_range
		_dir = -_dir
	for body in get_overlapping_bodies():
		var player := body as Player
		if player == null or player.dead:
			continue
		if player.spiked:
			var pogo := player.recently_fell()
			die(player)
			if pogo:
				player.bounce(pogo_height)
			return
		player.take_hit(global_position.x)


func _process(_delta: float) -> void:
	queue_redraw()


func die(player: Player = null) -> void:
	if _dying:
		return
	_dying = true
	killed.emit()
	if player:
		player.add_trauma(0.3)
	set_deferred("monitoring", false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 0.2), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_dir, 1.0))
	var t := Time.get_ticks_msec() * 0.012
	for i in 3:
		var x := -12.0 + i * 12.0
		var swing := sin(t + i * 2.1) * 4.0
		draw_line(Vector2(x, -12.0), Vector2(x + swing - 5.0, -1.0), LEG, 3.0)
		draw_line(Vector2(x, -12.0), Vector2(x - swing + 5.0, -1.0), LEG, 3.0)
	draw_set_transform(Vector2(-2.0, -18.0), 0.0, Vector2(_dir, 1.0))
	draw_colored_polygon(_ellipse(24.0, 15.0), SHELL)
	draw_colored_polygon(_ellipse(18.0, 7.0, Vector2(-2.0, -6.0)), SHELL_LIGHT)
	draw_line(Vector2(0.0, -13.0), Vector2(0.0, 13.0), LEG, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_dir, 1.0))
	draw_circle(Vector2(22.0, -17.0), 9.0, LEG)
	draw_circle(Vector2(25.0, -20.0), 2.5, EYE)
	draw_line(Vector2(28.0, -23.0), Vector2(36.0, -30.0), LEG, 2.0)
	draw_line(Vector2(29.0, -14.0), Vector2(36.0, -10.0), LEG, 3.0)


func _ellipse(rx: float, ry: float, offset := Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(offset + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
