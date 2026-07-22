#!/usr/bin/env bash
#
# Ensure darwin/Frameworks/{ios|macos}/SGPlayer.xcframework exists, and sync a
# package-local link for Flutter SPM (see sync_spm_local_xcframework).
# Order: use existing -> download prebuilt -> build from source.
#
# Usage:
#   bash darwin/scripts/sgplayer/ensure_sgplayer.sh ios|macos

set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "${SCRIPT_DIR}/_common.sh"

PLATFORM_ARG="${1:-}"
shift || true
kinetic_sgplayer_init "${PLATFORM_ARG}"

if [[ -d "${XCFRAMEWORK_OUTPUT}" ]]; then
  sgplayer_log "Using existing ${XCFRAMEWORK_OUTPUT}"
  sync_spm_package_inputs
  exit 0
fi

if bash "${SCRIPT_DIR}/download_sgplayer.sh" "${KINETIC_SGPLAYER_PLATFORM}"; then
  sync_spm_package_inputs
  exit 0
fi

sgplayer_log "Prebuilt download unavailable; building from source..."
bash "${SCRIPT_DIR}/build_sgplayer.sh" "${KINETIC_SGPLAYER_PLATFORM}" "$@"
sync_spm_package_inputs
