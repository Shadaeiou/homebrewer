extends Node

## Reports the current build's version name + code.
##
## Both come from ProjectSettings — CI sed-injects them into project.godot at
## export time so the values are baked into the engine config and definitely
## bundled. (An earlier version used a sidecar res://data/version.cfg, but
## .cfg files aren't included by export_filter="all_resources".)

var version_name: String = ""
var version_code: int = 0

func _ready() -> void:
	version_name = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	version_code = int(ProjectSettings.get_setting("application/config/version_code", 0))

func full() -> String:
	return "v%s (build %d)" % [version_name, version_code]
