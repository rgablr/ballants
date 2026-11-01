class_name WorkerLine
extends Node3D
## WORKER LINE -- a line of worker ants, each carrying a pale crumb,
## marching nose to tail along a fixed path at a set speed and spacing,
## forever. They come out of a hole at the start of the path, walk it, and
## disappear into a hole at the end; out of sight they "walk back" for
## `hidden_length` meters (or a little more, see below) and come out again.
##
## NOTHING is random. Where every worker is depends only on how long the
## level has been loaded (physics steps since the level scene's _ready,
## shared by every line and gate in the level, so they stay in step with
## each other):
##     s = (time x speed + offset + i x spacing) mod loop
## Restarting reloads the scene, so the clock restarts too; the run timer
## (which starts on the first input) is NOT used. A rhythm learned on one
## attempt is the same on the next.
##
## The loop is the visible path plus the hidden part, rounded UP to a whole
## number of spacings, so the spacing is exact all the way round and the
## gaps never change size.
##
## Bumping a worker knocks the ball back, away from the ant's body:
## Tuning.worker_knock_speed outward, a little hop (worker_knock_lift), a
## part of the sideways speed kept (worker_knock_keep); then for
## worker_bump_grace seconds no worker can bump it again. Workers have no
## solid body, only an Area3D a bit smaller than the ant and its crumb.
##
## One worker can carry hidden crystal `crystal_which`: set
## `crystal_carrier` to its index. Its crumb has a glinting crystal on top;
## the first bump drops a real HiddenCrystal at its feet (the normal
## pickup awards it). If Progress already has that crystal the worker's
## crystal is faded and unlit and the dropped one shows as a ghost.
##
## Setup: `points` (this node's local space, y = the floor under the
## ants' feet). The first and last points should be ~1 m inside a wall or
## tunnel cap so the ants appear and vanish out of sight; `start_hole` /
## `end_hole` draw a dark hole `hole_inset` meters before those ends.
## `speed_key` / `spacing_key` name values in the physics config
## (config/physics_tuning.gd) that override `speed` / `spacing`, so the F1
## panel tunes the line live. With `sync_gate` set the spacing is
## speed x the gate's period, and the line is shifted so a worker is at
## `sync_distance` along the path in the middle of every open window.

@export var points := PackedVector3Array([Vector3(-6, 0, 0), Vector3(6, 0, 0)])
## Meters of the loop spent out of sight (at least; see above).
@export var hidden_length := 4.0
@export var speed := 1.5
@export var spacing := 4.5
## Meters along the loop the first worker starts at.
@export var offset := 0.0
@export var speed_key := ""
@export var spacing_key := ""
@export var sync_gate: NodePath
@export var sync_distance := 0.0
## CaveAnt body_scale: 2.8 makes a worker about 1.4 m long.
@export var body_scale := 2.8
## Index of the worker that carries a hidden crystal (-1 = none).
@export var crystal_carrier := -1
@export_range(0, 1) var crystal_which := 0
@export var start_hole := true
@export var end_hole := true
@export var hole_inset := 1.0
@export var seed := 1

const CRUMB := Color(0.93, 0.86, 0.68)
const CRUMB_DARK := Color(0.8, 0.7, 0.5)
const HIDDEN_CRYSTAL_SCENE := preload("res://src/objects/hidden_crystal.tscn")
const CLOCK_META := "worker_rush_clock_start"
const GRACE_META := "worker_bump_until"

var _cum := PackedFloat32Array()      # distance along the path at each point
var _length := 0.0
var _ants: Array[CaveAnt] = []
var _areas: Array[Area3D] = []
var _visible: Array[bool] = []
var _count := 0
var _loop := 0.0
var _speed := 0.0
var _spacing := 0.0
var _offset := 0.0
var _clock_start := 0
var _gate: Node
var _carried: Node3D           # the crystal on the carrier's crumb
var _carried_light: OmniLight3D
var _twinkle: MeshInstance3D
var _dropped := false
var _hit_half := Vector3(0.48, 0.5, 0.68)   # hit box half-size at body_scale 2.8
var _hit_center := Vector3(0.0, 0.5, 0.1)
var _logging := false


func _ready() -> void:
	_clock_start = clock_start(self)
	if not sync_gate.is_empty():
		_gate = get_node_or_null(sync_gate)
	for arg in OS.get_cmdline_user_args():
		_logging = _logging or arg.begins_with("--drive=")
	var k := body_scale / 2.8
	_hit_half *= k
	_hit_center *= k
	_measure()
	_read_tuning()
	_build_workers()
	if start_hole:
		_make_hole(true)
	if end_hole:
		_make_hole(false)
	Tuning.value_changed.connect(_on_tuning_changed)
	_update(true)


## The physics step the level's worker clock started on (the first piece
## to ask stamps the level scene; a restart reloads the scene and so
## restarts the clock).
static func clock_start(node: Node) -> int:
	var holder := node
	var root := node.get_tree().root
	while holder.get_parent() and holder.get_parent() != root:
		holder = holder.get_parent()
	if not holder.has_meta(CLOCK_META):
		holder.set_meta(CLOCK_META, Engine.get_physics_frames())
	return int(holder.get_meta(CLOCK_META))


## Seconds of level clock (physics steps since the clock started).
static func clock(_node: Node, start: int) -> float:
	return float(Engine.get_physics_frames() - start) / float(Engine.physics_ticks_per_second)


func _physics_process(_delta: float) -> void:
	_update(false)
	_check_bumps()
	# Determinism check for the bot drives: where this line's first visible worker
	# is exactly 10 s (600 physics steps) after the level loaded. Every run
	# must print the same numbers.
	if _logging and Engine.get_physics_frames() - _clock_start == 600:
		var k := 0
		while k < _count - 1 and worker_position(k) == Vector3.INF:
			k += 1
		var p := worker_position(k)
		print("[drive]   clock 10.00 s: %s worker %d at (%.3f, %.3f) of %d" % [name, k, p.x, p.z, _count])


# ---------------------------------------------------------------- path ----

func _measure() -> void:
	_cum = PackedFloat32Array()
	_cum.append(0.0)
	for i in range(1, points.size()):
		_cum.append(_cum[i - 1] + points[i - 1].distance_to(points[i]))
	_length = _cum[_cum.size() - 1] if _cum.size() > 0 else 0.0


## Path length (m) of the visible part.
func path_length() -> float:
	return _length


func _point_at(d: float) -> Vector3:
	d = clampf(d, 0.0, _length)
	var i := 0
	while i < _cum.size() - 2 and _cum[i + 1] < d:
		i += 1
	var seg := _cum[i + 1] - _cum[i]
	return points[i].lerp(points[i + 1], (d - _cum[i]) / maxf(seg, 0.0001))


## Facing along the path, smoothed over a meter so corners turn gently.
func _forward_at(d: float) -> Vector3:
	var a := _point_at(d - 0.8)
	var b := _point_at(d + 0.8)
	var f := b - a
	f.y = 0.0
	if f.length_squared() < 0.0001:
		return Vector3.FORWARD
	return f.normalized()


func _read_tuning() -> void:
	_speed = speed
	_spacing = spacing
	if not speed_key.is_empty() and speed_key in Tuning:
		_speed = float(Tuning.get(speed_key))
	if not spacing_key.is_empty() and spacing_key in Tuning:
		_spacing = float(Tuning.get(spacing_key))
	_offset = offset
	if _gate and _gate.has_method("period"):
		# One worker through the door per cycle, in the middle of the open window.
		_spacing = _speed * float(_gate.period())
		_offset = sync_distance - _speed * float(_gate.mid_open_time())
	_spacing = maxf(_spacing, 1.6 * body_scale / 2.8)
	_count = maxi(int(ceil((_length + hidden_length) / _spacing)), 1)
	_loop = _count * _spacing


func _on_tuning_changed(value_name: String, _value) -> void:
	if value_name == speed_key or value_name == spacing_key or value_name.begins_with("storage_gate"):
		var before := _count
		_read_tuning()
		if _count != before:
			_build_workers()
		_update(true)


## Distance along the loop of worker i at the current clock.
func distance_of(i: int) -> float:
	var t := clock(self, _clock_start)
	return fposmod(t * _speed + _offset + i * _spacing, _loop)


## World position of worker i's feet (or Vector3.INF while out of sight).
func worker_position(i: int) -> Vector3:
	var s := distance_of(i)
	if s > _length:
		return Vector3.INF
	return to_global(_point_at(s))


func worker_count() -> int:
	return _count


func _update(snap: bool) -> void:
	for i in _count:
		var s := distance_of(i)
		var show := s <= _length
		var ant := _ants[i]
		if show != _visible[i]:
			_visible[i] = show
			ant.visible = show
			snap = true
		if not show:
			continue
		var pos := _point_at(s)
		var basis := Basis.looking_at(_forward_at(s), Vector3.UP)
		ant.transform = Transform3D(basis.scaled(Vector3.ONE * ant.scale.x), pos)
		_areas[i].transform = Transform3D(basis, pos)
		if snap:
			ant.reset_physics_interpolation()
	if _twinkle and _carried and _carried.visible:
		var t := clock(self, _clock_start)
		var pulse := pow(maxf(sin(t * 3.1), 0.0), 6.0)
		_twinkle.scale = Vector3.ONE * (0.15 + pulse * 1.0)
		if _carried_light:
			_carried_light.light_energy = 1.0 + pulse * 2.5


# ------------------------------------------------------------- workers ----

func _build_workers() -> void:
	for ant in _ants:
		ant.queue_free()
	for area in _areas:
		area.queue_free()
	_ants.clear()
	_areas.clear()
	_visible.clear()
	_carried = null
	_carried_light = null
	_twinkle = null
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in _count:
		var ant := CaveAnt.new()
		ant.body_scale = body_scale
		ant.name = "Worker%d" % i
		add_child(ant)
		ant._moving_speed = _speed
		ant._time = rng.randf_range(0.0, 5.0)
		ant._gait = rng.randf()
		_add_crumb(ant, rng)
		if i == crystal_carrier and not _dropped:
			_add_crystal(ant)
		_ants.append(ant)
		_visible.append(true)
		var area := Area3D.new()
		area.name = "Bump%d" % i
		area.monitorable = false
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = _hit_half * 2.0
		shape.shape = box
		shape.position = _hit_center
		area.add_child(shape)
		add_child(area)
		_areas.append(area)


## A pale, chunky crumb on the worker's back (in the ant's own unscaled
## space: the ant node is scaled by body_scale).
func _add_crumb(ant: CaveAnt, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.name = "Crumb"
	holder.position = Vector3(0.0, 0.29, 0.03)
	holder.scale = Vector3.ONE * 1.3
	holder.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
	ant.add_child(holder)
	var pale := CritterParts.material(CRUMB, 0.95)
	var dark := CritterParts.material(CRUMB_DARK, 0.95)
	var box := BoxMesh.new()
	box.size = Vector3(rng.randf_range(0.17, 0.21), rng.randf_range(0.1, 0.13), rng.randf_range(0.16, 0.2))
	box.material = pale
	var core := MeshInstance3D.new()
	core.mesh = box
	holder.add_child(core)
	for n in 3:
		var lump := CritterParts.sphere(holder,
				Vector3(rng.randf_range(-0.07, 0.07), rng.randf_range(0.02, 0.06), rng.randf_range(-0.07, 0.07)),
				rng.randf_range(0.04, 0.06), Vector3(1.2, 0.7, 1.0), pale if n != 1 else dark, 6)
		lump.rotation.y = rng.randf() * TAU


func _add_crystal(ant: CaveAnt) -> void:
	var have := Levels.current_index >= 0 and Progress.has_crystal(Levels.current_index, Progress.SLOT_HIDDEN_A + crystal_which)
	_carried = TunnelEntrance.make_crystal(0.13)
	_carried.name = "CarriedCrystal"
	_carried.position = Vector3(0.0, 0.42, 0.03)
	ant.add_child(_carried)
	for child in _carried.get_children():
		if child is OmniLight3D:
			_carried_light = child
			_carried_light.omni_range = 5.0
			if have:
				child.queue_free()
				_carried_light = null
		elif child is MeshInstance3D and have:
			var faded := StandardMaterial3D.new()
			faded.albedo_color = Color(0.85, 0.97, 1.0, HiddenCrystal.GHOST_ALPHA)
			faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			faded.cull_mode = BaseMaterial3D.CULL_DISABLED
			(child as MeshInstance3D).material_override = faded
	if have:
		return
	# The glint: a little four-pointed star that flashes now and then.
	var star := QuadMesh.new()
	star.size = Vector2(0.3, 0.3)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = _star_texture()
	material.albedo_color = Color(0.85, 0.97, 1.0)
	material.no_depth_test = false
	star.material = material
	_twinkle = MeshInstance3D.new()
	_twinkle.name = "Glint"
	_twinkle.mesh = star
	_twinkle.position = Vector3(0.05, 0.12, 0.0)
	_twinkle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_carried.add_child(_twinkle)


static func _star_texture() -> ImageTexture:
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var dx := absf(x - c) / c
			var dy := absf(y - c) / c
			var a := maxf(1.0 - dx * 8.0 - dy * 1.1, 0.0) + maxf(1.0 - dy * 8.0 - dx * 1.1, 0.0)
			a += maxf(1.0 - sqrt(dx * dx + dy * dy) * 3.0, 0.0)
			image.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


## A dark doorway the ants walk into, facing back along the path.
func _make_hole(at_start: bool) -> void:
	if points.size() < 2:
		return
	var d := hole_inset if at_start else _length - hole_inset
	var pos := _point_at(d)
	var facing := -_forward_at(d) if at_start else _forward_at(d)
	var hole := Node3D.new()
	hole.name = "StartHole" if at_start else "EndHole"
	add_child(hole)
	hole.transform = Transform3D(Basis.looking_at(facing, Vector3.UP), pos)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.02, 0.01, 0.005)
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var k := body_scale / 2.8
	CritterParts.sphere(hole, Vector3(0.0, 0.25 * k, 0.0), 1.0, Vector3(0.95, 0.95, 0.14) * k, black, 12)
	var rim := AnthillTheme.material("dirt_dark")
	CritterParts.sphere(hole, Vector3(0.0, 0.25 * k, 0.06), 1.0, Vector3(1.15, 1.12, 0.1) * k, rim, 12)


# --------------------------------------------------------------- bumps ----

func _check_bumps() -> void:
	var ball := get_tree().get_first_node_in_group("player") as PlayerBall
	if ball == null or ball.knocked or Game.level_complete:
		return
	var t := clock(self, _clock_start)
	if t < float(ball.get_meta(GRACE_META, -1.0)):
		return
	for i in _count:
		if not _visible[i]:
			continue
		var area := _areas[i]
		if area.overlaps_body(ball):
			_bump(i, ball, t)
			return


func _bump(i: int, ball: PlayerBall, t: float) -> void:
	var area := _areas[i]
	var xf := area.global_transform
	var center := xf * _hit_center
	var forward := -xf.basis.z
	var rel := ball.global_position - center
	var along := clampf(rel.dot(forward), -_hit_half.z, _hit_half.z)
	var away := rel - forward * along
	away.y = 0.0
	if away.length() < 0.05:
		away = -Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z)
		if away.length() < 0.05:
			away = -forward
	away = away.normalized()
	var v := ball.linear_velocity
	var flat := Vector3(v.x, 0.0, v.z)
	var sideways := flat - away * flat.dot(away)
	var out := sideways * Tuning.worker_knock_keep + away * Tuning.worker_knock_speed
	ball.linear_velocity = Vector3(out.x, maxf(v.y, Tuning.worker_knock_lift), out.z)
	ball.allow_launch(0.3)
	ball.set_meta(GRACE_META, t + Tuning.worker_bump_grace)
	var contact := ball.global_position - away * 0.5
	Effects.impact(Tuning.impact_small * 3.0, -away, contact)
	Sounds.critter_bump(contact)
	if _logging:
		print("[drive]   worker bump: %s #%d at t=%.2f s, ball (%.1f, %.1f)" % [name, i, t, ball.global_position.x, ball.global_position.z])
	if i == crystal_carrier and not _dropped:
		_drop_crystal(i)


## The carried crystal falls off the crumb and lands on the worker's path
## just behind it (the path is always clear floor, never inside a crumb
## pile or a wall), and the worker walks on. Happens once per run.
func _drop_crystal(i: int) -> void:
	_dropped = true
	if _carried:
		_carried.queue_free()
		_carried = null
		_carried_light = null
		_twinkle = null
	var spot := to_global(_point_at(distance_of(i) - 1.6))
	var crystal := HIDDEN_CRYSTAL_SCENE.instantiate() as HiddenCrystal
	crystal.which = crystal_which
	crystal.name = "DroppedCrystal"
	var level := get_tree().current_scene
	crystal.position = level.to_local(spot) if level is Node3D else spot
	level.add_child.call_deferred(crystal)
	if _logging:
		print("[drive]   %s #%d dropped hidden crystal %d at (%.1f, %.1f)" % [name, i, crystal_which, spot.x, spot.z])
	Sounds.play_at("land", spot, -4.0, 1.6)
