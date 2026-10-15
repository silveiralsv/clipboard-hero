#!/bin/bash
# Runs the tests. With only the Command Line Tools installed, SwiftPM does not find
# Swift Testing on its own, so point the compiler and linker at the framework.
set -euo pipefail
cd "$(dirname "$0")/.."

DEV="$(xcode-select -p)"
if [[ "$DEV" == *CommandLineTools ]]; then
    F="$DEV/Library/Developer/Frameworks"
    L="$DEV/Library/Developer/usr/lib"
    exec swift test -Xswiftc -F"$F" -Xlinker -F"$F" -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$L" "$@"
fi
exec swift test "$@"
