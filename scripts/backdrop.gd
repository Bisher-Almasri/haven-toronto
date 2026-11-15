extends Node2D

const SURFACE := Color(0.46, 0.27, 0.13)
const DEEP := Color(0.13, 0.07, 0.05)
const DEPTH := 2800.0

var _blobs: Array[Vector3] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 36:
		_blobs.append(Vector3(rng.randf_range(0.0, 1500.0), rng.randf_range(0.0, 1000.0), rng.randf_range(60.0, 220.0)))


func _process(_delta: float) -> void:
	queue_redraw()


func _depth_color(y: float) -> Color:
	return SURFACE.lerp(DEEP, clampf(y / DEPTH, 0.0, 1.0))


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	var center := camera.get_screen_center_position() if camera else Vector2.ZERO
	var top_color := _depth_color(center.y - viewport_size.y * 0.5)
	var bottom_color := _depth_color(center.y + viewport_size.y * 0.5)
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(viewport_size.x, 0.0), viewport_size, Vector2(0.0, viewport_size.y)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color])
	)
	var blob_color := bottom_color.darkened(0.35)
	blob_color.a = 0.28
	var wrap := Vector2(viewport_size.x + 400.0, viewport_size.y + 400.0)
	for blob in _blobs:
		var p := Vector2(blob.x, blob.y) - center * 0.35
		p = Vector2(fposmod(p.x, wrap.x) - 200.0, fposmod(p.y, wrap.y) - 200.0)
		draw_circle(p, blob.z, blob_color)
