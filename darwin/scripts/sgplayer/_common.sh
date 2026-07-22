# shellcheck shell=bash
# Shared paths and helpers for kinetic_player SGPlayer scripts (iOS + macOS).
# Source from darwin/scripts/sgplayer; call kinetic_sgplayer_init <ios|macos>.

kinetic_sgplayer_init() {
  local platform="${1:-${KINETIC_SGPLAYER_PLATFORM:-}}"
  platform="$(printf '%s' "${platform}" | tr '[:upper:]' '[:lower:]')"
  case "${platform}" in
    ios | macos) ;;
    *)
      printf '[sgplayer] ERROR: platform must be ios or macos (got %s)\n' "${platform:-<empty>}" >&2
      return 1
      ;;
  esac

  KINETIC_SGPLAYER_PLATFORM="${platform}"

  local common_dir
  common_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  DARWIN_DIR="$(cd "${common_dir}/../.." && pwd)"
  PLUGIN_ROOT="$(cd "${DARWIN_DIR}/.." && pwd)"
  IOS_DIR="${PLUGIN_ROOT}/ios"
  MACOS_DIR="${PLUGIN_ROOT}/macos"
  PLATFORM_DIR="${PLUGIN_ROOT}/${platform}"
  MANIFEST="${DARWIN_DIR}/sgplayer/manifest.${platform}.json"
  OUTPUT_DIR="${DARWIN_DIR}/Frameworks/${platform}"
  XCFRAMEWORK_OUTPUT="${OUTPUT_DIR}/SGPlayer.xcframework"
  # Flutter SPM symlinks {ios|macos}/kinetic_player into ephemeral/Packages; relative
  # paths that leave that package dir resolve incorrectly. Keep a package-local link.
  SPM_LOCAL_XCFRAMEWORK="${PLATFORM_DIR}/kinetic_player/SGPlayer.xcframework"
  VENDOR_DIR="${DARWIN_DIR}/third_party"
  SGPLAYER_DIR="${VENDOR_DIR}/SGPlayer"
  SGPLAYER_SCRIPTS_DIR="${common_dir}"

  LOG_PREFIX="[sgplayer:${platform}]"
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

sgplayer_log() {
  # Always stderr so callers can capture path-only return values via $().
  printf '%s %s\n' "${LOG_PREFIX}" "$*" >&2
}

sgplayer_fail() {
  printf '%s ERROR: %s\n' "${LOG_PREFIX}" "$*" >&2
  exit 1
}

load_sgplayer_repo_from_manifest() {
  SGPLAYER_BRANCH="$(read_manifest_field sgplayer_branch)"
  SGPLAYER_REPO="$(read_manifest_field sgplayer_repository)"
  [[ -n "${SGPLAYER_BRANCH}" ]] || SGPLAYER_BRANCH="master"
  [[ -n "${SGPLAYER_REPO}" ]] || SGPLAYER_REPO="https://github.com/wanwenfeng4798/SGPlayer.git"
}

ensure_sgplayer_repo() {
  mkdir -p "${VENDOR_DIR}"

  if [[ ! -d "${SGPLAYER_DIR}/.git" ]]; then
    sgplayer_log "git clone ${SGPLAYER_REPO}"
    git clone "${SGPLAYER_REPO}" "${SGPLAYER_DIR}"
  else
    local origin_url
    origin_url="$(cd "${SGPLAYER_DIR}" && git remote get-url origin 2>/dev/null || true)"
    if [[ -n "${origin_url}" && "${origin_url}" != *"wanwenfeng4798/SGPlayer"* ]]; then
      sgplayer_fail "Existing clone is ${origin_url}. Remove ${SGPLAYER_DIR} and re-run to use ${SGPLAYER_REPO}"
    fi
    sgplayer_log "Using existing clone at ${SGPLAYER_DIR}"
  fi

  (
    cd "${SGPLAYER_DIR}"
    sgplayer_log "git fetch origin ${SGPLAYER_BRANCH}"
    git fetch origin "${SGPLAYER_BRANCH}"
    sgplayer_log "git checkout ${SGPLAYER_BRANCH}"
    git checkout "${SGPLAYER_BRANCH}"
    git pull --ff-only origin "${SGPLAYER_BRANCH}" 2>/dev/null || true
  )
}

# Flutter SPM forbids target paths outside the package root, and resolves paths via the
# ephemeral symlink of {ios|macos}/kinetic_player. Canonical sources/artifacts live under
# darwin/; mirror them into the SPM package before resolve/build.
sync_spm_package_inputs() {
  local pkg_root="${PLATFORM_DIR}/kinetic_player"
  local pkg_sources="${pkg_root}/Sources"
  local src_kit="${DARWIN_DIR}/kinetic_player/Sources/SgPlayerKit"
  local src_bridge="${DARWIN_DIR}/SgNativePlayerBridge"
  local dest_kit="${pkg_sources}/SgPlayerKit"
  local dest_bridge="${pkg_sources}/SgNativePlayerBridge"

  [[ -d "${src_kit}" ]] || sgplayer_fail "Missing shared sources: ${src_kit}"
  [[ -d "${src_bridge}" ]] || sgplayer_fail "Missing shared sources: ${src_bridge}"

  mkdir -p "${pkg_sources}"
  rm -rf "${dest_kit}" "${dest_bridge}"
  # Prefer APFS clone when available (near-instant); fall back to ditto.
  if cp -cR "${src_kit}" "${dest_kit}" 2>/dev/null; then
    :
  else
    ditto "${src_kit}" "${dest_kit}"
  fi
  if cp -cR "${src_bridge}" "${dest_bridge}" 2>/dev/null; then
    :
  else
    ditto "${src_bridge}" "${dest_bridge}"
  fi
  sgplayer_log "SPM sources synced -> ${dest_kit}, ${dest_bridge}"

  # Local binaryTarget (macos without remote URL, or ios offline fallback).
  if [[ -d "${XCFRAMEWORK_OUTPUT}" ]]; then
    SPM_LOCAL_XCFRAMEWORK="${pkg_root}/SGPlayer.xcframework"
    if [[ -L "${SPM_LOCAL_XCFRAMEWORK}" ]]; then
      rm -f "${SPM_LOCAL_XCFRAMEWORK}"
    fi
    if [[ ! -f "${SPM_LOCAL_XCFRAMEWORK}/Info.plist" ]]; then
      rm -rf "${SPM_LOCAL_XCFRAMEWORK}"
      sgplayer_log "Copying xcframework into SPM package..."
      ditto "${XCFRAMEWORK_OUTPUT}" "${SPM_LOCAL_XCFRAMEWORK}"
    fi
    sgplayer_log "SPM local xcframework: ${SPM_LOCAL_XCFRAMEWORK}"
  fi
}

# Back-compat alias used by build_sgplayer.sh
sync_spm_local_xcframework() {
  sync_spm_package_inputs
}
