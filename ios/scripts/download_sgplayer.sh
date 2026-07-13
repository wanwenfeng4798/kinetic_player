#!/usr/bin/env bash
#
# Download prebuilt SGPlayer.xcframework from GitHub Release (or custom URL).
# Returns 0 on success, 1 if download is skipped or failed (caller may build locally).
#
# Override:
#   KINETIC_PLAYER_SGPLAYER_DOWNLOAD_URL=https://.../SGPlayer.xcframework.zip

set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST="${IOS_DIR}/sgplayer_binary_manifest.json"
OUTPUT_DIR="${IOS_DIR}/Frameworks"
XCFRAMEWORK_OUTPUT="${OUTPUT_DIR}/SGPlayer.xcframework"

log() {
  printf '[download_sgplayer] %s\n' "$*"
}

read_manifest_field() {
  local field="$1"
  python3 - "$MANIFEST" "$field" <<'PY'
import json, sys
path, field = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
value = data.get(field, "")
print("" if value is None else str(value))
PY
}

normalize_sha256() {
  # Accept bare hex or GitHub-style "sha256:<hex>".
  local value="$1"
  value="$(printf '%s' "${value}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  if [[ "${value}" == sha256:* ]]; then
    value="${value#sha256:}"
  fi
  printf '%s' "${value}"
}

verify_sha256() {
  local file="$1"
  local expected
  expected="$(normalize_sha256 "$2")"
  [[ -n "${expected}" ]] || return 0

  local actual
  if command -v shasum >/dev/null; then
    actual="$(shasum -a 256 "${file}" | awk '{print $1}')"
  else
    actual="$(sha256sum "${file}" | awk '{print $1}')"
  fi

  if [[ "${actual}" != "${expected}" ]]; then
    log "SHA256 mismatch. expected=${expected} actual=${actual}"
    return 1
  fi
  log "SHA256 verified."
}

main() {
  if [[ -d "${XCFRAMEWORK_OUTPUT}" ]]; then
    log "SGPlayer.xcframework already present."
    exit 0
  fi

  local download_url="${KINETIC_PLAYER_SGPLAYER_DOWNLOAD_URL:-}"
  local expected_sha256=""

  if [[ -z "${download_url}" && -f "${MANIFEST}" ]]; then
    download_url="$(read_manifest_field download_url)"
    expected_sha256="$(read_manifest_field sha256)"
  fi

  if [[ -z "${download_url}" ]]; then
    log "No download_url configured. Skipping prebuilt download."
    exit 1
  fi

  command -v curl >/dev/null || { log "curl is required."; exit 1; }
  command -v unzip >/dev/null || { log "unzip is required."; exit 1; }

  mkdir -p "${OUTPUT_DIR}"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local zip_path="${tmp_dir}/SGPlayer.xcframework.zip"

  log "Downloading ${download_url}"
  # GitHub Release assets redirect to blob storage; HTTP/2 framing can fail on large
  # downloads (curl 16). Prefer HTTP/1.1. Progress on stderr so pod install is not silent.
  if ! curl -fL --http1.1 --retry 5 --retry-all-errors --retry-delay 2 \
      --connect-timeout 30 --progress-bar \
      "${download_url}" -o "${zip_path}"; then
    log "Download failed."
    rm -rf "${tmp_dir}"
    exit 1
  fi

  if [[ ! -s "${zip_path}" ]]; then
    log "Downloaded file is empty."
    rm -rf "${tmp_dir}"
    exit 1
  fi

  if ! verify_sha256 "${zip_path}" "${expected_sha256}"; then
    rm -rf "${tmp_dir}"
    exit 1
  fi

  unzip -q "${zip_path}" -d "${tmp_dir}/extract"
  if [[ ! -d "${tmp_dir}/extract/SGPlayer.xcframework" ]]; then
    log "Archive must contain SGPlayer.xcframework at zip root."
    rm -rf "${tmp_dir}"
    exit 1
  fi

  rm -rf "${XCFRAMEWORK_OUTPUT}"
  mv "${tmp_dir}/extract/SGPlayer.xcframework" "${XCFRAMEWORK_OUTPUT}"
  rm -rf "${tmp_dir}"

  log "Installed ${XCFRAMEWORK_OUTPUT}"
}

main "$@"
