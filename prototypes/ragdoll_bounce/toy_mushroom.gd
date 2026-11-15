@tool
class_name ToyMushroom
extends Mushroom

signal activated

@export var checkpoint := false
@export var drift_start_y := -90.0

var active := false


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for body in get_overlapping_bodies():
		var hog := body as ToyHog
		if hog == null or hog.ko:
			continue
		var cap_top := global_position.y - _total_height()
		if checkpoint and not active:
			_activate(hog)
		if hog.linear_velocity.y < 40.0:
			continue
		if hog.global_position.y + ToyHog.RADIUS > cap_top + 52.0:
			continue
		_pop(hog)


func _activate(hog: ToyHog) -> void:
	for other in get_tree().get_nodes_in_group("toy_checkpoints"):
		other.active = false
		other.queue_redraw()
	active = true
	activated.emit()
	hog.respawn_point = global_position + Vector2(0.0, -_total_height() - ToyHog.RADIUS - 6.0)
	queue_redraw()


func _pop(hog: ToyHog) -> void:
	if master:
		hog.launch_to(landing_position, launch_apex_y, drift_start_y)
	else:
		hog.bounce_up(bounce_height)
	bounced_player.emit()
	if _spores:
		_spores.restart()
		_spores.emitting = true
	if _squash_tween:
		_squash_tween.kill()
	scale = Vector2(1.2, 0.65)
	_squash_tween = create_tween()
	_squash_tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _ready() -> void:
	super._ready()
	if checkpoint and not Engine.is_editor_hint():
		add_to_group("toy_checkpoints")


func _process(delta: float) -> void:
	super._process(delta)
	if checkpoint and active and not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	super._draw()
	if checkpoint:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006) if active else 0.0
		var color := Color(1.0, 0.85, 0.3, 0.35) if active else Color(0.3, 0.3, 0.3, 0.25)
		draw_arc(Vector2(0.0, -_total_height() * 0.5), cap_width * (0.62 + 0.05 * pulse), 0.0, TAU, 32, color, 5.0)
