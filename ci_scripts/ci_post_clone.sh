#!/bin/sh
# Xcode Cloud: the .xcodeproj is generated, not committed (see project.yml).
set -e
export HOMEBREW_NO_AUTO_UPDATE=1
brew install xcodegen
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate
# Xcode Cloud requires a committed Package.resolved (automatic resolution
# is disabled on CI) — place ours inside the freshly generated project.
mkdir -p Noor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
cp ci_scripts/Package.resolved Noor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
