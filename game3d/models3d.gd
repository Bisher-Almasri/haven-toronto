class_name Models3D

static var _mats := {}


static func mat(color: Color, rough := 0.85, glow := 0.0) -> StandardMaterial3D:
	var key := "m%s%s%s" % [color, rough, glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


static func unlit(color: Color, additive := false) -> StandardMaterial3D:
	var key := "u%s%s" % [color, additive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	if color.a < 1.0 or additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mats[key] = m
	return m


static func sphere(radius: float, material: Material, pos := Vector3.ZERO, parent: Node = null, squash := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	return _instance(mesh, material, pos, parent, squash)


static func box(size: Vector3, material: Material, pos := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(mesh, material, pos, parent)


static func cylinder(top: float, bottom: float, height: float, material: Material, pos := Vector3.ZERO, parent: Node = null, segments := 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _instance(mesh, material, pos, parent)


static func _instance(mesh: Mesh, material: Material, pos: Vector3, parent: Node, squash := Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.scale = squash
	if parent:
		parent.add_child(node)
	return node


static func fibonacci(count: int) -> Array:
	var dirs := []
	for i in count:
		var y := 1.0 - 2.0 * (float(i) + 0.5) / float(count)
		var r := sqrt(maxf(1.0 - y * y, 0.0))
		var phi := float(i) * 2.399963
		dirs.append(Vector3(cos(phi) * r, y, sin(phi) * r))
	return dirs


static func spikes(dirs: Array, base: float, length: float, radius_at: float, material: Material, center := Vector3.ZERO) -> MultiMeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = base
	cone.height = length
	cone.radial_segments = 6
	cone.rings = 1
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.instance_count = dirs.size()
	multi.mesh = cone
	for i in dirs.size():
		var d: Vector3 = dirs[i]
		multi.set_instance_transform(i, Transform3D(Basis(Quaternion(Vector3.UP, d)), center + d * radius_at))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	return node


## Little billboard squares for CPUParticles3D.
static func dot_mesh(size: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_fog = true
	quad.material = m
	return quad


static func burst(amount: int, lifetime: float, size: float, color: Color, speed_min: float, speed_max: float, spread := 180.0, gravity := -9.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.mesh = dot_mesh(size)
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = Vector3(0.0, gravity, 0.0)
	p.color = color
	return p
