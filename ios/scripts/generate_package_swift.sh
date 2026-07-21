#!/usr/bin/env bash
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec bash "${PLUGIN_ROOT}/darwin/scripts/sgplayer/generate_package_swift.sh" ios "$@"
