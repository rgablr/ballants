@tool
extends Node3D
## PLACEHOLDER ANT -- a low-poly ant standing upright on its two back legs,
## assembled from basic shapes in code. Its front and middle legs are held
## out like arms for balance.
##
## The back feet are placed ON the ball's surface every frame (a small
## two-bone "IK" solve per leg), so they never float or sink. Walking is a
## gait: a foot stays planted for most of the cycle, then lifts and swings
## forward, while the arms swing opposite, the body dips and sways, and the
## antennae bob. Idle breathing, a crouched balancing pose at high speed
## and tucked legs in the air. All the numbers are constants below.
##
## Any model that replaces this (via the "ant" entry in asset_manifest.gd)
## only needs to match:
##   1. Feet at the origin (y = 0), facing -Z (Godot's "forward").
##   2. Optionally set_walk_speed(speed), set_airborne(bool) and
##      set_ball_radius(radius) methods to animate. All are optional;
##      without them the model just stands.

const BODY_COLOR := Color(0.45, 0.19, 0.10)
const DARK_COLOR := Color(0.22, 0.09, 0.05)
const EYE_COLOR := Color(0.03, 0.03, 0.03)

# --- Walk cycle -------------------------------------------------------
# A real gait instead of a sped-up shuffle: each back foot is PLANTED for
# most of the cycle (sliding back with the ball's surface), then LIFTS and
# swings forward. The cadence rises with speed but is capped, so at top
# speed the ant takes longer, bouncier strides rather than a blur of legs.
const IDLE_SPEED := 0.25        # below this ball speed (m/s) the ant stands
const CADENCE_SLOW := 1.3       # leg cycles per second at a walk
const CADENCE_FAST := 2.6       # leg cycles per second at a run (the cap)
const RUN_SPEED := 8.0          # ball speed (m/s) at which the run is reached
const STANCE := 0.62            # fraction of a cycle a foot is planted
const STRIDE_SLOW := 0.03       # how far a foot travels front-to-back, half (m)
const STRIDE_FAST := 0.075
const LIFT := 0.045             # how high a stepping foot lifts (m)
const BOB := 0.016              # body dips at each footfall (m)
const SWAY := 0.09              # body rolls toward the planted foot (radians)
const ARM_SWING := 0.7          # arms swing opposite the legs (radians)
const LEAN := 0.22              # forward lean at a run (radians)
# --- Balancing at high speed --------------------------------------------
# Above BALANCE_SPEED the ant shortens its steps, crouches and spreads its
# arms like someone riding a log down a river.
const BALANCE_SPEED := 9.5
const BALANCE_FULL := 12.5
const CROUCH := 0.035
# --- In the air -----------------------------------------------------------
const TUCK := 0.05              # feet pull up this far while airborne
const FLAIL_RATE := 13.0        # how fast legs kick and arms wave in the air (rad/s)
# --- Crawling (top speed) -------------------------------------------------
# At 75% of top speed and up the ant drops onto all six legs and scuttles
# along the top of the ball, body flat; it stands back up when it slows.
const CRAWL_PITCH := 1.2        # how far the body tips forward (radians, ~70°)
const CRAWL_BACK := 0.17        # body slides back so it lies on top of the ball (m)
const CRAWL_LOWER := 0.0        # and drops this much (m); 0 keeps the legs in view
const CRAWL_CADENCE := 1.6      # extra leg-cycle speed when crawling (x)
# --- Teetering (sharp turns) ----------------------------------------------
const TEETER_SWAY := 0.35       # side-to-side body wobble (radians)
const TEETER_RATE := 10.0       # wobble speed (rad/s)

const HIP_OFFSET := Vector3(0.045, 0.21, 0.03)   # back-leg hip, right side (x mirrored for left)
const FOOT_REST := Vector3(0.12, 0.0, 0.02)      # where a back foot rests, right side
const FEMUR := 0.15             # upper leg length
const TIBIA := 0.17             # lower leg length

var _ball_radius := 0.5
var _walk_phase := 0.0
var _walk_speed := 0.0
var _speed := 0.0               # smoothed speed, so the gait never jerks
var _air := 0.0                 # 0 = on the ball, 1 = airborne pose
var _airborne := false
var _time := 0.0
var _crawl := 0.0               # 0 = standing, 1 = on all six legs
var _crawl_target := 0.0
var _teeter := 0.0

var _body: Node3D
var _neck: Node3D                   # head pivot: tilts for gestures
var _eyes: Array[MeshInstance3D] = []
var _gesture_tween: Tween
var _legs: Array[Dictionary] = []   # each: {side, femur, tibia}


## Cutscene gestures: "blink" (eyes squeeze shut and open), "tilt" (head
## cocks to one side, holds, comes back), "nod".
func play_gesture(gesture: String) -> void:
	if _neck == null:
		return
	if _gesture_tween and _gesture_tween.is_valid():
		_gesture_tween.kill()
	_neck.rotation = Vector3.ZERO
	for eye in _eyes:
		eye.scale = Vector3.ONE
	_gesture_tween = create_tween()
	match gesture:
		"blink":
			_gesture_tween.tween_interval(0.25)
			for eye in _eyes:
				_gesture_tween.parallel().tween_property(eye, "scale:y", 0.1, 0.07)
			_gesture_tween.tween_interval(0.12)
			for eye in _eyes:
				_gesture_tween.parallel().tween_property(eye, "scale:y", 1.0, 0.1)
			_gesture_tween.tween_interval(0.9)
			for eye in _eyes:
				_gesture_tween.parallel().tween_property(eye, "scale:y", 0.1, 0.07)
			_gesture_tween.tween_interval(0.1)
			for eye in _eyes:
				_gesture_tween.parallel().tween_property(eye, "scale:y", 1.0, 0.1)
		"tilt":
			_gesture_tween.tween_interval(0.2)
			_gesture_tween.tween_property(_neck, "rotation:z", 0.42, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_gesture_tween.tween_interval(1.1)
			_gesture_tween.tween_property(_neck, "rotation:z", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"nod":
			_gesture_tween.tween_property(_neck, "rotation:x", 0.3, 0.14)
			_gesture_tween.tween_property(_neck, "rotation:x", 0.0, 0.2)
		_:
			_gesture_tween.kill()
var _arms: Array[Dictionary] = []   # each: {pivot, side, front}
var _antennae: Array[Node3D] = []
## One material per recolorable part (see set_part_color).
var _part_materials := {}


func _ready() -> void:
	_build()


func set_walk_speed(speed: float) -> void:
	_walk_speed = speed


## Optional: true while the ball is in the air (the ant tucks its legs).
func set_airborne(airborne: bool) -> void:
	_airborne = airborne


## Optional: 1 = crawl on all six legs (top speed), 0 = stand. The model
## blends between the two over about a third of a second.
func set_crawl(amount: float) -> void:
	_crawl_target = clampf(amount, 0.0, 1.0)


## Optional: 0..1, how close to falling off in a sharp turn (wobbles and
## windmills its arms).
func set_teeter(amount: float) -> void:
	_teeter = clampf(amount, 0.0, 1.0)


## Optional: recolors one part: "head", "thorax", "abdomen", "antennae",
## "legs" (all six) or "eyes". Used by the customize menu.
func set_part_color(part: String, color: Color) -> void:
	if _part_materials.has(part):
		(_part_materials[part] as StandardMaterial3D).albedo_color = color


## Radius of the ball the ant stands on, in this model's units.
func set_ball_radius(ball_radius: float) -> void:
	_ball_radius = max(ball_radius, 0.05)


func _process(delta: float) -> void:
	_time += delta
	_speed = lerpf(_speed, _walk_speed, 1.0 - exp(-delta * 6.0))
	_air = move_toward(_air, 1.0 if _airborne else 0.0, delta * 6.0)
	_crawl = move_toward(_crawl, _crawl_target, delta * 3.0)
	var crawl := smoothstep(0.0, 1.0, _crawl)
	var walking := clampf((_speed - IDLE_SPEED) / 1.0, 0.0, 1.0)
	var run := clampf(_speed / RUN_SPEED, 0.0, 1.0)
	var balance := smoothstep(BALANCE_SPEED, BALANCE_FULL, _speed) * (1.0 - crawl)
	var ground := 1.0 - _air
	var amount := walking * ground
	var cadence := lerpf(CADENCE_SLOW, CADENCE_FAST, run) * (1.0 - balance * 0.35) * lerpf(1.0, CRAWL_CADENCE, crawl)
	if not Engine.is_editor_hint():
		_walk_phase = fposmod(_walk_phase + delta * cadence * walking, 1.0)
	var stride := lerpf(STRIDE_SLOW, STRIDE_FAST, run) * (1.0 - balance * 0.5) * amount
	var flail := _time * FLAIL_RATE
	var wobble := sin(_time * TEETER_RATE) * TEETER_SWAY * _teeter * ground

	# Body: dips at each footfall, rolls toward the planted foot, leans
	# forward with speed, crouches when balancing, breathes when idle;
	# tips flat onto the ball when crawling; wobbles when teetering.
	var dip := 0.5 + 0.5 * cos(TAU * 2.0 * (_walk_phase - STANCE * 0.5))
	var breathe := sin(_time * 2.2) * 0.006 * (1.0 - walking)
	_body.position.y = -dip * BOB * amount - CROUCH * balance + breathe + _air * 0.02 - CRAWL_LOWER * crawl
	_body.position.z = CRAWL_BACK * crawl
	_body.rotation.x = lerpf(-LEAN * run * walking - 0.1 * balance - 0.15 * _air, -CRAWL_PITCH, crawl)
	_body.rotation.z = sin(TAU * (_walk_phase - STANCE * 0.5)) * SWAY * amount * (1.0 - balance) * (1.0 - crawl) + wobble
	_body.rotation.y = sin(TAU * _walk_phase) * 0.05 * amount

	# Back legs: planted, then lifted and swung forward. In the air they
	# kick wildly. Crawling, the feet reach further back.
	for i in _legs.size():
		var leg: Dictionary = _legs[i]
		var side: float = leg.side
		var p := fposmod(_walk_phase + 0.5 * i, 1.0)
		var step := _step(p)
		var z := -step.x * stride
		var lift := step.y * LIFT * amount
		var spread := 0.025 * balance + 0.03 * crawl
		var foot := Vector3((FOOT_REST.x + spread + 0.06 * crawl) * side, 0.0, FOOT_REST.z + z + 0.07 * crawl)
		foot.y = _height_on_ball(foot.x, foot.z) + lift + TUCK * _air
		if _air > 0.0:
			var kick := Vector3(0.0, 0.05 + 0.05 * cos(flail + i * PI), sin(flail + i * PI) * 0.09)
			foot = foot.lerp(Vector3(FOOT_REST.x * side * 1.3, 0.04, FOOT_REST.z) + kick, _air)
		var hip: Vector3 = _body.to_global(Vector3(HIP_OFFSET.x * side, HIP_OFFSET.y, HIP_OFFSET.z))
		hip = to_local(hip)
		var knee := _solve_knee(hip, foot, side)
		_set_rod(leg.femur, hip, knee)
		_set_rod(leg.tibia, knee, foot)

	# Arms: swing opposite the same-side leg; spread out to balance at
	# speed. Crawling, they become legs (tripod gait: right-front and
	# left-middle step with the right back leg). In the air they wave
	# about. Teetering, they windmill.
	for arm in _arms:
		var side: float = arm.side
		var front: bool = arm.front
		var pivot: Node3D = arm.pivot
		var leg_phase := _walk_phase + (0.0 if side > 0.0 else 0.5)
		var swing := -sin(TAU * leg_phase) * ARM_SWING * amount * (1.0 - balance * 0.6)
		var stand_x := swing * (0.6 if front else 1.0)
		var stand_z := side * (0.9 * balance + (0.08 * sin(_time * 1.7) if not front else 0.0))
		# Crawling: tripod gait.
		var tripod := fposmod(_walk_phase + (0.0 if (side > 0.0) == front else 0.5), 1.0)
		var crawl_step := _step(tripod)
		var crawl_x := (0.15 if front else 1.3) + crawl_step.x * 0.35 * amount
		var crawl_z := side * (0.15 + crawl_step.y * 0.35 * amount)
		var x := lerpf(stand_x, crawl_x, crawl)
		var z := lerpf(stand_z, crawl_z, crawl)
		# Teetering: arms out, windmilling.
		x += sin(_time * 9.0 + side) * 0.9 * _teeter * ground
		z += side * 0.9 * _teeter * ground
		# In the air: waving wildly over its head.
		var air_x := -1.6 + sin(flail * 0.9 + side * 1.3 + (0.8 if front else 0.0)) * 1.1
		var air_z := side * (0.7 + 0.4 * sin(flail * 1.1 + (1.0 if front else 0.0)))
		pivot.rotation.x = lerpf(x, air_x, _air)
		pivot.rotation.z = lerpf(z, air_z, _air)

	# Antennae: bob with each step, twitch now and then when idle, swept
	# forward when crawling, thrashing in the air.
	var twitch := maxf(sin(_time * 0.9) - 0.92, 0.0) * 6.0 * (1.0 - walking)
	for i in _antennae.size():
		var a := _antennae[i]
		a.rotation.x = sin(TAU * 2.0 * _walk_phase - 0.8) * 0.18 * amount + sin(_time * 1.3 + i) * 0.06 \
				+ twitch * 0.4 + 0.6 * crawl + _air * (sin(flail * 1.3 + i) * 0.5 - 0.3)
		a.rotation.z = (1.0 if i == 0 else -1.0) * (0.05 + 0.1 * run * walking)


## Where a foot is in its cycle: x = fore/aft position (1 = fully forward,
## -1 = fully back), y = how lifted it is (0..1). Planted for STANCE of the
## cycle (sliding from front to back), then lifted and swung forward.
func _step(phase: float) -> Vector2:
	if phase < STANCE:
		return Vector2(lerpf(1.0, -1.0, phase / STANCE), 0.0)
	var u := (phase - STANCE) / (1.0 - STANCE)
	return Vector2(lerpf(-1.0, 1.0, smoothstep(0.0, 1.0, u)), sin(u * PI))


## Height of the ball's surface at a horizontal offset from the top.
## The ant's origin is the top of the ball, so the ball's center is at
## (0, -radius, 0) in the ant's own space.
func _height_on_ball(x: float, z: float) -> float:
	var r := _ball_radius
	var h2 := r * r - x * x - z * z
	if h2 <= 0.0:
		return -r
	return sqrt(h2) - r


## Two-bone IK: where does the knee go so the leg reaches from hip to foot
## with fixed femur/tibia lengths? The knee bends outward and up, like an
## insect's.
func _solve_knee(hip: Vector3, foot: Vector3, side: float) -> Vector3:
	var to_foot := foot - hip
	var distance: float = clamp(to_foot.length(), 0.01, FEMUR + TIBIA - 0.001)
	var direction := to_foot / to_foot.length()
	# Distance along hip->foot where the knee sits, and how far off that line.
	var along := (FEMUR * FEMUR - TIBIA * TIBIA + distance * distance) / (2.0 * distance)
	var off := sqrt(max(FEMUR * FEMUR - along * along, 0.0))
	# Standing: knees forward and a little out. Crawling: up and out, like
	# an insect's.
	var pole := Vector3(side * 0.55, 0.35, -0.75).lerp(Vector3(side * 0.8, 0.9, 0.2), smoothstep(0.0, 1.0, _crawl)).normalized()
	var perpendicular := (pole - direction * pole.dot(direction))
	if perpendicular.length_squared() < 0.0001:
		perpendicular = Vector3.UP
	return hip + direction * along + perpendicular.normalized() * off


func _build() -> void:
	var head := _material(BODY_COLOR)
	var thorax := _material(BODY_COLOR)
	var abdomen_mat := _material(BODY_COLOR)
	var antenna_mat := _material(DARK_COLOR)
	var dark := _material(DARK_COLOR)
	var eye := _material(EYE_COLOR)
	eye.roughness = 0.25
	_part_materials = {"head": head, "thorax": thorax, "abdomen": abdomen_mat,
			"antennae": antenna_mat, "legs": dark, "eyes": eye}

	# Everything except the back legs hangs off _body so it can bob and lean.
	_body = Node3D.new()
	add_child(_body)

	# Abdomen: tilted egg pointing down and back.
	var abdomen := _sphere(_body, Vector3(0.0, 0.17, 0.07), 0.08, Vector3(1.0, 1.0, 1.45), abdomen_mat)
	abdomen.rotation_degrees.x = 40.0
	# Thorax (middle) and head. The head, eyes and antennae hang off a neck
	# pivot so the head can tilt and the eyes blink (cutscene gestures).
	_sphere(_body, Vector3(0.0, 0.3, -0.01), 0.06, Vector3.ONE, thorax)
	_neck = Node3D.new()
	_neck.position = Vector3(0.0, 0.38, -0.03)
	_body.add_child(_neck)
	_sphere(_neck, Vector3(0.0, 0.04, -0.02), 0.07, Vector3.ONE, head)
	# Eyes.
	_eyes.append(_sphere(_neck, Vector3(0.035, 0.06, -0.075), 0.016, Vector3.ONE, eye))
	_eyes.append(_sphere(_neck, Vector3(-0.035, 0.06, -0.075), 0.016, Vector3.ONE, eye))
	# Antennae, on pivots at the head so they can bob.
	for side in [1.0, -1.0]:
		var antenna := Node3D.new()
		antenna.position = Vector3(side * 0.02, 0.09, -0.04)
		_neck.add_child(antenna)
		_rod(antenna, Vector3.ZERO, Vector3(side * 0.04, 0.11, -0.07), 0.008, antenna_mat)
		_antennae.append(antenna)

	for side in [1.0, -1.0]:
		# Middle legs: relaxed arms hanging at the sides, on a shoulder pivot.
		var mid := Node3D.new()
		mid.position = Vector3(side * 0.05, 0.3, -0.01)
		_body.add_child(mid)
		_rod(mid, Vector3.ZERO, Vector3(side * 0.09, -0.04, -0.02), 0.011, dark)
		_rod(mid, Vector3(side * 0.09, -0.04, -0.02), Vector3(side * 0.07, -0.2, -0.04), 0.009, dark)
		_arms.append({"pivot": mid, "side": side, "front": false})
		# Front legs: held out forward for balance, on a shoulder pivot.
		var fore := Node3D.new()
		fore.position = Vector3(side * 0.045, 0.34, -0.04)
		_body.add_child(fore)
		_rod(fore, Vector3.ZERO, Vector3(side * 0.075, 0.04, -0.06), 0.011, dark)
		_rod(fore, Vector3(side * 0.075, 0.04, -0.06), Vector3(side * 0.035, -0.01, -0.15), 0.009, dark)
		_arms.append({"pivot": fore, "side": side, "front": true})

	for side in [1.0, -1.0]:
		# Back legs: built once, positioned every frame in _process.
		var femur := _rod(self, Vector3.ZERO, Vector3.UP * FEMUR, 0.013, dark)
		var tibia := _rod(self, Vector3.ZERO, Vector3.UP * TIBIA, 0.011, dark)
		_legs.append({"side": side, "femur": femur, "tibia": tibia})


func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m


func _sphere(parent: Node3D, pos: Vector3, radius: float, scale_by: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_by
	parent.add_child(instance)
	return instance


## A thin rod from point a to point b.
func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.radial_segments = 6
	mesh.rings = 2
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	parent.add_child(instance)
	_set_rod(instance, a, b)
	return instance


## Re-aims an existing rod so it runs from a to b.
func _set_rod(instance: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var mesh := instance.mesh as CapsuleMesh
	var length := a.distance_to(b)
	mesh.height = length + mesh.radius * 2.0
	# CapsuleMesh points along its Y axis; aim that axis from a to b.
	var y := (b - a).normalized() if length > 0.0001 else Vector3.UP
	var helper := Vector3.FORWARD if abs(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	var z := x.cross(y)
	instance.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
