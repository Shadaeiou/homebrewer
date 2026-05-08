extends Control

@onready var version_label: Label = %VersionLabel
@onready var changelog_container: VBoxContainer = %ChangelogContainer
@onready var update_banner: PanelContainer = %UpdateBanner
@onready var update_label: Label = %UpdateLabel
@onready var update_button: Button = %UpdateButton

func _ready() -> void:
	version_label.text = Version.full()
	_render_changelog()
	Updater.update_available.connect(_on_update_available)
	update_button.pressed.connect(Updater.install_update)

func _on_update_available(latest_name: String, latest_code: int, _release_url: String) -> void:
	update_label.text = "Update available: v%s (build %d)" % [latest_name, latest_code]
	update_banner.visible = true

func _render_changelog() -> void:
	for child in changelog_container.get_children():
		child.queue_free()

	var latest: Dictionary = Changelog.latest()
	if latest.is_empty():
		var empty := Label.new()
		empty.text = "No changelog entries yet."
		changelog_container.add_child(empty)
		return

	changelog_container.add_child(_entry_view(latest, true))
	for entry in Changelog.older():
		changelog_container.add_child(_entry_view(entry, false))

func _entry_view(entry: Dictionary, _is_latest: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = "%s · %s" % [entry.get("version", "?"), entry.get("date", "")]
	header.add_theme_font_size_override("font_size", 18)
	header.modulate = Color(0.95, 0.78, 0.32)
	box.add_child(header)

	for bullet in entry.get("bullets", []):
		var line := Label.new()
		line.text = "• %s" % bullet
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 14)
		box.add_child(line)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer)
	return box
