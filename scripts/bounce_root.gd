@tool
class_name BounceRoot
extends StaticBody2D

enum Side { LEFT, RIGHT }

const BASE := Color(0.36, 0.19, 0.09)
const STRAND := [Color(0.93, 0.62, 0.22), Color(0.80, 0.44, 0.16), Color(0.97, 0.76, 0.32)]
const CHEVRON := Color(1.0, 0.93, 0.7, 0.75)

## Which side the open air is on. The hedgehog is flung toward it.
@export var kick_side := Side.LEFT:
	set(value):
		kick_side = value
		queue_redraw()
@export var size := Vector2(28.0, 400.0):
	set(value):
		size = value
		_refresh()
@export var push_speed := 680.0
@export var rebound_height := 300.0

var _shape := RectangleShape2D.new()
var _trigger_shape := RectangleShape2D.new()
var _collision: CollisionShape2D
var _trigger: Area2D
var _trigger_collision: CollisionShape2D
var _wobble := 0.0
var _wobble_tween: Tween


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_collision = CollisionShape2D.new()
	_collision.shape = _shape
	add_child(_collision)
	_trigger = Area2D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2
	_trigger_collision = CollisionShape2D.new()
	_trigger_collision.shape = _trigger_shape
	_trigger.add_child(_trigger_collision)
	add_child(_trigger)
	_refresh()


func _refresh() -> void:
	if _collision == null:
		return
	_shape.size = size
	_collision.position = size * 0.5
	_trigger_shape.size = size + Vector2(20.0, 0.0)
	_trigger_collision.position = size * 0.5
	queue_redraw()


func _dir() -> float:
	return -1.0 if kick_side == Side.LEFT else 1.0


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for body in _trigger.get_overlapping_bodies():
		var player := body as Player
		if player == null or player.dead or player.launching:
			continue
		if player.velocity.x * _dir() > 150.0:
			continue
		var up := -sqrt(2.0 * player.rise_gravity * rebound_height)
		player.rebound(Vector2(_dir() * push_speed, up))
		_twang()


func _twang() -> void:
	if _wobble_tween:
		_wobble_tween.kill()
	_wobble = 1.0
	_wobble_tween = create_tween()
	_wobble_tween.tween_property(self, "_wobble", 0.0, 0.7)


func _process(_delta: float) -> void:
	if _wobble > 0.0:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var dir := _dir()
	var t := Time.get_ticks_msec() * 0.001
	draw_rect(Rect2(0, 0, w, h), BASE)
	for s in 3:
		var pts := PackedVector2Array()
		var x0 := w * (0.2 + 0.3 * s)
		var y := 0.0
		while y <= h + 12.0:
			var sway := sin(y * 0.045 + s * 2.1) * 3.5 + sin(y * 0.22 - t * 40.0) * 9.0 * _wobble * dir * -1.0
			pts.append(Vector2(x0 + sway, minf(y, h)))
			y += 12.0
		draw_polyline(pts, STRAND[s], 7.0)
	var rim_x := 0.0 if dir < 0.0 else w
	draw_line(Vector2(rim_x, 0), Vector2(rim_x, h), Color(1.0, 0.82, 0.35, 0.9), 4.0)
	var cy := 40.0
	while cy < h - 20.0:
		var tip := w * 0.2 if dir < 0.0 else w * 0.8
		var back := w * 0.8 if dir < 0.0 else w * 0.2
		draw_polyline(PackedVector2Array([Vector2(back, cy - 11), Vector2(tip, cy), Vector2(back, cy + 11)]), CHEVRON, 3.0)
		cy += 72.0
