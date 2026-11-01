#!/bin/sh
# Runs every automated check for Ballants and prints a summary.
#
#   ./run_tests.sh
#
# 1. Physics tests (tests/physics_tests.gd): small throwaway worlds that
#    check jump height, tunneling, seams, ramp crests, stacking, input lag.
# 2. Arena smoke test (--autotest): plays the test arena for a few seconds
#    and checks rolling, jumping, restart and the seesaw.
# 3. Level drives (tests/levels/*.json): a bot drives each level through
#    its waypoints and must reach the goal without falling out.
# 4. Hub tests (--hubtest=yes|no|skip): the anthill hub's arrival fall and
#    opening cutscene played by machine, each answer, the skip, locked and
#    open tunnels, small holes, and the return from a level.
#
# Exit code 0 = everything passed. Any FAIL line tells you what was
# measured and what was expected.

cd "$(dirname "$0")" || exit 1
failed=0

echo "=== Physics tests ==="
physics_output=$(godot --headless -- --tests 2>&1)
# (The "leaked at exit" lines are harmless noise from quitting a headless run.)
echo "$physics_output" | grep -E "^\[tests\]|ERROR" | grep -vE "leaked at exit|Pages in use"
echo "$physics_output" | grep -q "ALL PASSED" || failed=1

echo
echo "=== Arena smoke test ==="
arena_output=$(godot --headless -- --autotest 2>&1)
echo "$arena_output" | grep -E "^\[autotest\]|ERROR" | grep -vE "leaked at exit|Pages in use"
echo "$arena_output" | grep -q "ALL PASSED" || failed=1

echo
echo "=== Level drives ==="
for file in tests/levels/*.json; do
	[ -e "$file" ] || { echo "(no level drive files yet)"; break; }
	drive_output=$(godot --headless -- --drive="$(pwd)/$file" 2>&1)
	echo "$drive_output" | grep -E "^\[drive\]|ERROR|SCRIPT" | grep -vE "leaked at exit|Pages in use"
	echo "$drive_output" | grep -q "^\[drive\] PASS" || failed=1
done

echo
echo "=== Anthill hub (arrival, cutscene, tunnels) ==="
for mode in yes no skip; do
	hub_output=$(godot --headless -- --hubtest=$mode 2>&1)
	echo "$hub_output" | grep -E "^\[hubtest\]|SCRIPT ERROR" | grep -vE "leaked at exit|Pages in use"
	echo "$hub_output" | grep -q "^\[hubtest\] ALL PASSED" || failed=1
done

echo
if [ "$failed" -eq 0 ]; then
	echo "RESULT: all checks passed"
	exit 0
else
	echo "RESULT: something FAILED (see above)"
	exit 1
fi
