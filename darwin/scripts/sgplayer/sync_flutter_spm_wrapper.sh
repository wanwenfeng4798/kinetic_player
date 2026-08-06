#!/usr/bin/env bash
#
# Align FlutterGeneratedPluginSwiftPackage minimum OS with kinetic_player
# (macOS 11 / iOS 13). Flutter generates the wrapper at 10.15 / 12 by default
# on `flutter pub get`; this keeps SPM resolution working without host Pre-actions.
#
# Usage:
#   bash darwin/scripts/sgplayer/sync_flutter_spm_wrapper.sh [flutter_app_root]
#
# When [flutter_app_root] is omitted, walks up from cwd / PROJECT_DIR for pubspec.yaml.

set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "${SCRIPT_DIR}/_common.sh"
kinetic_sgplayer_init "macos"

MACOS_MIN="11.0"
IOS_MIN="13.0"

find_flutter_app_root() {
  local start="${1:-}"
  if [[ -n "${start}" && -f "${start}/pubspec.yaml" ]]; then
    printf '%s\n' "$(cd "${start}" && pwd)"
    return 0
  fi
  if [[ -n "${PROJECT_DIR:-}" && -f "${PROJECT_DIR}/../pubspec.yaml" ]]; then
    printf '%s\n' "$(cd "${PROJECT_DIR}/.." && pwd)"
    return 0
  fi
  local dir="${PWD}"
  while [[ "${dir}" != "/" ]]; do
    if [[ -f "${dir}/pubspec.yaml" ]]; then
      printf '%s\n' "${dir}"
      return 0
    fi
    dir="$(dirname "${dir}")"
  done
  return 1
}

patch_manifest() {
  local manifest="$1"
  local platform="$2"
  local version="$3"
  [[ -f "${manifest}" ]] || return 0

  local old new
  case "${platform}" in
    macos)
      old='.macOS("10.15")'
      new=".macOS(\"${version}\")"
      ;;
    ios)
      old='.iOS("12.0")'
      new=".iOS(\"${version}\")"
      if ! grep -q "${old}" "${manifest}" 2>/dev/null; then
        old='.iOS("13.0")'
      fi
      ;;
    *)
      return 0
      ;;
  esac

  if grep -q "${old}" "${manifest}"; then
    python3 - "${manifest}" "${old}" "${new}" <<'PY'
import pathlib, sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = pathlib.Path(path).read_text(encoding="utf-8")
if old not in text:
    raise SystemExit(0)
pathlib.Path(path).write_text(text.replace(old, new, 1), encoding="utf-8")
print(f"[sgplayer:spm] {path}: {old} -> {new}")
PY
  fi
}

app_root="$(find_flutter_app_root "${1:-}")" || {
  sgplayer_log "No Flutter app root; skip SPM wrapper sync"
  exit 0
}

sgplayer_log "Syncing FlutterGeneratedPluginSwiftPackage under ${app_root}"

for platform in macos ios; do
  case "${platform}" in
    macos) subdir="macos" ; min="${MACOS_MIN}" ;;
    ios) subdir="ios" ; min="${IOS_MIN}" ;;
  esac
  manifest="${app_root}/${subdir}/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
  patch_manifest "${manifest}" "${platform}" "${min}"
done
