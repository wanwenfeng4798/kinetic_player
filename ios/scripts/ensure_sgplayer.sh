#!/usr/bin/env bash
#
# Ensure ios/Frameworks/SGPlayer.xcframework exists.
# Order: use existing -> download prebuilt -> build from source.
#
# Used by kinetic_player.podspec prepare_command and SPM workflows.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
XCFRAMEWORK_OUTPUT="${IOS_DIR}/Frameworks/SGPlayer.xcframework"

if [[ -d "${XCFRAMEWORK_OUTPUT}" ]]; then
  printf '[ensure_sgplayer] Using existing %s\n' "${XCFRAMEWORK_OUTPUT}"
  exit 0
fi

if bash "${SCRIPT_DIR}/download_sgplayer.sh"; then
  exit 0
fi

printf '[ensure_sgplayer] Prebuilt download unavailable; building from source...\n'
exec bash "${SCRIPT_DIR}/build_sgplayer.sh" "$@"
