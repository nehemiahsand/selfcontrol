#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/selfcontrol-clock.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror \
    -framework Foundation -I Common/Utility \
    Common/Utility/SCBlockClock.m Common/Utility/SCProtectionStatus.m Common/Utility/SCSiteBundles.m SelfControlTests/SCBlockClockTests.m \
    -o "$test_dir/clock-tests"
"$test_dir/clock-tests"
xcrun clang -fobjc-arc -fblocks -DTESTING -Wno-deprecated-declarations \
    -framework Cocoa -I . -I Common -I Common/Utility -I Daemon -I "Block Management" \
    -include SelfControlTests/ClockTestPrefix.h \
    Common/Utility/SCBlockClock.m Common/Utility/SCProtectionStatus.m Common/Utility/SCSiteBundles.m Common/Utility/SCBlockUtilities.m Common/SCSettings.m \
    Common/SCErr.m Daemon/SCDaemonBlockMethods.m SelfControlTests/SCClockIntegrationTests.m \
    -o "$test_dir/integration-tests"
"$test_dir/integration-tests"
python3 SelfControlTests/check-safeguard-config.py
