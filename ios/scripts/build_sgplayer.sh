#!/usr/bin/env bash
#
# Build libobjc/SGPlayer (master) for kinetic_player iOS integration.
#
# Outputs ios/Frameworks/SGPlayer.xcframework for:
#   - CocoaPods (vendored_frameworks)
#   - Swift Package Manager (binaryTarget in ios/kinetic_player/Package.swift)
#
# Note: FFmpeg/OpenSSL from SGPlayer ./build.sh iOS build are device arm64 only,
# so the xcframework currently ships an ios-arm64 slice (physical device).
#
# Usage:
#   bash ios/scripts/build_sgplayer.sh          # full build
#   bash ios/scripts/build_sgplayer.sh clean    # remove artifacts
#
# Invoked by ensure_sgplayer.sh when prebuilt download is unavailable.

set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

SGPLAYER_BRANCH="master"
SGPLAYER_REPO="https://github.com/libobjc/SGPlayer.git"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENDOR_DIR="${IOS_DIR}/third_party"
SGPLAYER_DIR="${VENDOR_DIR}/SGPlayer"
OUTPUT_DIR="${IOS_DIR}/Frameworks"
LEGACY_FRAMEWORK="${OUTPUT_DIR}/SGPlayer.framework"
XCFRAMEWORK_OUTPUT="${OUTPUT_DIR}/SGPlayer.xcframework"
DERIVED_DATA_BASE="${SGPLAYER_DIR}/DerivedData"

log() {
  printf '[build_sgplayer] %s\n' "$*"
}

fail() {
  printf '[build_sgplayer] ERROR: %s\n' "$*" >&2
  exit 1
}

clean_artifacts() {
  log "Cleaning SGPlayer build artifacts..."
  rm -rf "${VENDOR_DIR}" "${OUTPUT_DIR}"
  log "Clean complete."
}

ensure_repo() {
  mkdir -p "${VENDOR_DIR}"

  if [[ ! -d "${SGPLAYER_DIR}/.git" ]]; then
    log "git clone ${SGPLAYER_REPO}"
    git clone "${SGPLAYER_REPO}" "${SGPLAYER_DIR}"
  else
    log "Using existing clone at ${SGPLAYER_DIR}"
  fi

  (
    cd "${SGPLAYER_DIR}"
    log "git fetch origin ${SGPLAYER_BRANCH}"
    git fetch origin "${SGPLAYER_BRANCH}"
    log "git checkout ${SGPLAYER_BRANCH}"
    git checkout "${SGPLAYER_BRANCH}"
    git pull --ff-only origin "${SGPLAYER_BRANCH}" 2>/dev/null || true
  )
}

build_dependencies() {
  local ffmpeg_lib="${SGPLAYER_DIR}/build/libs/iOS/universal/lib/libavcodec.a"
  if [[ -f "${ffmpeg_lib}" ]]; then
    log "FFmpeg/OpenSSL artifacts already present, skipping ./build.sh iOS build"
    return
  fi

  log "Running ./build.sh iOS build"
  log "FFmpeg + OpenSSL - first run may take 30-60 minutes."
  (
    cd "${SGPLAYER_DIR}"
    ./build.sh iOS build
  )
  [[ -f "${ffmpeg_lib}" ]] || fail "FFmpeg build did not produce ${ffmpeg_lib}"
}

build_device_framework() {
  local derived_data="${DERIVED_DATA_BASE}/iphoneos"

  log "Building SGPlayer.framework (Release, iphoneos)..."
  rm -rf "${derived_data}"

  (
    cd "${SGPLAYER_DIR}"
    xcodebuild \
      -project SGPlayer.xcodeproj \
      -scheme "SGPlayer iOS" \
      -configuration Release \
      -sdk iphoneos \
      -derivedDataPath "${derived_data}" \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
      ONLY_ACTIVE_ARCH=NO \
      build
  )

  local built_framework
  built_framework="$(find "${derived_data}" -path "*/Release-iphoneos/SGPlayer.framework" -type d | head -n 1)"
  [[ -n "${built_framework}" ]] || fail "Could not locate SGPlayer.framework for iphoneos"
  printf '%s' "${built_framework}"
}

build_xcframework() {
  mkdir -p "${OUTPUT_DIR}"
  rm -rf "${XCFRAMEWORK_OUTPUT}"

  local device_framework
  if [[ -d "${LEGACY_FRAMEWORK}" ]]; then
    log "Reusing existing ${LEGACY_FRAMEWORK}."
    device_framework="${LEGACY_FRAMEWORK}"
  else
    device_framework="$(build_device_framework)"
  fi

  log "Creating SGPlayer.xcframework (ios-arm64 device slice)..."
  xcodebuild -create-xcframework \
    -framework "${device_framework}" \
    -output "${XCFRAMEWORK_OUTPUT}"

  rm -rf "${LEGACY_FRAMEWORK}"
  log "Output: ${XCFRAMEWORK_OUTPUT}"
}

main() {
  if [[ "${1:-}" == "clean" ]]; then
    clean_artifacts
    exit 0
  fi

  if [[ -d "${XCFRAMEWORK_OUTPUT}" ]]; then
    log "SGPlayer.xcframework already exists, skipping build."
    log "Path: ${XCFRAMEWORK_OUTPUT}"
    exit 0
  fi

  command -v git >/dev/null || fail "git is required"
  command -v xcodebuild >/dev/null || fail "xcodebuild is required (install Xcode)"

  ensure_repo
  build_dependencies
  build_xcframework

  log "Done. SGPlayer (${SGPLAYER_BRANCH}) xcframework is ready for CocoaPods + SPM."
  log "Framework: ${XCFRAMEWORK_OUTPUT}"
}

main "$@"
