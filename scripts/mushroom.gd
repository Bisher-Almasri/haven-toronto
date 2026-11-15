@tool
class_name Mushroom
extends Area2D

signal bounced_player

const CAP := Color(0.84, 0.20, 0.16)
const CAP_MASTER := Color(0.92, 0.24, 0.34)
const CAP_UNDER := Color(0.97, 0.80, 0.55)
const SPOT := Color(1.0, 0.94, 0.78)
const STEM := Color(0.96, 0.86, 0.68)
const STEM_SHADE := Color(0.82, 0.68, 0.48)

@export var cap_width := 128.0:
	set(value):
		cap_width = value
		_refresh()
@export var bounce_height := 420.0
@export var master := false:
	set(value):
		master = value
		_refresh()
@export_group("Master launch")
@export var launch_apex_y := -420.0
@export var landing_position := Vector2(2260.0, 0.0)

var _shape := RectangleShape2D.new()
var _collision: CollisionShape2D
var _spores: CPUParticles2D
var _squash_tween: Tween


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_collision = CollisionShape2D.new()
	_collision.shape = _shape
	add_child(_collision)
	if not Engine.is_editor_hint():
		_spores = CPUParticles2D.new()
		_spores.emitting = false
		_spores.one_shot = true
		_spores.explosiveness = 1.0
		_spores.amount = 18
		_spores.lifetime = 0.9
		_spores.direction = Vector2(0, -1)
		_spores.spread = 70.0
		_spores.initial_velocity_min = 120.0
		_spores.initial_velocity_max = 320.0
		_spores.gravity = Vector2(0, 420)
		_spores.scale_amount_min = 3.0
		_spores.scale_amount_max = 7.0
		_spores.color = Color(1.0, 0.88, 0.55)
		_spores.position = Vector2(0, -_total_height())
		add_child(_spores)
	_refresh()


func _total_height() -> float:
	return cap_width * 0.5 + cap_width * 0.32


func _refresh() -> void:
	if _collision == null:
		return
	_shape.size = Vector2(cap_width * 0.9, 44.0)
	_collision.position = Vector2(0.0, -_total_height() + 18.0)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for body in get_overlapping_bodies():
		var player := body as Player
		if player == null or player.dead or player.launching:
			continue
		if player.is_on_floor() or player.velocity.y <= 0.0:
			continue
		if player.global_position.y > global_position.y - _total_height() + 44.0:
			continue
		_bounce(player)


func _bounce(player: Player) -> void:
	if master:
		player.launch(launch_apex_y, landing_position)
	else:
		player.bounce(bounce_height)
	bounced_player.emit()
	if _spores:
		_spores.restart()
		_spores.emitting = true
	if _squash_tween:
		_squash_tween.kill()
	scale = Vector2(1.2, 0.65)
	_squash_tween = create_tween()
	_squash_tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	if master and not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var cap_h := cap_width * 0.5
	var stem_h := cap_width * 0.32
	var stem_w := cap_width * 0.32
	var cap_color := CAP_MASTER if master else CAP

	if master:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		var center := Vector2(0.0, -_total_height() * 0.55)
		draw_circle(center, cap_width * (0.75 + 0.08 * pulse), Color(1.0, 0.85, 0.3, 0.10))
		draw_circle(center, cap_width * (0.58 + 0.05 * pulse), Color(1.0, 0.85, 0.3, 0.14))

	var stem := PackedVector2Array([
		Vector2(-stem_w * 0.5, -stem_h - 4.0), Vector2(stem_w * 0.5, -stem_h - 4.0),
		Vector2(stem_w * 0.62, 0.0), Vector2(-stem_w * 0.62, 0.0),
	])
	draw_colored_polygon(stem, STEM)
	draw_rect(Rect2(stem_w * 0.12, -stem_h, stem_w * 0.3, stem_h), STEM_SHADE)

	var under := PackedVector2Array()
	var cap := PackedVector2Array()
	var steps := 28
	for i in steps + 1:
		var a := PI * float(i) / float(steps)
		cap.append(Vector2(cos(a) * cap_width * 0.5, -stem_h - sin(a) * cap_h))
		under.append(Vector2(cos(a) * cap_width * 0.5, -stem_h + sin(a) * cap_h * 0.18))
	draw_colored_polygon(cap, cap_color)
	draw_colored_polygon(under, CAP_UNDER)
	draw_polyline(cap, cap_color.darkened(0.35), 3.0)

	var spots := [
		Vector2(-0.28, 0.62), Vector2(0.08, 0.78), Vector2(0.32, 0.48),
		Vector2(-0.08, 0.38), Vector2(0.18, 0.2),
	]
	var sizes := [0.1, 0.12, 0.085, 0.07, 0.06]
	for i in spots.size():
		var s: Vector2 = spots[i]
		draw_circle(Vector2(s.x * cap_width, -stem_h - s.y * cap_h), float(sizes[i]) * cap_width, SPOT)
