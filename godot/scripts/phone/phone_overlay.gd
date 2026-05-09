extends Control

## Phone overlay per DESIGN.md 1.4 + 7.2. Lives on PhoneLayer (layer=50).
## Pauses the rest of the tree while up so the brewing-day clock /
## anomalies don't run while the player's reading messages.
##
## v1 ships Messages (Marcus thread) as the only fully-wired app —
## that's the cold open from Appendix A. Shop / Forum / News / Calendar
## are placeholder tiles in the grid; tapping them shows a "coming soon"
## stub. The Phone overlay itself is the architectural piece this commit
## lands so each app can drop in as it gets built.

signal closed

const APPS := [
	{"id": "messages", "label": "Messages",  "scene": preload("res://scenes/phone/messages_app.tscn"), "available": true},
	{"id": "shop",     "label": "Shop",      "scene": preload("res://scenes/phone/shop_app.tscn"),     "available": true},
	{"id": "forum",    "label": "Forum",     "scene": null,  "available": false},
	{"id": "news",     "label": "News",      "scene": null,  "available": false},
	{"id": "calendar", "label": "Calendar",  "scene": null,  "available": false},
]

@onready var _back_button: Button = %BackButton
@onready var _close_button: Button = %CloseButton
@onready var _title_label: Label = %TitleLabel
@onready var _grid_container: GridContainer = %AppGrid
@onready var _content_slot: PanelContainer = %ContentSlot
@onready var _placeholder_label: Label = %PlaceholderLabel

var _current_app: Control = null

func _ready() -> void:
	# Run while tree is paused so phone input still works.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_back_button.pressed.connect(_on_back_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_render_grid()
	_show_grid()

func _render_grid() -> void:
	for child in _grid_container.get_children():
		child.queue_free()
	for app in APPS:
		var btn := Button.new()
		btn.text = String(app["label"])
		btn.custom_minimum_size = Vector2(0, 80)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not bool(app["available"]):
			btn.disabled = true
			btn.text += "\n(coming soon)"
		else:
			var id := String(app["id"])
			btn.pressed.connect(func(): _show_app(id))
		_grid_container.add_child(btn)

func _show_grid() -> void:
	_clear_app()
	_grid_container.visible = true
	_back_button.visible = false
	_title_label.text = "Phone"
	_placeholder_label.visible = true

func _show_app(app_id: String) -> void:
	for app in APPS:
		if String(app["id"]) == app_id:
			_clear_app()
			var packed: PackedScene = app["scene"]
			if packed == null:
				return
			_current_app = packed.instantiate()
			# Pass the overlay reference in case the app needs to swap
			# its own internal sub-view (e.g. messages → recipe card).
			if _current_app.has_method("set_phone_overlay"):
				_current_app.set_phone_overlay(self)
			_content_slot.add_child(_current_app)
			_grid_container.visible = false
			_back_button.visible = true
			_title_label.text = String(app["label"])
			_placeholder_label.visible = false
			return

func _clear_app() -> void:
	if _current_app != null:
		_current_app.queue_free()
		_current_app = null

func set_app_title(text: String) -> void:
	## Apps call this to update the header crumb when they navigate
	## into a sub-view (Messages → Marcus thread → recipe card).
	_title_label.text = text

func _on_back_pressed() -> void:
	# If the current app wants to handle Back internally (e.g. messages
	# popping a recipe-card sub-view), give it a chance.
	if _current_app != null and _current_app.has_method("on_phone_back"):
		var consumed: bool = _current_app.on_phone_back()
		if consumed:
			return
	_show_grid()

func _on_close_pressed() -> void:
	closed.emit()
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("pop_phone"):
		main.pop_phone()
