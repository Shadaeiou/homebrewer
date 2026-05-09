extends Control

## Messages app — single thread (Marcus) per Appendix A's cold open. The
## five-message thread is the player's first contact with the brewing
## prompt: party invite, the $30 startup capital, and the BREW MAGAZINE
## recipe attachment that opens the Apartment Pale Ale recipe card.
##
## Tapping the recipe attachment swaps the messages view for an inline
## recipe card. The phone overlay's Back button is wired to call
## on_phone_back() so navigating Marcus → recipe → Marcus works one
## level at a time before falling back to the app grid.
##
## v1 is read-only — no replies, no message authoring. Marcus stays
## the only thread until the NPC + relationship system lands.

const RECIPE_CARD := preload("res://scenes/phone/recipe_card.tscn")

const MARCUS_MESSAGES := [
	{"body": "yo party next saturday at my place"},
	{"body": "you said you might try brewing right? would be sick if you brought beer"},
	{"body": "no pressure but"},
	{"body": "Mom & Dad said they'd chip in $30 if you do it btw, called it your 'startup capital' lol"},
	{"type": "recipe_attachment", "recipe_id": "apartment_pale_ale",
		"label": "[image] torn page from BREW MAGAZINE"},
]

@onready var _thread_view: Control = %ThreadView
@onready var _recipe_slot: PanelContainer = %RecipeSlot
@onready var _bubble_list: VBoxContainer = %BubbleList
@onready var _sender_header: Label = %SenderHeader

var _phone_overlay: Control = null
var _recipe_card: Control = null

func _ready() -> void:
	_sender_header.text = "Marcus"
	_render_thread()
	_show_thread()

func set_phone_overlay(overlay: Control) -> void:
	_phone_overlay = overlay

func on_phone_back() -> bool:
	## Phone-overlay back button hook. If a recipe card is open, close it
	## and tell the overlay we consumed the press; otherwise fall through.
	if _recipe_card != null:
		_close_recipe()
		return true
	return false

func _render_thread() -> void:
	for child in _bubble_list.get_children():
		child.queue_free()
	for msg in MARCUS_MESSAGES:
		_bubble_list.add_child(_bubble(msg))

func _bubble(msg: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.custom_minimum_size = Vector2(200, 0)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	box.add_child(inner)

	var msg_type := String(msg.get("type", "text"))
	if msg_type == "recipe_attachment":
		var label := Label.new()
		label.text = String(msg.get("label", "[attachment]"))
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.78, 0.74, 0.70))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(label)
		var open_btn := Button.new()
		open_btn.text = "Open recipe"
		var rid: String = String(msg.get("recipe_id", ""))
		open_btn.pressed.connect(func(): _open_recipe(rid))
		inner.add_child(open_btn)
	else:
		var label := Label.new()
		label.text = String(msg.get("body", ""))
		label.add_theme_font_size_override("font_size", 13)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(label)
	return box

func _show_thread() -> void:
	_thread_view.visible = true
	_recipe_slot.visible = false
	if _phone_overlay != null and _phone_overlay.has_method("set_app_title"):
		_phone_overlay.set_app_title("Marcus")

func _open_recipe(recipe_id: String) -> void:
	_close_recipe()  # safety
	_recipe_card = RECIPE_CARD.instantiate()
	_recipe_card.recipe_id = recipe_id
	_recipe_slot.add_child(_recipe_card)
	_thread_view.visible = false
	_recipe_slot.visible = true
	if _phone_overlay != null and _phone_overlay.has_method("set_app_title"):
		_phone_overlay.set_app_title("Recipe")

func _close_recipe() -> void:
	if _recipe_card != null:
		_recipe_card.queue_free()
		_recipe_card = null
	_show_thread()
