class_name CutscenePlayer
extends Node
## CUTSCENE PLAYER -- plays a cutscene described in a JSON file: camera
## shots, dialogue lines with typed text and babble voices, a yes/no
## choice, actor actions (the Queen crawling out of her hole), an item
## hand-over, the jail, game over. Reusable: a scene adds one of these,
## registers its actors by name, and calls play(path).
##
##   var cutscene := CutscenePlayer.new()
##   add_child(cutscene)
##   cutscene.actors = {"hero": ant_rider, "queen": queen, "cave": shell, ...}
##   cutscene.scene_handler = self        # gets "scene" steps
##   var outcome: String = await cutscene.play("res://cutscenes/hub_intro.json")
##
## While it plays: the player can't steer (Game.control_locked), restart
## and level keys are off (Game.cutscene_active), A / Space completes a
## line or moves on, and holding Esc / Start for CutsceneStyle.SKIP_HOLD
## seconds jumps to the file's "skip_to" section.
##
## THE FILE (see cutscenes/hub_intro.json for a full example):
##   "characters": path of the characters file (names, voices, framings)
##   "start": the section to begin with; "skip_to": the section a skip runs
##   "sections": {name: [step, step, ...]}
## STEPS ("do"):
##   camera    target, shot (a framing name) or inline numbers, move (s),
##             front_toward (actor the target faces), track / follow
##   wait      seconds
##   line      speaker, text, camera (actor id or "none"), shot, gesture
##   choice    speaker, options [{text, input, keyboard, controller, goto}]
##   actor     actor, action, ... -> actor.cutscene_action(action, step, self)
##   scene     action, ...        -> scene_handler.cutscene_action(...)
##   give_item from, to, item, silent
##   game_over target             (iris wipe, "Game Over", back to the title)
##   goto      section
##   end       outcome
## FRAMINGS: distance, height, yaw (degrees from the target's front),
## look_height, optional y (absolute camera height), fov, track (keep
## aiming at a moving target), follow (keep the whole framing on a moving
## target). Defaults in CutsceneStyle.SHOT_DEFAULTS; per character in the
## characters file under "shots".

## The cutscene ended; outcome is the end step's "outcome" ("yes", "no",
## "skipped"...).
signal finished(outcome: String)

## Actor names -> Node3D, Vector3 (a spot) or a hole Dictionary.
var actors := {}
## Gets "scene" steps (cutscene_action(action, step, player)).
var scene_handler: Node
var camera: Camera3D
var dialogue: DialogueBox
var outcome := ""
var is_playing := false

const DEFAULT_CHARACTERS := "res://cutscenes/characters.json"
var _characters := {}
var _characters_path := ""
var _data := {}
var _run := 0
var _tweens: Array[Tween] = []
var _skip_hold := 0.0
var _skip_section := ""
var _skipping := false
var _track_target = null
var _track_params := {}
var _track_mode := ""
var _move_tween: Tween
var _previous_camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "CutsceneCamera"
	camera.fov = CutsceneStyle.CAMERA_FOV
	add_child(camera)
	dialogue = DialogueBox.new()
	dialogue.name = "DialogueBox"
	add_child(dialogue)
	# Framings and voices are wanted before play() too (the hub's arrival
	# shot), so load the default characters file right away.
	_load_characters(DEFAULT_CHARACTERS)


# ----------------------------------------------------------- playing ----

## Plays the file and returns its outcome.
func play(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null or parsed is not Dictionary:
		push_error("Cutscene: could not read %s" % path)
		return ""
	_data = parsed
	var characters_path := str(_data.get("characters", DEFAULT_CHARACTERS))
	if characters_path != _characters_path:
		_load_characters(characters_path)
	outcome = ""
	is_playing = true
	_skipping = false
	_skip_section = str(_data.get("skip_to", ""))
	Game.cutscene_active = true
	Game.control_locked = true
	take_camera()
	_run += 1
	var my_run := _run
	await _run_section(str(_data.get("start", "start")), my_run)
	return outcome


func _load_characters(path: String) -> void:
	_characters_path = path
	for id in _characters:
		var voice: VoiceSynth = _characters[id].voice
		if voice:
			voice.queue_free()
	_characters.clear()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		push_error("Cutscene: could not read characters file %s" % path)
		return
	for id in parsed:
		if parsed[id] is not Dictionary:
			continue   # notes such as "_about"
		var entry: Dictionary = parsed[id]
		var voice := VoiceSynth.new(entry.get("voice", {}))
		voice.name = "Voice_%s" % id
		add_child(voice)
		_characters[id] = {
			"name": str(entry.get("name", id)),
			"type_speed": float(entry.get("type_speed", CutsceneStyle.TYPE_SPEED)),
			"voice": voice,
			"shots": entry.get("shots", {}),
		}


func _run_section(section: String, my_run: int) -> void:
	var steps: Array = (_data.get("sections", {}) as Dictionary).get(section, [])
	if steps.is_empty():
		push_warning("Cutscene: section '%s' is empty or missing" % section)
	for step in steps:
		if my_run != _run:
			return
		var next: String = await _step(step, my_run)
		if my_run != _run:
			return
		if next == "END":
			await _finish(my_run)
			return
		if not next.is_empty():
			await _run_section(next, my_run)
			return
	await _finish(my_run)


## Returns "" to carry on, a section name to jump, or "END".
func _step(step: Dictionary, my_run: int) -> String:
	var kind := str(step.get("do", ""))
	match kind:
		"camera":
			var target = resolve(str(step.get("target", "")))
			var params := shot_params(str(step.get("target", "")), str(step.get("shot", "face")), step)
			var move := float(step.get("move", CutsceneStyle.CAMERA_MOVE))
			if step.get("await", true):
				await shot(target, params, move)
			else:
				shot(target, params, move)
		"wait":
			await get_tree().create_timer(float(step.get("seconds", 1.0))).timeout
		"line":
			await _line(step, my_run)
		"choice":
			var speaker := str(step.get("speaker", ""))
			if step.has("camera") and str(step.camera) != "none":
				await shot(resolve(str(step.camera)), shot_params(str(step.camera), str(step.get("shot", "face")), step),
						float(step.get("move", CutsceneStyle.CAMERA_MOVE)))
				if my_run != _run:
					return ""
			var options: Array = step.get("options", [])
			var picked: int = await dialogue.choose(options, _character_name(speaker))
			if picked < 0 or my_run != _run:
				return ""
			dialogue.hide_box()
			return str(options[picked].get("goto", ""))
		"actor":
			dialogue.hide_box()
			var node = resolve(str(step.get("actor", "")))
			if node and node.has_method("cutscene_action"):
				await node.cutscene_action(str(step.get("action", "")), step, self)
			else:
				push_warning("Cutscene: actor '%s' can't do '%s'" % [step.get("actor", ""), step.get("action", "")])
		"scene":
			dialogue.hide_box()
			if scene_handler and scene_handler.has_method("cutscene_action"):
				await scene_handler.cutscene_action(str(step.get("action", "")), step, self)
		"give_item":
			dialogue.hide_box()
			await _give_item(step, my_run)
		"game_over":
			await _game_over(step)
			return "END"
		"goto":
			return str(step.get("section", ""))
		"end":
			if step.has("outcome"):
				outcome = str(step.outcome)
			return "END"
		_:
			push_warning("Cutscene: unknown step '%s'" % kind)
	return ""


func _line(step: Dictionary, my_run: int) -> void:
	var speaker := str(step.get("speaker", ""))
	var camera_target := str(step.get("camera", speaker))
	if camera_target != "none" and not camera_target.is_empty():
		await shot(resolve(camera_target), shot_params(camera_target, str(step.get("shot", "face")), step),
				float(step.get("move", CutsceneStyle.CAMERA_MOVE)))
		if my_run != _run:
			return
	var node = resolve(speaker)
	if step.has("gesture") and node and node.has_method("play_gesture"):
		node.play_gesture(str(step.gesture))
	if node and node.has_method("nod"):
		node.nod()
	var ch: Dictionary = _characters.get(speaker, {})
	await dialogue.say(_character_name(speaker), str(step.get("text", "")), ch.get("voice"), float(ch.get("type_speed", 0.0)))


func _character_name(id: String) -> String:
	return str(_characters.get(id, {}).get("name", id))


func _finish(my_run: int) -> void:
	if my_run != _run or not is_inside_tree():
		return
	is_playing = false
	dialogue.hide_box()
	_track_mode = ""
	await release_camera()
	if my_run != _run:
		return
	Game.cutscene_active = false
	Game.control_locked = false
	finished.emit(outcome)


# ----------------------------------------------------------- skipping ----

func _process(delta: float) -> void:
	if is_playing and not _skipping and not _skip_section.is_empty() and Input.is_action_pressed("skip_cutscene"):
		_skip_hold += delta
		dialogue.set_skip_progress(_skip_hold / CutsceneStyle.SKIP_HOLD)
		if _skip_hold >= CutsceneStyle.SKIP_HOLD:
			_skip()
	elif _skip_hold > 0.0:
		_skip_hold = 0.0
		dialogue.set_skip_progress(0.0)
	_track(delta)


## Drops the current section and plays the skip section instead.
func _skip() -> void:
	_skipping = true
	_skip_hold = 0.0
	dialogue.set_skip_progress(0.0)
	_run += 1
	var my_run := _run
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	dialogue.cancel()
	_track_mode = ""
	outcome = "skipped"
	await _run_section(_skip_section, my_run)


# ------------------------------------------------------------- camera ----

## Takes over from whatever camera is current, starting from its view so
## there is no jump.
func take_camera() -> void:
	var current := get_viewport().get_camera_3d()
	if current and current != camera:
		_previous_camera = current
		camera.global_transform = current.global_transform
		camera.fov = current.fov
	camera.current = true


## Glides back to the game camera and hands over.
func release_camera() -> void:
	_track_mode = ""
	if _previous_camera and is_instance_valid(_previous_camera):
		await get_tree().process_frame
		var tween := create_tween().set_parallel(true)
		tween.tween_property(camera, "global_transform", _previous_camera.global_transform, CutsceneStyle.CAMERA_RELEASE) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(camera, "fov", _previous_camera.fov, CutsceneStyle.CAMERA_RELEASE)
		await tween.finished
		if is_instance_valid(_previous_camera):
			_previous_camera.current = true
	camera.current = false


## The framing for a target: the named shot from its character entry (or
## the defaults), with any numbers in `overrides` on top.
func shot_params(target_id: String, shot_name: String, overrides: Dictionary = {}) -> Dictionary:
	var params: Dictionary = CutsceneStyle.SHOT_DEFAULTS.get(shot_name, CutsceneStyle.SHOT_DEFAULTS.face).duplicate()
	var ch: Dictionary = _characters.get(target_id, {})
	var own: Dictionary = (ch.get("shots", {}) as Dictionary).get(shot_name, {})
	for key in own:
		params[key] = own[key]
	for key in ["distance", "height", "yaw", "look_height", "y", "fov", "track", "follow", "front_toward"]:
		if overrides.has(key):
			params[key] = overrides[key]
	return params


## Moves the camera to frame `target` (a node, point or hole) over
## move_time seconds (0 = cut). Awaitable.
func shot(target, params: Dictionary, move_time: float) -> void:
	var xf := _shot_transform(target, params)
	var fov := float(params.get("fov", CutsceneStyle.CAMERA_FOV))
	_track_target = target
	_track_params = params
	_track_mode = "follow" if params.get("follow", false) else ("aim" if params.get("track", false) else "")
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	if move_time <= 0.0:
		camera.global_transform = xf
		camera.fov = fov
		return
	_move_tween = create_tween().set_parallel(true)
	_tweens.append(_move_tween)
	_move_tween.tween_property(camera, "global_transform", xf, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(camera, "fov", fov, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _move_tween.finished


func _shot_transform(target, p: Dictionary) -> Transform3D:
	var origin := position_of(target)
	var front := _front_of(target, p)
	var dir := front.rotated(Vector3.UP, deg_to_rad(float(p.get("yaw", 0.0))))
	var cam_pos := origin + dir * float(p.get("distance", 2.0)) + Vector3.UP * float(p.get("height", 0.5))
	if p.has("y"):
		cam_pos.y = float(p.y)
	var look := origin + Vector3.UP * float(p.get("look_height", 0.3))
	var forward := look - cam_pos
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	var up := Vector3.UP
	if absf(forward.normalized().dot(up)) > 0.98:
		up = Vector3.BACK
	return Transform3D(Basis.looking_at(forward.normalized(), up), cam_pos)


## Which way the target faces, flat: toward another actor if asked, else
## the node's own -Z.
func _front_of(target, p: Dictionary) -> Vector3:
	var front := Vector3.FORWARD
	if p.has("front_toward"):
		front = position_of(resolve(str(p.front_toward))) - position_of(target)
	elif target is Node3D:
		front = -(target as Node3D).global_transform.basis.z
	elif target is Dictionary and target.has("transform"):
		front = (target.transform as Transform3D).basis.y   # a hole: out of the wall
	front.y = 0.0
	return front.normalized() if front.length_squared() > 0.0001 else Vector3.FORWARD


var _shake := 0.0

## A quick decaying shake of the cutscene camera (landings, slams).
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _physics_process(delta: float) -> void:
	if _shake < 0.001:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		return
	camera.h_offset = randf_range(-_shake, _shake)
	camera.v_offset = randf_range(-_shake, _shake)
	_shake *= exp(-delta * Tuning.shake_decay)


## Keeps a tracking or following shot on its target each frame (not while
## a move is in progress).
func _track(delta: float) -> void:
	if _track_mode.is_empty() or _track_target == null:
		return
	if _move_tween and _move_tween.is_valid() and _move_tween.is_running():
		return
	if _track_target is Object and not is_instance_valid(_track_target):
		_track_mode = ""
		return
	var look := position_of(_track_target) + Vector3.UP * float(_track_params.get("look_height", 0.3))
	if _track_mode == "follow":
		var want := _shot_transform(_track_target, _track_params)
		camera.global_position = camera.global_position.lerp(want.origin, 1.0 - exp(-delta * 4.0))
	if (look - camera.global_position).length_squared() > 0.0001:
		camera.look_at(look, Vector3.UP)


# ------------------------------------------------------------ helpers ----

## An actor by name (node, point or hole), or null.
func resolve(name: String):
	return actors.get(name)


## Where something is: a node's position, a point, or a hole's mouth.
func position_of(thing) -> Vector3:
	if thing is Node3D:
		return (thing as Node3D).global_position
	if thing is Vector3:
		return thing
	if thing is Dictionary and thing.has("transform"):
		return (thing.transform as Transform3D).origin
	return Vector3.ZERO


## A small glowing thing floats from one actor to the other, then a
## "Received" popup. Progress remembers the gift.
func _give_item(step: Dictionary, my_run: int) -> void:
	var item_name := str(step.get("item", "a gift"))
	Progress.give_queen_item()
	if step.get("silent", false):
		return
	var from := position_of(resolve(str(step.get("from", "")))) + Vector3.UP * 0.6
	var to := position_of(resolve(str(step.get("to", "")))) + Vector3.UP * 0.25
	var orb := _make_orb()
	get_tree().current_scene.add_child(orb)
	orb.global_position = from
	orb.scale = Vector3.ONE * 0.1
	var tween := create_tween()
	_tweens.append(tween)
	tween.tween_property(orb, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(t: float):
		var arc := Vector3.UP * sin(t * PI) * 0.8
		orb.global_position = from.lerp(to, t) + arc
		orb.rotation.y = t * TAU * 2.0,
		0.0, 1.0, CutsceneStyle.ITEM_FLOAT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(orb, "scale", Vector3.ONE * 0.05, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		Sounds.ui("confirm")
		Effects.impact(Tuning.impact_small, Vector3.UP, to)
		orb.queue_free())
	await tween.finished
	if my_run != _run:
		return
	dialogue.show_popup("Received: %s" % item_name, CutsceneStyle.ITEM_POPUP_TIME)
	await get_tree().create_timer(CutsceneStyle.ITEM_POPUP_TIME * 0.8).timeout


func _make_orb() -> Node3D:
	var orb := Node3D.new()
	orb.name = "GiftOrb"
	var mesh := SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.28
	mesh.radial_segments = 10
	mesh.rings = 5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.95, 0.7)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.85, 0.4)
	material.emission_energy_multiplier = 2.5
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	orb.add_child(instance)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.5)
	light.light_energy = 1.5
	light.omni_range = 4.0
	light.shadow_enabled = false
	orb.add_child(light)
	return orb


## The iris closes on the hero, "Game Over", then the title (main menu).
func _game_over(step: Dictionary) -> void:
	var hero = resolve(str(step.get("target", "hero")))
	var center := camera.unproject_position(position_of(hero) + Vector3.UP * 0.3)
	dialogue.hide_box()
	is_playing = false
	await Transition.game_over(center)
	_run += 1   # nothing after this belongs to the cutscene any more
	Levels.load_title()
