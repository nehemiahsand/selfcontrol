#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/selfcontrol-slider.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
xcrun clang -fobjc-arc -fblocks -Wno-deprecated-declarations -framework Cocoa \
    -include Cocoa/Cocoa.h -I . -I Pods/FormatterKit SCDurationSlider.m SCTimeIntervalFormatter.m \
    Pods/FormatterKit/FormatterKit/TTTTimeIntervalFormatter.m \
    Pods/FormatterKit/FormatterKit/NSBundle+FormatterKit.m \
    SelfControlTests/SCDurationSliderTests.m -o "$test_dir/slider-tests"
"$test_dir/slider-tests"
