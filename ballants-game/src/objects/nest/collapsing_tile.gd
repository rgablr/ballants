@tool
class_name CollapsingTile
extends StaticBody3D
## COLLAPSING TILE -- a slab of old, cracked floor that gives way after the
## ball touches it. Lay them side by side to make a floor that falls away
## behind you (the Collapsing Gallery is built from them).
##
## The life of a tile, timed from the moment the ball first rolls onto it
## (or from the moment any tile of its `trigger_group` is touched):
##   1. waits `extra_delay` + crack delay       (looks normal)
##   2. CRACKS: shakes, fresh cracks open, dust puffs out, a low crunch
##   3. after the fall delay it DROPS: its collision switches off at once
##      and the slab falls away into the dark and disappears.
## The timer counts physics steps (never the wall clock), so a tile falls
## exactly the same time after the touch on every run. Restarting the
## level reloads the scene, so every tile is back.
##
## Timing: the crack and fall delays come from the physics config
## (Tuning.tile_crack_delay, Tuning.tile_fall_delay, so the F1 panel
## changes every tile at once) unless `crack_delay` / `fall_delay` are set
## (>= 0). Both are then multiplied by `timing_scale` and, if
## `timing_setting` names a value in the physics config (e.g.
## "gallery_warning_scale"), by that value too, so one slider can slow down
## or speed up a whole section. `extra_delay` (plus the config value named
## by `extra_delay_setting`) is added before the crack, unscaled.
##
## Shape: a box of `size` (top face at local y = 0, the slab hangs below),
## or, if `corners` holds 4 points, a four-sided slab whose top face has
## those corners (local x, z) -- wedge-shaped tiles fit together round a
## curve with no gaps. The collision is exactly that slab; the look is a
## touch smaller on top so a dark groove shows between neighbours.
##
## It is NOT a Block and has no `merge_collision`, so the level's
## StaticMerger leaves it alone (it must be able to switch off).

## Width (x), thickness (y) and depth (z) of a plain box tile. The top face
## is at the node's origin.
@export var size := Vector3(2.5, 0.6, 2.5):
	set(v):
		size = v
		_rebuild()
## Optional: four top-face corners (local x, z) in order round the edge.
## Overrides size.x / size.z (size.y is still the thickness).
@export var corners := PackedVector2Array():
	set(v):
		corners = v
		_rebuild()
## Seconds from the touch to the crack; -1 = Tuning.tile_crack_delay.
@export var crack_delay := -1.0
## Seconds of shaking before it drops; -1 = Tuning.tile_fall_delay.
@export var fall_delay := -1.0
## Multiplies both delays (2 = twice as slow to go).
@export var timing_scale := 1.0
## Name of a physics-config value that also multiplies both delays ("" = none).
@export var timing_setting := ""
## Seconds added before the crack (not scaled).
@export var extra_delay := 0.0
## Name of a physics-config value added to extra_delay ("" = none).
@export var extra_delay_setting := ""
## Tiles sharing a non-empty group all start their timers when any one of
## them is touched (each still uses its own delays).
@export var trigger_group := ""
## Touching this tile also starts the countdown of every tile in this
## group, without this tile joining it (its own countdown still starts
## from its own touch). The opening patch sets off the falling demo this way.
@export var triggers_group := ""
## Base dirt color; each tile shifts it a little (from `seed`).
@export var color := Color(0.5, 0.3, 0.15):
	set(v):
		color = v
		_rebuild()
@export var seed := 1:
	set(v):
		seed = v
		_rebuild()

enum State { IDLE, WAITING, CRACKING, FALLING, GONE }

const CRACK_COLOR := Color(0.13, 0.07, 0.035)
const FRESH_CRACK_COLOR := Color(0.07, 0.035, 0.015)
const SIDE_COLOR := Color(0.3, 0.17, 0.08)
const DUST_COLOR := Color(0.62, 0.5, 0.36)
## How far below its starting place a dropped tile is hidden (m).
const DROP_DISTANCE := 14.0

static var _material: StandardMaterial3D
static var _sound_frame := -100

var state := State.IDLE
var _built := false
var _t := 0.0
var _crack_at := 0.0
var _fall_at := 0.0
var _fall_speed := 0.0
var _visual: Node3D
var _fresh: MeshInstance3D
var _collision: CollisionShape3D
var _top: PackedVector2Array      # top-face corners actually used
var _home := Transform3D.IDENTITY # global transform at start (for the touch test)
var _home_inverse := Transform3D.IDENTITY
var _shake_phase := Vector3.ZERO
var _player: PlayerBall


func _ready() -> void:
	_built = true
	_rebuild()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	if not trigger_group.is_empty():
		add_to_group(_group_name())
	_home = global_transform
	_home_inverse = _home.affine_inverse()


func _group_name() -> String:
	return "collapse_" + trigger_group


## Starts this tile's countdown (if it has not started yet).
func trigger() -> void:
	if state != State.IDLE:
		return
	state = State.WAITING
	_t = 0.0
	var scale_by := timing_scale
	if not timing_setting.is_empty() and timing_setting in Tuning:
		scale_by *= float(Tuning.get(timing_setting))
	var extra := extra_delay
	if not extra_delay_setting.is_empty() and extra_delay_setting in Tuning:
		extra += float(Tuning.get(extra_delay_setting))
	var crack := (crack_delay if crack_delay >= 0.0 else Tuning.tile_crack_delay) * scale_by
	var fall := (fall_delay if fall_delay >= 0.0 else Tuning.tile_fall_delay) * scale_by
	_crack_at = extra + crack
	_fall_at = _crack_at + fall


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			if _ball_on_top():
				if trigger_group.is_empty():
					trigger()
				else:
					get_tree().call_group(_group_name(), "trigger")
				if not triggers_group.is_empty():
					get_tree().call_group("collapse_" + triggers_group, "trigger")
		State.WAITING:
			_t += delta
			if _t >= _crack_at:
				_start_cracking()
		State.CRACKING:
			_t += delta
			_shake()
			if _t >= _fall_at:
				_drop()
		State.FALLING:
			_fall_speed += Tuning.gravity * Tuning.tile_fall_speed * delta
			_visual.position.y -= _fall_speed * delta
			_visual.rotation.x += delta * (_shake_phase.x - 0.5) * 1.2
			_visual.rotation.z += delta * (_shake_phase.z - 0.5) * 1.2
			if -_visual.position.y > DROP_DISTANCE:
				_visual.visible = false
				state = State.GONE
				set_physics_process(false)


## Is the ball resting on (or rolling over) this tile's top face?
func _ball_on_top() -> bool:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerBall
		if _player == null:
			return false
	var local := _home_inverse * _player.global_position
	if local.y < -0.2 or local.y > _player.radius + 0.3:
		return false
	return Geometry2D.is_point_in_polygon(Vector2(local.x, local.z), _top)


func _start_cracking() -> void:
	state = State.CRACKING
	if _fresh:
		_fresh.visible = true
	_puff(10, 1.6)
	_crunch(-16.0, 0.55)


func _shake() -> void:
	# A deterministic rattle that gets stronger toward the drop.
	var span := maxf(_fall_at - _crack_at, 0.05)
	var k := clampf((_t - _crack_at) / span, 0.0, 1.0)
	var a := Tuning.tile_shake * (0.4 + 0.6 * k)
	var w := 55.0
	_visual.position = Vector3(
			sin(_t * w + _shake_phase.x * TAU) * a,
			sin(_t * w * 1.3 + _shake_phase.y * TAU) * a * 0.5 - k * 0.04,
			sin(_t * w * 0.9 + _shake_phase.z * TAU) * a)


func _drop() -> void:
	state = State.FALLING
	_fall_speed = 0.0
	_collision.disabled = true
	collision_layer = 0
	if _player and _player.sleeping:
		_player.sleeping = false
	_visual.position = Vector3.ZERO
	_puff(16, 2.4)
	_crunch(-12.0, 0.42)


## One crunch per physics step at most, however many tiles go at once.
func _crunch(volume_db: float, pitch: float) -> void:
	var frame := Engine.get_physics_frames()
	if frame - _sound_frame < 4:
		return
	_sound_frame = frame
	Sounds.play_at("thud", global_position, volume_db, pitch)


## A puff of dust chunks from the tile's edges (looks only).
func _puff(amount: int, speed: float) -> void:
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = amount
	particles.lifetime = 0.9
	particles.local_coords = false
	particles.fixed_fps = 0
	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.1, 0.1, 0.1)
	chunk.material = CritterParts.material(DUST_COLOR, 1.0)
	particles.draw_pass_1 = chunk
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	var extent := _extent()
	process.emission_box_extents = Vector3(extent.x * 0.5, 0.05, extent.y * 0.5)
	process.direction = Vector3.UP
	process.spread = 60.0
	process.initial_velocity_min = speed * 0.4
	process.initial_velocity_max = speed
	process.gravity = Vector3(0, -Tuning.gravity * 0.5, 0)
	process.damping_min = 1.0
	process.damping_max = 2.5
	process.scale_min = 0.4
	process.scale_max = 1.1
	process.angular_velocity_min = -300.0
	process.angular_velocity_max = 300.0
	particles.process_material = process
	add_child(particles)
	particles.position = Vector3(_center().x, 0.05, _center().y)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.3, false).timeout.connect(particles.queue_free)


func _center() -> Vector2:
	var c := Vector2.ZERO
	for p in _top:
		c += p
	return c / maxf(_top.size(), 1)


func _extent() -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in _top:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return hi - lo


# ---------------------------------------------------------------- build ----

func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		child.queue_free()
	if corners.size() == 4:
		_top = corners
	else:
		var hx := size.x * 0.5
		var hz := size.z * 0.5
		_top = PackedVector2Array([Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)])
	# Make the corners run anticlockwise seen from above (+Y) for the mesh.
	var area := 0.0
	for i in 4:
		var a := _top[i]
		var b := _top[(i + 1) % 4]
		area += a.x * b.y - b.x * a.y
	if area > 0.0:
		_top.reverse()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_shake_phase = Vector3(rng.randf(), rng.randf(), rng.randf())
	var thick := size.y

	# Collision: the exact slab (flush with its neighbours; the ball's
	# seam smoothing irons out the joins).
	var points := PackedVector3Array()
	for p in _top:
		points.append(Vector3(p.x, 0.0, p.y))
	for p in _top:
		points.append(Vector3(p.x, -thick, p.y))
	var convex := ConvexPolygonShape3D.new()
	convex.points = points
	_collision = CollisionShape3D.new()
	_collision.name = "Collision"
	_collision.shape = convex
	add_child(_collision)

	# Look: slab with a bevelled top, cracks, all one mesh.
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var tint := rng.randf_range(-0.09, 0.07)
	var top_color := color.lightened(tint) if tint > 0.0 else color.darkened(-tint)
	top_color = top_color.lerp(Color(0.56, 0.5, 0.44), rng.randf_range(0.5, 0.7))
	var builder := _MeshBuilder.new()
	var c := _center()
	var inset := PackedVector2Array()
	for p in _top:
		inset.append(p + (c - p).normalized() * 0.07)
	var top_y := 0.0
	var bevel_y := -0.07
	# Top face.
	builder.quad(_v(inset[0], top_y), _v(inset[1], top_y), _v(inset[2], top_y), _v(inset[3], top_y), top_color)
	for i in 4:
		var j := (i + 1) % 4
		# Bevel from the inset top down to the full edge.
		builder.quad(_v(_top[i], bevel_y), _v(_top[j], bevel_y), _v(inset[j], top_y), _v(inset[i], top_y), top_color.darkened(0.25))
		# Side.
		builder.quad(_v(_top[i], -thick), _v(_top[j], -thick), _v(_top[j], bevel_y), _v(_top[i], bevel_y), SIDE_COLOR.lightened(tint))
	builder.quad(_v(_top[3], -thick), _v(_top[2], -thick), _v(_top[1], -thick), _v(_top[0], -thick), SIDE_COLOR.darkened(0.3))
	# Old cracks: a few branching lines from near the middle out toward the edges.
	for k in rng.randi_range(2, 3):
		_crack_line(builder, rng, inset, c, 0.045, CRACK_COLOR, 0.004)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = builder.commit(_shared_material())
	_visual.add_child(mesh_instance)
	# Fresh cracks: hidden until the tile starts to give way.
	var fresh_builder := _MeshBuilder.new()
	for k in 4:
		_crack_line(fresh_builder, rng, inset, c, 0.08, FRESH_CRACK_COLOR, 0.008)
	_fresh = MeshInstance3D.new()
	_fresh.mesh = fresh_builder.commit(_shared_material())
	_fresh.visible = false
	_visual.add_child(_fresh)


func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


## A jagged dark line on the top face from near the middle toward an edge.
func _crack_line(builder: _MeshBuilder, rng: RandomNumberGenerator, top: PackedVector2Array, c: Vector2,
		width: float, crack_color: Color, lift: float) -> void:
	var corner := top[rng.randi_range(0, 3)]
	var other := top[rng.randi_range(0, 3)]
	var target := corner.lerp(other, rng.randf_range(0.2, 0.8))
	var start := c + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
	var steps := 4
	var prev := start
	for s in steps:
		var u := float(s + 1) / steps
		var next := start.lerp(target, u * 0.92)
		if s < steps - 1:
			var side := (target - start).orthogonal().normalized()
			next += side * rng.randf_range(-0.22, 0.22)
		var dir := (next - prev).normalized().orthogonal() * width * (1.0 - u * 0.5)
		builder.quad(_v(prev + dir, lift), _v(prev - dir, lift), _v(next - dir, lift), _v(next + dir, lift), crack_color)
		prev = next


static func _shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true   # match the Blocks' dirt colors
		_material.roughness = 1.0
	return _material


## Collects flat-shaded, vertex-colored quads into one mesh.
class _MeshBuilder:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	## Corners in any order round the quad; the face is shown on the side
	## the corners run anticlockwise when seen from.
	func quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, color: Color) -> void:
		tri(p0, p1, p2, color)
		tri(p0, p2, p3, color)

	func tri(p0: Vector3, p1: Vector3, p2: Vector3, color: Color) -> void:
		var normal := (p1 - p0).cross(p2 - p0)
		if normal.length_squared() < 0.0000001:
			return
		normal = normal.normalized()
		# Godot front faces are clockwise as seen by the viewer.
		for p in [p0, p2, p1]:
			vertices.append(p)
			normals.append(normal)
			colors.append(color)

	func commit(material: Material) -> ArrayMesh:
		var mesh := ArrayMesh.new()
		if vertices.is_empty():
			return mesh
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material)
		return mesh
