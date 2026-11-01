#!/usr/bin/env python3
"""Generates levels/nest/level_5_collapsing_gallery.tscn and its bot drives.

The course is a "cursor walk" (like tools/make_tunnel_drop.py): solid
islands, rows of collapsing tiles on straights and arcs, a collapsing
slope and a jump, each starting where the last one ended. Edit build(),
run this from ballants-game/, and the scene and drive files are rewritten:

    python3 tools/make_collapsing_gallery.py

Coordinates: the course starts at the origin heading -Z (the StartPoint's
forward). heading 0 = -Z, positive = turning LEFT. y is floor height.
"offset" is sideways from the centerline, + = to the right.
"""
import json
import math
import os

START_Y = 12.0
TILE = 2.4            # tile length along the path and width of a row (m)
ROWS = 3              # rows across the corridor
WIDTH = TILE * ROWS   # corridor width (7.2 m)
THICK = 0.6           # tile thickness
WALL_H = 5.0          # walls run from 2.5 m below the floor to 2.5 m above
WALL_T = 1.0

SCENE = "levels/nest/level_5_collapsing_gallery.tscn"
DRIVE = "tests/levels/level_5_collapsing_gallery"


def fmt(v):
    s = "%.5f" % v
    s = s.rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def v3(x, y, z):
    return "Vector3(%s, %s, %s)" % (fmt(x), fmt(y), fmt(z))


class Course:
    def __init__(self):
        self.x, self.y, self.z = 0.0, START_Y, 0.0
        self.h = 0.0
        self.nodes = []        # (section, text)
        self.section = "S1"
        self.waypoints = []    # main route
        self.count = 0
        self.light_d = 0.0     # distance since the last wall light
        self.light_side = 1
        self.dist = 0.0        # distance walked
        self.marks = {}
        self.footprints = []   # (x, z, radius, name) for the overlap check

    # ------------------------------------------------------------ helpers --
    def dir(self, h=None):
        h = self.h if h is None else h
        return (-math.sin(h), -math.cos(h))

    def right(self, h=None):
        h = self.h if h is None else h
        return (math.cos(h), -math.sin(h))

    def at(self, s, o, h=None):
        """Point s meters ahead and o to the right of the cursor (flat)."""
        dx, dz = self.dir(h)
        rx, rz = self.right(h)
        return (self.x + dx * s + rx * o, self.z + dz * s + rz * o)

    def name(self, base):
        self.count += 1
        return "%s%d" % (base, self.count)

    def add(self, text, parent=None):
        self.nodes.append((parent or self.section, text))

    def wp(self, x, z, y=None, speed=None, reach=None, jump=False, route=None):
        e = {"pos": [round(x, 2), round(self.y if y is None else y, 2), round(z, 2)]}
        if speed is not None:
            e["speed"] = speed
        if reach is not None:
            e["reach"] = reach
        if jump:
            e["jump"] = True
        (self.waypoints if route is None else route).append(e)
        return e

    # -------------------------------------------------------------- pieces --
    def slab(self, cx, cz, y_top, sx, sz, h, parent=None, thick=1.0):
        n = self.name("Slab")
        self.add('[node name="%s" parent="%s" instance=ExtResource("slab")]\n'
                 'position = %s\nrotation = Vector3(0, %s, 0)\nsize = %s\n'
                 % (n, parent or self.section, v3(cx, y_top - thick / 2, cz), fmt(h), v3(sx, thick, sz)), parent)
        self.footprints.append((cx, cz, max(sx, sz) / 2, n))

    def wall(self, cx, y_floor, cz, length, h, pitch=0.0, parent=None, height=WALL_H, below=2.5):
        n = self.name("Wall")
        self.add('[node name="%s" parent="%s" type="StaticBody3D"]\nscript = ExtResource("wall")\n'
                 'position = %s\nrotation = Vector3(%s, %s, 0)\nlength = %s\nheight = %s\nthickness = %s\nseed = %d\n'
                 % (n, parent or self.section, v3(cx, y_floor - below, cz), fmt(pitch), fmt(h), fmt(length),
                    fmt(height), fmt(WALL_T), self.count), parent)

    def tile(self, cx, y_top, cz, corners=None, size=None, rot=None, opts=None, parent=None):
        n = self.name("Tile")
        text = '[node name="%s" parent="%s" type="StaticBody3D"]\nscript = ExtResource("tile")\nposition = %s\n' % (
            n, parent or self.section, v3(cx, y_top, cz))
        if rot is not None:
            text += "rotation = Vector3(%s, %s, 0)\n" % (fmt(rot[0]), fmt(rot[1]))
        if corners is not None:
            text += "corners = PackedVector2Array(%s)\n" % ", ".join("%s, %s" % (fmt(a), fmt(b)) for a, b in corners)
        if size is not None:
            text += "size = %s\n" % v3(*size)
        for k, v in (opts or {}).items():
            if isinstance(v, str):
                text += '%s = "%s"\n' % (k, v)
            else:
                text += "%s = %s\n" % (k, fmt(v))
        text += "seed = %d\n" % self.count
        self.add(text, parent)
        self.footprints.append((cx, cz, TILE * 0.5, n))

    def fungus(self, x, y, z, amber=True, size=0.8, energy=1.5, rng=12.0, parent=None, rot=None):
        n = self.name("Fungus")
        text = '[node name="%s" parent="%s" type="Node3D"]\nscript = ExtResource("fungus")\nposition = %s\n' % (
            n, parent or self.section, v3(x, y, z))
        if rot is not None:
            text += "rotation = %s\n" % v3(*rot)
        text += "amber = %s\nsize = %s\nlight_energy = %s\nlight_range = %s\nseed = %d\n" % (
            "true" if amber else "false", fmt(size), fmt(energy), fmt(rng), self.count)
        self.add(text, parent)

    def crystal_lamp(self, x, y, z, rot, size=1.1, rng=11.0, parent=None):
        n = self.name("WallCrystal")
        self.add('[node name="%s" parent="%s" type="Node3D"]\nscript = ExtResource("wcrystal")\n'
                 'position = %s\nrotation = %s\nsize = %s\nlight_range = %s\nseed = %d\n'
                 % (n, parent or self.section, v3(x, y, z), v3(*rot), fmt(size), fmt(rng), self.count), parent)

    def dust(self, cx, cz, h, width, length, amount=50, pours=2):
        y = self.y
        n = self.name("Dust")
        self.add('[node name="%s" parent="%s" type="Node3D"]\nscript = ExtResource("dust")\n'
                 'position = %s\nrotation = Vector3(0, %s, 0)\nsize = Vector2(%s, %s)\nheight = 6.0\namount = %d\npours = %d\nseed = %d\n'
                 % (n, self.section, v3(cx, y, cz), fmt(h), fmt(width), fmt(length), amount, pours, self.count))

    def arch(self, s=0.0):
        """An old root arching over the corridor from wall top to wall top (decoration)."""
        lx, lz = self.at(s, -WIDTH / 2 - 0.3)
        rx, rz = self.at(s, WIDTH / 2 + 0.3)
        mx, mz = (lx + rx) / 2, (lz + rz) / 2
        y0 = self.y + 2.3
        n = self.name("Arch")
        pts = [(lx, y0, lz), ((lx + mx) / 2, y0 + 1.6, (lz + mz) / 2), (mx, y0 + 2.1, mz),
               ((rx + mx) / 2, y0 + 1.5, (rz + mz) / 2), (rx, y0 - 0.2, rz)]
        self.add('[node name="%s" parent="%s" type="Node3D"]\nscript = ExtResource("root")\n'
                 'points = PackedVector3Array(%s)\nradius = 0.32\nsolid = false\nrootlets = 3\nseed = %d\n'
                 % (n, self.section, ", ".join("%s, %s, %s" % (fmt(a), fmt(b), fmt(c)) for a, b, c in pts), self.count))

    def lights_along(self, length, walls=(True, True)):
        """A fungus cluster on a wall top every ~12 m, alternating sides."""
        s = 0.0
        while s < length:
            step = 12.0 - self.light_d
            if s + step > length:
                self.light_d += length - s
                return
            s += step
            self.light_d = 0.0
            side = self.light_side
            self.light_side = -side
            if not walls[0 if side < 0 else 1]:
                side = -side
                if not walls[0 if side < 0 else 1]:
                    continue
            x, z = self.at(s, side * (WIDTH / 2 + WALL_T / 2))
            self.fungus(x, self.y + 2.55, z)

    # ------------------------------------------------------------ sections --
    def solid(self, length, walls=(True, True), width=WIDTH, speed=None, wp=True, gaps=()):
        cx, cz = self.at(length / 2, 0)
        self.slab(cx, cz, self.y, width, length, self.h)
        self._straight_walls(length, walls, width, gaps)
        if wp:
            self._waypoints(length, speed)
        self.lights_along(length, walls)
        self._advance(length)

    def _straight_walls(self, length, walls, width=WIDTH, gaps=()):
        """Walls along a straight; gaps = [(side, s0, s1)] leave an opening."""
        for side_i, on in enumerate(walls):
            if not on:
                continue
            side = -1 if side_i == 0 else 1
            spans = [(0.0, length)]
            for g_side, g0, g1 in gaps:
                if g_side != side:
                    continue
                new = []
                for a, b in spans:
                    if g1 <= a or g0 >= b:
                        new.append((a, b))
                        continue
                    if g0 > a:
                        new.append((a, g0))
                    if g1 < b:
                        new.append((g1, b))
                spans = new
            for a, b in spans:
                if b - a < 0.2:
                    continue
                x, z = self.at((a + b) / 2, side * (width / 2 + WALL_T / 2))
                self.wall(x, self.y, z, b - a + (0.0 if gaps else 0.4), self.h)

    def _waypoints(self, length, speed, offset=0.0, step=4.8):
        n = max(int(round(length / step)), 1)
        for i in range(n):
            x, z = self.at((i + 1) * length / n, offset)
            self.wp(x, z, speed=speed)

    def _advance(self, length):
        dx, dz = self.dir()
        self.x += dx * length
        self.z += dz * length
        self.dist += length

    def tiles(self, rows_long, opts=None, walls=(True, True), speed=None, group_last_row=None, gaps=(), wp=True):
        """rows_long rows of ROWS tiles on a straight. opts(row_index, lane) -> dict."""
        length = rows_long * TILE
        for r in range(rows_long):
            for lane in range(ROWS):
                o = (lane - (ROWS - 1) / 2) * TILE
                cx, cz = self.at((r + 0.5) * TILE, o)
                d = dict(opts(r, lane)) if opts else {}
                if group_last_row and r == rows_long - 1:
                    d["trigger_group"] = group_last_row
                self.tile(cx, self.y, cz, size=(TILE, THICK, TILE), rot=(0.0, self.h), opts=d)
        self._straight_walls(length, walls, gaps=gaps)
        if wp:
            self._waypoints(length, speed)
        self.lights_along(length, walls)
        self._advance(length)

    def arc(self, degrees, radius, opts=None, walls=(True, True), speed=None, wp_offset=0.0, wall_lamps=False):
        """Wedge tiles round an arc (+ = left). opts(k, lane, inner) -> dict."""
        sweep = math.radians(abs(degrees))
        sign = 1.0 if degrees > 0 else -1.0
        n = max(int(round(sweep * radius / TILE)), 1)
        da = sweep / n * sign
        # Center of the turn: to the left for a left turn.
        rx, rz = self.right()
        cx0 = self.x - rx * radius * sign
        cz0 = self.z - rz * radius * sign
        h0 = self.h

        def P(h, o):
            # centerline point at heading h, then o to the right
            rx_, rz_ = self.right(h)
            px = cx0 + rx_ * radius * sign
            pz = cz0 + rz_ * radius * sign
            return (px + rx_ * o, pz + rz_ * o)

        inner_lane = 0 if degrees > 0 else ROWS - 1
        for k in range(n):
            ha = h0 + da * k
            hb = h0 + da * (k + 1)
            for lane in range(ROWS):
                o0 = (lane - ROWS / 2) * TILE
                o1 = o0 + TILE
                pts = [P(ha, o0), P(ha, o1), P(hb, o1), P(hb, o0)]
                mx = sum(p[0] for p in pts) / 4
                mz = sum(p[1] for p in pts) / 4
                corners = [(p[0] - mx, p[1] - mz) for p in pts]
                d = dict(opts(k, lane, lane == inner_lane)) if opts else {}
                self.tile(mx, self.y, mz, corners=corners, opts=d)
            # Walls: chords along each edge.
            hm = (ha + hb) / 2
            for side_i, on in enumerate(walls):
                if not on:
                    continue
                side = -1 if side_i == 0 else 1
                o = side * (WIDTH / 2 + WALL_T / 2)
                a = P(ha, o)
                b = P(hb, o)
                ln = math.hypot(b[0] - a[0], b[1] - a[1])
                self.wall((a[0] + b[0]) / 2, self.y, (a[1] + b[1]) / 2, ln + 0.5, hm)
            # Lamp on the outer wall at every other wedge.
            if wall_lamps and k % 2 == 1:
                outer = -1 if degrees < 0 else 1
                px, pz = P(hm, outer * (WIDTH / 2 + 0.02))
                self.crystal_lamp(px, self.y + 1.6, pz, (0, hm, math.radians(90 if outer > 0 else -90)), size=1.0)
        # Waypoints along the arc.
        m = max(int(round(sweep * radius / 4.0)), 2)
        for i in range(m):
            h = h0 + sweep * sign * (i + 1) / m
            px, pz = P(h, wp_offset)
            self.wp(px, pz, speed=speed)
        # Lights on wall tops (outer side when the inner side is open).
        arc_len = sweep * radius
        steps = max(int(arc_len // 12), 1)
        for i in range(steps):
            h = h0 + sweep * sign * (i + 0.5) / steps
            side = 1 if degrees > 0 else -1   # outer side
            if walls[0 if side < 0 else 1]:
                px, pz = P(h, side * (WIDTH / 2 + WALL_T / 2))
                self.fungus(px, self.y + 2.55, pz)
        self.light_d = 0.0
        # Move the cursor to the end of the arc.
        self.h = h0 + sweep * sign
        self.x, self.z = P(self.h, 0.0)
        self.dist += arc_len

    def slope_tiles(self, angles, opts=None, speed=None):
        """One row of tiles per angle (degrees down), each row TILE long along its slope."""
        prev = 0.0
        for r, a_deg in enumerate(angles):
            a = math.radians(a_deg)
            if a_deg != prev:
                # A crest: start the steeper row 2 cm lower, so the ball rolls
                # off one slab onto the next instead of catching its back edge.
                self.y -= 0.02
            prev = a_deg
            hl = TILE * math.cos(a)
            dy = TILE * math.sin(a)
            for lane in range(ROWS):
                o = (lane - (ROWS - 1) / 2) * TILE
                cx, cz = self.at(hl / 2, o)
                d = dict(opts(r, lane)) if opts else {}
                self.tile(cx, self.y - dy / 2, cz, size=(TILE, THICK, TILE), rot=(-a, self.h), opts=d)
            for side in (-1, 1):
                wx, wz = self.at(hl / 2, side * (WIDTH / 2 + WALL_T / 2))
                self.wall(wx, self.y - dy / 2, wz, TILE + 0.3, self.h, pitch=-a)
            if r % 4 == 1:
                side = self.light_side
                self.light_side = -side
                fx, fz = self.at(hl / 2, side * (WIDTH / 2 + WALL_T / 2))
                self.fungus(fx, self.y - dy / 2 + 2.55, fz)
            ex, ez = self.at(hl, 0)
            self.wp(ex, ez, y=self.y - dy, speed=speed)
            self._advance(hl)
            self.y -= dy


# ======================================================================
def build():
    c = Course()
    warn = lambda r, lane: {"timing_setting": "gallery_warning_scale"}
    warn_arc = lambda k, lane, inner: {"timing_setting": "gallery_warning_scale"}

    # ---------------------------------------------------------- start --
    sx, sz = c.at(3.0, 0)
    c.marks["start"] = (sx, c.y, sz)
    bx, bz = c.at(-0.5, 0)
    c.wall(bx, c.y, bz, WIDTH + 2 * WALL_T, c.h + math.pi / 2)

    # ============ Section 1: WARNING FLOOR (slow tiles, teach the rule) ===
    c.section = "S1"
    c.solid(14.0, speed=8)
    c.dust(*c.at(-7, 0), c.h, 6, 12)
    c.marks["s1_first_tiles"] = c.at(TILE * 1.5, 0)
    # The first patch: touching it also starts a "demo" -- three middle
    # tiles of the next patch crack and fall while you watch.
    # (They only SET OFF the demo: each keeps its own countdown from its own
    # touch, so the patch never drops all at once.)
    c.tiles(3, opts=lambda r, lane: {"timing_setting": "gallery_warning_scale", "triggers_group": "warn_demo"}, speed=8)
    c.solid(7.0, speed=8)
    c.arch(3.5)
    demo = lambda r, lane: ({"trigger_group": "warn_demo", "crack_delay": 0.2, "fall_delay": 0.6, "extra_delay": 0.2 * (r - 1)}
                            if lane == 1 and r in (1, 2, 3) else {"timing_setting": "gallery_warning_scale"})
    c.tiles(5, opts=demo, speed=8, wp=False)
    # The bot steers round the hole on the left lane.
    for s_, o_ in [(-12.0 + 0.5, -2.0), (-12.0 + 4.0, -2.4), (-12.0 + 8.0, -2.4), (-0.5, -1.8)]:
        c.wp(*c.at(s_, o_), speed=8)
    c.dust(*c.at(-6, 0), c.h, 6, 12)
    c.solid(7.0, speed=8)
    c.arc(30, 24, opts=warn_arc, speed=8)
    c.tiles(4, opts=warn, speed=8)
    c.arch(-4.8)
    c.solid(10.0, speed=8)                       # island B

    # ============ Section 2: CRUMBLING CORRIDOR (normal tiles, keep rolling) ==
    c.section = "S2"
    c.tiles(8, speed=9)
    c.dust(*c.at(-9.6, 0), c.h, 6, 18, amount=70)
    c.arch(-6)
    c.arc(-35, 26, speed=9)
    # The rows just before the ledge straight start the countdown of the
    # bridge out to the ledge (group "ledge_a").
    c.tiles(4, speed=9, group_last_row="ledge_a")
    c.marks["ledge_start"] = (c.x, c.y, c.z, c.h)
    # The ledge straight: no right wall (the ledge is across a void).
    ledge_rows = 14
    c.tiles(ledge_rows, speed=9, walls=(True, False))
    c.dust(*c.at(-16.8, 0), c.h, 6, 30, amount=90, pours=3)
    c.solid(8.0, speed=9)                        # island C
    c.tiles(14, speed=9)
    c.arch(-12)
    c.dust(*c.at(-12, 0), c.h, 6, 22, amount=70)
    c.arc(40, 22, speed=9)
    c.arc(-40, 22, speed=9)
    c.tiles(12, speed=9)
    c.dust(*c.at(-14.4, 0), c.h, 6, 26, amount=80)
    # Island D: the dead-end branch opens off its left wall.
    c.marks["dead_end_island"] = (c.x, c.y, c.z, c.h)
    c.solid(12.0, speed=8, gaps=[(-1, 4.8, 7.2)])

    # ============ Section 3: COLLAPSING CURVES (the inside goes first) ======
    c.section = "S3"
    inside = lambda grp: (lambda k, lane, inner: {"trigger_group": grp, "timing_setting": "gallery_curve_inside_scale"} if inner else {})
    c.tiles(3, speed=8.5, group_last_row="curve_1")
    c.arc(90, 9.6, opts=inside("curve_1"), walls=(False, True), speed=8, wp_offset=0.7, wall_lamps=True)
    c.tiles(4, speed=8.5, group_last_row="curve_2")
    c.arc(-120, 9.6, opts=inside("curve_2"), walls=(True, False), speed=8, wp_offset=-0.7, wall_lamps=True)
    c.tiles(4, speed=8.5, group_last_row="curve_3")
    c.arc(90, 9.6, opts=inside("curve_3"), walls=(False, True), speed=8, wp_offset=0.7, wall_lamps=True)
    c.tiles(3, speed=9)
    c.solid(10.0, speed=9)                       # island E
    c.dust(*c.at(-5, 0), c.h, 6, 9)

    # ============ Section 4: FINAL SPRINT (collapsing slope, jump) =========
    c.section = "S4"
    sprint = lambda r, lane: {"timing_setting": "gallery_sprint_scale"}
    angles = [5, 9] + [12] * 11
    c.marks["sprint_top"] = (c.x, c.y, c.z)
    c.slope_tiles(angles, opts=sprint, speed=9.8)
    # Lamps marking the lip.
    for side in (-1, 1):
        lx2, lz2 = c.at(-0.6, side * (WIDTH / 2 + 0.02))
        c.crystal_lamp(lx2, c.y + 1.4, lz2, (0, c.h, math.radians(90 if side > 0 else -90)), size=1.4, rng=14)
    # The jump: press it on the last row.
    jx, jz = c.at(-1.6, 0)
    c.waypoints[-1:] = []
    c.wp(jx, jz, speed=9.8, reach=1.0, jump=True)
    lip = (c.x, c.y, c.z)
    gap = 6.0
    drop = 1.0
    c.marks["lip"] = lip
    c._advance(gap)
    c.y -= drop
    plateau_len = 20.0
    pcx, pcz = c.at(plateau_len / 2, 0)
    c.slab(pcx, pcz, c.y, 14.0, plateau_len, c.h, thick=2.0)
    for side in (-1, 1):
        wx, wz = c.at(plateau_len / 2, side * (7.0 + WALL_T / 2))
        c.wall(wx, c.y, wz, plateau_len, c.h)
    ex, ez = c.at(plateau_len + WALL_T / 2, 0)
    c.wall(ex, c.y, ez, 14.0 + 2 * WALL_T, c.h + math.pi / 2)
    hx, hz = c.at(11.0, 0)
    c.marks["hill"] = (hx, c.y, hz)
    lx3, lz3 = c.at(3.0, 0)
    c.wp(lx3, lz3, speed=8)
    c.wp(hx, hz, speed=4, reach=0.4)
    for side in (-1, 1):
        fx, fz = c.at(5.0, side * 5.2)
        c.fungus(fx, c.y, fz, size=1.2, energy=2.0, rng=16)
        fx, fz = c.at(17.0, side * 5.2)
        c.fungus(fx, c.y, fz, size=1.0, energy=1.6, rng=12)
    return c


# -------------------------------------------------- hidden crystal bits --
def add_ledge(c, routes):
    """Hidden 0: a solid ledge across a void on the right of the ledge straight,
    reached by a narrow collapsing bridge that starts falling as soon as you
    roll past its approach; a second bridge leads back."""
    lx, ly, lz, lh = c.marks["ledge_start"]
    save = (c.x, c.y, c.z, c.h, c.section)
    c.x, c.y, c.z, c.h, c.section = lx, ly, lz, lh, "Ledge"
    ledge_in, ledge_out = 7.6, 12.4          # offsets of the ledge's edges
    ledge_c = (ledge_in + ledge_out) / 2
    s0, s1 = 6.0, 30.0
    cx, cz = c.at((s0 + s1) / 2, ledge_c)
    c.slab(cx, cz, c.y, ledge_out - ledge_in, s1 - s0, c.h)
    wx, wz = c.at((s0 + s1) / 2, ledge_out + WALL_T / 2)
    c.wall(wx, c.y, wz, s1 - s0 + 2, c.h)
    for s in (s0 - WALL_T / 2, s1 + WALL_T / 2):
        wx, wz = c.at(s, ledge_c)
        wx, wz = c.at(s, ledge_c + WALL_T / 2)
        c.wall(wx, c.y, wz, ledge_out - ledge_in + WALL_T, c.h + math.pi / 2)
    # Bridges: from the corridor's right lane out to the ledge and back.
    bridge_w = 2.0
    route = []

    def bridge(a, b, opts_fn):
        (sa, oa), (sb, ob) = a, b
        ax, az = c.at(sa, oa)
        bx, bz = c.at(sb, ob)
        ln = math.hypot(bx - ax, bz - az)
        h = math.atan2(-(bx - ax), -(bz - az))
        n = max(int(round(ln / 2.3)), 1)
        seg = ln / n
        for k in range(n):
            u = (k + 0.5) / n
            px, pz = ax + (bx - ax) * u, az + (bz - az) * u
            c.tile(px, c.y, pz, size=(bridge_w, THICK, seg + 0.02), rot=(0.0, h), opts=opts_fn(k, n))
        return (ax, az), (bx, bz)

    a_opts = lambda k, n: {"trigger_group": "ledge_a", "timing_setting": "gallery_ledge_bridge_scale",
                           "extra_delay_setting": "gallery_ledge_bridge_delay",
                           "extra_delay": round(0.25 * k, 2)}
    b_opts = lambda k, n: {"timing_setting": "gallery_ledge_bridge_scale"}
    (a0, a1) = bridge((1.0, 2.4), (13.0, ledge_c), a_opts)
    (b0, b1) = bridge((23.0, ledge_c), (35.0, 2.4), b_opts)
    # Decoration: a crystal lamp on the ledge's back wall, a root curtain.
    px, pz = c.at(18.0, ledge_out - 0.02)
    c.crystal_lamp(px, c.y + 1.5, pz, (0, c.h, math.radians(-90)), size=1.0, rng=9)
    fx, fz = c.at(10.5, ledge_out - 0.8)
    c.fungus(fx, c.y, fz, amber=False, size=0.7, energy=1.0, rng=8)
    kx, kz = c.at(18.0, ledge_c + 0.6)
    c.marks["crystal0"] = (kx, c.y, kz)
    # Bot route for the ledge drive: replaces the main route waypoints along
    # the ledge straight.
    for (s, o, sp) in [(-2.0, 1.2, 8), (1.0, 2.4, 7.5)]:
        x, z = c.at(s, o)
        c.wp(x, z, speed=sp, route=route)
    for u in (0.35, 0.7, 1.0):
        c.wp(a0[0] + (a1[0] - a0[0]) * u, a0[1] + (a1[1] - a0[1]) * u, speed=7, route=route)
    for s in (16.0, 18.0, 20.5):
        x, z = c.at(s, ledge_c + 0.6)
        c.wp(x, z, speed=7, reach=1.2, route=route)
    for u in (0.0, 0.35, 0.7, 1.0):
        c.wp(b0[0] + (b1[0] - b0[0]) * u, b0[1] + (b1[1] - b0[1]) * u, speed=7, route=route)
    c.x, c.y, c.z, c.h, c.section = save
    routes["ledge"] = route


def add_dead_end(c, routes):
    """Hidden 1: a one-tile-wide dead end off island D's left wall. Rolling
    onto its first tile starts the countdown of all its tiles: the entrance
    goes first, `gallery_dead_end_time` later."""
    ix, iy, iz, ih = c.marks["dead_end_island"]
    save = (c.x, c.y, c.z, c.h, c.section)
    c.x, c.y, c.z, c.h, c.section = ix, iy, iz, ih, "DeadEnd"
    s_mid = 6.0
    n = 4
    route = []
    for k in range(n):
        o = -(WIDTH / 2 + (k + 0.5) * TILE)
        x, z = c.at(s_mid, o)
        c.tile(x, c.y, z, size=(TILE, THICK, TILE), rot=(0.0, c.h),
               opts={"trigger_group": "dead_end", "extra_delay_setting": "gallery_dead_end_time",
                     "extra_delay": round(0.3 * k, 2)})
    # Side walls and the end wall.
    depth = n * TILE
    for s in (s_mid - TILE / 2 - WALL_T / 2, s_mid + TILE / 2 + WALL_T / 2):
        x, z = c.at(s, -(WIDTH / 2 + depth / 2))
        c.wall(x, c.y, z, depth + WALL_T, c.h + math.pi / 2)
    x, z = c.at(s_mid, -(WIDTH / 2 + depth + WALL_T / 2))
    c.wall(x, c.y, z, TILE + 2 * WALL_T + 0.4, c.h)
    # A hanging root curtain half across the opening, blue fungus at the end.
    ox, oz = c.at(s_mid - 1.6, -WIDTH / 2 - 0.2)
    o2x, o2z = c.at(s_mid + 0.4, -WIDTH / 2 - 0.4)
    nm = c.name("Curtain")
    c.add('[node name="%s" parent="DeadEnd" type="Node3D"]\nscript = ExtResource("root")\n'
          'points = PackedVector3Array(%s, %s, %s, %s, %s, %s, %s, %s, %s)\nradius = 0.3\nsolid = false\nrootlets = 4\nseed = 3\n'
          % (nm, fmt(ox), fmt(c.y + 3.0), fmt(oz), fmt((ox + o2x) / 2), fmt(c.y + 2.2), fmt((oz + o2z) / 2),
             fmt(o2x), fmt(c.y + 0.9), fmt(o2z)), "DeadEnd")
    fx, fz = c.at(s_mid + 0.6, -(WIDTH / 2 + depth - 0.5))
    c.fungus(fx, c.y + 2.55, fz, amber=False, size=0.6, energy=0.8, rng=6)
    kx, kz = c.at(s_mid, -(WIDTH / 2 + depth - 1.2))
    c.marks["crystal1"] = (kx, c.y, kz)
    # Bot route: stop on the island beside the opening, roll in, bounce off
    # the end wall, roll straight back out.
    for (s, o, sp, rc) in [(s_mid - 1.5, -0.5, 5, 1.2), (s_mid, -2.4, 2, 0.8)]:
        x, z = c.at(s, o)
        c.wp(x, z, speed=sp, reach=rc, route=route)
    x, z = c.at(s_mid, -(WIDTH / 2 + depth - 0.6))
    c.wp(x, z, speed=8, reach=0.8, route=route)
    for (o, sp) in [(-(WIDTH / 2 + 1.0), 9), (-0.5, 6)]:
        x, z = c.at(s_mid, o)
        c.wp(x, z, speed=sp, reach=1.0, route=route)
    c.x, c.y, c.z, c.h, c.section = save
    routes["dead_end"] = route


# ------------------------------------------------------------------ main --
def write(c, routes):
    out = []
    out.append('[gd_scene format=3]\n')
    res = [("Script", "res://levels/level.gd", "level"),
           ("PackedScene", "res://levels/nest/anthill_theme.tscn", "theme"),
           ("PackedScene", "res://src/objects/start_point.tscn", "start"),
           ("PackedScene", "res://src/objects/ant_hill.tscn", "hill"),
           ("PackedScene", "res://src/objects/fall_zone.tscn", "fall"),
           ("PackedScene", "res://src/objects/hidden_crystal.tscn", "crystal"),
           ("PackedScene", "res://src/objects/nest/dirt_slab.tscn", "slab"),
           ("Script", "res://src/objects/nest/collapsing_tile.gd", "tile"),
           ("Script", "res://src/objects/nest/dirt_wall.gd", "wall"),
           ("Script", "res://src/objects/nest/glow_fungus.gd", "fungus"),
           ("Script", "res://src/objects/nest/wall_crystal.gd", "wcrystal"),
           ("Script", "res://src/objects/nest/root.gd", "root"),
           ("Script", "res://src/objects/nest/falling_dust.gd", "dust")]
    for t, p, i in res:
        out.append('[ext_resource type="%s" path="%s" id="%s"]' % (t, p, i))
    out.append("""
[sub_resource type="StandardMaterial3D" id="pit_mat"]
shading_mode = 0
albedo_color = Color(0.045, 0.026, 0.015, 1)
disable_fog = true

[sub_resource type="PlaneMesh" id="pit_mesh"]
material = SubResource("pit_mat")
size = Vector2(600, 600)
""")
    out.append("""
; LEVEL 5 -- Collapsing Gallery. GENERATED by tools/make_collapsing_gallery.py;
; edit the walk there and re-run it rather than editing this file.
; S1 warning floor (slow tiles), S2 crumbling corridor (side ledge = hidden 0),
; S3 collapsing curves (inside row goes first; dead end off island D = hidden 1),
; S4 final sprint (collapsing slope, jump to the goal plateau).
[node name="Level5CollapsingGallery" type="Node3D"]
script = ExtResource("level")
level_name = "Collapsing Gallery"

[node name="AnthillTheme" parent="." instance=ExtResource("theme")]

[node name="StartPoint" parent="." instance=ExtResource("start")]
position = %s
""" % v3(*c.marks["start"]))
    for sec in ["S1", "S2", "Ledge", "S3", "DeadEnd", "S4"]:
        out.append('[node name="%s" type="Node3D" parent="."]\n' % sec)
        for parent, text in c.nodes:
            if parent == sec:
                out.append(text)
    k0 = c.marks["crystal0"]
    k1 = c.marks["crystal1"]
    hill = c.marks["hill"]
    out.append('[node name="HiddenCrystal0" parent="." instance=ExtResource("crystal")]\nposition = %s\nwhich = 0\n' % v3(*k0))
    out.append('[node name="HiddenCrystal1" parent="." instance=ExtResource("crystal")]\nposition = %s\nwhich = 1\nsize = 0.7\n' % v3(*k1))
    out.append('[node name="AntHill" parent="." instance=ExtResource("hill")]\nposition = %s\nbase_radius = 5.0\n' % v3(*hill))
    xs = [f[0] for f in c.footprints]
    zs = [f[1] for f in c.footprints]
    out.append('[node name="Pit" type="MeshInstance3D" parent="."]\n; the dark far below: makes every hole in the floor read black (no collision)\nposition = %s\nmesh = SubResource("pit_mesh")\n'
               % v3((min(xs) + max(xs)) / 2, 1.2, (min(zs) + max(zs)) / 2))
    out.append('[node name="FallZone" parent="." instance=ExtResource("fall")]\nposition = %s\nsize = Vector3(600, 4, 600)\n'
               % v3((min(xs) + max(xs)) / 2, -1, (min(zs) + max(zs)) / 2))
    with open(SCENE, "w") as f:
        f.write("\n".join(out))

    main = c.waypoints

    def drive(waypoints, expect=None, timeout=150):
        d = {"level": 5, "timeout": timeout, "speed": 8}
        if expect is not None:
            d["expect_hidden"] = expect
        d["waypoints"] = waypoints
        return d

    with open(DRIVE + ".json", "w") as f:
        json.dump(drive(main), f)
    # Ledge: replace main waypoints along the ledge straight.
    li = c.wp_index["ledge_from"]
    lj = c.wp_index["ledge_to"]
    with open(DRIVE + "_ledge.json", "w") as f:
        json.dump(drive(main[:li] + routes["ledge"] + main[lj:], [0]), f)
    di = c.wp_index["dead_end_at"]
    with open(DRIVE + "_dead_end.json", "w") as f:
        json.dump(drive(main[:di] + routes["dead_end"] + main[di:], [1]), f)
    print("tiles: %d, nodes: %d, course length %.0f m, waypoints %d" %
          (sum(1 for _, t in c.nodes if 'ExtResource("tile")' in t), len(c.nodes), c.dist, len(main)))
    print("start", c.marks["start"], "lip", c.marks["lip"], "hill", hill)
    print("bounds x %.0f..%.0f z %.0f..%.0f" % (min(xs), max(xs), min(zs), max(zs)))


def check_overlaps(c):
    """Warn if two pieces from far-apart parts of the walk come close."""
    fp = c.footprints
    order = {f[3]: i for i, f in enumerate(fp)}
    bad = 0
    for i in range(len(fp)):
        for j in range(i + 40, len(fp)):
            a, b = fp[i], fp[j]
            d = math.hypot(a[0] - b[0], a[1] - b[1])
            if d < a[2] + b[2] + 3.0 and abs(i - j) > 40:
                if bad < 10:
                    print("close:", a[3], b[3], round(d, 1))
                bad += 1
    print("overlap warnings:", bad)


def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    c = build()
    routes = {}
    # Indices into the main route for splicing the hidden routes.
    c.wp_index = {}
    lx, ly, lz, lh = c.marks["ledge_start"]
    ix, iy, iz, ih = c.marks["dead_end_island"]

    def nearest(x, z):
        best, bi = 1e9, 0
        for i, w in enumerate(c.waypoints):
            d = math.hypot(w["pos"][0] - x, w["pos"][2] - z)
            if d < best:
                best, bi = d, i
        return bi
    c.wp_index["ledge_from"] = nearest(lx, lz)
    ex = lx - math.sin(lh) * 36.0
    ez = lz - math.cos(lh) * 36.0
    c.wp_index["ledge_to"] = nearest(ex, ez)
    dx = ix - math.sin(ih) * 4.0
    dz = iz - math.cos(ih) * 4.0
    c.wp_index["dead_end_at"] = nearest(dx, dz)
    add_ledge(c, routes)
    add_dead_end(c, routes)
    check_overlaps(c)
    write(c, routes)


if __name__ == "__main__":
    main()
