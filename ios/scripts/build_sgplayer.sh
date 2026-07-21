#!/usr/bin/env bash
# Wrapper → darwin/scripts/sgplayer/build_sgplayer.sh
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec bash "${PLUGIN_ROOT}/darwin/scripts/sgplayer/build_sgplayer.sh" ios "$@"
