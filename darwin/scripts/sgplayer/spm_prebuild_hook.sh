#!/usr/bin/env bash
#
# Pre-build hook for SPM / Xcode / Flutter (iOS or macOS artifact).
# Regenerates the unified sharedDarwinSource Package.swift, then ensures the
# requested platform's SGPlayer.xcframework (CocoaPods / local fallback).
#
# Usage:
#   bash darwin/scripts/sgplayer/spm_prebuild_hook.sh ios|macos

set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "${SCRIPT_DIR}/_common.sh"
kinetic_sgplayer_init "${1:-}"

sgplayer_log "Syncing unified Package.swift from manifests..."
bash "${SCRIPT_DIR}/generate_package_swift.sh"

sgplayer_log "Ensuring SGPlayer.xcframework (CocoaPods / local fallback)..."
bash "${SCRIPT_DIR}/ensure_sgplayer.sh" "${KINETIC_SGPLAYER_PLATFORM}"

sgplayer_log "Done."
