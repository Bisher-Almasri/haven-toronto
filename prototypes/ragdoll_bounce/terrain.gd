class_name ToyTerrain
extends StaticBody2D

const DIRT := Color(0.34, 0.20, 0.11)
const OUTLINE := Color(0.14, 0.07, 0.04)
const DIRT_TOP := Color(0.46, 0.29, 0.15)
const PEBBLE := Color(0.21, 0.12, 0.07)
const LEAVES := [
	Color(0.93, 0.45, 0.10),
	Color(0.78, 0.22, 0.10),
	Color(0.98, 0.72, 0.15),
	Color(0.62, 0.30, 0.10),
]

@export var points := PackedVector2Array()
@export var grass := true
@export var fill := Color(0.34, 0.20, 0.11)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	add_child(shape)
	queue_redraw()


func _draw() -> void:
	if points.size() < 3:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(name)) + points.size()
	draw_colored_polygon(points, fill)
	draw_polyline(points + PackedVector2Array([points[0]]), OUTLINE, 8.0)
	var rect := Rect2(points[0], Vector2.ZERO)
	for p in points:
		rect = rect.expand(p)
	var count := mini(int(rect.get_area() / 9000.0), 160)
	for i in count:
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		if Geometry2D.is_point_in_polygon(p, points):
			draw_circle(p, rng.randf_range(3.0, 8.0), PEBBLE)
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var dx := b.x - a.x
		if dx > 1.0 and absf(b.y - a.y) < dx * 1.6:
			draw_line(a, b, DIRT_TOP, 16.0)
			if grass:
				var length := a.distance_to(b)
				var step := 12.0
				var s := 0.0
				while s < length:
					var p := a.lerp(b, s / length)
					var color: Color = LEAVES[rng.randi() % LEAVES.size()]
					draw_circle(p + Vector2(rng.randf_range(-3, 3), rng.randf_range(-4, 6)), rng.randf_range(7.0, 12.0), color)
					s += step
