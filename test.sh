#!/bin/bash
# Run GdUnit4 tests

GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a test/ --ignoreHeadlessMode "$@"
