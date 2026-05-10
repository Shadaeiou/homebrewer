#!/usr/bin/env bash
# Enforces the changelog-version rule from CLAUDE.md §2:
#
#   Every player-visible commit must update godot/data/changelog.json in the
#   same commit, and the new top entry's `version` must equal:
#       0.2.$(($(git rev-list --count HEAD) + 1))
#
# Two checks:
#   1. The top entry's version must be <= the version the next commit will
#      have. (Prevents typos that claim a future release.)
#   2. If you've modified godot/data/changelog.json (vs HEAD), the top entry's
#      version must match the next commit's version exactly.
#
# In CI mode ($CI=true) — the commit already happened, so the top entry must
# match THIS commit's version exactly. CI runs after my static-checks step in
# build-android.yml; failing here red-lights the build before any APK is
# produced (which is the point: a release with the wrong "What's new" would
# be very visible).
#
# This script CANNOT detect "forgot to update changelog.json on a player-
# visible commit" — that requires judgment about what's player-visible. The
# CLAUDE.md rule still relies on human discipline for that part. We just
# catch the mechanical version mismatch.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CHANGELOG="godot/data/changelog.json"

if [ ! -f "$CHANGELOG" ]; then
  echo "[changelog-check] FAIL: $CHANGELOG missing"
  exit 1
fi

if [ "${CI:-false}" = "true" ]; then
  expected_code=$(git rev-list --count HEAD)
  context="this commit"
else
  expected_code=$(($(git rev-list --count HEAD) + 1))
  context="the next commit"
fi
expected_version="0.2.$expected_code"

# Pull the top entry's version. Prefer jq; fall back to python3.
if command -v jq >/dev/null 2>&1; then
  top_version=$(jq -r '.[0].version' "$CHANGELOG")
else
  top_version=$(python3 -c "import json; print(json.load(open('$CHANGELOG'))[0]['version'])")
fi

if [ -z "$top_version" ] || [ "$top_version" = "null" ]; then
  echo "[changelog-check] FAIL: could not read top entry's version from $CHANGELOG"
  exit 1
fi

# All current versions are 0.2.<N>. If we ever bump the prefix, this stripping
# logic needs to follow.
case "$top_version" in
  0.2.*) top_code=${top_version#0.2.} ;;
  *)
    echo "[changelog-check] FAIL: top entry version $top_version is not in 0.2.<N> form. Update the version prefix in this script if you've intentionally bumped to 0.3.x."
    exit 1
    ;;
esac

if ! [[ "$top_code" =~ ^[0-9]+$ ]]; then
  echo "[changelog-check] FAIL: top entry version $top_version doesn't end with an integer"
  exit 1
fi

if [ "$top_code" -gt "$expected_code" ]; then
  echo "[changelog-check] FAIL: top changelog entry is $top_version, but $context will be $expected_version."
  echo "  Either fix the version field (typo? out-of-order edit?) or rebase to pick up the missing commits."
  exit 1
fi

# Strict-equality check fires only when this commit (CI) or the working
# tree (local) actually touches the changelog. An untouched changelog
# means an internal-only commit — allowed per CLAUDE.md §2.
touched_changelog=false
if [ "${CI:-false}" = "true" ]; then
  if ! git diff --quiet HEAD~1 HEAD -- "$CHANGELOG" 2>/dev/null; then
    touched_changelog=true
  fi
else
  if ! git diff --quiet HEAD -- "$CHANGELOG" 2>/dev/null; then
    touched_changelog=true
  fi
fi

if [ "$touched_changelog" = "true" ] && [ "$top_version" != "$expected_version" ]; then
  if [ "${CI:-false}" = "true" ]; then
    echo "[changelog-check] FAIL: this commit modified $CHANGELOG but the top entry version is $top_version, not the expected $expected_version (this commit's number)."
  else
    echo "[changelog-check] FAIL: you modified $CHANGELOG but the top entry version is $top_version."
    echo "  $context will be $expected_version — update the version field accordingly."
  fi
  exit 1
fi

echo "[changelog-check] ok (top=$top_version, $context=$expected_version)"
