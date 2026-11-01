# Level 3 -- Fungus Farm (design notes)

Teaches: **jumping**. An underground fungus garden: raised beds of damp,
tilled soil with glowing green buttons along their lips, soft glowing
bounce mushrooms, pale slick spore floors and spores drifting in the air.
The course runs straight toward -Z for about 230 m and ends by climbing a
spiral of mushrooms to a high ledge with the ant hill. The scene is
GENERATED: `python3 tools/make_fungus_farm.py` (run from `ballants-game/`)
rewrites `level_3_fungus_farm.tscn` and the three bot drive files from the
numbers at the top of the script. Change a gap or a height there and run
it again rather than moving nodes by hand.

Target time: recommend **1:10 (70 s)**. The bot's clean run is 0:49, its
tall-mushroom shortcut run 1:02 (slower: the launcher is off to the side
and the bot settles on the ledge), its spore-spur run 1:12. A fast
human should need about 0:58-1:05; a careful first-timer 3-4 minutes
(furrow misses, pit falls and tower falls each cost 5-15 s, the section 3
gaps restart the level). Beating 1:10 needs clean jumps (no furrow
climbs, first-try pit and tower bounces), not the shortcut.

Every floor is at y = 8 or higher (the plaza 13.5, the exit 31); a
FallZone at y = -1 catches anything that leaves the course.

## Section by section

| # | Section | What it is | Skill beat |
|---|---|---|---|
| 1 | Small hops | A 22 m starting bed, then five 9 m beds separated by furrows 3, 3.5, 4, 4.5 and 5 m wide, 10 m wide, walled both sides. The furrows are 1.2 m deep with a floor: miss and you jump back out | Press jump at the lip. Any speed from ~4 m/s clears 3 m; 5 m wants ~6 m/s |
| 2a | Bounce patch | The last bed (20 m) ends at a 4 m-high ledge face; three glowing caps set into the floor across its foot (radius 1.5) | Roll onto a cap and it throws you up onto the ledge. Too slow (under ~2 m/s) and you clip the lip; anything else works |
| 2b | Stepping mushrooms | An 18 m ledge, then a 21 m pit with three mushrooms on stems, caps level with the ledges (radius 1.6), zig-zagging 2.6 m and 3.4 m sideways, 7.5-7.7 m apart, the far ledge 5.4 m past the last. The pit has a floor (y 8) and two floor caps near the first ledge that throw you back up onto it | Aim by speed: every bounce lasts ~2 s, so you cover 2 m per 1 m/s. Arrive at ~3.5 m/s and steer gently toward the next cap in the air |
| 3 | Spore floors | Four beds over the void. (a) 20 m dirt + 6 m spores, then a 6 m gap to a bed 0.5 m higher; (b) 7 m dirt + 7 m spores, a 4 m gap onto (c) an 8 m island; a 4.5 m gap rising 1.0 m onto (d) 12 m dirt + 8 m spores (walled), then a 6.5 m gap onto the tower plaza | On spores you can neither speed up nor brake much: set your speed on the dirt. (a) and (d) want top speed going in; (b) wants ~5.5 m/s or you overshoot the island |
| 4 | Mushroom tower | A 34 x 28 m walled plaza. A floor cap, then three more caps in a left-turning spiral, each 4.5 m higher and 4.2 m on (turning 40 degrees per step), and a 14 x 14 m exit ledge 17.5 m above the plaza (3.9 m above the last cap) with the ant hill | Bounce, steer in the air to the next cap, repeat. A miss drops you to the plaza, not the void |

## Hidden crystals

- **Tall mushroom (hidden 0, shortcut/explore).** Beside the tower's
  third cap stands a tall solid amber mushroom (cap 10.7 m up, radius
  1.8); the crystal sits on its cap. At its foot, 3.4 m east, a blue-white
  launcher cap (uses `mushroom_tall_bounce_height`, 12.5 m) throws you
  onto it. From its cap you roll off west onto the third tower cap (0.3 m
  gap, 1.6 m drop) and carry on: it skips the first two tower bounces.
  It is not faster for the bot (the launcher is off the line and you must
  stop on the ledge), so the target time does not need it.
- **Spore spur (hidden 1, off the fast route).** On the long spore run
  (section 3d) the right wall has a 4 m opening. Behind it a 14 m spur
  runs off to the right, spore-covered for its first 10 m, with 3.5 m of
  dirt and then an open edge at its end. The crystal is round the corner
  in a walled nook to the right of the spur's end. Roll in fast and you
  slide straight off the end; roll in at walking pace (under ~3 m/s) and
  you can turn into the nook. Afterwards back up to the landing edge for a
  run-up: the 6.5 m jump needs near top speed. A speedrunner passing at 9 m/s
  sees an opening, not the crystal (the nook walls are 3.5 m tall).

## New pieces (src/objects/nest/)

- `bounce_mushroom.gd` (`BounceMushroom`): a glowing cap on a stem. Cap
  top at `cap_height` above the node (the stem's foot); `cap_radius`,
  `stem_radius`, `bouncy` (off = a solid mushroom ledge or decoration),
  `height_value` (which physics config value sets the bounce height) and
  `height_scale`, colors, light, `seed`. Collision: a flat cylinder for
  the cap and one for the stem; the trigger is an Area3D from the cap top
  to 1.25 m above it, so a fast fall is caught before the ball hits the
  cap. Launch: the ball's peak is always cap top + 0.5 + bounce height
  (vertical speed from the damped-climb formula, see below), its sideways
  speed is kept, `allow_launch()` is called; the cap squashes and springs
  back. A ball moving up through the trigger is ignored.
- `spore_patch.gd` (`SporePatch`, extends SlickPatch): grip from
  `Tuning.spore_grip`; looks: a pale powdery floor 2 cm above the
  surface, lighter blotches, puffball nubs along the long edges, a pale
  light and a SporeCloud.
- `spore_cloud.gd` (`SporeCloud`, a GPUParticles3D): pale glowing spores
  drifting up through a box; fixed seed. Decoration only.
- `dirt_bed.gd` (`DirtBed`): a raised bed; origin at the center of its
  TOP; one box collider of `size`; damp dark top, furrow stripes, a
  lighter lip band and small glowing green buttons along the edges.

## New tunables (physics config, section "LEVEL 3: FUNGUS FARM")

| Value | Now | What |
|---|---|---|
| `mushroom_bounce_height` | 6.5 | m the ball rises above a bounce cap |
| `mushroom_tall_bounce_height` | 12.5 | the blue launcher by the tower |
| `spore_grip` | 0.3 | grip on spore floors (friction and push multiplier) |

## Layout <-> physics (the owner's current tuning)

| Measurement | Depends on | Why |
|---|---|---|
| Furrows 3-5 m, 1.2 m deep | `jump_height` 1.59, `gravity` 12.27, `max_speed` | A flat jump covers ~1.02 x v m (airtime 1.02 s): 3 m needs ~3.5 m/s, 5 m ~6 m/s (the bot does all at 6.7 m/s). The ball's bottom rises to 1.59 m, so a 1.2 m furrow wall can be jumped out of |
| Bounce patch 2.6 m before a 4 m ledge | `mushroom_bounce_height` 6.5 | The ball rises to 7 m above the floor and needs ~0.35 s to pass 4.5 m; it clears the lip at any speed from ~2 to ~11 m/s |
| Pit caps 7.5-7.7 m apart, level | `mushroom_bounce_height`, `gravity`, `air_control` 0.2475 | A level cap-to-cap bounce lasts 2 sqrt(2h/g) = 2.06 s, so the distance is ~2 x speed; 3.5-4 m/s fits. In the air you can change speed by 2.5 m/s^2 x 2 s = 5 m/s, so a wrong approach speed can be fixed |
| Tower: caps 4.5 m higher, 4.2 m apart | `mushroom_bounce_height` (must stay above ~5.5) | Up 6.5, down 2.0 m: 1.6 s in the air, so ~2.6-3.4 m/s sideways (landing on the near edge of a cap launches you from there). Above 6.5 the caps get easier; below ~5.5 you cannot reach the next cap |
| Exit ledge 3.9 m above the last cap | `mushroom_bounce_height` | Peak is 6.5 + 0.5 above that cap, so you land from ~3 m above the ledge. The third cap's peak (29.6) is below the ledge (31), so you cannot skip the last cap |
| Tall mushroom 10.7 m, launcher 12.5 m, 3.4 m apart | `mushroom_tall_bounce_height` | Peak 26.6 vs ledge 24.2 (+0.5): ~2 s in the air, 3.4-5 m to cover. If lowered below ~11 the ledge is out of reach |
| Spore floors 6, 7, 8 m before the gaps | `spore_grip` 0.3, `rolling_resistance` 0.3975 | Pushing on spores at top speed loses ~0.17 m/s per meter (9.1 -> 7.9 m/s over 7 m); at ~5 m/s it holds its speed. Braking and steering are cut to 30% |
| Gap (a) 6 m, +0.5 m | `jump_height`, spore floor before it | Landing 0.5 m higher shortens the jump to ~0.9 x v: needs ~7.5 m/s at the lip; 20 m of dirt then 6 m of spores gives ~8.5 |
| Gap (b) 4 m onto an 8 m island | `brake_multiplier`, spore floor | At 5.5 m/s you land ~1 m into the island; at top speed ~5 m in, with 3 m to jump again or fall off the end |
| Gap (c) 4.5 m rising 1.0 m | `jump_height`, `ball_bounce` 0.55 | A +1 m landing is reached after 0.82 s: needs ~6.7 m/s. The island landing bounces (0.55), so the jump must wait for the ball to settle: the island is 8 m, not 6 |
| Gap (d) 6.5 m | `spore_grip`, `max_speed` | Needs ~7.2 m/s at the lip after 8 m of spores: reach top speed on the 12 m of dirt before them (a 7 m gap after 10 m of spores was too tight: ~7.7 m/s at the lip) |
| Spur: 10 m spores, 3.5 m dirt, open end | `spore_grip`, `brake_multiplier` | Braking on dirt from 6 m/s takes ~2.5 m; at 3 m/s ~0.7 m. Come in slowly |
| Bounce launch speed | project `physics/3d/default_linear_damp` 0.1 | Plain sqrt(2 g h) peaked ~10% low (the engine's air damping); `BounceMushroom.launch_speed_for()` solves the damped climb instead, so the peak matches the tunable to ~0.3 m |
| Trigger 1.25 m tall above each cap | `gravity` | A ball falling 14 m/s moves 0.23 m per physics step; a short trigger let it touch the cap rim first and lose its sideways speed |
| Every floor above y = 8 | `fall_respawn_y` -2.5 | |
| Fungus every ~11 m, lamps at every lip and landing | `camera_distance` 2.14 | The camera is close; lips must be lit. The beds' glowing edge buttons outline every jump |
| Section 1-2 walls 4.5 m, section 3d walls 2.5 m | `jump_height` | The ball cannot hop over a wall |

If any of those tuning values change, re-run `./run_tests.sh`: the three
drive files prove the main route (`level_3_fungus_farm.json`), the tall
mushroom (`_shortcut`, expects hidden 0) and the spore spur (`_crystals`,
expects hidden 1).

## Acceptance criteria (test by playing)

- The level loads as "Fungus Farm"; you start facing a long lit bed with
  a furrow ahead and giant purple mushrooms beside the course.
- Each of the five furrows can be cleared with a jump at the lip at a
  moderate speed; dropping into one, you can jump straight back out.
- Rolling onto any of the three green caps at the first ledge throws you
  up onto it, with a squash of the cap and a soft bump.
- On the stepping mushrooms, arriving slowly (~3-4 m/s) and steering
  toward the next cap lands you on it; arriving at full speed overshoots.
  Falling into the pit, rolling back onto a floor cap returns you to the
  first ledge.
- The pale spore floors visibly differ from dirt (pale, powdery, drifting
  spores) and feel slick: you cannot brake or turn sharply on them.
- Section 3: entering spore floor (a) and (d) at top speed makes the
  jump; entering (b) at top speed overshoots the island unless you jump
  again at once; the 1 m rise onto the long bed needs a running jump
  from the island.
- The tower: from the floor cap, each bounce reaches above the next cap;
  steering in the air lands you on it; the last throws you onto the exit
  ledge. Missing drops you to the plaza (no restart).
- Hidden 0: the blue cap by the tall amber mushroom throws you onto its
  cap; the crystal is there; rolling off west lands on the third tower
  cap and the climb continues.
- Hidden 1: entering the right-hand opening on the long spore run
  slowly lets you turn into the nook and take the crystal; entering
  fast slides you off the spur's end.
- The run is the same every time (no random play elements).

## Known issues

- The F1 panel's section regex (`^# -+ ([A-Z /()]+) -+$`) does not match
  the heading the brief prescribes ("LEVEL 3: FUNGUS FARM" has a digit
  and a colon), so the three new sliders appear at the end of the
  "Interactive Objects" group. They work; only the grouping is off. Fixing
  it means touching the panel plumbing (shared by all five builders).
- The bot reports "pops" for every mushroom bounce and for its own jumps
  (it releases jump before its pop watcher sees it). Harmless: pops do
  not fail a drive.
- A ball landing on the very rim of a cap (center just outside it) is
  bounced up but loses or reverses its sideways speed. Reads as "you just
  missed"; it usually lands back on the same cap.
- The level is on the short side of the brief's 60-90 s fast run (bot
  0:49). See question 1.

## Questions for the owner

1. Length: the bot runs it in 0:49, a fast human ~1:00. Should it be
   longer? (a) fine as is; (b) add two more hops to section 1 and a third
   bounce challenge (a sideways bounce onto a side ledge) to section 2;
   (c) add a fifth tower cap.
2. Mushroom bounce height (now 6.5 m above the cap): (a) keep; (b) higher
   and floatier (7.5, longer airtime, easier aiming); (c) lower and
   snappier (5.8, the tower gets tight).
3. Section 1 furrows have floors (miss = jump out, lose ~3 s). Should
   they be (a) kept forgiving; (b) real gaps into the void like section 3;
   (c) forgiving for the first three, void for the last two?
4. Spore grip 0.3: (a) keep; (b) slicker (0.2: almost no steering); (c)
   grippier (0.45).
5. The pit under the stepping mushrooms has a floor and a way back. (a)
   keep; (b) make it the void (a miss restarts the level).
6. Can a mushroom bounce be boosted by pressing jump as you land (a
   "super bounce")? (a) no, as now (the cap blocks the coyote jump so a
   jump pressed on it cannot shrink the bounce either); (b) yes, jump on
   landing adds the jump height.
7. The spore spur's crystal: (a) as is; (b) harder (shorter dirt at the
   end); (c) easier (a low wall at the spur's end so you cannot slide off).
