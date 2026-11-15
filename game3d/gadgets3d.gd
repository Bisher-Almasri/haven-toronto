class_name Gadgets3D

const CAP := Color(0.84, 0.20, 0.16)
const CAP_MASTER := Color(0.92, 0.24, 0.34)
const CAP_UNDER := Color(0.97, 0.80, 0.55)
const SPOT := Color(1.0, 0.94, 0.78)
const STEM := Color(0.96, 0.86, 0.68)


class Shroom extends Area3D:
	signal activated
	signal bounced_player

	var cap_width := 1.8
	var bounce_height := 3.8
	var checkpoint := false
	var master := false
	var launch_apex_y := 4.2
	var drift_start_y := 0.9
	var landing_position := Vector3.ZERO
	var active := false

	var _model: Node3D
	var _ring: MeshInstance3D
	var _halo: MeshInstance3D
	var _lamp: OmniLight3D
	var _spores: CPUParticles3D
	var _tween: Tween

	func total_height() -> float:
		return cap_width * 0.82

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var shape := BoxShape3D.new()
		shape.size = Vector3(cap_width * 0.9, 0.44, 1.2)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(0.0, total_height() - 0.18, 0.0)
		add_child(collision)
		_build_model()
		_spores = Models3D.burst(18, 0.9, 0.07, Color(1.0, 0.88, 0.55), 1.2, 3.2, 40.0, -4.2)
		_spores.position = Vector3(0.0, total_height(), 0.3)
		add_child(_spores)
		if checkpoint:
			add_to_group("toy_checkpoints")

	func _build_model() -> void:
		_model = Node3D.new()
		add_child(_model)
		if Art2D.PAINTED_MUSHROOM:
			_build_painted()
		else:
			var rect := Art2D.MASTER_RECT if master else Art2D.MUSHROOM_RECT
			var art := Art2D.sprite(Art2D.mushroom(master), rect, cap_width * 100.0 / (Art2D.MASTER_W if master else Art2D.MUSHROOM_W), true)
			art.position = Vector3(0.0, 0.0, -0.05)
			_model.add_child(art)
		if checkpoint:
			var ring_mesh := TorusMesh.new()
			ring_mesh.inner_radius = cap_width * 0.6
			ring_mesh.outer_radius = cap_width * 0.65
			ring_mesh.rings = 32
			ring_mesh.ring_segments = 6
			_ring = MeshInstance3D.new()
			_ring.mesh = ring_mesh
			_ring.rotation.x = PI * 0.5
			_ring.position = Vector3(0.0, total_height() * 0.5, -0.02)
			add_child(_ring)
			_refresh_ring()
			_lamp = OmniLight3D.new()
			_lamp.light_color = Color(1.0, 0.82, 0.45)
			_lamp.light_energy = 0.0
			_lamp.omni_range = 5.0
			_lamp.light_specular = 0.0
			_lamp.position = Vector3(0.0, total_height() * 0.6, 1.3)
			add_child(_lamp)
		if master:
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.8, 0.4)
			light.light_energy = 0.9
			light.omni_range = 7.0
			light.position = Vector3(0.0, total_height() * 0.7, 1.6)
			add_child(light)

	# The hand-painted 128x128 mushroom, stretched to the height the bounce trigger expects.
	func _build_painted() -> void:
		var tex := Art2D.PAINTED_MUSHROOM_TEX
		var art := Sprite3D.new()
		art.texture = tex
		art.pixel_size = total_height() * 1.05 / float(tex.get_height())
		art.offset = Vector2(0.0, tex.get_height() * 0.5)
		art.shaded = Art2D.LIT_PROPS
		art.double_sided = true
		art.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		art.position = Vector3(0.0, 0.0, -0.05)
		if master:
			art.modulate = Color(1.0, 0.72, 0.84)
		_model.add_child(art)
		if master:
			var glow := Gradient.new()
			glow.colors = PackedColorArray([Color(1.0, 0.8, 0.25, 0.6), Color(1.0, 0.8, 0.25, 0.0)])
			glow.offsets = PackedFloat32Array([0.0, 1.0])
			var glow_tex := GradientTexture2D.new()
			glow_tex.gradient = glow
			glow_tex.fill = GradientTexture2D.FILL_RADIAL
			glow_tex.fill_from = Vector2(0.5, 0.5)
			glow_tex.fill_to = Vector2(1.0, 0.5)
			glow_tex.width = 128
			glow_tex.height = 128
			var glow_mat := StandardMaterial3D.new()
			glow_mat.albedo_texture = glow_tex
			glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			glow_mat.disable_fog = true
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE * cap_width * 2.4
			_halo = MeshInstance3D.new()
			_halo.mesh = quad
			_halo.material_override = glow_mat
			_halo.position = Vector3(0.0, total_height() * 0.55, -0.2)
			add_child(_halo)

	func _refresh_ring() -> void:
		if _ring == null:
			return
		if _lamp:
			_lamp.light_energy = 0.5 if active else 0.0
		_ring.material_override = Models3D.unlit(Color(1.0, 0.85, 0.3, 0.9) if active else Color(0.35, 0.35, 0.35, 0.35))

	func _process(_delta: float) -> void:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		if _ring and active:
			_ring.scale = Vector3.ONE * (1.0 + 0.06 * pulse)
		if _halo:
			_halo.scale = Vector3.ONE * (0.9 + 0.12 * pulse)

	# Jolt reports Area3D overlaps a couple of frames late, which is too slow for a hog falling at
	# 18 m/s, so the cap is tested against the hog's position directly.
	func _physics_process(delta: float) -> void:
		var cap_top := global_position.y + total_height()
		var half := cap_width * 0.45
		for node in get_tree().get_nodes_in_group("hog"):
			var hog := node as Hog3D
			if hog == null or hog.ko:
				continue
			var p := hog.global_position
			if absf(p.x - global_position.x) > half + Hog3D.RADIUS * 0.4:
				continue
			var bottom := p.y - Hog3D.RADIUS
			if checkpoint and not active and absf(p.y - cap_top) < 1.0:
				_activate(hog)
			if hog.linear_velocity.y > -0.4:
				continue
			var reach := maxf(-hog.linear_velocity.y * delta * 2.0, 0.0)
			if bottom > cap_top + 0.04 + Hog3D.RADIUS or bottom < cap_top - 0.52 - reach:
				continue
			_pop(hog)

	func _activate(hog: Hog3D) -> void:
		for other in get_tree().get_nodes_in_group("toy_checkpoints"):
			var m := other as Shroom
			m.active = false
			m._refresh_ring()
			m._ring.scale = Vector3.ONE
		active = true
		_refresh_ring()
		activated.emit()
		hog.respawn_point = global_position + Vector3(0.0, total_height() + Hog3D.RADIUS + 0.06, 0.0)

	func _pop(hog: Hog3D) -> void:
		if master:
			hog.launch_to(landing_position, launch_apex_y, drift_start_y)
		else:
			hog.bounce_up(bounce_height)
		bounced_player.emit()
		_spores.restart()
		_spores.emitting = true
		if _tween:
			_tween.kill()
		_model.scale = Vector3(1.2, 0.65, 1.2)
		_tween = create_tween()
		_tween.tween_property(_model, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


class Bug extends Area3D:
	signal killed

	var patrol_range := 0.9
	var speed := 0.7
	var pogo_height := 3.0

	var _dir := 1.0
	var _origin_x := 0.0
	var _dying := false
	var _model: Node3D

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		_origin_x = position.x
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.5, 0.32, 1.0)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(0.0, 0.17, 0.0)
		add_child(collision)
		_model = Node3D.new()
		add_child(_model)
		var art := Art2D.sprite(Art2D.beetle(), Art2D.BEETLE_RECT, 1.0, true)
		art.position = Vector3(0.0, 0.0, 0.05)
		_model.add_child(art)

	func _physics_process(delta: float) -> void:
		if _dying:
			return
		position.x += _dir * speed * delta
		if absf(position.x - _origin_x) >= patrol_range:
			position.x = _origin_x + signf(position.x - _origin_x) * patrol_range
			_dir = -_dir
		for body in get_overlapping_bodies():
			var hog := body as Hog3D
			if hog == null or hog.ko:
				continue
			if hog.curled:
				var falling := hog.linear_velocity.y < -1.0
				die()
				if falling:
					hog.bounce_up(pogo_height)
				return
			hog.knock_out(global_position)

	func _process(_delta: float) -> void:
		_model.scale.x = _dir if not _dying else _model.scale.x

	func die() -> void:
		if _dying:
			return
		_dying = true
		killed.emit()
		set_deferred("monitoring", false)
		var tween := create_tween()
		tween.tween_property(_model, "scale", Vector3(1.5 * _dir, 0.2, 1.0), 0.2)
		tween.tween_interval(0.15)
		tween.tween_callback(queue_free)


class Thorns extends Area3D:
	var width := 3.0
	var draw_spikes := true

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var shape := BoxShape3D.new()
		shape.size = Vector3(width, 0.3, 1.2)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(0.0, 0.15, 0.0)
		add_child(collision)
		if not draw_spikes:
			return
		# the 2D spike art tiled across the pit, in rows so it fills the depth of the cave
		var tex := Art2D.thorn()
		var quad := QuadMesh.new()
		quad.size = Vector2(width, 0.46)
		var z := 0.5
		var shade := 1.0
		while z > -5.6:
			var m := StandardMaterial3D.new()
			m.albedo_texture = tex
			m.albedo_color = Color(shade, shade, shade)
			m.uv1_scale = Vector3(width / 0.26, 1.0, 1.0)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
			var row := MeshInstance3D.new()
			row.mesh = quad
			row.material_override = m
			row.position = Vector3(0.0, 0.15, z)
			add_child(row)
			z -= 0.9
			shade -= 0.1
		Models3D.box(Vector3(width, 0.08, 7.0), Models3D.mat(Color(0.25, 0.1, 0.08)), Vector3(0.0, -0.04, -2.2), self)

	func _physics_process(_delta: float) -> void:
		for body in get_overlapping_bodies():
			var hog := body as Hog3D
			if hog == null or hog.ko:
				continue
			if draw_spikes and hog.curled:
				continue
			hog.knock_out(global_position)


class Zone extends Area3D:
	signal fired

	var size := Vector3(0.8, 6.0, 2.0)
	var _done := false

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		add_child(collision)

	func _physics_process(_delta: float) -> void:
		if _done:
			return
		for body in get_overlapping_bodies():
			if body is Hog3D and not body.ko:
				_done = true
				fired.emit()


class Seesaw extends Node3D:
	var length := 3.8
	var max_tilt_deg := 20.0
	var support_depth := 6.5

	func _ready() -> void:
		var pivot := StaticBody3D.new()
		pivot.collision_layer = 0
		pivot.collision_mask = 0
		add_child(pivot)

		var plank := RigidBody3D.new()
		plank.collision_layer = 4
		plank.collision_mask = 1 | 2 | 4
		plank.mass = 4.0
		plank.gravity_scale = Hog3D.GRAVITY_SCALE
		plank.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		plank.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		plank.linear_damp = 0.1
		plank.angular_damp = 2.5
		plank.can_sleep = false
		plank.axis_lock_linear_z = true
		plank.axis_lock_angular_x = true
		plank.axis_lock_angular_y = true
		var material := PhysicsMaterial.new()
		material.friction = 0.9
		plank.physics_material_override = material
		var shape := BoxShape3D.new()
		shape.size = Vector3(length, 0.22, 1.2)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		plank.add_child(collision)
		plank.add_child(Art2D.sprite(Art2D.plank(length), Art2D.plank_rect(length), 1.0, true))
		add_child(plank)

		var joint := HingeJoint3D.new()
		add_child(joint)
		joint.node_a = joint.get_path_to(pivot)
		joint.node_b = joint.get_path_to(plank)

		var post := Art2D.sprite(Art2D.support(support_depth), Art2D.support_rect(support_depth), 1.0, true)
		post.position = Vector3(0.0, 0.0, -0.1)
		add_child(post)

		var half := length * 0.5 - 0.2
		var stop_top := sin(deg_to_rad(max_tilt_deg)) * half + 0.12
		for side in [-1.0, 1.0]:
			var stopper := StaticBody3D.new()
			stopper.collision_layer = 1
			stopper.collision_mask = 0
			var stopper_shape := BoxShape3D.new()
			stopper_shape.size = Vector3(0.4, 2.0, 1.2)
			var stopper_collision := CollisionShape3D.new()
			stopper_collision.shape = stopper_shape
			stopper.add_child(stopper_collision)
			stopper.position = Vector3(side * half, -(stop_top + 1.0), 0.0)
			add_child(stopper)


class Pendulum extends Node3D:
	var length := 5.2
	var start_angle := 0.9
	var ball_radius := 0.44

	func _ready() -> void:
		var pivot := StaticBody3D.new()
		pivot.collision_layer = 0
		pivot.collision_mask = 0
		add_child(pivot)
		var hub := Art2D.sprite(Art2D.dot(), Art2D.DOT_RECT, 1.0, true)
		hub.position = Vector3(0.0, 0.0, -0.1)
		add_child(hub)

		var swinger := RigidBody3D.new()
		swinger.collision_layer = 4
		swinger.collision_mask = 1 | 2 | 4
		swinger.mass = 6.0
		swinger.gravity_scale = Hog3D.GRAVITY_SCALE
		swinger.can_sleep = false
		swinger.continuous_cd = true
		swinger.axis_lock_linear_z = true
		swinger.axis_lock_angular_x = true
		swinger.axis_lock_angular_y = true
		swinger.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		swinger.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		swinger.linear_damp = 0.0
		swinger.angular_damp = 0.0
		swinger.rotation.z = -start_angle
		var rod_shape := BoxShape3D.new()
		rod_shape.size = Vector3(0.26, length, 0.5)
		var rod := CollisionShape3D.new()
		rod.shape = rod_shape
		rod.position = Vector3(0.0, -length * 0.5, 0.0)
		swinger.add_child(rod)
		var ball_shape := SphereShape3D.new()
		ball_shape.radius = ball_radius
		var ball := CollisionShape3D.new()
		ball.shape = ball_shape
		ball.position = Vector3(0.0, -length, 0.0)
		swinger.add_child(ball)
		var art := Art2D.sprite(Art2D.swinger(length, ball_radius), Art2D.swinger_rect(length, ball_radius), 1.0, true)
		art.position.z = 0.05
		swinger.add_child(art)
		add_child(swinger)

		var joint := HingeJoint3D.new()
		add_child(joint)
		joint.node_a = joint.get_path_to(pivot)
		joint.node_b = joint.get_path_to(swinger)


class Boulder extends RigidBody3D:
	var radius := 0.45

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 1 | 2 | 4
		gravity_scale = Hog3D.GRAVITY_SCALE
		mass = 3.0
		can_sleep = false
		axis_lock_linear_z = true
		axis_lock_angular_x = true
		axis_lock_angular_y = true
		var material := PhysicsMaterial.new()
		material.friction = 0.8
		material.bounce = 0.2
		physics_material_override = material
		var shape := SphereShape3D.new()
		shape.radius = radius
		var collision := CollisionShape3D.new()
		collision.shape = shape
		add_child(collision)
		var art := Art2D.sprite(Art2D.boulder(radius), Art2D.BOULDER_RECT, 1.0, true)
		art.position.z = 0.05
		add_child(art)
