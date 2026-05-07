# Tests

Unit tests for the brewing simulation (recipe math, infection rolls, fermentation curves) live here.

## Stack

We use [GUT](https://github.com/bitwes/Gut) (Godot Unit Test). It's added as a git submodule (or vendored — see `.gitmodules`) at `godot/addons/gut/`.

## Running

From the repo root:

```bash
scripts/dev-check.sh           # imports + parses + runs all tests + renders screenshots
```

Or just the tests:

```bash
cd godot
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/ -gexit
```

## Conventions

- Test files: `test_<thing>.gd`, classes inherit from `GutTest`.
- Pure-domain tests (no scene tree needed) live in `tests/sim/`.
- Scene-shaped tests (need a `SceneTree`) live in `tests/scene/`.
- Don't test Godot — test your own code. If a test would be "does Godot's HBoxContainer lay out correctly", delete it.

The first real test will land alongside the brewing recipe model.
