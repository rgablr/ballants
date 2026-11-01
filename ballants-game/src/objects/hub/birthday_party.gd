class_name BirthdayParty
extends Node
## BIRTHDAY PARTY -- the hub's easter egg. The pieces, and how they chain:
##
##   1. A bounce pad sits at the foot of the cave wall between tunnels 4
##      and 5. High above it, out of jumping reach, hangs a tiny yellow
##      KEY (mystery_key.gd). Bounce up through it: "You found a
##      mysterious key".
##   2. Roll up to the JAIL CELL without the key and the HUD says
##      "Locked". With it, the barred door swings open and stays open
##      (Progress.jail_unlocked).
##   3. Inside, on the left-hand wall, is a small red BUTTON
##      (cell_button.gd). Near it the HUD prompts a push; Space / A pushes
##      it, and the party starts.
##   4. THE PARTY: the hero rolls out of the cell toward the middle of the
##      cave and stops to watch; the camera sits behind them. Worker ants
##      pour out of the holes in the far wall and run into two rows in the
##      daylight spotlight in the middle of the floor; the Queen crawls out
##      of her own hole and takes the middle of the front row. A crowd of
##      spectators comes out too and stands round the dance floor on their
##      back legs, cheering and clapping (CaveAnt.start_cheer). The band
##      strikes up "Happy Birthday" (birthday_song.gd, made in code) and the
##      line dances in step (CaveAnt.start_dance) for exactly two routines,
##      holding the finale pose for the song's last chord, under a shower of
##      confetti, with "Happy Birthday, Martha!" across the screen. Then
##      everyone cheers, scurries back into their holes, and the hero gets
##      control back.
##      Hold Esc / Start to skip, like any cutscene.
##
## Everything here is built in code by setup(); the hub owns one of these.

## Where the bounce pad sits: the wall angle (degrees, see CaveShell) and
## how far out from the middle as a fraction of the floor radius.
const PAD_ANGLE := 288.0
const PAD_RADIUS_FRACTION := 0.86
## The key hangs this far under the top of a bounce, so the ball passes
## through it on the way up.
const KEY_UNDER_APEX := 0.8
## Where the button sits on the cell's left wall (cell space: x right, y
## up, z into the wall; "left" as you roll in facing +Z is +X).
const BUTTON_SPOT := Vector3(JailCell.INNER_HALF_WIDTH - 0.02, 1.0, 3.2)
## How close to the cell door counts as "at the jail" (meters).
const JAIL_REACH := 5.0
## The dance troupe: worker ants in two rows, the Queen in the middle of
## the front row.
const DANCERS := 12
const ROW_SPACING := 1.3
const QUEEN_GAP := 3.4
## The dance floor: the middle of the cave, under the daylight from the
## hole in the top (the spotlight). The hero watches from this far away,
## on the side toward the jail.
const DANCE_CENTER := Vector3.ZERO
const HERO_DISTANCE := 8.0   # just outside the pool of light
const BACK_ROW := 2.0         # the second row this far behind the first
## The crowd: this many spectators stand in an arc round the dance floor,
## at this radius, spanning this many degrees either side of the far side
## (the gap is on the hero's side, so nobody stands in the way).
const SPECTATORS := 18
const SPECTATOR_RADIUS := 9.0
const SPECTATOR_ARC := 115.0
const SPECTATOR_SPEED := 12.0
const RUN_SPEED := 11.0
const QUEEN_SPEED := 8.0
## The band waits until every dancer is on its mark, but never longer
## than this (seconds after the ants set off).
const SONG_WAIT_LIMIT := 15.0
const BANNER_TEXT := "Happy Birthday, Martha!"
const BOUNCE_PAD_SCENE := preload("res://src/objects/bounce_pad.tscn")
const CONFETTI_COLORS := [
	Color(1.0, 0.25, 0.3), Color(1.0, 0.85, 0.2), Color(0.3, 0.85, 1.0),
	Color(0.4, 0.95, 0.4), Color(1.0, 0.5, 0.9), Color(1.0, 0.6, 0.2), Color(0.75, 0.5, 1.0),
]

signal started
signal finished

## The hub (levels/hub/anthill_hub.gd; untyped so its members resolve).
var hub
var shell: CaveShell
var jail: JailCell
var queen: CaveAnt
var queen_hole: Dictionary = {}

var pad: Node3D
var key: MysteryKey
var button: CellButton
var dancers: Array[CaveAnt] = []
var spectators: Array[CaveAnt] = []
## Whether the whole line was in place when the band started (tests).
var line_was_ready := false
var is_playing := false

var _jail_zone: Area3D
var _near_jail := false
var _jail_prompting := false
var _song: AudioStreamPlayer
var _song_started_msec := -1
var _banner: CanvasLayer
var _banner_label: Label
var _banner_time := 0.0
var _confetti: Array[GPUParticles3D] = []
var _hud: Node
var _skip_hold := 0.0
var _skipping := false
var _last_bar := -100
var _hero_ball: PlayerBall
var _hero_rest := Vector3.ZERO
var _run := 0
## The rendered song and the background job that renders it. Both belong
## to this node (never to a static variable): a sound still held when the
## game quits is freed after the audio server has shut down, which crashes
## Godot on exit.
var _song_stream: AudioStreamWAV
var _song_task := -1


## Renders the song on a worker thread (about a second of work).
func _prepare_song() -> void:
	if _song_stream != null or _song_task != -1:
		return
	_song_task = WorkerThreadPool.add_task(func(): _song_stream = BirthdaySong.render(), false, "BirthdaySong")


## The finished song, waiting for the render if it is still going.
func _get_song() -> AudioStreamWAV:
	_finish_song_task()
	if _song_stream == null:
		_song_stream = BirthdaySong.render()
	return _song_stream


func _finish_song_task() -> void:
	if _song_task != -1:
		WorkerThreadPool.wait_for_task_completion(_song_task)
		_song_task = -1


## Leaving the hub (or quitting): let the render finish and let go of the
## sound while the audio server is still running.
func _exit_tree() -> void:
	_finish_song_task()
	if _song:
		_song.stop()
		_song.stream = null
	_song_stream = null


## Builds the pad, the key, the jail trigger, the button and the dancers.
## `queen_hole_dict` is the Queen's hole (she goes home to it).
func setup(hub_node: Node3D, cave: CaveShell, cell: JailCell, queen_ant: CaveAnt, queen_hole_dict: Dictionary) -> void:
	hub = hub_node
	shell = cave
	jail = cell
	queen = queen_ant
	queen_hole = queen_hole_dict
	_prepare_song()
	_build_pad_and_key()
	_build_jail_zone()
	_build_button()
	_build_dancers()
	_build_spectators()
	_song = AudioStreamPlayer.new()
	_song.name = "Band"
	_song.bus = Sounds.SFX_BUS
	_song.volume_db = -5.0
	add_child(_song)
	_build_banner()
	if Progress.jail_unlocked:
		jail.open(true)
		button.armed = true
	if Progress.birthday_party_done:
		_start_nest_confetti(true)


# ------------------------------------------------------------- pieces ----

func _build_pad_and_key() -> void:
	var dir := CaveShell.direction(PAD_ANGLE)
	var spot := dir * shell.floor_radius * PAD_RADIUS_FRACTION
	spot.y = shell._floor_bump(spot.x, spot.z)
	pad = BOUNCE_PAD_SCENE.instantiate()
	pad.name = "KeyBouncePad"
	hub.add_child(pad)
	pad.global_position = spot
	if Progress.has_mystery_key:
		return
	key = MysteryKey.new()
	key.name = "MysteryKey"
	hub.add_child(key)
	# The pad launches the ball's center (0.5 m up when resting on the
	# pad's 0.25 m top) to bounce_pad_height above where it was.
	key.global_position = spot + Vector3.UP * (0.25 + 0.5 + Tuning.bounce_pad_height - KEY_UNDER_APEX)
	key.found.connect(_on_key_found)


func _on_key_found() -> void:
	var hud := _find_hud()
	if hud:
		hud.popup("You found a mysterious key", 3.0)


## A zone in front of the cell door: "Locked" without the key, the door
## opens with it.
func _build_jail_zone() -> void:
	_jail_zone = Area3D.new()
	_jail_zone.name = "JailZone"
	_jail_zone.monitoring = true
	_jail_zone.monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = JAIL_REACH
	shape.shape = sphere
	_jail_zone.add_child(shape)
	hub.add_child(_jail_zone)
	_jail_zone.global_position = jail.mouth_point(0.5)
	_jail_zone.body_entered.connect(func(body: Node3D):
		if body is PlayerBall:
			_near_jail = true)
	_jail_zone.body_exited.connect(func(body: Node3D):
		if body is PlayerBall:
			_near_jail = false)


func _build_button() -> void:
	button = CellButton.new()
	button.name = "CellButton"
	# Local +Y (the button's face) points into the cell, off the +X wall.
	button.transform = Transform3D(Basis(Vector3.UP, Vector3.LEFT, Vector3.BACK), BUTTON_SPOT)
	jail.add_child(button)
	button.pushed.connect(_play)


## The troupe waits inside holes on the far side of the cave from the
## jail, so the hero (looking out of the cell) sees them pour down the
## wall and run across the floor.
func _build_dancers() -> void:
	var root := Node3D.new()
	root.name = "Dancers"
	hub.add_child(root)
	var holes := _far_holes(75.0, 0.55)
	if holes.size() < 4:
		holes = _far_holes(120.0, 0.7)
	if holes.is_empty():
		holes = shell.holes.duplicate()
	for i in DANCERS:
		var ant := CaveAnt.new()
		ant.name = "Dancer%d" % i
		root.add_child(ant)
		ant.hide_in_hole(holes[i % holes.size()])
		dancers.append(ant)


## The crowd waits in holes spread all round the cave (low ones, so the
## crawl down is short). Their claps are silent: the dancers' claps and the
## band carry the sound.
func _build_spectators() -> void:
	var root := Node3D.new()
	root.name = "Spectators"
	hub.add_child(root)
	var holes := []
	for hole in shell.holes:
		if hole != queen_hole and float(hole.t) >= 0.05 and float(hole.t) <= 0.35:
			holes.append(hole)
	if holes.is_empty():
		holes = shell.holes.duplicate()
	holes.sort_custom(func(a, b): return float(a.angle) < float(b.angle))
	for i in SPECTATORS:
		var ant := CaveAnt.new()
		ant.name = "Spectator%d" % i
		ant.clap_sound = false
		root.add_child(ant)
		ant.hide_in_hole(holes[int(float(i) * holes.size() / SPECTATORS) % holes.size()])
		spectators.append(ant)


## Small holes on the wall across from the jail, within `spread` degrees
## of straight across and no higher than `max_t`, nearest first.
func _far_holes(spread: float, max_t: float) -> Array:
	var across: float = float(hub.JAIL_ANGLE) + 180.0
	var picked := []
	for hole in shell.holes:
		if hole == queen_hole or float(hole.t) > max_t or float(hole.t) < 0.05:
			continue
		if absf(wrapf(float(hole.angle) - across, -180.0, 180.0)) <= spread:
			picked.append(hole)
	picked.sort_custom(func(a, b):
		return absf(wrapf(float(a.angle) - across, -180.0, 180.0)) < absf(wrapf(float(b.angle) - across, -180.0, 180.0)))
	return picked


func _build_banner() -> void:
	_banner = CanvasLayer.new()
	_banner.name = "Banner"
	_banner.layer = 32
	_banner.visible = false
	add_child(_banner)
	_banner_label = Label.new()
	_banner_label.text = BANNER_TEXT
	_banner_label.add_theme_font_size_override("font_size", 72)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	_banner_label.add_theme_color_override("font_outline_color", Color(0.45, 0.1, 0.15))
	_banner_label.add_theme_constant_override("outline_size", 12)
	_banner_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_banner_label.add_theme_constant_override("shadow_offset_x", 4)
	_banner_label.add_theme_constant_override("shadow_offset_y", 4)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.anchor_left = 0.0
	_banner_label.anchor_right = 1.0
	_banner_label.anchor_top = 0.08
	_banner_label.anchor_bottom = 0.08
	_banner_label.offset_bottom = 110.0
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_banner_label)


func banner_visible() -> bool:
	return _banner.visible


func song_playing() -> bool:
	return _song != null and _song.playing


# ---------------------------------------------------------- every frame ----

func _process(delta: float) -> void:
	_update_jail_prompt()
	if not is_playing:
		return
	# The whole line (and the Queen) step to the song's clock.
	var beat := _dance_beat()
	for ant in dancers:
		ant.dance_beat = beat
	queen.dance_beat = beat
	_animate_banner(delta, beat)
	_hero_bounce(beat)
	# Hold Esc / Start to skip.
	if not _skipping and Input.is_action_pressed("skip_cutscene"):
		_skip_hold += delta
		hub.cutscene.dialogue.set_skip_progress(_skip_hold / CutsceneStyle.SKIP_HOLD)
		if _skip_hold >= CutsceneStyle.SKIP_HOLD:
			_skipping = true
			hub.cutscene.dialogue.set_skip_progress(0.0)
	elif _skip_hold > 0.0:
		_skip_hold = 0.0
		hub.cutscene.dialogue.set_skip_progress(0.0)


## "Locked" while the hero is at the door without the key; the door opens
## the moment they arrive with it.
func _update_jail_prompt() -> void:
	var hud := _find_hud()
	if hud == null:
		return
	var busy := Game.control_locked or Game.cutscene_active
	if _near_jail and not busy and not Progress.jail_unlocked:
		if Progress.has_mystery_key:
			_unlock_jail(hud)
		elif not _jail_prompting:
			_jail_prompting = true
			hud.show_prompt("Locked")
		return
	if _jail_prompting:
		_jail_prompting = false
		if hud.prompt_text() == "Locked":
			hud.hide_prompt()


func _unlock_jail(hud: Node) -> void:
	Progress.set_flag("jail_unlocked")
	_jail_prompting = false
	hud.hide_prompt()
	Sounds.ui("confirm")
	jail.open()
	button.armed = true
	hud.popup("The mysterious key fits!", 2.5)


## Counts of the dance routine: 0 at the song's first downbeat, negative
## during the intro, far negative before the band starts.
func _dance_beat() -> float:
	if _song_started_msec < 0:
		return -100.0
	var seconds := (Time.get_ticks_msec() - _song_started_msec) / 1000.0 - AudioServer.get_output_latency()
	return seconds / BirthdaySong.seconds_per_beat() - BirthdaySong.FIRST_DOWNBEAT


func _animate_banner(delta: float, beat: float) -> void:
	if not _banner.visible:
		return
	_banner_time += delta
	var pulse := absf(sin(beat * PI)) if beat > 0.0 else 0.0
	_banner_label.pivot_offset = _banner_label.size * 0.5
	var pop := minf(_banner_time / 0.45, 1.0)
	var grow := 1.0 + 0.5 * sin(pop * PI) * (1.0 - pop)   # overshoots, then settles
	_banner_label.scale = Vector2.ONE * (grow * (1.0 + 0.04 * pulse))
	_banner_label.rotation = sin(_banner_time * 2.2) * 0.035


## The hero bobs along on every downbeat.
func _hero_bounce(beat: float) -> void:
	if beat < 0.0 or _hero_ball == null or not is_instance_valid(_hero_ball):
		return
	var bar := int(floorf(beat / 3.0))
	if bar == _last_bar:
		return
	_last_bar = bar
	var tween := create_tween()
	tween.tween_property(_hero_ball, "global_position:y", _hero_rest.y + 0.28, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_hero_ball, "global_position:y", _hero_rest.y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _hero_ball._play_squash(Vector3.UP, Tuning.impact_small * 0.8))


# ------------------------------------------------------------ the party ----

## Throws the party right now, key or no key (watching it again from the
## progress screen).
func play_again() -> void:
	button.armed = true
	button.push()


func _play() -> void:
	if is_playing:
		return
	var ball := get_tree().get_first_node_in_group("player") as PlayerBall
	if ball == null:
		return
	if hub.cutscene == null:
		hub._make_cutscene(ball)
	var cut: CutscenePlayer = hub.cutscene
	is_playing = true
	_skipping = false
	_skip_hold = 0.0
	_last_bar = -100
	_song_started_msec = -1
	_run += 1
	var my_run := _run
	var hud := _find_hud()
	Game.cutscene_active = true
	Game.control_locked = true
	if hud:
		hud.hide_prompt()
		hud.visible = false
	Music.set_hold(true)
	started.emit()
	cut.take_camera()
	var rider := ball.get_node("AntRider") as Node3D

	# A close look at the button being pushed.
	cut.shot(button, {"distance": 1.3, "height": 0.25, "yaw": 35.0, "look_height": 0.05}, 0.0)
	await _wait(0.8)
	if my_run != _run:
		return

	# The hero hurries out of the cell to see, and turns to face the cave.
	ball.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	var toward := -jail.global_transform.basis.z
	toward.y = 0.0
	toward = toward.normalized()
	var side := toward.cross(Vector3.UP).normalized()
	var start := ball.global_position
	# Out toward the middle of the cave, stopping short of the dance floor.
	var center := _floor_spot(DANCE_CENTER, Basis.IDENTITY).origin
	var stand := center - toward * HERO_DISTANCE
	stand.y = start.y
	_hero_ball = ball
	_hero_rest = stand
	var roll_seconds := clampf(start.distance_to(stand) / 6.0, 1.5, 3.5)
	cut.shot(ball, {"at": start.lerp(stand, 0.55) + side * 8.0 + Vector3.UP * 2.8, "look_height": 0.3, "track": true}, 0.6)
	await _roll_ball(ball, start, stand, roll_seconds, side)
	if my_run != _run:
		return
	if rider.has_method("face_toward"):
		rider.face_toward(toward)
	ball.set_spawn(Transform3D(Basis.IDENTITY, stand))
	# The camera settles behind the hero (a little to one side and above, so
	# the hero's head doesn't hide the Queen), looking out over them.
	var look := stand + toward * 3.5 + Vector3.UP * 0.3
	cut.shot(look, {"at": stand - toward * 3.4 + side * 0.9 + Vector3.UP * 2.1, "look_height": 0.0}, 1.0)
	await _wait(0.6)
	if my_run != _run:
		return
	if rider.has_method("play_gesture"):
		rider.play_gesture("tilt")

	# Places for the troupe: two rows across the middle of the floor, in
	# the spotlight, the Queen in the middle of the front row.
	var facing := Basis.looking_at(-toward, Vector3.UP)
	var spots: Array[Transform3D] = []
	for k in 3:
		for s in [1.0, -1.0]:
			spots.append(_floor_spot(center + side * s * (QUEEN_GAP * 0.5 + ROW_SPACING * k), facing))
	for k in 3:
		for s in [1.0, -1.0]:
			spots.append(_floor_spot(center + toward * BACK_ROW + side * s * (ROW_SPACING * 0.5 + ROW_SPACING * k), facing))
	var queen_spot := _floor_spot(center, facing)

	_spotlight(true)
	# Everybody out! The crowd and the troupe together, each staggered so
	# they pour out rather than pop out.
	_send_crowd(center, toward, my_run)
	for i in dancers.size():
		_send_dancer(dancers[i], spots[i], stand, my_run)
		await _wait(0.2)
		if my_run != _run:
			return
	_send_queen(queen_spot, stand, my_run)
	# The band only starts once the whole line is in place.
	var waited := 0.0
	while waited < SONG_WAIT_LIMIT and not _line_ready():
		await get_tree().process_frame
		waited += get_process_delta_time()
		if my_run != _run:
			return
	await _wait(0.4)
	if my_run != _run:
		return

	# The band strikes up; the banner and confetti arrive on the first
	# downbeat.
	line_was_ready = _line_ready()
	_song.stream = _get_song()
	_song.play()
	_song_started_msec = Time.get_ticks_msec()
	var intro := BirthdaySong.FIRST_DOWNBEAT * BirthdaySong.seconds_per_beat()
	await _wait(intro)
	if my_run != _run:
		return
	_banner_time = 0.0
	_banner.visible = true
	_start_confetti(center, stand)
	var remaining := BirthdaySong.length() - intro - 0.4
	var t := 0.0
	while t < remaining and not _skipping:
		await get_tree().process_frame
		t += get_process_delta_time()
		if my_run != _run:
			return
	if _skipping:
		await _end(ball, hud, cut, true)
	else:
		await _end(ball, hud, cut, false)


## Every dancer and the Queen are on their spots.
func _line_ready() -> bool:
	if not queen.dancing:
		return false
	for ant in dancers:
		if not ant.dancing:
			return false
	return true


## One worker: out of its hole, down the wall, across the floor to its
## spot, then in step with the line.
func _send_dancer(ant: CaveAnt, spot: Transform3D, face: Vector3, my_run: int) -> void:
	ant.stop_dance()
	ant.state = CaveAnt.State.TRAVELLING
	ant.dance_cycles = BirthdaySong.VERSES
	await ant.emerge_from_hole(shell, ant.home_hole, spot.origin, face, RUN_SPEED)
	if my_run != _run or not is_playing:
		return
	ant.start_dance(spot)


## The crowd: out of the holes all round, into an arc round the dance
## floor (open on the hero's side), each turned to face the dancers, then
## up on their back legs cheering.
func _send_crowd(center: Vector3, toward: Vector3, my_run: int) -> void:
	var spots: Array[Transform3D] = []
	for i in SPECTATORS:
		var u := float(i) / maxf(SPECTATORS - 1, 1)
		var angle := deg_to_rad(lerpf(-SPECTATOR_ARC, SPECTATOR_ARC, u))
		var where := center + toward.rotated(Vector3.UP, angle) * SPECTATOR_RADIUS
		var look := center - where
		look.y = 0.0
		spots.append(_floor_spot(where, Basis.looking_at(look.normalized(), Vector3.UP)))
	# Each ant takes the spot nearest its own hole, so the paths don't cross.
	var free := spots.duplicate()
	for ant in spectators:
		var hole_at: Vector3 = (ant.home_hole.transform as Transform3D).origin
		var best := 0
		for k in free.size():
			if (free[k] as Transform3D).origin.distance_to(hole_at) < (free[best] as Transform3D).origin.distance_to(hole_at):
				best = k
		_send_spectator(ant, free[best], center, my_run)
		free.remove_at(best)
		await _wait(0.08)
		if my_run != _run:
			return


func _crowd_home(ant: CaveAnt) -> void:
	await ant.stop_cheer()
	ant.go_home(shell, 8.0)


func _send_spectator(ant: CaveAnt, spot: Transform3D, center: Vector3, my_run: int) -> void:
	ant.stop_cheer(true)
	ant.state = CaveAnt.State.TRAVELLING
	await ant.emerge_from_hole(shell, ant.home_hole, spot.origin, center, SPECTATOR_SPEED)
	if my_run != _run or not is_playing:
		return
	ant.start_cheer(spot)


func _send_queen(spot: Transform3D, face: Vector3, my_run: int) -> void:
	queen.stop_dance()
	queen.dance_cycles = BirthdaySong.VERSES
	queen.set_mood("happy")
	await queen.emerge_from_hole(shell, queen_hole, spot.origin, face, QUEEN_SPEED)
	if my_run != _run or not is_playing:
		return
	queen.start_dance(spot)


## The end: a cheer, everyone scurries home, the hero gets control back.
## Skipping cuts straight to the hand-back.
func _end(ball: PlayerBall, hud: Node, cut: CutscenePlayer, skipped: bool) -> void:
	_run += 1   # stops any dancer still on its way from joining in
	# The reward: from now on confetti drifts down all over the nest.
	Progress.set_flag("birthday_party_done")
	_start_nest_confetti(false)
	var all: Array[CaveAnt] = dancers.duplicate()
	all.append(queen)
	if skipped:
		_song.stop()
		for ant in all:
			ant.stop_dance()
			ant._path = []
			ant.hide_in_hole(ant.home_hole)
		for ant in spectators:
			ant.stop_cheer(true)
			ant._path = []
			ant.hide_in_hole(ant.home_hole)
		queen.set_mood("calm")
		_stop_confetti()
		_banner.visible = false
	else:
		# The line is already on its spots, reared up in the finale pose:
		# carry straight on into the cheer from there.
		for ant in all:
			ant.end_dance()
			ant.celebrate(4)
		Sounds.play("level_complete", -8.0)
		await _wait(1.9)
		_stop_confetti()
		var fade := create_tween()
		fade.tween_property(_banner_label, "modulate:a", 0.0, 0.8)
		fade.tween_callback(func():
			_banner.visible = false
			_banner_label.modulate.a = 1.0)
		for ant in all:
			ant.go_home(shell, 8.0 if ant != queen else 6.5)
		queen.set_mood("calm")
		# The crowd sits back down on six legs, then heads home too.
		for ant in spectators:
			if ant.cheering:
				_crowd_home(ant)
		await _wait(1.6)
	_song_started_msec = -1
	_spotlight(false)
	# Hand back: the ball back in the physics where it stands.
	if is_instance_valid(ball):
		ball.freeze = false
		ball.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
		ball.reset_physics_interpolation()
	_hero_ball = null
	await cut.release_camera()
	Game.cutscene_active = false
	Game.control_locked = false
	Music.set_hold(false)
	if hud and is_instance_valid(hud):
		hud.visible = true
	button.armed = true   # the party can be thrown again
	is_playing = false
	finished.emit()


# ------------------------------------------------------------- helpers ----

## A place on the cave floor (the floor is a little bumpy).
func _floor_spot(where: Vector3, facing: Basis) -> Transform3D:
	var origin := where
	origin.y = shell._floor_bump(where.x, where.z)
	return Transform3D(facing, origin)


## Rolls the frozen ball along the floor from a to b, turning as it goes.
func _roll_ball(ball: PlayerBall, from: Vector3, to: Vector3, seconds: float, side: Vector3) -> void:
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var distance := from.distance_to(to)
	var rolled := [0.0]
	tween.tween_method(func(u: float):
		var eased := smoothstep(0.0, 1.0, u)
		ball.global_position = from.lerp(to, eased)
		var travelled := eased * distance
		ball.rotate(side, -(travelled - rolled[0]) / maxf(ball.radius, 0.1))
		rolled[0] = travelled,
		0.0, 1.0, seconds)
	await tween.finished


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds).timeout


func _find_hud() -> Node:
	if _hud == null or not is_instance_valid(_hud):
		_hud = hub.find_child("HUD", true, false)
	return _hud


# ----------------------------------------------------------- spotlight ----

## How much brighter the daylight on the floor shines during the party.
const SPOTLIGHT_BOOST := 3.0
## The visible beam stays on during the party, a little lighter than usual
## so the dancers inside it still read clearly.
const BEAM_DURING_PARTY := 0.4
## The rest of the cave dims to this fraction of its usual ambient light
## ("house lights down"), so the lit dance floor stands out.
const HOUSE_LIGHTS := 0.3
var _daylight_energy := -1.0
var _beam_alpha := -1.0
var _ambient_energy := -1.0

## The daylight from the hole in the top becomes the party's spotlight:
## the light on the floor brightens and the hazy cone of "dusty air" fades
## out (the camera watches from outside it, and through it the dancers
## looked washed out), and the rest of the cave dims. All come back
## afterwards.
func _spotlight(on: bool) -> void:
	var world := hub.find_child("CaveEnvironment", true, false) as WorldEnvironment
	var daylight := hub.find_child("Daylight", true, false) as SpotLight3D
	var beam := hub.find_child("LightBeam", true, false) as MeshInstance3D
	var tween := create_tween().set_parallel(true)
	if world and world.environment:
		if _ambient_energy < 0.0:
			_ambient_energy = world.environment.ambient_light_energy
		tween.tween_property(world.environment, "ambient_light_energy", _ambient_energy * (HOUSE_LIGHTS if on else 1.0), 1.5)
	if daylight:
		if _daylight_energy < 0.0:
			_daylight_energy = daylight.light_energy
		tween.tween_property(daylight, "light_energy", _daylight_energy * (SPOTLIGHT_BOOST if on else 1.0), 1.0)
	if beam and beam.mesh and beam.mesh.surface_get_material(0) is StandardMaterial3D:
		var material := beam.mesh.surface_get_material(0) as StandardMaterial3D
		if _beam_alpha < 0.0:
			_beam_alpha = material.albedo_color.a
		var target := Color(material.albedo_color, _beam_alpha * (BEAM_DURING_PARTY if on else 1.0))
		tween.tween_property(material, "albedo_color", target, 1.0)


# ------------------------------------------------------------ confetti ----

var nest_confetti: GPUParticles3D

## Confetti drifting down everywhere in the cave, for good, once the party
## has been thrown (this session: nothing is saved yet). `already` = it was
## thrown before this visit, so the air starts full instead of filling up.
func _start_nest_confetti(already: bool) -> void:
	if nest_confetti and is_instance_valid(nest_confetti):
		return
	# Born anywhere from head height to high in the dome, so the air is
	# full at once rather than raining down from the ceiling.
	var top := shell.height * 0.75
	var low := 1.5
	nest_confetti = _make_confetti(Vector3(0.0, (top + low) * 0.5, 0.0),
			Vector3(shell.floor_radius * 0.8, (top - low) * 0.5, shell.floor_radius * 0.8), 1100)
	nest_confetti.name = "NestConfetti"
	nest_confetti.lifetime = 20.0
	nest_confetti.preprocess = 20.0 if already else 0.0
	nest_confetti.visibility_aabb = AABB(Vector3(-30.0, -14.0, -30.0), Vector3(60.0, 28.0, 60.0))
	var process := nest_confetti.process_material as ParticleProcessMaterial
	process.gravity = Vector3(0.0, -1.0, 0.0)
	process.damping_min = 0.2
	process.damping_max = 0.45
	process.turbulence_noise_strength = 1.2
	process.turbulence_influence_max = 0.25
	process.scale_min = 1.6
	process.scale_max = 2.4
	nest_confetti.restart()


## Two showers: a wide one over the dancers and a smaller one over the
## hero, so it falls in the foreground too.
func _start_confetti(over_line: Vector3, over_hero: Vector3) -> void:
	_stop_confetti()
	_confetti.append(_make_confetti(over_line + Vector3.UP * 6.5, Vector3(6.5, 0.4, 2.5), 420))
	_confetti.append(_make_confetti(over_hero + Vector3.UP * 5.0, Vector3(2.5, 0.3, 2.5), 120))


func _stop_confetti() -> void:
	for particles in _confetti:
		if is_instance_valid(particles):
			particles.emitting = false
			get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(particles.queue_free)
	_confetti.clear()


func _make_confetti(at: Vector3, extents: Vector3, amount: int) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Confetti"
	particles.amount = amount
	particles.lifetime = 7.0
	particles.preprocess = 1.5
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-12.0, -10.0, -12.0), Vector3(24.0, 14.0, 24.0))
	var piece := BoxMesh.new()
	piece.size = Vector3(0.12, 0.08, 0.01)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	piece.material = material
	particles.draw_pass_1 = piece
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = Vector3.DOWN
	process.spread = 60.0
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 1.2
	process.gravity = Vector3(0.0, -0.9, 0.0)
	process.damping_min = 0.6
	process.damping_max = 1.2
	process.angular_velocity_min = -360.0
	process.angular_velocity_max = 360.0
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.6
	process.turbulence_noise_scale = 3.0
	process.turbulence_influence_min = 0.05
	process.turbulence_influence_max = 0.15
	var colors := Gradient.new()
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	var palette := PackedColorArray()
	for i in CONFETTI_COLORS.size():
		offsets.append(float(i) / CONFETTI_COLORS.size())
		palette.append(CONFETTI_COLORS[i])
	colors.offsets = offsets
	colors.colors = palette
	var ramp := GradientTexture1D.new()
	ramp.gradient = colors
	process.color_initial_ramp = ramp
	particles.process_material = process
	hub.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	return particles
