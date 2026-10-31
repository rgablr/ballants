extends CanvasLayer
## DEBUG OVERLAY (F2) -- shows what the physics engine sees:
##   - every collision shape drawn as a wireframe
##   - an arrow on the ball showing its velocity (direction and size)
##   - FPS, ball speed, velocity, position, and ground state
##
## Nothing here affects gameplay; it only adds pictures and text.

const SHAPE_VIS_NAME := "DebugShapeVis"
const ARROW_SCALE := 0.25   # arrow length per m/s

var _text: Label
var _arrow: MeshInstance3D
var _arrow_mesh: ImmediateMesh
var _rescan_timer := 0.0
var _wire_material: StandardMaterial3D
var _player: RigidBody3D


func _ready() -> void:
	visible = false
	layer = 9

	_text = Label.new()
	_text.anchor_left = 1.0
	_text.anchor_right = 1.0
	_text.offset_left = -330.0
	_text.offset_right = -16.0
	_text.offset_top = 48.0
	_text.add_theme_font_size_override("font_size", 15)
	_text.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_text.add_theme_constant_override("shadow_offset_x", 1)
	_text.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_text)

	_wire_material = StandardMaterial3D.new()
	_wire_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wire_material.albedo_color = Color(0.2, 1.0, 0.4)
	_wire_material.no_depth_test = true
	_wire_material.render_priority = 10

	_arrow_mesh = ImmediateMesh.new()
	_arrow = MeshInstance3D.new()
	_arrow.mesh = _arrow_mesh
	_arrow.top_level = true
	var arrow_material := StandardMaterial3D.new()
	arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_material.vertex_color_use_as_albedo = true
	arrow_material.no_depth_test = true
	arrow_material.render_priority = 11
	_arrow.material_override = arrow_material


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug_overlay"):
		set_enabled(not visible)
		get_viewport().set_input_as_handled()


func set_enabled(enabled: bool) -> void:
	visible = enabled
	if enabled:
		if _arrow.get_parent() == null:
			get_tree().current_scene.add_child(_arrow)
		_show_shapes()
	else:
		_hide_shapes()
		if _arrow.get_parent():
			_arrow.get_parent().remove_child(_arrow)


func _process(delta: float) -> void:
	if not visible:
		return
	_rescan_timer += delta
	if _rescan_timer > 0.5:
		_rescan_timer = 0.0
		_show_shapes()   # picks up objects spawned since last time
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as RigidBody3D
	_draw_arrow()
	_update_text()


func _update_text() -> void:
	var lines: Array[String] = []
	lines.append("FPS %d   physics %d Hz" % [Engine.get_frames_per_second(), Engine.physics_ticks_per_second])
	if _player:
		var v := _player.linear_velocity
		var p := _player.global_position
		lines.append("speed %.2f m/s  (flat %.2f)" % [v.length(), Vector2(v.x, v.z).length()])
		lines.append("velocity  x %.2f  y %.2f  z %.2f" % [v.x, v.y, v.z])
		lines.append("position  x %.2f  y %.2f  z %.2f" % [p.x, p.y, p.z])
		lines.append("spin %.1f rad/s" % _player.angular_velocity.length())
		lines.append("state: " + _state_name())
	lines.append("F2 hides this. Green wire = collision shapes.")
	_text.text = "\n".join(lines)


func _state_name() -> String:
	if _player.has_method("is_grounded") and _player.is_grounded():
		return "GROUNDED"
	if _player.has_method("is_coyote_active") and _player.is_coyote_active():
		return "AIRBORNE (coyote time: can still jump)"
	return "AIRBORNE"


func _draw_arrow() -> void:
	_arrow_mesh.clear_surfaces()
	if _player == null:
		return
	var v := _player.linear_velocity
	if v.length() < 0.05:
		return
	var start := _player.global_position
	var end := start + v * ARROW_SCALE
	var color := Color(1.0, 0.9, 0.2)
	_arrow_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_arrow_mesh.surface_set_color(color)
	_arrow_mesh.surface_add_vertex(start)
	_arrow_mesh.surface_add_vertex(end)
	# Arrowhead: two short lines angled back from the tip.
	var direction := v.normalized()
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var head_length := minf(0.4, (end - start).length() * 0.3)
	for s in [1.0, -1.0]:
		_arrow_mesh.surface_add_vertex(end)
		_arrow_mesh.surface_add_vertex(end - direction * head_length + side * s * head_length * 0.5)
	_arrow_mesh.surface_end()


func _show_shapes() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	for shape in _find_shapes(root):
		if shape.has_node(SHAPE_VIS_NAME) or shape.shape == null:
			continue
		var vis := MeshInstance3D.new()
		vis.name = SHAPE_VIS_NAME
		vis.mesh = _wireframe_of(shape.shape.get_debug_mesh())
		vis.material_override = _wire_material
		shape.add_child(vis)


## Godot's debug mesh mixes filled faces and outline lines; keep only the
## lines so the shapes read as wireframes. Falls back to a see-through
## fill for shapes that have no line surface.
func _wireframe_of(debug_mesh: ArrayMesh) -> Mesh:
	var lines := ArrayMesh.new()
	for i in debug_mesh.get_surface_count():
		if debug_mesh.surface_get_primitive_type(i) == Mesh.PRIMITIVE_LINES:
			lines.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, debug_mesh.surface_get_arrays(i))
	if lines.get_surface_count() > 0:
		return lines
	_wire_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wire_material.albedo_color.a = 0.25
	return debug_mesh


func _hide_shapes() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	for shape in _find_shapes(root):
		if shape.has_node(SHAPE_VIS_NAME):
			shape.get_node(SHAPE_VIS_NAME).queue_free()


func _find_shapes(node: Node) -> Array[CollisionShape3D]:
	var found: Array[CollisionShape3D] = []
	if node is CollisionShape3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_shapes(child))
	return found
