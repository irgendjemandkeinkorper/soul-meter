#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${GODOT_BIN:-godot}" --path "$project_root" \
  res://world/fixtures/structure_yard.tscn -- capture-scene
