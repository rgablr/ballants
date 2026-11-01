# Level 4 -- Worker Rush (design notes)

Teaches: **speed control and timing**. Busy flat tunnels (floor at y = 4
everywhere) full of worker ants carrying pale crumbs on fixed paths. 341 m
of main centerline in four sections joined by two 90-degree bends
(radius 20 m). The scene is GENERATED: `python3 tools/make_worker_rush.py`
(run from `ballants-game/`) rewrites `level_4_worker_rush.tscn`; change the
layout there, not in the scene. The three bot drive files are hand-tuned
(see "Bot drives" below).

Recommended target time **1:15** (75 s). The bot's clean run is **1:04.1**
with zero bumps (it waits in safe spots for every gap); a fast human who
reads the rhythms should land around 1:00-1:10; a careful first-timer 3-4
minutes. Lucky gaps do not get you there: each bump costs 1.5-3 s (you
are thrown back ~2-3 m and lose all your speed), and the gate costs up to
2 s more if you arrive while it is shut.

## The rhythm is the same every run

Every worker's place is `(level clock x speed + offset + i x spacing) mod
loop`, where the level clock is **physics steps since the level scene
loaded** (`WorkerLine.clock_start`: the first piece to ask stamps the
level root; a restart reloads the scene, so the clock restarts). It is
NOT the run timer (that starts on the first input). The gate uses the
same clock. No `randf` anywhere in play; crumb shapes use a seeded
RandomNumberGenerator (looks only).

Proof: every drive prints, at clock 10.00 s, where each line's first
visible worker is. Two runs of the main drive printed identical lines
(`SingleLine worker 0 at (3.000, -30.000)`, `HighwayWith worker 0 at
(-98.000, -116.257)`, `GateLine worker 1 at (-110.057, -212.000)`, ...)
and finished in 1:04.09 and 1:04.11 (the bot's
own start is on a 0.5 s real-time timer, so the BALL can differ by a
physics step or two; the ants cannot).

## Section by section

| # | Section | What it is | Skill beat |
|---|---|---|---|
| 1 | Single line | 70 m straight, 9 m wide, walls. At 30 m a line of 7 workers walks out of a hole in a side tunnel on the left, across the corridor and into a tunnel on the right (1.5 m/s, 4.5 m apart: one every 3 s) | Watch it once, then go through a gap at full speed; the open part of each 3 s beat is about 1.2 s |
| 2 | Crossing lines | Bend left (r 20), 60 m straight along -X. Two lanes 4 m apart cross the corridor in opposite directions (1.8 m/s, 5 m apart, 2.8 s beat each). They come from a long side tunnel on the left and go into a short dead end on the right | Gaps in the two lanes only line up for a moment, and where they line up slides along the crossing (the lanes move opposite ways). At top speed you cross both in 0.45 s; at the corridor's middle the clean window is ~0.8 s of each 2.8 s |
| 3 | Crumb highway | Bend right (r 20), a 97 m straight, 10 m wide. Oncoming lane on the left (x -102, 2 m/s, 10 m apart), a lane going your way on the right (x -98, 1.4 m/s, 7 m apart); they come out of / go into side tunnels at both ends. Crumb piles block the channels in turn: middle (z -124), both sides (-142), middle (-160), both sides (-178) | Four forced lane crossings. Crossing the oncoming lane at full speed down the highway needs a near-sideways dash through a ~1 s window; slowing first makes it easy |
| 4 | Storage gate | 27 m approach, then a wall across with a 4 m doorway and a packed-dirt door that slides into the right wall: 4 s cycle, fully open 1.8 s, 0.5 s slides, lamps over it flicker for the second before it opens. A line of workers (2 m/s, spaced to the gate: exactly one per opening) comes out of a tunnel on the left and files through the left side of the doorway in the middle of every open window. The 22 m wide storage chamber behind has the goal (ant hill, base radius 5) | Arrive as the lamps flicker, go through the right half beside the worker. Hitting the shut door stops you dead; getting caught as it closes shoves you sideways |

## Hidden crystals

- **Hidden 0, the glinting worker.** In the highway's "your way" lane,
  worker 0 carries a small blue sugar crystal on its crumb with a light
  and a twinkle. Bump it and the crystal drops onto the lane 1.6 m behind
  it (always clear floor, never in a pile) as a normal HiddenCrystal; roll
  through it before the next worker (7 m back, ~5 s) walks over you. The
  drop happens once per run. If you already own it the carried crystal is
  faded and unlit and the drop is a ghost. Its lane loops in 85 s, of
  which ~60 s it is on the highway, so it is there most of the time.
- **Hidden 1, the workers' tunnel.** Section 2's lanes come out of a long
  side tunnel (9.5 m wide, ceiling 3.2 m) on the left. It runs 12 m
  straight, bends right (r 8) out of sight and ends after 10 m at a wall
  with the two worker holes; the crystal floats between them, lit by
  blue-white fungus. Roll up the middle between the two lanes (2 m of
  clear floor each side of you) and come back the same way, crossing
  lane B on the way out. A speedrunner never looks left into it.

## Layout <-> physics (the current tuning)

| Measurement | Depends on | Why |
|---|---|---|
| Corridors 9 m, highway 10 m, chamber 22 m | ball radius 0.5, worker hit box 0.96 x 1.36 m | Room to swerve around a worker: a lane occupies ~2.2 m of the floor for the ball's center |
| Bends radius 20 m | `roll_acceleration`, `turn_assist`, `max_speed` | Tightest turn at top speed is 12.1 m (v^2/7.9); bends are not the challenge here |
| Single line 1.5 m/s, 4.5 m apart | `max_speed` 9.775 | Ball crosses the 2 m danger strip in 0.22 s at top speed; the gap is open ~1.2 s of each 3 s, so you must time it but can do it flat out |
| Crossing lanes 4 m apart, 1.8 m/s, 5 m apart | `max_speed` | 0.45 s at top speed from one lane to the next; with the lanes moving opposite ways the double-gap appears at a different point across the corridor every beat |
| Oncoming lane 2 m/s, 10 m apart (free gap 7.6 m) | `max_speed`, `roll_acceleration` | Rolling at 6-8 m/s the oncoming gap passes you in ~1 s; a 2.2 m sideways dash at the ~7 m/s/s you can push takes 0.6-0.8 s. Tighter spacing made crossing impossible at speed |
| Crumb piles 3 m long, every 18 m | `brake_multiplier` 1.2525 | 18 m gives time to see the pile, pick a side and brake for a gap (braking from 9.8 to 6 m/s takes ~3 m) |
| Worker knock 6 m/s straight out, +1.4 m/s up, 40% of sideways speed kept, 0.5 s grace | `worker_knock_*`, `worker_bump_grace` (new) | Firm: you lose your momentum and land ~2-3 m back. Fair: never off the course (walls everywhere), one bump per touch. The ball's own impact check sees the velocity change and plays the big-impact shake |
| Gate 4 s cycle, fully open 1.8 s, slides 0.5 s, door 4 m, worker in its left 1 m | `storage_gate_*` (new), ball radius | The ball fits in the right 2.5 m once the door is ~90% open: about 1.9 s of each 4 s |
| Gate line spacing = speed x gate period (8 m) | `worker_rush_gate_speed`, `storage_gate_period` | Keeps one worker in the doorway at mid-opening whatever the two are tuned to |
| Walls 3 m, tunnel ceilings 3.2 m | `jump_height` 1.59 | Cannot hop out; ants never seen from outside |
| Fungus every 12 m (main), 9 m (tunnels) | `camera_distance` 2.14 | Close camera: the next line has to be lit before you reach it |
| Every floor at y = 4 | `fall_respawn_y` -2.5 | No open edges anywhere; FallZone at y = -1 anyway |
| Short and long neighbouring track segments within 2x of each other | DirtTrack's Catmull-Rom curve | A 1 m segment next to 6 m ones folded the floor under the gate and popped the ball 2.7 m/s up; the generator now splits segments (`densify`) |

## New pieces (src/objects/nest/)

- `worker_line.gd` (`WorkerLine`): a looping line of CaveAnt workers
  (`body_scale` 2.8: about 1.4 m long) each carrying a chunky crumb, along
  `points`, with `speed`/`spacing` (or `speed_key`/`spacing_key` naming
  physics-config values, so F1 tunes each line live), `offset`,
  `hidden_length` (time spent "inside the wall"; the loop is rounded up to
  a whole number of spacings so gaps never change), dark holes at both
  ends, a bump Area3D per worker, `crystal_carrier`/`crystal_which`, and
  `sync_gate`/`sync_distance` to march in step with a StorageGate.
- `storage_gate.gd` (`StorageGate`): a sliding packed-dirt door
  (AnimatableBody3D, solid when shut) on the level clock, with a lintel
  and two warning lamps.
- `crumb_pile.gd` (`CrumbPile`): a box collider under a heap of pale
  crumbs; merged into the level's static body.

New physics-config values (section `LEVEL 4: WORKER RUSH`):
`worker_knock_speed` 6, `worker_knock_lift` 1.4, `worker_knock_keep` 0.4,
`worker_bump_grace` 0.5, per-line `worker_rush_single_speed/spacing`
(1.5 / 4.5), `worker_rush_cross_a_speed/spacing` (1.8 / 5),
`worker_rush_cross_b_speed/spacing` (1.8 / 5),
`worker_rush_highway_on_speed/spacing` (2 / 10),
`worker_rush_highway_with_speed/spacing` (1.4 / 7),
`worker_rush_gate_speed` 2, `storage_gate_period` 4,
`storage_gate_open_fraction` 0.45, `storage_gate_slide_time` 0.5.

## Bot drives

- `tests/levels/level_4_worker_rush.json`: main route, zero bumps, 1:04.1.
- `level_4_worker_rush_carrier.json`: main route, then in the highway's
  right channel it bumps the glinting worker from the side and rolls over
  the dropped crystal (expects hidden 0); 1:04.9, one bump (the carrier).
- `level_4_worker_rush_tunnel.json`: detours up the workers' tunnel for
  hidden 1 (expects hidden 1); 1:20.6, zero bumps.

They were timed by running the drive with bumps switched off, comparing
the ball's track with the (deterministic) worker positions, and slowing
the bot on a "hold" stretch before each crossing so it reaches the gap in
the middle of its window. Because the ants are deterministic the drives
keep passing; if a line's speed, spacing or offset changes, the drives
need re-timing (each crossing's window is 0.3-1 s).

## Acceptance (test by playing)

- Section 1: the line crosses in an even beat; rolling flat out without
  looking you get bumped about half the time; watching one beat, you get
  through every time.
- A bump throws you back 2-3 m with a dust puff, a shake and a plip; you
  are never pushed off the course and never bumped twice by one touch.
- Restart (R) at any moment: the ants are back where they were at the
  start of the previous attempt (same positions at the same time after
  load).
- Section 2: the two lanes walk opposite ways; there is a moment in each
  beat when you can cross both at speed.
- Highway: four piles force four lane changes; the oncoming lane can be
  crossed without a bump if you pick a gap and move sideways, not
  diagonally.
- The glinting worker is visible in the right lane; bumping it drops a
  crystal on the lane behind it that you can pick up; it only drops once.
- Gate: the lamps flicker just before it opens; a worker goes through
  every opening; the shut door is solid.
- Hidden 1 is out of sight from the main route and reachable by rolling
  up the middle of the workers' tunnel.
- Clean fast run under 1:15 needs reading every rhythm.

## Known issues

- Workers have no body: the ball passes through their legs visually for
  the instant before the knock. They also walk through each other's
  dropped crystal and through the fungus.
- A worker pops into / out of view at the holes if you look straight
  into the hole from inside the side tunnel (the last 1 m of its path is
  inside the wall).
- Being caught by the closing gate shoves the ball sideways along the
  door (physics push), not back; harmless but abrupt.
- The F1 panel can change a line's spacing live; the line then rebuilds
  (workers jump to their new places).
- The bot drives depend on the exact worker timings and the gate period.

## Questions for the owner

1. Bump strength: (a) 6 m/s as now, (b) softer 4 m/s (only stops you),
   (c) harder 9 m/s (sends you well back).
2. The big-impact shake/freeze on a worker bump (from the ball's own
   impact check): (a) keep, (b) only dust and the plip.
3. Hidden 0 carrier: (a) highway lane going your way (now), (b) the
   section 1 single line (easier to spot), (c) the gate line.
4. Highway oncoming spacing: (a) 10 m (now), (b) 8 m (busier, harder),
   (c) 12 m.
5. Gate rhythm: (a) 4 s, open 45% (now), (b) 3 s, open 40% (tighter),
   (c) 5 s, open 50%.
6. Target time: (a) 1:15, (b) 1:10, (c) 1:25.
