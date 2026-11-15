@tool
class_name ToyBeetle
extends Beetle


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _dying:
		return
	position.x += _dir * speed * delta
	if absf(position.x - _origin_x) >= patrol_range:
		position.x = _origin_x + signf(position.x - _origin_x) * patrol_range
		_dir = -_dir
	for body in get_overlapping_bodies():
		var hog := body as ToyHog
		if hog == null or hog.ko:
			continue
		if hog.curled:
			var falling := hog.linear_velocity.y > 100.0
			die()
			if falling:
				hog.bounce_up(pogo_height)
			return
		hog.knock_out(global_position)
