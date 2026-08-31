#!/bin/sh
# Xcode Cloud: the .xcodeproj is generated, not committed (see project.yml).
set -e
brew install xcodegen
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate
