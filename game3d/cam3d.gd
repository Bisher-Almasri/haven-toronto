class_name Cam3D
extends Camera3D

## 720 px of the old game = 7.2 m of world; the old 1.4x zoom shows 5.14 m of height.
const VIEW_H := 7.2
const LIFT := 1.1

var target: Hog3D
var left_limit := -6.0
var right_limit := 59.0
var bottom_limit := -24.0
var top_limit := 15.0
var zoom := 1.4
var focus := Vector3.ZERO

var _trauma := 0.0


func _ready() -> void:
	fov = 40.0
	near = 0.1
	far = 250.0


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func snap() -> void:
	focus = target.global_position + Vector3(0.0, 0.6, 0.0)
	_apply(0.0)


func _process(delta: float) -> void:
	if target == null:
		return
	var speed := target.linear_velocity.length()
	var want_zoom := lerpf(1.4, 1.1, clampf((speed - 6.0) / 16.0, 0.0, 1.0))
	zoom = lerpf(zoom, want_zoom, 1.0 - exp(-2.5 * delta))
	var ahead := (target.linear_velocity * 0.22).limit_length(2.6)
	var want := target.global_position + ahead + Vector3(0.0, 0.6, 0.0)
	focus = focus.lerp(want, 1.0 - exp(-6.0 * delta))
	_apply(delta)


func _apply(delta: float) -> void:
	var half_h := VIEW_H / zoom * 0.5
	var dist := half_h / tan(deg_to_rad(fov) * 0.5)
	var half_w := half_h * get_viewport().get_visible_rect().size.aspect()
	var f := focus
	f.x = clampf(f.x, left_limit + half_w, maxf(right_limit - half_w, left_limit + half_w))
	f.y = clampf(f.y, bottom_limit + half_h, top_limit - half_h)
	look_at_from_position(f + Vector3(0.0, LIFT, dist), f)
	if _trauma > 0.0:
		_trauma = maxf(_trauma - 2.0 * delta, 0.0)
		var k := _trauma * _trauma
		h_offset = randf_range(-1.0, 1.0) * 0.24 * k
		v_offset = randf_range(-1.0, 1.0) * 0.24 * k
		rotate_object_local(Vector3.BACK, randf_range(-1.0, 1.0) * 0.03 * k)
	else:
		h_offset = 0.0
		v_offset = 0.0
