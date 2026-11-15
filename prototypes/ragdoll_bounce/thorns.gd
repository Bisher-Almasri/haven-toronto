class_name ToyThorns
extends Area2D

@export var width := 300.0
@export var draw_spikes := true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 30.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -15.0)
	add_child(collision)


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		var hog := body as ToyHog
		if hog == null or hog.ko:
			continue
		if draw_spikes and hog.curled:
			continue
		hog.knock_out(global_position)


func _draw() -> void:
	if not draw_spikes:
		return
	var x := -width * 0.5
	while x < width * 0.5:
		draw_colored_polygon(PackedVector2Array([Vector2(x, 4), Vector2(x + 13, -38), Vector2(x + 26, 4)]), Color(0.55, 0.14, 0.12))
		draw_colored_polygon(PackedVector2Array([Vector2(x + 8, -22), Vector2(x + 13, -38), Vector2(x + 18, -22)]), Color(0.95, 0.5, 0.3))
		x += 26.0
	draw_rect(Rect2(-width * 0.5, 0, width, 8), Color(0.25, 0.1, 0.08))
