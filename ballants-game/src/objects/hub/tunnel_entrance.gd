class_name TunnelEntrance
extends StaticBody3D
## TUNNEL ENTRANCE -- one of the big tunnel mouths around the hub's floor.
## Tunnel N leads to entry N of the level list (levels/level_list.gd); the
## list is also where its name and unlock cost come from, so nothing about
## a destination is hard-coded here.
##
##   open:    a dirt collar around an arched passage that fades to black;
##            roll in far enough and the level loads. The level's name
##            arches over the mouth in 3D letters embedded in the wall.
##   locked:  the passage is choked with rubble (solid), with the number of
##            crystals still needed standing on it and a glowing, turning
##            sugar crystal hovering over the number.
##
## Local space: -Z faces the middle of the cave, +Z runs into the wall.
## The hub places one per level and calls attach(shell).

@export var level_index := 0

const INNER_HALF_WIDTH := 2.4
const INNER_HEIGHT := 4.3
const OUTER_HALF_WIDTH := 5.0
const OUTER_HEIGHT := 7.0
const PORCH := 3.0           # how far the collar sticks into the cave
const COLLAR_DEPTH := 6.0    # how far into the wall the outer collar runs
const DEPTH := 11.0          # where the passage ends in black
const TRIGGER_Z := 5.5       # roll this far in and the level loads
const COLOR := Color(0.6, 0.34, 0.16)
const LETTER_COLOR := Color(0.92, 0.82, 0.62)
const LETTER_HEIGHT := 1.05  # meters
const LETTER_ARC_RADIUS := INNER_HALF_WIDTH + 1.15
const LETTER_ARC_MAX := OUTER_HALF_WIDTH - 0.8   # letters stay on the collar's face
const CRYSTAL_COLOR := Color(0.85, 0.97, 1.0)

var _shell: CaveShell
var _rubble: Node3D
var _rubble_shape: CollisionShape3D
var _crystal: Node3D
var _locked := true
var _entered := false
var _time := 0.0


func info() -> Dictionary:
	if level_index >= 0 and level_index < LevelList.LEVELS.size():
		return LevelList.LEVELS[level_index]
	return {"name": "?", "crystals_required": 0}


func _ready() -> void:
	add_to_group("tunnel")
	var built := ArchBuilder.build(self, INNER_HALF_WIDTH, INNER_HEIGHT, OUTER_HALF_WIDTH, OUTER_HEIGHT,
			PORCH, COLLAR_DEPTH, DEPTH, COLOR)
	var collider := CollisionShape3D.new()
	collider.name = "Collision"
	collider.shape = built.shape
	add_child(collider)
	_build_trigger()
	_build_light()
	_build_letters()
	_build_rubble()
	_update_number()
	refresh()
	Progress.changed.connect(refresh)


## The hub hands over the cave shell (kept for pieces that need the wall).
func attach(shell: CaveShell) -> void:
	_shell = shell


## Where the player appears when coming back from this tunnel's level:
## just in front of the mouth, on the floor. The yaw is the direction the
## camera should look (toward the middle of the cave).
func return_transform() -> Transform3D:
	var spot := to_global(Vector3(0.0, 0.6, -PORCH - 2.5))
	# Local -Z faces the middle of the cave; the camera should look that way.
	var forward := -global_transform.basis.z
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	var yaw := atan2(-forward.x, -forward.z)
	return Transform3D(Basis(Vector3.UP, yaw), spot)


func is_locked() -> bool:
	return _locked


## Opens or blocks the tunnel to match the player's crystals.
func refresh() -> void:
	var locked := not Progress.is_unlocked(level_index)
	if locked == _locked and _rubble.visible == locked:
		return
	if _locked and not locked and is_inside_tree() and _time > 0.5:
		_clear_rubble_animated()
	else:
		_rubble.visible = locked
		_rubble_shape.disabled = not locked
	_locked = locked
	_update_number()


func _process(delta: float) -> void:
	_time += delta
	if _crystal and _crystal.visible:
		_crystal.rotation.y += delta * 1.6
		_crystal.position.y = INNER_HEIGHT * 0.85 + sin(_time * 2.2) * 0.15


# ------------------------------------------------------------ trigger ----

func _build_trigger() -> void:
	var area := Area3D.new()
	area.name = "Trigger"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(INNER_HALF_WIDTH * 2.0, INNER_HEIGHT, 1.5)
	shape.shape = box
	shape.position = Vector3(0.0, INNER_HEIGHT * 0.5, TRIGGER_Z)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _entered or _locked or body is not PlayerBall:
		return
	if Game.control_locked:
		return
	_entered = true
	Levels.enter_level_from_hub(level_index)


## A small warm light just inside the mouth so the opening reads from afar.
func _build_light() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.45)
	light.light_energy = 1.1
	light.omni_range = 9.0
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position = Vector3(0.0, INNER_HEIGHT - 0.6, -0.5)
	add_child(light)


# ------------------------------------------------------------ letters ----

## The level's name spelled out along an arc over the mouth, each letter a
## block of 3D dirt-letters sunk halfway into the collar's face (and tilted
## to follow the arc). Long names get smaller letters so they fit.
func _build_letters() -> void:
	var text: String = str(info().name).to_upper()
	if text.is_empty():
		return
	var root := Node3D.new()
	root.name = "Letters"
	add_child(root)
	var material := StandardMaterial3D.new()
	material.albedo_color = LETTER_COLOR
	material.roughness = 0.8
	material.emission_enabled = true
	material.emission = LETTER_COLOR * 0.45
	material.emission_energy_multiplier = 0.6
	var arc_center := Vector3(0.0, INNER_HEIGHT - INNER_HALF_WIDTH, 0.0)
	var cell := LETTER_HEIGHT / BlockLetters.ROWS
	var depth := 0.55
	var max_span := deg_to_rad(150.0)
	# Letter spacing along the arc from each letter's real width. If the
	# name doesn't fit on the biggest arc the collar allows, shrink it.
	var widths := PackedFloat32Array()
	var total := 0.0
	var radius := LETTER_ARC_RADIUS
	for attempt in 6:
		widths = PackedFloat32Array()
		total = 0.0
		for ch in text:
			var w := BlockLetters.width(ch, cell) + cell * 1.3
			widths.append(w)
			total += w
		radius = clampf(total / max_span, LETTER_ARC_RADIUS, LETTER_ARC_MAX)
		if total / radius <= max_span:
			break
		cell *= 0.88
	var span := total / radius
	var letter_height := cell * BlockLetters.ROWS
	# Seen from the cave (looking along local +Z) the viewer's left is local
	# +X, so the first letter goes on the +X side and the angle grows.
	var angle := PI * 0.5 - span * 0.5
	for i in text.length():
		var ch := text[i]
		var half := widths[i] * 0.5 / radius
		angle += half
		var mesh := BlockLetters.letter_mesh(ch, cell, depth)
		if mesh:
			var letter := MeshInstance3D.new()
			letter.mesh = mesh
			letter.material_override = material
			var x := cos(angle) * radius
			var y := arc_center.y + sin(angle) * radius
			# The letter mesh grows from its bottom-left corner; center it on
			# the arc point, then tilt it to follow the arc.
			var pivot := Node3D.new()
			pivot.position = Vector3(x, y, -PORCH)
			pivot.rotation.z = angle - PI * 0.5
			root.add_child(pivot)
			# Letters are built facing +Z; the cave is at -Z, so turn them round
			# (a plain mirror would flip their faces inside out).
			var flip := Node3D.new()
			flip.rotation.y = PI
			pivot.add_child(flip)
			letter.position = Vector3(-BlockLetters.width(ch, cell) * 0.5, -letter_height * 0.5, 0.0)
			flip.add_child(letter)
		angle += half


# ------------------------------------------------------------- rubble ----

## Rocks and clods choking the passage just inside the mouth, a solid block
## behind them, the "crystals needed" number, and the hovering crystal.
func _build_rubble() -> void:
	_rubble = Node3D.new()
	_rubble.name = "Rubble"
	add_child(_rubble)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + level_index
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.5
	rock_mesh.height = 1.0
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 4
	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = Color(0.5, 0.33, 0.2)
	rock_material.roughness = 1.0
	rock_mesh.material = rock_material
	var dark_mesh := rock_mesh.duplicate() as SphereMesh
	var dark_material := rock_material.duplicate() as StandardMaterial3D
	dark_material.albedo_color = Color(0.36, 0.22, 0.13)
	dark_mesh.material = dark_material
	# A heap: more and bigger rocks low down, tapering toward the arch.
	for i in 34:
		var y := rng.randf_range(0.0, 1.0)
		y = y * y * INNER_HEIGHT * 0.95
		var width_here := INNER_HALF_WIDTH * (1.0 - 0.45 * (y / INNER_HEIGHT))
		var rock := MeshInstance3D.new()
		rock.mesh = rock_mesh if rng.randf() < 0.6 else dark_mesh
		var size := rng.randf_range(0.5, 1.2) * (1.0 - 0.4 * (y / INNER_HEIGHT)) + 0.3
		rock.scale = Vector3(size, size * rng.randf_range(0.6, 0.9), size * rng.randf_range(0.8, 1.1))
		rock.position = Vector3(rng.randf_range(-width_here, width_here), y + size * 0.3, rng.randf_range(0.7, 2.2))
		rock.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		_rubble.add_child(rock)
	# A solid wall behind the rocks fills any gap between them.
	var fill := MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(INNER_HALF_WIDTH * 2.0, INNER_HEIGHT, 1.2)
	fill_mesh.material = dark_material
	fill.mesh = fill_mesh
	fill.position = Vector3(0.0, INNER_HEIGHT * 0.5, 2.0)
	_rubble.add_child(fill)
	_rubble_shape = CollisionShape3D.new()
	_rubble_shape.name = "RubbleCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(INNER_HALF_WIDTH * 2.0 + 0.2, INNER_HEIGHT + 0.5, 2.6)
	_rubble_shape.shape = box
	_rubble_shape.position = Vector3(0.0, INNER_HEIGHT * 0.5, 1.3)
	add_child(_rubble_shape)
	# The number, standing on the heap, facing the cave (filled in by
	# _update_number).
	var number := Node3D.new()
	number.name = "Number"
	number.position = Vector3(0.0, INNER_HEIGHT * 0.55, -0.9)
	number.rotation.y = PI   # block digits face +Z; the cave is at -Z
	_rubble.add_child(number)
	# The crystal hovering above it.
	_crystal = make_crystal(0.8)
	_crystal.position = Vector3(0.0, INNER_HEIGHT * 0.85, -0.9)
	_rubble.add_child(_crystal)


## Rebuilds the "crystals needed" number out of block digits.
func _update_number() -> void:
	var number := _rubble.get_node_or_null("Number") as Node3D
	if number == null:
		return
	for child in number.get_children():
		child.queue_free()
	var text := str(Progress.crystals_needed(level_index))
	var cell := 1.4 / BlockLetters.ROWS
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.98, 0.9, 0.7)
	material.emission_enabled = true
	material.emission = Color(0.9, 0.7, 0.35)
	material.emission_energy_multiplier = 0.8
	var total := 0.0
	for ch in text:
		total += BlockLetters.width(ch, cell) + cell
	var x := -total * 0.5
	for ch in text:
		var mesh := BlockLetters.letter_mesh(ch, cell, 0.4)
		if mesh:
			var digit := MeshInstance3D.new()
			digit.mesh = mesh
			digit.material_override = material
			digit.position = Vector3(x, -0.7, 0.0)
			number.add_child(digit)
		x += BlockLetters.width(ch, cell) + cell


## The rubble tumbles away when the tunnel unlocks during play.
func _clear_rubble_animated() -> void:
	_rubble_shape.disabled = true
	var tween := create_tween()
	for child in _rubble.get_children():
		var node := child as Node3D
		tween.parallel().tween_property(node, "position:y", node.position.y - 6.0, 0.9) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_rubble.visible = false
		for child in _rubble.get_children():
			(child as Node3D).position.y += 6.0)
	Effects.impact(Tuning.impact_big, Vector3.UP, to_global(Vector3(0.0, 0.5, 0.5)))


## A glowing sugar crystal: a six-sided double point, with a light. Shared
## with the HUD-less "crystal needed" sign and the Queen's gift popup.
static func make_crystal(size: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Crystal"
	var material := StandardMaterial3D.new()
	material.albedo_color = CRYSTAL_COLOR
	material.roughness = 0.25
	material.emission_enabled = true
	material.emission = Color(0.55, 0.85, 1.0)
	material.emission_energy_multiplier = 2.2
	for sign in [1.0, -1.0]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = size * 0.42
		cone.height = size
		cone.radial_segments = 6
		cone.rings = 1
		cone.material = material
		var half := MeshInstance3D.new()
		half.mesh = cone
		half.position = Vector3(0.0, sign * size * 0.5, 0.0)
		half.scale.y = sign
		root.add_child(half)
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.85, 1.0)
	light.light_energy = 0.9
	light.omni_range = 4.0
	light.shadow_enabled = false
	root.add_child(light)
	return root
