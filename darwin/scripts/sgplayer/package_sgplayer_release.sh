#!/usr/bin/env bash
#
# Package SGPlayer.xcframework for GitHub Release upload.
#
# Usage:
#   bash darwin/scripts/sgplayer/package_sgplayer_release.sh ios|macos

set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "${SCRIPT_DIR}/_common.sh"
kinetic_sgplayer_init "${1:-}"

GITHUB_REPO="wanwenfeng4798/kinetic_player"

if [[ "${KINETIC_SGPLAYER_PLATFORM}" == "ios" ]]; then
  ZIP_NAME="SGPlayer.xcframework.zip"
  RELEASE_TAG_PREFIX="sgplayer-v"
  RELEASE_TITLE_PREFIX="SGPlayer prebuilt"
  NOTES="Prebuilt SGPlayer.xcframework for kinetic_player iOS integration."
else
  ZIP_NAME="SGPlayer-macOS.xcframework.zip"
  RELEASE_TAG_PREFIX="sgplayer-macos-v"
  RELEASE_TITLE_PREFIX="SGPlayer macOS prebuilt"
  NOTES="Prebuilt SGPlayer.xcframework for kinetic_player macOS integration."
fi

ZIP_PATH="${OUTPUT_DIR}/${ZIP_NAME}"
SHA_PATH="${ZIP_PATH}.sha256"

if [[ ! -d "${XCFRAMEWORK_OUTPUT}" ]]; then
  sgplayer_fail "Missing ${XCFRAMEWORK_OUTPUT}. Run: bash darwin/scripts/sgplayer/build_sgplayer.sh ${KINETIC_SGPLAYER_PLATFORM}"
fi

(
  cd "${OUTPUT_DIR}"
  rm -f "${ZIP_NAME}"
  zip -ry "${ZIP_NAME}" SGPlayer.xcframework
)

if command -v shasum >/dev/null; then
  shasum -a 256 "${ZIP_PATH}" | awk '{print $1}' > "${SHA_PATH}"
else
  sha256sum "${ZIP_PATH}" | awk '{print $1}' > "${SHA_PATH}"
fi

SHA256="$(cat "${SHA_PATH}")"
VERSION="$(python3 - "${MANIFEST}" <<'PY' 2>/dev/null || echo "1.0.0"
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    print(json.load(f).get("version", "1.0.0"))
PY
)"
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG_PREFIX}${VERSION}/${ZIP_NAME}"

python3 - "${MANIFEST}" "${VERSION}" "${DOWNLOAD_URL}" "${SHA256}" "${ZIP_NAME}" <<'PY'
import json, sys
from pathlib import Path
path, version, url, sha, asset = Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
data = json.loads(path.read_text(encoding="utf-8"))
data["version"] = version
data["download_url"] = url
data["sha256"] = sha
data["asset_name"] = asset
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(f"Updated {path}")
PY

bash "${SCRIPT_DIR}/generate_package_swift.sh" "${KINETIC_SGPLAYER_PLATFORM}"

cat <<EOF

Packaged release artifact (${KINETIC_SGPLAYER_PLATFORM}):
  Zip:    ${ZIP_PATH}
  SHA256: ${SHA256}

Upload to GitHub Release:

  gh release create ${RELEASE_TAG_PREFIX}${VERSION} \\
    "${ZIP_PATH}" \\
    --repo "${GITHUB_REPO}" \\
    --title "${RELEASE_TITLE_PREFIX} v${VERSION}" \\
    --notes "${NOTES}"

Manifest + Package.swift updated:
  download_url: ${DOWNLOAD_URL}
  sha256: ${SHA256}

Commit darwin/sgplayer/manifest.${KINETIC_SGPLAYER_PLATFORM}.json and ${KINETIC_SGPLAYER_PLATFORM}/kinetic_player/Package.swift.
Do NOT commit the zip into git main branch (GitHub file limit ~100 MiB per blob).

EOF
