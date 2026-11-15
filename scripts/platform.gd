@tool
class_name Platform
extends StaticBody2D

enum Kind { ROOT, DIRT, GRASS, TRUNK }

const ROOT_COL := Color(0.50, 0.31, 0.16)
const ROOT_TOP := Color(0.72, 0.48, 0.24)
const ROOT_DARK := Color(0.30, 0.17, 0.08)
const DIRT_COL := Color(0.30, 0.18, 0.10)
const DIRT_TOP := Color(0.46, 0.29, 0.15)
const PEBBLE_DARK := Color(0.21, 0.12, 0.07)
const PEBBLE_LIGHT := Color(0.40, 0.26, 0.15)
const TRUNK_COL := Color(0.36, 0.21, 0.11)
const LEAVES := [
	Color(0.93, 0.45, 0.10),
	Color(0.78, 0.22, 0.10),
	Color(0.98, 0.72, 0.15),
	Color(0.62, 0.30, 0.10),
]

@export var size := Vector2(256.0, 28.0):
	set(value):
		size = value
		_refresh()
@export var kind := Kind.ROOT:
	set(value):
		kind = value
		_refresh()

var _shape := RectangleShape2D.new()
var _collision: CollisionShape2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_collision = CollisionShape2D.new()
	_collision.shape = _shape
	add_child(_collision)
	_refresh()


func _refresh() -> void:
	if _collision == null:
		return
	_shape.size = size
	_collision.position = size * 0.5
	_collision.one_way_collision = kind == Kind.ROOT
	queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(name)) + int(size.x)
	match kind:
		Kind.ROOT:
			_draw_root(rng)
		Kind.DIRT:
			_draw_dirt(rng)
		Kind.GRASS:
			_draw_dirt(rng)
			_draw_leaves(rng)
		Kind.TRUNK:
			_draw_trunk(rng)


func _draw_root(rng: RandomNumberGenerator) -> void:
	var w := size.x
	var h := size.y
	var body := PackedVector2Array([
		Vector2(0, h * 0.5), Vector2(10, 0), Vector2(w - 10, 0),
		Vector2(w, h * 0.5), Vector2(w - 14, h), Vector2(14, h),
	])
	draw_colored_polygon(body, ROOT_COL)
	draw_rect(Rect2(10, 0, w - 20, 6), ROOT_TOP)
	for i in int(w / 24.0):
		var x := rng.randf_range(16.0, w - 16.0)
		draw_line(Vector2(x, h * 0.3), Vector2(x + rng.randf_range(-6.0, 6.0), h * 0.9), ROOT_DARK, 2.0)
	for i in maxi(2, int(w / 64.0)):
		var x := rng.randf_range(16.0, w - 16.0)
		var length := rng.randf_range(18.0, 60.0)
		var pts := PackedVector2Array([
			Vector2(x, h - 2.0),
			Vector2(x + rng.randf_range(-8.0, 8.0), h + length * 0.5),
			Vector2(x + rng.randf_range(-14.0, 14.0), h + length),
		])
		draw_polyline(pts, ROOT_DARK, 4.0)


func _draw_dirt(rng: RandomNumberGenerator) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DIRT_COL)
	var x := 0.0
	while x < size.x:
		var step := minf(16.0, size.x - x)
		draw_rect(Rect2(x, 0, step, rng.randf_range(8.0, 18.0)), DIRT_TOP)
		x += step
	var count := mini(int(size.x * size.y / 5000.0), 400)
	for i in count:
		var p := Vector2(rng.randf_range(4.0, size.x - 4.0), rng.randf_range(22.0, maxf(size.y - 4.0, 23.0)))
		draw_circle(p, rng.randf_range(2.5, 7.0), PEBBLE_DARK if rng.randf() < 0.65 else PEBBLE_LIGHT)


func _draw_leaves(rng: RandomNumberGenerator) -> void:
	draw_rect(Rect2(0, 4, size.x, 14), LEAVES[3])
	var x := 0.0
	while x < size.x:
		var color: Color = LEAVES[rng.randi() % LEAVES.size()]
		draw_circle(Vector2(x + rng.randf_range(0.0, 10.0), rng.randf_range(-2.0, 9.0)), rng.randf_range(7.0, 13.0), color)
		x += 11.0


func _draw_trunk(rng: RandomNumberGenerator) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), TRUNK_COL)
	var x := 8.0
	while x < size.x:
		var y := rng.randf_range(0.0, size.y)
		var length := rng.randf_range(80.0, 360.0)
		draw_line(Vector2(x, y), Vector2(x + rng.randf_range(-4.0, 4.0), minf(y + length, size.y)), ROOT_DARK, 4.0)
		x += rng.randf_range(12.0, 22.0)
	for i in int(size.y / 220.0):
		draw_circle(Vector2(rng.randf_range(20.0, size.x - 20.0), rng.randf_range(0.0, size.y)), rng.randf_range(10.0, 18.0), ROOT_DARK)
