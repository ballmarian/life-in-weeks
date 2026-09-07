#!/bin/bash
# Runs the LifeInWeeksCore test suite.
#
# On a machine with only the Command Line Tools installed, swift-testing's
# framework sits outside the default search path, and SwiftPM's generated test
# runner compiles `#if canImport(Testing)` to false — so plain `swift test`
# exits 0 having run nothing. Passing -F to *every* target (which only the
# command line can do, not Package.swift) fixes that. Harmless once Xcode is
# installed, where plain `swift test` works on its own.
set -euo pipefail
cd "$(dirname "$0")/.."

FRAMEWORKS="$(xcode-select -p)/Library/Developer/Frameworks"
if [ -d "$FRAMEWORKS/Testing.framework" ]; then
    exec swift test -Xswiftc -F -Xswiftc "$FRAMEWORKS" "$@"
else
    exec swift test "$@"
fi
