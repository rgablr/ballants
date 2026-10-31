class_name Worm
extends Node3D
## WORM -- an earthworm inching around a loop in the dirt. Seen from an
## ant it's huge: several meters long and as thick as the ball is tall. It
## moves the way worms do: the front stretches forward, then the rest
## bunches up behind it, with a little arch rippling down the body.
##
## Roll into it and it pulls itself back into the ground, leaving a little
## dirt mound, then pops up somewhere else on its loop a few seconds later.
## (It has no collision, so it never knocks the ball off course.)

@export var segments := 14
@export var segment_radius := 0.26
@export var spacing := 0.36
## Size of the loop it crawls around (m).
@export var loop_radius := 4.5
@export var speed := 0.6
## Ball closer than this (m) to any segment makes it burrow.
@export var touch_distance := 0.9

var _parts: Array[MeshInstance3D] = []
var _distance := 0.0        # how far along its loop the head is (m)
var _time := 0.0
var _hidden := 0.0          # seconds left underground
var _sink := 0.0            # 0 = above ground, 1 = fully under
var _mound: MeshInstance3D
var _ground_cache := {}


func _ready() -> void:
	var pink := CritterParts.material(Color(0.86, 0.52, 0.5), 0.5)
	var band := CritterParts.material(Color(0.78, 0.4, 0.4), 0.5)
	for i in segments:
		var r := segment_radius * (1.0 - 0.35 * pow(float(i) / segments, 2.0))
		if i == 0:
			r *= 0.85
		var part := CritterParts.sphere(self, Vector3.ZERO, r, Vector3(1, 1, 1.3), band if i == 3 or i == 4 else pink, 10)
		part.top_level = true
		_parts.append(part)
	_mound = CritterParts.sphere(self, Vector3.ZERO, 0.5, Vector3(1, 0.35, 1), CritterParts.material(Color(0.5, 0.36, 0.22), 0.95), 8)
	_mound.top_level = true
	_mound.visible = false
	_distance = randf() * TAU * loop_radius
	_time = randf() * 10.0


## A point on the crawl loop at a distance along it (a wobbly circle).
func _loop_point(d: float) -> Vector3:
	var a := d / loop_radius
	var r := loop_radius * (1.0 + 0.2 * sin(a * 3.0))
	return global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)


func _ground_at(p: Vector3) -> float:
	var key := Vector2i(roundi(p.x * 2.0), roundi(p.z * 2.0))
	if not _ground_cache.has(key):
		_ground_cache[key] = CritterParts.ground_height(self, p)
	return _ground_cache[key]


func _physics_process(delta: float) -> void:
	_time += delta
	var player := CritterParts.find_player(self)
	if _hidden > 0.0:
		_hidden -= delta
		if _hidden <= 0.0:
			_distance += loop_radius * PI * randf_range(0.6, 1.4)   # resurface elsewhere
			_mound.visible = false
	elif player and _sink < 0.05:
		for part in _parts:
			if part.global_position.distance_to(player.global_position) < touch_distance + 0.25:
				_burrow()
				break
	_sink = move_toward(_sink, 1.0 if _hidden > 0.0 else 0.0, delta * 1.4)
	if _hidden <= 0.0:
		# Inching: the head surges forward on a rhythm, the body follows.
		var surge := 0.5 + 0.5 * sin(_time * 2.6)
		_distance += speed * surge * 2.0 * delta
	for i in _parts.size():
		var stretch := 1.0 + 0.18 * sin(_time * 2.6 - i * 0.45)
		var d := _distance - i * spacing * stretch
		var p := _loop_point(d)
		var ahead := _loop_point(d + 0.1)
		var arch := maxf(sin(_time * 2.6 - i * 0.55), 0.0) * 0.22
		var y := _ground_at(p) + segment_radius * 0.8 + arch
		# Burrowing: the head goes down first and the body follows it in.
		var under := clampf(_sink * 1.6 - float(i) / _parts.size() * 0.6, 0.0, 1.0)
		y -= under * (segment_radius * 2.5 + 0.5)
		var part := _parts[i]
		part.global_position = Vector3(p.x, y, p.z)
		var dir := ahead - p
		if dir.length() > 0.001:
			part.look_at(part.global_position + dir, Vector3.UP)
		part.visible = under < 0.99


func _burrow() -> void:
	_hidden = 5.0
	var head := _parts[0].global_position
	_mound.global_position = Vector3(head.x, _ground_at(head), head.z)
	_mound.visible = true
	_mound.scale = Vector3(0.2, 0.1, 0.2)
	_mound.create_tween().tween_property(_mound, "scale", Vector3(1, 0.35, 1), 0.4).set_trans(Tween.TRANS_BACK)
