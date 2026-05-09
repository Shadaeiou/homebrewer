extends SceneTree

## Headless screenshot harness.
##
## Loads a list of scenes, advances each one N frames, captures the root
## viewport, and writes a PNG to user://screenshots/<name>.png.
##
## Usage (from repo root):
##   scripts/render_screenshots.sh
## (which wraps `godot --headless --script res://tools/screenshot_harness.gd`
## with Xvfb + opengl3 driver so we get real pixels in CI / on machines
## without a GPU.)

const SCENES := [
	{"name": "main", "path": "res://scenes/main.tscn", "frames": 5},
	{"name": "brewing_day", "path": "res://scenes/brewing_day.tscn", "frames": 5},
	{"name": "brewing_day_fill_kettle", "path": "res://scenes/brewing_day.tscn",
		"frames": 5, "props": {"initial_stage_index": 1}},
	{"name": "fill_kettle", "path": "res://scenes/minigames/fill_kettle.tscn", "frames": 5},
]

const OUT_DIR := "res://../screenshots"
const VIEWPORT_SIZE := Vector2i(540, 960)

func _initialize() -> void:
	# `--script` mode bypasses ProjectSettings autoload loading. Re-add the
	# autoloads we depend on so scripts that reference them globally don't
	# crash. Order matters when one autoload depends on another.
	_bootstrap_autoloads()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for spec in SCENES:
		await _capture(spec)
	quit()

func _bootstrap_autoloads() -> void:
	var autoloads := [
		["Palette", "res://systems/palette.gd"],
		["Lighting", "res://systems/lighting.gd"],
		["Changelog", "res://systems/changelog.gd"],
		["Version", "res://systems/version.gd"],
		["Updater", "res://systems/updater.gd"],
		["TimeService", "res://systems/time_service.gd"],
		["GameState", "res://systems/game_state.gd"],
		["SaveService", "res://systems/save_service.gd"],
	]
	for entry in autoloads:
		var alias_name: String = entry[0]
		var path: String = entry[1]
		if root.has_node(alias_name):
			continue
		var script: Script = load(path)
		var instance: Node = script.new()
		instance.name = alias_name
		root.add_child(instance)

func _capture(spec: Dictionary) -> void:
	var scene_name: String = spec.get("name", "unnamed")
	var path: String = spec.get("path", "")
	var frames: int = int(spec.get("frames", 3))

	var packed := load(path)
	if packed == null:
		push_error("Could not load scene: %s" % path)
		return

	var instance: Node = packed.instantiate()
	# Apply pre-_ready props so the scene wakes up with the harness's setup.
	var props: Dictionary = spec.get("props", {})
	for k in props:
		instance.set(String(k), props[k])
	root.add_child(instance)
	root.content_scale_size = VIEWPORT_SIZE

	# Wait one frame for _ready() so @onready vars resolve before we poke at state.
	await process_frame

	for _i in frames:
		await process_frame

	var image: Image = root.get_texture().get_image()
	if image == null:
		push_error("get_image() returned null for %s" % scene_name)
		instance.queue_free()
		return

	var out_path := "%s/%s.png" % [OUT_DIR, scene_name]
	var globalized := ProjectSettings.globalize_path(out_path)
	var err := image.save_png(globalized)
	if err != OK:
		push_error("save_png failed for %s: %s" % [scene_name, err])
	else:
		print("[harness] wrote %s" % globalized)

	instance.queue_free()
