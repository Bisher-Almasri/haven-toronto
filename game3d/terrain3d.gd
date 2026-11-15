class_name Terrain3D
extends StaticBody3D

const LEAVES := [
	Color(0.93, 0.45, 0.10),
	Color(0.78, 0.22, 0.10),
	Color(0.98, 0.72, 0.15),
	Color(0.62, 0.30, 0.10),
]

static var _dirt: ImageTexture
static var _leaf: ImageTexture
static var _bark: ImageTexture

## Outline in metres: x right, y up. Top surfaces run left to right in this order.
@export var points := PackedVector2Array()
@export var grass := true
@export var fill := Color(0.34, 0.20, 0.11)
var bark := false
var z_back := -6.0
var z_front := 1.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	if points.size() < 3:
		return
	var pts := points
	var area := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		area += a.x * b.y - b.x * a.y
	var ccw := PackedVector2Array(pts)
	if area < 0.0:
		ccw.reverse()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var tris := Geometry2D.triangulate_polygon(ccw)
	for t in range(0, tris.size(), 3):
		var a := ccw[tris[t]]
		var b := ccw[tris[t + 1]]
		var c := ccw[tris[t + 2]]
		if (b - a).cross(c - a) > 0.0:
			var swap := b
			b = c
			c = swap
		# front (+z) wound clockwise, back (-z) the other way
		_tri(st, faces, Vector3(a.x, a.y, z_front), Vector3(b.x, b.y, z_front), Vector3(c.x, c.y, z_front), Vector3.BACK)
		_tri(st, faces, Vector3(a.x, a.y, z_back), Vector3(c.x, c.y, z_back), Vector3(b.x, b.y, z_back), Vector3.FORWARD)
	for i in ccw.size():
		var p := ccw[i]
		var q := ccw[(i + 1) % ccw.size()]
		var d := q - p
		if d.length() < 0.001:
			continue
		var n := Vector3(d.y, -d.x, 0.0).normalized()
		var af := Vector3(p.x, p.y, z_front)
		var bf := Vector3(q.x, q.y, z_front)
		var bb := Vector3(q.x, q.y, z_back)
		var ab := Vector3(p.x, p.y, z_back)
		_tri(st, faces, af, bf, bb, n)
		_tri(st, faces, af, bb, ab, n)
	var mesh := st.commit()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _dirt_material()
	add_child(instance)

	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(name)) + points.size()
	if grass:
		_leaf_top(rng)
	_pebbles(rng)


func _tri(st: SurfaceTool, faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	for v in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(v)
	faces.append_array(PackedVector3Array([a, b, c]))


func _dirt_material() -> StandardMaterial3D:
	if _dirt == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.03
		noise.seed = 4
		var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
		for y in 256:
			for x in 256:
				var g := 0.8 + 0.2 * noise.get_noise_2d(x, y)
				image.set_pixel(x, y, Color(g, g, g))
		image.generate_mipmaps()
		_dirt = ImageTexture.create_from_image(image)
	var m := StandardMaterial3D.new()
	m.albedo_color = fill
	if bark:
		m.albedo_texture = bark_texture()
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.45
		m.roughness = 1.0
		return m
	m.albedo_texture = _dirt
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.5
	m.roughness = 0.95
	return m


## Vertical bark streaks: a wide, short seamless noise image stretched tall.
static func bark_texture() -> ImageTexture:
	if _bark == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.05
		noise.seed = 9
		var crack := FastNoiseLite.new()
		crack.frequency = 0.09
		crack.seed = 31
		var base := noise.get_seamless_image(256, 32)
		var cracks := crack.get_seamless_image(256, 32)
		var image := Image.create(256, 32, false, Image.FORMAT_RGB8)
		for y in 32:
			for x in 256:
				var g := 0.62 + 0.38 * base.get_pixel(x, y).r
				if cracks.get_pixel(x, y).r > 0.7:
					g *= 0.5
				image.set_pixel(x, y, Color(g, g, g))
		image.generate_mipmaps()
		_bark = ImageTexture.create_from_image(image)
	return _bark


static func leaf_texture() -> ImageTexture:
	if _leaf == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
		image.fill(Color(0.55, 0.28, 0.10))
		for i in 520:
			var color: Color = LEAVES[rng.randi() % LEAVES.size()]
			var cx := rng.randi_range(0, 127)
			var cy := rng.randi_range(0, 127)
			var r := rng.randi_range(2, 5)
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx * dx + dy * dy <= r * r:
						image.set_pixel((cx + dx) & 127, (cy + dy) & 127, color)
		image.generate_mipmaps()
		_leaf = ImageTexture.create_from_image(image)
	return _leaf


func _leaf_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = leaf_texture()
	m.albedo_color = Color(0.62, 0.55, 0.5)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_scale = Vector3(1.0, 1.0, 1.0)
	return m


func _leaf_top(rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	var lumps := []
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var dx := b.x - a.x
		if dx > 0.01 and absf(b.y - a.y) < dx * 1.6:
			any = true
			var lift := Vector3(0.0, 0.02, 0.0)
			var corners := [
				Vector3(a.x, a.y, z_back) + lift, Vector3(b.x, b.y, z_back) + lift,
				Vector3(b.x, b.y, z_front) + lift, Vector3(a.x, a.y, z_front) + lift]
			var uvs := [Vector2(a.x, z_back), Vector2(b.x, z_back), Vector2(b.x, z_front), Vector2(a.x, z_front)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.set_uv(uvs[k] * 0.35)
				st.add_vertex(corners[k])
			var length := a.distance_to(b)
			var s := 0.0
			while s < length:
				var p := a.lerp(b, s / length)
				lumps.append(Vector3(p.x, p.y + rng.randf_range(-0.01, 0.05), z_front - rng.randf_range(0.0, 0.12)))
				s += 0.13
	if not any:
		return
	var top := MeshInstance3D.new()
	top.mesh = st.commit()
	top.material_override = _leaf_material()
	add_child(top)
	var blob := SphereMesh.new()
	blob.radius = 0.08
	blob.height = 0.12
	blob.radial_segments = 8
	blob.rings = 4
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.instance_count = lumps.size()
	multi.mesh = blob
	for i in lumps.size():
		var size := rng.randf_range(0.8, 1.5)
		multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(size, size * 0.8, size)), lumps[i]))
		multi.set_instance_color(i, LEAVES[rng.randi() % LEAVES.size()])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	instance.material_override = m
	add_child(instance)


func _pebbles(rng: RandomNumberGenerator) -> void:
	var rect := Rect2(points[0], Vector2.ZERO)
	for p in points:
		rect = rect.expand(p)
	var count := mini(int(rect.get_area() / 0.9), 160)
	var spots := []
	for i in count:
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		if Geometry2D.is_point_in_polygon(p, points):
			spots.append(p)
	if spots.is_empty():
		return
	var pebble := SphereMesh.new()
	pebble.radius = 0.05
	pebble.height = 0.1
	pebble.radial_segments = 8
	pebble.rings = 4
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.instance_count = spots.size()
	multi.mesh = pebble
	for i in spots.size():
		var r := rng.randf_range(0.6, 1.6)
		multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r, r * 0.8, 0.4)), Vector3(spots[i].x, spots[i].y, z_front)))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = Models3D.mat(Color(0.2, 0.12, 0.07))
	add_child(instance)
