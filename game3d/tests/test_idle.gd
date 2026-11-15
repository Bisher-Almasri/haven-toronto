extends SceneTree

# godot --headless --path . --script res://game3d/tests/test_idle.gd
# A hedgehog standing still shows the standing frame and blinks now and then.

func _initialize() -> void:
	ToyScores.enabled = false
	Game3D.level = 1
	var level: Node = load("res://game3d/game3d.tscn").instantiate()
	root.add_child(level)
	for i in 60:
		await physics_frame
	var hog: Hog3D = level.hog
	var seen := {}
	var blinks := 0
	var was_blinking := false
	for i in 60 * 12:
		await process_frame
		var tex: Texture2D = hog._sprite.texture
		seen[tex.resource_path.get_file()] = true
		var blinking := tex == Hog3D.TEX_BLINK
		if blinking and not was_blinking:
			blinks += 1
		was_blinking = blinking
	print("frames seen: ", seen.keys(), "  blinks in ~12 s: ", blinks)
	var ok := seen.has(Hog3D.TEX_STAND.resource_path.get_file()) and blinks >= 1
	print("PASS  idle shows the standing frame and blinks" if ok else "FAIL  idle animation")
	quit(0 if ok else 1)
