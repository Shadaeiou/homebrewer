extends Control

## Recipe card — the BREW MAGAZINE attachment from Appendix A. Renders
## a RecipeDef as a printable-looking spread: name + tagline, ingredients
## list, target numbers, brewing notes. Read-only; this isn't where the
## player edits a recipe.

@onready var _name_label: Label = %NameLabel
@onready var _tagline_label: Label = %TaglineLabel
@onready var _ingredients_label: Label = %IngredientsLabel
@onready var _targets_label: Label = %TargetsLabel
@onready var _notes_label: Label = %NotesLabel

var recipe_id: String = ""

func _ready() -> void:
	if recipe_id == "":
		return
	var path: String = "res://data/recipes/%s.tres" % recipe_id
	var recipe: RecipeDef = load(path)
	if recipe == null:
		_name_label.text = "Recipe not found"
		return
	_name_label.text = recipe.display_name
	_tagline_label.text = "\"Bulletproof first batch. Forgiving. Tasty.\""

	# Build the ingredients line in Appendix A's format. (GDScript's %
	# operator doesn't support %g, so we format floats via String() to
	# strip trailing zeros manually.)
	var bits: PackedStringArray = PackedStringArray()
	for f in recipe.fermentables:
		bits.append("%s lb %s" % [_fmt_qty(f.get("weight_lb", 0)), String(f.get("item", ""))])
	for h in recipe.hop_schedule:
		var minutes: int = int(h.get("minutes_remaining", 0))
		var when_label: String = "@ flameout" if minutes == 0 else "@ %dmin" % minutes
		bits.append("%s oz %s %s" % [
			_fmt_qty(h.get("weight_oz", 0)),
			String(h.get("item", "")),
			when_label,
		])
	bits.append("1 packet %s" % String(recipe.yeast.get("item", "")))
	bits.append("%s gal water" % _fmt_qty(recipe.batch_size_gal))
	bits.append("%s oz priming sugar" % _fmt_qty(recipe.priming_sugar_oz))
	var joined: String = " · ".join(bits)
	_ingredients_label.text = "Ingredients (%s gal): %s" % [_fmt_qty(recipe.batch_size_gal), joined]

	_targets_label.text = "Targets: OG %.3f · FG %.3f · ABV %.1f%% · IBU %.0f" % [
		recipe.target_og, recipe.target_fg, recipe.target_abv, recipe.target_ibu,
	]

	_notes_label.text = "Boil %s gallons. Add LME late. Top off with cold water in the fermenter." % _fmt_qty(recipe.boil_volume_gal)

func _fmt_qty(v) -> String:
	# Strip trailing ".0" so "6.0 lb" reads as "6 lb"; keep one decimal
	# otherwise (Cascade additions are 0.5 oz, batch_size 5.0 gal etc.).
	var f := float(v)
	if f == floor(f):
		return str(int(f))
	return "%.1f" % f
