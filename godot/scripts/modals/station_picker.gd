extends Control

## Bottom-anchored modal that lists owned equipment compatible with the
## given station. The dashboard pushes one of these via Main.push_modal
## and listens for `item_picked(equipment_id)` to act on the choice.

signal item_picked(equipment_id: String)

@onready var _title: Label = %Title
@onready var _items: VBoxContainer = %Items
@onready var _cancel_button: Button = %CancelButton

var station: int = -1
var title_text: String = "What goes here?"

func _ready() -> void:
	_title.text = title_text
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_render_items()

func _render_items() -> void:
	for child in _items.get_children():
		child.queue_free()
	var ids: Array = EquipmentDefs.owned_at_station(station)
	if ids.is_empty():
		var empty := Label.new()
		empty.text = "Nothing in your inventory fits here."
		empty.add_theme_font_size_override("font_size", 13)
		empty.modulate = Color(0.78, 0.74, 0.70, 1)
		_items.add_child(empty)
		return
	for id in ids:
		_items.add_child(_make_row(String(id)))

func _make_row(equipment_id: String) -> Control:
	var row := Button.new()
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0, 56)
	row.text = "%s  —  %s" % [
		EquipmentDefs.display(equipment_id),
		EquipmentDefs.hint(equipment_id),
	]
	row.add_theme_font_size_override("font_size", 14)
	row.pressed.connect(func(): _on_item_pressed(equipment_id))
	return row

func _on_item_pressed(equipment_id: String) -> void:
	item_picked.emit(equipment_id)
	_close()

func _on_cancel_pressed() -> void:
	_close()

func _close() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("pop_modal"):
		main.pop_modal()
	else:
		queue_free()
