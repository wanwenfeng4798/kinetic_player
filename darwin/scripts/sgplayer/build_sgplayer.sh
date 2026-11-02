#!/usr/bin/env bash
# Explicit source fallback for SGPlayer 2.0; normally use the release archives.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
kinetic_sgplayer_init "${1:-}"
load_sgplayer_repo_from_manifest
ensure_sgplayer_repo
case "${KINETIC_SGPLAYER_PLATFORM}" in
  ios) sdk_platform=iOS ;;
  macos) sdk_platform=macOS ;;
esac
(
  cd "${SGPLAYER_DIR}"
  ./build.sh "${sdk_platform}" build
  python3 scripts/build-package.py --platform "${sdk_platform}"
)
framework="${SGPLAYER_DIR}/build/Package-${sdk_platform}/Artifacts/SGPlayer.xcframework"
[[ -f "${framework}/Info.plist" ]] || sgplayer_fail "Upstream packaging did not produce ${framework}"
mkdir -p "${OUTPUT_DIR}"
resources="${SPM_PACKAGE_DIR}/Sources/kinetic_player/Resources/SGPlayer"
mkdir -p "${resources}"
ditto "${SGPLAYER_DIR}/build/Package-${sdk_platform}/Sources/SGPlayerUI/Resources" "${resources}"
rm -rf "${XCFRAMEWORK_OUTPUT}"
ditto "${framework}" "${XCFRAMEWORK_OUTPUT}"
read_manifest_field version > "${OUTPUT_DIR}/.sgplayer-version"
sync_spm_package_inputs
