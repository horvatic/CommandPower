#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TASK_PACKAGE="$TASK_ROOT/dist/CommandPower-linux-x86_64"
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
.tools/godot --headless --editor --path "$TASK_ROOT" --import
.tools/godot --headless --path "$TASK_ROOT" --export-pack "Linux" "$TASK_PROFILE/CommandPower.pck"
[[ -s "$TASK_PROFILE/CommandPower.pck" ]]
rm -rf -- "$TASK_PACKAGE"
mkdir -p "$TASK_PACKAGE"
install -m 755 .tools/godot "$TASK_PACKAGE/CommandPower"
cp -- "$TASK_PROFILE/CommandPower.pck" "$TASK_PACKAGE/CommandPower.pck"
cp -- README.md LICENSE "$TASK_PACKAGE/"
cp -- assets/voices/CREDITS.txt "$TASK_PACKAGE/VOICE-CREDITS.txt"
cp -- .tools/GODOT-LICENSE.txt "$TASK_PACKAGE/GODOT-LICENSE.txt"
cp -- .tools/GODOT-COPYRIGHT.txt "$TASK_PACKAGE/GODOT-COPYRIGHT.txt"
cat > "$TASK_PACKAGE/play.sh" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail
TASK_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec "$TASK_DIR/CommandPower" --main-pack "$TASK_DIR/CommandPower.pck" "$@"
LAUNCHER
chmod +x "$TASK_PACKAGE/play.sh"
rm -f -- "$TASK_ROOT/dist/CommandPower-linux-x86_64.zip"
(cd -- "$TASK_ROOT/dist" && zip -qr CommandPower-linux-x86_64.zip CommandPower-linux-x86_64)
printf 'Built %s\nArchive: %s\n' "$TASK_PACKAGE/play.sh" "$TASK_ROOT/dist/CommandPower-linux-x86_64.zip"
