extends Control

## Settings tile in the phone overlay. Houses things that don't fit
## into the apartment-as-game model: version, changelog, and the dev
## reset button. The dashboard's HUD is purely environmental now.

@onready var _version_label: Label = %VersionLabel
@onready var _changelog_container: VBoxContainer = %ChangelogContainer
@onready var _reset_button: Button = %ResetButton
@onready var _reset_dialog: ConfirmationDialog = %ResetConfirmDialog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_version_label.text = Version.full()
	_reset_button.pressed.connect(func(): _reset_dialog.popup_centered())
	_reset_dialog.confirmed.connect(func(): SaveService.wipe_and_reset())
	_render_changelog()

func _render_changelog() -> void:
	for child in _changelog_container.get_children():
		child.queue_free()
	var latest: Dictionary = Changelog.latest()
	if latest.is_empty():
		var empty := Label.new()
		empty.text = "No changelog entries yet."
		_changelog_container.add_child(empty)
		return
	_changelog_container.add_child(_entry_view(latest, true))
	for entry in Changelog.older():
		_changelog_container.add_child(_entry_view(entry, false))

func _entry_view(entry: Dictionary, _is_latest: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var header := Label.new()
	header.text = "%s · %s" % [entry.get("version", "?"), entry.get("date", "")]
	header.add_theme_font_size_override("font_size", 16)
	header.modulate = Color(0.96, 0.78, 0.32)
	box.add_child(header)
	for bullet in entry.get("bullets", []):
		var line := Label.new()
		line.text = "• %s" % bullet
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 12)
		box.add_child(line)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)
	return box
