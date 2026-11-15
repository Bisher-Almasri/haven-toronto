@tool
class_name Checkpoint
extends Area2D

signal activated

var active := false
var _burst := 0.0
var _shape := RectangleShape2D.new()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_shape.size = Vector2(60.0, 90.0)
	var collision := CollisionShape2D.new()
	collision.shape = _shape
	collision.position = Vector2(0.0, -45.0)
	add_child(collision)
	if not Engine.is_editor_hint():
		add_to_group("checkpoints")
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	player.respawn_point = global_position + Vector2(0.0, -2.0)
	if not active:
		activated.emit()
		_burst = 1.0
		create_tween().tween_property(self, "_burst", 0.0, 0.7)
	for other in get_tree().get_nodes_in_group("checkpoints"):
		other.set_active(other == self)


func set_active(value: bool) -> void:
	active = value
	queue_redraw()


func _process(_delta: float) -> void:
	if (active or _burst > 0.0) and not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	draw_line(Vector2(0, 0), Vector2(0, -56), Color(0.35, 0.2, 0.1), 5.0)
	var glow := Color(1.0, 0.78, 0.25) if active else Color(0.55, 0.42, 0.3)
	if active:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		draw_circle(Vector2(0, -66), 30.0 + 4.0 * pulse, Color(1.0, 0.8, 0.3, 0.18))
	if _burst > 0.0:
		var r := 20.0 + 90.0 * (1.0 - _burst)
		draw_arc(Vector2(0, -66), r, 0.0, TAU, 40, Color(1.0, 0.85, 0.4, _burst), 5.0 * _burst + 1.0)
	draw_circle(Vector2(0, -66), 13.0, glow)
	draw_circle(Vector2(-4, -70), 4.0, glow.lightened(0.5))
	draw_rect(Rect2(-8, -82, 16, 7), Color(0.42, 0.24, 0.12))
