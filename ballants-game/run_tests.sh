#!/bin/sh
# Runs every automated check for Ballants and prints a summary.
#
#   ./run_tests.sh
#
# 1. Physics tests (tests/physics_tests.gd): small throwaway worlds that
#    check jump height, tunneling, seams, ramp crests, stacking, input lag.
# 2. Arena smoke test (--autotest): plays the real test level for a few
#    seconds and checks rolling, jumping, restart and the seesaw.
#
# Exit code 0 = everything passed. Any FAIL line tells you what was
# measured and what was expected.

cd "$(dirname "$0")" || exit 1

echo "=== Physics tests ==="
physics_output=$(godot --headless -- --tests 2>&1)
# (The "leaked at exit" lines are harmless noise from quitting a headless run.)
echo "$physics_output" | grep -E "^\[tests\]|ERROR" | grep -vE "leaked at exit|Pages in use"

echo
echo "=== Arena smoke test ==="
arena_output=$(godot --headless -- --autotest 2>&1)
echo "$arena_output" | grep -E "^\[autotest\]|ERROR" | grep -vE "leaked at exit|Pages in use"

echo
if echo "$physics_output" | grep -q "ALL PASSED" && echo "$arena_output" | grep -q "ALL PASSED"; then
	echo "RESULT: all checks passed"
	exit 0
else
	echo "RESULT: something FAILED (see above)"
	exit 1
fi
