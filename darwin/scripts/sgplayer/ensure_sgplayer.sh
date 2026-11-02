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

# Explicit local development source takes precedence over downloaded caches.
LOCAL_ROOT="${KINETIC_PLAYER_SGPLAYER_LOCAL_ROOT:-}"
if [[ -z "$LOCAL_ROOT" && -f "${DARWIN_DIR}/sgplayer/.local-root" ]]; then
  LOCAL_ROOT="$(cat "${DARWIN_DIR}/sgplayer/.local-root")"
fi
if [[ -n "$LOCAL_ROOT" ]]; then
  case "$KINETIC_SGPLAYER_PLATFORM" in
    ios) local_platform=iOS ;;
    macos) local_platform=macOS ;;
  esac
  local_artifact="$LOCAL_ROOT/build/Package-$local_platform/Artifacts/SGPlayer.xcframework"
  [[ -f "$local_artifact/Info.plist" ]] || sgplayer_fail "Local artifact missing: $local_artifact. Build SGPlayer locally first; remote download is disabled."
  rm -rf "$XCFRAMEWORK_OUTPUT" "$SPM_PACKAGE_DIR/Artifacts/$KINETIC_SGPLAYER_PLATFORM/SGPlayer.xcframework"
  mkdir -p "$OUTPUT_DIR"
  ditto "$local_artifact" "$XCFRAMEWORK_OUTPUT"
  resources="$SPM_PACKAGE_DIR/Sources/kinetic_player/Resources/SGPlayer"
  mkdir -p "$resources"
  ditto "$LOCAL_ROOT/SGPlayer/Resources/Fonts" "$resources/Fonts"
  ditto "$LOCAL_ROOT/licenses" "$resources/Licenses"
  rm -f "$SPM_PACKAGE_DIR/Artifacts/$KINETIC_SGPLAYER_PLATFORM/.sgplayer-version"
  read_manifest_field version > "$OUTPUT_DIR/.sgplayer-version"
  sgplayer_log "Using local SGPlayer artifact: $local_artifact"
  sync_spm_package_inputs
  sync_flutter_spm_wrapper_if_needed
  exit 0
fi

if sgplayer_artifact_is_current; then
  sgplayer_log "Using existing ${XCFRAMEWORK_OUTPUT}"
  sync_spm_package_inputs
  sync_flutter_spm_wrapper_if_needed
  exit 0
fi

if bash "${SCRIPT_DIR}/download_sgplayer.sh" "${KINETIC_SGPLAYER_PLATFORM}"; then
  sync_spm_package_inputs
  sync_flutter_spm_wrapper_if_needed
  exit 0
fi

if [[ "${KINETIC_PLAYER_SGPLAYER_BUILD_FROM_SOURCE:-0}" != "1" ]]; then
  sgplayer_fail "Release download failed. Retry ensure_sgplayer.sh; source builds require KINETIC_PLAYER_SGPLAYER_BUILD_FROM_SOURCE=1."
fi
sgplayer_log "Prebuilt download unavailable; building from source..."
bash "${SCRIPT_DIR}/build_sgplayer.sh" "${KINETIC_SGPLAYER_PLATFORM}" "$@"
sync_spm_package_inputs
sync_flutter_spm_wrapper_if_needed
