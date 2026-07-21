#!/usr/bin/env bash
# Resolves kinetic_player macos/scripts and runs spm_prebuild_hook.sh.
set -euo pipefail
APP_IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ROOT="$(cd "${APP_IOS_DIR}/.." && pwd)"
resolve_plugin_macos() {
  if [[ -n "${KINETIC_PLAYER_MACOS_DIR:-}" && -d "${KINETIC_PLAYER_MACOS_DIR}" ]]; then
    printf '%s' "${KINETIC_PLAYER_MACOS_DIR}"
    return 0
  fi
  local sibling="${APP_IOS_DIR}/../../macos"
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
root = data.get("plugins") or data
for key in ("macos", "darwin"):
    entries = root.get(key) or []
    for entry in entries:
        if not isinstance(entry, dict) or entry.get("name") != "kinetic_player":
            continue
        path = entry.get("path") or ""
        p = pathlib.Path(path)
        if not p.is_absolute():
            p = (app_root / p).resolve()
        hook = p / "macos" / "scripts" / "spm_prebuild_hook.sh"
        if hook.is_file():
            print(p / "macos")
            raise SystemExit(0)
raise SystemExit(1)
PY
    return $?
  fi
  return 1
}
PLUGIN_MACOS="$(resolve_plugin_macos)" || {
  echo "[run_kinetic_sgplayer_prebuild] Could not locate kinetic_player/macos" >&2
  exit 1
}
exec bash "${PLUGIN_MACOS}/scripts/spm_prebuild_hook.sh"
