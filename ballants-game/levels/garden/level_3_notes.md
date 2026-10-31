# Level 3 – Garden Hose Bridge (design notes)

Scene: `levels/garden/level_3_garden_hose_bridge.tscn`
Bot drive: `tests/levels/level_3.json` (PASS in about 0:22 with 0 falls)

**Skill taught:** balance on a narrow surface and choosing a careful speed.
Every section is the same hose; what changes is how much room the ball has
and whether the hose is straight, humped or bending.

## The course, section by section

The course runs from the start toward -Z. One `Hose` node (world position
`(0, 0, -5)`, 23 points, 78 m long) does the whole bridge. Its radius blends
linearly from 2.0 m at the first point to 1.0 m at the last point.

| # | Section | Where (world z) | What it asks of the player |
|---|---|---|---|
| 0 | Start bank | z = +10 … -6 | Dirt, 56 m wide, 2 m thick, grass wall along the back. The ball starts at `(0, 0, 3)` facing the hose. |
| 1 | Wide straight | z = -5 … -29 | Hose radius 2.0 -> 1.7 (3.4–4 m wide). Nothing to do but roll; the player gets used to the rounded top. |
| 2 | Gentle hump | z = -29 … -47 (peak -38) | The hose drapes over a dark pebble: the top rises 0.8 m over 9 m and falls again over 9 m. Radius about 1.55. Too much speed here lifts the ball off the top. |
| 3 | S-bend, narrowing | z = -47 … -70 | Four 15-degree turns right then four back left (bend radius 13.4 m, points every 3.5 m). Radius 1.45 -> 1.1. Tall flowers stand on the banks outside each turn so the curve can be seen coming at camera distance 2.14 m. |
| 4 | Narrow straight | z = -70 … -78, x = 13.3 | Radius 1.1 -> 1.0 (2 m wide). The pot is straight ahead. |
| 5 | Jump to the pot | hose end z = -78.0, pot centre z = -82.8 | 2.0 m of water between the last hose point and the pot's collision rim; pot top 0.5 m above the hose top; landing disc 5.6 m across. |
| 6 | Far bank and goal | z = -84.5 … -100.5, goal at `(13.3, 0, -93.5)` | Roll off the pot (0.5 m drop) onto dirt and through the ring. |

Falling anywhere off the hose lands in the `Puddle` (water at y = -1.6,
32 x 81 m, FallZone just under the surface) which fails the run and
restarts the level after 0.8 s. A big `FallZone` at y = -8 catches anything
else (the banks have open sides).

## Skill progression and target time

1. Wide and straight: learn that the hose top is round and the sides slope.
2. Hump: learn that speed matters (the ball hugs the hump at 4–6 m/s and
   pops off it at top speed).
3. S-bend while narrowing: steer gently at 4–5 m/s, read the turn ahead.
4. Narrow straight + one small jump: the "test", using the same balance
   skill plus one jump of the kind the player already did in levels 1–2.

Target time: 30–60 s for a first-time player (the bot does it in ~22 s
at 4–6 m/s; par is 75 s in the level list). A fall costs about 10–20 s
because the level restarts from the beginning, which is the "careful speed"
lesson.

## Layout measurements and the tuning values they depend on

All tuning values are from `config/physics_tuning.gd` at the time of
writing; if they change, re-check the row that mentions them.

| Measurement | Value | Depends on |
|---|---|---|
| Hose radius start / end | 2.0 m / 1.0 m | ball radius 0.5 m (1.0 is "comfortable", 0.6–0.8 would be hard); `turn_assist` 0.72 and the 4–6 m/s cruising speed set how much sideways drift the player must correct |
| Hose point spacing | 4 m straight, 3 m hump, 3.5 m bends | polyline kinks must stay under about 15 degrees so the ball tracks the top (`ground_stick` 0.37) |
| Bend radius | 13.4 m (15 degrees per 3.5 m point, 4 points per turn) | minimum comfortable turn radius ~ v^2 / 12.6 m/s^2 (sideways push from `roll_acceleration` 10.48 x `turn_assist`): 5 m/s -> 2 m, 8 m/s -> 5 m; 13.4 m leaves a wide margin and the brief's 6 m minimum |
| Hump | +0.8 m over 9 m up, 9 m down (slope 5–8 degrees, crest radius ~20 m) | `ground_stick` 0.37 keeps the ball on a rise of up to ~1 m over 6 m at 6 m/s; launch-off speed at the crest ~ sqrt(g R) with `gravity` 9.94 -> about 14 m/s, i.e. only a full-speed ball leaves the hose |
| Hose top at the start | y = 0, first point 1 m inside the dirt edge | the dirt top is at y = 0, so there is no lip; the hose is not merged with the dirt (`StaticMerger` only folds Blocks) |
| Jump gap (hose end point to pot collision rim) | 2.0 m (pot centre 4.8 m past the end) | `jump_height` 1.59 m -> launch 5.62 m/s; time to land 0.5 m higher is 1.03 s with `gravity` 9.94, so take-off at 3–6 m/s covers 3.1–6.2 m; the pot top spans 2.0–7.6 m past the hose end |
| Pot top above hose top | 0.5 m | must be <= 1.4 m (jump apex) and the brief's 1.0 m; 0.5 m keeps it an obvious "jump up" and a soft 0.5 m drop onto the far bank |
| Pot | height 2.1 m from the water (top at y = 0.5), top_radius 2.6 (collision radius 2.81, landing 5.6 m across) | landing target >= 4 m across so a 1 m/s speed error still lands |
| Puddle surface | y = -1.6 | `fall_respawn_y` is -2.5: the water's FallZone (top at -1.8) catches the ball before the hard respawn height, so the "Fell out" restart is always the puddle's |
| Stopping on the hose | 4 m from 8 m/s | `brake_multiplier` 1.25 x effective 7.3 m/s^2; the final narrow straight is 8 m so a player can slow before the jump |
| Bot speeds | 6 straight, 5 hump, 4 bends, 5 at the jump, 7 to the goal | `max_speed` 14.2 is never needed; proves a careful human pace completes it |

## What was checked

- `godot --headless -- --drive=tests/levels/level_3.json`: PASS, 0 falls.
- A drive that deliberately steers off the wide straight: the puddle fails
  the run and the level restarts (the bot reports falls).
- Debug-overlay screenshots at the dirt/hose junction, the hump, the
  S-bend, the hose end, the pot and the goal: the ball never enters the
  hose capsules or the pot cylinder; the hose top is flush with the dirt.
- `./run_tests.sh`: "RESULT: all checks passed".

## Not done / open

- No new piece files were needed; the level is built only from the
  existing garden kit (hose, puddle, pot, dirt tiles, stems, pebbles,
  grass). No assets were added.
- The hose's radius is a single linear blend, so the wide straight already
  narrows a little (2.0 -> 1.7) before the "narrowing" section. A piece
  with a per-point radius would let the straight stay a constant width.
- The world outside the four dirt banks is empty sky, like the other
  garden levels; nothing stops the player wandering off the banks' outer
  edges except the big FallZone.
