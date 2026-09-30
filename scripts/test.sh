#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

xcodebuild test -scheme BookShelf \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:BookShelfTests -quiet
