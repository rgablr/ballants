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
# 5. Easter egg (--eggtest): the mysterious key, the jail cell, the button
#    and the birthday party, played by machine.
# 6. Menus (--menutest): the main menu, the four save profiles (in a
#    throwaway folder), the progress screen, the pause menu.
#
# Exit code 0 = everything passed. Any FAIL line tells you what was
# measured and what was expected.

cd "$(dirname "$0")" || exit 1
failed=0

# Runs one headless Godot pass and keeps its output in $output. A test
# can print PASS and still have Godot crash afterwards (macOS then shows
# "Godot quit unexpectedly"), so an exit by a signal (code 128 and up,
# e.g. 134 = abort) counts as a failure too, even after a PASS.
run_godot() {
	label=$1
	shift
	output=$(godot --headless -- "$@" 2>&1)
	code=$?
	if [ "$code" -ge 128 ]; then
		echo "CRASH: Godot died with exit code $code (signal $((code - 128))) during: $label"
		failed=1
	fi
}

echo "=== Physics tests ==="
run_godot "physics tests" --tests
physics_output=$output
# (The "leaked at exit" lines are harmless noise from quitting a headless run.)
echo "$physics_output" | grep -E "^\[tests\]|ERROR" | grep -vE "leaked at exit|Pages in use"
echo "$physics_output" | grep -q "ALL PASSED" || failed=1

echo
echo "=== Arena smoke test ==="
run_godot "arena smoke test" --autotest
arena_output=$output
echo "$arena_output" | grep -E "^\[autotest\]|ERROR" | grep -vE "leaked at exit|Pages in use"
echo "$arena_output" | grep -q "ALL PASSED" || failed=1

echo
echo "=== Level drives ==="
for file in tests/levels/*.json; do
	[ -e "$file" ] || { echo "(no level drive files yet)"; break; }
	run_godot "drive $file" --drive="$(pwd)/$file"
	drive_output=$output
	echo "$drive_output" | grep -E "^\[drive\]|ERROR|SCRIPT" | grep -vE "leaked at exit|Pages in use"
	echo "$drive_output" | grep -q "^\[drive\] PASS" || failed=1
done

echo
echo "=== Anthill hub (arrival, cutscene, tunnels) ==="
for mode in yes no skip; do
	run_godot "hub test ($mode)" --hubtest=$mode
	hub_output=$output
	echo "$hub_output" | grep -E "^\[hubtest\]|SCRIPT ERROR" | grep -vE "leaked at exit|Pages in use"
	echo "$hub_output" | grep -q "^\[hubtest\] ALL PASSED" || failed=1
done

echo
echo "=== Birthday easter egg (key, cell, button, party) ==="
run_godot "easter egg test" --eggtest
egg_output=$output
echo "$egg_output" | grep -E "^\[eggtest\]|SCRIPT ERROR" | grep -vE "leaked at exit|Pages in use"
echo "$egg_output" | grep -q "^\[eggtest\] ALL PASSED" || failed=1

echo
echo "=== Menus and save profiles ==="
run_godot "menu test" --menutest
echo "$output" | grep -E "^\[menutest\]|SCRIPT ERROR" | grep -vE "leaked at exit|Pages in use"
echo "$output" | grep -q "^\[menutest\] ALL PASSED" || failed=1

echo
if [ "$failed" -eq 0 ]; then
	echo "RESULT: all checks passed"
	exit 0
else
	echo "RESULT: something FAILED (see above)"
	exit 1
fi
