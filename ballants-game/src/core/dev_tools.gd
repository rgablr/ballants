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
##       Loads the test arena, plays it by itself for a few seconds (rolls,
##       jumps), prints PASS/FAIL checks, and quits. Exit code 0 = all passed.
##
##   godot -- --level=2
##       Starts on that level (1/2/3), the test arena (0) or the title
##       area (-1, which is also where a normal start opens). Combine with
##       --screenshot, --zoom, --camera-yaw to picture a level.
##
##   godot --headless -- --drive=/full/path/level_1.json
##       A bot drives the ball through the waypoints in the file (format in
##       src/core/level_bot.gd) and reports whether it reached the goal.
##       This is how "the level can be completed" is checked by machine.
##
##   godot -- --screenshot=/full/path/picture.png
##       Waits 1.5 seconds, saves a picture of the game window, and quits.
##       Can be combined with --autotest to capture the end of the test.
##
##   godot -- --zoom=2.5
##       Overrides the camera distance for this run (close-ups of the ant).
##
##   godot -- --level=1 --teleport=-9.7,1,-180
##       Puts the ball at that x,y,z right after the level loads, to picture
##       or try one spot of a level without rolling there.
##
##   godot -- --hub --autoplay=no --screenshot=/tmp/s.png --shots=30,32,34
##       Presses through cutscene dialogue with that answer and saves a
##       picture at each time (s_1.png, s_2.png...).
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
var _timed_shots := false


func _ready() -> void:
	var autotest := false
	var level := -2          # -2 = leave the main scene alone
	var drive_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--tests":
			get_tree().change_scene_to_file.call_deferred("res://tests/physics_tests.tscn")
			return
		elif arg == "--autotest":
			autotest = true
			level = 0
		elif arg.begins_with("--level="):
			level = int(arg.get_slice("=", 1))
		elif arg == "--hub":
			# The anthill hub, arriving by the fall from the top.
			level = -3
		elif arg.begins_with("--hubtest"):
			# --hubtest=yes | no | skip : plays the hub arrival and opening
			# cutscene by machine and checks the hub's rules (see _run_hubtest).
			_run_hubtest(arg.get_slice("=", 1) if arg.contains("=") else "yes")
			return
		elif arg.begins_with("--scene="):
			# Any scene by path, e.g. --scene=res://levels/garden/garden_showcase.tscn
			Levels.current_index = -1
			get_tree().change_scene_to_file.call_deferred(arg.get_slice("=", 1))
		elif arg.begins_with("--drive="):
			drive_path = arg.get_slice("=", 1)
		elif arg.begins_with("--screenshot="):
			_screenshot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--zoom="):
			Tuning.camera_distance = float(arg.get_slice("=", 1))
		elif arg.begins_with("--camera-yaw="):
			_aim_camera_later(float(arg.get_slice("=", 1)), Tuning.camera_pitch_default)
		elif arg.begins_with("--camera-pitch="):
			Tuning.camera_pitch_default = float(arg.get_slice("=", 1))
		elif arg.begins_with("--teleport="):
			var parts := arg.get_slice("=", 1).split(",")
			if parts.size() == 3:
				_teleport_later(Vector3(float(parts[0]), float(parts[1]), float(parts[2])))
		elif arg.begins_with("--press="):
			# --press=jump  (at 0.5 s)  or  --press=jump@3,dialogue_no@6.5
			for item in arg.get_slice("=", 1).split(","):
				var at := 0.5
				var action := item
				if item.contains("@"):
					action = item.get_slice("@", 0)
					at = float(item.get_slice("@", 1))
				_press_later(action, at)
		elif arg.begins_with("--autoplay="):
			# --autoplay=yes|no : presses through any cutscene dialogue and
			# gives that answer, for watching cutscenes with --shots.
			_autoplay(arg.get_slice("=", 1))
		elif arg.begins_with("--shots="):
			# --shots=1,3.5,8 with --screenshot=base.png saves base_1.png, base_2.png...
			var times := PackedFloat32Array()
			for item in arg.get_slice("=", 1).split(","):
				times.append(float(item))
			_timed_shots_later(times)
		elif arg == "--save-roundtrip":
			var error := Tuning.save_to_file()
			print("[devtools] save roundtrip: %s" % ("ok" if error.is_empty() else error))
			get_tree().quit.call_deferred(0 if error.is_empty() else 1)
			return
	if not drive_path.is_empty():
		_run_drive(drive_path)
		return
	if level != -2:
		_load_level_later(level)
	if autotest:
		_run_autotest()
	elif not _screenshot_path.is_empty() and not _timed_shots:
		_screenshot_then_quit(1.5)


## Switches to a level once the tree is up. 0 = arena, 1..n = list order.
func _load_level_later(level: int) -> void:
	await get_tree().process_frame
	if level == -3:
		Levels.load_hub()
	elif level < 0:
		Levels.load_title()
	elif level == 0:
		Levels.load_test_arena()
	else:
		Levels.load_level(level - 1)


func _run_drive(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var config = JSON.parse_string(text)
	if config == null or config is not Dictionary:
		print("[drive] FAIL: could not read waypoint file %s" % path)
		get_tree().quit.call_deferred(1)
		return
	await _load_level_later(int(config.get("level", 1)))
	await get_tree().create_timer(0.5).timeout
	var bot := LevelBot.new()
	add_child(bot)
	bot.start(config)
	var result: Array = await bot.finished
	var passed: bool = result[0]
	print("[drive] %s: level %d -- %s" % ["PASS" if passed else "FAIL", int(config.get("level", 1)), result[1]])
	# Crystals: which of the level's four the run earned, and whether the
	# file expected particular hidden ones ("expect_hidden": [0, 1]).
	if Levels.is_in_level():
		var states: Array = Progress.slot_states(Levels.current_index)
		var earned := PackedStringArray()
		for slot in Progress.SLOT_COUNT:
			if states[slot] != "none":
				earned.append(Progress.SLOT_NAMES[slot].to_lower() + ("" if states[slot] == "new" else " (old)"))
		print("[drive] crystals this run: %s" % (", ".join(earned) if not earned.is_empty() else "none"))
		for which in config.get("expect_hidden", []):
			var got: bool = states[Progress.SLOT_HIDDEN_A + int(which)] != "none"
			if not got:
				passed = false
			print("[drive] %s: hidden crystal %d %s" % ["PASS" if got else "FAIL", int(which), "collected" if got else "NOT collected"])
	if not _screenshot_path.is_empty():
		# One picture at the finish (ball dropping into the hill), one of the
		# results screen a second after the wipe to black.
		await _save_screenshot(_screenshot_path)
		await get_tree().create_timer(Levels.DROP_DELAY * 0.5).timeout
		await _save_screenshot(_screenshot_path.get_basename() + "_drop.png")
		await get_tree().create_timer(Levels.DROP_DELAY * 0.5 + Levels.FADE_TIME + Levels.CONTINUE_DELAY + 0.6).timeout
		await _save_screenshot(_screenshot_path.get_basename() + "_results.png")
	if passed and int(config.get("level", 1)) < 0:
		await get_tree().create_timer(Levels.DROP_DELAY + Levels.FADE_TIME + 1.0).timeout
		var where := "the anthill hub" if Levels.is_in_hub() else "level %d" % [Levels.current_index + 1]
		print("[drive] after entering the giant ant hill the game loaded %s" % where)
	elif passed and Levels.is_in_level():
		# Confirm the level system moves on to the next level by itself.
		var before := Levels.current_index
		# Wait for the "press any button" prompt, press it like a player would.
		await get_tree().create_timer(Levels.DROP_DELAY + Levels.FADE_TIME + Levels.CONTINUE_DELAY + 0.5).timeout
		Transition.press_continue()
		if LevelList.is_last_of_world(before):
			# The world-complete card comes next; press through it too.
			await get_tree().create_timer(Levels.CONTINUE_DELAY + 0.5).timeout
			if not _screenshot_path.is_empty():
				await _save_screenshot(_screenshot_path.get_basename() + "_world.png")
			Transition.press_continue()
		await get_tree().create_timer(1.0).timeout
		var now := "the title area" if get_tree().current_scene.scene_file_path == LevelList.TITLE \
				else ("the anthill hub" if Levels.is_in_hub() else "level %d" % [Levels.current_index + 1])
		if Levels.is_in_hub():
			var hub := get_tree().current_scene
			var tunnel = hub.tunnel_for(before) if hub.has_method("tunnel_for") else null
			var player := get_tree().get_first_node_in_group("player") as Node3D
			if tunnel and player:
				var gap: float = player.global_position.distance_to(tunnel.return_transform().origin)
				now += ", %.1f m from tunnel %d's mouth" % [gap, before + 1]
		print("[drive] after completing level %d the game loaded %s" % [before + 1, now])
	get_tree().quit(0 if passed else 1)


## --camera-yaw=DEGREES turns the camera to look in that direction at start
## (0 = north/-Z, 180 = south/+Z). Pair with --camera-pitch and --zoom.
func _aim_camera_later(yaw_degrees: float, pitch_degrees: float) -> void:
	await get_tree().create_timer(0.1).timeout
	for rig in get_tree().get_nodes_in_group("camera_rig"):
		if rig.has_method("aim"):
			rig.aim(deg_to_rad(yaw_degrees), deg_to_rad(pitch_degrees))


func _teleport_later(point: Vector3) -> void:
	await get_tree().create_timer(0.3).timeout
	var player := get_tree().get_first_node_in_group("player") as RigidBody3D
	if player:
		player.global_position = point
		player.linear_velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		for rig in get_tree().get_nodes_in_group("camera_rig"):
			rig.global_position = point


## Saves a numbered screenshot at each time (seconds since start), then quits.
func _timed_shots_later(times: PackedFloat32Array) -> void:
	_timed_shots = true
	var elapsed := 0.0
	var index := 0
	for t in times:
		index += 1
		if t > elapsed:
			await get_tree().create_timer(t - elapsed).timeout
			elapsed = t
		if _screenshot_path.is_empty():
			continue
		await _save_screenshot("%s_%d.png" % [_screenshot_path.get_basename(), index])
	get_tree().quit(0)


func _autoplay(answer: String) -> void:
	while true:
		await get_tree().create_timer(0.5).timeout
		var box := get_tree().root.find_child("DialogueBox", true, false) as DialogueBox
		if box == null or not box.is_showing():
			continue
		if box._choosing:
			_press_action("dialogue_no" if answer == "no" else "jump")
		else:
			_press_action("jump")


func _press_later(action: String, at := 0.5) -> void:
	await get_tree().create_timer(at).timeout
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
	await get_tree().create_timer(1.5).timeout
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
	# A landing only counts as an impact if it's harder than impact_small.
	var landing_speed := sqrt(2.0 * Tuning.gravity * Tuning.jump_height)
	if landing_speed > Tuning.impact_small * 1.15:
		_check("landing counts as an impact", impacts[0] >= 1,
				"impacts=%d (landing at %.1f m/s, impact_small %.1f)" % [impacts[0], landing_speed, Tuning.impact_small])
	elif landing_speed < Tuning.impact_small * 0.85:
		_check("soft landing is not an impact", impacts[0] == 0,
				"impacts=%d (landing at %.1f m/s, impact_small %.1f)" % [impacts[0], landing_speed, Tuning.impact_small])

	# Restart should put the ball back near the start.
	Game.restart_level()
	await get_tree().create_timer(0.8).timeout
	player = get_tree().get_first_node_in_group("player") as PlayerBall
	_check("restart reloads the level", player != null and player.global_position.length() < 3.0)

	# Drop a boulder on one end of the seesaw: the plank should tip around
	# its hinge (the Z axis) and nothing else. (A crate is too light to tip
	# it with the owner's tuning, so the heavy prop is used.)
	var seesaw := get_tree().current_scene.find_child("Seesaw", true, false)
	if seesaw:
		var plank := seesaw.get_node("Plank") as RigidBody3D
		var crate := load("res://src/objects/boulder.tscn").instantiate() as RigidBody3D
		get_tree().current_scene.add_child(crate)
		crate.global_position = seesaw.global_position + Vector3(-2.5, 2.0, 0.0)
		await get_tree().create_timer(1.5).timeout
		var tilt := plank.rotation
		_check("seesaw tips on its hinge", abs(tilt.z) > 0.1 and abs(tilt.x) < 0.05 and abs(tilt.y) < 0.05,
				"rotation=(%.2f, %.2f, %.2f)" % [tilt.x, tilt.y, tilt.z])
	else:
		_check("seesaw present in level", false)
	_finish()


# ----------------------------------------------------------- hub test ----

## Plays the anthill hub by machine and checks its rules. Headless-safe.
##   yes   fall, cutscene, answer Yes: gift received, control back, then
##         locked tunnel blocks, small hole blocks, open tunnel loads level
##         1, finishing it returns to the hub in front of tunnel 1 with no
##         second cutscene
##   no    answer No: jail, game over, back at the title
##   skip  hold Esc/Start: cutscene ends at once as if Yes
func _run_hubtest(mode: String) -> void:
	var hcheck := func(name: String, ok: bool, detail := "") -> void:
		if not ok:
			_failures += 1
		print("[hubtest] %s: %s %s" % ["PASS" if ok else "FAIL", name, detail])
	await get_tree().process_frame
	Levels.load_hub()
	await get_tree().create_timer(0.6).timeout
	var hub := get_tree().current_scene
	hcheck.call("hub scene loaded", Levels.is_in_hub() and hub.has_method("tunnel_for"))
	var player := get_tree().get_first_node_in_group("player") as PlayerBall
	hcheck.call("player exists", player != null)
	if player == null or not Levels.is_in_hub():
		_finish_hubtest()
		return
	hcheck.call("control locked during the fall", Game.control_locked and player.global_position.y > 4.0,
			"locked=%s y=%.1f" % [Game.control_locked, player.global_position.y])
	hcheck.call("cutscene camera is live", get_viewport().get_camera_3d() == hub.cutscene.camera)
	var landed := await _await_signal_or_timeout(hub.arrival_landed, 6.0)
	hcheck.call("hero landed on the cave floor", landed and player.global_position.y < 1.5 and player.global_position.length() < 2.0,
			"at %s" % player.global_position)
	var started := await _wait_until(func(): return Game.cutscene_active, 4.0)
	hcheck.call("opening cutscene started after landing", started)
	var cutscene: CutscenePlayer = hub.cutscene
	var t0 := Time.get_ticks_msec()
	if mode == "skip":
		await get_tree().create_timer(1.0).timeout
		Input.action_press("skip_cutscene")
		await get_tree().create_timer(CutsceneStyle.SKIP_HOLD + 0.3).timeout
		Input.action_release("skip_cutscene")
	# Press through the dialogue like a player: A to complete/advance, and
	# the chosen answer at the question.
	var outcome := [""]
	hub.intro_finished.connect(func(o: String): outcome[0] = o)
	var answered := false
	var guard := 0.0
	while cutscene.is_playing and guard < 120.0 and is_instance_valid(cutscene):
		await get_tree().create_timer(0.35).timeout
		guard += 0.35
		if not is_instance_valid(cutscene) or not Levels.is_in_hub():
			break
		var box: DialogueBox = cutscene.dialogue
		if box._choosing:
			if not answered:
				answered = true
				hcheck.call("choice appeared with two options", box._options.size() == 2)
				_press_action("dialogue_no" if mode == "no" else "jump")
		elif box.is_showing():
			_press_action("jump")
	var seconds := (Time.get_ticks_msec() - t0) / 1000.0
	if mode != "no":
		# is_playing drops before the camera has glided back; the outcome
		# arrives when the hand-over is done.
		await _wait_until(func(): return outcome[0] != "", 5.0)
	match mode:
		"no":
			var at_title := await _wait_until(func(): return get_tree().current_scene != null \
					and get_tree().current_scene.scene_file_path == LevelList.TITLE, 30.0)
			hcheck.call("No: game over returned to the title (main menu)", at_title, "after %.0f s" % seconds)
			hcheck.call("No: the Queen's gift was not received", not Progress.has_queen_item)
			_finish_hubtest()
			return
		"skip":
			hcheck.call("skip: cutscene ended quickly", seconds < 12.0, "%.1f s" % seconds)
			hcheck.call("skip: treated as Yes (gift received, outcome yes)", Progress.has_queen_item and outcome[0] == "yes", "outcome=%s" % outcome[0])
			hcheck.call("skip: the question was never asked", not answered)
			var hole_at: Vector3 = (hub.queen_hole.transform as Transform3D).origin
			hcheck.call("skip: the Queen is back in her hole", hub.queen.global_position.distance_to(hole_at) < 2.0)
		_:
			hcheck.call("Yes: cutscene finished with outcome yes", outcome[0] == "yes", "outcome=%s after %.0f s" % [outcome[0], seconds])
			hcheck.call("Yes: the Queen's gift was received", Progress.has_queen_item)
			var hole_at: Vector3 = (hub.queen_hole.transform as Transform3D).origin
			var home := await _wait_until(func(): return hub.queen.global_position.distance_to(hole_at) < 2.0, 15.0)
			hcheck.call("Yes: the Queen crawled back into her hole", home,
					"%.1f m from the hole" % hub.queen.global_position.distance_to(hole_at))
	await get_tree().create_timer(0.3).timeout
	hcheck.call("control returned to the player", not Game.control_locked and not Game.cutscene_active)
	hcheck.call("game camera is live again", get_viewport().get_camera_3d() != cutscene.camera)
	hcheck.call("intro marked as seen for this session", Progress.hub_intro_seen)
	# Worker ants: at least one is out of its hole by now.
	var out := 0
	for ant in hub.get_node("WorkerAnts").get_children():
		if ant.state != CaveAnt.State.HIDDEN:
			out += 1
	hcheck.call("worker ants come out of the holes", out > 0, "%d of %d out" % [out, hub.get_node("WorkerAnts").get_child_count()])
	if mode == "skip":
		_finish_hubtest()
		return

	# A locked tunnel: push into it for a while, the rubble must hold.
	var locked: TunnelEntrance = hub.tunnel_for(3)
	hcheck.call("tunnel 4 is locked (needs crystals)", locked != null and locked.is_locked(), "needs %d, have %d" % [Progress.crystals_needed(3), Progress.crystals])
	if locked:
		var spot := locked.return_transform().origin
		player.teleport(spot)
		var into := locked.global_transform.basis.z   # local +Z = into the wall
		await _shove(player, into, 8.0, 2.5)
		var depth := locked.to_local(player.global_position).z
		hcheck.call("locked tunnel blocks the ball", Levels.is_in_hub() and depth < 1.0, "reached z=%.2f into the mouth (rubble at 0..2.6)" % depth)

	# Unlock thresholds from the level list: tunnel 4 opens at 5 crystals,
	# tunnel 5 at 8, and a count below each keeps the rubble in place.
	var tunnel5: TunnelEntrance = hub.tunnel_for(4)
	if locked and tunnel5:
		var need4 := Progress.crystals_needed(3)
		var need5 := Progress.crystals_needed(4)
		Progress.debug_set_crystals(need4 - 1)
		await get_tree().process_frame
		hcheck.call("tunnel 4 stays locked one crystal short", locked.is_locked(), "%d crystals" % Progress.crystals)
		Progress.debug_set_crystals(need4)
		await get_tree().create_timer(1.2).timeout
		hcheck.call("tunnel 4 opens at %d crystals" % need4, not locked.is_locked() and not locked._rubble.visible)
		hcheck.call("tunnel 5 still locked at %d crystals" % need4, tunnel5.is_locked())
		Progress.debug_set_crystals(need5 - 1)
		await get_tree().process_frame
		hcheck.call("tunnel 5 stays locked one crystal short", tunnel5.is_locked(), "%d crystals" % Progress.crystals)
		Progress.debug_set_crystals(need5)
		await get_tree().create_timer(1.2).timeout
		hcheck.call("tunnel 5 opens at %d crystals" % need5, not tunnel5.is_locked() and not tunnel5._rubble.visible)
		Progress.debug_set_crystals(0)
		await get_tree().process_frame
		hcheck.call("rubble is back at 0 crystals", locked.is_locked() and tunnel5.is_locked())

	# A small hole: fling the ball at one; it must stay outside the wall.
	var shell: CaveShell = hub.shell
	var hole: Dictionary = {}
	for h in shell.holes:
		if h.t < 0.3 and h != hub.queen_hole:
			hole = h
			break
	if not hole.is_empty():
		var xf: Transform3D = hole.transform
		player.teleport(xf.origin + xf.basis.y * 2.5)
		await _shove(player, -xf.basis.y, 10.0, 1.0)
		var inside := (player.global_position - xf.origin).dot(xf.basis.y)
		var radial := Vector2(player.global_position.x, player.global_position.z).length()
		hcheck.call("ball cannot enter a small hole", inside > 0.3 and radial < shell.floor_radius * 1.15,
				"%.2f m in front of the hole, %.1f m from the middle" % [inside, radial])
	await get_tree().create_timer(0.5).timeout

	# An open tunnel loads its level.
	var open: TunnelEntrance = hub.tunnel_for(0)
	hcheck.call("tunnel 1 is open", open != null and not open.is_locked())
	if open:
		player.teleport(open.return_transform().origin)
		var into := open.global_transform.basis.z
		_shove(player, into, 7.0, 3.0)
		var loaded := await _wait_until(func(): return Levels.current_index == 0 and not Levels.is_in_hub(), 8.0)
		hcheck.call("rolling into tunnel 1 loads level 1", loaded, "level index now %d" % Levels.current_index)
	# Finish that level: it must bring us back in front of tunnel 1, with
	# no second cutscene.
	if Levels.current_index == 0:
		await get_tree().create_timer(1.0).timeout
		Game.complete_level()
		await get_tree().create_timer(Levels.DROP_DELAY + Levels.FADE_TIME + Levels.CONTINUE_DELAY + 0.5).timeout
		Transition.press_continue()
		var back := await _wait_until(func(): return Levels.is_in_hub(), 6.0)
		await get_tree().create_timer(1.5).timeout
		hub = get_tree().current_scene
		player = get_tree().get_first_node_in_group("player") as PlayerBall
		var gap := INF
		if back and player and hub.has_method("tunnel_for"):
			gap = player.global_position.distance_to(hub.tunnel_for(0).return_transform().origin)
		hcheck.call("finishing level 1 returns to the hub in front of tunnel 1", back and gap < 3.0, "%.1f m from the mouth" % gap)
		hcheck.call("no cutscene on the way back", not Game.cutscene_active and not Game.control_locked)
	_finish_hubtest()


func _finish_hubtest() -> void:
	print("[hubtest] %s (%d failures)" % ["ALL PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _press_action(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


## Keeps the ball moving a set way for a while (steering is locked out of
## the test's hands, so it sets the velocity directly each step).
func _shove(player: PlayerBall, direction: Vector3, speed: float, seconds: float) -> void:
	var t := 0.0
	while t < seconds and is_instance_valid(player):
		player.linear_velocity = direction.normalized() * speed + Vector3.UP * minf(player.linear_velocity.y, 0.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


## True once `condition` holds, false after the timeout.
func _wait_until(condition: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if condition.call():
			return true
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	return condition.call()


## Awaits a signal, giving up after the timeout. Returns whether it fired.
func _await_signal_or_timeout(sig: Signal, timeout: float) -> bool:
	var fired := [false]
	var handler := func(): fired[0] = true
	sig.connect(handler, CONNECT_ONE_SHOT)
	var t := 0.0
	while not fired[0] and t < timeout:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	if sig.is_connected(handler):
		sig.disconnect(handler)
	return fired[0]


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
