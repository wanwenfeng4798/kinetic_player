#!/usr/bin/env bash
#
# Host-app helper: locate kinetic_player ios/scripts and run spm_prebuild_hook.sh.
#
# Intended for Xcode scheme Pre-actions where SRCROOT is the app's ios/ folder.
#
# Usage (Runner.xcscheme PreAction):
#   /bin/bash "${SRCROOT}/scripts/run_kinetic_sgplayer_prebuild.sh"
#
# Resolution order:
#   1. KINETIC_PLAYER_IOS_DIR
#   2. Path dependency sibling: ${SRCROOT}/../../ios (plugin checkout next to example)
#   3. .flutter-plugins-dependencies → kinetic_player path

set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

APP_IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ROOT="$(cd "${APP_IOS_DIR}/.." && pwd)"

resolve_plugin_ios() {
  if [[ -n "${KINETIC_PLAYER_IOS_DIR:-}" && -d "${KINETIC_PLAYER_IOS_DIR}" ]]; then
    printf '%s' "${KINETIC_PLAYER_IOS_DIR}"
    return 0
  fi

  local sibling="${APP_IOS_DIR}/../../ios"
  if [[ -f "${sibling}/scripts/spm_prebuild_hook.sh" ]]; then
    cd "${sibling}" && pwd
    return 0
  fi

  local plugins_file="${APP_ROOT}/.flutter-plugins-dependencies"
  if [[ -f "${plugins_file}" ]]; then
    python3 - "${plugins_file}" "${APP_ROOT}" <<'PY'
import json, pathlib, sys
plugins = pathlib.Path(sys.argv[1])
app_root = pathlib.Path(sys.argv[2])
data = json.loads(plugins.read_text(encoding="utf-8"))
# Format: {"plugins":{"ios":[{"name":"kinetic_player","path":"..."}], ...}}
candidates = []
root = data.get("plugins") or data
for key in ("ios", "darwin"):
    entries = root.get(key) or []
    if isinstance(entries, dict):
        entries = [{"name": k, **v} if isinstance(v, dict) else {"name": k, "path": v} for k, v in entries.items()]
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        name = entry.get("name") or ""
        path = entry.get("path") or entry.get("native_build_path") or ""
        if name == "kinetic_player" and path:
            candidates.append(path)
# Older flat map: {"kinetic_player": "<path>"}
if not candidates and isinstance(root, dict):
    path = root.get("kinetic_player")
    if isinstance(path, str):
        candidates.append(path)
for path in candidates:
    p = pathlib.Path(path)
    if not p.is_absolute():
        p = (app_root / p).resolve()
    ios = p / "ios"
    hook = ios / "scripts" / "spm_prebuild_hook.sh"
    if hook.is_file():
        print(ios)
        raise SystemExit(0)
raise SystemExit(1)
PY
    return $?
  fi

  return 1
}

PLUGIN_IOS="$(resolve_plugin_ios)" || {
  echo "[run_kinetic_sgplayer_prebuild] Could not locate kinetic_player/ios." >&2
  echo "Set KINETIC_PLAYER_IOS_DIR or run: flutter pub get" >&2
  exit 1
}

exec bash "${PLUGIN_IOS}/scripts/spm_prebuild_hook.sh"
