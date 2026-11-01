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
##   godot -- --hub-from=0
##       The hub as if just back from level 1: no fall, no cutscene, the
##       hero in front of that tunnel. Handy with --teleport for pictures.
##
##   godot --headless -- --eggtest
##       Plays the birthday easter egg by machine (the key, the cell, the
##       button, the party) and prints PASS/FAIL checks. With --screenshot
##       and --shots it saves pictures along the way instead of quitting.
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
	var eggtest := false
	var level := -2          # -2 = leave the main scene alone
	var drive_path := ""
	# The automated runs play without the main and pause menus.
	for arg in OS.get_cmdline_user_args():
		for flag in ["--tests", "--autotest", "--drive=", "--hubtest", "--eggtest"]:
			if arg.begins_with(flag):
				GameMenu.enabled = false
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
		elif arg.begins_with("--hub-from="):
			# --hub-from=0 : the hub as if back from level 1 (no fall, no
			# cutscene): the hero waits in front of that tunnel.
			level = -2
			Levels.load_hub.call_deferred(int(arg.get_slice("=", 1)))
		elif arg.begins_with("--menushots="):
			# Pictures of every menu page (a throwaway user with some progress).
			_menu_shots(arg.get_slice("=", 1))
			return
		elif arg == "--menutest":
			# Plays the main menu, save profiles, progress screen and pause
			# menu by machine (in a throwaway profiles folder).
			_run_menutest()
			return
		elif arg == "--eggtest":
			# Plays the birthday easter egg by machine (key, cell, button,
			# party) and checks each step; combines with --screenshot and
			# --shots to picture it (see _run_eggtest).
			eggtest = true
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
	elif eggtest:
		_run_eggtest()
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


## The birthday easter egg, step by step: the hub without the fall, "Locked"
## at the cell without the key, the bounce pad up through the key, the
## door opening with it, the button's prompt and push, the party (ants out
## of the holes, the Queen in the line, song, banner), the hand-back and
## everyone home. With --screenshot and --shots the pictures are taken on
## the way and that quits instead.
func _run_eggtest() -> void:
	var echeck := func(name: String, ok: bool, detail := "") -> void:
		if not ok:
			_failures += 1
		print("[eggtest] %s: %s %s" % ["PASS" if ok else "FAIL", name, detail])
	await get_tree().process_frame
	Levels.load_hub(0)
	await get_tree().create_timer(0.8).timeout
	var hub := get_tree().current_scene
	var ok_scene := Levels.is_in_hub() and "party" in hub and hub.party != null
	echeck.call("hub loaded with the party set up", ok_scene)
	var player := get_tree().get_first_node_in_group("player") as PlayerBall
	if not ok_scene or player == null:
		_finish_eggtest()
		return
	var party: BirthdayParty = hub.party
	var jail: JailCell = hub.jail
	var hud := hub.find_child("HUD", true, false)
	echeck.call("no cutscene on a return arrival", not Game.control_locked and not Game.cutscene_active)
	echeck.call("the key hangs over the bounce pad, out of jumping reach",
			party.key != null and party.pad != null and party.key.global_position.y - party.pad.global_position.y > Tuning.jump_height + 2.0,
			"key %.1f m above the pad" % (party.key.global_position.y - party.pad.global_position.y if party.key else 0.0))
	echeck.call("the key is tiny and yellow, no glow", MysteryKey.LENGTH <= 0.15 and party.key.find_children("*", "OmniLight3D").is_empty())
	echeck.call("%d dancers wait in the holes" % BirthdayParty.DANCERS, party.dancers.size() == BirthdayParty.DANCERS)

	# 1. At the cell without the key: "Locked", and the door stays shut.
	player.teleport(jail.approach_point() + Vector3.UP * 0.2)
	await get_tree().create_timer(0.7).timeout
	echeck.call("at the cell without the key the HUD says Locked", hud.prompt_text() == "Locked", "prompt='%s'" % hud.prompt_text())
	echeck.call("the door stays shut", not jail.is_open())
	var into_cell := jail.global_transform.basis.z   # local +Z = into the wall
	await _shove(player, into_cell, 5.0, 2.0)
	var shut_depth := jail.to_local(player.global_position).z
	echeck.call("the shut door blocks the ball", shut_depth < JailCell.BAR_Z, "reached z=%.2f (bars at %.2f)" % [shut_depth, JailCell.BAR_Z])
	player.teleport(Vector3(0.0, 0.6, 0.0))
	await get_tree().create_timer(0.5).timeout
	echeck.call("the prompt goes away when you leave", hud.prompt_text().is_empty())

	# 2. Drop onto the bounce pad: it throws the ball up through the key.
	player.teleport(party.pad.global_position + Vector3.UP * 1.2)
	var found := await _wait_until(func(): return Progress.has_mystery_key, 5.0)
	echeck.call("bouncing on the pad finds the key", found)
	echeck.call("\"You found a mysterious key\" appears", hud.popup_text() == "You found a mysterious key", "popup='%s'" % hud.popup_text())
	await get_tree().create_timer(2.5).timeout   # let the ball come down

	# 3. Back at the cell with the key: the door opens.
	player.teleport(jail.approach_point() + Vector3.UP * 0.2)
	var opened := await _wait_until(func(): return jail.is_open(), 3.0)
	echeck.call("with the key the cell door opens", opened and Progress.jail_unlocked)
	await get_tree().create_timer(1.0).timeout
	echeck.call("no Locked prompt once it's open", hud.prompt_text() != "Locked")

	# 4. Roll in through the open door (no teleport: the doorway must be
	# clear), up to the button: the prompt, then the push.
	player.teleport(jail.approach_point() + Vector3.UP * 0.2)
	await get_tree().physics_frame
	var target := jail.to_global(Vector3(0.9, 0.5, 3.0))
	var t_roll := 0.0
	while t_roll < 4.0 and player.global_position.distance_to(target) > 0.4:
		var to := target - player.global_position
		to.y = 0.0
		player.linear_velocity = to.normalized() * 4.0 + Vector3.UP * minf(player.linear_velocity.y, 0.0)
		await get_tree().physics_frame
		t_roll += get_physics_process_delta_time()
	player.linear_velocity = Vector3.ZERO
	var rolled_depth := jail.to_local(player.global_position).z
	echeck.call("the ball rolls in through the open door", rolled_depth > 2.0, "reached z=%.2f into the cell" % rolled_depth)
	await get_tree().create_timer(0.7).timeout
	echeck.call("near the button the HUD prompts a push", hud.prompt_text().begins_with("Push the button"), "prompt='%s'" % hud.prompt_text())
	var t0 := Time.get_ticks_msec()
	_press_action("jump")
	var started := await _wait_until(func(): return party.is_playing and Game.cutscene_active, 2.0)
	echeck.call("pushing the button starts the party (controls locked)", started and Game.control_locked)
	echeck.call("cutscene camera is live", get_viewport().get_camera_3d() == hub.cutscene.camera)
	if not started:
		_finish_eggtest()
		return
	# Everyone out of the holes and the band playing.
	var out_count := func() -> int:
		var n := 0
		for ant in party.dancers:
			if ant.dancing or ant.state != CaveAnt.State.HIDDEN:
				n += 1
		return n
	print("[eggtest] (the party started %.1f s after launch)" % (Time.get_ticks_msec() / 1000.0))
	var came_out := await _wait_until(func(): return out_count.call() >= BirthdayParty.DANCERS, 12.0)
	echeck.call("the ants come out of the holes", came_out, "%d of %d out" % [out_count.call(), BirthdayParty.DANCERS])
	var band := await _wait_until(func(): return party.song_playing(), 20.0)
	echeck.call("the band is playing", band)
	echeck.call("the music waited until every dancer was in place", party.line_was_ready)
	var hero_out := Vector2(player.global_position.x, player.global_position.z).length()
	echeck.call("the hero watches from just outside the spotlight", hero_out > 7.0 and hero_out < 9.5, "%.1f m from the middle" % hero_out)
	var beam := hub.find_child("LightBeam", true, false) as MeshInstance3D
	var beam_alpha := (beam.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color.a if beam else 0.0
	echeck.call("the spotlight beam stays on during the dance", beam_alpha > 0.01, "beam alpha %.3f" % beam_alpha)
	var dancing := await _wait_until(func():
		var n := 0
		for ant in party.dancers:
			if ant.dancing:
				n += 1
		return n >= BirthdayParty.DANCERS - 1 and hub.queen.dancing, 14.0)
	var line_count := 0
	for ant in party.dancers:
		if ant.dancing:
			line_count += 1
	echeck.call("the line dances, the Queen in the middle of it", dancing, "%d dancing, queen=%s" % [line_count, hub.queen.dancing])
	var banner := await _wait_until(func(): return party.banner_visible(), 8.0)
	echeck.call("\"Happy Birthday, Martha!\" is on the screen", banner and party._banner_label.text == "Happy Birthday, Martha!")
	# The dance floor is the middle of the cave, in the daylight spotlight.
	var middle: Vector3 = hub.queen.global_position
	for ant in party.dancers:
		middle += ant.global_position
	middle /= party.dancers.size() + 1
	echeck.call("the line dances in the spotlight in the middle", Vector2(middle.x, middle.z).length() < 1.5,
			"line centred %.1f m from the middle" % Vector2(middle.x, middle.z).length())
	var cheering := 0
	for ant in party.spectators:
		if ant.cheering:
			cheering += 1
	echeck.call("a crowd stands round the floor cheering", cheering >= BirthdayParty.SPECTATORS - 2,
			"%d of %d up on their back legs" % [cheering, BirthdayParty.SPECTATORS])
	var showers := 0
	for particles in party._confetti:
		if is_instance_valid(particles) and particles.emitting:
			showers += 1
	echeck.call("confetti is falling", showers >= 2, "%d showers" % showers)
	# The camera sits behind the hero, looking out over them.
	var cam: Camera3D = hub.cutscene.camera
	var hero := player.global_position
	var to_hero := hero - cam.global_position
	var forward := -cam.global_transform.basis.z
	var behind := to_hero.length() < 5.0 and forward.dot(Vector3(to_hero.x, 0.0, to_hero.z).normalized()) > 0.8
	echeck.call("the camera is behind the hero, watching with them", behind,
			"%.1f m from the hero, facing dot %.2f" % [to_hero.length(), forward.dot(Vector3(to_hero.x, 0.0, to_hero.z).normalized())])
	# The whole thing ends on its own and hands back.
	# All through the dance: the Queen never walks into her neighbours.
	var closest := INF
	var finale_beat := float(BirthdaySong.VERSES * CaveAnt.DANCE_COUNTS) + 1.0
	while party.is_playing and party._dance_beat() < finale_beat:
		for ant in party.dancers:
			if ant.dancing and hub.queen.dancing:
				var gap: Vector3 = ant.global_position - hub.queen.global_position
				closest = minf(closest, Vector2(gap.x, gap.z).length())
		await get_tree().process_frame
	echeck.call("the Queen keeps clear of the other dancers", closest > 1.3, "closest %.2f m" % closest)
	# The finale: the routine has come home to every ant's spot and the line
	# holds the pose (reared up) while the last chord rings.
	var worst := 0.0
	var reared := 0
	var line: Array = party.dancers.duplicate()
	line.append(hub.queen)
	for ant in line:
		if ant.dancing:
			worst = maxf(worst, ant.global_position.distance_to(ant._dance_home.origin))
			if ant._rear > 0.5:
				reared += 1
	echeck.call("the song ends with the line on its spots, holding the finale", worst < 0.05 and reared >= line.size() - 1,
			"furthest %.2f m off its spot, %d of %d reared up" % [worst, reared, line.size()])
	var done := await _wait_until(func(): return not party.is_playing, 50.0)
	var seconds := (Time.get_ticks_msec() - t0) / 1000.0
	echeck.call("the party ends on its own", done, "%.0f s" % seconds)
	echeck.call("control returned to the player", not Game.control_locked and not Game.cutscene_active)
	echeck.call("game camera is live again", get_viewport().get_camera_3d() != hub.cutscene.camera)
	echeck.call("the hero is outside the cell, in the physics", not player.freeze and jail.to_local(player.global_position).z < -1.0)
	var home := await _wait_until(func():
		for ant in party.dancers:
			if ant.state != CaveAnt.State.HIDDEN:
				return false
		for ant in party.spectators:
			if ant.state != CaveAnt.State.HIDDEN:
				return false
		return hub.queen.state == CaveAnt.State.HIDDEN, 14.0)
	echeck.call("everyone is back in the holes", home)
	echeck.call("the button can be pushed again", party.button.armed)
	echeck.call("confetti keeps falling all over the nest afterwards",
			party.nest_confetti != null and is_instance_valid(party.nest_confetti) and party.nest_confetti.emitting)
	# Leave and come back: the nest is still full of confetti.
	Levels.load_hub(0)
	await get_tree().create_timer(1.0).timeout
	var again = get_tree().current_scene
	var still: bool = Levels.is_in_hub() and again.party.nest_confetti != null and again.party.nest_confetti.emitting
	echeck.call("the confetti is still there after leaving and coming back", still)
	_finish_eggtest()


## The menus and save profiles, by machine. Uses its own profiles folder
## and settings file, so real saves are never touched.
func _run_menutest() -> void:
	var mcheck := func(name: String, ok: bool, detail := "") -> void:
		if not ok:
			_failures += 1
		print("[menutest] %s: %s %s" % ["PASS" if ok else "FAIL", name, detail])
	Saves.folder = "user://menutest_profiles"
	Saves.settings_path = "user://menutest_settings.cfg"
	_clear_test_saves()
	await get_tree().process_frame
	Levels.load_title()
	await get_tree().create_timer(1.0).timeout
	mcheck.call("the main menu opens on the title meadow", GameMenu.mode == "main" and GameMenu.page == "main")
	mcheck.call("the ball is held still while the menu is up", Game.control_locked)
	var empty := true
	for slot in range(1, Saves.SLOTS + 1):
		empty = empty and Saves.info(slot).is_empty()
	mcheck.call("four empty profile slots to start", empty and Saves.SLOTS == 4)

	# Play with no user picked goes to Select User; slot 2 is empty, so it
	# asks for a name.
	GameMenu._on_play()
	mcheck.call("Play with no user opens Select User", GameMenu.page == "users")
	GameMenu._pick_slot(2)
	mcheck.call("an empty slot asks for a name", GameMenu.page == "name" and GameMenu._name_edit != null)
	GameMenu._name_edit.text = "  Martha  "
	GameMenu._confirm_name()
	mcheck.call("the new user is created and picked", Saves.active == 2 and Saves.active_name == "Martha" and Saves.exists(2),
			"active=%d name='%s'" % [Saves.active, Saves.active_name])
	mcheck.call("back on the main menu, playing as Martha", GameMenu.page == "main" and _menu_text().contains("Martha"))

	# Progress saves by itself.
	Progress.collect_hidden(0, 0)
	Progress.record_finish(1, 50.0, 62.0)
	Progress.set_flag("has_mystery_key")
	Cosmetics.set_all({"head": 3, "ball": 2})
	await get_tree().process_frame
	await get_tree().process_frame
	var info := Saves.info(2)
	mcheck.call("progress saved by itself", int(info.get("crystals", 0)) == 3, "%s crystals in the file" % info.get("crystals", "?"))

	# A new session: forget everything, pick Martha again, all of it is back.
	Saves.active = 0
	Progress.reset()
	Cosmetics.set_all({})
	mcheck.call("(forgotten)", Progress.crystals == 0 and not Progress.has_mystery_key)
	Saves.select(2)
	mcheck.call("picking the user brings the progress back", Progress.crystals == 3 and Progress.has_mystery_key \
			and Progress.has_crystal(0, Progress.SLOT_HIDDEN_A) and is_equal_approx(float(Progress.best_times.get(1, 0.0)), 50.0),
			"%d crystals, key %s, best %s" % [Progress.crystals, Progress.has_mystery_key, Progress.best_times])
	mcheck.call("and the user's ant and ball look", int(Cosmetics.choices.head) == 3 and int(Cosmetics.choices.ball) == 2)

	# The progress screen: ??? for what isn't found, the real thing for what is.
	GameMenu._show("progress")
	var text := _menu_text()
	mcheck.call("progress shows what was found and where", text.contains("Hidden crystal: In the shortcut tunnel") \
			and text.contains("Mysterious Key") and text.contains("best 0:50"))
	var unknown := text.count("???")
	mcheck.call("everything not found yet is ???", unknown >= 15 and not text.contains("Crystal Pouch") \
			and not text.contains("jail cell"), "%d ??? entries" % unknown)
	mcheck.call("unseen cutscenes can't be watched", not text.contains("Watch"))
	Progress.set_flag("hub_intro_seen")
	GameMenu._show("progress", false)
	mcheck.call("a seen cutscene gets a Watch button", _menu_text().contains("The Queen's Request") and _menu_text().contains("Watch"))
	GameMenu.back()

	# Rename, a second user, delete.
	Saves.rename(2, "Marty")
	mcheck.call("rename", Saves.info(2).get("name", "") == "Marty" and Saves.active_name == "Marty")
	Saves.create(3, "")
	mcheck.call("a blank name becomes 'Player 3'", Saves.info(3).get("name", "") == "Player 3")
	mcheck.call("a new user starts from nothing", Progress.crystals == 0 and not Progress.has_mystery_key)
	Saves.delete(3)
	mcheck.call("delete removes the user", not Saves.exists(3) and Saves.active == 0)
	Saves.select(2)
	mcheck.call("the other user is untouched", Progress.crystals == 3)

	# Play starts the meadow.
	GameMenu._show("main", false)
	GameMenu._on_play()
	await get_tree().process_frame
	var meadow := get_tree().current_scene
	mcheck.call("Play closes the menu and starts the game", GameMenu.mode == "" and not Game.control_locked and meadow._started)

	# Pause in the meadow: Controls page, back, resume.
	_press_action("pause")
	await get_tree().process_frame
	mcheck.call("Esc / Start pauses the game", GameMenu.mode == "pause" and get_tree().paused)
	mcheck.call("no Restart Level outside a level", not _menu_text().contains("Restart Level"))
	GameMenu._show("controls")
	mcheck.call("the Controls page lists the keys", _menu_text().contains("Jump") and _menu_text().contains("Esc"))
	_press_action("ui_cancel")
	await get_tree().process_frame
	mcheck.call("Esc goes back a page", GameMenu.page == "pause")
	_press_action("pause")
	await get_tree().process_frame
	mcheck.call("Esc again resumes", GameMenu.mode == "" and not get_tree().paused)

	# Pause in a level: Restart Level restarts it.
	Levels.load_level(0)
	await get_tree().create_timer(1.0).timeout
	var player := get_tree().get_first_node_in_group("player") as PlayerBall
	player.teleport(player.global_position + Vector3(0.0, 0.5, -6.0))
	GameMenu.open_pause()
	mcheck.call("in a level the pause menu has Restart Level", _menu_text().contains("Restart Level") and _menu_text().contains("Back to the Anthill"))
	GameMenu._page_button("Restart Level").pressed.emit()
	await get_tree().create_timer(1.0).timeout
	player = get_tree().get_first_node_in_group("player") as PlayerBall
	mcheck.call("Restart Level reloads the level, unpaused", Levels.current_index == 0 and not get_tree().paused and GameMenu.mode == "")

	# Main Menu from the pause menu goes back to the title with its menu.
	GameMenu.open_pause()
	GameMenu._page_button("Main Menu").pressed.emit()
	await get_tree().create_timer(1.5).timeout
	mcheck.call("Main Menu returns to the title's main menu", get_tree().current_scene.scene_file_path == LevelList.TITLE \
			and GameMenu.mode == "main")

	# Watching a cutscene again from the progress screen.
	Progress.set_flag("birthday_party_done")
	GameMenu.watch("party")
	var party_on := await _wait_until(func():
		var hub = get_tree().current_scene
		return Levels.is_in_hub() and hub.party != null and hub.party.is_playing, 6.0)
	mcheck.call("Watch plays the birthday party again", party_on)
	Saves.save_now()
	var last := ConfigFile.new()
	last.load(Saves.settings_path)
	mcheck.call("the last user is remembered for next time", int(last.get_value("profiles", "last", 0)) == 2)
	Saves.active = 0   # or quitting saves it again into the test folder
	_clear_test_saves()
	print("[menutest] %s (%d failures)" % ["ALL PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _menu_shots(base: String) -> void:
	await get_tree().process_frame
	Saves.folder = "user://menutest_profiles"
	Saves.settings_path = "user://menutest_settings.cfg"
	_clear_test_saves()
	Saves.create(1, "Martha")
	Progress.collect_hidden(0, 0)
	Progress.record_finish(0, 71.4, 85.0)
	Progress.record_finish(1, 66.0, 62.0)
	Progress.give_queen_item()
	Progress.set_flag("hub_intro_seen")
	Progress.set_flag("has_mystery_key")
	Saves.create(3, "Ryan")
	Saves.select(1)
	Levels.load_title()
	await get_tree().create_timer(2.5).timeout
	var shots := 0
	for page in ["main", "users", "progress", "name"]:
		if page == "name":
			GameMenu._edit_slot = 2
			GameMenu._renaming = false
		GameMenu._show(page)
		await get_tree().create_timer(0.5).timeout
		shots += 1
		await _save_screenshot("%s_%d_%s.png" % [base.get_basename(), shots, page])
	GameMenu._show("main", false)
	GameMenu._on_play()
	Levels.load_level(1)
	await get_tree().create_timer(2.0).timeout
	GameMenu.open_pause()
	for page in ["pause", "controls"]:
		GameMenu._show(page)
		await get_tree().create_timer(0.5).timeout
		shots += 1
		await _save_screenshot("%s_%d_%s.png" % [base.get_basename(), shots, page])
	Saves.active = 0
	_clear_test_saves()
	get_tree().quit(0)


func _clear_test_saves() -> void:
	var dir := DirAccess.open(Saves.folder)
	if dir:
		for file in dir.get_files():
			dir.remove(file)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.folder))
	if FileAccess.file_exists(Saves.settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.settings_path))


## All the text on the menu's current page.
func _menu_text() -> String:
	var parts := PackedStringArray()
	for node in GameMenu._box.find_children("*", "", true, false):
		if node is Label or node is Button:
			parts.append(node.text)
	return "\n".join(parts)


func _finish_eggtest() -> void:
	print("[eggtest] %s (%d failures)" % ["ALL PASSED" if _failures == 0 else "FAILED", _failures])
	if not _timed_shots:
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
