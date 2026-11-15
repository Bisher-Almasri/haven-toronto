extends Node2D

const ROOT_COLOR := Color(0.40, 0.24, 0.12, 0.9)
const ROOT_COLOR_DARK := Color(0.28, 0.16, 0.08, 0.9)
const CEILING_Y := 128.0
const FLOOR_Y := 2800.0
const CAVE_WIDTH := 2560.0
const HOLES := [Vector2(480.0, 800.0), Vector2(1700.0, 2100.0)]


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026

	for hole: Vector2 in HOLES:
		var beam_bottom := 2700.0 if hole.x < 1000.0 else 1500.0
		var spread := 140.0
		draw_polygon(
			PackedVector2Array([
				Vector2(hole.x, CEILING_Y), Vector2(hole.y, CEILING_Y),
				Vector2(hole.y + spread, beam_bottom), Vector2(hole.x - spread, beam_bottom),
			]),
			PackedColorArray([Color(1.0, 0.8, 0.4, 0.26), Color(1.0, 0.8, 0.4, 0.26), Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.8, 0.4, 0.0)])
		)

	for i in 340:
		var p := Vector2(rng.randf_range(20.0, CAVE_WIDTH - 20.0), rng.randf_range(CEILING_Y + 80.0, FLOOR_Y - 20.0))
		draw_circle(p, rng.randf_range(4.0, 14.0), Color(0.2, 0.11, 0.06, 0.35))

	var x := 30.0
	while x < CAVE_WIDTH:
		if not _in_hole(x) and rng.randf() < 0.8:
			var color := ROOT_COLOR if rng.randf() < 0.6 else ROOT_COLOR_DARK
			_root(Vector2(x, CEILING_Y - 6.0), Vector2(rng.randf_range(-0.25, 0.25), 1.0), rng.randf_range(70.0, 340.0), rng.randf_range(6.0, 13.0), rng, color)
		x += rng.randf_range(50.0, 95.0)

	for i in 40:
		var y := rng.randf_range(260.0, FLOOR_Y - 120.0)
		_root(Vector2(-4.0, y), Vector2(1.0, rng.randf_range(-0.3, 0.3)), rng.randf_range(70.0, 240.0), rng.randf_range(5.0, 10.0), rng, ROOT_COLOR_DARK)
		_root(Vector2(CAVE_WIDTH + 4.0, y + 60.0), Vector2(-1.0, rng.randf_range(-0.3, 0.3)), rng.randf_range(70.0, 240.0), rng.randf_range(5.0, 10.0), rng, ROOT_COLOR_DARK)

	for i in 18:
		_root(Vector2(rng.randf_range(40.0, CAVE_WIDTH - 40.0), FLOOR_Y + 6.0), Vector2(rng.randf_range(-0.4, 0.4), -1.0), rng.randf_range(40.0, 130.0), rng.randf_range(5.0, 8.0), rng, ROOT_COLOR_DARK)


func _in_hole(x: float) -> bool:
	for hole: Vector2 in HOLES:
		if x > hole.x - 20.0 and x < hole.y + 20.0:
			return true
	return false


func _root(origin: Vector2, dir: Vector2, length: float, width: float, rng: RandomNumberGenerator, color: Color, depth := 0) -> void:
	var segment := 18.0
	var count := int(length / segment)
	var points := PackedVector2Array([origin])
	var p := origin
	var d := dir.normalized()
	for i in count:
		d = d.rotated(rng.randf_range(-0.3, 0.3)).normalized()
		p += d * segment
		points.append(p)
		if depth < 2 and i > 2 and rng.randf() < 0.12:
			_root(p, d.rotated(rng.randf_range(-1.0, 1.0)), length * 0.5, width * 0.6, rng, color, depth + 1)
	for i in points.size() - 1:
		var w := width * (1.0 - float(i) / float(points.size())) + 1.5
		draw_line(points[i], points[i + 1], color, w)
