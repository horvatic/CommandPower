#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TASK_RELEASE=4.5.1-stable
TASK_TMP=$(mktemp -d "${TMPDIR:-/tmp}/commandpower-engine.XXXXXX")
trap 'rm -rf -- "$TASK_TMP"' EXIT
mkdir -p "$TASK_ROOT/.tools"
if [[ ! -x "$TASK_ROOT/.tools/godot" ]]; then
  curl -L --fail --retry 2 --connect-timeout 20 -o "$TASK_TMP/engine.zip" "https://github.com/godotengine/godot/releases/download/$TASK_RELEASE/Godot_v${TASK_RELEASE}_linux.x86_64.zip"
  unzip -q "$TASK_TMP/engine.zip" -d "$TASK_TMP"
  install -m 755 "$TASK_TMP/Godot_v${TASK_RELEASE}_linux.x86_64" "$TASK_ROOT/.tools/godot"
fi
for task_notice in LICENSE.txt COPYRIGHT.txt; do
  if [[ ! -s "$TASK_ROOT/.tools/GODOT-$task_notice" ]]; then
    curl -L --fail --retry 2 --connect-timeout 20 -o "$TASK_TMP/$task_notice" "https://raw.githubusercontent.com/godotengine/godot/$TASK_RELEASE/$task_notice"
    cp -- "$TASK_TMP/$task_notice" "$TASK_ROOT/.tools/GODOT-$task_notice"
  fi
done
"$TASK_ROOT/.tools/godot" --version
