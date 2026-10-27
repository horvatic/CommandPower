#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TASK_RELEASE=4.5.1-stable
TASK_TEMPLATES="$TASK_ROOT/.tools/export_templates/4.5.1.stable"
if [[ -s "$TASK_TEMPLATES/windows_release_x86_64.exe" && -s "$TASK_TEMPLATES/macos.zip" ]]; then
  exit 0
fi
TASK_TMP=$(mktemp -d "${TMPDIR:-/tmp}/commandpower-templates.XXXXXX")
trap 'rm -rf -- "$TASK_TMP"' EXIT
curl -L --fail --retry 2 --connect-timeout 20 -o "$TASK_TMP/templates.tpz" \
  "https://github.com/godotengine/godot/releases/download/$TASK_RELEASE/Godot_v${TASK_RELEASE}_export_templates.tpz"
unzip -q "$TASK_TMP/templates.tpz" 'templates/windows_release_x86_64.exe' 'templates/macos.zip' -d "$TASK_TMP"
mkdir -p "$TASK_TEMPLATES"
cp -- "$TASK_TMP/templates/windows_release_x86_64.exe" "$TASK_TMP/templates/macos.zip" "$TASK_TEMPLATES/"
