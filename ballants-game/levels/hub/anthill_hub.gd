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
	if arrived_from >= 0 and arrived_from < tunnels.size():
		# Back from a level: in front of its tunnel, looking into the cave.
		var spot := tunnels[arrived_from].return_transform()
		player.global_position = spot.origin
		player.linear_velocity = Vector3.ZERO
		player.angular_velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		player.set_spawn(player.global_transform)
		if rig and rig.has_method("aim"):
			rig.aim(spot.basis.get_euler().y, deg_to_rad(Tuning.camera_pitch_default))
		return
	# A fresh arrival: fall in from the top (step 2) -- for now, the middle.
	player.set_spawn(player.global_transform)


## The tunnel that leads to a level index, or null.
func tunnel_for(level_index: int) -> TunnelEntrance:
	for tunnel in tunnels:
		if tunnel.level_index == level_index:
			return tunnel
	return null
