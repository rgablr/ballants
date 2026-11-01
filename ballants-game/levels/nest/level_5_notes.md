# Level 5 -- Collapsing Gallery (design notes)

Teaches: **commitment**. Everything from the earlier nest levels at once
(speed, open edges, tight curves, a jump), on a floor that falls away
after you touch it. An old, abandoned tunnel: cracked grey-brown floor
slabs over a dark drop, lumpy dirt walls, old roots arching overhead,
dirt specks and thin pours of dirt falling from the dark ceiling. A
near-black unlit plane (no collision, fog off) at y = 1.2 under the whole
level makes every hole in the floor read as a black pit.

The scene is GENERATED: `python3 tools/make_collapsing_gallery.py` (run
from `ballants-game/`) rewrites `level_5_collapsing_gallery.tscn` and the
three drive files from a cursor walk of solid islands, tile straights,
tile arcs and a tile slope, so every piece meets the next by
construction. Change the walk in `build()`, not the scene.

About 400 m of course, 421 collapsing tiles. Floors run from y = 12 down
to the goal plateau at y = 4.9; a FallZone at y = -1 catches anything
that drops through (a fall through a hole takes about 1.3 s to register).

Target time: **recommend 1:05 (65 s)** (the list still says 90 s; the
integrator sets it). The bot's clean main run is 0:52.5; a fast
human who never hesitates should manage about 0:58-1:02; a first-timer
3-4 minutes with restarts. Beating 1:05 needs a clean run: no stops, the
outside line through the curves, and the jump taken at speed.

## The piece: CollapsingTile (`src/objects/nest/collapsing_tile.gd`)

A StaticBody3D slab (NOT a Block, no `merge_collision`, so the
StaticMerger leaves it alone) with its own convex collision: a box
(`size`) or any four-cornered slab (`corners`, used for the wedge tiles
round the curves). The top face is at the node origin. Each frame it
checks whether the ball's center is over its top face (within 0.3 m of
touching); the first touch starts its timer:

1. wait `extra_delay` + crack delay (looks normal: grey dirt, a few old cracks),
2. CRACK: fresh dark cracks appear, it rattles harder and harder, dust puffs, a low crunch,
3. after the fall delay it DROPS: collision off at once, the slab tumbles away and is hidden.

The timer counts physics steps (never the clock), so a tile falls exactly
the same time after the touch on every run; restarting reloads the scene
so every tile is back. Crack/fall delays come from the physics config
unless overridden per tile (`crack_delay`, `fall_delay` >= 0), times
`timing_scale` times the config value named in `timing_setting`.
`trigger_group`: every tile of a group starts its timer when any one is
touched (used for the curves, the bridge, the dead end and the warning demo).
Looks: a bevelled top inset 7 cm (a dark groove between neighbours),
per-tile color from a seeded RNG, 2-3 old crack lines, 4 hidden fresh ones.

`src/objects/nest/falling_dust.gd` (FallingDust): a looping
GPUParticles3D of dirt specks plus a few thin "pours", over a box along
the corridor. Decoration only.

## New tunables (physics config, section "LEVEL 5: COLLAPSING GALLERY")

| Value | Default | What |
|---|---|---|
| `tile_crack_delay` | 0.55 s | touch -> starts cracking |
| `tile_fall_delay` | 0.75 s | cracking -> drops (so a normal tile is gone 1.3 s after the touch) |
| `tile_fall_speed` | 1.0 | how fast a dropped slab falls out of sight (x gravity), looks only |
| `tile_shake` | 0.05 m | rattle size, looks only |
| `gallery_warning_scale` | 2.6 | section 1 tiles: x2.6 slower (crack 1.43 s, gone 3.4 s) |
| `gallery_curve_inside_scale` | 0.3 | curves' inside row: crack 0.17 s, gone 0.39 s after the curve's trigger |
| `gallery_sprint_scale` | 0.5 | slope tiles: crack 0.28 s, gone 0.65 s |
| `gallery_ledge_bridge_scale` | 0.5 | the ledge bridges' own crack/fall times (0.28 / 0.65 s) |
| `gallery_ledge_bridge_delay` | 1.5 s | the first bridge waits this long after its trigger, +0.25 s per tile outward |
| `gallery_dead_end_time` | 2.5 s | dead end: entrance tile's countdown starts this long after you enter (it is gone 3.8 s after you enter) |

## Section by section

| # | Section | What it is | Skill beat |
|---|---|---|---|
| 1 | Warning floor | 14 m solid start, a 3x3 patch, 7 m solid, a 3x5 patch, 7 m solid, a gentle 30 degree left arc of tiles (radius 24 m), 4 rows, a 10 m solid island. All tiles x2.6 slow. Rolling onto the first patch also triggers a DEMO: the middle lane of the next patch (3 tiles) cracks at once and falls 0.8-1.2 s later, in front of you, leaving a hole to steer round | See a tile crack and fall before it can hurt you; learn "cracked floor goes" and "a hole is a fall" |
| 2 | Crumbling corridor | Normal tiles: 19 m straight, a 35 degree right arc (radius 26), 10 m, the 34 m LEDGE straight (open on the right: a void, then the side ledge), 8 m solid island, 34 m straight, an S-bend (40 degrees left then right, radius 22), 29 m straight, a 12 m solid island (the dead end opens off its left wall) | Keep rolling: any tile you stop on is gone 1.3 s later. Islands are the only safe places to stop |
| 3 | Collapsing curves | Each curve: a short tile straight whose last row is the trigger, then a wedge-tile arc of 3 rows (centerline radius 9.6 m): left 90, right 120, left 90. Outer wall only; the inside is open. Entering the trigger row drops the whole INSIDE row 0.4 s later. Amber wall crystals mark each outer wall. 10 m solid island after | The inside line is gone; take the middle/outer line at a speed it allows (8-9.5 m/s) |
| 4 | Final sprint | A 31 m collapsing slope (5, 9, then 11 rows at 12 degrees, 6.1 m drop), fast tiles, walled. Two big wall crystals mark the lip. A 6 m gap to a goal plateau 1 m lower (14 x 20 m, walled), ant hill (base radius 5) 11 m in | Commit: full speed down, jump off the last row. Hesitate and the row under you is gone |

## Hidden crystals

- **Hidden 0: the side ledge (rewards exploring).** Along the 34 m ledge
  straight the corridor's right wall is missing: across a 4 m void runs
  a 24 m solid ledge with its own wall, the crystal in the middle, a
  blue-white fungus at its near end. A 2 m wide tile BRIDGE leaves the
  corridor's right lane at a 31 degree angle and reaches the ledge 13 m
  on. The bridge's countdown starts when you roll over the row just
  BEFORE it (group `ledge_a`): 1.5 s later its first tile cracks, each
  tile further out 0.25 s after that, so you must turn onto it at once
  and keep going. A speedrunner on the main line sees the bridge crumble
  as they pass. A second bridge (own-touch, fast) leads from the ledge's
  far end back to the corridor just before the island.
- **Hidden 1: the dead end (off the fast route, fast turnaround).** On
  the 12 m island at the end of section 2 a 2.4 m opening in the LEFT
  wall, half hidden by a hanging root curtain, leads into a 1-tile-wide,
  9.6 m deep dead end, the crystal near its end wall, faint blue fungus
  behind it. Touching its first tile starts all four tiles' clocks: the
  ENTRANCE tile goes first (cracks at 3.05 s, gone 3.8 s), the deeper
  ones 0.3 s apart after it. Roll in, bounce off the end wall (you come
  back at ~0.55 of your speed) and roll straight out. Hesitate and you
  are cut off. A speedrunner crossing the island at speed sees only a
  dark gap behind roots.

## Layout <-> physics (current tuning)

| Measurement | Depends on | Why |
|---|---|---|
| Tiles 2.4 m long; normal tile gone 1.3 s after the touch | `tile_crack_delay`, `tile_fall_delay` | Only a ball that STOPS falls: crossing a 2.4 m tile in 1.3 s needs just 1.9 m/s. "Stopping means falling" |
| Warning tiles gone 3.4 s after the touch | `gallery_warning_scale` x the two above | A first-timer can stop, look, and still get off |
| Corridor 7.2 m wide (3 lanes), walls 2.5 m above the floor | `jump_height` 1.59, ball radius 0.5 | Room to steer round a hole; no hopping the wall |
| Curves: centerline radius 9.6 m; inside lane gone, usable floor from radius 8.4 to 13.2 m | `roll_acceleration` 10.085, `turn_assist` 0.1, `max_speed` 9.775 | Tightest steady turn ~ v^2 / 7.9: the middle lane (9.6 m) holds 8.7 m/s, the outer lane (12 m) 9.7 m/s. The lost inside lane (7.2 m) would only have held 7.5 m/s anyway, but it is the short line; with it gone you must swing wide. Arrive at top speed on the inside and you drop through |
| Inside row gone 0.39 s after the trigger row (2.4 m before the arc) | `gallery_curve_inside_scale` | At 8 m/s you reach the arc 0.3 s after the trigger and the inside is going as you arrive: you see it fall ahead |
| Sprint slope 12 degrees, 31 m | `gravity` 12.27, `rolling_resistance` 0.3975 | Under ~26 degrees the slope never beats the push cap, so you arrive at the lip at ~9.8 m/s however you rolled, as long as you held forward |
| Sprint tiles gone 0.65 s after the touch | `gallery_sprint_scale` | Need >= 3.7 m/s; the LAST row gives you 0.65 s to jump (plus `coyote_time` 0.115) |
| Jump gap 6 m, landing 1 m lower | `jump_height` 1.59 (launch 6.25 m/s), `gravity` | Airtime to 1 m below the lip is 1.16 s: you need >= 5.2 m/s across the gap; at 9.8 m/s you land ~11 m out (the plateau is 20 m long). Rolling off without jumping at 9.8 m/s on the 12 degree slope covers only ~2.4 m |
| Crest rows 5 -> 9 -> 12 degrees, each steeper row 2 cm lower | `ground_stick` 1.0 | A flush crest let the ball catch the next slab's back edge (a 3.4 m/s pop); the 2 cm step removes it |
| Ledge bridge: 2 m wide, 14 m long, 31 degrees off the corridor; tile k gone 2.15 + 0.25k s after the trigger | `gallery_ledge_bridge_delay`, `gallery_ledge_bridge_scale`, `turn_assist` | At 7-8 m/s you reach tile k ~0.9 + 0.33k s after the trigger: ~1 s to spare if you turn at once, none if you brake first |
| Dead end 9.6 m deep; entrance gone 3.8 s after you enter | `gallery_dead_end_time`, `ball_bounce` 0.55, `brake_multiplier` | In 4.5 m/s, bounce off the end wall at ~0.55 v, push back out: ~2.5-3.3 s for the bot (it passes with the setting at 2.0, fails at 1.2) |
| Every floor above y = 4.8 | `fall_respawn_y` -2.5 | Falling below -2.5 fails the run even on a floor |
| Fungus every 12 m on the wall tops, amber crystals on the outer walls of the curves and at the lip | `camera_distance` 2.14 | The camera is close; lights keep the next bend and the lip readable |

## Verification

`./run_tests.sh` runs the three drives:
`tests/levels/level_5_collapsing_gallery.json` (main route),
`..._ledge.json` (expects hidden 0), `..._dead_end.json` (expects hidden 1).

Bot times: main 0:52.5, ledge (hidden 0) 0:55.5, dead end (hidden 1) 0:58.6.
Determinism: the main drive run twice gave 0:52.66 / 0:52.64, and after the last changes 0:52.51 / 0:52.58 (the HUD timer adds frame times, so a few hundredths of jitter; the tiles themselves count fixed physics steps).

## Acceptance criteria (test by playing)

- Roll onto the first cracked patch slowly: nothing happens for ~1.4 s, then the slabs rattle, crack and puff dust, and ~3.4 s after you touched them they drop into the dark. Restart (R): every slab is back.
- On the first patch, look ahead: three slabs in the middle of the next patch crack and fall while you watch, leaving a hole you can steer round.
- In section 2, stop on any tile: about 1.3 s later it goes and you fall. Stop on the solid islands (plain, darker dirt, no grooves): nothing happens.
- Each of the three tight curves: as you enter, the whole inside lane crumbles ahead of you; the middle/outer lanes stay until you touch them.
- The final slope crumbles right behind you; jump off the last row and you land on the plateau with room to spare; roll off without jumping and you drop short.
- The same tile always goes the same time after you touch it (try stopping on one twice).
- Hidden 0: from the ledge straight, turn right onto the narrow bridge straight away: you make it to the ledge; brake first and the bridge is already falling.
- Hidden 1: stop on the island after the S-bend, find the dark gap behind the roots on the left, roll in, take the crystal and come straight back: you get out as the entrance cracks.
- A clean, confident run beats 1:05; one stop or a wide curve does not.

## Known issues

- The F1 panel groups sliders by section header, but its header pattern
  (`[A-Z /()]`) does not accept the brief's `LEVEL 5: ...` header (digit
  and colon), so the new values appear under the previous section
  ("Interactive Objects") in the panel. They work; only the grouping is
  off. Same for every level that follows the brief's header format.
- The bot reports one "pop" at the final jump: the bot releases jump
  before its pop check runs, so its own jump looks like a pop. Not a
  level problem.
- A hidden crystal is saved the moment you touch it (level system), so
  grabbing the dead-end crystal and then falling still keeps it. See Q2.
- Tiles are separate bodies; the ball's seam smoothing irons out the
  joins (writing tile corners to 5 decimals mattered: at 3 decimals a
  1 mm mismatch gave a 3 m/s pop). The ledge drive still logs one small
  pop (1.2 m/s) where the first bridge's angled slabs overlap the
  corridor lane. A chamfered tile edge was tried and made it far worse.
- About 420 tiles each run a cheap check every physics step (dropped
  tiles stop). Fine on the dev Mac; not profiled on weaker machines.

## Questions for the owner

Q1. Target time: (A) 1:05 as recommended (bot ~0:52) (B) 1:10 (forgiving) (C) 1:00 (tight, near-perfect only)
Q2. Dead-end crystal when you fall after grabbing it: (A) keep it, as the level system does now (B) only count it if you get back out (needs a level-system change) (C) move the crystal so you grab it on the way OUT (e.g. hanging over the entrance, reachable only on the return)
Q3. Normal tile timing (touch -> gone): (A) 1.3 s as now (B) 0.9 s (harsher, slow players fall more) (C) 1.8 s (gentler)
Q4. The curves' inside lane: (A) drops all at once on entry, as now (B) drops in a wave just ahead of you (C) only the inner half of each wedge drops
Q5. The warning demo (slabs ahead falling by themselves): (A) keep (B) also add a short on-screen hint the first time (C) remove it, let players learn by touch
Q6. Level length (~400 m, bot 0:52): (A) fine (B) add a fourth curve or a longer corridor to reach a 60-90 s fast run (C) shorter
Q7. Tile look: (A) grey-brown dusty slabs with grooves (clearly different from safe dirt) as now (B) same color as the safe floor, only cracks show (harder to read) (C) add a faint glow/red tint when cracking
