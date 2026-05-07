#!/usr/bin/env bash
# Run every static check we have, in order:
#   1. Godot project import (catches missing resources, malformed .tscn)
#   2. GDScript parse (loads scripts, catches syntax errors)
#   3. GUT unit tests (if installed)
#   4. Screenshot harness (re-renders screenshots/main.png)
#
# Exit non-zero if anything fails. Run before every commit.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_DIR="$REPO_ROOT/godot"

echo "[dev-check] godot import (catches parse errors, missing resources, broken .tscn)"
import_log="$(mktemp)"
(cd "$GODOT_DIR" && godot --headless --import 2>&1) | tee "$import_log" | tail -5
if grep -E 'SCRIPT ERROR|ERROR:' "$import_log" >/dev/null; then
  echo "[dev-check] FAIL: errors during import (see above)"
  exit 1
fi

if [ -d "$GODOT_DIR/addons/gut" ]; then
  echo "[dev-check] GUT tests"
  (cd "$GODOT_DIR" && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/ -gexit 2>&1) | tail -20
else
  echo "[dev-check] GUT not installed yet — skipping tests"
fi

echo "[dev-check] screenshot harness"
"$REPO_ROOT/scripts/render_screenshots.sh" 2>&1 | tail -3

echo
echo "[dev-check] ok"
