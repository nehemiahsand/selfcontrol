#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -d SelfControl.xcworkspace ]]; then
    echo "Install the Podfile dependencies first to create SelfControl.xcworkspace." >&2
    exit 1
fi
mkdir -p build
xcodebuild -workspace SelfControl.xcworkspace -scheme SelfControl \
    -configuration Debug -derivedDataPath "$PWD/build/DerivedData" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    MACOSX_DEPLOYMENT_TARGET=12.0 ONLY_ACTIVE_ARCH=YES \
    ENABLE_USER_SCRIPT_SANDBOXING=NO GCC_PRECOMPILE_PREFIX_HEADER=NO build \
    > build/xcode-build.log 2>&1
echo "Build succeeded: $PWD/build/DerivedData/Build/Products/Debug/SelfControl.app"
echo "Helper signing must be configured before this build can start a protected block."
