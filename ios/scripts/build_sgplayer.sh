#!/usr/bin/env bash
#
# Build libobjc/SGPlayer (master) for kinetic_player iOS integration.
#
#   git clone https://github.com/libobjc/SGPlayer.git
#   cd SGPlayer
#   git checkout master
#   ./build.sh iOS build
#
# Then packages SGPlayer.framework into ios/Frameworks/ for CocoaPods.
#
# Usage:
#   bash ios/scripts/build_sgplayer.sh          # full build
#   bash ios/scripts/build_sgplayer.sh clean    # remove artifacts
#
# Also invoked automatically by kinetic_player.podspec prepare_command on pod install.

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
FRAMEWORK_OUTPUT="${OUTPUT_DIR}/SGPlayer.framework"
DERIVED_DATA="${SGPLAYER_DIR}/DerivedData"

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
  log "FFmpeg 4.4.4 + OpenSSL 1.1.1w - first run may take 30-60 minutes."
  (
    cd "${SGPLAYER_DIR}"
    ./build.sh iOS build
  )
  [[ -f "${ffmpeg_lib}" ]] || fail "FFmpeg build did not produce ${ffmpeg_lib}"
}

build_framework() {
  log "Building SGPlayer.framework (Release, iphoneos)..."
  mkdir -p "${OUTPUT_DIR}"
  rm -rf "${DERIVED_DATA}"

  (
    cd "${SGPLAYER_DIR}"
    xcodebuild \
      -project SGPlayer.xcodeproj \
      -scheme "SGPlayer iOS" \
      -configuration Release \
      -sdk iphoneos \
      -derivedDataPath "${DERIVED_DATA}" \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
      ONLY_ACTIVE_ARCH=NO \
      build
  )

  local built_framework
  built_framework="$(find "${DERIVED_DATA}" -path "*/Release-iphoneos/SGPlayer.framework" -type d | head -n 1)"
  [[ -n "${built_framework}" ]] || fail "Could not locate built SGPlayer.framework"

  rm -rf "${FRAMEWORK_OUTPUT}"
  cp -R "${built_framework}" "${FRAMEWORK_OUTPUT}"
  log "Output: ${FRAMEWORK_OUTPUT}"
}

main() {
  if [[ "${1:-}" == "clean" ]]; then
    clean_artifacts
    exit 0
  fi

  if [[ -d "${FRAMEWORK_OUTPUT}" ]]; then
    log "SGPlayer.framework already exists, skipping build."
    log "Path: ${FRAMEWORK_OUTPUT}"
    exit 0
  fi

  command -v git >/dev/null || fail "git is required"
  command -v xcodebuild >/dev/null || fail "xcodebuild is required (install Xcode)"

  ensure_repo
  build_dependencies
  build_framework

  log "Done. SGPlayer (${SGPLAYER_BRANCH}) is ready."
  log "Framework: ${FRAMEWORK_OUTPUT}"
}

main "$@"
