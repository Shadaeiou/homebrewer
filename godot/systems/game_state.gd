extends Node

## GameState — the fat state autoload per DESIGN.md 7.1.
##
## Holds the entire persistent player tree as a Dictionary that maps 1:1
## to Section 8.1's twelve entity groups. SaveService is the only thing
## that reads/writes this to disk.
##
## Cross-references inside the tree are by ID — equipment_used: [uuid]
## resolves against equipment.owned[uuid]. No dangling pointers.
##
## Eleven of the twelve entity groups live here; the brewing journal
## (entity #8) is its own JSONL file held by SaveService.

signal day_advanced(new_day: int)        ## Re-emitted from TimeService after we sync our cached day.
signal state_loaded                       ## Fires after SaveService loads us from disk (or initializes us fresh).

## v2 (2026-05-09): added _initial_equipment, _initial_recipe_knowledge,
## _initial_inventory bootstrap. v1 saves had empty owned/known/ingredients
## dicts and the dashboard's Start-brewing button can't validate against
## them. The migration in SaveService re-runs the bootstrap to fill them.
const SAVE_FORMAT_VERSION := 2

## Starter equipment per Appendix A's "Equipment present at start" table.
## Loaded from .tres archetypes when reset_to_new_career() seeds the tree.
const STARTER_EQUIPMENT_PATHS := [
	"res://data/equipment/apartment_stove.tres",
	"res://data/equipment/apartment_stockpot.tres",
	"res://data/equipment/plastic_bucket_fermenter.tres",
	"res://data/equipment/long_plastic_spoon.tres",
	"res://data/equipment/bi_metal_thermometer.tres",
	"res://data/equipment/wing_capper.tres",
	"res://data/equipment/measuring_pitcher.tres",
	"res://data/equipment/funnel.tres",
]

const STARTER_RECIPE_PATHS := [
	"res://data/recipes/apartment_pale_ale.tres",
]

var data: Dictionary = {}                 ## The whole tree. Initialized via reset_to_new_career().

func _ready() -> void:
	TimeService.day_advanced.connect(_on_day_advanced)

func reset_to_new_career(destination_id: String = "home_town") -> void:
	## Initial-state factory for a brand-new career. SaveService calls this when
	## no save file exists. Numbers are placeholders to be tuned in playtest.
	data = {
		"player_meta": {
			"save_format_version": SAVE_FORMAT_VERSION,
			"prestige_count": 0,
			"current_destination_id": destination_id,
			"settings": {
				"audio_master": 1.0,
				"audio_sfx": 1.0,
				"audio_music": 1.0,
				"haptic_enabled": true,
				"reduce_motion": false,
			},
		},
		"cash": {
			"balance": 30,                # Per Appendix A: $30 startup capital
			"outstanding_loans": [],
			"customer_advances": [],
			"recurring_bills": [],
		},
		"skills": _initial_skills(),
		"equipment": {
			"owned": _initial_equipment(),
		},
		"inventory": _initial_inventory(),
		"recipe_knowledge": {
			"known": _initial_recipe_knowledge(),
			"invented": [],
			"pinned_for_prestige": "",
		},
		"brews_in_flight": [],
		"npcs": {},
		"calendar": {
			"open_commitments": [],
			"closed_commitments": [],
		},
		"phone_world": {
			"forum": {"threads_seen": [], "threads_posted": [], "threads_mentioned_in": []},
			"news": {"articles_seen": [], "current_trends": []},
			"social": {"follower_count": 0, "posts": []},
			"shop": {"last_browsed_items": [], "items_unlocked": []},
			"regional_water_profile_id": "default",
		},
		"rng_state": {
			"world_anomaly_seed": randi(),
			"next_brew_seed": randi(),
		},
	}
	# Sync the day clock — fresh career starts at day 0.
	TimeService.day_clock = 0
	state_loaded.emit()

func adopt(loaded_data: Dictionary) -> void:
	## Called by SaveService.load() with the deserialized tree. Replaces our
	## current state. Caller is responsible for migration before adopt.
	data = loaded_data
	# Sync the day clock from the save's record. The save format doesn't store
	# day_clock directly today — it's implicit in brew/calendar state — so we
	# default to 0. When a v2 save format adds it, change here.
	TimeService.day_clock = 0
	state_loaded.emit()

func _initial_skills() -> Dictionary:
	# Six axes per 3.4. All start at level 0; water_chem stays unlocked=false
	# until the player owns a pH meter (per 3.4 + 8.6).
	return {
		"sanitation":   {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
		"temp_control": {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
		"timing":       {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
		"process":      {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
		"palate":       {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
		"water_chem":   {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": false},
	}

func _initial_equipment() -> Dictionary:
	## One instance per starter archetype. instance_id is deterministic
	## (`<archetype_id>_1`) — when the player buys a second of the same
	## archetype later, the new instance gets `_2`. Per-instance dynamic
	## state (`state`, `sanitized_at_day`, `uses_since_clean`) lives here;
	## static properties stay on the .tres archetype and are looked up
	## by archetype_id.
	var owned: Dictionary = {}
	for path in STARTER_EQUIPMENT_PATHS:
		var arche: EquipmentArchetype = load(path)
		if arche == null:
			push_error("[GameState] could not load equipment archetype: %s" % path)
			continue
		var instance_id: String = "%s_1" % arche.archetype_id
		owned[instance_id] = {
			"instance_id": instance_id,
			"archetype_id": arche.archetype_id,
			"state": arche.starting_state,
			"sanitized_at_day": -1,
			"uses_since_clean": 0,
		}
	return owned

func _initial_inventory() -> Dictionary:
	## v1 stopgap: pre-seed enough ingredients + consumables to brew the
	## starter Apartment Pale Ale once. The canonical Appendix A flow has
	## the player buy these from the Homebrew Supply phone app with the
	## $30 starter capital — that flow is deferred until the phone overlay
	## (step 10) lands. Until then, every fresh career starts already
	## "shopped" so the brewing flow is reachable. When the shop ships,
	## seed an empty inventory here and let the player make the first
	## real cash trade-off.
	return {
		"ingredients": {
			"lme_light":     {"name": "Light Malt Extract (LME)", "qty": 6.0, "unit": "lb"},
			"hops_cascade":  {"name": "Cascade",                  "qty": 2.0, "unit": "oz"},
			"yeast_us05":    {"name": "US-05 dry ale",            "qty": 1,   "unit": "packet"},
			"priming_sugar": {"name": "Priming sugar",            "qty": 5.0, "unit": "oz"},
			"water_tap":     {"name": "Tap water",                "qty": 999, "unit": "gal"},
		},
		"bottles": {"available": 24, "in_use": 0},  # Per 4.2: starter kit
		"consumables": {
			"dish_soap": {"qty": 1, "unit": "bottle"},
			"sponge":    {"qty": 1, "unit": "piece"},
		},
	}

func _initial_recipe_knowledge() -> Dictionary:
	## Seed every recipe in STARTER_RECIPE_PATHS as known + unlocked.
	## v1 starts with just Apartment Pale Ale per 3.8 + Appendix A.
	var known: Dictionary = {}
	for path in STARTER_RECIPE_PATHS:
		var recipe: RecipeDef = load(path)
		if recipe == null:
			push_error("[GameState] could not load recipe: %s" % path)
			continue
		known[recipe.recipe_id] = {
			"recipe_id": recipe.recipe_id,
			"unlocked_on_day": 0,
			"times_brewed": 0,
		}
	return known

func free_fermenter_count() -> int:
	## Per 4.2: a brewing day requires at least one free fermenter at start.
	## A fermenter is "in use" while a brew is FERMENTING in it; once the
	## brew bottles, the fermenter frees up.
	var fermenters := 0
	var owned: Dictionary = data.get("equipment", {}).get("owned", {})
	for instance_id in owned:
		var inst: Dictionary = owned[instance_id]
		var archetype_path: String = "res://data/equipment/%s.tres" % inst.get("archetype_id", "")
		var arche: EquipmentArchetype = load(archetype_path)
		if arche != null and arche.category == "fermenter":
			fermenters += 1
	var in_use := 0
	for b in data.get("brews_in_flight", []):
		if String(b.get("stage", "")) == BrewState.STAGE_FERMENTING:
			in_use += 1
	return max(0, fermenters - in_use)

func start_brewing_issues(recipe_id: String) -> Array:
	## Returns a human-readable list of reasons the player can't begin
	## a brewing day for `recipe_id` right now. Empty array → ready.
	var issues: Array = []
	var known: Dictionary = data.get("recipe_knowledge", {}).get("known", {})
	if not known.has(recipe_id):
		issues.append("Recipe not unlocked")
		return issues
	if free_fermenter_count() <= 0:
		issues.append("No fermenter available — bottle a brew first")
	# v1 ingredient check: any ingredient row missing from inventory.ingredients
	# blocks the brew. The pre-seeded inventory satisfies this for APA; once
	# the shop is built the player can land here legitimately broke.
	var ingredients: Dictionary = data.get("inventory", {}).get("ingredients", {})
	var recipe: RecipeDef = load("res://data/recipes/%s.tres" % recipe_id)
	if recipe != null:
		if not ingredients.has("lme_light") and recipe.method == "EXTRACT":
			issues.append("Need malt extract")
		if not ingredients.has("hops_cascade"):
			issues.append("Need hops")
		if not ingredients.has("yeast_us05"):
			issues.append("Need yeast")
	return issues

func make_brew_id() -> String:
	## Stable, unique brew id. Time-based; collisions only on sub-millisecond
	## double-fires which the UI prevents anyway.
	return "brew_%d" % Time.get_ticks_msec()

func _on_day_advanced(new_day: int) -> void:
	day_advanced.emit(new_day)
