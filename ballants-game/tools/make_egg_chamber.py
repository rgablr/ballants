#!/usr/bin/env python3
"""Generates levels/nest/level_2_egg_chamber.tscn and its bot drive files.

    python3 tools/make_egg_chamber.py          (from ballants-game/)
    python3 tools/make_egg_chamber.py --map    (also print a top-view map)

The level is one round nursery chamber (NurseryChamber, radius 48, floor
at y = 4). Inside it, in order:
  1. Egg rows: a winding lane fenced by rows of eggs (EggPile).
  2. The bowl: a U-shaped skate bowl (EggBowl); you come in up one leg,
     carve round the curved wall and leave down the other.
  3. Spiral ramp: a shelf (DirtTrack) that rides the room's outer wall,
     clockwise, 200 degrees round and 10 m up, to a high ledge.
  4. Nursery bridge: a wall-less DirtTrack curving over the eggs to the
     egg mound in the middle of the room, where the ant hill is.

Coordinates: x east, z south (+Z), y up. Headings: 0 = -Z (north),
positive = turning LEFT, like tools/make_tunnel_drop.py. Room angles
("phi") are measured from +X toward +Z (0 = east, 90 = south).
"""
import json
import math
import os
import random
import sys

FLOOR = 4.0
ROOM_R = 48.0
LANE_HALF = 4.6            # lane centerline to egg-row centerline (m)
ROW_R = 0.95               # egg row half-thickness
ROW_H = 1.85               # egg row height (a jump apex is 1.59 m)
SEG = 3.4                  # egg row segment length

# The bowl (EggBowl) and where it stands.
BOWL = dict(floor_radius=5.0, leg_length=14.0, pipe_radius=4.5, pipe_angle=85.0, height=9.0, rim_width=1.2)
BOWL_POS = (6.0, FLOOR, -31.0)      # center of the round end
BOWL_YAW = 0.0                        # round end toward -Z (north), mouth south
DIVIDER_R = 1.0                       # half-thickness of the egg row splitting the mouth
DIVIDER_TIP_Z = -1.5                  # the divider runs from the mouth to here (bowl local z)
CENTER_HEAP_R = 1.6                   # the egg heap at the divider's tip

# The spiral shelf along the room wall.
SPIRAL_R = 43.3
SPIRAL_RISE = 10.0
SPIRAL_SWEEP = 200.0
SPIRAL_W = 6.5

# The egg mound (goal) in the middle.
MOUND_POS = (19.0, FLOOR, 12.0)
MOUND_TOP = FLOOR + SPIRAL_RISE      # same height as the ledge
MOUND_R = 7.0

LANE_START_X = 18.0
LANE_START_Z = 27.0
TRANSFER_STRAIGHT = 4.0
# The bridge's walk from the ledge: a right turn back over the room, an S
# over the egg lane, a left turn toward the mound, then it steers onto it.
BRIDGE_WALK = [("arc", -145, 11.0), ("straight", 4, 0), ("arc", 35, 18.0), ("arc", -45, 18.0), ("straight", 2, 0), ("arc", 95, 14.0)]

BRIDGE_W = 3.8
BRIDGE_SAG = 1.2
BRIDGE_BOT_SPEED = 8.0
# The bot's line round the bowl's round end (from its center) and speed:
# out on the wall's foot at full speed (the carve).
CARVE_R = 7.6
CARVE_SPEED = 9.5
CARVE_REACH = 2.2
FUNNEL_LEN = 9.0
# Hidden crystal 0, in the bowl's local space (x, height above the bowl
# floor, z): on the round end, where the west leg's line meets the wall.
HIDDEN0_LOCAL = (-1.25, 6.63, -9.1)
HIDDEN0_PICKUP = 1.6
# The bot rolls straight up the west leg's middle at full speed, holding
# toward this point far beyond the wall (bowl local x, z); it counts as
# reached at the top of the climb (`reach` m), then the bot rolls on.
HIDDEN0_AIM = (-3.0, -16.0, 7.17)
LOOSE_HEAPS = 26

OUT_SCENE = "levels/nest/level_2_egg_chamber.tscn"
OUT_DRIVE = "tests/levels/level_2_egg_chamber.json"
OUT_DRIVE_BOWL = "tests/levels/level_2_egg_chamber_crystals.json"
OUT_DRIVE_NOOK = "tests/levels/level_2_egg_chamber_shortcut.json"


# ------------------------------------------------------------- walking ----

class Walk:
    """A cursor that leaves a dense centerline (every ~1 m) behind it."""

    def __init__(self, x, y, z, heading_deg):
        self.x, self.y, self.z = x, y, z
        self.h = math.radians(heading_deg)
        self.pts = [(x, y, z)]
        self.marks = {}

    def dir(self):
        return (-math.sin(self.h), -math.cos(self.h))

    def mark(self, name):
        self.marks[name] = len(self.pts) - 1

    def straight(self, length, rise=0.0):
        n = max(int(math.ceil(length)), 1)
        dx, dz = self.dir()
        for _ in range(n):
            self.x += dx * length / n
            self.z += dz * length / n
            self.y += rise / n
            self.pts.append((self.x, self.y, self.z))

    def arc(self, degrees, radius, rise=0.0):
        n = max(int(math.ceil(abs(math.radians(degrees)) * radius)), 2)
        da = math.radians(degrees) / n
        for _ in range(n):
            self.h += da * 0.5
            dx, dz = self.dir()
            chord = 2.0 * radius * math.sin(abs(da) * 0.5)
            self.x += dx * chord
            self.z += dz * chord
            self.h += da * 0.5
            self.y += rise / n
            self.pts.append((self.x, self.y, self.z))


def tangent(pts, i):
    a = pts[max(i - 1, 0)]
    b = pts[min(i + 1, len(pts) - 1)]
    dx, dz = b[0] - a[0], b[2] - a[2]
    n = math.hypot(dx, dz) or 1.0
    return (dx / n, dz / n)


def right_of(t):
    """Right-hand side of a forward direction (x, z), seen from above."""
    return (-t[1], t[0])


def yaw_deg(t):
    """rotation.y in degrees for a node whose -Z should point along t."""
    return math.degrees(math.atan2(-t[0], -t[1]))


def offset_curve(pts, side):
    out = []
    for i, p in enumerate(pts):
        r = right_of(tangent(pts, i))
        out.append((p[0] + r[0] * side, p[1], p[2] + r[1] * side))
    return out


def polyline_length(pts):
    return sum(math.dist((a[0], a[2]), (b[0], b[2])) for a, b in zip(pts, pts[1:]))


def resample(pts, step):
    """Points every `step` meters along a polyline (keeps both ends)."""
    out = [pts[0]]
    carry = 0.0
    for a, b in zip(pts, pts[1:]):
        seg = math.dist((a[0], a[2]), (b[0], b[2]))
        d = step - carry
        while d <= seg:
            u = d / seg
            out.append(tuple(a[k] + (b[k] - a[k]) * u for k in range(3)))
            d += step
        carry = seg - (d - step)
    if math.dist((out[-1][0], out[-1][2]), (pts[-1][0], pts[-1][2])) > step * 0.3:
        out.append(pts[-1])
    return out


# ---------------------------------------------------------------- bowl ----

def bowl_profile():
    rows = [(-0.6, -0.04)]
    steps = int(math.ceil(BOWL["pipe_angle"] / 2.5))
    R = BOWL["pipe_radius"]
    for k in range(steps + 1):
        a = math.radians(BOWL["pipe_angle"] * k / steps)
        rows.append((R * math.sin(a), R * (1 - math.cos(a))))
    top = rows[-1]
    a = math.radians(BOWL["pipe_angle"])
    extra = (BOWL["height"] - top[1]) / math.sin(a)
    rows.append((top[0] + math.cos(a) * extra, top[1] + math.sin(a) * extra))
    return rows


def bowl_local_to_world(x, y, z):
    c, s = math.cos(math.radians(BOWL_YAW)), math.sin(math.radians(BOWL_YAW))
    return (BOWL_POS[0] + x * c + z * s, BOWL_POS[1] + y, BOWL_POS[2] - x * s + z * c)


def bowl_outer():
    return BOWL["floor_radius"] + bowl_profile()[-1][0] + BOWL["rim_width"]


# --------------------------------------------------------------- build ----

def min_radius(pts):
    """Smallest turning radius along a dense polyline (m), and where."""
    best = (1e9, None)
    for i in range(2, len(pts) - 2):
        a, b, c = pts[i - 2], pts[i], pts[i + 2]
        ab = math.dist((a[0], a[2]), (b[0], b[2]))
        bc = math.dist((b[0], b[2]), (c[0], c[2]))
        ac = math.dist((a[0], a[2]), (c[0], c[2]))
        cross = abs((b[0] - a[0]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[0] - a[0]))
        if cross < 1e-9:
            continue
        r = ab * bc * ac / (2 * cross)
        if r < best[0]:
            best = (r, (round(b[0], 1), round(b[2], 1)))
    return best


def eased_ramp(u, e):
    """0..1 over u = 0..1: a straight ramp with its first and last `e`
    eased (constant curvature ends), so the steepest slope is only
    1 / (1 - e) times the average."""
    k = 1.0 / (1.0 - e)            # slope of the straight middle
    if u < e:
        return k * u * u / (2 * e)
    if u > 1 - e:
        return 1.0 - k * (1 - u) ** 2 / (2 * e)
    return k * (u - e / 2)


def steer_to(w, target, radius, stop_short=0.0, rise_per_m=0.0):
    """Arc toward (x, z) until pointing at it, then roll straight to it."""
    for _ in range(200):
        d = w.dir()
        tx, tz = target[0] - w.x, target[1] - w.z
        n = math.hypot(tx, tz)
        left = (d[1], -d[0])
        cross = (tx * left[0] + tz * left[1]) / n
        dot = (tx * d[0] + tz * d[1]) / n
        ang = math.degrees(math.atan2(cross, dot))
        if abs(ang) < 1.0:
            break
        step = max(-2.0, min(2.0, ang))
        w.arc(step, radius, rise_per_m * abs(math.radians(step)) * radius)
    else:
        raise RuntimeError("steer_to: target inside the turning circle")
    n = math.hypot(target[0] - w.x, target[1] - w.z) - stop_short
    if n > 0.1:
        w.straight(n, rise_per_m * n)


def build():
    r0 = BOWL["floor_radius"]
    leg_x = (r0 + DIVIDER_R) * 0.5          # leg centerline, from the bowl axis
    L = BOWL["leg_length"]
    west_mouth = bowl_local_to_world(-leg_x, 0, L)
    east_mouth = bowl_local_to_world(leg_x, 0, L)

    # ---- 1. Egg rows: a winding lane from the start to the west leg:
    # west along the south of the room with a soft S, a wide right-hand
    # U-turn, then a left turn north into the bowl's west leg.
    uturn_r, last_r = 12.0, 12.0
    lane = Walk(LANE_START_X, FLOOR, LANE_START_Z, 90)
    lane.mark("start")
    lane.straight(6)
    lane.mark("wiggle")
    lane.arc(-28, 16)
    lane.arc(28, 16)
    # straight west until the U-turn's center line is last_r west of the
    # mouth line (the U-turn and the last bend then line up exactly)
    lane.straight(lane.x - (west_mouth[0] - last_r))
    lane.mark("uturn")
    lane.arc(-180, uturn_r)
    lane.mark("uturn_end")
    lane.straight(max((west_mouth[0] - last_r) - lane.x, 0.0))
    lane.mark("last_bend")
    lane.arc(90, last_r)
    lane.mark("last_bend_end")
    lane.straight(lane.z - west_mouth[2])
    lane.mark("lane_end")      # at the mouth: the bowl's walls take over

    # ---- 2b. Transfer lane: from the east mouth heading south, a left turn
    # then a right turn that ends on the spiral's circle, tangent to it.
    r1, r2 = 9.0, 12.0
    best = None
    for a1_10 in range(300, 1300, 2):
        a1 = a1_10 / 10.0
        t = Walk(east_mouth[0], FLOOR, east_mouth[2], 180.0)
        t.straight(TRANSFER_STRAIGHT)
        t.arc(a1, r1)
        for a2 in range(1, 200):
            tt = Walk(t.x, FLOOR, t.z, math.degrees(t.h))
            tt.arc(-a2, r2)
            rad = math.hypot(tt.x, tt.z)
            phi = math.degrees(math.atan2(tt.z, tt.x))
            want = (-math.sin(math.radians(phi)), math.cos(math.radians(phi)))
            err = abs(rad - SPIRAL_R) + 4.0 * math.dist(want, tt.dir())
            if best is None or err < best[0]:
                best = (err, a1, a2, phi)
    _, a1, a2, phi0 = best
    transfer = Walk(east_mouth[0], FLOOR, east_mouth[2], 180.0)
    transfer.straight(TRANSFER_STRAIGHT)
    transfer.mark("turn1")
    transfer.arc(a1, r1)
    transfer.mark("turn2")
    transfer.arc(-a2, r2)
    transfer.mark("spiral_foot")

    # ---- 3. Spiral: from phi0 clockwise, SPIRAL_RISE up, eased in and out.
    spiral = []
    n = int(SPIRAL_SWEEP / 4)
    lead = 2      # two points behind the foot, just under the floor
    for i in range(-lead, n + 1):
        u = max(i / n, 0.0)
        phi = math.radians(phi0 + SPIRAL_SWEEP * i / n)
        rise = SPIRAL_RISE * eased_ramp(u, 0.12)
        y = FLOOR + rise - (0.06 if i <= 0 else 0.0)
        spiral.append((SPIRAL_R * math.cos(phi), y, SPIRAL_R * math.sin(phi)))
    phi1 = phi0 + SPIRAL_SWEEP
    # The ledge: flat, along the circle, widening.
    for i in range(1, 4):
        phi = math.radians(phi1 + i * 4.0)
        spiral.append((SPIRAL_R * math.cos(phi), FLOOR + SPIRAL_RISE, SPIRAL_R * math.sin(phi)))
    ledge_n = 3

    # ---- 4. Bridge: from the ledge over the egg lane to the mound.
    lp = spiral[-1]
    t_led = tangent(spiral, len(spiral) - 1)
    bridge = Walk(lp[0], FLOOR + SPIRAL_RISE, lp[2], math.degrees(math.atan2(-t_led[0], -t_led[1])))
    bridge.pts = [lp]
    for kind, a, b in BRIDGE_WALK:
        if kind == "arc":
            bridge.arc(a, b)
        else:
            bridge.straight(a)
    mx, mz = MOUND_POS[0], MOUND_POS[2]
    steer_to(bridge, (mx, mz), 14.0, stop_short=MOUND_R - 1.5)
    bridge.mark("mound_edge")
    return dict(lane=lane, transfer=transfer, spiral=spiral, ledge_n=ledge_n, lead=lead, bridge=bridge,
                phi0=phi0, phi1=phi1, west_mouth=west_mouth, east_mouth=east_mouth, leg_x=leg_x)


# ----------------------------------------------------------------- map ----

def ascii_map(d, extra=()):
    W = 96
    grid = [[" "] * W for _ in range(W // 2 + 1)]

    def put(x, z, c):
        i = int(x + 48)
        j = int((z + 48) / 2)
        if 0 <= i < W and 0 <= j < len(grid):
            grid[j][i] = c
    for a in range(360):
        put(ROOM_R * math.cos(math.radians(a)), ROOM_R * math.sin(math.radians(a)), "#")
    for p in d["lane"].pts + d["transfer"].pts:
        put(p[0], p[2], ".")
    for kind, x, z in d.get("piles", []):
        put(x, z, kind)
    for p in d["spiral"]:
        put(p[0], p[2], "S")
    for p in d["bridge"].pts:
        put(p[0], p[2], "=")
    r0 = BOWL["floor_radius"]
    ro = bowl_outer()
    for a in range(0, 181, 3):
        for rr, c in ((r0, "b"), (ro, "B")):
            p = bowl_local_to_world(-rr * math.cos(math.radians(a)), 0, -rr * math.sin(math.radians(a)))
            put(p[0], p[2], c)
    for zz in range(0, int(BOWL["leg_length"]) + 1):
        for rr, c in ((r0, "b"), (ro, "B")):
            for sgn in (-1, 1):
                p = bowl_local_to_world(sgn * rr, 0, zz)
                put(p[0], p[2], c)
    for a in range(0, 360, 6):
        put(MOUND_POS[0] + MOUND_R * math.cos(math.radians(a)), MOUND_POS[2] + MOUND_R * math.sin(math.radians(a)), "M")
    for x, z, c in extra:
        put(x, z, c)
    print("\n".join("".join(r) for r in grid))



# ---------------------------------------------------------------- emit ----

def fmt(v):
    return ("%.3f" % v).rstrip("0").rstrip(".") if abs(v) > 1e-9 else "0"


def v3(p):
    return "Vector3(%s, %s, %s)" % (fmt(p[0]), fmt(p[1]), fmt(p[2]))


def vec3_array(pts):
    return "PackedVector3Array(" + ", ".join(", ".join(fmt(c) for c in p) for p in pts) + ")"


def f32_array(vals):
    return "PackedFloat32Array(" + ", ".join(fmt(v) for v in vals) + ")"


def i32_array(vals):
    return "PackedInt32Array(" + ", ".join(str(v) for v in vals) + ")"


class Scene:
    def __init__(self):
        self.ext = []
        self.nodes = []
        self.ids = {}

    def res(self, kind, path):
        if path not in self.ids:
            rid = "%d_%s" % (len(self.ext) + 1, os.path.splitext(os.path.basename(path))[0])
            self.ids[path] = rid
            self.ext.append('[ext_resource type="%s" path="res://%s" id="%s"]' % (kind, path, rid))
        return self.ids[path]

    def comment(self, text):
        self.nodes.append("\n".join("; " + line for line in text.split("\n")))

    def script_node(self, name, node_type, script, props, parent="."):
        rid = self.res("Script", script)
        lines = ['[node name="%s" type="%s" parent="%s"]' % (name, node_type, parent), 'script = ExtResource("%s")' % rid]
        lines += ["%s = %s" % kv for kv in props]
        self.nodes.append("\n".join(lines))

    def instance(self, name, scene, props, parent="."):
        rid = self.res("PackedScene", scene)
        lines = ['[node name="%s" parent="%s" instance=ExtResource("%s")]' % (name, parent, rid)]
        lines += ["%s = %s" % kv for kv in props]
        self.nodes.append("\n".join(lines))

    def text(self, root_name, level_name):
        head = ["[gd_scene format=3]", ""] + self.ext + [""]
        root = ['; LEVEL 2 -- EGG CHAMBER. GENERATED by tools/make_egg_chamber.py; edit the',
                '; layout there and re-run it rather than moving things by hand.',
                '[node name="%s" type="Node3D"]' % root_name,
                'script = ExtResource("%s")' % self.ids["levels/level.gd"],
                'level_name = "%s"' % level_name]
        return "\n".join(head + root) + "\n\n" + "\n\n".join(self.nodes) + "\n"


def row_segments(curve, seg=SEG):
    """Split a polyline into straight EggPile rows ~seg long (they overlap
    by ROW_R at each end so the fence has no gaps)."""
    pts = resample(curve, seg)
    out = []
    for a, b in zip(pts, pts[1:]):
        length = math.dist((a[0], a[2]), (b[0], b[2]))
        if length < 0.3:
            continue
        mid = ((a[0] + b[0]) / 2, FLOOR, (a[2] + b[2]) / 2)
        yaw = math.degrees(math.atan2(-(b[2] - a[2]), b[0] - a[0]))
        out.append((mid, yaw, length + ROW_R * 0.8))
    return out


def funnel(curve, target, length):
    """Bends the last `length` meters of a row curve so it ends at target."""
    total = polyline_length(curve)
    out = []
    acc = 0.0
    end = curve[-1]
    for i, p in enumerate(curve):
        if i > 0:
            acc += math.dist((p[0], p[2]), (curve[i - 1][0], curve[i - 1][2]))
        u = max(0.0, (acc - (total - length)) / length)
        u = u * u * (3 - 2 * u)
        out.append((p[0] + (target[0] - end[0]) * u, p[1], p[2] + (target[2] - end[2]) * u))
    return out


def dist_to_polyline(x, z, pts):
    best = 1e9
    for a, b in zip(pts, pts[1:]):
        ax, az, bx, bz = a[0], a[2], b[0], b[2]
        dx, dz = bx - ax, bz - az
        L2 = dx * dx + dz * dz or 1e-9
        u = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / L2))
        best = min(best, math.hypot(x - (ax + dx * u), z - (az + dz * u)))
    return best


def emit(d):
    sc = Scene()
    sc.res("Script", "levels/level.gd")
    lane, transfer, spiral, bridge = d["lane"], d["transfer"], d["spiral"], d["bridge"]
    piles = []          # (kind char, x, z) for the map

    sc.instance("AnthillTheme", "levels/nest/anthill_theme.tscn", [("fog_density", "0.0055"), ("fill_light_energy", "0.2")])
    start = lane.pts[0]
    sc.instance("StartPoint", "src/objects/start_point.tscn", [("position", v3(start)), ("rotation_degrees", "Vector3(0, 90, 0)")])
    sc.script_node("Chamber", "StaticBody3D", "src/objects/nest/nursery_chamber.gd",
                   [("position", v3((0, FLOOR, 0))), ("radius", fmt(ROOM_R)), ("seed", "7")])

    # ---------------- 1. Egg rows.
    sc.comment("1. EGG ROWS: a winding lane fenced by rows of eggs (EggPile). They knock\n"
               "the ball gently back instead of stopping it; speed along a row is kept.")
    k = 0

    def row(curve, tag, height=ROW_H, radius=ROW_R):
        nonlocal k
        for mid, yaw, length in row_segments(curve):
            sc.script_node("Row%s%d" % (tag, k), "StaticBody3D", "src/objects/nest/egg_pile.gd",
                           [("position", v3(mid)), ("rotation_degrees", "Vector3(0, %s, 0)" % fmt(yaw)),
                            ("length", fmt(length)), ("radius", fmt(radius)), ("height", fmt(height + (k % 3) * 0.12)),
                            ("seed", str(100 + k))])
            piles.append(("o", mid[0], mid[2]))
            k += 1

    m = lane.marks
    lane_pts = lane.pts[: m["lane_end"] + 1]
    # Near the mouth both rows funnel in: the left one onto the end of the
    # bowl's west wall, the right one onto the egg row splitting the mouth.
    r0 = BOWL["floor_radius"]
    left_end = bowl_local_to_world(-r0 - 1.6, 0, BOWL["leg_length"])
    split = bowl_local_to_world(0, 0, BOWL["leg_length"])
    row(funnel(offset_curve(lane_pts, -LANE_HALF), left_end, FUNNEL_LEN), "L")
    # Right side: follows the lane up to the last bend, then squares off
    # the bend's outside into a corner pocket (hidden crystal 1 is in it).
    before = offset_curve(lane.pts[: m["last_bend"] + 1], LANE_HALF)
    after = funnel(offset_curve(lane.pts[m["last_bend_end"]: m["lane_end"] + 1], LANE_HALF), split, FUNNEL_LEN)
    corner = (after[0][0], FLOOR, before[-1][2])
    row(before + [corner], "R")
    row([corner] + after, "R")
    # Close the lane behind the start.
    behind = (start[0] + 3.0, FLOOR, start[2])
    row([(behind[0], FLOOR, behind[2] - LANE_HALF - 0.5), (behind[0], FLOOR, behind[2] + LANE_HALF + 0.5)], "S")

    # The corner pocket: three heaps screen it from the racing line
    # (offsets from the corner, west and north are negative).
    cx, cz = corner[0], corner[2]
    pocket = [(-4.6, -1.3, 1.25, 2.6), (-1.4, -4.4, 1.15, 2.4), (-5.2, -5.0, 0.9, 2.0)]
    for i, (ox, oz, rad, h) in enumerate(pocket):
        sc.script_node("PocketHeap%d" % i, "StaticBody3D", "src/objects/nest/egg_pile.gd",
                       [("position", v3((cx + ox, FLOOR, cz + oz))), ("radius", fmt(rad)), ("height", fmt(h)), ("seed", str(60 + i))])
        piles.append(("@", cx + ox, cz + oz))
    hidden1 = (cx - 2.1, FLOOR, cz - 2.1)
    d["hidden1"] = hidden1

    # Fungus along the lane, alternating sides, just inside the rows.
    lane_d = resample(lane_pts, 11.0)
    for i, p in enumerate(lane_d[1:-1]):
        j = lane_pts.index(min(lane_pts, key=lambda q: math.dist((q[0], q[2]), (p[0], p[2]))))
        r = right_of(tangent(lane_pts, j))
        side = 1 if i % 2 == 0 else -1
        off = (LANE_HALF - ROW_R - 0.5) * side
        sc.script_node("LaneFungus%d" % i, "Node3D", "src/objects/nest/glow_fungus.gd",
                       [("position", v3((p[0] + r[0] * off, FLOOR, p[2] + r[1] * off))), ("size", "0.8"),
                        ("light_energy", "1.6"), ("light_range", "11.0"), ("seed", str(200 + i))])

    # ---------------- 2. The bowl.
    sc.comment("2. THE BOWL: a U-shaped skate bowl (EggBowl). In up the west leg, carve\n"
               "round the curved wall, out down the east leg. Egg rows divide the legs.")
    sc.script_node("Bowl", "StaticBody3D", "src/objects/nest/egg_bowl.gd",
                   [("position", v3(BOWL_POS)), ("rotation_degrees", "Vector3(0, %s, 0)" % fmt(BOWL_YAW))]
                   + [(key, fmt(val)) for key, val in BOWL.items()] + [("seed", "5")])
    L = BOWL["leg_length"]
    div_a = bowl_local_to_world(0, 0, DIVIDER_TIP_Z)
    div_b = bowl_local_to_world(0, 0, L + 3.0)
    for i, (a, b) in enumerate([(div_a, div_b)]):
        n_seg = 4
        for s_ in range(n_seg):
            pa = [a[q] + (b[q] - a[q]) * s_ / n_seg for q in range(3)]
            pb = [a[q] + (b[q] - a[q]) * (s_ + 1) / n_seg for q in range(3)]
            mid = ((pa[0] + pb[0]) / 2, FLOOR, (pa[2] + pb[2]) / 2)
            yaw = math.degrees(math.atan2(-(pb[2] - pa[2]), pb[0] - pa[0]))
            sc.script_node("Divider%d" % s_, "StaticBody3D", "src/objects/nest/egg_pile.gd",
                           [("position", v3(mid)), ("rotation_degrees", "Vector3(0, %s, 0)" % fmt(yaw)),
                            ("length", fmt(math.dist(pa, pb) + 1.0)), ("radius", fmt(DIVIDER_R)), ("height", "2.4"),
                            ("seed", str(80 + s_))])
            piles.append(("d", mid[0], mid[2]))
    tip = bowl_local_to_world(0, 0, DIVIDER_TIP_Z)
    sc.script_node("DividerTip", "StaticBody3D", "src/objects/nest/egg_pile.gd",
                   [("position", v3(tip)), ("radius", fmt(CENTER_HEAP_R)), ("height", "3.0"), ("egg_size", "1.2"), ("seed", "90")])
    # Lights on the rim and the leg ends.
    prof = bowl_profile()
    top_off = prof[-1][0] + BOWL["rim_width"] * 0.5
    r0 = BOWL["floor_radius"]
    for i, a in enumerate((25, 90, 155)):
        x = -(r0 + top_off) * math.cos(math.radians(a))
        z = -(r0 + top_off) * math.sin(math.radians(a))
        sc.script_node("RimFungus%d" % i, "Node3D", "src/objects/nest/glow_fungus.gd",
                       [("position", v3(bowl_local_to_world(x, BOWL["height"], z))), ("size", "1.1"),
                        ("light_energy", "2.2"), ("light_range", "16.0"), ("seed", str(300 + i))])
    for i, sgn in enumerate((-1, 1)):
        sc.script_node("MouthFungus%d" % i, "Node3D", "src/objects/nest/glow_fungus.gd",
                       [("position", v3(bowl_local_to_world(sgn * (r0 + top_off), BOWL["height"], L - 0.8))), ("size", "0.9"),
                        ("light_energy", "1.6"), ("light_range", "12.0"), ("seed", str(310 + i))])
    # Hidden crystal 0: high on the round end's wall, where the west leg's
    # line meets it. Only a full-speed run straight up the leg gets there.
    hx, hy, hz = HIDDEN0_LOCAL
    hidden0 = bowl_local_to_world(hx, hy, hz)
    d["hidden0"] = hidden0
    # Blue fungus on the rim right above it, and a cool wall light beside it.
    ang = math.atan2(-hz, -hx)
    rim = bowl_local_to_world(-(r0 + top_off) * math.cos(ang), BOWL["height"], -(r0 + top_off) * math.sin(ang))
    sc.script_node("HighCrystalFungus", "Node3D", "src/objects/nest/glow_fungus.gd",
                   [("position", v3(rim)), ("amber", "false"), ("size", "1.2"), ("light_energy", "2.4"),
                    ("light_range", "11.0"), ("seed", "320")])

    # ---------------- 2b. Transfer lane.
    sc.comment("2b. Out of the bowl: an egg-row lane to the foot of the spiral.")
    tr = transfer.pts
    # Both rows stop short of the spiral's foot: the lane opens there.
    row(offset_curve(tr, -LANE_HALF)[:-9], "TL")
    row(list(reversed(funnel(list(reversed(offset_curve(tr, LANE_HALF)[:-5])), split, FUNNEL_LEN))), "TR")
    for i, p in enumerate(resample(tr, 12.0)[1:-1]):
        sc.script_node("TransferFungus%d" % i, "Node3D", "src/objects/nest/glow_fungus.gd",
                       [("position", v3(p)), ("size", "0.7"), ("light_energy", "1.4"), ("light_range", "10.0"),
                        ("seed", str(400 + i))])

    # ---------------- 3. Spiral.
    sc.comment("3. SPIRAL RAMP: a shelf riding the room's outer wall, clockwise, 10 m up\n"
               "to the ledge. Thick enough that its open inner side is a cliff to the floor.")
    n_sp = len(spiral)
    widths = [SPIRAL_W] * n_sp
    for i in range(1, d["ledge_n"] + 1):
        widths[-i] = SPIRAL_W + 2.5
    widths[-d["ledge_n"] - 1] = SPIRAL_W + 1.0
    sc.script_node("Spiral", "StaticBody3D", "src/objects/nest/dirt_track.gd",
                   [("points", vec3_array(spiral)), ("widths", f32_array(widths)), ("wall_sides", "1"),
                    ("wall_height", "2.4"), ("floor_thickness", fmt(SPIRAL_RISE + 1.2)), ("lights_every", "12.0"),
                    ("samples_per_meter", "1.0"), ("seed", "17")])

    # ---------------- 4. Bridge.
    sc.comment("4. NURSERY BRIDGE: no walls, curving over the eggs to the egg mound.")
    bp = resample(bridge.pts, 3.0)
    # Start 2 m back inside the ledge (same height), sag a little mid-span.
    t0 = tangent(spiral, n_sp - 1)
    first = (bp[0][0] - t0[0] * 2.0, bp[0][1], bp[0][2] - t0[1] * 2.0)
    total = polyline_length(bp)
    acc = 0.0
    pts = [first]
    for i, p in enumerate(bp):
        if i > 0:
            acc += math.dist((p[0], p[2]), (bp[i - 1][0], bp[i - 1][2]))
        u = acc / total
        pts.append((p[0], MOUND_TOP - BRIDGE_SAG * math.sin(math.pi * u) ** 2, p[2]))
    d["bridge_pts"] = pts
    sc.script_node("Bridge", "StaticBody3D", "src/objects/nest/dirt_track.gd",
                   [("points", vec3_array(pts)), ("width", fmt(BRIDGE_W)), ("wall_sides", "0"),
                    ("floor_thickness", "1.0"), ("lights_every", "9.0"), ("samples_per_meter", "1.0"), ("seed", "29")])

    # ---------------- The mound and the goal.
    entry = math.degrees(math.atan2(pts[-1][2] - MOUND_POS[2], pts[-1][0] - MOUND_POS[0]))
    sc.script_node("Mound", "StaticBody3D", "src/objects/nest/egg_mound.gd",
                   [("position", v3(MOUND_POS)), ("height", fmt(MOUND_TOP - FLOOR)), ("top_radius", fmt(MOUND_R)),
                    ("base_radius", fmt(MOUND_R + 1.5)), ("entry_angle", fmt(entry)), ("seed", "9")])
    goal = (MOUND_POS[0], MOUND_TOP, MOUND_POS[2])
    d["goal"] = goal

    # ---------------- Hidden crystals.
    sc.instance("HiddenCrystal0", "src/objects/hidden_crystal.tscn",
                [("position", v3(hidden0)), ("which", "0"), ("pickup_radius", fmt(HIDDEN0_PICKUP))])
    sc.instance("HiddenCrystal1", "src/objects/hidden_crystal.tscn", [("position", v3(hidden1)), ("which", "1")])

    # ---------------- Room dressing: wall crystals, floor fungus, loose egg heaps.
    rng = random.Random(2)
    for i in range(14):
        phi = 360.0 * i / 14 + rng.uniform(-6, 6)
        y = FLOOR + rng.uniform(14.5, 21.0)
        p = (ROOM_R * 0.995 * math.cos(math.radians(phi)), y, ROOM_R * 0.995 * math.sin(math.radians(phi)))
        sc.script_node("WallCrystal%d" % i, "Node3D", "src/objects/nest/wall_crystal.gd",
                       [("position", v3(p)), ("rotation_degrees", "Vector3(0, %s, 90)" % fmt(-phi)), ("size", "1.6"),
                        ("light_energy", "1.6"), ("light_range", "18.0"), ("seed", str(500 + i))])
    keep_out = [lane.pts, transfer.pts]
    heaps = 0
    tries = 0
    while heaps < LOOSE_HEAPS and tries < 5000:
        tries += 1
        x, z = rng.uniform(-40, 40), rng.uniform(-40, 40)
        r = math.hypot(x, z)
        if r > SPIRAL_R - SPIRAL_W * 0.5 - 2.5:
            continue
        if min(dist_to_polyline(x, z, c) for c in keep_out) < LANE_HALF + 2.6:
            continue
        lx, lz = x - BOWL_POS[0], z - BOWL_POS[2]
        if lz < BOWL["leg_length"] + 2 and math.hypot(lx, min(lz, 0.0)) < bowl_outer() + 1.5:
            continue
        if math.hypot(x - MOUND_POS[0], z - MOUND_POS[2]) < MOUND_R + 4.5:
            continue
        if math.hypot(x - corner[0], z - corner[2]) < 3.0:
            continue
        if any(math.hypot(x - px, z - pz) < 4.2 for c, px, pz in piles if c in "*"):
            continue
        rad = rng.uniform(1.0, 2.0)
        sc.script_node("LooseHeap%d" % heaps, "StaticBody3D", "src/objects/nest/egg_pile.gd",
                       [("position", v3((x, FLOOR, z))), ("radius", fmt(rad)), ("height", fmt(rad * rng.uniform(1.3, 1.8))),
                        ("seed", str(700 + heaps))])
        piles.append(("*", x, z))
        if heaps % 4 == 0:
            sc.script_node("FloorFungus%d" % heaps, "Node3D", "src/objects/nest/glow_fungus.gd",
                           [("position", v3((x + rad + 0.8, FLOOR, z))), ("size", "0.9"), ("light_energy", "1.4"),
                            ("light_range", "12.0"), ("seed", str(800 + heaps))])
        heaps += 1
    sc.script_node("GoalGlow", "Node3D", "src/objects/nest/glow_fungus.gd",
                   [("position", v3((goal[0] + 5.5, MOUND_TOP, goal[2] + 3.0))), ("size", "1.3"),
                    ("light_energy", "2.2"), ("light_range", "16.0"), ("seed", "900")])
    sc.instance("AntHill", "src/objects/ant_hill.tscn", [("position", v3(goal)), ("base_radius", "5.0")])
    sc.instance("FallZone", "src/objects/fall_zone.tscn", [("position", "Vector3(0, -1, 0)"), ("size", "Vector3(600, 4, 600)")])
    d["piles"] = piles
    return sc.text("Level2EggChamber", "Egg Chamber")


# --------------------------------------------------------------- drives ----

def wp(p, speed=None, reach=None, jump=False):
    e = {"pos": [round(p[0], 2), round(p[1], 2), round(p[2], 2)]}
    if speed is not None:
        e["speed"] = speed
    if reach is not None:
        e["reach"] = reach
    if jump:
        e["jump"] = True
    return e


def drives(d):
    lane, transfer, spiral = d["lane"], d["transfer"], d["spiral"]
    m = lane.marks
    out = []
    for p in resample(lane.pts[2: m["lane_end"] + 1], 4.0):
        out.append(wp(p, 9.5, 2.2))
    lane_wps = out
    leg_x = d["leg_x"]
    up_leg = [wp(bowl_local_to_world(-leg_x, 0, z), 9.5, 2.0) for z in (11.0, 6.0)]
    carve = []
    for a in range(-10, 191, 20):
        rr = CARVE_R
        carve.append(wp(bowl_local_to_world(-rr * math.cos(math.radians(a)), 0, -rr * math.sin(math.radians(a))), CARVE_SPEED, CARVE_REACH))
    down_leg = [wp(bowl_local_to_world(leg_x, 0, z), 9.5, 2.2) for z in (6.0, 11.0)]
    tr = [wp(p, 9.5, 2.2) for p in resample(transfer.pts, 4.0)]
    sp = [wp(p, 9.5, 2.5) for p in spiral[d["lead"] + 1:]]
    br = [wp(p, BRIDGE_BOT_SPEED, 1.6) for p in resample(d["bridge_pts"][1:], 3.0)]
    goal = [wp(d["goal"], 4, 0.5)]
    main_route = lane_wps + up_leg + carve + down_leg + tr + sp + br + goal

    # Hidden 0: straight up the west leg at full speed, at the crystal.
    h0 = d["hidden0"]
    ux, uy, uz = HIDDEN0_LOCAL
    shot = [wp(bowl_local_to_world(-leg_x, 0, z), 10, 2.0) for z in (7.0, 3.0)]
    ax, az, areach = HIDDEN0_AIM
    shot.append(wp(bowl_local_to_world(ax, 0, az), 10, areach))
    # ...then come back down and carry on round.
    after = [wp(bowl_local_to_world(2.5, 0, -4.5), 6, 2.0)]
    crystal_route = lane_wps + shot + after + down_leg + tr + sp + br + goal

    # Hidden 1: into the corner pocket at the last bend, then on.
    i_bend = next(i for i, e in enumerate(lane_wps)
                  if math.dist((e["pos"][0], e["pos"][2]), (lane.pts[m["last_bend"]][0], lane.pts[m["last_bend"]][2])) < 3.0)
    h1 = d["hidden1"]
    nook = [wp((h1[0] - 3.0, 0, h1[2] - 2.0), 6, 1.5), wp(h1, 3, 0.6), wp((h1[0] - 3.5, 0, h1[2] - 3.5), 4, 1.5)]
    nook_route = lane_wps[: i_bend - 1] + nook + lane_wps[i_bend + 2:] + up_leg + carve + down_leg + tr + sp + br + goal
    return main_route, crystal_route, nook_route


def main():
    d = build()
    print("spiral phi0 %.1f phi1 %.1f" % (d["phi0"], d["phi1"]))
    for k in ("lane", "transfer", "bridge"):
        print(k, "length %.0f" % polyline_length(d[k].pts), "end (%.1f, %.1f)" % (d[k].x, d[k].z),
              "min radius %.1f at %s" % min_radius(d[k].pts))
    print("spiral length %.0f" % polyline_length(d["spiral"]))
    text = emit(d)
    with open(OUT_SCENE, "w") as f:
        f.write(text)
    main_route, crystal_route, nook_route = drives(d)
    for path, route, hidden, timeout in ((OUT_DRIVE, main_route, None, 150), (OUT_DRIVE_BOWL, crystal_route, [0], 150),
                                         (OUT_DRIVE_NOOK, nook_route, [1], 160)):
        cfg = {"level": 2, "timeout": timeout, "speed": 9}
        if hidden:
            cfg["expect_hidden"] = hidden
        cfg["waypoints"] = route
        with open(path, "w") as f:
            json.dump(cfg, f)
    print("hidden0", d["hidden0"], "hidden1", d["hidden1"])
    print("wrote", OUT_SCENE, "and 3 drive files;", len(text) // 1024, "KB")
    if "--map" in sys.argv:
        ascii_map(d)


if __name__ == "__main__":
    main()
