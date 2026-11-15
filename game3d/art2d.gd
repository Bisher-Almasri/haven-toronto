class_name Art2D

## Puts the original 2D art into the 3D world: 2D drawing code is rendered in a hidden SubViewport
## and the result is shown on flat Sprite3D quads. 1 art pixel = 1 cm, like the old pixel units.

const K := 2.0

## Flip to false to go back to the mushroom drawn by the 2D code.
const PAINTED_MUSHROOM := true

## Props (mushrooms, beetles, boulders, ...) are lit by the scene lights; the hedgehog stays unlit so it always reads.
const LIT_PROPS := false
const PAINTED_MUSHROOM_TEX := preload("res://mushrooms.png")
const PX := 0.01

static var host: Node
static var _cache := {}


class Painter extends Node2D:
	var draw_fn: Callable

	func _draw() -> void:
		draw_fn.call(self)


static func reset(parent: Node) -> void:
	_cache.clear()
	host = Node.new()
	host.name = "Art2D"
	parent.add_child(host)


## rect is the art area in old pixel units, relative to the drawing's origin (y down).
static func texture(key: String, rect: Rect2, make: Callable, animated := false) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(rect.size * K)
	viewport.size_2d_override = Vector2i(rect.size)
	viewport.size_2d_override_stretch = true
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if animated else SubViewport.UPDATE_ONCE
	var node: Node2D = make.call()
	node.position = -rect.position
	viewport.add_child(node)
	host.add_child(viewport)
	_cache[key] = viewport.get_texture()
	return _cache[key]


## A Sprite3D whose origin is the drawing's origin. size_scale 1.0 = original pixel size.
static func sprite(tex: Texture2D, rect: Rect2, size_scale := 1.0, lit := false) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = PX / K
	s.shaded = lit and LIT_PROPS
	s.double_sided = true
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.scale = Vector3.ONE * size_scale
	var w := rect.size.x * K
	var h := rect.size.y * K
	var px := -rect.position.x * K
	var py := -rect.position.y * K
	s.offset = Vector2(w * 0.5 - px, -(h * 0.5 - py))
	return s


# ---- the real 2D classes, drawn into a viewport -------------------------------------------

const MUSHROOM_W := 200.0
const MUSHROOM_RECT := Rect2(-112.0, -180.0, 224.0, 192.0)
const MASTER_W := 210.0
const MASTER_RECT := Rect2(-200.0, -290.0, 400.0, 380.0)
const BEETLE_RECT := Rect2(-46.0, -48.0, 96.0, 56.0)
const THORN_RECT := Rect2(0.0, -38.0, 26.0, 46.0)
const BOULDER_RECT := Rect2(-52.0, -52.0, 104.0, 104.0)
const DOT_RECT := Rect2(-18.0, -18.0, 36.0, 36.0)


static func mushroom(master: bool) -> Texture2D:
	return texture("mushroom_master" if master else "mushroom", MASTER_RECT if master else MUSHROOM_RECT, _make_mushroom.bind(master), master)


static func _make_mushroom(master: bool) -> Node2D:
	var m := Mushroom.new()
	m.cap_width = MASTER_W if master else MUSHROOM_W
	m.master = master
	return m


static func beetle() -> Texture2D:
	return texture("beetle", BEETLE_RECT, _make_beetle, true)


static func _make_beetle() -> Node2D:
	var b := Beetle.new()
	b.speed = 0.0
	return b


static func _paint(fn: Callable) -> Node2D:
	var p := Painter.new()
	p.draw_fn = fn
	return p


# ---- small painters ported from the 2D gadgets ---------------------------------------------

static func thorn() -> Texture2D:
	return texture("thorn", THORN_RECT, _paint.bind(_draw_thorn))


static func _draw_thorn(c: Node2D) -> void:
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, 4), Vector2(13, -38), Vector2(26, 4)]), Color(0.55, 0.14, 0.12))
	c.draw_colored_polygon(PackedVector2Array([Vector2(8, -22), Vector2(13, -38), Vector2(18, -22)]), Color(0.95, 0.5, 0.3))
	c.draw_rect(Rect2(0, 0, 26, 8), Color(0.25, 0.1, 0.08))


const BRAMBLE_VINE := Color(0.34, 0.18, 0.12)
const BRAMBLE_VINE_LIGHT := Color(0.56, 0.34, 0.2)
const BRAMBLE_OUTLINE := Color(0.13, 0.06, 0.05)
const BRAMBLE_LEAVES := [Color(0.85, 0.36, 0.1), Color(0.7, 0.17, 0.1), Color(0.93, 0.6, 0.15)]


static func bramble_rect(w: float, h: float) -> Rect2:
	return Rect2(-w * 0.5 - 26.0, -h - 24.0, w + 52.0, h + 36.0)


## One of three layers (0 back, 1 middle, 2 front) of a tangled thorn bush, w and h in pixel units.
static func bramble(w: float, h: float, layer: int) -> Texture2D:
	return texture("bramble%s_%s_%d" % [w, h, layer], bramble_rect(w, h), _paint.bind(_draw_bramble.bind(w, h, layer)))


static func _draw_bramble(c: Node2D, w: float, h: float, layer: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 977 * layer + 13
	var half := w * 0.5
	if layer == 0:
		var core := PackedVector2Array()
		var y := 6.0
		while y > -h * 0.94:
			core.append(Vector2(-half * 0.78 + sin(y * 0.05) * 7.0 + rng.randf_range(-6.0, 6.0), y))
			y -= 18.0
		y = -h * 0.94
		while y < 6.0:
			core.append(Vector2(half * 0.78 + sin(y * 0.06) * 7.0 + rng.randf_range(-6.0, 6.0), y))
			y += 18.0
		c.draw_colored_polygon(core, Color(0.15, 0.07, 0.07))
	var vines: int = [24, 17, 12][layer]
	for i in vines:
		var x0 := rng.randf_range(-half, half)
		var x1 := clampf(x0 + rng.randf_range(-half * 0.9, half * 0.9), -half - 12.0, half + 12.0)
		var top := -h * (rng.randf_range(0.8, 1.0) if layer == 0 else rng.randf_range(0.5, 1.0))
		var amp := rng.randf_range(12.0, 32.0)
		var freq := rng.randf_range(1.5, 3.5)
		var phase := rng.randf_range(0.0, TAU)
		var thick := rng.randf_range(4.5, 8.0)
		var steps := int(absf(top) / 9.0) + 2
		var pts := PackedVector2Array()
		for s in steps + 1:
			var t := float(s) / float(steps)
			var px := lerpf(x0, x1, t) + sin(t * freq * TAU + phase) * amp
			pts.append(Vector2(clampf(px, -half - 14.0, half + 14.0), lerpf(4.0, top, t)))
		c.draw_polyline(pts, BRAMBLE_OUTLINE, thick + 3.0, true)
		c.draw_polyline(pts, BRAMBLE_VINE, thick, true)
		var lit := PackedVector2Array()
		for p in pts:
			lit.append(p + Vector2(-thick * 0.18, -thick * 0.1))
		c.draw_polyline(lit, BRAMBLE_VINE_LIGHT, thick * 0.35, true)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var gap := 0.0
		for s in range(1, pts.size()):
			var tangent := (pts[s] - pts[s - 1]).normalized()
			gap -= pts[s].distance_to(pts[s - 1])
			if gap > 0.0:
				continue
			gap = rng.randf_range(20.0, 30.0)
			var dir := (tangent.rotated(side * PI * 0.5) + tangent * 0.7).normalized()
			_bramble_thorn(c, pts[s], dir, rng.randf_range(11.0, 19.0), rng.randf_range(3.5, 5.0))
			side = -side
			if rng.randf() < 0.18:
				_bramble_leaf(c, pts[s], dir.rotated(rng.randf_range(-0.5, 0.5)), rng.randf_range(10.0, 15.0), BRAMBLE_LEAVES[rng.randi() % BRAMBLE_LEAVES.size()])
		var last := pts.size() - 1
		_bramble_thorn(c, pts[last], (pts[last] - pts[last - 1]).normalized(), rng.randf_range(12.0, 18.0), 4.5)


static func _bramble_thorn(c: Node2D, base: Vector2, dir: Vector2, length: float, width: float) -> void:
	var side := dir.rotated(PI * 0.5)
	var tip := base + dir * length
	c.draw_colored_polygon(PackedVector2Array([base - side * (width + 1.5), tip + dir * 1.8, base + side * (width + 1.5)]), BRAMBLE_OUTLINE)
	c.draw_colored_polygon(PackedVector2Array([base - side * width, tip, base + side * width]), Color(0.6, 0.15, 0.12))
	var mid := base + dir * length * 0.55
	c.draw_colored_polygon(PackedVector2Array([mid - side * width * 0.45, tip, mid + side * width * 0.45]), Color(0.95, 0.5, 0.3))


static func _bramble_leaf(c: Node2D, base: Vector2, dir: Vector2, length: float, color: Color) -> void:
	var side := dir.rotated(PI * 0.5)
	var pts := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		pts.append(base + dir * length * t + side * sin(t * PI) * length * 0.32)
	for i in range(8, -1, -1):
		var t := float(i) / 8.0
		pts.append(base + dir * length * t - side * sin(t * PI) * length * 0.32)
	c.draw_colored_polygon(pts, color)
	c.draw_line(base, base + dir * length * 0.9, color.darkened(0.45), 1.3)


static func boulder(radius: float) -> Texture2D:
	return texture("boulder%s" % radius, BOULDER_RECT, _paint.bind(_draw_boulder.bind(radius * 100.0)))


static func _draw_boulder(c: Node2D, radius: float) -> void:
	c.draw_circle(Vector2.ZERO, radius, Color(0.48, 0.42, 0.38))
	c.draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.45, Color(0.6, 0.54, 0.49))
	c.draw_line(Vector2(-radius * 0.6, radius * 0.1), Vector2(radius * 0.1, radius * 0.7), Color(0.3, 0.26, 0.24), 4.0)
	c.draw_line(Vector2(radius * 0.2, -radius * 0.7), Vector2(radius * 0.55, -radius * 0.1), Color(0.3, 0.26, 0.24), 4.0)
	c.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.28, 0.24, 0.22), 4.0)


static func dot() -> Texture2D:
	return texture("dot", DOT_RECT, _paint.bind(_draw_dot))


static func _draw_dot(c: Node2D) -> void:
	c.draw_circle(Vector2.ZERO, 16.0, Color(0.25, 0.14, 0.07))


static func plank_rect(length: float) -> Rect2:
	return Rect2(-length * 50.0 - 4.0, -15.0, length * 100.0 + 8.0, 30.0)


static func plank(length: float) -> Texture2D:
	return texture("plank%s" % length, plank_rect(length), _paint.bind(_draw_plank.bind(Vector2(length * 100.0, 22.0))))


static func _draw_plank(c: Node2D, size: Vector2) -> void:
	c.draw_rect(Rect2(-size * 0.5, size), Color(0.55, 0.33, 0.16))
	c.draw_rect(Rect2(-size.x * 0.5, -size.y * 0.5, size.x, 5.0), Color(0.78, 0.52, 0.26))
	for i in 6:
		c.draw_circle(Vector2(-size.x * 0.5 + 24.0 + i * (size.x - 48.0) / 5.0, 2.0), 2.5, Color(0.25, 0.14, 0.07))


static func support_rect(depth: float) -> Rect2:
	return Rect2(-16.0, -16.0, 32.0, depth * 100.0 + 24.0)


static func support(depth: float) -> Texture2D:
	return texture("support%s" % depth, support_rect(depth), _paint.bind(_draw_support.bind(depth * 100.0)))


static func _draw_support(c: Node2D, depth: float) -> void:
	c.draw_rect(Rect2(-9.0, 8.0, 18.0, depth), Color(0.38, 0.22, 0.11))
	c.draw_circle(Vector2.ZERO, 14.0, Color(0.25, 0.14, 0.07))


static func swinger_rect(length: float, radius: float) -> Rect2:
	return Rect2(-radius * 100.0 - 24.0, -16.0, radius * 200.0 + 48.0, length * 100.0 + radius * 100.0 + 40.0)


static func swinger(length: float, radius: float) -> Texture2D:
	return texture("swinger%s_%s" % [length, radius], swinger_rect(length, radius), _paint.bind(_draw_swinger.bind(length * 100.0, radius * 100.0)))


static func _draw_swinger(c: Node2D, l: float, r: float) -> void:
	c.draw_line(Vector2.ZERO, Vector2(0.0, l), Color(0.30, 0.17, 0.08), 26.0)
	c.draw_line(Vector2.ZERO, Vector2(0.0, l), Color(0.52, 0.33, 0.16), 20.0)
	var y := 10.0
	while y < l:
		c.draw_line(Vector2(-10.0, y), Vector2(10.0, y + 12.0), Color(0.34, 0.2, 0.09), 3.0)
		y += 16.0
	var center := Vector2(0.0, l)
	for i in 18:
		var a := TAU * float(i) / 18.0
		c.draw_line(center + Vector2(cos(a), sin(a)) * r * 0.7, center + Vector2(cos(a), sin(a)) * (r + 16.0), Color(0.45, 0.2, 0.08), 6.0)
	c.draw_circle(center, r, Color(0.55, 0.3, 0.12))
	c.draw_circle(center + Vector2(-12.0, -12.0), r * 0.4, Color(0.75, 0.5, 0.25))


# ---- background trees ------------------------------------------------------------------------

const TREE_RECT := Rect2(-250.0, -700.0, 500.0, 720.0)
const TREE_VARIANTS := 4
const LEAF_COLORS := [
	Color(0.93, 0.45, 0.10), Color(0.80, 0.24, 0.10), Color(0.98, 0.72, 0.15),
	Color(0.72, 0.34, 0.10), Color(0.62, 0.17, 0.09), Color(0.90, 0.58, 0.14),
]


static func tree(variant: int) -> Texture2D:
	return texture("tree%d" % variant, TREE_RECT, _paint.bind(_draw_tree.bind(variant)))


static func _wobble(center: Vector2, r: float, rng: RandomNumberGenerator, amp := 0.1) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 20
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a), sin(a)) * r * (1.0 + rng.randf_range(-amp, amp)))
	return pts


static func _draw_tree(c: Node2D, variant: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 311 + variant * 53
	var ink := Color(0.21, 0.10, 0.05)
	var bark := Color(0.43, 0.25, 0.13)
	var bark_dark := Color(0.30, 0.17, 0.09)
	var bark_light := Color(0.58, 0.36, 0.19)
	var height := rng.randf_range(330.0, 410.0)
	var w0 := rng.randf_range(56.0, 74.0)
	var w1 := w0 * rng.randf_range(0.5, 0.62)
	var lean := rng.randf_range(-22.0, 22.0)

	# trunk: wobbly tapered column with a root flare
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var mid := PackedVector2Array()
	for i in 11:
		var t := float(i) / 10.0
		var sway := sin(t * 2.6 + float(variant)) * 16.0 * t + lean * t * t
		var w := lerpf(w0, w1, t) + rng.randf_range(-2.0, 2.0)
		left.append(Vector2(sway - w * 0.5, -height * t))
		right.append(Vector2(sway + w * 0.5, -height * t))
		mid.append(Vector2(sway + w * 0.12, -height * t))
	var trunk := PackedVector2Array([Vector2(-w0 * 0.98, 6.0)])
	trunk.append_array(left)
	var right_rev := right.duplicate()
	right_rev.reverse()
	trunk.append_array(right_rev)
	trunk.append(Vector2(w0 * 0.98, 6.0))
	c.draw_colored_polygon(trunk, bark)
	var shade := PackedVector2Array(mid)
	shade.append_array(right_rev)
	shade.append(Vector2(w0 * 0.98, 6.0))
	shade.append(Vector2(w0 * 0.1, 6.0))
	c.draw_colored_polygon(shade, bark_dark)
	for i in 16:
		var t := rng.randf_range(0.04, 0.95)
		var idx := int(t * 10.0)
		var x := lerpf(left[idx].x, right[idx].x, rng.randf_range(0.12, 0.88))
		var y := -height * t
		var len := rng.randf_range(18.0, 44.0)
		c.draw_line(Vector2(x, y), Vector2(x + rng.randf_range(-4.0, 4.0), y - len), bark_dark if rng.randf() < 0.6 else bark_light, rng.randf_range(2.0, 4.0))
	var outline := PackedVector2Array(trunk)
	outline.append(trunk[0])
	c.draw_polyline(outline, ink, 5.0)

	# a few branches reaching into the canopy
	var top := Vector2(left[10].x * 0.5 + right[10].x * 0.5, -height)
	for i in 3:
		var dir := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, -0.45)).normalized()
		var start := Vector2(top.x, top.y + rng.randf_range(20.0, 90.0))
		var end := start + dir * rng.randf_range(90.0, 150.0)
		c.draw_line(start, end, ink, 17.0)
		c.draw_line(start, end, bark, 11.0)

	# canopy: overlapping clumps, back to front, each with an ink outline and a lit side
	var clumps := []
	for i in rng.randi_range(9, 12):
		var p := top + Vector2(rng.randf_range(-150.0, 150.0), rng.randf_range(-190.0, 10.0))
		clumps.append([p, rng.randf_range(62.0, 105.0), LEAF_COLORS[rng.randi() % LEAF_COLORS.size()]])
	clumps.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).y < (b[0] as Vector2).y)
	for clump: Array in clumps:
		var p: Vector2 = clump[0]
		var r: float = clump[1]
		var col: Color = clump[2]
		c.draw_colored_polygon(_wobble(p, r + 5.0, rng, 0.07), ink.lerp(col, 0.25))
		c.draw_colored_polygon(_wobble(p, r, rng, 0.09), col)
		c.draw_colored_polygon(_wobble(p + Vector2(-r * 0.22, -r * 0.28), r * 0.55, rng, 0.14), col.lightened(0.18))
		for k in 7:
			var q := p + Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r)) * 0.7
			c.draw_circle(q, rng.randf_range(4.0, 8.0), LEAF_COLORS[rng.randi() % LEAF_COLORS.size()].darkened(0.1))


# ---- cave columns and rock wall (neutral light tones, tinted per level theme at runtime) ---------

const COLUMN_RECT := Rect2(0.0, 0.0, 200.0, 300.0)
const ROCK_RECT := Rect2(0.0, 0.0, 256.0, 256.0)


## A vertically tileable root / rock column: wobbly outline, streaks and knots.
static func column() -> Texture2D:
	return texture("column", COLUMN_RECT, _paint.bind(_draw_column))


static func _draw_column(c: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var ink := Color(0.30, 0.22, 0.17)
	var base := Color(0.86, 0.76, 0.66)
	var dark := Color(0.62, 0.52, 0.43)
	var light := Color(0.97, 0.90, 0.80)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var t := float(i) / float(steps)
		var y := 300.0 * t
		left.append(Vector2(10.0 + 6.0 * sin(t * TAU * 2.0) + 3.0 * sin(t * TAU * 5.0), y))
		right.append(Vector2(190.0 + 6.0 * sin(t * TAU * 2.0 + 1.3) + 3.0 * sin(t * TAU * 4.0), y))
	var body := PackedVector2Array(left)
	var right_rev := right.duplicate()
	right_rev.reverse()
	body.append_array(right_rev)
	c.draw_colored_polygon(body, base)
	# shaded right third and lit left third
	var shade := PackedVector2Array()
	var glow := PackedVector2Array()
	for i in steps + 1:
		shade.append(left[i].lerp(right[i], 0.68))
		glow.append(left[i].lerp(right[i], 0.3))
	var shade_poly := PackedVector2Array(shade)
	shade_poly.append_array(right_rev)
	c.draw_colored_polygon(shade_poly, dark)
	var glow_poly := PackedVector2Array(left)
	var glow_rev := glow.duplicate()
	glow_rev.reverse()
	glow_poly.append_array(glow_rev)
	c.draw_colored_polygon(glow_poly, base.lerp(light, 0.5))
	# streaks and knots, kept inside the tile so it repeats cleanly
	for i in 26:
		var x := rng.randf_range(24.0, 176.0)
		var len := rng.randf_range(34.0, 110.0)
		var y := rng.randf_range(8.0, 292.0 - len)
		c.draw_line(Vector2(x, y), Vector2(x + rng.randf_range(-5.0, 5.0), y + len), dark if rng.randf() < 0.65 else light, rng.randf_range(2.5, 5.0))
	for i in 7:
		var p := Vector2(rng.randf_range(34.0, 166.0), rng.randf_range(24.0, 276.0))
		c.draw_colored_polygon(_wobble(p, rng.randf_range(9.0, 17.0), rng, 0.2), dark)
		c.draw_polyline(_wobble(p, rng.randf_range(9.0, 17.0), rng, 0.2), ink, 2.0)
	for edge: PackedVector2Array in [left, right]:
		c.draw_polyline(edge, ink, 5.0)


## A rock wall tile that wraps on all sides.
static func rock() -> Texture2D:
	return texture("rock", ROCK_RECT, _paint.bind(_draw_rock))


static func _draw_rock(c: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	c.draw_rect(ROCK_RECT, Color(0.80, 0.70, 0.60))
	var blots := []
	for i in 46:
		var shade := rng.randf_range(0.66, 1.0)
		blots.append([Vector2(rng.randf_range(0.0, 256.0), rng.randf_range(0.0, 256.0)), rng.randf_range(16.0, 48.0), Color(0.82 * shade, 0.71 * shade, 0.60 * shade)])
	var strokes := []
	for i in 40:
		var p := Vector2(rng.randf_range(0.0, 256.0), rng.randf_range(0.0, 256.0))
		strokes.append([p, p + Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(-8.0, 8.0)), rng.randf_range(2.0, 4.0)])
	for ox in [-256.0, 0.0, 256.0]:
		for oy in [-256.0, 0.0, 256.0]:
			var off := Vector2(ox, oy)
			for b: Array in blots:
				c.draw_colored_polygon(_wobble(b[0] + off, b[1], rng, 0.16), b[2])
			for s: Array in strokes:
				c.draw_line(s[0] + off, s[1] + off, Color(0.46, 0.37, 0.30, 0.55), s[2])
