#!/bin/sh
# Builds the game as stand-alone apps that run without Godot installed.
#
#   ./export.sh            both
#   ./export.sh mac        just the Mac app
#   ./export.sh windows    just the Windows .exe
#
# Results (not saved in git):
#   ../builds/mac/BallAnts.zip         unzip, then double-click BallAnts.app
#   ../builds/windows/BallAnts.exe     one file, double-click it
#
# Needs Godot's export templates for this Godot version (4.7.2), installed
# once: in the Godot editor, Editor > Manage Export Templates > Download.
#
# The Mac app is "ad-hoc" signed, not signed by an Apple developer account,
# so a Mac that DOWNLOADED it will say it can't check it for malware. The
# first time: right-click BallAnts.app > Open > Open. (A copy made over a
# USB stick or AirDrop between your own Macs usually opens normally.)
# Windows may show "Windows protected your PC": More info > Run anyway.

cd "$(dirname "$0")" || exit 1
which="${1:-all}"
failed=0

build() {
	name=$1
	path=$2
	mkdir -p "$(dirname "$path")"
	echo "=== Building $name -> $path"
	if godot --headless --export-release "$name" "$path" > /tmp/ballants_export.log 2>&1 && [ -e "$path" ]; then
		echo "    done ($(du -h "$path" | cut -f1))"
	else
		echo "    FAILED:"
		grep -E "ERROR|error" /tmp/ballants_export.log | head -20
		failed=1
	fi
}

if [ "$which" = "all" ] || [ "$which" = "mac" ]; then
	build "macOS" "../builds/mac/BallAnts.zip"
fi
if [ "$which" = "all" ] || [ "$which" = "windows" ]; then
	build "Windows" "../builds/windows/BallAnts.exe"
fi
exit $failed
