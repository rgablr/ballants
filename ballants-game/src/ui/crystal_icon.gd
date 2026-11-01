class_name CrystalIcon
extends Control
## CRYSTAL ICON -- a small sugar crystal drawn for the UI (the HUD's pouch
## counter and the results card). Three looks:
##   "new"   bright, glowing, with a sparkle: earned just now
##   "old"   plain, earned on an earlier run
##   "none"  a dim outline: still to find
## Set `state` and it redraws. `extent` is its size in pixels.

@export var state := "none":
	set(v):
		state = v
		queue_redraw()
@export var extent := 28.0:
	set(v):
		extent = v
		custom_minimum_size = Vector2(extent, extent * 1.5)
		queue_redraw()

const FILL := Color(0.85, 0.97, 1.0)
const GLOW := Color(0.55, 0.85, 1.0)
const OUTLINE := Color(1.0, 1.0, 1.0, 0.3)

var _time := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(extent, extent * 1.5)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if state == "new":
		_time += delta
		queue_redraw()


func _draw() -> void:
	var w := extent
	var h := extent * 1.5
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	# A six-sided double point: top tip, two shoulders, two hips, bottom tip.
	var points := PackedVector2Array([
		c + Vector2(0.0, -h * 0.5),
		c + Vector2(w * 0.42, -h * 0.18),
		c + Vector2(w * 0.42, h * 0.18),
		c + Vector2(0.0, h * 0.5),
		c + Vector2(-w * 0.42, h * 0.18),
		c + Vector2(-w * 0.42, -h * 0.18),
	])
	match state:
		"new":
			var pulse := 0.75 + 0.25 * sin(_time * 6.0)
			draw_colored_polygon(points, GLOW.lerp(Color.WHITE, 0.4 * pulse))
			draw_colored_polygon(_shrink(points, c, 0.55), Color(1, 1, 1, 0.75))
			# A sparkle to one side.
			var s := c + Vector2(w * 0.55, -h * 0.42)
			var r := w * (0.16 + 0.08 * pulse)
			draw_line(s - Vector2(r, 0), s + Vector2(r, 0), Color.WHITE, 1.5)
			draw_line(s - Vector2(0, r), s + Vector2(0, r), Color.WHITE, 1.5)
		"old":
			draw_colored_polygon(points, FILL.darkened(0.15))
			draw_colored_polygon(_shrink(points, c, 0.55), Color(1, 1, 1, 0.3))
		_:
			draw_colored_polygon(points, Color(1, 1, 1, 0.06))
			var closed := points.duplicate()
			closed.append(points[0])
			draw_polyline(closed, OUTLINE, 1.5)


static func _shrink(points: PackedVector2Array, center: Vector2, by: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(center + (p - center) * by)
	return out
