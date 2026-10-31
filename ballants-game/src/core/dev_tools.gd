extends Node
## DEV TOOLS -- helpers that only wake up when the game is started from the
## command line with special flags. They do nothing during a normal F5 run.
##
## Open a terminal in the ballants-game folder and run:
##
##   godot --headless -- --tests
##       Runs the physics test suite in tests/physics_tests.gd (throwaway
##       worlds, no level) and quits. Exit code 0 = all passed.
##
##   godot -- --autotest
##       Plays the level by itself for a few seconds (rolls forward, jumps),
##       prints PASS/FAIL checks, and quits. Exit code 0 = all passed.
##
##   godot -- --screenshot=/full/path/picture.png
##       Waits 1.5 seconds, saves a picture of the game window, and quits.
##       Can be combined with --autotest to capture the end of the test.
##
##   godot -- --zoom=2.5
##       Overrides the camera distance for this run (close-ups of the ant).
##
##   godot -- --press=toggle_tuning_panel
##       Presses a named input action half a second after start (any action
##       from the Input Map). Handy with --screenshot to capture the F1/F2 panels.
##
##   godot --headless -- --save-roundtrip
##       Re-saves the tuning file unchanged and quits; `git diff` should then
##       be empty. Checks the F1 panel's Save can't mangle the file.
##
## Loaded as a global called "DevTools".

var _screenshot_path := ""
var _failures := 0


func _ready() -> void:
	var autotest := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--tests":
			get_tree().change_scene_to_file.call_deferred("res://tests/physics_tests.tscn")
			return
		elif arg == "--autotest":
			autotest = true
		elif arg.begins_with("--screenshot="):
			_screenshot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--zoom="):
			Tuning.camera_distance = float(arg.get_slice("=", 1))
		elif arg.begins_with("--press="):
			_press_later(arg.get_slice("=", 1))
		elif arg == "--save-roundtrip":
			var error := Tuning.save_to_file()
			print("[devtools] save roundtrip: %s" % ("ok" if error.is_empty() else error))
			get_tree().quit.call_deferred(0 if error.is_empty() else 1)
			return
	if autotest:
		_run_autotest()
	elif not _screenshot_path.is_empty():
		_screenshot_then_quit(1.5)


func _press_later(action: String) -> void:
	await get_tree().create_timer(0.5).timeout
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("[autotest] %s: %s %s" % ["PASS" if ok else "FAIL", name, detail])


func _run_autotest() -> void:
	await get_tree().create_timer(1.0).timeout
	var player := get_tree().get_first_node_in_group("player") as PlayerBall
	_check("player exists", player != null)
	if player == null:
		_finish()
		return
	_check("ball settled on ground", player.is_grounded(), "y=%.2f" % player.global_position.y)
	var impacts := [0]
	if player.has_signal("impacted"):
		player.impacted.connect(func(_s, _d, _p): impacts[0] += 1)

	# Roll backward (toward the camera) for 1.5 seconds: that side of the
	# test arena is open ground, so nothing gets in the way.
	Input.action_press("move_back")
	await get_tree().create_timer(0.35).timeout
	if not _screenshot_path.is_empty():
		await _save_screenshot(_screenshot_path.get_basename() + "_accel.png")
	await get_tree().create_timer(1.15).timeout
	_check("no false impacts while rolling on flat ground", impacts[0] == 0, "impacts=%d" % impacts[0])
	var vel := player.linear_velocity
	var speed := Vector2(vel.x, vel.z).length()
	_check("ball rolls when pushed", speed > 3.0, "speed=%.2f m/s" % speed)
	_check("ball obeys speed cap", speed <= Tuning.max_speed + 0.5, "max=%.1f" % Tuning.max_speed)
	_check("back is toward the camera", vel.z > 0.0, "vz=%.2f" % vel.z)
	if not _screenshot_path.is_empty():
		await _save_screenshot(_screenshot_path.get_basename() + "_rolling.png")
	Input.action_release("move_back")

	# Jump and measure how high the apex is above the take-off point.
	var start_y := player.global_position.y
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	var apex := start_y
	var t := 0.0
	var landing_shot_taken := false
	impacts[0] = 0
	while t < 1.2:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		apex = max(apex, player.global_position.y)
		if t > 0.3 and player.is_grounded() and not landing_shot_taken:
			landing_shot_taken = true
			if not _screenshot_path.is_empty():
				await get_tree().create_timer(0.08).timeout
				await _save_screenshot(_screenshot_path.get_basename() + "_landing.png")
	var height := apex - start_y
	_check("jump height matches tuning", abs(height - Tuning.jump_height) < 0.35,
			"got %.2f m, wanted %.2f m" % [height, Tuning.jump_height])
	var landed := player.is_grounded()
	for i in 40:   # allow a small bounce to settle
		if landed:
			break
		await get_tree().physics_frame
		landed = player.is_grounded()
	_check("ball landed again", landed)
	_check("landing counts as an impact", impacts[0] >= 1, "impacts=%d" % impacts[0])

	# Restart should put the ball back near the start.
	Game.restart_level()
	await get_tree().create_timer(0.5).timeout
	player = get_tree().get_first_node_in_group("player") as PlayerBall
	_check("restart reloads the level", player != null and player.global_position.length() < 3.0)

	# Drop a crate on one end of the seesaw: the plank should tip around its
	# hinge (the Z axis) and nothing else.
	var seesaw := get_tree().current_scene.find_child("Seesaw", true, false)
	if seesaw:
		var plank := seesaw.get_node("Plank") as RigidBody3D
		var crate := load("res://src/objects/crate.tscn").instantiate() as RigidBody3D
		get_tree().current_scene.add_child(crate)
		crate.global_position = seesaw.global_position + Vector3(-2.5, 2.0, 0.0)
		await get_tree().create_timer(1.5).timeout
		var tilt := plank.rotation
		_check("seesaw tips on its hinge", abs(tilt.z) > 0.1 and abs(tilt.x) < 0.05 and abs(tilt.y) < 0.05,
				"rotation=(%.2f, %.2f, %.2f)" % [tilt.x, tilt.y, tilt.z])
	else:
		_check("seesaw present in level", false)
	_finish()


func _save_screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("[devtools] screenshot %s -> %s" % ["saved" if err == OK else "FAILED", path])


func _finish() -> void:
	print("[autotest] %s (%d failures)" % ["ALL PASSED" if _failures == 0 else "FAILED", _failures])
	if _screenshot_path.is_empty():
		get_tree().quit(1 if _failures > 0 else 0)
	else:
		_screenshot_then_quit(0.2, 1 if _failures > 0 else 0)


func _screenshot_then_quit(delay: float, exit_code := 0) -> void:
	await get_tree().create_timer(delay).timeout
	await _save_screenshot(_screenshot_path)
	get_tree().quit(exit_code)
