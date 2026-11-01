class_name CaveAnt
extends Node3D
## CAVE ANT -- a low-poly six-legged ant built from shapes, crawling on
## all six legs (unlike the hero, who stands on two). No collision: these
## are decoration, and the Queen is a cutscene actor.
##
## Worker ants live on the hub's walls: they wait inside a small hole, poke
## their head out and look around, or crawl across the wall and ceiling to
## another hole and disappear into it (see src/objects/hub/cave_shell.gd
## for the holes and the wall surface they walk on).
##
## With `queen` on it is the Queen Ant: twice the size, a bigger abdomen, a
## crown of spikes on her head, and no mind of her own; the cutscene moves
## her with emerge_from_hole(), walk_floor_to() and face_point().
##
## Local space: feet at y = 0, facing -Z, "up" is +Y. On a wall the whole
## node is tilted so +Y is the wall's inward normal.

@export var queen := false
@export var body_scale := 1.0
## Crawling speed in m/s (workers; the Queen gets her own when asked to walk).
@export var speed := 2.4

signal path_finished
## The thorax swing just hit (see swing_thorax).
signal struck

enum State { HIDDEN, PEEKING, TRAVELLING, IDLE }

## The cave shell whose holes this ant uses (workers).
var shell: CaveShell
var state := State.IDLE

const BODY := Color(0.42, 0.18, 0.09)
const DARK := Color(0.2, 0.08, 0.04)
const QUEEN_BODY := Color(0.5, 0.15, 0.1)
const QUEEN_DARK := Color(0.25, 0.07, 0.05)
const CROWN := Color(0.95, 0.75, 0.25)
const EYE := Color(0.02, 0.02, 0.02)

var _body: Node3D
var _head: Node3D
var _eye_material: StandardMaterial3D
var _brows: Node3D
var _steam: Array[GPUParticles3D] = []
var _eyes: Array[MeshInstance3D] = []
var _blush: Node3D
## Clapping: seconds left (< 0 = not clapping) and the clap count so far.
var _clap_time := -1.0
## Rearing up (0..1): the body tips back and lifts so the abdomen tip
## stays on the ground and the front legs come up off it.
var _rear := 0.0
var _clap_total := 0.0
var _claps_heard := 0
## The hole she lives in (the Queen goes back to it).
var home_hole: Dictionary = {}
var _legs: Array[Dictionary] = []
var _antennae: Array[Node3D] = []
var _time := 0.0
var _gait := 0.0
var _moving_speed := 0.0
var _look := 0.0            # extra head yaw, for looking around
var _look_target := 0.0

# Path following: keyframes with distances along the path.
var _path: Array[Transform3D] = []
var _path_dist: PackedFloat32Array
var _dist := 0.0
var _path_speed := 0.0
# Worker behaviour.
var _hole: Dictionary = {}
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_build()
	_rng.seed = get_instance_id() % 10007


# -------------------------------------------------------------- body ----

func _build() -> void:
	var body_mat := CritterParts.material(QUEEN_BODY if queen else BODY, 0.85)
	var dark_mat := CritterParts.material(QUEEN_DARK if queen else DARK, 0.8)
	var eye_mat := CritterParts.material(EYE, 0.3)
	if queen:
		# Her own eye material, so only her eyes turn red when she's angry.
		eye_mat = eye_mat.duplicate() as StandardMaterial3D
		_eye_material = eye_mat
	var s := body_scale * (2.4 if queen else 1.0)
	scale = Vector3.ONE * s
	_body = Node3D.new()
	add_child(_body)
	var y := 0.13
	# Abdomen: egg pointing back (and much bigger on the Queen).
	var abdomen := CritterParts.sphere(_body, Vector3(0.0, y + 0.01, 0.15), 0.1,
			Vector3(1.0, 0.95, 1.4) * (1.45 if queen else 1.0), body_mat, 10)
	abdomen.rotation.x = -0.15
	if queen:
		abdomen.position = Vector3(0.0, y + 0.05, 0.22)
		# Pale bands on the royal abdomen.
		var band_mat := CritterParts.material(Color(0.78, 0.55, 0.35), 0.8)
		for i in 3:
			CritterParts.sphere(_body, abdomen.position + Vector3(0.0, 0.0, -0.04 + i * 0.06), 0.1,
					Vector3(1.36, 1.3, 0.3), band_mat, 10)
	# Thorax and the waist.
	CritterParts.sphere(_body, Vector3(0.0, y, -0.02), 0.07, Vector3(1.0, 0.9, 1.1), body_mat, 10)
	CritterParts.sphere(_body, Vector3(0.0, y + 0.005, 0.06), 0.035, Vector3.ONE, dark_mat, 8)
	# Head on a pivot so it can look around and tilt.
	_head = Node3D.new()
	_head.position = Vector3(0.0, y + 0.01, -0.1)
	_body.add_child(_head)
	CritterParts.sphere(_head, Vector3(0.0, 0.0, -0.045), 0.07, Vector3(1.05, 0.95, 1.05), body_mat, 10)
	for side in [1.0, -1.0]:
		_eyes.append(CritterParts.sphere(_head, Vector3(side * 0.045, 0.02, -0.095), 0.018, Vector3.ONE, eye_mat, 8))
		# Mandibles.
		CritterParts.rod(_head, Vector3(side * 0.03, -0.03, -0.1), Vector3(side * 0.01, -0.035, -0.14), 0.008, dark_mat)
		var antenna := Node3D.new()
		antenna.position = Vector3(side * 0.025, 0.04, -0.09)
		_head.add_child(antenna)
		CritterParts.rod(antenna, Vector3.ZERO, Vector3(side * 0.05, 0.08, -0.08), 0.007, dark_mat)
		CritterParts.rod(antenna, Vector3(side * 0.05, 0.08, -0.08), Vector3(side * 0.09, 0.09, -0.14), 0.006, dark_mat)
		_antennae.append(antenna)
	if queen:
		# A crown of spikes around the top of the head.
		var crown_mat := CritterParts.material(CROWN, 0.4)
		for i in 6:
			var a := TAU * float(i) / 6.0
			var spike := CylinderMesh.new()
			spike.top_radius = 0.0
			spike.bottom_radius = 0.014
			spike.height = 0.06
			spike.radial_segments = 5
			spike.rings = 1
			spike.material = crown_mat
			var instance := MeshInstance3D.new()
			instance.mesh = spike
			instance.position = Vector3(cos(a) * 0.045, 0.065, -0.045 + sin(a) * 0.045)
			instance.rotation = Vector3(sin(a) * 0.35, 0.0, -cos(a) * 0.35)
			_head.add_child(instance)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.04
		ring.outer_radius = 0.055
		ring.rings = 8
		ring.ring_segments = 5
		ring.material = crown_mat
		var ring_instance := MeshInstance3D.new()
		ring_instance.mesh = ring
		ring_instance.position = Vector3(0.0, 0.05, -0.045)
		_head.add_child(ring_instance)
		_build_anger(dark_mat)
	# Six legs: hip on the thorax, knee up and out, foot on the ground.
	for i in 3:
		for side in [1.0, -1.0]:
			var z := -0.09 + i * 0.07
			var hip := Vector3(side * 0.04, y - 0.01, z)
			var rest := Vector3(side * 0.19, 0.0, z + (-0.1 if i == 0 else (0.0 if i == 1 else 0.1)))
			var femur := CritterParts.rod(self, hip, hip, 0.011, dark_mat)
			var tibia := CritterParts.rod(self, hip, rest, 0.009, dark_mat)
			_legs.append({"hip": hip, "rest": rest, "side": side, "femur": femur, "tibia": tibia,
					"phase": 0.0 if (i == 1) == (side < 0.0) else 0.5})
	_pose_legs(0.0, 0.0)


func _pose_legs(gait: float, amount: float) -> void:
	for leg in _legs:
		var p := fposmod(gait + float(leg.phase), 1.0)
		var step := _step(p)
		var rest: Vector3 = leg.rest
		var foot := rest + Vector3(0.0, step.y * 0.05 * amount, -step.x * 0.06 * amount)
		var hip: Vector3 = leg.hip
		var mid := (hip + foot) * 0.5
		var knee := mid + Vector3(float(leg.side) * 0.05, 0.09, 0.0)
		CritterParts.set_rod(leg.femur, hip, knee)
		CritterParts.set_rod(leg.tibia, knee, foot)


## Foot cycle: planted for 60% (sliding back), then lifted and swung forward.
static func _step(phase: float) -> Vector2:
	if phase < 0.6:
		return Vector2(lerpf(1.0, -1.0, phase / 0.6), 0.0)
	var u := (phase - 0.6) / 0.4
	return Vector2(lerpf(-1.0, 1.0, smoothstep(0.0, 1.0, u)), sin(u * PI))


func _process(delta: float) -> void:
	_time += delta
	if not _path.is_empty():
		_follow_path(delta)
	elif shell and not queen:
		_worker_brain(delta)
	# Legs step when moving; otherwise a little breathing and antenna waving.
	var moving := clampf(_moving_speed / 1.5, 0.0, 1.0)
	_gait = fposmod(_gait + delta * (1.6 + _moving_speed * 1.1) * moving, 1.0)
	_pose_legs(_gait, moving)
	_clap(delta)
	_body.position.y = sin(_time * 2.4) * 0.004 * (1.0 - moving) + absf(sin(_gait * TAU * 2.0)) * 0.006 * moving \
			+ sin(_rear * CLAP_REAR) * 0.2
	_look = lerpf(_look, _look_target, 1.0 - exp(-delta * 4.0))
	_head.rotation.y = _look + sin(_time * 1.1) * 0.05
	for i in _antennae.size():
		var a := _antennae[i]
		a.rotation.x = sin(_time * 1.7 + i * 2.0) * 0.12 + moving * sin(_gait * TAU * 2.0 + i * PI) * 0.1
		a.rotation.z = (1.0 if i == 0 else -1.0) * 0.04 * sin(_time * 0.9 + i)


# --------------------------------------------------------------- path ----

## Follows a list of keyframes (origin = feet, Y = up, -Z = forward) at a
## constant speed, blending orientation between them.
func set_path(keys: Array[Transform3D], path_speed: float) -> void:
	_path = keys
	_path_speed = path_speed
	_path_dist = PackedFloat32Array()
	_path_dist.append(0.0)
	for i in range(1, keys.size()):
		_path_dist.append(_path_dist[i - 1] + keys[i - 1].origin.distance_to(keys[i].origin))
	_dist = 0.0
	if not keys.is_empty():
		global_transform = _scaled(keys[0])


func _follow_path(delta: float) -> void:
	_dist += _path_speed * delta
	_moving_speed = _path_speed
	var total := _path_dist[_path_dist.size() - 1]
	if _dist >= total or _path.size() < 2:
		global_transform = _scaled(_path[_path.size() - 1])
		_path = []
		_moving_speed = 0.0
		path_finished.emit()
		return
	var i := 0
	while i < _path_dist.size() - 2 and _path_dist[i + 1] < _dist:
		i += 1
	var seg := _path_dist[i + 1] - _path_dist[i]
	var u := (_dist - _path_dist[i]) / maxf(seg, 0.0001)
	var a := _path[i]
	var b := _path[i + 1]
	var origin := a.origin.lerp(b.origin, u)
	var basis := Basis(a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), u))
	global_transform = _scaled(Transform3D(basis, origin))


func _scaled(xf: Transform3D) -> Transform3D:
	return Transform3D(xf.basis.orthonormalized().scaled(scale), xf.origin)


## Keyframes along the cave wall between two (angle, t) spots.
static func wall_path(cave: CaveShell, a0: float, t0: float, a1: float, t1: float) -> Array[Transform3D]:
	var keys: Array[Transform3D] = []
	var start := cave.surface_transform(a0, t0).origin
	var end := cave.surface_transform(a1, t1).origin
	var n := maxi(int(start.distance_to(end) / 0.5), 4)
	var da := wrapf(a1 - a0, -180.0, 180.0)
	var points: Array[Transform3D] = []
	for i in n + 1:
		var u := float(i) / n
		points.append(cave.surface_transform(a0 + da * u, lerpf(t0, t1, u)))
	for i in n + 1:
		var xf := points[i]
		var next := points[mini(i + 1, n)]
		var prev := points[maxi(i - 1, 0)]
		var forward := next.origin - prev.origin
		var up := xf.basis.y
		forward -= up * forward.dot(up)
		if forward.length_squared() < 0.0001:
			forward = -xf.basis.z
		keys.append(Transform3D(Basis.looking_at(forward.normalized(), up), xf.origin))
	return keys


## Keyframes straight across the floor from a to b (both at foot height).
static func floor_path(a: Vector3, b: Vector3) -> Array[Transform3D]:
	var keys: Array[Transform3D] = []
	var forward := b - a
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	var basis := Basis.looking_at(forward.normalized(), Vector3.UP)
	keys.append(Transform3D(basis, a))
	keys.append(Transform3D(basis, b))
	return keys


## In and out of a hole: from `depth_in` meters inside the wall to
## `depth_out` meters out of it (negative = still inside), facing out.
static func hole_path(hole: Dictionary, depth_in: float, depth_out: float) -> Array[Transform3D]:
	var xf: Transform3D = hole.transform
	var normal := xf.basis.y
	var keys: Array[Transform3D] = []
	# Facing out of the hole: forward is along the normal; "up" for the ant
	# is up the wall (so it crawls out like through a doorway in the wall),
	# which keeps its feet on the lip as it turns onto the wall.
	var up := -xf.basis.z
	var basis := Basis.looking_at(normal, up)
	keys.append(Transform3D(basis, xf.origin - normal * depth_in))
	keys.append(Transform3D(basis, xf.origin + normal * depth_out))
	return keys


# ------------------------------------------------------------ workers ----

## Puts a worker inside a hole, out of sight.
func hide_in_hole(hole: Dictionary) -> void:
	if home_hole.is_empty():
		home_hole = hole
	_hole = hole
	state = State.HIDDEN
	_timer = _rng.randf_range(0.5, 6.0)
	var keys := hole_path(hole, 1.2, -1.2)
	global_transform = _scaled(keys[0])
	_moving_speed = 0.0


func _worker_brain(delta: float) -> void:
	_timer -= delta
	match state:
		State.HIDDEN:
			if _timer <= 0.0 and not _hole.is_empty():
				if _rng.randf() < 0.45:
					_start_peek()
				else:
					_start_travel()
		State.PEEKING:
			if _timer <= 0.0:
				_look_target = 0.0
				state = State.HIDDEN
				_timer = _rng.randf_range(0.8, 2.0)
				set_path(hole_path(_hole, -0.25, -1.2), 1.2)
				_timer += 1.0
			elif fmod(_timer, 0.9) < delta:
				_look_target = _rng.randf_range(-0.7, 0.7)
		State.TRAVELLING:
			pass   # path_finished moves things along
		State.IDLE:
			pass


func _start_peek() -> void:
	state = State.PEEKING
	_timer = _rng.randf_range(1.5, 3.5)
	set_path(hole_path(_hole, 1.2, -0.25), 1.0)


func _start_travel() -> void:
	if shell.holes.size() < 2:
		return
	var target: Dictionary = shell.holes[_rng.randi() % shell.holes.size()]
	var tries := 0
	while target == _hole and tries < 10:
		target = shell.holes[_rng.randi() % shell.holes.size()]
		tries += 1
	state = State.TRAVELLING
	# Out of the hole, across the wall, into the next hole.
	var keys := hole_path(_hole, 1.2, 0.2)
	var across := wall_path(shell, _hole.angle, _hole.t, target.angle, target.t)
	keys.append_array(across)
	keys.append_array(hole_path(target, -0.2, -1.3))
	var next := target
	set_path(keys, speed * _rng.randf_range(0.8, 1.2))
	if not path_finished.is_connected(_on_travel_done):
		path_finished.connect(_on_travel_done, CONNECT_ONE_SHOT)
	_hole = next


func _on_travel_done() -> void:
	if state == State.TRAVELLING:
		hide_in_hole(_hole)


# -------------------------------------------------------------- queen ----

## Crawls out of a hole, down the wall to the floor, and across the floor
## to `settle_at`, ending up facing `face`. Awaitable.
func emerge_from_hole(cave: CaveShell, hole: Dictionary, settle_at: Vector3, face: Vector3, walk_speed := 5.0) -> void:
	var keys := hole_path(hole, 1.4, 0.3)
	keys.append_array(wall_path(cave, hole.angle, hole.t, hole.angle, 0.0))
	var foot := keys[keys.size() - 1].origin
	foot.y = 0.0
	var toward := settle_at - foot
	toward.y = 0.0
	keys.append_array(floor_path(foot, foot + toward.normalized() * 0.5))
	keys.append_array(floor_path(foot + toward.normalized() * 0.5, settle_at))
	set_path(keys, walk_speed)
	await path_finished
	await face_point(face)


## Turns on the spot to look at a point. Awaitable.
func face_point(point: Vector3, seconds := 0.5) -> void:
	var forward := point - global_position
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return
	var from := global_transform.basis.get_rotation_quaternion()
	var to := Basis.looking_at(forward.normalized(), Vector3.UP).get_rotation_quaternion()
	var t := 0.0
	while t < seconds:
		t += get_process_delta_time()
		var q := from.slerp(to, smoothstep(0.0, 1.0, t / seconds))
		global_transform = _scaled(Transform3D(Basis(q), global_position))
		await get_tree().process_frame
	global_transform = _scaled(Transform3D(Basis(to), global_position))


## Walks straight across the floor. Awaitable.
func walk_floor_to(point: Vector3, walk_speed := 4.0) -> void:
	set_path(floor_path(global_position, point), walk_speed)
	await path_finished


## Cutscene steps aimed at this ant ({"do": "actor", "actor": ..., "action": ...}):
##   emerge   hole, settle (a spot), face (an actor), speed, camera_follow
##   walk_to  to (a spot or actor), speed
##   face     target (an actor)
##   nod
##   mood     mood ("angry" / "happy" / "calm"), hold (seconds to wait after)
##   celebrate  claps: hops up and claps her front legs with a happy face
##   go_home  speed, await (false = let the scene move on while she
##            crawls), instant (true = straight back inside, for skips)
func cutscene_action(action: String, step: Dictionary, player: Node) -> void:
	match action:
		"emerge":
			var hole = player.resolve(str(step.get("hole", "")))
			var cave = player.resolve("cave")
			if hole is not Dictionary or cave is not CaveShell:
				push_warning("CaveAnt: emerge needs a hole and the 'cave' actor")
				return
			var settle: Vector3 = player.position_of(player.resolve(str(step.get("settle", ""))))
			var face: Vector3 = player.position_of(player.resolve(str(step.get("face", ""))))
			if step.get("camera_follow", false):
				player.shot(self, player.shot_params("queen", "walk"), 1.0)
			await emerge_from_hole(cave, hole, settle, face, float(step.get("speed", 5.0)))
		"walk_to":
			await walk_floor_to(player.position_of(player.resolve(str(step.get("to", "")))), float(step.get("speed", 4.0)))
		"face":
			await face_point(player.position_of(player.resolve(str(step.get("target", "")))))
		"nod":
			nod()
		"mood":
			set_mood(str(step.get("mood", "calm")))
			await get_tree().create_timer(float(step.get("hold", 0.6))).timeout
		"celebrate":
			await celebrate(int(step.get("claps", 6)))
		"go_home":
			var cave = player.resolve("cave")
			if step.get("instant", false):
				set_mood("calm")
				_path = []
				hide_in_hole(home_hole)
				return
			if step.get("await", true):
				await go_home(cave, float(step.get("speed", 6.0)))
			else:
				go_home(cave, float(step.get("speed", 6.0)))


# -------------------------------------------------------------- anger ----

## The Queen's angry face, hidden until set_mood("angry"): heavy brows
## slanting down to the middle, and steam puffing out of both sides of
## her head.
func _build_anger(brow_material: Material) -> void:
	# Rosy cheeks for her happy face.
	_blush = Node3D.new()
	_blush.name = "Blush"
	_blush.visible = false
	_head.add_child(_blush)
	var pink := CritterParts.material(Color(1.0, 0.72, 0.78), 0.6)
	for side in [1.0, -1.0]:
		CritterParts.sphere(_blush, Vector3(side * 0.062, -0.022, -0.088), 0.015, Vector3(1.4, 0.6, 0.5), pink, 8)
	_brows = Node3D.new()
	_brows.name = "Brows"
	_brows.visible = false
	_head.add_child(_brows)
	var brow_black := CritterParts.material(Color(0.02, 0.01, 0.01), 0.6)
	for side in [1.0, -1.0]:
		# Outer end high, inner end low and forward: a scowl, sitting just
		# above each eye, thick and black so it reads on her dark head.
		CritterParts.rod(_brows, Vector3(side * 0.078, 0.066, -0.098), Vector3(side * 0.014, 0.036, -0.128), 0.015, brow_black)
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 8
	puff.rings = 4
	var steam_material := StandardMaterial3D.new()
	steam_material.albedo_color = Color(1.0, 1.0, 1.0, 0.75)
	steam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	steam_material.vertex_color_use_as_albedo = true
	puff.material = steam_material
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	var grow := Curve.new()
	grow.max_value = 2.5   # set before the points, or they get clamped to 1
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 2.2))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	for side in [1.0, -1.0]:
		# Puffs of steam from the top of her head, rising and swelling. Local
		# coordinates keep them at her head (and scaled with her).
		var steam := GPUParticles3D.new()
		steam.name = "Steam"
		steam.emitting = false
		steam.amount = 10
		steam.lifetime = 0.75
		steam.local_coords = true
		steam.draw_pass_1 = puff
		steam.position = Vector3(side * 0.05, 0.08, -0.03)
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(side * 0.6, 1.0, 0.0)
		process.spread = 14.0
		process.initial_velocity_min = 0.22
		process.initial_velocity_max = 0.32
		process.gravity = Vector3(0.0, 0.12, 0.0)
		process.damping_min = 0.15
		process.damping_max = 0.25
		process.scale_min = 0.045
		process.scale_max = 0.065
		process.scale_curve = grow_texture
		process.color_ramp = fade_texture
		steam.process_material = process
		_head.add_child(steam)
		_steam.append(steam)


## "angry": red glowing eyes, scowling brows, steam, a furious head
## shake. Anything else: back to calm.
func set_mood(mood: String) -> void:
	var angry := mood == "angry"
	var happy := mood == "happy"
	# Happy: eyes squeezed into smiling slits, rosy cheeks, antennae up.
	for eye in _eyes:
		eye.scale = Vector3(1.25, 0.3, 1.0) if happy else Vector3.ONE
		eye.position.y = 0.028 if happy else 0.02
	if _blush:
		_blush.visible = happy
	if _brows:
		_brows.visible = angry
	for steam in _steam:
		steam.emitting = angry
	if _eye_material:
		_eye_material.albedo_color = Color(0.9, 0.05, 0.03) if angry else EYE
		_eye_material.emission_enabled = angry
		_eye_material.emission = Color(1.0, 0.1, 0.05)
		_eye_material.emission_energy_multiplier = 2.5
	if angry:
		var shake := create_tween()
		for i in 6:
			shake.tween_property(_head, "rotation:z", 0.18 if i % 2 == 0 else -0.18, 0.06)
		shake.tween_property(_head, "rotation:z", 0.0, 0.08)


# ---------------------------------------------------------- celebrate ----

const CLAP_RATE := 3.2       # claps per second
const CLAP_REAR := 0.95      # how far she rears up to free her front legs (rad)

## Delighted: a happy face, she rears up on her back legs and claps her two
## front legs together, hopping. Awaitable.
func celebrate(claps := 6) -> void:
	set_mood("happy")
	_clap_total = claps / CLAP_RATE
	_clap_time = _clap_total
	_claps_heard = 0
	var rear := create_tween().set_parallel(true)
	rear.tween_property(_body, "rotation:x", CLAP_REAR, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rear.tween_property(self, "_rear", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Two little hops while clapping.
	var base_y := position.y
	var hops := create_tween()
	for i in 2:
		hops.tween_property(self, "position:y", base_y + 0.55, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hops.tween_property(self, "position:y", base_y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		hops.tween_interval(0.25)
	await get_tree().create_timer(_clap_total + 0.1).timeout
	var down := create_tween().set_parallel(true)
	down.tween_property(_body, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	down.tween_property(self, "_rear", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await down.finished


## While clapping, the front pair of legs is lifted in front of her and
## brought together and apart (overrides the walking pose).
func _clap(delta: float) -> void:
	if _clap_time < 0.0:
		return
	_clap_time -= delta
	var elapsed := _clap_total - _clap_time
	var phase := elapsed * CLAP_RATE
	# 0 = legs apart, 1 = touching; snappy shut, slower open.
	var shut := pow(0.5 + 0.5 * cos(phase * TAU), 3.0)
	var count := int(phase + 0.5)
	if count > _claps_heard and shut > 0.9:
		_claps_heard = count
		Sounds.play_at("menu_change", global_position + Vector3.UP, -2.0, randf_range(1.5, 1.8))
	for i in 2:   # the two front legs come first in _legs
		var leg: Dictionary = _legs[i]
		var side: float = leg.side
		var hip: Vector3 = _body.transform * (leg.hip as Vector3)
		# Hands meet in front of her face (worked out from where the head is
		# now, since she's rearing).
		var face := _body.transform * _head.position
		var hand := face + Vector3(side * lerpf(0.12, 0.01, shut), 0.02, -0.14)
		var knee := (hip + hand) * 0.5 + Vector3(side * 0.06, -0.02, 0.0)
		CritterParts.set_rod(leg.femur, hip, knee)
		CritterParts.set_rod(leg.tibia, knee, hand)
	if _clap_time < 0.0:
		_clap_time = -1.0


## Crawls back across the floor, up the wall and into her own hole, then
## stays hidden there. Awaitable.
func go_home(cave: CaveShell, walk_speed := 6.0) -> void:
	if home_hole.is_empty() or cave == null:
		return
	set_mood("calm")
	var hole := home_hole
	var foot := cave.surface_transform(hole.angle, 0.0).origin
	foot.y = 0.0
	var keys: Array[Transform3D] = []
	var here := global_position
	here.y = 0.0
	keys.append_array(floor_path(here, foot))
	keys.append_array(wall_path(cave, hole.angle, 0.0, hole.angle, hole.t))
	# Into the hole: facing into the wall, "up" up the wall.
	var xf: Transform3D = hole.transform
	var normal := xf.basis.y
	var inward := Basis.looking_at(-normal, -xf.basis.z)
	keys.append(Transform3D(inward, xf.origin + normal * 0.3))
	keys.append(Transform3D(inward, xf.origin - normal * 1.5))
	set_path(keys, walk_speed)
	global_position = here   # start where she stands (set_path jumps to key 0)
	await path_finished
	state = State.HIDDEN


## Winds her body back, then swings her thorax forward through whatever is
## in front of her head. `struck` fires at the moment of contact. Awaitable.
func swing_thorax() -> void:
	var tween := create_tween()
	# Wind-up: twist away and rear up.
	tween.tween_property(_body, "rotation", Vector3(0.35, 0.9, 0.0), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_body, "position:z", 0.06, 0.45)
	tween.tween_interval(0.2)
	# The swing: fast, lunging forward and down.
	tween.tween_property(_body, "rotation", Vector3(-0.3, -0.6, 0.0), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_body, "position:z", -0.12, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): struck.emit())
	tween.tween_interval(0.35)
	tween.tween_property(_body, "rotation", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_body, "position:z", 0.0, 0.5)
	await tween.finished


## A little nod of the head (talking).
func nod() -> void:
	var tween := create_tween()
	tween.tween_property(_head, "rotation:x", 0.25, 0.12)
	tween.tween_property(_head, "rotation:x", 0.0, 0.18)
