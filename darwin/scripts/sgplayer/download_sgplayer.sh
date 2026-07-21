#!/usr/bin/env bash
#
# Download prebuilt SGPlayer.xcframework (iOS or macOS manifest).
# Returns 0 on success, 1 if download is skipped or failed (caller may build locally).
#
# Usage:
#   bash darwin/scripts/sgplayer/download_sgplayer.sh ios|macos
#
# Override:
#   KINETIC_PLAYER_SGPLAYER_DOWNLOAD_URL=https://.../SGPlayer.xcframework.zip

set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "${SCRIPT_DIR}/_common.sh"
kinetic_sgplayer_init "${1:-}"

normalize_sha256() {
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
    sgplayer_log "SHA256 mismatch. expected=${expected} actual=${actual}"
    return 1
  fi
  sgplayer_log "SHA256 verified."
}

main() {
  if [[ -d "${XCFRAMEWORK_OUTPUT}" ]]; then
    sgplayer_log "SGPlayer.xcframework already present."
    exit 0
  fi

  local download_url="${KINETIC_PLAYER_SGPLAYER_DOWNLOAD_URL:-}"
  local expected_sha256=""

  if [[ -z "${download_url}" && -f "${MANIFEST}" ]]; then
    download_url="$(read_manifest_field download_url)"
    expected_sha256="$(read_manifest_field sha256)"
  fi

  if [[ -z "${download_url}" ]]; then
    sgplayer_log "No download_url configured. Skipping prebuilt download."
    exit 1
  fi

  command -v curl >/dev/null || { sgplayer_log "curl is required."; exit 1; }
  command -v unzip >/dev/null || { sgplayer_log "unzip is required."; exit 1; }

  mkdir -p "${OUTPUT_DIR}"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local zip_path="${tmp_dir}/SGPlayer.xcframework.zip"

  sgplayer_log "Downloading ${download_url}"
  if ! curl -fL --http1.1 --retry 5 --retry-all-errors --retry-delay 2 \
      --connect-timeout 30 --progress-bar \
      "${download_url}" -o "${zip_path}"; then
    sgplayer_log "Download failed."
    rm -rf "${tmp_dir}"
    exit 1
  fi

  if [[ ! -s "${zip_path}" ]]; then
    sgplayer_log "Downloaded file is empty."
    rm -rf "${tmp_dir}"
    exit 1
  fi

  if ! verify_sha256 "${zip_path}" "${expected_sha256}"; then
    rm -rf "${tmp_dir}"
    exit 1
  fi

  unzip -q "${zip_path}" -d "${tmp_dir}/extract"
  if [[ ! -d "${tmp_dir}/extract/SGPlayer.xcframework" ]]; then
    sgplayer_log "Archive must contain SGPlayer.xcframework at zip root."
    rm -rf "${tmp_dir}"
    exit 1
  fi

  rm -rf "${XCFRAMEWORK_OUTPUT}"
  mv "${tmp_dir}/extract/SGPlayer.xcframework" "${XCFRAMEWORK_OUTPUT}"
  rm -rf "${tmp_dir}"

  sgplayer_log "Installed ${XCFRAMEWORK_OUTPUT}"
}

main
