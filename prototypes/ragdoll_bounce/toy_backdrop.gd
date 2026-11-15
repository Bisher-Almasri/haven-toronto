class_name ToyBackdrop
extends Node2D

const DEPTH := 2800.0
const PERIOD := 3400.0
const WARM := [Color(0.46, 0.27, 0.13), Color(0.13, 0.07, 0.05)]
# palette keyframes along the course: [progress, surface colour, deep colour]
const THEME_2 := [
	[0.0, Color(0.46, 0.27, 0.13), Color(0.13, 0.07, 0.05)],
	[0.3, Color(0.46, 0.27, 0.13), Color(0.13, 0.07, 0.05)],
	[0.5, Color(0.38, 0.2, 0.3), Color(0.1, 0.04, 0.12)],
	[0.68, Color(0.2, 0.3, 0.34), Color(0.04, 0.09, 0.11)],
	[0.84, Color(0.38, 0.22, 0.12), Color(0.12, 0.06, 0.04)],
	[1.0, Color(0.46, 0.27, 0.13), Color(0.13, 0.07, 0.05)],
]
# parallax factor, pillar count, width range, alpha
const LAYERS := [[0.18, 9, Vector2(180.0, 340.0), 0.5], [0.38, 11, Vector2(90.0, 200.0), 0.5], [0.62, 8, Vector2(50.0, 120.0), 0.55]]

var level := 1
var world_end := 5900.0
var _pillars: Array = []
var _spores: Array = []
var _clock := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for layer in LAYERS.size():
		var info: Array = LAYERS[layer]
		for i in int(info[1]):
			var w: Vector2 = info[2]
			_pillars.append([layer, rng.randf() * PERIOD, rng.randf_range(w.x, w.y), rng.randf_range(-60.0, 60.0), rng.randf_range(0.7, 1.0)])
	for i in 48:
		_spores.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.4, 1.0)))


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _palette(t: float) -> Array:
	if level != 2:
		return WARM
	for i in THEME_2.size() - 1:
		var a: Array = THEME_2[i]
		var b: Array = THEME_2[i + 1]
		if t <= float(b[0]):
			var k := inverse_lerp(float(a[0]), float(b[0]), t)
			return [(a[1] as Color).lerp(b[1], k), (a[2] as Color).lerp(b[2], k)]
	return WARM


func _draw() -> void:
	var vp := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	var center := camera.get_screen_center_position() if camera else Vector2.ZERO
	var zoom := camera.zoom.x if camera else 1.0
	var pal := _palette(clampf(center.x / world_end, 0.0, 1.0))
	var surface: Color = pal[0]
	var deep: Color = pal[1]
	var top_color := surface.lerp(deep, clampf((center.y - vp.y * 0.5 / zoom) / DEPTH, 0.0, 1.0))
	var bottom_color := surface.lerp(deep, clampf((center.y + vp.y * 0.5 / zoom) / DEPTH, 0.0, 1.0))
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(vp.x, 0.0), vp, Vector2(0.0, vp.y)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color]))

	# distant rock columns on three parallax planes
	for p in _pillars:
		var info: Array = LAYERS[int(p[0])]
		var factor: float = info[0]
		var wrap := PERIOD * zoom
		var x := fposmod(vp.x * 0.5 + (float(p[1]) - center.x * factor) * zoom, wrap + 600.0) - 300.0
		var half := float(p[2]) * zoom * 0.5
		var lean := float(p[3]) * zoom
		var shade := bottom_color.lerp(surface, 0.35 - 0.12 * int(p[0])).darkened(0.1 + 0.18 * int(p[0]))
		var alpha: float = float(info[3]) * float(p[4])
		var near := Color(shade.r, shade.g, shade.b, alpha * 0.25)
		var far := Color(shade.r, shade.g, shade.b, alpha)
		draw_polygon(
			PackedVector2Array([Vector2(x - half + lean, -50.0), Vector2(x + half + lean, -50.0), Vector2(x + half * 1.3, vp.y + 50.0), Vector2(x - half * 1.3, vp.y + 50.0)]),
			PackedColorArray([near, near, far, far]))

	# soft fog
	var fog := bottom_color.lightened(0.25)
	fog.a = 0.07
	for i in 5:
		var fx := fposmod(vp.x * 0.5 + (i * 700.0 - center.x * 0.8) * zoom + sin(_clock * 0.15 + i) * 60.0, vp.x + 800.0) - 400.0
		draw_circle(Vector2(fx, vp.y * (0.25 + 0.14 * i)), 260.0 * zoom, fog)

	# drifting spores
	var glow := surface.lightened(0.55)
	for s in _spores:
		var sx := fposmod(s.x * vp.x + sin(_clock * 0.4 + s.y * 9.0) * 30.0 - center.x * 0.08 * s.z, vp.x)
		var sy := fposmod(s.y * vp.y - _clock * 14.0 * s.z - center.y * 0.08 * s.z, vp.y)
		glow.a = 0.18 + 0.3 * s.z * (0.5 + 0.5 * sin(_clock * 1.7 + s.x * 20.0))
		draw_circle(Vector2(sx, sy), 1.5 + 2.2 * s.z, glow)
