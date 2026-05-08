extends Node

## Polls GitHub Releases for a newer build and emits a signal so the UI
## can show an "Update available" banner. Tapping the banner opens the
## release page in the system browser (Chrome on Android), where the
## user downloads + installs the APK manually.
##
## Phase 2B will replace the shell_open hand-off with a native
## DownloadManager + install-intent flow once the custom Android build
## template is in place.

const RELEASES_URL := "https://api.github.com/repos/Shadaeiou/homebrewer/releases?per_page=10"

signal update_available(latest_name: String, latest_code: int, release_url: String)
signal update_check_finished(found: bool)

var _http: HTTPRequest
var latest_name: String = ""
var latest_code: int = 0
var latest_url: String = ""

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	# Defer slightly so the home scene is fully laid out before we emit.
	await get_tree().create_timer(1.0).timeout
	check_for_updates()

func check_for_updates() -> void:
	var headers := PackedStringArray([
		"Accept: application/vnd.github+json",
		"User-Agent: homebrewer-updater",
	])
	var err := _http.request(RELEASES_URL, headers)
	if err != OK:
		push_warning("Updater: HTTPRequest.request() returned %d" % err)
		update_check_finished.emit(false)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("Updater: request failed result=%d code=%d" % [result, response_code])
		update_check_finished.emit(false)
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Updater: unexpected response shape")
		update_check_finished.emit(false)
		return

	var best_code := 0
	var best_name := ""
	var best_url := ""
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var tag: String = entry.get("tag_name", "")
		var parsed_pair := _parse_tag(tag)
		if parsed_pair.is_empty():
			continue
		var code: int = parsed_pair["code"]
		if code > best_code:
			best_code = code
			best_name = parsed_pair["name"]
			best_url = entry.get("html_url", "")

	if best_code == 0:
		update_check_finished.emit(false)
		return

	latest_name = best_name
	latest_code = best_code
	latest_url = best_url

	if best_code > Version.version_code:
		update_available.emit(best_name, best_code, best_url)
	update_check_finished.emit(true)

## Parse a tag like "v0.2.8+8" into {"name": "0.2.8", "code": 8}.
## Returns {} if the tag doesn't match the expected shape.
func _parse_tag(tag: String) -> Dictionary:
	var t := tag.lstrip("v")
	var plus := t.find("+")
	if plus < 0:
		return {}
	var name := t.substr(0, plus)
	var code_str := t.substr(plus + 1)
	if not code_str.is_valid_int():
		return {}
	return {"name": name, "code": int(code_str)}

func open_release_page() -> void:
	if latest_url.is_empty():
		return
	OS.shell_open(latest_url)
