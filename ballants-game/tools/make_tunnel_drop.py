#!/usr/bin/env python3
"""Generates levels/nest/level_1_tunnel_drop.tscn and its bot drive files.

The course is a "cursor walk": straights and arcs with a slope each, so
every point is computed and the seams meet by construction. Edit the walk
in build(), run this from ballants-game/, and the scene is rewritten.

    python3 tools/make_tunnel_drop.py

Coordinates: the course starts at the origin heading -Z (the StartPoint's
forward). heading 0 = -Z, positive = turning LEFT. y is height.
Everything stays above y = 4 (the ball counts as fallen below -2.5).
"""
import json
import math
import os

START_Y = 76.0


class Walk:
    def __init__(self, y):
        self.x, self.y, self.z = 0.0, y, 0.0
        self.h = 0.0            # heading, radians, 0 = -Z, + = left
        self.pts = []           # (x, y, z)
        self.widths = []
        self.walls = []
        self.marks = {}         # name -> index of a point
        self.sections = []      # (name, start index)
        self._emit(10.0, 3)

    def dir(self):
        return (-math.sin(self.h), -math.cos(self.h))

    def _emit(self, width, walls):
        self.pts.append((round(self.x, 3), round(self.y, 3), round(self.z, 3)))
        self.widths.append(width)
        self.walls.append(walls)

    def mark(self, name):
        self.marks[name] = len(self.pts) - 1

    def section(self, name):
        self.sections.append((name, len(self.pts) - 1))

    def straight(self, length, slope, width, walls, step=5.0):
        n = max(int(math.ceil(length / step)), 1)
        ds = length / n
        dx, dz = self.dir()
        for _ in range(n):
            self.x += dx * ds
            self.z += dz * ds
            self.y -= slope * ds
            self._emit(width, walls)

    def arc(self, degrees, radius, slope, width, walls, step_deg=15.0):
        """Positive degrees = left turn."""
        n = max(int(math.ceil(abs(degrees) / step_deg)), 1)
        da = math.radians(degrees) / n
        arc_len = abs(da) * radius
        for _ in range(n):
            # Turn half, step, turn half: a chord that follows the arc.
            self.h += da * 0.5
            dx, dz = self.dir()
            chord = 2.0 * radius * math.sin(abs(da) * 0.5)
            self.x += dx * chord
            self.z += dz * chord
            self.h += da * 0.5
            self.y -= slope * arc_len
            self._emit(width, walls)

    def pos(self):
        return (self.x, self.y, self.z)


def build():
    w = Walk(START_Y)
    # ---- Section 1: gentle slope, wide, walls both sides, soft turns.
    w.section("gentle")
    w.straight(12, 0.02, 10, 3)
    w.arc(35, 30, 0.06, 10, 3)
    w.straight(10, 0.06, 10, 3)
    w.arc(-50, 28, 0.06, 10, 3)
    w.straight(10, 0.06, 10, 3)
    w.arc(30, 30, 0.06, 10, 3)
    w.straight(8, 0.06, 10, 3)
    # ---- Section 2: the outside wall drops away on the turns.
    w.section("open")
    w.straight(10, 0.08, 8, 3)          # width tapers 10 -> 8 over this
    w.mark("open_right_start")
    w.arc(-75, 9, 0.08, 7, 2)           # right turn: outer = left side open
    w.straight(12, 0.08, 7, 3)
    w.mark("open_left_start")
    w.arc(85, 9, 0.08, 7, 1)            # left turn: outer = right side open
    w.straight(10, 0.08, 7, 3)
    # ---- Section 3: switchbacks down a steep slope.
    w.section("switchbacks")
    w.straight(20, 0.21, 6.5, 3)        # leg 0
    w.mark("turn1_start")
    w.arc(-75, 5, 0.07, 6.5, 3, 25)     # turn 1 (right)...
    w.arc(-15, 5, 0.0, 6.5, 3, 7.5)     # ...level through the apex, in fine
    w.mark("turn1_apex")                 #    steps (the shortcut leaves here)
    w.arc(-15, 5, 0.0, 6.5, 3, 7.5)
    w.arc(-75, 5, 0.07, 6.5, 3, 25)
    w.straight(24, 0.21, 6.5, 3)        # leg 1
    w.arc(180, 5, 0.07, 6.5, 3, 30)     # turn 2 (left)
    w.straight(24, 0.21, 6.5, 3)        # leg 2
    w.arc(-75, 5, 0.07, 6.5, 3, 25)     # turn 3 (right)...
    w.arc(-15, 5, 0.0, 6.5, 3, 7.5)     # ...level through the apex (the
    w.mark("turn3_apex")                 #    shortcut comes back in here)
    w.arc(-15, 5, 0.0, 6.5, 3, 7.5)
    w.arc(-75, 5, 0.07, 6.5, 3, 25)
    w.mark("turn3_end")
    w.straight(24, 0.21, 6.5, 3)        # leg 3
    w.arc(180, 5, 0.07, 6.5, 3, 30)     # turn 4 (left)
    w.straight(14, 0.21, 6.5, 3)        # leg 4
    # ---- Section 4: the crest with the hidden ledge, the plunge, landing, goal.
    w.section("plunge")
    w.straight(6, 0.05, 6.5, 3)
    w.mark("crest")
    w.straight(6, 0.04, 6.5, 3)
    w.mark("plunge_top")
    w.straight(5, 0.2, 6.5, 3, 5.0)     # the lip rolls over...
    w.straight(5, 0.4, 6.5, 3, 5.0)
    w.straight(50, 0.60, 6.5, 3, 5.0)   # ...into 31 degrees
    w.mark("plunge_bottom")
    w.straight(30, 0.0, 7, 3)           # the flat landing
    w.arc(-60, 15, 0.0, 8, 3)           # the final curve (right)
    w.straight(10, 0.0, 10, 3)
    w.mark("plateau_start")
    w.straight(14, 0.0, 16, 3)
    w.mark("goal")
    return w


def fmt(v):
    return ("%.3f" % v).rstrip("0").rstrip(".") if abs(v) > 1e-9 else "0"


def vec3_array(pts):
    return "PackedVector3Array(" + ", ".join(", ".join(fmt(c) for c in p) for p in pts) + ")"


def f32_array(vals):
    return "PackedFloat32Array(" + ", ".join(fmt(v) for v in vals) + ")"


def i32_array(vals):
    return "PackedInt32Array(" + ", ".join(str(v) for v in vals) + ")"


def tangent(pts, i):
    a = pts[max(i - 1, 0)]
    b = pts[min(i + 1, len(pts) - 1)]
    dx, dz = b[0] - a[0], b[2] - a[2]
    n = math.hypot(dx, dz)
    return (dx / n, dz / n)


def right_of(t):
    """Right-hand side of a forward direction (x, z) seen from above."""
    return (-t[1], t[0])


def yaw_deg(t):
    """rotation.y in degrees for a node whose -Z should point along t."""
    return math.degrees(math.atan2(-t[0], -t[1]))


def main():
    w = build()
    pts = w.pts
    # Width taper for the first 10 m of section 2: handled by the point
    # widths (the walk already emits 8 there and the strip lerps 10 -> 8).
    # --- Shortcut: through the OUTER wall at turn 1's apex (turn 1 is a
    # right-hander, so its outside is the LEFT wall), a narrow steep tunnel
    # heads straight out, hairpins right with a 10 m radius (the legs are
    # 10 m apart, so it comes back level with turn 3) and re-enters the
    # course through the outer wall at turn 3's apex. Cuts turns 2 and 3
    # and legs 1 and 2. The crystal sits at the tunnel's own hairpin.
    apex = w.marks["turn1_apex"]
    apex3 = w.marks["turn3_apex"]
    for i in (apex - 2, apex - 1, apex, apex + 1):
        w.walls[i] = 2        # right wall only: the left (outer) wall is gone
    for i in (apex3 - 2, apex3 - 1, apex3, apex3 + 1):
        w.walls[i] = 2
    ta = tangent(pts, apex)
    out1 = tuple(-c for c in right_of(ta))      # outward = left of a right turn
    ap = pts[apex]
    half = w.widths[apex] * 0.5
    ap3 = pts[apex3]
    t3 = tangent(pts, apex3)
    out3 = tuple(-c for c in right_of(t3))
    half3 = w.widths[apex3] * 0.5
    end_pt = (ap3[0] + out3[0] * (half3 - 0.3), ap3[2] + out3[1] * (half3 - 0.3))
    t = Walk(ap[1])
    t.pts = []
    t.widths = []
    t.walls = []
    t.x = ap[0] + out1[0] * (half - 0.3)
    t.z = ap[2] + out1[1] * (half - 0.3)
    t.h = math.atan2(-out1[0], -out1[1])        # heading along `out1`
    t._emit(2.8, 3)
    R = 10.0
    # Work out the slope that lands exactly on turn 3's floor: the stub and
    # the last 4 m are flat, the 4 m after the stub tip over at 0.12.
    out_len = 5.0
    # length of the return straight = distance from the hairpin's end to end_pt
    hx = t.x + out1[0] * (3.3 + 4.0 + out_len) + right_of(out1)[0] * 2 * R
    hz = t.z + out1[1] * (3.3 + 4.0 + out_len) + right_of(out1)[1] * 2 * R
    back_len = math.hypot(end_pt[0] - hx, end_pt[1] - hz)
    drop = ap[1] - ap3[1]
    sloped = out_len + math.pi * R + (back_len - 4.0)
    slope = (drop - 0.12 * 4.0) / sloped
    t.straight(3.3, 0.0, 2.8, 3, 4)      # through the gap (the false wall sits here)
    t.straight(4, 0.12, 2.8, 3, 4)       # tipping over...
    t.straight(out_len, slope, 2.8, 3, 5)
    t.arc(-90, R, slope, 2.8, 3, 22.5)
    t.mark("crystal")
    t.arc(-90, R, slope, 2.8, 3, 22.5)
    # The return straight, aimed at the exit, with the last 4 m flat.
    dist = math.hypot(end_pt[0] - t.x, end_pt[1] - t.z)
    ux, uz = (end_pt[0] - t.x) / dist, (end_pt[1] - t.z) / dist
    sx, sz, sy = t.x, t.z, t.y
    n = max(int(math.ceil((dist - 4.0) / 4.0)), 1)
    for k in range(1, n + 1):
        u = k / n
        d = (dist - 4.0) * u
        t.pts.append((round(sx + ux * d, 3), round(sy - slope * d, 3), round(sz + uz * d, 3)))
        t.widths.append(2.8)
        t.walls.append(3)
    t.pts.append((round(end_pt[0], 3), round(ap3[1], 3), round(end_pt[1], 3)))
    t.widths.append(2.8)
    t.walls.append(3)
    tunnel_pts, tunnel_w, tunnel_walls = t.pts, t.widths, t.walls
    crystal_a = t.pts[t.marks["crystal"]]
    merge_i = apex3

    # --- False wall across the gap at turn 1's apex: centered on the apex
    # point's outer edge, along the wall line (the tangent).
    gap_center = (ap[0] + out1[0] * half, ap[1], ap[2] + out1[1] * half)
    false_wall_yaw = yaw_deg(ta)

    # --- The ledge pocket at the crest, on the right side.
    ci = w.marks["crest"]
    ct = tangent(pts, ci)
    cr = right_of(ct)
    cp = pts[ci]
    chalf = w.widths[ci] * 0.5
    for i in (ci - 1, ci):
        w.walls[i] = 1                   # open the right wall here
    pocket_center = (cp[0] + cr[0] * (chalf + 2.0), cp[1], cp[2] + cr[1] * (chalf + 2.0))
    pocket_yaw = yaw_deg(ct)
    crystal_b = (cp[0] + cr[0] * (chalf + 3.4) - ct[0] * 1.6, cp[1], cp[2] + cr[1] * (chalf + 3.4) - ct[1] * 1.6)
    # The big root: grows out of the wall at the uphill end of the gap and
    # arches across the pocket's uphill half.
    root_base = (cp[0] - ct[0] * 2.6 + cr[0] * (chalf + 0.3), cp[1], cp[2] - ct[1] * 2.6 + cr[1] * (chalf + 0.3))

    goal = pts[w.marks["goal"]]
    start = pts[0]

    # ------------------------------------------------------------ scene
    lines = []
    lines.append('[gd_scene format=3]\n')
    lines.append('[ext_resource type="Script" path="res://levels/level.gd" id="1_level"]')
    lines.append('[ext_resource type="PackedScene" path="res://levels/nest/anthill_theme.tscn" id="2_theme"]')
    lines.append('[ext_resource type="PackedScene" path="res://src/objects/start_point.tscn" id="3_start"]')
    lines.append('[ext_resource type="PackedScene" path="res://src/objects/ant_hill.tscn" id="4_goal"]')
    lines.append('[ext_resource type="PackedScene" path="res://src/objects/fall_zone.tscn" id="5_fall"]')
    lines.append('[ext_resource type="Script" path="res://src/objects/nest/dirt_track.gd" id="6_track"]')
    lines.append('[ext_resource type="Script" path="res://src/objects/nest/false_wall.gd" id="7_false"]')
    lines.append('[ext_resource type="Script" path="res://src/objects/nest/dirt_wall.gd" id="8_wall"]')
    lines.append('[ext_resource type="Script" path="res://src/objects/nest/root.gd" id="9_root"]')
    lines.append('[ext_resource type="PackedScene" path="res://src/objects/hidden_crystal.tscn" id="10_crystal"]')
    lines.append('[ext_resource type="PackedScene" path="res://src/objects/nest/dirt_slab.tscn" id="11_slab"]')
    lines.append('[ext_resource type="Script" path="res://src/objects/nest/glow_fungus.gd" id="12_fungus"]')
    lines.append('[ext_resource type="Script" path="res://src/objects/nest/wall_crystal.gd" id="13_wcrystal"]')
    lines.append('')
    lines.append('; LEVEL 1 -- TUNNEL DROP. GENERATED by tools/make_tunnel_drop.py; edit the')
    lines.append('; walk there and re-run it rather than moving points by hand.')
    lines.append('[node name="Level1TunnelDrop" type="Node3D"]')
    lines.append('script = ExtResource("1_level")')
    lines.append('level_name = "Tunnel Drop"\n')
    lines.append('[node name="AnthillTheme" parent="." instance=ExtResource("2_theme")]\n')
    lines.append('[node name="StartPoint" parent="." instance=ExtResource("3_start")]')
    lines.append('position = Vector3(%s, %s, %s)\n' % (fmt(start[0]), fmt(start[1]), fmt(start[2])))
    lines.append('[node name="Track" type="StaticBody3D" parent="."]')
    lines.append('script = ExtResource("6_track")')
    lines.append('points = ' + vec3_array(pts))
    lines.append('widths = ' + f32_array(w.widths))
    lines.append('walls = ' + i32_array(w.walls))
    lines.append('wall_height = 3.0')
    lines.append('lights_every = 13.0')
    lines.append('seed = 11\n')
    lines.append('[node name="Shortcut" type="StaticBody3D" parent="."]')
    lines.append('script = ExtResource("6_track")')
    lines.append('points = ' + vec3_array(tunnel_pts))
    lines.append('widths = ' + f32_array(tunnel_w))
    lines.append('walls = ' + i32_array(tunnel_walls))
    lines.append('wall_height = 2.6')
    lines.append('ceiling_height = 2.6')
    lines.append('floor_thickness = 0.6')
    lines.append('lights_every = 9.0')
    lines.append('samples_per_meter = 1.2')
    lines.append('seed = 23\n')
    lines.append('[node name="FalseWall" type="Node3D" parent="."]')
    lines.append('script = ExtResource("7_false")')
    lines.append('position = Vector3(%s, %s, %s)' % tuple(fmt(c) for c in gap_center))
    lines.append('rotation_degrees = Vector3(0, %s, 0)' % fmt(false_wall_yaw))
    lines.append('length = 4.6')
    lines.append('height = 3.0')
    lines.append('thickness = 0.6')
    lines.append('subtlety = 0.75')
    lines.append('lean = 0.18')
    lines.append('seed = 4\n')
    lines.append('[node name="ShortcutCrystal" parent="." instance=ExtResource("10_crystal")]')
    lines.append('position = Vector3(%s, %s, %s)' % (fmt(crystal_a[0]), fmt(crystal_a[1] + 0.1), fmt(crystal_a[2])))
    lines.append('which = 0')
    lines.append('size = 0.7\n')
    # The pocket: a slab flush with the track floor, three walls, the root, the crystal.
    lines.append('[node name="Pocket" type="Node3D" parent="."]')
    lines.append('position = Vector3(%s, %s, %s)' % tuple(fmt(c) for c in pocket_center))
    lines.append('rotation_degrees = Vector3(0, %s, 0)\n' % fmt(pocket_yaw))
    lines.append('[node name="Floor" parent="Pocket" instance=ExtResource("11_slab")]')
    lines.append('position = Vector3(-0.5, -0.5, 0)')
    lines.append('size = Vector3(5.6, 1, 5.4)\n')
    lines.append('[node name="WallBack" parent="Pocket" type="StaticBody3D"]')
    lines.append('script = ExtResource("8_wall")')
    lines.append('position = Vector3(2.5, 0, 0)')
    lines.append('length = 6.4')
    lines.append('height = 3.0')
    lines.append('thickness = 0.8')
    lines.append('seed = 31\n')
    lines.append('[node name="WallUphill" parent="Pocket" type="StaticBody3D"]')
    lines.append('script = ExtResource("8_wall")')
    lines.append('position = Vector3(0.2, 0, 2.9)')
    lines.append('rotation_degrees = Vector3(0, 90, 0)')
    lines.append('length = 5.2')
    lines.append('height = 3.0')
    lines.append('thickness = 0.8')
    lines.append('seed = 32\n')
    lines.append('[node name="WallDownhill" parent="Pocket" type="StaticBody3D"]')
    lines.append('script = ExtResource("8_wall")')
    lines.append('position = Vector3(0.2, 0, -2.9)')
    lines.append('rotation_degrees = Vector3(0, 90, 0)')
    lines.append('length = 5.2')
    lines.append('height = 3.0')
    lines.append('thickness = 0.8')
    lines.append('seed = 33\n')
    # The root: from the uphill wall corner near the track, arching across
    # the pocket's mouth on its uphill half, back into the ground.
    lines.append('[node name="BigRoot" parent="Pocket" type="Node3D"]')
    lines.append('script = ExtResource("9_root")')
    lines.append('position = Vector3(-2.6, 0, 2.6)')
    lines.append('points = PackedVector3Array(0.4, 2.2, 0.6, -0.6, 2.4, -0.3, -0.9, 1.3, -1.6, -0.7, 0.2, -2.6, 0.2, -0.4, -3.2)')
    lines.append('radius = 0.55')
    lines.append('rootlets = 4')
    lines.append('seed = 8\n')
    lines.append('[node name="SmallRoot" parent="Pocket" type="Node3D"]')
    lines.append('script = ExtResource("9_root")')
    lines.append('position = Vector3(2.2, 1.6, 1.4)')
    lines.append('points = PackedVector3Array(0, 0, 0, -0.9, 0.3, -0.4, -1.6, -0.6, -0.9)')
    lines.append('radius = 0.2')
    lines.append('solid = false')
    lines.append('rootlets = 2')
    lines.append('seed = 9\n')
    lines.append('[node name="LedgeCrystal" parent="Pocket" instance=ExtResource("10_crystal")]')
    lines.append('position = Vector3(1.4, 0, 1.6)')
    lines.append('which = 1')
    lines.append('size = 0.7\n')
    # Roots poking through walls along the way (decoration, solid off).
    root_spots = [("gentle", 3, 1.0), ("gentle", 7, -1.0), ("open", 1, 1.0), ("switchbacks", 4, -1.0),
                  ("switchbacks", 16, 1.0), ("plunge", 9, -1.0), ("plunge", 14, 1.0)]
    sec = dict(w.sections)
    k = 0
    for name, offset, side in root_spots:
        i = min(sec[name] + offset, len(pts) - 2)
        if (w.walls[i] & (2 if side > 0 else 1)) == 0:
            continue
        tt = tangent(pts, i)
        rr = right_of(tt)
        p = pts[i]
        h = w.widths[i] * 0.5
        bx, bz = p[0] + rr[0] * side * (h + 0.3), p[2] + rr[1] * side * (h + 0.3)
        k += 1
        lines.append('[node name="WallRoot%d" parent="." type="Node3D"]' % k)
        lines.append('script = ExtResource("9_root")')
        lines.append('position = Vector3(%s, %s, %s)' % (fmt(bx), fmt(p[1] + 1.2 + 0.4 * (k % 3)), fmt(bz)))
        lines.append('rotation_degrees = Vector3(0, %s, 0)' % fmt(yaw_deg(tt) + (90 if side > 0 else -90)))
        lines.append('points = PackedVector3Array(0, 0.6, 0, 0.3, 0.9, -1.0, -0.2, 0.3, -1.8, 0.4, -0.9, -2.2)')
        lines.append('radius = %s' % fmt(0.3 + 0.1 * (k % 2)))
        lines.append('solid = false')
        lines.append('rootlets = 3')
        lines.append('seed = %d\n' % (40 + k))
    # Amber wall crystals at the two open-edge turns (landmarks for the edge).
    for n, (mark, side) in enumerate((("open_right_start", -1.0), ("open_left_start", 1.0))):
        i = w.marks[mark] + 2
        tt = tangent(pts, i)
        rr = right_of(tt)
        p = pts[i]
        h = w.widths[i] * 0.5
        lines.append('[node name="EdgeCrystal%d" parent="." type="Node3D"]' % (n + 1))
        lines.append('script = ExtResource("13_wcrystal")')
        lines.append('position = Vector3(%s, %s, %s)' % (fmt(p[0] + rr[0] * side * (h + 1.5)), fmt(p[1] - 1.0), fmt(p[2] + rr[1] * side * (h + 1.5))))
        lines.append('size = 1.3')
        lines.append('light_range = 14.0')
        lines.append('seed = %d\n' % (60 + n))
    # Plunge-bottom crystals and a glow on the goal plateau.
    lines.append('[node name="GoalGlow" parent="." type="Node3D"]')
    lines.append('script = ExtResource("12_fungus")')
    lines.append('position = Vector3(%s, %s, %s)' % (fmt(goal[0] + 5.0), fmt(goal[1]), fmt(goal[2] + 4.0)))
    lines.append('size = 1.3')
    lines.append('light_energy = 2.0')
    lines.append('light_range = 16.0')
    lines.append('seed = 70\n')
    lines.append('[node name="AntHill" parent="." instance=ExtResource("4_goal")]')
    lines.append('position = Vector3(%s, %s, %s)' % (fmt(goal[0]), fmt(goal[1]), fmt(goal[2])))
    lines.append('base_radius = 5.0\n')
    lines.append('[node name="FallZone" parent="." instance=ExtResource("5_fall")]')
    lines.append('position = Vector3(0, -1, -120)')
    lines.append('size = Vector3(600, 4, 600)')
    scene = "\n".join(lines) + "\n"
    out = os.path.join(os.path.dirname(__file__), "..", "levels", "nest", "level_1_tunnel_drop.tscn")
    with open(out, "w") as f:
        f.write(scene)

    # ------------------------------------------------------------ drives
    def waypoints(indices_speeds):
        out = []
        for i, speed, reach in indices_speeds:
            p = pts[i]
            out.append({"pos": [round(p[0], 2), round(p[1], 2), round(p[2], 2)], "speed": speed, "reach": reach})
        return out

    # Main route: every other point, slower into the open turns and the switchbacks.
    sec = dict(w.sections)
    route = []
    for i in range(1, len(pts)):
        name = [n for n, s in w.sections if s <= i][-1]
        speed = 9
        reach = 2.0
        if name == "open":
            speed = 8
            reach = 1.8
        elif name == "switchbacks":
            speed = 6.0
            reach = 1.6
        elif name == "plunge":
            speed = 9
            reach = 2.5
            if i >= w.marks["plunge_bottom"]:
                speed = 7
        if i == w.marks["goal"]:
            speed = 4
            reach = 0.4
        route.append((i, speed, reach))
    drive = {"level": 1, "timeout": 240, "speed": 8, "waypoints": waypoints(route)}
    tests = os.path.join(os.path.dirname(__file__), "..", "tests", "levels")
    with open(os.path.join(tests, "level_1_tunnel_drop.json"), "w") as f:
        json.dump(drive, f)

    # Shortcut route: main route to turn 1's apex, through the tunnel, then
    # leg 3 onward. Expects the tunnel crystal (hidden 0).
    short = [(i, s, r) for i, s, r in route if i <= w.marks["turn1_apex"]]
    short_pts = [{"pos": [round(p[0], 2), round(p[1], 2), round(p[2], 2)], "speed": 5.0, "reach": 1.2} for p in tunnel_pts[1:]]
    tail = [(i, s, r) for i, s, r in route if i > merge_i]
    drive2 = {"level": 1, "timeout": 240, "speed": 8, "expect_hidden": [0],
              "waypoints": waypoints(short) + short_pts + waypoints(tail)}
    with open(os.path.join(tests, "level_1_tunnel_drop_shortcut.json"), "w") as f:
        json.dump(drive2, f)

    # Ledge route: main route, but at the crest turn into the pocket for the
    # second crystal, come back out, then on down. Expects hidden 1.
    before = [(i, s, r) for i, s, r in route if i <= w.marks["crest"] - 1]
    ci = w.marks["crest"]
    ct = tangent(pts, ci)
    cr = right_of(ct)
    cp = pts[ci]
    chalf = w.widths[ci] * 0.5
    mouth = [round(cp[0] - ct[0] * 1.0 + cr[0] * (chalf - 0.5), 2), round(cp[1], 2), round(cp[2] - ct[1] * 1.0 + cr[1] * (chalf - 0.5), 2)]
    inside = [round(crystal_b[0], 2), round(crystal_b[1], 2), round(crystal_b[2], 2)]
    back = [round(cp[0] + ct[0] * 2.0, 2), round(cp[1], 2), round(cp[2] + ct[1] * 2.0, 2)]
    after = [(i, s, r) for i, s, r in route if i > w.marks["crest"]]
    drive3 = {"level": 1, "timeout": 240, "speed": 8, "expect_hidden": [1],
              "waypoints": waypoints(before) + [
                  {"pos": [round(cp[0] - ct[0] * 3.0, 2), round(cp[1], 2), round(cp[2] - ct[1] * 3.0, 2)], "speed": 3.0, "reach": 1.0},
                  {"pos": mouth, "speed": 3.0, "reach": 1.0},
                  {"pos": inside, "speed": 3.0, "reach": 0.8},
                  {"pos": mouth, "speed": 3.0, "reach": 1.0},
                  {"pos": back, "speed": 4.0, "reach": 1.2}] + waypoints(after)}
    with open(os.path.join(tests, "level_1_tunnel_drop_ledge.json"), "w") as f:
        json.dump(drive3, f)

    # A summary for the notes.
    total = 0.0
    for i in range(1, len(pts)):
        a, b = pts[i - 1], pts[i]
        total += math.dist(a, b)
    print("points: %d, centerline length %.0f m, drop %.1f m, goal at %s" % (len(pts), total, pts[0][1] - goal[1], goal))
    for name, i in w.sections:
        print("  section %-12s starts at point %3d  %s" % (name, i, pts[i]))
    print("  shortcut: %d points, crystal at %s" % (len(tunnel_pts), crystal_a))
    print("  ledge crystal at %s" % (crystal_b,))


if __name__ == "__main__":
    main()
