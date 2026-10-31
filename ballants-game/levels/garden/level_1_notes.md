# Level 1 -- Sidewalk Crack (design notes)

Teaches: **speed and steering**. The whole course is a raised sidewalk
(top at y = 3) running through a lawn, with a crack down the middle to
follow. Grass walls fence the early sections; later the edges are open
and only a painted curb line marks them. Falling off drops the ball
through the visual-only lawn into the FallZone (the run restarts).
It ends with a downhill slope onto a fenced goal plateau at y = 0.

Target time: 30-45 s for a first-time player (par 45 s in the level
list). The waypoint bot at 6-9 m/s finishes in about 29 s. The path is
about 212 m long: at a steady 8 m/s that is 27 s, so a player who brakes
for the open curves and bumps a wall or two lands in the 35-60 s range.

The scene is generated from a cursor-walk script (straight / curve /
downhill steps); every node's numbers below come from that walk, so the
seams meet by construction. Course runs from the start toward -Z.

## Section by section

| # | Section | What it is | Skill beat |
|---|---|---|---|
| S1 | Straight start | 48 m straight, 12 m wide, grass walls both sides, back wall behind the start, crack down the middle, seams every 12 m | Hold forward, get to speed; walls make it impossible to fail |
| C1 | First bend | left 45 deg, centerline radius 24 m, 12 m wide, curved grass walls both sides, three tall flowers on the outside | Steer for the first time with a safety net; flowers show the bend from far away |
| S2 | Diagonal straight | 36 m, 12 m wide, walls both sides; two purple flowers mark where the walls stop | Build speed again; the "gate" says the open part starts |
| C2 | Open right-hander | right 90 deg, radius 20 m, 12 m wide, NO walls, curb lines on both edges, four tall flowers along the outside, pebbles on the lawn inside | The lesson: full speed into a curve sends you off; 12 m width forgives a late turn |
| S3 | Narrowing straight | 12 m at 12 m wide, then 14 m at 9 m wide, open edges, curb lines | Breathe, line up on the crack, notice the path narrowing |
| C3 | The small challenge | left 45 deg, radius 15 m, 9 m wide, open edges; flowers outside, a big dark pebble inside | Must slow down a little or steer early; at top speed the turn does not fit |
| S4 | Crest run | 8 m, 10 m wide, walls return | Safety returns; aim for the crest |
| D | Downhill | 20 m run, 3 m drop (8.5 deg, 20.2 m of slab), walls both sides | Speed builds by itself; keep straight |
| Goal | Plateau | 26 m x 14 m at y = 0, walls on three sides, goal ring 12 m in, flowers behind it | Roll through the ring; the end wall catches an overshoot |

Path length: 48 + 18.8 + 36 + 31.4 + 12 + 14 + 11.8 + 8 + 20 + 12 = 212 m
to the ring.

## Layout measurements and the tuning values they depend on

Physics: gravity 9.94, max_speed 14.2 m/s, roll_acceleration 10.48
(about 7.3 m/s^2 effective), brake_multiplier 1.25, turn_assist 0.72
(sideways push about 12.6 m/s^2, so minimum turn radius ~ v^2 / 12.6),
rolling_resistance 0.26, ball_bounce 0.47, fall_respawn_y -2.5, camera
distance 2.14 m. Ball radius 0.5 m.

| Measurement | Value | Depends on | Why |
|---|---|---|---|
| S1 length | 48 m | roll_acceleration (0 to 14 m/s takes ~14 m) | Long enough to reach top speed and feel it before the first bend |
| C1 radius | 24 m centerline (18 inner, 30 outer) | turn_assist: min radius at 14.2 m/s = 15.5 m | Makeable at full speed even hugging the inner edge; it is the "safe" bend |
| C2 radius | 20 m centerline (14 inner, 26 outer) | turn_assist (15.5 m at top speed), max_speed | Makeable at top speed only on the outer half; a player who does not steer goes straight off. Not steering early is the lesson |
| C2 width | 12 m | turn_assist, ball radius | The extra width is the forgiveness: a late turn still fits |
| C3 radius | 15 m centerline (10.5 inner, 19.5 outer) | turn_assist, max_speed, brake_multiplier | Below the 15.5 m top-speed radius: needs ~12 m/s or less (12^2/12.6 = 11.4 m). Braking 14 to 12 m/s takes about 0.2 s / 3 m, so a glance ahead is enough |
| C3 width | 9 m | ball radius, turn_assist | Narrow enough that the line matters, wide enough (9 ball widths) that a small wobble is fine |
| Grass wall base height | 1.0 m (1.2 m end wall) | ball radius 0.5, ball_bounce 0.47 | Taller than the ball's center so a fast glancing hit bounces back onto the path instead of popping over |
| Downhill | 20 m run, 3 m drop, 8.5 deg | gravity (g sin 8.5 deg = 1.47 m/s^2 adds ~3 m/s over the slope), ground_stick 0.37 | Gentle enough that the ball stays on the slab over the crest and does not launch at the bottom |
| Crest / plateau overlap | flat slab extends 0.5 m past the crest; slope extends 0.5 m under the plateau | ball radius | No lip facing the ball at either seam (the upper surface always wins) |
| Course height | 3 m above y = 0, lawn at y = -4 | fall_respawn_y -2.5 | The lawn is visual only; a ball that leaves the path passes -2.5 after a 6 m drop (about 1.1 s) and the run restarts. The FallZone (y = -8, 600 x 6 x 600) is the backstop |
| Goal plateau | 26 m long | brake_multiplier (stopping from 14 m/s ~ 11 m), ball_bounce | Room to stop after the ring; the end wall and bounce keep an overshoot on the plateau |
| Flower / pebble markers | 10-14 m stems outside every bend, 3-5 m pebbles | camera_distance 2.14 (little view ahead) | Tall pieces are visible above the walls and over the crest before the bend itself is |
| Bot waypoints | every 8 m, 9 m/s straights, 7 m/s C2, 6 m/s C3, 8 m/s downhill | same as above | tests/levels/level_1.json |

## Testing done

- `godot --headless -- --drive=tests/levels/level_1.json`: PASS, goal
  reached in about 0:29 with 0 falls.
- A scratch drive with a waypoint off the edge after S1 reported
  "1 falls" and the level restarted (FallZone / fall line confirmed).
- `./run_tests.sh`: all checks passed.
- Screenshots of every section from above and from the ball's eye (the
  camera follows the bot to each section end).

## Pieces added for this level (reusable, src/objects/garden/)

- `crack_line.gd/.tscn` -- CrackLine: visual-only painted line through a
  list of points, with seeded jaggedness (the crack), or straight (slab
  seams, curb lines). No collision, so it never bumps the ball.
- `curved_grass_wall.gd/.tscn` -- CurvedGrassWall: GrassWall segments
  along an arc, same center/start/sweep convention as CurvedTrack.
- `lawn.gd/.tscn` -- Lawn: visual-only turf sheet with seeded grass
  clumps for the ground far below a raised path.

## Could not do / left for later

- The sidewalk is flat (no banked curves): CurvedTrack supports banking
  but the brief wants the open curves to punish speed, so bank is 0.
- Curves are built from 6-degree block segments, so the inner edge has
  faint facets; smooth enough for low-poly but a true arc mesh would
  look nicer.
- No audio or particle cues at the "walls end" gate; the purple flowers
  do that job for now.
