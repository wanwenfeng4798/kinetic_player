#!/usr/bin/env bash
#
# Package SGPlayer.xcframework for GitHub Release upload.
#
# Usage:
#   bash ios/scripts/package_sgplayer_release.sh
#
# Outputs:
#   ios/Frameworks/SGPlayer.xcframework.zip
#   ios/Frameworks/SGPlayer.xcframework.zip.sha256

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
XCFRAMEWORK="${IOS_DIR}/Frameworks/SGPlayer.xcframework"
ZIP_PATH="${IOS_DIR}/Frameworks/SGPlayer.xcframework.zip"
SHA_PATH="${ZIP_PATH}.sha256"
MANIFEST="${IOS_DIR}/sgplayer_binary_manifest.json"
GITHUB_REPO="wanwenfeng4798/kinetic_player"
GITHUB_REPO_URL="https://github.com/${GITHUB_REPO}"

if [[ ! -d "${XCFRAMEWORK}" ]]; then
  echo "Missing ${XCFRAMEWORK}. Run: bash ios/scripts/build_sgplayer.sh" >&2
  exit 1
fi

(
  cd "${IOS_DIR}/Frameworks"
  rm -f "${ZIP_PATH}"
  zip -ry "$(basename "${ZIP_PATH}")" SGPlayer.xcframework
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

cat <<EOF

Packaged release artifact:
  Zip:    ${ZIP_PATH}
  SHA256: ${SHA256}

Upload to GitHub Release (recommended, single file limit 2 GiB):

  gh release create sgplayer-v${VERSION} \\
    "${ZIP_PATH}" \\
    --repo "${GITHUB_REPO}" \\
    --title "SGPlayer prebuilt v${VERSION}" \\
    --notes "Prebuilt SGPlayer.xcframework for kinetic_player iOS integration."

Then update ios/sgplayer_binary_manifest.json:

  "download_url": "https://github.com/wanwenfeng4798/kinetic_player/releases/download/sgplayer-v${VERSION}/SGPlayer.xcframework.zip",
  "sha256": "${SHA256}"

Do NOT commit the zip into git main branch (GitHub file limit ~100 MiB per blob).

EOF
