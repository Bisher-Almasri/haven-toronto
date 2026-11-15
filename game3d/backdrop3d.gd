class_name Backdrop3D
extends Node3D

const Z_WALL := -6.2
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

var level := 1
var world_end := 59.0
var env: Environment
var camera: Camera3D

var _wall_mat := StandardMaterial3D.new()
var _pillar_mats: Array[StandardMaterial3D] = []
var _spores: CPUParticles3D
var _leaves: Array[CPUParticles3D] = []
var _leaves_placed := false


func _ready() -> void:
	_wall_mat.roughness = 1.0
	_wall_mat.albedo_texture = Art2D.rock()
	_wall_mat.uv1_scale = Vector3((world_end + 40.0) / 4.0, 7.0, 1.0)
	var wall := Models3D.box(Vector3(world_end + 40.0, 28.0, 0.3), _wall_mat, Vector3(world_end * 0.5, -14.05, Z_WALL - 0.15), self)
	wall.name = "CaveWall"
	wall.layers = 2
	_pillars()
	_forest()
	_dust()
	_falling_leaves()
	_apply_palette(0.0)


func _pillars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var tex := Art2D.column()
	for layer in 3:
		var m := StandardMaterial3D.new()
		m.roughness = 1.0
		m.albedo_texture = tex
		m.uv1_scale = Vector3(1.0, 26.0 / 3.0, 1.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_pillar_mats.append(m)
	var x := -8.0
	while x < world_end + 8.0:
		var layer := rng.randi() % 3
		var z := Z_WALL + 0.8 + float(layer) * 1.4 + rng.randf_range(0.0, 0.8)
		var width := rng.randf_range(0.7, 2.0) * (1.5 - 0.3 * layer)
		var quad := QuadMesh.new()
		quad.size = Vector2(width, 26.0)
		var pillar := MeshInstance3D.new()
		pillar.mesh = quad
		pillar.material_override = _pillar_mats[layer]
		pillar.position = Vector3(x, -13.0, z)
		pillar.name = "Pillar"
		pillar.layers = 2
		add_child(pillar)
		x += rng.randf_range(2.2, 4.5)


func _forest() -> void:
	var leaf_ground := StandardMaterial3D.new()
	leaf_ground.albedo_texture = Terrain3D.leaf_texture()
	leaf_ground.albedo_color = Color(0.72, 0.62, 0.55)
	leaf_ground.uv1_scale = Vector3((world_end + 140.0) / 4.0, 9.0, 1.0)
	leaf_ground.roughness = 1.0
	leaf_ground.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	leaf_ground.disable_fog = true
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	# runs right up to the back edge of the terrain (z = -6.0) so no dark gap shows between them
	plane.size = Vector2(world_end + 140.0, 36.22)
	ground.mesh = plane
	ground.material_override = leaf_ground
	ground.position = Vector3(world_end * 0.5, 0.0, Z_WALL - 18.0 + 0.11)
	add_child(ground)

	var texture: Texture2D = load("res://overworld_bg.webp")
	var sky_mat := StandardMaterial3D.new()
	sky_mat.albedo_texture = texture
	sky_mat.albedo_color = Color(0.95, 0.88, 0.85)
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mat.disable_fog = true
	sky_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var step := 64.0
	var tiles := int((world_end + 140.0) / step) + 1
	for i in tiles:
		var quad := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(step, step * 9.0 / 16.0 * 1.02)
		quad.mesh = q
		quad.material_override = sky_mat
		quad.position = Vector3(-60.0 + i * step + step * 0.5, q.size.y * 0.5, Z_WALL - 36.0)
		if i % 2 == 1:
			quad.scale.x = -1.0
		add_child(quad)

	# painted trees standing on the forest floor, far ones fading into the orange haze
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var haze := Color(0.97, 0.62, 0.28)
	var x := -12.0
	while x < world_end + 16.0:
		var z := Z_WALL - rng.randf_range(3.0, 32.0)
		var depth := inverse_lerp(Z_WALL - 3.0, Z_WALL - 32.0, z)
		var size := rng.randf_range(1.5, 2.5)
		var tree := Art2D.sprite(Art2D.tree(rng.randi() % Art2D.TREE_VARIANTS), Art2D.TREE_RECT, size)
		if rng.randf() < 0.5:
			tree.scale.x = -tree.scale.x
		tree.position = Vector3(x, -0.05, z)
		tree.modulate = Color.WHITE.lerp(haze, depth * 0.7)
		tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tree.name = "Tree"
		add_child(tree)
		x += rng.randf_range(2.2, 4.6)

	# haze on the horizon
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := (world_end + 140.0) * 0.5
	var corners := [Vector3(-half, 0.0, 0.0), Vector3(half, 0.0, 0.0), Vector3(half, 7.0, 0.0), Vector3(-half, 7.0, 0.0)]
	var colors := [Color(haze, 0.8), Color(haze, 0.8), Color(haze, 0.0), Color(haze, 0.0)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_color(colors[k])
		st.add_vertex(corners[k])
	var haze_mesh := MeshInstance3D.new()
	haze_mesh.mesh = st.commit()
	var haze_mat := StandardMaterial3D.new()
	haze_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze_mat.vertex_color_use_as_albedo = true
	haze_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	haze_mat.disable_fog = true
	haze_mesh.material_override = haze_mat
	haze_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	haze_mesh.position = Vector3(world_end * 0.5, 0.0, Z_WALL - 34.0)
	add_child(haze_mesh)


func _dust() -> void:
	_spores = CPUParticles3D.new()
	_spores.amount = 70
	_spores.lifetime = 9.0
	_spores.preprocess = 9.0
	_spores.local_coords = false
	_spores.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_spores.emission_box_extents = Vector3(9.0, 4.0, 4.0)
	_spores.direction = Vector3.UP
	_spores.spread = 60.0
	_spores.initial_velocity_min = 0.08
	_spores.initial_velocity_max = 0.3
	_spores.gravity = Vector3.ZERO
	_spores.mesh = Models3D.dot_mesh(0.045)
	_spores.color = Color(1.0, 0.85, 0.55, 0.45)
	add_child(_spores)


func _falling_leaves() -> void:
	for texture_path in ["res://leaf_orange.png", "res://leaf_red.png"]:
		var material := StandardMaterial3D.new()
		material.albedo_texture = load(texture_path)
		material.albedo_color = Color(0.78, 0.68, 0.64)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.4
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.billboard_keep_scale = true
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var quad := QuadMesh.new()
		quad.size = Vector2(0.42, 0.33)
		quad.material = material
		var leaves := CPUParticles3D.new()
		leaves.amount = 70
		leaves.lifetime = 11.0
		leaves.preprocess = 11.0
		leaves.local_coords = false
		leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		leaves.emission_box_extents = Vector3(17.0, 0.4, 4.5)
		leaves.direction = Vector3(0.25, -1.0, 0.0)
		leaves.spread = 22.0
		leaves.initial_velocity_min = 0.55
		leaves.initial_velocity_max = 1.0
		leaves.gravity = Vector3(0.1, -0.04, 0.0)
		leaves.angle_min = 0.0
		leaves.angle_max = 360.0
		leaves.angular_velocity_min = -80.0
		leaves.angular_velocity_max = 80.0
		leaves.scale_amount_min = 0.55
		leaves.scale_amount_max = 1.25
		leaves.mesh = quad
		add_child(leaves)
		_leaves.append(leaves)


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


func _apply_palette(t: float) -> void:
	var pal := _palette(clampf(t, 0.0, 1.0))
	var surface: Color = pal[0]
	var deep: Color = pal[1]
	_wall_mat.albedo_color = surface.lerp(deep, 0.45)
	for i in _pillar_mats.size():
		_pillar_mats[i].albedo_color = surface.lerp(deep, 0.3 + 0.2 * i).lightened(0.12)
	if env:
		env.fog_light_color = deep.lightened(0.05)
		env.ambient_light_color = surface.lerp(Color.WHITE, 0.3)


func _process(_delta: float) -> void:
	if camera == null:
		return
	_apply_palette(camera.global_position.x / world_end)
	_spores.global_position = Vector3(camera.global_position.x, camera.global_position.y - 1.0, -2.0)
	for leaves in _leaves:
		leaves.global_position = Vector3(camera.global_position.x, 9.0, -1.5)
		if not _leaves_placed:
			leaves.restart()
	_leaves_placed = true
