@tool
class_name BounceMushroom
extends StaticBody3D
## BOUNCE MUSHROOM -- a big, soft, glowing mushroom cap the ball can land
## on. Land on it (or roll onto it) and it springs the ball straight up
## to a FIXED height above the cap, read from the physics config
## (Tuning.mushroom_bounce_height by default), whatever speed the ball
## came down with. The ball keeps its sideways speed, so the aiming is
## horizontal: how fast you were going decides how far you fly. The cap
## squashes and springs back (like bounce_pad.gd).
##
## Set `bouncy` off for a plain solid mushroom: a ledge to stand on (the
## tall mushrooms that hold a crystal) or a decoration.
##
## The node's origin is the FOOT of the stem; `cap_height` is how far
## above that the flat top of the cap is (that is what the ball rolls on).
## For a "bounce patch" set into a floor, sink the node so the cap top is
## about 0.1 m above the floor. Collision: a flat cylinder for the cap and
## a cylinder for the stem, separate from the looks; it is folded into the
## level's static body like every other piece. The trigger is an Area3D a
## little wider than the cap, just above it.
##
## The launch: vertical speed = sqrt(2 g h), where h is measured from the
## ball's current height to (cap top + ball radius + bounce height), so
## the ball's peak is the same every time (corrected for the engine's
## air damping, see launch_speed_for); allow_launch() tells the ball
## this upward kick is on purpose (no seam smoothing).

## Flat top of the cap, meters above the node's origin (the stem's foot).
@export var cap_height := 2.0:
	set(v):
		cap_height = v
		_rebuild()
@export var cap_radius := 1.6:
	set(v):
		cap_radius = v
		_rebuild()
@export var stem_radius := 0.45:
	set(v):
		stem_radius = v
		_rebuild()
## Off = a solid mushroom that does not bounce (a ledge or decoration).
@export var bouncy := true:
	set(v):
		bouncy = v
		_rebuild()
## Which physics config value sets the bounce height (m above the cap).
@export var height_value := "mushroom_bounce_height"
## Multiplies that height (1 = as configured).
@export var height_scale := 1.0
## Cap color and its glow.
@export var cap_color := Color(0.62, 1.0, 0.72):
	set(v):
		cap_color = v
		_rebuild()
@export var glow_color := Color(0.35, 0.95, 0.6):
	set(v):
		glow_color = v
		_rebuild()
@export var glow_energy := 0.8:
	set(v):
		glow_energy = v
		_rebuild()
@export var light_energy := 1.2:
	set(v):
		light_energy = v
		_rebuild()
@export var light_range := 8.0:
	set(v):
		light_range = v
		_rebuild()
@export var seed := 1:
	set(v):
		seed = v
		_rebuild()
## Leave on: the level's StaticMerger folds this collision into one body.
@export var merge_collision := true

const CAP_THICKNESS := 0.5
const DOME := 0.32         # how far the soft dome rises above the flat top (looks only)
const STEM_COLOR := Color(0.92, 0.86, 0.72)
const GILL_COLOR := Color(0.55, 0.42, 0.33)

var _built := false
var _cap_visual: Node3D
var _trigger: Area3D


func _ready() -> void:
	_built = true
	_rebuild()


## Top of the cap in world space (where the ball rolls).
func cap_top() -> Vector3:
	return global_transform * Vector3(0.0, cap_height, 0.0)


## How high this mushroom throws the ball, in meters above the cap.
func bounce_height() -> float:
	var h = Tuning.get(height_value) if Tuning else null
	return (float(h) if h != null else 6.0) * height_scale


func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# ---- stem (looks + collision)
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = STEM_COLOR
	stem_mat.roughness = 0.9
	stem_mat.emission_enabled = true
	stem_mat.emission = glow_color
	stem_mat.emission_energy_multiplier = 0.06
	var stem_len := cap_height - CAP_THICKNESS * 0.5
	if stem_len > 0.05:
		var stem := CylinderMesh.new()
		stem.top_radius = stem_radius * 0.85
		stem.bottom_radius = stem_radius * 1.15
		stem.height = stem_len
		stem.radial_segments = 10
		stem.rings = 2
		stem.material = stem_mat
		var stem_mi := MeshInstance3D.new()
		stem_mi.name = "Stem"
		stem_mi.mesh = stem
		stem_mi.position.y = stem_len * 0.5
		add_child(stem_mi)
		if stem_len > 0.3:
			var stem_shape := CylinderShape3D.new()
			stem_shape.radius = stem_radius
			stem_shape.height = stem_len
			var stem_col := CollisionShape3D.new()
			stem_col.name = "StemCollision"
			stem_col.shape = stem_shape
			stem_col.position.y = stem_len * 0.5
			add_child(stem_col)

	# ---- cap collision: a flat disc whose top is cap_height
	var cap_shape := CylinderShape3D.new()
	cap_shape.radius = cap_radius
	cap_shape.height = CAP_THICKNESS
	var cap_col := CollisionShape3D.new()
	cap_col.name = "CapCollision"
	cap_col.shape = cap_shape
	cap_col.position.y = cap_height - CAP_THICKNESS * 0.5
	add_child(cap_col)

	# ---- cap looks: a soft glowing dome, darker gills under it, pale spots
	_cap_visual = Node3D.new()
	_cap_visual.name = "Cap"
	_cap_visual.position.y = cap_height - CAP_THICKNESS
	add_child(_cap_visual)
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = cap_color
	cap_mat.roughness = 0.55
	cap_mat.emission_enabled = true
	cap_mat.emission = glow_color
	cap_mat.emission_energy_multiplier = glow_energy
	var dome := SphereMesh.new()
	dome.radius = cap_radius * 1.04
	dome.height = cap_radius * 2.08
	dome.is_hemisphere = true
	dome.radial_segments = 18
	dome.rings = 5
	dome.material = cap_mat
	var dome_mi := MeshInstance3D.new()
	dome_mi.mesh = dome
	# Flatten the hemisphere so its crown sits DOME above the flat top.
	var dome_height := CAP_THICKNESS + DOME
	dome_mi.scale = Vector3(1.0, dome_height / (cap_radius * 1.04), 1.0)
	_cap_visual.add_child(dome_mi)
	var gill_mat := StandardMaterial3D.new()
	gill_mat.albedo_color = GILL_COLOR
	gill_mat.roughness = 1.0
	gill_mat.emission_enabled = true
	gill_mat.emission = glow_color
	gill_mat.emission_energy_multiplier = 0.15
	var gills := CylinderMesh.new()
	gills.top_radius = cap_radius * 1.0
	gills.bottom_radius = stem_radius * 1.1
	gills.height = 0.18
	gills.radial_segments = 18
	gills.rings = 1
	gills.material = gill_mat
	var gills_mi := MeshInstance3D.new()
	gills_mi.mesh = gills
	gills_mi.position.y = -0.08
	_cap_visual.add_child(gills_mi)
	var spot_mat := StandardMaterial3D.new()
	spot_mat.albedo_color = cap_color.lightened(0.6)
	spot_mat.emission_enabled = true
	spot_mat.emission = glow_color.lightened(0.5)
	spot_mat.emission_energy_multiplier = glow_energy * 1.6
	var spots := rng.randi_range(4, 7)
	for i in spots:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * cap_radius * 0.8
		var spot := SphereMesh.new()
		var s := rng.randf_range(0.09, 0.16) * maxf(cap_radius, 0.6)
		spot.radius = s
		spot.height = s * 0.8
		spot.radial_segments = 6
		spot.rings = 2
		spot.material = spot_mat
		var spot_mi := MeshInstance3D.new()
		spot_mi.mesh = spot
		# On the dome's surface (the flattened hemisphere), height falls off with r.
		var u := r / (cap_radius * 1.04)
		spot_mi.position = Vector3(cos(a) * r, dome_height * sqrt(maxf(1.0 - u * u, 0.0)), sin(a) * r)
		_cap_visual.add_child(spot_mi)

	# ---- light
	if light_energy > 0.0:
		var light := OmniLight3D.new()
		light.light_color = glow_color
		light.light_energy = light_energy
		light.omni_range = light_range
		light.omni_attenuation = 1.2
		light.shadow_enabled = false
		light.position.y = cap_height + 1.2
		add_child(light)

	# ---- trigger
	_trigger = null
	if bouncy:
		_trigger = Area3D.new()
		_trigger.name = "Trigger"
		_trigger.monitorable = false
		var trigger_shape := CylinderShape3D.new()
		trigger_shape.radius = cap_radius + 0.15
		trigger_shape.height = 1.3
		var trigger_col := CollisionShape3D.new()
		trigger_col.shape = trigger_shape
		trigger_col.position.y = cap_height + 0.6
		_trigger.add_child(trigger_col)
		add_child(_trigger)
		if not Engine.is_editor_hint():
			_trigger.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is not RigidBody3D:
		return
	var rigid := body as RigidBody3D
	if rigid.linear_velocity.y > 1.0:
		return   # passing up through the edge (already launched): leave it
	var radius := 0.5
	if body is PlayerBall:
		radius = (body as PlayerBall).radius
	var peak := cap_top().y + radius + bounce_height()
	var rise := maxf(peak - rigid.global_position.y, 0.5)
	var launch_speed := launch_speed_for(rise, rigid)
	if rigid.has_method("allow_launch"):
		rigid.allow_launch()
	if body is PlayerBall:
		# No coyote jump straight after a bounce: a jump pressed as you roll
		# onto a cap would replace the bounce with a small hop.
		(body as PlayerBall)._time_since_grounded = 999.0
	rigid.apply_central_impulse(Vector3.UP * (launch_speed - rigid.linear_velocity.y) * rigid.mass)
	Sounds.play_at("bump", cap_top(), -3.0, 0.55)
	_squash()


## The upward speed that makes `body` rise `rise` meters. Plain sqrt(2 g h)
## would fall short: the physics engine's default linear damping (0.1 per
## second, project setting) bleeds speed on the long climb, so solve the
## damped climb instead: h = v/k - (g/k^2) ln(1 + k v / g).
static func launch_speed_for(rise: float, body: RigidBody3D) -> float:
	var g := Tuning.gravity
	var v := sqrt(2.0 * g * rise)
	var k := float(ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1))
	if body.linear_damp_mode == RigidBody3D.DAMP_MODE_REPLACE:
		k = body.linear_damp
	else:
		k += body.linear_damp
	if k <= 0.0001:
		return v
	# Newton's method on f(v) = v/k - (g/k^2) ln(1 + k v / g) - rise.
	for i in 6:
		var f := v / k - g / (k * k) * log(1.0 + k * v / g) - rise
		var df := 1.0 / k - 1.0 / (k * (1.0 + k * v / g))
		if df <= 0.000001:
			break
		v -= f / df
	return v


## Squash-and-stretch on the cap so it reads as soft and springy.
func _squash() -> void:
	if _cap_visual == null:
		return
	var tween := create_tween()
	tween.tween_property(_cap_visual, "scale", Vector3(1.18, 0.55, 1.18), 0.06)
	tween.tween_property(_cap_visual, "scale", Vector3(0.94, 1.12, 0.94), 0.12).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_cap_visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
