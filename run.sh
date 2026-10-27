#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ -x "$TASK_ROOT/.tools/godot" ]] || "$TASK_ROOT/scripts/setup-engine.sh"
exec "$TASK_ROOT/.tools/godot" --path "$TASK_ROOT" "$@"
