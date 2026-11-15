class_name ToyCamera
extends Camera2D

var target: ToyHog
var _trauma := 0.0


func _ready() -> void:
	zoom = Vector2(1.4, 1.4)
	limit_left = -600
	limit_right = 5900
	limit_top = -1500
	limit_bottom = 2400
	position_smoothing_enabled = false


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _process(delta: float) -> void:
	if target == null:
		return
	var speed := target.linear_velocity.length()
	var want_zoom := lerpf(1.4, 1.1, clampf((speed - 600.0) / 1600.0, 0.0, 1.0))
	zoom = zoom.lerp(Vector2.ONE * want_zoom, 1.0 - exp(-2.5 * delta))
	var ahead := target.linear_velocity * 0.22
	ahead = ahead.limit_length(260.0)
	var want := target.global_position + ahead + Vector2(0.0, -60.0)
	global_position = global_position.lerp(want, 1.0 - exp(-6.0 * delta))
	if _trauma > 0.0:
		_trauma = maxf(_trauma - 2.0 * delta, 0.0)
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 24.0 * _trauma * _trauma
	else:
		offset = Vector2.ZERO
