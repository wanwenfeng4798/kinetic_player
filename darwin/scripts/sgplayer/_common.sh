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
  # sharedDarwinSource: single SPM / CocoaPods tree under darwin/
  SPM_PACKAGE_DIR="${DARWIN_DIR}/kinetic_player"
  MANIFEST="${DARWIN_DIR}/sgplayer/manifest.${platform}.json"
  OUTPUT_DIR="${DARWIN_DIR}/Frameworks/${platform}"
  XCFRAMEWORK_OUTPUT="${OUTPUT_DIR}/SGPlayer.xcframework"
  # Optional local copy inside the SPM package (gitignore'd); remote binaryTarget is primary.
  SPM_LOCAL_XCFRAMEWORK="${SPM_PACKAGE_DIR}/SGPlayer.xcframework"
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

# Sources live under darwin/kinetic_player/Sources (sharedDarwinSource). Only mirror a
# local xcframework into the package when present (offline / CocoaPods helper).
sync_spm_package_inputs() {
  local pkg_root="${SPM_PACKAGE_DIR}"
  local dest_bridge="${pkg_root}/Sources/SgNativePlayerBridge"
  local dest_kit="${pkg_root}/Sources/SgPlayerKit"

  [[ -d "${dest_kit}" ]] || sgplayer_fail "Missing SPM sources: ${dest_kit}"
  [[ -d "${dest_bridge}" ]] || sgplayer_fail "Missing SPM sources: ${dest_bridge}"

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

sync_flutter_spm_wrapper_if_needed() {
  local script="${SGPLAYER_SCRIPTS_DIR}/sync_flutter_spm_wrapper.sh"
  if [[ -x "${script}" || -f "${script}" ]]; then
    bash "${script}" || true
  fi
}
