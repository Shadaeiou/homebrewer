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
]

const OUT_DIR := "res://../screenshots"
const VIEWPORT_SIZE := Vector2i(540, 960)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for spec in SCENES:
		await _capture(spec)
	quit()

func _capture(spec: Dictionary) -> void:
	var scene_name: String = spec.get("name", "unnamed")
	var path: String = spec.get("path", "")
	var frames: int = int(spec.get("frames", 3))

	var packed := load(path)
	if packed == null:
		push_error("Could not load scene: %s" % path)
		return

	var instance: Node = packed.instantiate()
	root.add_child(instance)
	root.content_scale_size = VIEWPORT_SIZE

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
