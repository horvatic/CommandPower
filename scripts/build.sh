#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TASK_TARGET=${1:-linux}
case "$TASK_TARGET" in
  linux) TASK_PLATFORM=linux-x86_64 ;;
  windows) TASK_PLATFORM=windows-x86_64 ;;
  macos) TASK_PLATFORM=macos-universal ;;
  *) printf 'Usage: %s [linux|windows|macos]\n' "$0" >&2; exit 1 ;;
esac
TASK_PACKAGE="$TASK_ROOT/dist/CommandPower-$TASK_PLATFORM"
TASK_PROFILE=$(mktemp -d "${TMPDIR:-/tmp}/commandpower-build.XXXXXX")
trap 'rm -rf -- "$TASK_PROFILE"' EXIT
cd -- "$TASK_ROOT"
[[ -x .tools/godot ]] || ./scripts/setup-engine.sh
for task_notice in LICENSE.txt COPYRIGHT.txt; do
  if [[ ! -s ".tools/GODOT-$task_notice" ]]; then
    printf 'Missing Godot notices; run ./scripts/setup-engine.sh before packaging.\n' >&2
    exit 1
  fi
done
if command -v pgrep >/dev/null 2>&1 && pgrep -f "^$TASK_PACKAGE/CommandPower([[:space:]]|$)" >/dev/null; then
  printf 'Close the packaged CommandPower game before rebuilding.\n' >&2
  exit 1
fi
mkdir -p "$TASK_PROFILE/data" "$TASK_PROFILE/config" "$TASK_PROFILE/cache" "$TASK_ROOT/dist"
export XDG_DATA_HOME="$TASK_PROFILE/data" XDG_CONFIG_HOME="$TASK_PROFILE/config" XDG_CACHE_HOME="$TASK_PROFILE/cache"
export GODOT_SILENCE_ROOT_WARNING=1
if [[ "$TASK_TARGET" != linux ]]; then
  ./scripts/setup-export-templates.sh
  mkdir -p "$XDG_DATA_HOME/godot/export_templates"
  ln -s "$TASK_ROOT/.tools/export_templates/4.5.1.stable" "$XDG_DATA_HOME/godot/export_templates/4.5.1.stable"
fi
.tools/godot --headless --editor --path "$TASK_ROOT" --import
if [[ "$TASK_TARGET" == linux ]]; then
  .tools/godot --headless --path "$TASK_ROOT" --export-pack "Linux" "$TASK_PROFILE/CommandPower.pck"
  [[ -s "$TASK_PROFILE/CommandPower.pck" ]]
fi
rm -rf -- "$TASK_PACKAGE"
mkdir -p "$TASK_PACKAGE"
case "$TASK_TARGET" in
  linux)
    install -m 755 .tools/godot "$TASK_PACKAGE/CommandPower"
    cp -- "$TASK_PROFILE/CommandPower.pck" "$TASK_PACKAGE/CommandPower.pck"
    ;;
  windows)
    .tools/godot --headless --path "$TASK_ROOT" --export-release "Windows" "$TASK_PACKAGE/CommandPower.exe"
    [[ -s "$TASK_PACKAGE/CommandPower.exe" && -s "$TASK_PACKAGE/CommandPower.pck" ]]
    ;;
  macos)
    .tools/godot --headless --path "$TASK_ROOT" --export-release "macOS" "$TASK_PACKAGE/CommandPower.app"
    [[ -s "$TASK_PACKAGE/CommandPower.app/Contents/Info.plist" ]]
    [[ -x "$TASK_PACKAGE/CommandPower.app/Contents/MacOS/CommandPower" ]]
    ;;
esac
cp -- README.md LICENSE "$TASK_PACKAGE/"
cp -- assets/voices/CREDITS.txt "$TASK_PACKAGE/VOICE-CREDITS.txt"
cp -- .tools/GODOT-LICENSE.txt "$TASK_PACKAGE/GODOT-LICENSE.txt"
cp -- .tools/GODOT-COPYRIGHT.txt "$TASK_PACKAGE/GODOT-COPYRIGHT.txt"
if [[ "$TASK_TARGET" == linux ]]; then
  cat > "$TASK_PACKAGE/play.sh" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail
TASK_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec "$TASK_DIR/CommandPower" --main-pack "$TASK_DIR/CommandPower.pck" "$@"
LAUNCHER
  chmod +x "$TASK_PACKAGE/play.sh"
fi
rm -f -- "$TASK_PACKAGE.zip"
(cd -- "$TASK_ROOT/dist" && zip -qry "CommandPower-$TASK_PLATFORM.zip" "CommandPower-$TASK_PLATFORM")
printf 'Built %s\nArchive: %s\n' "$TASK_PACKAGE" "$TASK_PACKAGE.zip"
