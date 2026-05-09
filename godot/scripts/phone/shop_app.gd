extends Control

## Homebrew Supply shop per Appendix A's "Shopping" beat. Recipe-driven
## shopping list with prices that don't fit the $30 starter capital —
## the player has to skip something. This is "the first real choice the
## game asks" (Appendix A 1573).
##
## v1 scope: the canonical six-item APA list, single-purchase per tap,
## items go straight into inventory.ingredients / inventory.consumables.
## v1 does NOT deplete ingredients during brewing — one purchase carries
## arbitrarily many brews. That sim layer lands when the inventory
## consumption pass does, alongside the "running low" morning cues.

const SHOP_ITEMS := [
	{"id": "lme_light",     "label": "Light Malt Extract — 6 lb tin",
		"price": 18, "category": "ingredient", "qty": 6.0, "unit": "lb",
		"display_name": "Light Malt Extract (LME)"},
	{"id": "hops_cascade",  "label": "Cascade hops — 2 oz",
		"price": 4,  "category": "ingredient", "qty": 2.0, "unit": "oz",
		"display_name": "Cascade"},
	{"id": "yeast_us05",    "label": "US-05 dry ale yeast",
		"price": 4,  "category": "ingredient", "qty": 1,   "unit": "packet",
		"display_name": "US-05 dry ale"},
	{"id": "priming_sugar", "label": "Priming sugar — 5 oz",
		"price": 1,  "category": "ingredient", "qty": 5.0, "unit": "oz",
		"display_name": "Priming sugar"},
	{"id": "water_spring",  "label": "Bottled spring water — 5 gal jug",
		"price": 4,  "category": "ingredient", "qty": 5.0, "unit": "gal",
		"display_name": "Bottled spring water"},
	{"id": "star_san",      "label": "Star San sanitizer — 8 oz",
		"price": 8,  "category": "consumable", "qty": 1,   "unit": "bottle",
		"display_name": "Star San"},
	{"id": "case_of_24",    "label": "Case of 24 empty 12oz bottles",
		"price": 12, "category": "bottles",    "qty": 24,  "unit": "bottle",
		"display_name": "Empty bottles"},
]

@onready var _cash_label: Label = %CashLabel
@onready var _total_label: Label = %TotalLabel
@onready var _shortfall_label: Label = %ShortfallLabel
@onready var _items_container: VBoxContainer = %ItemsContainer
@onready var _buy_button: Button = %BuyButton

var _phone_overlay: Control = null
var _checkboxes: Dictionary = {}  # item_id → CheckBox

func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_pressed)
	_render_items()
	_render_totals()

func set_phone_overlay(overlay: Control) -> void:
	_phone_overlay = overlay

func _render_items() -> void:
	for child in _items_container.get_children():
		child.queue_free()
	_checkboxes.clear()
	for item in SHOP_ITEMS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var box := CheckBox.new()
		box.text = String(item["label"])
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var item_id: String = String(item["id"])
		box.toggled.connect(func(_b): _render_totals())
		_checkboxes[item_id] = box
		row.add_child(box)

		var price_label := Label.new()
		price_label.text = "$%d" % int(item["price"])
		price_label.custom_minimum_size = Vector2(40, 0)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.32))
		row.add_child(price_label)
		_items_container.add_child(row)

func _render_totals() -> void:
	var cash: int = int(GameState.data.get("cash", {}).get("balance", 0))
	var total: int = _selected_total()
	_cash_label.text = "Cash: $%d" % cash
	_total_label.text = "Total: $%d" % total
	if total == 0:
		_shortfall_label.text = "Pick what to buy."
		_shortfall_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
		_buy_button.disabled = true
	elif total > cash:
		_shortfall_label.text = "Short $%d. Skip something." % (total - cash)
		_shortfall_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.30))
		_buy_button.disabled = true
	else:
		_shortfall_label.text = "$%d left after this." % (cash - total)
		_shortfall_label.add_theme_color_override("font_color", Color(0.55, 0.90, 0.55))
		_buy_button.disabled = false

func _selected_total() -> int:
	var sum: int = 0
	for item in SHOP_ITEMS:
		var box: CheckBox = _checkboxes.get(String(item["id"]), null)
		if box != null and box.button_pressed:
			sum += int(item["price"])
	return sum

func _on_buy_pressed() -> void:
	var total: int = _selected_total()
	var cash: int = int(GameState.data.get("cash", {}).get("balance", 0))
	if total <= 0 or total > cash:
		return  # button should be disabled, defensive

	# Deduct cash.
	GameState.data["cash"]["balance"] = cash - total

	# Move purchased items into the right inventory bucket.
	var inv: Dictionary = GameState.data.get("inventory", {})
	var ingredients: Dictionary = inv.get("ingredients", {})
	var consumables: Dictionary = inv.get("consumables", {})
	var bottles: Dictionary = inv.get("bottles", {"available": 0, "in_use": 0})

	for item in SHOP_ITEMS:
		var box: CheckBox = _checkboxes.get(String(item["id"]), null)
		if box == null or not box.button_pressed:
			continue
		var category: String = String(item["category"])
		match category:
			"ingredient":
				_add_to_inventory_dict(ingredients, item)
			"consumable":
				_add_to_inventory_dict(consumables, item)
			"bottles":
				bottles["available"] = int(bottles.get("available", 0)) + int(item["qty"])

	inv["ingredients"] = ingredients
	inv["consumables"] = consumables
	inv["bottles"] = bottles
	GameState.data["inventory"] = inv

	# Reset checkboxes; refresh totals.
	for box in _checkboxes.values():
		box.set_pressed_no_signal(false)
	_render_totals()

	# Tell the dashboard to re-render — cash + inventory both moved.
	GameState.notify_state_loaded()
	SaveService.flush_now()

func _add_to_inventory_dict(target: Dictionary, item: Dictionary) -> void:
	var item_id: String = String(item["id"])
	var existing: Dictionary = target.get(item_id, {
		"name": String(item.get("display_name", item_id)),
		"qty": 0,
		"unit": String(item.get("unit", "")),
	})
	# Use a float for qty since some items use 0.5 oz etc.
	existing["qty"] = float(existing.get("qty", 0)) + float(item["qty"])
	existing["name"] = String(item.get("display_name", item_id))
	existing["unit"] = String(item.get("unit", ""))
	target[item_id] = existing
