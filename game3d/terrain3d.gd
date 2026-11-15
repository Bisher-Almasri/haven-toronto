class_name Terrain3D
extends StaticBody3D

static var _dirt: ImageTexture
static var _leaf: ImageTexture
static var _bark: ImageTexture
static var _fade_noise: ImageTexture
static var _root: ImageTexture
static var _fade_shader: Shader

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
	if not bark:
		_edge_fades(ccw)
		_roots(ccw, rng)


func _tri(st: SurfaceTool, faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	for v in [a, b, c]:
		st.set_normal(normal)
		# side walls sink into shadow towards the back so a slab's edge does not glare at the camera
		var shade := 1.0
		if absf(normal.z) < 0.5:
			shade = remap(v.z, z_back, z_front, 0.18, 0.8)
		st.set_color(Color(shade, shade, shade))
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
	m.vertex_color_use_as_albedo = true
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


## Seamless floor of the same hand-painted leaves that fall in the air (baked into floor_leaves.png).
static func leaf_texture() -> ImageTexture:
	if _leaf == null:
		var image := (load("res://floor_leaves.png") as Texture2D).get_image()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGB8)
		image.generate_mipmaps()
		_leaf = ImageTexture.create_from_image(image)
	return _leaf


func _leaf_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = leaf_texture()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.72, 0.62, 0.55)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _leaf_top(rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	var spots := []
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var dx := b.x - a.x
		if dx > 0.01 and absf(b.y - a.y) < dx * 1.6:
			any = true
			var lift := Vector3(0.0, 0.02, 0.0)
			# the back of the floor sinks into the cave's shadow instead of ending in a hard line
			var rows := [[z_back, 0.08], [z_back + 1.4, 0.32], [z_back + 3.4, 1.0], [z_front, 1.0]]
			for r in 3:
				var z0: float = rows[r][0]
				var z1: float = rows[r + 1][0]
				var c0: float = rows[r][1]
				var c1: float = rows[r + 1][1]
				var corners := [
					Vector3(a.x, a.y, z0) + lift, Vector3(b.x, b.y, z0) + lift,
					Vector3(b.x, b.y, z1) + lift, Vector3(a.x, a.y, z1) + lift]
				var uvs := [Vector2(a.x, z0), Vector2(b.x, z0), Vector2(b.x, z1), Vector2(a.x, z1)]
				var shades := [c0, c0, c1, c1]
				for k in [0, 1, 2, 0, 2, 3]:
					st.set_normal(Vector3.UP)
					st.set_uv(uvs[k] * 0.25)
					var sh: float = shades[k]
					st.set_color(Color(sh, sh * 0.9, sh * 0.82))
					st.add_vertex(corners[k])
			var length := a.distance_to(b)
			var slope := atan2(b.y - a.y, dx)
			for n in int(length * 7.0) + 1:
				var p := a.lerp(b, rng.randf())
				var z := z_front - rng.randf_range(0.0, 1.3) if rng.randf() < 0.6 else rng.randf_range(-3.0, z_front)
				var hang := rng.randf() < 0.08
				if hang:
					z = z_front + rng.randf_range(0.0, 0.1)
				spots.append([Vector3(p.x, p.y + rng.randf_range(0.03, 0.07), z), slope, hang])
	if not any:
		return
	var top := MeshInstance3D.new()
	top.mesh = st.commit()
	top.material_override = _leaf_material()
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(top)

	var halves := [[], []]
	for spot in spots:
		halves[rng.randi() % 2].append(spot)
	var textures := ["res://leaf_orange.png", "res://leaf_red.png"]
	for h in 2:
		var group: Array = halves[h]
		if group.is_empty():
			continue
		var quad := QuadMesh.new()
		quad.size = Vector2(0.34, 0.27)
		quad.orientation = PlaneMesh.FACE_Y
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(textures[h])
		m.albedo_color = Color(0.86, 0.78, 0.74)
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 1.0
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		quad.material = m
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.instance_count = group.size()
		multi.mesh = quad
		for i in group.size():
			var spot: Array = group[i]
			var size := rng.randf_range(0.7, 1.15)
			var basis := Basis(Vector3.BACK, float(spot[1])) * Basis(Vector3.UP, rng.randf_range(0.0, TAU))
			var tilt := rng.randf_range(-0.2, 0.2)
			if spot[2]:
				tilt = rng.randf_range(0.25, 0.45)
			basis = basis * Basis(Vector3.RIGHT, tilt) * Basis.from_scale(Vector3(size, size, size))
			multi.set_instance_transform(i, Transform3D(basis, spot[0]))
			var shade := rng.randf_range(0.75, 1.0)
			multi.set_instance_color(i, Color(shade, shade * rng.randf_range(0.9, 1.0), shade * rng.randf_range(0.85, 1.0)))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


static func fade_noise() -> ImageTexture:
	if _fade_noise == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.04
		noise.seed = 12
		noise.fractal_octaves = 3
		var image := noise.get_seamless_image(128, 128)
		image.convert(Image.FORMAT_L8)
		image.generate_mipmaps()
		_fade_noise = ImageTexture.create_from_image(image)
	return _fade_noise


static func fade_material(tint: Color, strength: float) -> ShaderMaterial:
	if _fade_shader == null:
		_fade_shader = Shader.new()
		_fade_shader.code = """shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;

uniform vec4 tint : source_color;
uniform float strength = 1.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(noise_tex, wp.xy * 0.8).r;
	float t = clamp(UV.x + (n - 0.5) * 0.4, 0.0, 1.0);
	ALBEDO = tint.rgb;
	ALPHA = pow(1.0 - t, 2.0) * strength;
}"""
	var m := ShaderMaterial.new()
	m.shader = _fade_shader
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("noise_tex", fade_noise())
	return m


## Soft dark gradients inside the front face along its edges, so a slab does not end in a hard line
## against the dark cave behind it: a heavy one on the sides and underside, a light contact shadow
## under the leafy lip on top.
func _edge_fades(ccw: PackedVector2Array) -> void:
	var dark := SurfaceTool.new()
	dark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lip := SurfaceTool.new()
	lip.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_dark := false
	var any_lip := false
	for i in ccw.size():
		var p := ccw[i]
		var q := ccw[(i + 1) % ccw.size()]
		var d := q - p
		var length := d.length()
		if length < 0.3 or minf(p.y, q.y) < -22.0:
			continue
		var out := Vector2(d.y, -d.x) / length
		var top := out.y > 0.55
		var depth := 0.3 if top else 0.55
		var st := lip if top else dark
		if top:
			any_lip = true
		else:
			any_dark = true
		var z := z_front + 0.012
		var corners := [
			Vector3(p.x, p.y, z), Vector3(q.x, q.y, z),
			Vector3(q.x - out.x * depth, q.y - out.y * depth, z), Vector3(p.x - out.x * depth, p.y - out.y * depth, z)]
		var us := [0.0, 0.0, 1.0, 1.0]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(Vector2(us[k], 0.0))
			st.add_vertex(corners[k])
	if any_dark:
		var mesh := MeshInstance3D.new()
		mesh.mesh = dark.commit()
		mesh.material_override = fade_material(Color(0.07, 0.035, 0.025), 0.85)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
	if any_lip:
		var mesh := MeshInstance3D.new()
		mesh.mesh = lip.commit()
		mesh.material_override = fade_material(Color(0.2, 0.1, 0.045), 0.6)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)


static func root_texture() -> ImageTexture:
	if _root == null:
		var image := Image.create(16, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			var t := y / 63.0
			var cx := 8.0 + 2.6 * sin(y * 0.21) * (0.4 + t)
			var half := lerpf(3.2, 0.6, t)
			for x in 16:
				var a := clampf((half - absf(x + 0.5 - cx)) * 1.4, 0.0, 1.0)
				image.set_pixel(x, y, Color(1, 1, 1, a))
		image.generate_mipmaps()
		_root = ImageTexture.create_from_image(image)
	return _root


## Hanging roots on the sides and underside of a slab, to break up its straight silhouette.
func _roots(ccw: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	var spots := []
	for i in ccw.size():
		var p := ccw[i]
		var q := ccw[(i + 1) % ccw.size()]
		var d := q - p
		var length := d.length()
		if length < 0.3 or minf(p.y, q.y) < -22.0:
			continue
		var out := Vector2(d.y, -d.x) / length
		if out.y > 0.2:
			continue
		for n in mini(int(length * 3.5), 90):
			var at := p.lerp(q, rng.randf())
			spots.append(Vector3(at.x + out.x * 0.03, at.y, rng.randf_range(0.0, 1.0)))
	if spots.is_empty():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.8)
	quad.center_offset = Vector3(0.0, -0.4, 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = root_texture()
	m.albedo_color = Color(0.22, 0.11, 0.06)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = m
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.instance_count = spots.size()
	multi.mesh = quad
	for i in spots.size():
		var spot: Vector3 = spots[i]
		var length := rng.randf_range(0.5, 1.3)
		var basis := Basis(Vector3.BACK, rng.randf_range(-0.2, 0.2)) * Basis.from_scale(Vector3(rng.randf_range(0.8, 1.4), length, 1.0))
		multi.set_instance_transform(i, Transform3D(basis, Vector3(spot.x, spot.y + 0.03, z_front + 0.02 + spot.z * 0.01)))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
