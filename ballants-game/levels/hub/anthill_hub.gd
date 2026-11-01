extends Level
## ANTHILL HUB -- the inside of the giant ant hill: a big cave you roll
## around freely, with one tunnel per level around the floor. The whole
## cave is built in code when the scene starts (see src/objects/hub/).
##
## Layout (angles: 0 = +Z, 90 = +X; the hero starts in the middle facing -Z):
##   tunnels 1..5 at TUNNEL_ANGLES, tunnel 1 straight ahead (180 degrees)
##   the jail cell between tunnels 1 and 5
##   the Queen's hole low on the wall between tunnels 1 and 2
##
## Arriving:
##   - from the title meadow's giant hill (or a fresh start): the hero falls
##     in through the hole in the top and lands in the middle; the first
##     time per session the opening cutscene follows
##   - back from a level: the hero appears in front of that level's tunnel
## Progress.hub_return_from says which (-1 = fall in).

const TUNNEL_ANGLES := [180.0, 108.0, 36.0, 324.0, 252.0]
const JAIL_ANGLE := 216.0
const QUEEN_HOLE_ANGLE := 150.0
const QUEEN_HOLE_T := 0.17
const WORKER_COUNT := 14
## How high above the floor the hero appears before the fall.
const FALL_HEIGHT := 17.5
## Where the Queen settles to talk, relative to the hero (who faces -Z).
const QUEEN_SPOT := Vector3(1.7, 0.0, -2.4)
## How far behind the ball the Queen stands to swing at it (her origin to
## the ball's center).
const QUEEN_SWING_GAP := 1.05
## Looking into the jail cell from in front, off to the side away from the
## door's hinge so the open door is out of the way.
const CELL_SHOT := {"distance": 5.5, "height": 1.6, "yaw": -24.0, "look_height": 0.9}
const INTRO_CUTSCENE := "res://cutscenes/hub_intro.json"

## The hero has hit the floor after the fall.
signal arrival_landed
## The opening cutscene ended with this outcome ("yes" / "skipped"; "no"
## never gets here because the game is over).
signal intro_finished(outcome: String)

var cutscene: CutscenePlayer
var shell: CaveShell
var tunnels: Array[TunnelEntrance] = []
var jail: JailCell
var queen: CaveAnt
var queen_hole: Dictionary = {}

## How the hero got here this time (see Progress.hub_return_from).
var arrived_from := -1


func _ready() -> void:
	level_name = "The Anthill"
	_build_cave()
	super._ready()
	_build_environment()
	_arrive.call_deferred()


func _build_cave() -> void:
	shell = CaveShell.new()
	shell.name = "CaveShell"
	for angle in TUNNEL_ANGLES:
		shell.cuts.append({"angle": angle, "cells": 2, "rows": 3})
	shell.cuts.append({"angle": JAIL_ANGLE, "cells": 2, "rows": 2})
	shell.keep_clear_angles = TUNNEL_ANGLES.duplicate()
	add_child(shell)
	move_child(shell, 0)

	for i in TUNNEL_ANGLES.size():
		var tunnel := TunnelEntrance.new()
		tunnel.name = "Tunnel%d" % (i + 1)
		tunnel.level_index = i
		tunnel.transform = _wall_mount(TUNNEL_ANGLES[i])
		add_child(tunnel)
		tunnel.attach(shell)
		tunnels.append(tunnel)

	jail = JailCell.new()
	jail.name = "JailCell"
	jail.transform = _wall_mount(JAIL_ANGLE)
	add_child(jail)

	CaveDecor.build(self, shell)

	# The Queen waits inside her own hole, low on the wall.
	queen_hole = shell.add_hole_at(QUEEN_HOLE_ANGLE, QUEEN_HOLE_T)
	queen = CaveAnt.new()
	queen.name = "QueenAnt"
	queen.queen = true
	add_child(queen)
	queen.hide_in_hole(queen_hole)

	# Worker ants, each starting inside a random hole.
	var ants := Node3D.new()
	ants.name = "WorkerAnts"
	add_child(ants)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in WORKER_COUNT:
		if shell.holes.size() < 2:
			break
		var ant := CaveAnt.new()
		ant.name = "Worker%d" % i
		ant.shell = shell
		ants.add_child(ant)
		var hole: Dictionary = shell.holes[rng.randi() % shell.holes.size()]
		while hole == queen_hole:
			hole = shell.holes[rng.randi() % shell.holes.size()]
		ant.hide_in_hole(hole)


## A transform on the floor at the foot of the wall, with +Z pointing into
## the wall (the convention the tunnel and jail pieces use).
func _wall_mount(angle: float) -> Transform3D:
	var dir := CaveShell.direction(angle)
	var origin := dir * shell.floor_radius
	return Transform3D(Basis.looking_at(-dir, Vector3.UP), origin)


## Dim, warm, foggy, with glow on the emissive fungus and crystals.
func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.04, 0.025, 0.015)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.36, 0.22)
	environment.ambient_light_energy = 0.42
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.26, 0.14, 0.07)
	environment.fog_density = 0.011
	environment.fog_sky_affect = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.7
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.name = "CaveEnvironment"
	world_environment.environment = environment
	add_child(world_environment)


# ------------------------------------------------------------ arrival ----

func _arrive() -> void:
	arrived_from = Progress.hub_return_from
	Progress.hub_return_from = -1
	var player := get_tree().get_first_node_in_group("player") as PlayerBall
	var rig := find_child("CameraRig", true, false)
	if player == null:
		return
	if arrived_from >= 0:
		# Back from a level: in front of its tunnel, looking into the cave.
		# A level with no tunnel (the unassigned garden levels) puts you in
		# the middle, facing tunnel 1.
		var tunnel := tunnel_for(arrived_from)
		var spot := tunnel.return_transform() if tunnel else Transform3D(Basis.IDENTITY, Vector3(0.0, 0.6, 0.0))
		player.global_position = spot.origin
		player.linear_velocity = Vector3.ZERO
		player.angular_velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		player.set_spawn(player.global_transform)
		if rig and rig.has_method("aim"):
			rig.aim(spot.basis.get_euler().y, deg_to_rad(Tuning.camera_pitch_default))
		return
	# A fresh arrival: the hero falls in through the hole in the top.
	await _fall_in(player, rig)


## The hero drops from high in the middle of the cave onto the floor, seen
## by a camera low on the floor that tracks the fall. Control is locked
## until the landing (and, the first time, until the cutscene ends).
func _fall_in(player: PlayerBall, rig: Node3D) -> void:
	Game.control_locked = true
	var hud := find_child("HUD", true, false) as CanvasLayer
	if hud:
		hud.visible = false
	_make_cutscene(player)
	var rider := player.get_node("AntRider") as Node3D
	# No bounce on this one landing: it should thump, not spring back up.
	player.physics_material_override.bounce = 0.0
	player.teleport(Vector3(0.0, FALL_HEIGHT, 0.0))
	player.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.6, 0.0)))
	if rig and rig.has_method("aim"):
		rig.aim(0.0, deg_to_rad(Tuning.camera_pitch_default))
	cutscene.take_camera()
	cutscene.shot(rider, cutscene.shot_params("hero", "fall"), 0.0)
	# Make sure the ball has really left the floor before waiting to land.
	var frames := 0
	while player.is_grounded() and frames < 30:
		await get_tree().physics_frame
		frames += 1
	await player.landed
	_landing_effects(player)
	arrival_landed.emit()
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	if not Progress.hub_intro_seen:
		Progress.hub_intro_seen = true
		var outcome: String = await cutscene.play(INTRO_CUTSCENE)
		if not is_inside_tree():
			return   # "No" ended in game over and a scene change
		intro_finished.emit(outcome)
	else:
		await cutscene.release_camera()
		Game.control_locked = false
	if hud:
		hud.visible = true


## Dust, squash and a shake when the hero hits the floor.
func _landing_effects(player: PlayerBall) -> void:
	player.set_surface_grip(player.surface_grip)   # restores the tuned bounce
	Effects.impact(Tuning.impact_big * 1.5, Vector3.DOWN, player.global_position + Vector3.DOWN * 0.45)
	cutscene.shake(0.35)
	Sounds.land(12.0)


func _make_cutscene(player: PlayerBall) -> void:
	if cutscene:
		return
	cutscene = CutscenePlayer.new()
	cutscene.name = "Cutscene"
	add_child(cutscene)
	cutscene.scene_handler = self
	cutscene.actors = {
		"hero": player.get_node("AntRider"),
		"hero_ball": player,
		"queen": queen,
		"queen_hole": queen_hole,
		"queen_spot": QUEEN_SPOT,
		"cave": shell,
		"jail": jail,
	}


# ----------------------------------------------------------- cutscene ----

## Steps aimed at the hub itself ({"do": "scene", "action": ...}).
func cutscene_action(action: String, _step: Dictionary, player: CutscenePlayer) -> void:
	match action:
		"jail":
			await _jail_sequence(player)


## The hero is banished: the cell door swings open, the furious Queen
## lines up behind the ball and swings her thorax into it, the ball flies
## across the cave, through the doorway and bounces off the back of the
## cell, and the door slams shut behind it.
func _jail_sequence(cut: CutscenePlayer) -> void:
	var ball := get_tree().get_first_node_in_group("player") as PlayerBall
	if ball == null:
		return
	# The door swings open (seen from the middle of the cave).
	await cut.shot(jail, {"distance": 9.0, "height": 2.4, "yaw": 35.0, "look_height": 1.2}, 1.0)
	jail.open()
	await get_tree().create_timer(1.1).timeout
	# The Queen walks round behind the ball, lined up with the cell.
	var start := ball.global_position
	var toward := jail.mouth_point(start.y) - start
	toward.y = 0.0
	toward = toward.normalized()
	var side := Vector3.UP.cross(toward)
	var stand := start - toward * QUEEN_SWING_GAP
	stand.y = 0.0
	cut.shot(ball, {"at": start - toward * 1.5 + side * 5.5 + Vector3.UP * 1.6, "look_height": 0.2, "track": true}, 0.9)
	await queen.walk_floor_to(stand, 3.5)
	await queen.face_point(start, 0.35)
	# Wind up... and swing.
	queen.swing_thorax()
	await queen.struck
	await _fling_into_cell(cut, ball, start, toward, side)
	# Slam.
	await get_tree().create_timer(0.3).timeout
	jail.slam()
	await get_tree().create_timer(0.22).timeout
	cut.shake(0.4)
	await get_tree().create_timer(1.3).timeout


## The ball, taken out of the physics, flies in an arc to the doorway,
## straight on into the back wall (dust, squash, shake), bounces back to
## the middle of the cell with a hop, and settles.
func _fling_into_cell(cut: CutscenePlayer, ball: PlayerBall, start: Vector3, toward: Vector3, side: Vector3) -> void:
	ball.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	Sounds.play("thud", 0.0, 1.2)
	Effects.impact(Tuning.impact_big, toward, start - toward * 0.5)
	ball._play_squash(toward, Tuning.impact_big)
	cut.shake(0.25)
	var mouth := jail.mouth_point(1.0)
	var back := jail.back_wall_point(1.0)
	var cell := jail.cell_center()
	# Watch from the side, half-way along the flight, turning to follow.
	var middle := start.lerp(mouth, 0.5)
	cut.shot(ball, {"at": middle + side * 9.0 + Vector3.UP * 3.0, "look_height": 0.0, "track": true}, 0.0)
	var spin_axis := side.normalized()
	var fly := func(from: Vector3, to: Vector3, peak: float, seconds: float, spin: float) -> void:
		var tween := create_tween()
		tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_method(func(t: float):
			ball.global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * peak
			ball.rotate(spin_axis, -spin * get_physics_process_delta_time()),
			0.0, 1.0, seconds)
		await tween.finished
	await fly.call(start, mouth, 4.5, 0.95, 18.0)
	# Cut to a view through the doorway (from the side away from the open
	# door) to see it hit the back of the cell.
	cut.shot(jail, CELL_SHOT, 0.0)
	await fly.call(mouth, back, 0.0, 0.14, 18.0)
	# Smack into the back wall.
	Sounds.play("thud", 3.0, 0.8)
	Effects.impact(Tuning.impact_big * 1.5, -toward, back + toward * 0.5)
	ball._play_squash(-toward, Tuning.impact_big * 1.5)
	cut.shake(0.35)
	await fly.call(back, cell, 0.7, 0.42, -8.0)
	Sounds.land(4.0)
	ball._play_squash(Vector3.UP, Tuning.impact_big * 0.6)
	await fly.call(cell, cell, 0.2, 0.25, -3.0)
	Sounds.land(2.0)


## The tunnel that leads to a level index, or null.
func tunnel_for(level_index: int) -> TunnelEntrance:
	for tunnel in tunnels:
		if tunnel.level_index == level_index:
			return tunnel
	return null
