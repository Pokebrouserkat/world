#!/bin/bash
# Run GdUnit4 tests

GODOT=~/Library/Application\ Support/Steam/steamapps/common/Godot\ Engine/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a test/ --ignoreHeadlessMode "$@"
