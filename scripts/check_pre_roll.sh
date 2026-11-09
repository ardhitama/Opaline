#!/bin/bash
# Runs the pre-roll wait checks against the shipping parser source.
# Usage: ./scripts/check_pre_roll.sh
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
{
    echo "enum InnertubeClient {}"
    cat "$ROOT/Opaline/Core/API/InnertubeClient+PreRoll.swift" \
        "$ROOT/scripts/pre_roll_checks.swift"
} > "$TMP/main.swift"
swift "$TMP/main.swift"
rm -rf "$TMP"
