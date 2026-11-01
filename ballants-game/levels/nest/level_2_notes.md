# Level 2 -- Egg Chamber (design notes)

Teaches: **turning**. One big round nursery chamber (radius 48 m, floor at
y = 4, dome 38 m up) full of pale ant eggs. The course runs through it in
four sections: a winding lane fenced by rows of eggs, a skate bowl you
carve round, a spiral shelf up the chamber's outer wall, and a wall-less
bridge over the eggs to the egg mound in the middle, where the ant hill
is. The scene is GENERATED: `python3 tools/make_egg_chamber.py` (from
`ballants-game/`; add `--map` for a text top view) rewrites
`level_2_egg_chamber.tscn` and the three bot drive files. Change the
layout there, not in the scene.

Recommended target time **1:02** (62 s). The bot's clean run is 0:55
(54.8-54.9 s), the high-crystal run 0:55.0, the nook-crystal run 1:04.4;
a careful first-timer needs 3-4 minutes (the bowl, the narrow bridge and
a fall or two). Taking the bowl's round end slowly on its floor (5 m/s)
instead of carving it on the wall costs the bot 2 s (0:56.7), so a 1:02
target leaves room for human slack only if you carve; 1:05 is the
friendlier choice if the owner prefers (see questions).

Everything stays above y = 4. The chamber is closed (walls and dome), so
nothing can fall out; a FallZone at y = -1 is there anyway.

## Section by section

| # | Section | What it is | Skill beat |
|---|---|---|---|
| 1 | Egg rows | 88 m lane, 9.2 m between the egg rows (7.3 m clear), rows 1.85-2.1 m tall. West with a soft S (radius 16 m), a wide right-hand U-turn (radius 12 m), a left turn (radius 12 m) and a straight north into the bowl; the rows funnel in to the bowl's mouth over the last 9 m | Easy wide turns at full speed. Clip a row and the eggs squash and nudge you back out; you keep the speed you had along the row |
| 2 | The bowl | U-shaped skate bowl: 10 m wide floor, 14 m legs, a curved wall all round (quarter-pipe, radius 4.5 m, steepening to 85 degrees, rim 9 m up). An egg row splits the two legs and ends in a heap of eggs near the round end, so on the floor there is only a 1.2 m groove round the end | In up the west leg, carve round the round end ON the wall, out down the east leg. At full speed the ball rides 0.5-1.5 m up the wall and comes back down at speed; slowly you must squeeze round the groove next to the eggs |
| 3 | Spiral ramp | A 6.5 m shelf hugging the chamber's outer wall, clockwise 200 degrees (166 m), 10 m up (3.5 degrees average, 4 at most), a 2.4 m wall on the outside, the inside an open cliff to the floor; it widens to a 9 m ledge at the top. Reached from the bowl's east leg by a short egg lane (turns of 9 and 12 m) | A long sweeping climb at full speed; drift inward and you drop to the floor |
| 4 | Nursery bridge | 104 m, 3.8 m wide, no walls, 10 m above the eggs, sags 1.2 m mid-span. A right-hander off the ledge (radius 11 m), an S over the egg lane (radius 18 m), a left turn (radius 14 m) and onto the mound's flat top (radius 7 m); goal ant hill, base radius 5 | Carry speed through the turns with nothing to stop you sliding off |

## Hidden crystals

- **High on the bowl wall (hidden 0).** A crystal hangs 7.6 m up the
  round end's wall, straight ahead of the west leg, with blue fungus on
  the rim above it (you can see it glowing from the leg). Roll straight up
  the middle of the leg at full speed and keep holding forward: the ball
  climbs the wall to about 5.7 m and touches it. At 9.2 m/s it falls about
  0.3 m short. A jump at the wall's foot does not help (it throws the ball
  off the curve; measured lower). The ball falls back into the bowl and
  you carry on round, so the detour costs almost nothing (0:55.0 vs 0:54.9)
  if you are fast enough.
- **The corner nook (hidden 1).** At the last bend of the egg lane (the
  left turn into the bowl) the outside rows do not follow the curve: they
  run on square into a corner, leaving a pocket about 7 m deep outside the
  racing line. Three egg heaps screen it; the crystal sits behind them,
  2.1 m from each row. The fast line hugs the inside of the bend 9 m away
  and never sees it. Costs about 10 s.

## The bowl math (current physics)

- **Climbing.** A rolling ball's energy is 0.7 m v^2 (translation plus a
  solid sphere's spin), so on speed alone it climbs h = 0.7 v^2 / g =
  0.057 v^2: 4.8 m at 9.2 m/s, 5.4 m at 9.7 m/s. Holding forward while the
  ball is still on the lower, gentler part of the wall adds a little; the
  steep upper wall is "air" (`ground_normal_min` 0.5 = steeper than 60
  degrees) where only `air_control` 0.2475 of the push works. Measured
  (ball center above the bowl floor, straight up the west leg's middle):
  9.2 m/s -> 5.44 m, 9.7 m/s -> 5.72 m (bot), about 5.9 m holding forward
  all the way.
- **The crystal.** Its center is 7.62 m up and 0.6 m off the wall; the
  pickup sphere is 1.6 m plus the ball's 0.5 m = 2.1 m. So the ball's
  center must reach about 5.6 m: about 9.4 m/s at the foot of the wall,
  i.e. full speed (push cap 9.775). That is why the leg is 14 m (18 m of
  straight counting the lane's end): enough run-up to arrive at the cap.
- **Carving.** On a wall banked at angle a the ball can turn with
  7.9 + g tan(a) m/s^2 sideways (7.9 = the push's steering part, see level
  1; `ground_stick` cancels out: it pushes into the wall but its sideways
  part is matched by the extra wall force). Around the round end at 7.6 m
  from its center at 9.5 m/s the ball needs 11.9 m/s^2, i.e. an 18 degree
  bank, which the 4.5 m pipe has 0.3 m up the wall; the faster you go the
  higher it rides and the more the wall helps. On the flat the same turn
  would need radius 11.4 m, and the floor's own groove (radius about 4 m
  past the egg heap) allows only 5.6 m/s.

## Layout <-> physics (the owner's current tuning)

| Measurement | Depends on | Why |
|---|---|---|
| Lane bends: U-turn and last bend radius 12 m, S radius 16 m, 7.3 m clear | `roll_acceleration` 10.085, `turn_assist` 0.1, `max_speed` 9.775 | Tightest steady turn is v^2 / 7.9: 12.1 m at full speed, so the centerline is a full-speed line and the outside of the lane (up to radius 15.6 m) has room to spare. "Easy, wide turns" |
| Egg rows 1.85-2.1 m tall | `jump_height` 1.59 | A jump cannot clear a row, so the lane cannot be cut |
| Egg knock: out at 2.5 m/s + 0.15 x the speed you hit with, speed along the row kept | new `egg_knock_speed`, `egg_knock_bounce` (vs `ball_bounce` 0.55 for a dirt wall) | Soft: a head-on hit at 9 m/s comes back at 3.9 m/s (a dirt wall returns 5 m/s and rubs off the rest); a glancing hit keeps almost all its speed |
| Bowl wall: pipe radius 4.5 m to 85 degrees, rim 9 m | `gravity` 12.27, `ground_normal_min` 0.5, `air_control` 0.2475 | The crystal at 7.6 m needs ~9.4 m/s; the rim is high enough that nothing flies out (a 9.775 m/s ball tops out near 6 m) |
| Bowl wall foot starts 3 cm under the floor | seam smoothing, Jolt edge contacts | The wall meets the floor face to face, so the ball never catches an edge where they join; no seam pops were measured |
| Bowl floor groove next to the egg heap (1.2 m, line radius ~4 m) | same as the lane bends | Flat speed there is at most 5.6 m/s; on the wall at 7.6 m the same turn takes 9.5 m/s (see the bowl math). Measured: bot carving at 9.5 = 0:54.8, at 5 m/s = 0:56.7 |
| West leg 14 m + 4 m straight before it | `roll_acceleration`, `rolling_resistance` 0.3975 | A full-speed line through the last bend (radius 12 m fits 9.7 m/s) arrives at the cap; the bot measures 9.7 m/s at the wall. The crystal needs ~9.4 m/s |
| Hidden 0: center 7.62 m up, `pickup_radius` 1.6 | all of the above | See the bowl math; measured 9.7 m/s collects, 9.2 m/s misses |
| Spiral: 10 m rise over 166 m, 4 degrees at most | `gravity`, `rolling_resistance` | Uphill pull 0.714 x g x sin 4 = 0.6 m/s^2, far below the push: a full-speed climb with no braking or stalling |
| Spiral 6.5 m wide, open inside | turn radius | Centerline radius 43 m: no steering needed beyond the bend; the open edge only catches a drifting ball |
| Bridge 3.8 m wide, first turn radius 11 m, then 14-18 m | turn radius v^2 / 7.9 | 11 m needs 9.3 m/s or less (a hair under the cap), the rest are full-speed; 3.8 m wide leaves 1.4 m either side of the ball for error |
| Bridge 10 m above the eggs | `gravity`, `ball_bounce` | A fall is not a fail: you land on the nursery floor (or in the egg lane) and roll back to the spiral |
| Transfer turns radius 9 m and 12 m | turn radius | 8.4 m/s on the 9 m turn's centerline; the lane is wide enough to take it wider |
| Fungus every 11-12 m along the lane, rim, shelf (12 m) and bridge (9 m); 14 wall crystals | `camera_distance` 2.14 | The camera is close; lights mark the next turn and the edges |

If any of those tuning values change, re-run `./run_tests.sh`. The three
drive files (`tests/levels/level_2_egg_chamber*.json`) prove the main
route, the high crystal (`_crystals`, expects hidden 0) and the nook
(`_shortcut`, expects hidden 1). The high-crystal drive rolls straight up
the leg holding toward a point beyond the wall and moves on when the ball
is 7.17 m from it (the top of the climb); if the physics changes, measure
the new top of the climb and adjust `HIDDEN0_LOCAL` / `HIDDEN0_AIM` in the
generator.

## New pieces (src/objects/nest/)

- `nursery_chamber.gd` (`NurseryChamber`): a round room, flat floor,
  straight smooth lower wall (for shelves to hug), leaning upper wall and
  dome; one trimesh.
- `egg_bowl.gd` (`EggBowl`): the U-shaped skate bowl (no floor of its own;
  it stands on one). `surface_point(along, height)` and `foot_at(along)`
  place things on its wall.
- `egg_pile.gd` (`EggPile`): a heap (`length` 0) or a row of eggs
  (`length` > 0) with a solid core and the soft knock-back shell. Eggs are
  one MultiMesh per pile, each a slightly different cream.
- `egg_mound.gd` (`EggMound`): the flat-topped dirt column the goal sits on,
  heaped with eggs (looks only).

New tunables (physics config, LEVEL 2 section, F1 panel): `egg_knock_speed`
2.5, `egg_knock_bounce` 0.15, `egg_squash` 0.14.

## Acceptance criteria (test by playing)

- The level loads into a big round, lit egg chamber; from the start you
  look down a lane fenced by rows of pale eggs, with fungus along it.
- Roll the lane at full speed holding the middle: every bend fits without
  braking. Steer into a row: the eggs squash, there is a soft bump and you
  slide off along it without stopping dead. A row cannot be jumped.
- The lane narrows into the bowl's west leg. Carve the round end on the
  wall at speed: the ball rides up the wall, round, and down the east leg
  still fast. Brake and try it on the floor: it fits only slowly, right
  next to the egg heap.
- Roll straight up the west leg's middle at full speed into the round end,
  holding forward: you touch the glowing crystal under the blue fungus
  (hidden 0). At a little under full speed you fall just short.
- At the last bend before the bowl, look right (the outside corner): a
  pocket behind three egg heaps holds hidden 1.
- After the bowl a short egg lane leads to the foot of the spiral; the
  shelf climbs the outer wall all the way round to a ledge at the top,
  above where you started.
- The bridge leaves the ledge with a right-hander, swings over the egg
  lane and ends on the egg mound, where the ant hill is. Falling off it,
  or off the spiral's inner edge, drops you on the floor; you can always
  roll back to the spiral's foot.
- A clean fast run takes about a minute; both crystals award once.

## Known issues

- The bot's "pop" counter reports about 20 pops per run, all where the
  ball rolls onto the bowl's west wall (vertical speed 1.2-1.6 m/s). That
  is the ball following the curve (real geometry), not a seam; the counter
  assumes floors are flat. There are no pops anywhere else.
- On the bowl wall the ball counts as "in the air" whenever it is rising
  faster than 2 m/s (player_ball.gd's launch rule) and wherever the wall is
  steeper than 60 degrees, so steering up there is air control (25%).
  Carving works anyway (it is the wall doing the turning), but it feels
  looser than steering on the floor.
- The high-crystal drive depends on an exact distance (7.17 m) to let the
  bot hold forward to the top of the climb; any physics change means
  re-measuring it (see above). The crystal's own threshold is about
  9.4 m/s, so tuning `max_speed` below ~9.5 would make it unreachable.
- Headless runs vary by about 0.03 s from run to run (54.88 vs 54.91);
  nothing random is used, so this is the physics engine's own jitter.
- About 60 small lights (fungus, rim fungus, wall crystals); not yet
  checked on a slow machine.
- The egg rows look a little like continuous tubes from a distance.

## Questions for the owner

1. Falling off the bridge or the spiral:
   a) keep it: you land on the nursery floor and climb the spiral again (current);
   b) it fails the run and restarts the level;
   c) soften it: a pile of eggs catches you and a ramp leads straight back to the ledge.
2. Target time:
   a) 1:02 (the bowl carve is needed) (recommended);
   b) 1:05;
   c) 1:10.
3. The high crystal:
   a) full speed only, about 9.4 m/s (current);
   b) a bit easier, about 9.0 m/s;
   c) much easier: any fast run up the leg.
4. Egg knock-back strength (`egg_knock_speed`):
   a) 2.5 m/s, a soft nudge (current);
   b) 1.5 m/s, barely a nudge;
   c) 4 m/s, bouncy like a cushion.
5. The bowl's floor:
   a) keep the egg heap that leaves only a narrow groove, so carving the wall is clearly the fast way (current);
   b) remove the heap: the floor is open and carving is only slightly faster.
6. Falling off the bridge into the egg lane means doing the bowl and spiral again (~35 s):
   a) fine, it is the price of falling (current);
   b) route the bridge over open floor instead, so a fall only costs the spiral.
