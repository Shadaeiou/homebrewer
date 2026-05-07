#!/usr/bin/env bash
# Run the headless screenshot harness against the project.
#
# Usage (from repo root):
#   scripts/render_screenshots.sh
#
# Output: screenshots/<scene>.png

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_DIR="$REPO_ROOT/godot"
OUT_DIR="$REPO_ROOT/screenshots"

mkdir -p "$OUT_DIR"

cd "$GODOT_DIR"

# Make sure imports are up to date before we render.
godot --headless --import >/dev/null 2>&1 || true

# Render with software OpenGL through Xvfb. --headless disables rendering, so
# we use Xvfb instead and pass a real display.
xvfb-run -a godot \
  --rendering-driver opengl3 \
  --script res://tools/screenshot_harness.gd

echo
echo "Rendered to: $OUT_DIR"
ls -la "$OUT_DIR"
