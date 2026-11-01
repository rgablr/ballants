@tool
class_name EggPile
extends StaticBody3D
## EGG PILE -- a heap of pale ant eggs. Roll into it and it gives: the
## eggs wobble and squash, and the ball is knocked gently back out instead
## of stopping dead against it. Whatever speed you had ALONG the pile is
## kept, so a ball that glances off a row of eggs slides along it without
## losing speed (unlike a dirt wall, which rubs and bounces).
##
## Two shapes: `length` 0 is a round heap of `radius`; `length` > 0 is a
## row of eggs that long along local X (`radius` is then half its
## thickness). `height` is how tall the heap is. Rows laid end to end
## (overlapping by about `radius`) fence a winding path.
##
## How the knock works (all numbers in config/physics_tuning.gd, LEVEL 2):
## every physics step the pile checks the ball's distance from its middle
## line. When the ball comes within the "soft shell" (radius + ball radius
## + SHELL) while moving INTO the pile, its into-the-pile speed is removed
## and replaced by an outward speed of
##     Tuning.egg_knock_speed + Tuning.egg_knock_bounce x (speed it came in at)
## (along-the-pile speed untouched), the eggs squash by Tuning.egg_squash,
## and there is a soft bump. A solid core (a capsule a little smaller than
## the heap) sits behind the shell so nothing can ever pass through.
## The core folds into the level's one static body like a Block.

@export var length := 0.0:
	set(v):
		length = v
		_rebuild()
@export var radius := 1.0:
	set(v):
		radius = v
		_rebuild()
@export var height := 1.8:
	set(v):
		height = v
		_rebuild()
## Egg size multiplier (1 = eggs about 1.1 m tall).
@export var egg_size := 1.0:
	set(v):
		egg_size = v
		_rebuild()
@export var seed := 1:
	set(v):
		seed = v
		_rebuild()
## Leave on: the level's StaticMerger folds the core into one body.
@export var merge_collision := true

## How far outside the eggs the soft shell starts (m).
const SHELL := 0.25
## A pile can knock once per this long (s), so one touch is one knock.
const COOLDOWN := 0.12
const EGG_COLOR := Color(0.95, 0.92, 0.82)
const EGG_GLOW := Color(1.0, 0.86, 0.6)
const EGG_SHADES := [Color(1.0, 0.97, 0.9), Color(0.92, 0.84, 0.7), Color(0.98, 0.9, 0.82), Color(0.86, 0.8, 0.68)]

static var _egg_mesh: SphereMesh
## The physics frame of the last knock from ANY pile: where two rows meet,
## only one of them knocks.
static var _last_knock_frame := -1

var _built := false
var _visual: Node3D
var _cooldown := 0.0
var _squash := 0.0
var _squash_tween: Tween
var _player: PlayerBall


func _ready() -> void:
	_built = true
	_rebuild()
	if not Engine.is_editor_hint():
		add_to_group("egg_pile")


static func egg_mesh() -> SphereMesh:
	if _egg_mesh == null:
		_egg_mesh = SphereMesh.new()
		_egg_mesh.radius = 0.5
		_egg_mesh.height = 1.0
		_egg_mesh.radial_segments = 14
		_egg_mesh.rings = 8
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true   # the per-egg tint
		material.albedo_color = Color.WHITE
		material.roughness = 0.55
		material.emission_enabled = true
		material.emission = EGG_GLOW
		material.emission_energy_multiplier = 0.1
		_egg_mesh.material = material
	return _egg_mesh


func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_visual = Node3D.new()
	_visual.name = "Eggs"
	add_child(_visual)

	# Eggs: layers from the bottom up, each layer a ring (round heap) or
	# two staggered lines (row), narrowing toward the top.
	var transforms: Array[Transform3D] = []
	var egg_w := 0.7 * egg_size      # egg diameter
	var egg_h := 1.1 * egg_size      # egg height (they stand upright-ish)
	var layers := maxi(int(ceil((height - egg_h * 0.5) / (egg_h * 0.55))), 1)
	for layer in layers:
		var y := egg_h * 0.45 + layer * egg_h * 0.55
		if y > height - egg_h * 0.35 and layer > 0:
			break
		var shrink := 1.0 - float(layer) / (layers + 0.5)
		var half_w := maxf(radius * shrink - egg_w * 0.45, 0.0)
		if length > 0.0:
			var count := maxi(int(ceil((length + radius * shrink) / (egg_w * 0.8))), 1)
			var lines := PackedFloat32Array([-1.0, 1.0]) if half_w > egg_w * 0.3 else PackedFloat32Array([0.0])
			for line in lines:
				for i in count:
					var x: float = -length * 0.5 + length * (i + 0.5 * (1.0 + line * 0.5)) / count
					var z: float = line * half_w + rng.randf_range(-0.08, 0.08)
					transforms.append(_egg(rng, Vector3(x, y, z), egg_w, egg_h))
			if half_w > egg_w * 0.9:
				for i in count - 1:
					var x := -length * 0.5 + length * (i + 1.0) / count
					transforms.append(_egg(rng, Vector3(x, y + 0.1, rng.randf_range(-0.15, 0.15)), egg_w, egg_h))
		else:
			if half_w < egg_w * 0.3:
				transforms.append(_egg(rng, Vector3(0.0, y, 0.0), egg_w, egg_h))
				continue
			var ring := maxi(int(TAU * half_w / (egg_w * 0.85)), 3)
			var turn := rng.randf() * TAU
			for i in ring:
				var a := turn + TAU * i / ring
				transforms.append(_egg(rng, Vector3(cos(a) * half_w, y, sin(a) * half_w), egg_w, egg_h))
			if half_w > egg_w * 1.2:
				var inner := maxi(int(TAU * half_w * 0.45 / (egg_w * 0.85)), 1)
				for i in inner:
					var a := turn + 0.4 + TAU * i / inner
					transforms.append(_egg(rng, Vector3(cos(a) * half_w * 0.45, y + 0.1, sin(a) * half_w * 0.45), egg_w, egg_h))
	# A top egg.
	transforms.append(_egg(rng, Vector3(rng.randf_range(-0.2, 0.2), height - egg_h * 0.45, 0.0), egg_w * 1.05, egg_h * 1.05))

	var multimesh := make_multimesh(transforms, rng)
	var eggs := MultiMeshInstance3D.new()
	eggs.multimesh = multimesh
	_visual.add_child(eggs)

	# Solid core: a capsule lying along X (a row), or a squat cylinder (a
	# heap), a little inside the eggs.
	var core := CollisionShape3D.new()
	core.name = "Core"
	if length > 0.0:
		var core_r := minf(radius * 0.85, height * 0.5)
		var capsule := CapsuleShape3D.new()
		capsule.radius = core_r
		capsule.height = length + core_r * 2.0
		core.rotation_degrees = Vector3(0, 0, 90)
		core.position = Vector3(0.0, core_r, 0.0)
		core.shape = capsule
	else:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius * 0.8
		cylinder.height = height * 0.85
		core.position = Vector3(0.0, cylinder.height * 0.5, 0.0)
		core.shape = cylinder
	add_child(core)


## A MultiMesh of eggs at these transforms, each a slightly different
## shade of cream (used by EggMound too).
static func make_multimesh(transforms: Array[Transform3D], rng: RandomNumberGenerator) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = egg_mesh()
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		var shade := EGG_COLOR.lerp(EGG_SHADES[rng.randi() % EGG_SHADES.size()], rng.randf_range(0.0, 0.7))
		multimesh.set_instance_color(i, shade)
	return multimesh


func _egg(rng: RandomNumberGenerator, pos: Vector3, w: float, h: float) -> Transform3D:
	var s := rng.randf_range(0.85, 1.12)
	var basis := Basis.from_euler(Vector3(rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.35, 0.35)))
	basis = basis * Basis.from_scale(Vector3(w, h, w) * s)
	return Transform3D(basis, pos)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerBall
		if _player == null:
			return
	var local := to_local(_player.global_position)
	if local.y < -0.6 or local.y > height + 0.4:
		return
	var reach := radius + _player.radius + SHELL
	var nearest := Vector3(clampf(local.x, -length * 0.5, length * 0.5), local.y, 0.0)
	var offset := local - nearest
	offset.y = 0.0
	if offset.length() > reach:
		return
	var out_local := offset.normalized() if offset.length() > 0.01 else Vector3.BACK
	var out := (global_transform.basis * out_local)
	out.y = 0.0
	out = out.normalized()
	var v := _player.linear_velocity
	var into := -v.dot(out)
	if Engine.get_physics_frames() == _last_knock_frame:
		return
	if into < 0.2 or _cooldown > 0.0:
		# Inside the shell but not hitting it (resting against it, or
		# creeping in): a gentle steady push out, so nothing ever sinks
		# into the eggs.
		var leaving := -into
		var gentle := Tuning.egg_knock_speed * 0.4
		if leaving < gentle:
			_player.apply_central_impulse(out * (gentle - leaving) * minf(delta * 8.0, 1.0) * _player.mass)
		return
	_cooldown = COOLDOWN
	_last_knock_frame = Engine.get_physics_frames()
	var push := Tuning.egg_knock_speed + Tuning.egg_knock_bounce * into
	_player.apply_central_impulse(out * (into + push) * _player.mass)
	_play_squash(clampf(into / 8.0, 0.3, 1.0))
	Sounds.play_at("bump", _player.global_position, lerpf(-16.0, -6.0, clampf(into / 9.0, 0.0, 1.0)), 0.8)


## The eggs flatten a little and wobble back (visual only).
func _play_squash(amount: float) -> void:
	if _visual == null:
		return
	_squash = Tuning.egg_squash * amount
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_method(_apply_squash, _squash, 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _apply_squash(amount: float) -> void:
	_visual.scale = Vector3(1.0 + amount * 0.5, 1.0 - amount, 1.0 + amount * 0.5)
