extends SceneTree

## Headless screenshot harness.
##
## Loads a list of scenes, advances each one N frames, captures the root
## viewport, and writes a PNG to user://screenshots/<name>.png (which is
## bind-mounted to repo-root/screenshots/ via --rendering-driver opengl3).
##
## Usage (from repo root):
##   cd godot
##   godot --headless --script res://tools/screenshot_harness.gd
##
## NOTE: --headless disables actual rendering. To get real pixels we need
## the OpenGL/Vulkan driver. The wrapper script (scripts/render_screenshots.sh)
## handles that and a Xvfb display when no GPU is present.

const SCENES := [
	{"name": "main", "path": "res://scenes/main.tscn", "frames": 5},
	{
		"name": "brew_flow_start",
		"path": "res://scenes/brew_flow.tscn",
		"frames": 3,
		"setup": "brew_flow_start",
	},
	{
		"name": "brew_flow_mid",
		"path": "res://scenes/brew_flow.tscn",
		"frames": 3,
		"setup": "brew_flow_mid",
	},
	{
		"name": "brew_flow_complete",
		"path": "res://scenes/brew_flow.tscn",
		"frames": 3,
		"setup": "brew_flow_complete",
	},
	{
		"name": "fill_kettle_ready",
		"path": "res://scenes/minigames/fill_kettle.tscn",
		"frames": 3,
		"setup": "fill_kettle_ready",
	},
	{
		"name": "fill_kettle_pouring",
		"path": "res://scenes/minigames/fill_kettle.tscn",
		"frames": 30,
		"setup": "fill_kettle_pouring",
	},
	{
		"name": "fill_kettle_done_a",
		"path": "res://scenes/minigames/fill_kettle.tscn",
		"frames": 30,
		"setup": "fill_kettle_done_a",
	},
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
		["Recipes", "res://data/recipes.gd"],
		["BrewSession", "res://scripts/sim/brew_session.gd"],
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
	var setup_kind: String = spec.get("setup", "")

	var packed := load(path)
	if packed == null:
		push_error("Could not load scene: %s" % path)
		return

	var instance: Node = packed.instantiate()
	root.add_child(instance)
	root.content_scale_size = VIEWPORT_SIZE

	# Wait one frame for _ready() so @onready vars resolve before we poke at state.
	await process_frame
	if setup_kind != "":
		_apply_setup(instance, setup_kind)

	for i in frames:
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

func _apply_setup(scene: Node, kind: String) -> void:
	# `--script` mode can't resolve autoload identifiers at parse time, so
	# we look them up via root each time. This runs only in the harness.
	var session: Node = root.get_node_or_null("BrewSession")
	var recipes: Node = root.get_node_or_null("Recipes")
	match kind:
		"brew_flow_start":
			session.reset()
			session.start(recipes.default_recipe())
			if scene.has_method("_render_stage_list"):
				scene._render_stage_list()
				scene._render_current()
		"brew_flow_mid":
			session.reset()
			session.start(recipes.default_recipe())
			for _i in range(4):
				session.record_ideal_outcome()
			if scene.has_method("_render_stage_list"):
				scene._render_stage_list()
				scene._render_current()
		"brew_flow_complete":
			session.reset()
			session.start(recipes.default_recipe())
			while session.active and not session.is_complete():
				session.record_ideal_outcome()
			if scene.has_method("_render_stage_list"):
				scene._render_stage_list()
				scene._render_current()
				scene._show_result(session.final_grade, session.final_summary)
		_:
			_apply_fill_kettle_setup(scene, kind)

func _apply_fill_kettle_setup(scene: Node, kind: String) -> void:
	if not scene.has_method("_on_pour_pressed"):
		return
	match kind:
		"fill_kettle_ready":
			pass  # default — empty kettle, faucet closed
		"fill_kettle_pouring":
			scene._on_pour_pressed()
			var water_p := scene.get_node("Stage/Kettle/Water")
			if water_p:
				water_p.fill_litres = 1.4
				water_p.pour_intensity = 1.0
				water_p.time_since_last_pour = 0.0
				if scene.has_method("_update_labels"):
					scene._update_labels()
				if scene.has_method("_update_gauge"):
					scene._update_gauge()
		"fill_kettle_done_a":
			# Land near target for an "A"-grade result modal.
			var water_d := scene.get_node("Stage/Kettle/Water")
			if water_d:
				water_d.fill_litres = 4.07
				water_d.pour_intensity = 0.0
				water_d.time_since_last_pour = 2.0
			scene.state = scene.State.PLAYING
			if scene.has_method("_update_labels"):
				scene._update_labels()
			if scene.has_method("_update_gauge"):
				scene._update_gauge()
			scene._on_done()
