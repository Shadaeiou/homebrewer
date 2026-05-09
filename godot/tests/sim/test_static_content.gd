extends GutTest

## Confirms the .tres files under res://data/ load with the expected
## fields. Cheap canary — if a .tres goes malformed (missing field,
## wrong type, dangling script ref) this fails before mini-game code
## starts dereferencing things.

const APA_PATH := "res://data/recipes/apartment_pale_ale.tres"
const STOCKPOT_PATH := "res://data/equipment/apartment_stockpot.tres"
const BUCKET_PATH := "res://data/equipment/plastic_bucket_fermenter.tres"
const THERMO_PATH := "res://data/equipment/bi_metal_thermometer.tres"
const CAPPER_PATH := "res://data/equipment/wing_capper.tres"
const APA_STYLE_PATH := "res://data/styles/american_pale_ale.tres"

func test_apartment_pale_ale_recipe_loads() -> void:
	var r: RecipeDef = load(APA_PATH)
	assert_not_null(r, "recipe must load")
	assert_eq(r.recipe_id, "apartment_pale_ale")
	assert_eq(r.style, "american_pale_ale")
	assert_eq(r.method, "EXTRACT")
	assert_almost_eq(r.target_og, 1.045, 1e-6)
	assert_almost_eq(r.target_fg, 1.012, 1e-6)
	assert_almost_eq(r.target_abv, 4.5, 1e-6)
	assert_eq(r.fermentation_days, 5)
	assert_eq(r.condition_days, 14)

func test_apartment_pale_ale_hop_schedule_matches_appendix_a() -> void:
	# Per Appendix A: 1 oz Cascade @ 60min, 0.5 oz @ 15min, 0.5 oz @ flameout.
	var r: RecipeDef = load(APA_PATH)
	assert_eq(r.hop_schedule.size(), 3, "three Cascade additions")
	for h in r.hop_schedule:
		assert_eq(h["item"], "Cascade")
	assert_almost_eq(float(r.hop_schedule[0]["weight_oz"]), 1.0, 1e-6)
	assert_eq(int(r.hop_schedule[0]["minutes_remaining"]), 60)
	assert_almost_eq(float(r.hop_schedule[1]["weight_oz"]), 0.5, 1e-6)
	assert_eq(int(r.hop_schedule[1]["minutes_remaining"]), 15)
	assert_eq(int(r.hop_schedule[2]["minutes_remaining"]), 0)

func test_apartment_pale_ale_yeast_us05() -> void:
	var r: RecipeDef = load(APA_PATH)
	assert_eq(r.yeast["item"], "US-05 dry ale")
	assert_almost_eq(float(r.yeast["attenuation"]), 0.75, 1e-6)

func test_apartment_pale_ale_fermentables_lme() -> void:
	var r: RecipeDef = load(APA_PATH)
	assert_eq(r.fermentables.size(), 1, "extract recipe: one LME entry")
	assert_eq(r.fermentables[0]["item"], "Light Malt Extract (LME)")
	assert_almost_eq(float(r.fermentables[0]["weight_lb"]), 6.0, 1e-6)

func test_apartment_stockpot_loads() -> void:
	var e: EquipmentArchetype = load(STOCKPOT_PATH)
	assert_not_null(e)
	assert_eq(e.archetype_id, "apartment_stockpot")
	assert_eq(e.category, "kettle")
	assert_eq(e.starting_state, "USED")  # per 3.2: "you've cooked pasta in it"
	assert_almost_eq(float(e.properties["volume_capacity_gal"]), 5.0, 1e-6)
	assert_eq(e.properties["volume_markings"], "NONE")
	assert_eq(e.properties["has_thermometer"], false)
	assert_almost_eq(float(e.properties["precision_for_volume"]), 0.4, 1e-6)

func test_plastic_bucket_fermenter_loads() -> void:
	var e: EquipmentArchetype = load(BUCKET_PATH)
	assert_eq(e.category, "fermenter")
	assert_eq(e.properties["transparent"], false)
	assert_eq(e.properties["airlock_grommet"], true)
	assert_eq(e.properties["thermotape_installed"], false)

func test_bi_metal_thermometer_loads() -> void:
	var e: EquipmentArchetype = load(THERMO_PATH)
	assert_eq(e.category, "thermometer")
	assert_eq(e.properties["type"], "ANALOG_BIMETAL")
	assert_almost_eq(float(e.properties["precision_f"]), 5.0, 1e-6)

func test_wing_capper_loads() -> void:
	var e: EquipmentArchetype = load(CAPPER_PATH)
	assert_eq(e.category, "capper")
	assert_eq(e.properties["type"], "WING")
	assert_eq(e.properties["requires_squeeze_gesture"], true)

func test_american_pale_ale_style_loads() -> void:
	var s: StyleProfile = load(APA_STYLE_PATH)
	assert_not_null(s)
	assert_eq(s.style_id, "american_pale_ale")
	# OG/IBU/ABV ranges roughly bracket the recipe targets.
	var r: RecipeDef = load(APA_PATH)
	assert_true(r.target_og >= s.og_min and r.target_og <= s.og_max,
		"recipe target OG should fall in the style range")
	assert_true(r.target_ibu >= s.ibu_min and r.target_ibu <= s.ibu_max,
		"recipe target IBU should fall in the style range")
