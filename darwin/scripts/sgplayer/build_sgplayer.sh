#!/usr/bin/env bash
#
# Build wanwenfeng4798/SGPlayer for kinetic_player (iOS or macOS).
#
# Usage:
#   bash darwin/scripts/sgplayer/build_sgplayer.sh ios|macos
#   bash darwin/scripts/sgplayer/build_sgplayer.sh ios clean   # removes darwin/third_party + ios slice
#
# Thin wrappers: ios/scripts/build_sgplayer.sh, macos/scripts/build_sgplayer.sh

set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "${SCRIPT_DIR}/_common.sh"

PLATFORM_ARG="${1:-}"
shift || true
kinetic_sgplayer_init "${PLATFORM_ARG}"
load_sgplayer_repo_from_manifest

LEGACY_FRAMEWORK="${OUTPUT_DIR}/SGPlayer.framework"

clean_artifacts() {
  sgplayer_log "Cleaning SGPlayer build artifacts..."
  if [[ "${KINETIC_SGPLAYER_PLATFORM}" == "ios" ]]; then
    rm -rf "${VENDOR_DIR}" "${OUTPUT_DIR}"
  else
    rm -rf "${OUTPUT_DIR}"
  fi
  sgplayer_log "Clean complete."
}

build_dependencies_ios() {
  local ffmpeg_lib="${SGPLAYER_DIR}/build/libs/iOS/universal/lib/libavcodec.a"
  if [[ -f "${ffmpeg_lib}" ]]; then
    sgplayer_log "FFmpeg/OpenSSL artifacts already present, skipping ./build.sh iOS build"
    return
  fi
  sgplayer_log "Running ./build.sh iOS build (first run may take 30-60 minutes)"
  (
    cd "${SGPLAYER_DIR}"
    ./build.sh iOS build
  )
  [[ -f "${ffmpeg_lib}" ]] || sgplayer_fail "FFmpeg build did not produce ${ffmpeg_lib}"
}

build_dependencies_macos() {
  local ffmpeg_lib="${SGPLAYER_DIR}/build/libs/macOS/universal/lib/libavcodec.a"
  if [[ -f "${ffmpeg_lib}" ]]; then
    sgplayer_log "FFmpeg/OpenSSL macOS artifacts present, skipping ./build.sh macOS build"
    return
  fi
  sgplayer_log "Running ./build.sh macOS build (first run may take 30-60 minutes)"
  (
    cd "${SGPLAYER_DIR}"
    ./build.sh macOS build
  )
  [[ -f "${ffmpeg_lib}" ]] || sgplayer_fail "FFmpeg build did not produce ${ffmpeg_lib}"
}

# Locate built .framework under DerivedData. Echoes path on stdout only.
find_built_framework() {
  local derived_data="$1"
  local path_glob="$2"
  local built_framework
  built_framework="$(find "${derived_data}" -path "${path_glob}" -type d | head -n 1)"
  [[ -n "${built_framework}" ]] || sgplayer_fail "Could not locate SGPlayer.framework under ${derived_data} (${path_glob})"
  printf '%s\n' "${built_framework}"
}

build_device_framework_ios() {
  local derived_data="${SGPLAYER_DIR}/DerivedData/iphoneos"
  sgplayer_log "Building SGPlayer.framework (Release, iphoneos)..."
  rm -rf "${derived_data}"
  (
    cd "${SGPLAYER_DIR}"
    # Keep xcodebuild on stderr so "$(...)" only captures the framework path.
    xcodebuild \
      -project SGPlayer.xcodeproj \
      -scheme "SGPlayer iOS" \
      -configuration Release \
      -sdk iphoneos \
      -derivedDataPath "${derived_data}" \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
      ONLY_ACTIVE_ARCH=NO \
      build
  ) >&2
  find_built_framework "${derived_data}" "*/Release-iphoneos/SGPlayer.framework"
}

build_mac_framework() {
  local derived_data="${SGPLAYER_DIR}/DerivedData-macos/macosx"
  sgplayer_log "Building SGPlayer.framework (Release, macosx) scheme=SGPlayer macOS..."
  rm -rf "${derived_data}"
  (
    cd "${SGPLAYER_DIR}"
    xcodebuild \
      -project SGPlayer.xcodeproj \
      -scheme "SGPlayer macOS" \
      -configuration Release \
      -sdk macosx \
      -derivedDataPath "${derived_data}" \
      -destination 'platform=macOS' \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
      ONLY_ACTIVE_ARCH=NO \
      build
  ) >&2
  find_built_framework "${derived_data}" "*/Release/SGPlayer.framework"
}

build_xcframework() {
  mkdir -p "${OUTPUT_DIR}"
  rm -rf "${XCFRAMEWORK_OUTPUT}"

  local slice_framework
  if [[ -d "${LEGACY_FRAMEWORK}" ]]; then
    sgplayer_log "Reusing existing ${LEGACY_FRAMEWORK}."
    slice_framework="${LEGACY_FRAMEWORK}"
  elif [[ "${KINETIC_SGPLAYER_PLATFORM}" == "ios" ]]; then
    slice_framework="$(build_device_framework_ios)"
  else
    slice_framework="$(build_mac_framework)"
  fi

  # Trim accidental whitespace/newlines from captured path.
  slice_framework="$(printf '%s' "${slice_framework}" | tr -d '\r' | head -n 1)"
  [[ -d "${slice_framework}" ]] || sgplayer_fail "Framework path is not a directory: ${slice_framework}"

  sgplayer_log "Creating SGPlayer.xcframework from ${slice_framework}..."
  xcodebuild -create-xcframework \
    -framework "${slice_framework}" \
    -output "${XCFRAMEWORK_OUTPUT}"

  rm -rf "${LEGACY_FRAMEWORK}"
  sgplayer_log "Output: ${XCFRAMEWORK_OUTPUT}"
}

main() {
  if [[ "${1:-}" == "clean" ]]; then
    clean_artifacts
    exit 0
  fi

  if [[ -d "${XCFRAMEWORK_OUTPUT}" ]]; then
    sgplayer_log "SGPlayer.xcframework already exists, skipping build."
    sgplayer_log "Path: ${XCFRAMEWORK_OUTPUT}"
    exit 0
  fi

  command -v git >/dev/null || sgplayer_fail "git is required"
  command -v xcodebuild >/dev/null || sgplayer_fail "xcodebuild is required (install Xcode)"

  ensure_sgplayer_repo
  if [[ "${KINETIC_SGPLAYER_PLATFORM}" == "ios" ]]; then
    build_dependencies_ios
  else
    build_dependencies_macos
  fi
  build_xcframework

  sync_spm_local_xcframework
  sgplayer_log "Done. SGPlayer (${SGPLAYER_BRANCH}) xcframework is ready."
}

main "$@"
