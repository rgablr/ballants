#!/usr/bin/env python3
"""Generates levels/nest/level_3_fungus_farm.tscn and its bot drive files.

    python3 tools/make_fungus_farm.py      (run from ballants-game/)

The course runs toward -Z from the StartPoint. Every piece is placed from
the numbers in LAYOUT below, so change a gap or a height there and run
this again rather than moving nodes by hand. The drive files
(tests/levels/level_3_fungus_farm*.json) are written from the same
numbers, so they follow any change.

Coordinates: x right, y up, z toward the start (the course goes -Z).
Every floor is above y = 6; the FallZone sits at y = -1.
"""
import json
import math
import os

# ------------------------------------------------------------------ layout --
Y0 = 8.0                 # section 1-2 floor
W = 10.0                 # bed width
TRENCH_DEPTH = 1.2       # section 1 furrows (climbable: the jump is 1.59 m)

# Section 1: beds and the furrows between them (gap lengths, m).
S1_FIRST_BED = 22.0
S1_GAPS = [3.0, 3.5, 4.0, 4.5, 5.0]
S1_BED = 9.0

# Section 2
S2_RUNUP = 20.0          # bed after the last hop, with the bounce patch at its end
LEDGE1_H = 4.0           # the first ledge is this much higher than the bed
LEDGE1_LEN = 18.0
PIT_LEN = 21.0
PIT_MUSH = [(0.0, 1.7), (2.6, 8.7), (-0.8, 15.6)]   # (x, distance past the ledge lip)
PIT_R = 1.6

# Section 3 (spore floors): each entry is a bed: (dirt_len, spore_len, gap_after, rise_of_next)
LEDGE2_DIRT = 20.0

# Tower
STEP = 4.2               # horizontal spacing of the tower mushrooms
RISE = 4.5               # cap-to-cap height
TURN = 40.0              # degrees left per step
TOWER_R = 1.6

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def f(v):
    return ("%.3f" % v).rstrip("0").rstrip(".") if abs(v) > 1e-9 else "0"


def v3(x, y, z):
    return "Vector3(%s, %s, %s)" % (f(x), f(y), f(z))


class Scene:
    def __init__(self):
        self.nodes = []
        self.counts = {}

    def name(self, base):
        self.counts[base] = self.counts.get(base, 0) + 1
        return "%s%d" % (base, self.counts[base])

    def add(self, header, props, comment=None):
        text = ""
        if comment:
            text += "; %s\n" % comment
        text += header + "\n"
        for k, v in props:
            text += "%s = %s\n" % (k, v)
        self.nodes.append(text)

    # ---- pieces
    def bed(self, x, top, z0, z1, width=W, depth=2.0, comment=None, rot=0.0, name="Bed", **kw):
        """A DirtBed from z0 to z1 (z0 > z1), top at `top`."""
        n = self.name(name)
        props = [("script", 'ExtResource("bed")')]
        if rot:
            props.append(("rotation_degrees", v3(0, rot, 0)))
        props += [("position", v3(x, top, (z0 + z1) * 0.5)),
                  ("size", v3(width, depth, abs(z0 - z1))),
                  ("seed", str(len(self.nodes) + 1))]
        for k, v in kw.items():
            props.append((k, v))
        self.add('[node name="%s" type="StaticBody3D" parent="."]' % n, props, comment)
        return n

    def bed_at(self, cx, top, cz, sx, sz, depth=2.0, rot=0.0, name="Bed", comment=None, **kw):
        n = self.name(name)
        props = [("script", 'ExtResource("bed")')]
        if rot:
            props.append(("rotation_degrees", v3(0, rot, 0)))
        props += [("position", v3(cx, top, cz)), ("size", v3(sx, depth, sz)),
                  ("seed", str(len(self.nodes) + 1))]
        for k, v in kw.items():
            props.append((k, v))
        self.add('[node name="%s" type="StaticBody3D" parent="."]' % n, props, comment)

    def mushroom(self, x, foot_y, z, cap_top, radius, name="Mushroom", comment=None, **kw):
        n = self.name(name)
        props = [("script", 'ExtResource("mush")'), ("position", v3(x, foot_y, z)),
                 ("cap_height", f(cap_top - foot_y)), ("cap_radius", f(radius)),
                 ("seed", str(len(self.nodes) + 3))]
        for k, v in kw.items():
            props.append((k, v))
        self.add('[node name="%s" type="StaticBody3D" parent="."]' % n, props, comment)
        return n

    def spores(self, x, top, z0, z1, width=W, comment=None, name="Spores", size_x=None):
        n = self.name(name)
        sx = size_x if size_x is not None else width
        props = [("script", 'ExtResource("spore")'), ("position", v3(x, top, (z0 + z1) * 0.5)),
                 ("size", v3(sx, 1.2, abs(z0 - z1))), ("seed", str(len(self.nodes) + 5))]
        self.add('[node name="%s" type="Area3D" parent="."]' % n, props, comment)

    def wall(self, x, base, z, length, height, rot=0.0, thickness=1.0, comment=None):
        n = self.name("Wall")
        props = [("script", 'ExtResource("wall")'), ("position", v3(x, base, z))]
        if rot:
            props.append(("rotation_degrees", v3(0, rot, 0)))
        props += [("length", f(length)), ("height", f(height)), ("thickness", f(thickness)),
                  ("seed", str(len(self.nodes) + 7))]
        self.add('[node name="%s" type="StaticBody3D" parent="."]' % n, props, comment)

    def wall_z(self, x, base, z0, z1, height, comment=None):
        self.wall(x, base, (z0 + z1) * 0.5, abs(z0 - z1), height, comment=comment)

    def wall_x(self, z, base, x0, x1, height, comment=None):
        self.wall((x0 + x1) * 0.5, base, z, abs(x1 - x0), height, rot=90.0, comment=comment)

    def fungus(self, x, y, z, amber=True, size=1.0, energy=1.5, rng=12.0, rot=None):
        n = self.name("Fungus")
        props = [("script", 'ExtResource("fungus")'), ("position", v3(x, y, z))]
        if rot is not None:
            props.append(("rotation_degrees", v3(*rot)))
        props += [("seed", str(len(self.nodes) + 11)), ("size", f(size)),
                  ("light_energy", f(energy)), ("light_range", f(rng))]
        if not amber:
            props.append(("amber", "false"))
        self.add('[node name="%s" type="Node3D" parent="."]' % n, props)

    def crystal_lamp(self, x, y, z, rot=(0, 0, 0), size=1.0):
        n = self.name("WallCrystal")
        props = [("script", 'ExtResource("wcrystal")'), ("position", v3(x, y, z)),
                 ("rotation_degrees", v3(*rot)), ("seed", str(len(self.nodes) + 13)),
                 ("size", f(size))]
        self.add('[node name="%s" type="Node3D" parent="."]' % n, props)

    def cloud(self, x, y, z, sx, sy, sz, count):
        n = self.name("SporeDrift")
        props = [("script", 'ExtResource("cloud")'), ("position", v3(x, y, z)),
                 ("size", v3(sx, sy, sz)), ("spore_count", str(count)),
                 ("spore_size", "0.07"), ("drift_height", "2.5"), ("glow", "1.2"),
                 ("spore_seed", str(len(self.nodes) + 17))]
        self.add('[node name="%s" type="GPUParticles3D" parent="."]' % n, props)


def build():
    s = Scene()
    wp = []          # main drive waypoints
    marks = {}

    # ================================================= SECTION 1: SMALL HOPS
    z = 6.0
    beds = []
    z_end = z - S1_FIRST_BED
    beds.append((z, z_end))
    for g in S1_GAPS:
        trench = (z_end, z_end - g)
        z_start = z_end - g
        length = S1_BED if g != S1_GAPS[-1] else S2_RUNUP
        beds.append((z_start, z_start - length))
        z_end = z_start - length
    s1_trenches = []
    for i, (a, b) in enumerate(beds):
        comment = None
        if i == 0:
            comment = "SECTION 1 -- SMALL HOPS. Raised dirt beds with furrows between (3 to 5 m)."
        s.bed(0, Y0, a, b, comment=comment, buttons_on_sides="false" if i else "true")
        if i + 1 < len(beds):
            na = beds[i + 1][0]
            s1_trenches.append((b, na))
            s.bed(0, Y0 - TRENCH_DEPTH, b, na, depth=1.5, name="Furrow",
                  comment="a furrow %.1f m wide, %.1f m deep: miss the hop and you jump back out" % (b - na, TRENCH_DEPTH),
                  buttons_every="0")
    s1_end = beds[-1][1]
    # Side walls for the whole of sections 1-2 floor level.
    s.wall_x(6.5, Y0 - 2.0, -W / 2 - 1.0, W / 2 + 1.0, 4.5, comment="the wall behind the start")

    # Main-route waypoints over the hops.
    wp.append({"pos": [0, Y0, -4.0], "speed": 7})
    for (lip, land) in s1_trenches:
        wp.append({"pos": [0, Y0, lip + 0.6], "speed": 7, "reach": 0.8, "jump": True})
        wp.append({"pos": [0, Y0, land - 2.5], "speed": 7})

    # ================================================ SECTION 2: BOUNCE PATCHES
    ledge1_z0 = s1_end
    ledge1_top = Y0 + LEDGE1_H
    patch_z = ledge1_z0 + 2.6
    for i, px in enumerate([-3.3, 0.0, 3.3]):
        s.mushroom(px, Y0, patch_z, Y0 + 0.1, 1.5, name="BouncePatch",
                   comment="SECTION 2 -- BOUNCE PATCHES. Three caps set in the floor at the foot of a 4 m ledge: roll on, get thrown up." if i == 0 else None)
    s.bed(0, ledge1_top, ledge1_z0, ledge1_z0 - LEDGE1_LEN, depth=LEDGE1_H + 2.0, name="Ledge",
          comment="the first ledge, 4 m up: too high to jump, easy to bounce")
    ledge1_end = ledge1_z0 - LEDGE1_LEN
    pit_end = ledge1_end - PIT_LEN
    s.bed(0, Y0, ledge1_end, pit_end, name="PitFloor", buttons_every="0",
          comment="the pit under the stepping mushrooms; a miss lands here, not in the void")
    pit_caps = []
    for i, (px, d) in enumerate(PIT_MUSH):
        pz = ledge1_end - d
        pit_caps.append((px, pz))
        s.mushroom(px, Y0, pz, ledge1_top, PIT_R, name="PitMushroom",
                   comment="stepping mushrooms across the pit, caps level with the ledges: aim by how fast you are going" if i == 0 else None)
    # Recovery: two floor caps near the first ledge's face; roll back onto one.
    for px in [-3.3, 3.3]:
        s.mushroom(px, Y0, ledge1_end - 3.2, Y0 + 0.1, 1.4, name="PitRecovery",
                   comment="back out of the pit: roll back toward the first ledge onto one of these" if px < 0 else None)
    ledge2_top = ledge1_top
    # Side walls along sections 1-2.
    for side in [-1, 1]:
        s.wall_z(side * (W / 2 + 0.5), Y0 - 2.0, 6.0, pit_end, 4.5,
                 comment="side walls of the garden rows" if side < 0 else None)
    for side in [-1, 1]:
        s.wall_z(side * (W / 2 + 0.5), Y0 + 2.5, ledge1_z0 + 4, pit_end, 5.0)

    wp.append({"pos": [0, Y0, patch_z + 4.0], "speed": 5})
    wp.append({"pos": [0, Y0, patch_z], "speed": 4, "reach": 1.2})
    wp.append({"pos": [0, ledge1_top, ledge1_z0 - 9.0], "speed": 4, "reach": 1.5})
    wp.append({"pos": [0, ledge1_top, ledge1_end + 2.5], "speed": 3.5, "reach": 1.0})
    # The pit: approach cap 1 slowly, then glide cap to cap.
    # Flight between caps level with each other: 2 * sqrt(2 h / g) seconds.
    flight = 2.0 * math.sqrt(2.0 * 6.5 / 12.27)
    prev = (0.0, ledge1_end)
    wp.append({"pos": [0, ledge1_top, pit_caps[0][1]], "speed": 3.6, "reach": 1.3})
    prev = (0.0, pit_caps[0][1] + 0.6)
    for (px, pz) in pit_caps[1:] + [(0.0, pit_end - 3.0)]:
        d = math.hypot(px - prev[0], pz - prev[1])
        wp.append({"pos": [px, ledge1_top, pz], "speed": round(1.15 * d / flight, 2), "reach": 1.3})
        prev = (px, pz + 0.6)

    # ================================================ SECTION 3: SPORE FLOORS
    z = pit_end
    top = ledge2_top
    sec3 = [
        # (dirt, spores, gap after, rise of the next bed, next bed width)
        (LEDGE2_DIRT, 6.0, 6.0, 0.5),
        (7.0, 7.0, 4.0, 0.0),     # -> the island
        (8.0, 0.0, 4.5, 1.0),     # the island: 8 m, then a 4.5 m gap rising 1 m
        (12.0, 8.0, 6.5, 0.0),   # the long spore run into the 6.5 m jump
    ]
    s3_beds = []
    first = True
    for i, (dirt, spore, gap, rise) in enumerate(sec3):
        z0, z1 = z, z - dirt - spore
        width = 8.0 if i == 2 else W
        s.bed(0, top, z0, z1, width=width, depth=2.0 if i else LEDGE1_H + 2.0,
              comment=("SECTION 3 -- SPORE FLOORS. Pale slick spores right before each jump: set your speed on the dirt first." if first else None))
        first = False
        if spore > 0:
            s.spores(0, top, z0 - dirt, z1, width=width)
        s3_beds.append({"z0": z0, "z1": z1, "top": top, "dirt": dirt, "spore": spore, "gap": gap, "rise": rise})
        z = z1 - gap
        top += rise
    plaza_top = top
    plaza_z0 = z

    # Main-route waypoints over section 3.
    b = s3_beds
    wp.append({"pos": [0, b[0]["top"], b[0]["z0"] - 5.0], "speed": 9.8})
    wp.append({"pos": [0, b[0]["top"], b[0]["z1"] + 0.6], "speed": 9.8, "reach": 0.8, "jump": True})
    wp.append({"pos": [0, b[1]["top"], b[1]["z0"] - 1.5], "speed": 9.8, "reach": 1.5})
    wp.append({"pos": [0, b[1]["top"], b[1]["z0"] - 6.5], "speed": 5.4, "reach": 1.5})
    wp.append({"pos": [0, b[1]["top"], b[1]["z1"] + 0.5], "speed": 5.4, "reach": 0.8, "jump": True})
    wp.append({"pos": [0, b[2]["top"], b[2]["z0"] - 1.0], "speed": 9.8, "reach": 1.5})
    wp.append({"pos": [0, b[2]["top"], b[2]["z1"] + 0.9], "speed": 9.8, "reach": 0.6, "jump": True})
    wp.append({"pos": [0, b[3]["top"], b[3]["z0"] - 5.0], "speed": 9.8})
    wp.append({"pos": [0, b[3]["top"], b[3]["z1"] + 0.6], "speed": 9.8, "reach": 0.8, "jump": True})
    wp.append({"pos": [0, plaza_top, plaza_z0 - 1.5], "speed": 9.8, "reach": 1.5})

    # Walls on the long spore run (both sides) with the spur opening on the right.
    b3 = b[3]
    spur_z0, spur_z1 = b3["z0"] - 4.0, b3["z0"] - 8.0
    for side in [-1, 1]:
        x = side * (W / 2 + 0.5)
        if side < 0:
            s.wall_z(x, b3["top"] - 0.5, b3["z0"], b3["z1"], 2.5)
        else:
            s.wall_z(x, b3["top"] - 0.5, b3["z0"], spur_z0, 2.5)
            s.wall_z(x, b3["top"] - 0.5, spur_z1, b3["z1"], 2.5)

    # Hidden 1: the spore spur off to the right, and the nook round its end.
    spur_x0, spur_x1 = W / 2, W / 2 + 14.0
    spur_spore_x1 = spur_x1 - 3.5
    spur_cz = (spur_z0 + spur_z1) * 0.5
    st = b3["top"]
    s.bed_at((spur_x0 + spur_x1) * 0.5, st, spur_cz, spur_x1 - spur_x0, spur_z0 - spur_z1,
             name="Spur", furrows_along_z="false",
             comment="HIDDEN 1 -- a spore-covered spur off the right side of the long spore run; at its end, round a corner, a nook")
    n = s.name("Spores")
    s.add('[node name="%s" type="Area3D" parent="."]' % n,
          [("script", 'ExtResource("spore")'), ("position", v3((spur_x0 + 0.3 + spur_spore_x1) * 0.5, st, spur_cz)),
           ("size", v3(spur_spore_x1 - spur_x0 - 0.3, 1.2, spur_z0 - spur_z1)), ("seed", "77")])
    nook_x0, nook_x1 = spur_x1 - 4.0, spur_x1
    nook_z0, nook_z1 = spur_z1, spur_z1 - 6.0
    s.bed_at((nook_x0 + nook_x1) * 0.5, st, (nook_z0 + nook_z1) * 0.5, nook_x1 - nook_x0, nook_z0 - nook_z1, name="Nook")
    # The nook's walls: the spur's far side is open (slide off if too fast), the nook is walled on its inner side.
    s.wall_z(nook_x0 - 0.5, st - 0.5, nook_z0, nook_z1 - 1.0, 3.5)
    s.wall_x(nook_z1 - 0.5, st - 0.5, nook_x0 - 1.0, nook_x1, 3.5)
    s.wall_x(spur_z0 + 0.5, st - 0.5, spur_x0 + 1.0, spur_x1, 1.2)
    crystal1 = (nook_x0 + 2.0, st, nook_z1 + 2.0)
    s.add('[node name="SporeCrystal" parent="." instance=ExtResource("crystal")]',
          [("position", v3(*crystal1)), ("which", "1")])
    s.fungus(nook_x1 - 0.6, st, nook_z1 + 0.7, amber=False, size=0.9, energy=1.6, rng=9.0)
    s.fungus(spur_x1 - 0.6, st, spur_z0 - 0.7, amber=False, size=0.7, energy=1.0, rng=7.0)

    # ================================================ SECTION 4: MUSHROOM TOWER
    plaza_x0, plaza_x1 = -26.0, 8.0
    plaza_z1 = plaza_z0 - 28.0
    s.bed_at((plaza_x0 + plaza_x1) * 0.5, plaza_top, (plaza_z0 + plaza_z1) * 0.5,
             plaza_x1 - plaza_x0, plaza_z0 - plaza_z1, name="Plaza", buttons_every="2.4",
             comment="SECTION 4 -- MUSHROOM TOWER. A walled plaza; the tower climbs from it in a left-turning spiral")
    pb = plaza_top - 0.5
    s.wall_z(plaza_x1 + 0.5, pb, plaza_z0, plaza_z1 - 1.0, 4.0)
    s.wall_z(plaza_x0 - 0.5, pb, plaza_z0, plaza_z1 - 1.0, 4.0)
    s.wall_x(plaza_z1 - 0.5, pb, plaza_x0 - 1.0, plaza_x1 + 1.0, 4.0)
    s.wall_x(plaza_z0 + 0.5, pb, plaza_x0 - 1.0, -W / 2 - 0.5, 2.5)
    s.wall_x(plaza_z0 + 0.5, pb, W / 2 + 0.5, plaza_x1 + 1.0, 2.5)

    m1 = (0.0, plaza_z0 - 9.0)
    tower = [m1]
    heading = 0.0
    for i in range(3):
        dx, dz = -math.sin(math.radians(heading)), -math.cos(math.radians(heading))
        last = tower[-1]
        tower.append((last[0] + dx * STEP, last[1] + dz * STEP))
        heading += TURN
    caps = []
    for i, (tx, tz) in enumerate(tower):
        cap = plaza_top + 0.1 + RISE * i
        caps.append(cap)
        s.mushroom(tx, plaza_top, tz, cap, 1.8 if i == 0 else TOWER_R, name="Tower",
                   comment=("the tower: each cap %.1f m above the last, %.1f m apart" % (RISE, STEP)) if i == 0 else None)
    # The exit platform past the top mushroom.
    dx, dz = -math.sin(math.radians(heading)), -math.cos(math.radians(heading))
    t4 = tower[-1]
    exit_top = caps[-1] + 3.9
    exit_center = (t4[0] + dx * (TOWER_R + 0.4 + 7.0), t4[1] + dz * (TOWER_R + 0.4 + 7.0))
    s.bed_at(exit_center[0], exit_top, exit_center[1], 14.0, 14.0, rot=heading, name="Exit", depth=2.0,
             comment="the high exit, %.1f m above the plaza, with the goal" % (exit_top - plaza_top))
    hill = (exit_center[0] + dx * 1.5, exit_top, exit_center[1] + dz * 1.5)

    # Hidden 0: the tall mushroom beside the tower and the blue cap that throws you onto it.
    t3 = tower[2]
    out = (0.8, -0.6)
    tall = (t3[0] + out[0] * 3.7, t3[1] + out[1] * 3.7)
    tall_top = caps[2] + 1.6
    s.mushroom(tall[0], plaza_top, tall[1], tall_top, 1.8, name="TallMushroom", bouncy="false",
               cap_color="Color(1, 0.86, 0.55, 1)", glow_color="Color(1, 0.7, 0.3, 1)", stem_radius="0.6",
               comment="HIDDEN 0 -- a tall, solid mushroom beside the tower; the crystal sits on its cap. Roll off it onto the third tower cap")
    launcher = (tall[0] + 3.4, tall[1] + 0.4)
    s.mushroom(launcher[0], plaza_top, launcher[1], plaza_top + 0.1, 1.4, name="TallLauncher",
               height_value='"mushroom_tall_bounce_height"', cap_color="Color(0.75, 0.9, 1, 1)",
               glow_color="Color(0.45, 0.75, 1, 1)", glow_energy="1.1",
               comment="the blue launcher at the foot of the tall mushroom (Tuning.mushroom_tall_bounce_height)")
    crystal0 = (tall[0], tall_top, tall[1])
    s.add('[node name="TallCrystal" parent="." instance=ExtResource("crystal")]',
          [("position", v3(*crystal0)), ("which", "0")])

    # Main route up the tower.
    wp.append({"pos": [0, plaza_top, plaza_z0 - 3.5], "speed": 3.0, "reach": 1.2})
    wp.append({"pos": [m1[0], plaza_top, m1[1]], "speed": 2.0, "reach": 1.0})
    t_flight = math.sqrt(2.0 * 6.5 / 12.27) + math.sqrt(2.0 * (6.5 - RISE) / 12.27)
    for (tx, tz) in tower[1:]:
        wp.append({"pos": [round(tx, 2), 0, round(tz, 2)], "speed": round((STEP + 1.2) / t_flight, 2), "reach": 1.3})
    wp.append({"pos": [round(exit_center[0], 2), exit_top, round(exit_center[1], 2)], "speed": 3.0, "reach": 1.5})
    wp.append({"pos": [round(hill[0], 2), exit_top, round(hill[2], 2)], "speed": 3.0, "reach": 0.4})

    # ================================================ LIGHTS AND DECORATION
    # Fungus along the section 1-2 walls, every ~12 m, alternating sides.
    side = 1
    zz = 0.0
    while zz > pit_end + 2:
        y = Y0
        if zz < ledge1_z0 and zz > ledge1_end:
            y = ledge1_top
        in_trench = any(b0 >= zz >= b1 for (b0, b1) in s1_trenches)
        if not in_trench and not (ledge1_end >= zz >= pit_end):
            s.fungus(side * (W / 2 - 0.7), y, zz, size=0.8)
        side = -side
        zz -= 11.0
    # Lips of the hops: a small amber lamp on each side of every landing.
    for (lip, land) in s1_trenches:
        s.fungus(-W / 2 + 0.6, Y0, land - 0.8, size=0.5, energy=0.9, rng=7.0)
    # Wall crystals on the ledge faces and pit walls.
    s.crystal_lamp(W / 2 - 1.5, Y0 + 2.2, ledge1_z0 + 0.05, rot=(90, 0, 0), size=0.8)
    s.crystal_lamp(-W / 2 + 1.5, Y0 + 2.2, ledge1_z0 + 0.05, rot=(90, 0, 0), size=0.8)
    s.crystal_lamp(-W / 2 + 0.05, Y0 + 4.5, (ledge1_end + pit_end) / 2, rot=(0, 0, -90), size=0.9)
    s.crystal_lamp(W / 2 - 0.05, Y0 + 4.5, (ledge1_end + pit_end) / 2 + 6, rot=(0, 0, 90), size=0.9)
    s.crystal_lamp(0, Y0 + 2.0, pit_end - 0.0 + 0.05, rot=(90, 0, 0), size=1.0)
    # Section 3: lamps at every lip and landing, both sides.
    for bd in s3_beds:
        width = 8.0 if bd is s3_beds[2] else W
        for sx in [-1, 1]:
            s.fungus(sx * (width / 2 - 0.6), bd["top"], bd["z0"] - 0.8, size=0.6, energy=1.0, rng=8.0)
            s.fungus(sx * (width / 2 - 0.6), bd["top"], bd["z1"] + 0.8, size=0.6, energy=1.0, rng=8.0)
    # Plaza corners and the exit.
    for (cx, cz) in [(plaza_x1 - 1, plaza_z0 - 1), (plaza_x0 + 1, plaza_z0 - 1), (plaza_x1 - 1, plaza_z1 + 1),
                     (plaza_x0 + 1, plaza_z1 + 1), (-10, plaza_z1 + 1), ((plaza_x0 + plaza_x1) / 2, plaza_z0 - 1)]:
        s.fungus(cx, plaza_top, cz, size=1.1, energy=1.8, rng=14.0)
    for k in range(4):
        a = math.radians(heading + 45 + 90 * k)
        cx = exit_center[0] + math.sin(a) * 6.0
        cz = exit_center[1] + math.cos(a) * 6.0
        s.fungus(cx, exit_top, cz, size=0.9, energy=1.6, rng=12.0)
    s.crystal_lamp(plaza_x1 + 0.0, plaza_top + 2.5, (plaza_z0 + plaza_z1) / 2, rot=(0, 0, 90), size=1.2)
    s.crystal_lamp(plaza_x0 - 0.0, plaza_top + 2.5, (plaza_z0 + plaza_z1) / 2, rot=(0, 0, -90), size=1.2)
    # Drifting spores over the garden.
    s.cloud(0, Y0, -20, 10, 3, 30, 70)
    s.cloud(0, Y0 + 1, (ledge1_z0 + pit_end) / 2, 10, 6, 40, 90)
    s.cloud(0, Y0 + 3, (pit_end + plaza_z0) / 2, 12, 4, 60, 110)
    s.cloud(-8, plaza_top, (plaza_z0 + plaza_z1) / 2, 30, 18, 26, 220)
    # Decorative giant mushrooms beside the course (solid, outside the walls).
    for (dx_, dz_, h, r) in [(-9, -10, 7, 2.6), (9, -38, 9, 3.0), (-9.5, -70, 11, 3.2), (9.5, -100, 12, 3.0),
                             (-11, -150, 10, 3.0), (12, -170, 8, 2.6)]:
        s.mushroom(dx_, Y0 - 3.0, dz_, Y0 - 3.0 + h, r, name="Giant", bouncy="false",
                   cap_color="Color(0.85, 0.7, 1, 1)", glow_color="Color(0.6, 0.4, 1, 1)", glow_energy="0.7",
                   light_energy="1.6", light_range="14.0", stem_radius="0.7")

    return s, wp, marks, {
        "crystal0": crystal0, "crystal1": crystal1, "hill": hill, "launcher": launcher, "tall": tall,
        "tower": tower, "plaza_top": plaza_top, "plaza_z0": plaza_z0, "exit_center": exit_center,
        "exit_top": exit_top, "b3": b3, "spur": (spur_x0, spur_x1, spur_z0, spur_z1), "nook": (nook_x0, nook_x1, nook_z0, nook_z1),
    }


HEADER = """[gd_scene format=3]

[ext_resource type="Script" path="res://levels/level.gd" id="level"]
[ext_resource type="PackedScene" path="res://levels/nest/anthill_theme.tscn" id="theme"]
[ext_resource type="PackedScene" path="res://src/objects/start_point.tscn" id="start"]
[ext_resource type="PackedScene" path="res://src/objects/ant_hill.tscn" id="hill"]
[ext_resource type="PackedScene" path="res://src/objects/fall_zone.tscn" id="fall"]
[ext_resource type="PackedScene" path="res://src/objects/hidden_crystal.tscn" id="crystal"]
[ext_resource type="Script" path="res://src/objects/nest/dirt_bed.gd" id="bed"]
[ext_resource type="Script" path="res://src/objects/nest/bounce_mushroom.gd" id="mush"]
[ext_resource type="Script" path="res://src/objects/nest/spore_patch.gd" id="spore"]
[ext_resource type="Script" path="res://src/objects/nest/spore_cloud.gd" id="cloud"]
[ext_resource type="Script" path="res://src/objects/nest/dirt_wall.gd" id="wall"]
[ext_resource type="Script" path="res://src/objects/nest/glow_fungus.gd" id="fungus"]
[ext_resource type="Script" path="res://src/objects/nest/wall_crystal.gd" id="wcrystal"]

; LEVEL 3 -- FUNGUS FARM (teaches jumping). GENERATED by
; tools/make_fungus_farm.py; change the numbers there and re-run it.
[node name="Level3FungusFarm" type="Node3D"]
script = ExtResource("level")
level_name = "Fungus Farm"

[node name="AnthillTheme" parent="." instance=ExtResource("theme")]
fog_density = 0.0065

[node name="StartPoint" parent="." instance=ExtResource("start")]
position = Vector3(0, 8, 2)
"""


def main():
    s, wp, marks, info = build()
    text = HEADER
    for node in s.nodes:
        text += "\n" + node
    hill = info["hill"]
    text += "\n" + '[node name="AntHill" parent="." instance=ExtResource("hill")]\n'
    text += "position = %s\nbase_radius = 5.0\n" % v3(*hill)
    text += '\n[node name="FallZone" parent="." instance=ExtResource("fall")]\n'
    text += "position = Vector3(0, -1, -120)\nsize = Vector3(600, 4, 600)\n"
    with open(os.path.join(ROOT, "levels/nest/level_3_fungus_farm.tscn"), "w") as fh:
        fh.write(text)

    def clean(points):
        out = []
        for p in points:
            q = {k: v for k, v in p.items() if not k.startswith("_")}
            q["pos"] = [round(float(c), 2) for c in q["pos"]]
            out.append(q)
        return out

    tests = os.path.join(ROOT, "tests/levels")
    main_drive = {"level": 3, "timeout": 150, "speed": 8, "waypoints": clean(wp)}
    with open(os.path.join(tests, "level_3_fungus_farm.json"), "w") as fh:
        json.dump(main_drive, fh)

    # Hidden 1: the spore spur. Same as the main route up to the long spore
    # run, then slowly into the spur and round into the nook, and back.
    b3 = info["b3"]
    sx0, sx1, sz0, sz1 = info["spur"]
    nx0, nx1, nz0, nz1 = info["nook"]
    cut = next(i for i, p in enumerate(wp) if abs(p["pos"][2] - (b3["z0"] - 5.0)) < 0.01)
    spur_cz = (sz0 + sz1) / 2
    c1 = info["crystal1"]
    side = [
        {"pos": [0, b3["top"], b3["z0"] - 1.5], "speed": 9.8, "reach": 1.5},
        {"pos": [0, b3["top"], spur_cz + 0.5], "speed": 3.0, "reach": 1.0},
        {"pos": [sx0 + 1.0, b3["top"], spur_cz], "speed": 2.5, "reach": 0.8},
        {"pos": [nx0 + 2.0, b3["top"], spur_cz], "speed": 2.5, "reach": 0.8},
        {"pos": [c1[0], c1[1], c1[2]], "speed": 2.0, "reach": 0.5},
        {"pos": [nx0 + 2.0, b3["top"], spur_cz], "speed": 2.5, "reach": 0.8},
        {"pos": [sx0 + 1.5, b3["top"], spur_cz], "speed": 3.0, "reach": 1.0},
        {"pos": [-1.0, b3["top"], spur_cz], "speed": 3.0, "reach": 1.2},
        {"pos": [-1.0, b3["top"], b3["z0"] - 1.2], "speed": 3.0, "reach": 0.8},
        {"pos": [0, b3["top"], b3["z0"] - 10.0], "speed": 9.8, "reach": 1.5},
    ]
    route = wp[:cut] + side + wp[cut + 1:]
    with open(os.path.join(tests, "level_3_fungus_farm_crystals.json"), "w") as fh:
        json.dump({"level": 3, "timeout": 180, "speed": 8, "expect_hidden": [1], "waypoints": clean(route)}, fh)

    # Hidden 0: the tall mushroom shortcut on the tower.
    t_idx = next(i for i, p in enumerate(wp) if p["speed"] == 2.0)   # the M1 approach
    lx, lz = info["launcher"]
    tx, tz = info["tall"]
    tower = info["tower"]
    pt = info["plaza_top"]
    short = [
        {"pos": [lx + 3.8, pt, lz + 3.0], "speed": 3.0, "reach": 1.0},
        {"pos": [lx + 3.8, pt, lz], "speed": 2.0, "reach": 0.6},
        {"pos": [lx, pt, lz], "speed": 2.5, "reach": 1.2},
        {"pos": [tx, 0, tz], "speed": 2.6, "reach": 0.8},
        {"pos": [tx, 0, tz], "speed": 0.3, "reach": 0.4},
        {"pos": [round(tower[2][0], 2), 0, round(tower[2][1], 2)], "speed": 1.8, "reach": 1.3},
    ]
    after = [p for p in wp[t_idx + 1:]]
    # keep only the tower waypoints from the 4th mushroom on
    t4 = (round(tower[3][0], 2), round(tower[3][1], 2))
    k = next(i for i, p in enumerate(after) if abs(p["pos"][0] - t4[0]) < 0.01 and abs(p["pos"][2] - t4[1]) < 0.01)
    route = wp[:t_idx - 1] + [{"pos": [lx + 2.0, pt, info["plaza_z0"] - 3.0], "speed": 3.0, "reach": 1.2}] + short + after[k:]
    with open(os.path.join(tests, "level_3_fungus_farm_shortcut.json"), "w") as fh:
        json.dump({"level": 3, "timeout": 150, "speed": 8, "expect_hidden": [0], "waypoints": clean(route)}, fh)
    print("wrote level_3_fungus_farm.tscn and 3 drives; hill at", hill, "exit top", info["exit_top"])


if __name__ == "__main__":
    main()
