extends Node

## Reports the current build's version name + code.
##
## `versionName` is read from ProjectSettings (application/config/version),
## which CI overwrites at export time to match `0.1.<gitCommitCount>`.
## `versionCode` is the integer commit count, set via env var GODOT_VERSION_CODE
## at export time and baked into a generated res://data/version.cfg.

const VERSION_FILE := "res://data/version.cfg"

var version_name: String = ""
var version_code: int = 0

func _ready() -> void:
	version_name = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	version_code = _read_version_code()

func _read_version_code() -> int:
	if not FileAccess.file_exists(VERSION_FILE):
		return 0
	var cfg := ConfigFile.new()
	var err := cfg.load(VERSION_FILE)
	if err != OK:
		return 0
	return int(cfg.get_value("version", "code", 0))

func full() -> String:
	return "v%s (build %d)" % [version_name, version_code]
