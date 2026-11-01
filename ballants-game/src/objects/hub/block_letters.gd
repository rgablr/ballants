class_name BlockLetters
extends RefCounted
## BLOCK LETTERS -- chunky 3D letters built from little boxes on a 5x7 dot
## grid, for the level names arching over the hub's tunnels and the
## "crystals needed" numbers on the rubble. Built in code (Godot's TextMesh
## can't cut the UI font's overlapping outlines), low-poly, and they read
## well in dim light.
##
##   BlockLetters.letter_mesh("A", cell, depth) -> ArrayMesh (cached)
##   BlockLetters.width("A", cell)             -> how wide it is, in meters
## A letter's origin is its bottom-left corner; it extends +X and +Y, and
## from z = -depth/2 to +depth/2.

const ROWS := 7
const COLS := 5

## Each glyph: 7 strings of 5 characters, '#' = a box. Top row first.
const GLYPHS := {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
	"-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
	".": [".....", ".....", ".....", ".....", ".....", "..#..", "..#.."],
	"'": ["..#..", "..#..", ".#...", ".....", ".....", ".....", "....."],
	"!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	"&": [".##..", "#..#.", "#..#.", ".##..", "#.#.#", "#..#.", ".##.#"],
}

static var _cache := {}


## Columns a glyph really uses (narrow glyphs like "I" and "1" are trimmed).
static func _columns(glyph: Array) -> Array:
	var first := COLS
	var last := -1
	for row in glyph:
		for c in COLS:
			if row[c] == "#":
				first = mini(first, c)
				last = maxi(last, c)
	if last < 0:
		return [0, 2]   # a space: three cells wide
	return [first, last]


static func width(ch: String, cell: float) -> float:
	var glyph: Array = GLYPHS.get(ch.to_upper(), [])
	if glyph.is_empty():
		return cell * 3.0
	var cols := _columns(glyph)
	return cell * float(cols[1] - cols[0] + 1)


static func height(cell: float) -> float:
	return cell * ROWS


## The mesh for one character (null for a space or unknown character).
static func letter_mesh(ch: String, cell: float, depth: float) -> ArrayMesh:
	var key := "%s/%.3f/%.3f" % [ch.to_upper(), cell, depth]
	if _cache.has(key):
		return _cache[key]
	var glyph: Array = GLYPHS.get(ch.to_upper(), [])
	if glyph.is_empty():
		return null
	var cols := _columns(glyph)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for r in ROWS:
		var row: String = glyph[r]
		for c in range(cols[0], cols[1] + 1):
			if row[c] != "#":
				continue
			var x := float(c - cols[0]) * cell
			var y := float(ROWS - 1 - r) * cell
			# Skip faces hidden between two neighbouring boxes.
			var left: bool = c > cols[0] and row[c - 1] == "#"
			var right: bool = c < cols[1] and row[c + 1] == "#"
			var up: bool = r > 0 and glyph[r - 1][c] == "#"
			var down: bool = r < ROWS - 1 and glyph[r + 1][c] == "#"
			_box(vertices, normals, Vector3(x, y, -depth * 0.5), Vector3(cell, cell, depth), left, right, up, down)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[key] = mesh
	return mesh


## One box from `origin` (min corner) of `size`, leaving out faces that
## touch a neighbour. Faces wound clockwise as seen from outside.
static func _box(vertices: PackedVector3Array, normals: PackedVector3Array, origin: Vector3, size: Vector3,
		left: bool, right: bool, up: bool, down: bool) -> void:
	var o := origin
	var s := size
	var p := [
		o, o + Vector3(s.x, 0, 0), o + Vector3(s.x, s.y, 0), o + Vector3(0, s.y, 0),
		o + Vector3(0, 0, s.z), o + Vector3(s.x, 0, s.z), o + Vector3(s.x, s.y, s.z), o + Vector3(0, s.y, s.z),
	]
	# front (+Z, toward the viewer): 4 5 6 7, back (-Z): 0 1 2 3
	_face(vertices, normals, p[4], p[7], p[6], p[5], Vector3.BACK)
	_face(vertices, normals, p[0], p[1], p[2], p[3], Vector3.FORWARD)
	if not left:
		_face(vertices, normals, p[0], p[3], p[7], p[4], Vector3.LEFT)
	if not right:
		_face(vertices, normals, p[1], p[5], p[6], p[2], Vector3.RIGHT)
	if not up:
		_face(vertices, normals, p[3], p[2], p[6], p[7], Vector3.UP)
	if not down:
		_face(vertices, normals, p[0], p[4], p[5], p[1], Vector3.DOWN)


static func _face(vertices: PackedVector3Array, normals: PackedVector3Array,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	# Make sure the winding faces the normal (clockwise seen from outside).
	var n := (b - a).cross(c - a)
	var order := [a, b, c, a, c, d] if n.dot(normal) < 0.0 else [a, c, b, a, d, c]
	for v in order:
		vertices.append(v)
		normals.append(normal)
