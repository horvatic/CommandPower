#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TASK_PROFILE=$(mktemp -d "${TMPDIR:-/tmp}/commandpower-tests.XXXXXX")
trap 'rm -rf -- "$TASK_PROFILE"' EXIT
cd -- "$TASK_ROOT"
[[ -x .tools/godot ]] || ./scripts/setup-engine.sh
mkdir -p "$TASK_PROFILE/data" "$TASK_PROFILE/config" "$TASK_PROFILE/cache"
export XDG_DATA_HOME="$TASK_PROFILE/data" XDG_CONFIG_HOME="$TASK_PROFILE/config" XDG_CACHE_HOME="$TASK_PROFILE/cache"
export GODOT_SILENCE_ROOT_WARNING=1
if [[ ! -d .godot/imported ]]; then
  .tools/godot --headless --editor --path "$TASK_ROOT" --import
fi
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/simulation_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/building_actions_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/faction_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/skirmish_menu_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/skirmish_maps_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/minimap_cache_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/team_colors_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/projection_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/ui_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/music_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/voice_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/audio_settings_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/pause_menu_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/building_actions_ui_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/weapon_audio_test.gd

.tools/godot --headless --path "$TASK_ROOT" --script res://tests/announcer_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/announcer_events_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/expansion_gameplay_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/expansion_art_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/expansion_voice_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/expansion_ui_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/expansion_ai_test.gd
.tools/godot --headless --path "$TASK_ROOT" --script res://tests/synod_voice_test.gd
