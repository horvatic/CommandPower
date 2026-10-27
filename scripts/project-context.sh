#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$TASK_ROOT"
printf 'Project: %s\n' "$TASK_ROOT"
for task_file in AGENTS.md docs/DESIGN.md docs/Factions.md project.godot scripts/main.gd scripts/simulation.gd scripts/catalog.gd scripts/battlefield_view.gd scripts/build.sh tests/run.sh; do
  if [[ -f "$task_file" ]]; then printf 'present %s\n' "$task_file"; else printf 'missing %s\n' "$task_file"; fi
done
if [[ -x .tools/godot ]]; then .tools/godot --version; else printf 'Engine: not installed; run ./scripts/setup-engine.sh\n'; fi
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then git status --short; else printf 'Git: this directory is not a working repository\n'; fi
