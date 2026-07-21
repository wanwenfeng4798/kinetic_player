#!/usr/bin/env bash
#
# Pre-build hook for SPM / Xcode / Flutter iOS builds.
#
# 1. Sync Package.swift remote binaryTarget from sgplayer_binary_manifest.json
# 2. Ensure ios/Frameworks/SGPlayer.xcframework exists (download → local build)
#    so CocoaPods vendored_frameworks and offline workflows keep working.
#
# Usage:
#   bash ios/scripts/spm_prebuild_hook.sh
#   # or from an app ios/ directory (example PreAction):
#   bash "$SRCROOT/../../ios/scripts/spm_prebuild_hook.sh"
#
# Host apps (pub dependency) can use:
#   bash "$(dirname "$0")/run_from_app.sh"
# or resolve the plugin path via .flutter-plugins-dependencies (see docs).

set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() {
  printf '[spm_prebuild_hook] %s\n' "$*"
}

log "Syncing Package.swift from manifest..."
bash "${SCRIPT_DIR}/generate_package_swift.sh"

log "Ensuring SGPlayer.xcframework (CocoaPods / local fallback)..."
bash "${SCRIPT_DIR}/ensure_sgplayer.sh"

log "Done."
