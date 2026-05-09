extends Control

## Journal viewer per DESIGN.md 1.5 + 8.7. Reads the append-only
## brew_completed entries written by Pour & taste from
## user://journal.jsonl and renders them as a scroll of cards in
## reverse-chronological order.
##
## v1 surfaces only the brew header + actual numbers + grades. The
## design's full journal also lists per-interaction outcomes, risk-
## profile reveals, and the canonical post-mortem teaching moments;
## those are additive on top of this baseline once the journal
## becomes the in-fiction "brewery journal" UI per 1.5.

signal closed

@onready var _close_button: Button = %CloseButton
@onready var _list: VBoxContainer = %JournalList
@onready var _empty_label: Label = %EmptyLabel

func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_render_entries()

func _on_close_pressed() -> void:
	closed.emit()
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("clear_active_scene"):
		main.clear_active_scene()

func _render_entries() -> void:
	for child in _list.get_children():
		child.queue_free()
	var entries: Array = SaveService.read_journal()
	# Filter to brew_completed shape and reverse so newest is at top.
	var brews: Array = []
	for e in entries:
		if e is Dictionary and String(e.get("type", "")) == "brew_completed":
			brews.append(e)
	brews.reverse()

	if brews.is_empty():
		_empty_label.visible = true
		return
	_empty_label.visible = false
	for entry in brews:
		_list.add_child(_card(entry))

func _card(entry: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	box.add_child(inner)

	var name_label := Label.new()
	name_label.text = String(entry.get("recipe_display_name", entry.get("recipe_id", "Brew")))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.84))
	inner.add_child(name_label)

	var grade_row := HBoxContainer.new()
	grade_row.add_theme_constant_override("separation", 12)
	inner.add_child(grade_row)

	var day_label := Label.new()
	day_label.text = "Day %d" % int(entry.get("day_completed", 0))
	day_label.add_theme_font_size_override("font_size", 12)
	day_label.add_theme_color_override("font_color", Color(0.78, 0.74, 0.70))
	grade_row.add_child(day_label)

	var self_grade := String(entry.get("self_grade", "?"))
	var ext_grade := String(entry.get("external_grade", "?"))
	var self_label := Label.new()
	self_label.text = "Self %s" % self_grade
	self_label.add_theme_font_size_override("font_size", 12)
	self_label.add_theme_color_override("font_color", _grade_color(self_grade))
	grade_row.add_child(self_label)

	var ext_label := Label.new()
	ext_label.text = "Style %s" % ext_grade
	ext_label.add_theme_font_size_override("font_size", 12)
	ext_label.add_theme_color_override("font_color", _grade_color(ext_grade))
	grade_row.add_child(ext_label)

	var actuals: Dictionary = entry.get("actuals", {})
	if not actuals.is_empty():
		var stats := Label.new()
		stats.text = "OG %.3f · FG %.3f · IBU %.0f · ABV %.1f%% · carb %.0f%%" % [
			float(actuals.get("og", 0.0)),
			float(actuals.get("fg", 0.0)),
			float(actuals.get("ibu", 0.0)),
			float(actuals.get("abv", 0.0)),
			float(actuals.get("carbonation", 0.0)) * 100.0,
		]
		stats.add_theme_font_size_override("font_size", 11)
		stats.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
		inner.add_child(stats)
	return box

func _grade_color(grade: String) -> Color:
	match grade:
		"A+", "A": return Color(0.55, 0.90, 0.55)
		"A-", "B": return Color(0.85, 0.85, 0.55)
		"C":       return Color(0.95, 0.78, 0.32)
		"D":       return Color(0.95, 0.55, 0.30)
		_:         return Color(0.95, 0.35, 0.30)
