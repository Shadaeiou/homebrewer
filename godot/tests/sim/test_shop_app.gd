extends GutTest

const SCENE := preload("res://scenes/phone/shop_app.tscn")

func _mount() -> Control:
	GameState.reset_to_new_career()
	var s: Control = SCENE.instantiate()
	add_child_autofree(s)
	return s

func _check(s: Control, ids: Array) -> void:
	for id in ids:
		if s._checkboxes.has(id):
			s._checkboxes[id].button_pressed = true
	s._render_totals()

func test_default_state_buy_disabled() -> void:
	var s := _mount()
	await wait_frames(1)
	assert_true(s._buy_button.disabled, "nothing selected → Buy disabled")

func test_required_only_27_dollars() -> void:
	# Per Appendix A: LME $18 + Cascade $4 + US-05 $4 + priming $1 = $27.
	var s := _mount()
	await wait_frames(1)
	_check(s, ["lme_light", "hops_cascade", "yeast_us05", "priming_sugar"])
	assert_eq(s._selected_total(), 27)
	assert_false(s._buy_button.disabled, "$27 against $30 should be affordable")

func test_overcap_buy_disabled() -> void:
	# Buying everything totals $51 ($18+4+4+1+4+8+12), well over the $30
	# starter capital — shortfall label + Buy disabled.
	var s := _mount()
	await wait_frames(1)
	for id in s._checkboxes:
		s._checkboxes[id].button_pressed = true
	s._render_totals()
	assert_true(s._buy_button.disabled)
	assert_string_contains(s._shortfall_label.text, "Short")

func test_buy_deducts_cash_and_populates_inventory() -> void:
	var s := _mount()
	await wait_frames(1)
	_check(s, ["lme_light", "hops_cascade", "yeast_us05", "priming_sugar"])
	assert_eq(int(GameState.data["cash"]["balance"]), 30)
	s._on_buy_pressed()
	await wait_frames(1)
	assert_eq(int(GameState.data["cash"]["balance"]), 3, "spent $27, $3 left")
	var ing: Dictionary = GameState.data["inventory"]["ingredients"]
	for id in ["lme_light", "hops_cascade", "yeast_us05", "priming_sugar"]:
		assert_true(ing.has(id), "%s should be in inventory" % id)
	# Star San is a consumable, not an ingredient.
	assert_false(ing.has("star_san"))

func test_star_san_lands_in_consumables() -> void:
	var s := _mount()
	await wait_frames(1)
	_check(s, ["star_san"])
	s._on_buy_pressed()
	await wait_frames(1)
	assert_true(GameState.data["inventory"]["consumables"].has("star_san"))

func test_case_of_24_lands_in_bottles_available() -> void:
	var s := _mount()
	await wait_frames(1)
	_check(s, ["case_of_24"])
	# Fresh career has 24 available; buying a case adds 24 more.
	s._on_buy_pressed()
	await wait_frames(1)
	assert_eq(int(GameState.data["inventory"]["bottles"]["available"]), 48)

func test_buy_unblocks_start_brewing_validator() -> void:
	# End-to-end: empty fresh career → Start brewing has issues → buy
	# the required four → issues clear.
	var s := _mount()
	await wait_frames(1)
	assert_true(GameState.start_brewing_issues("apartment_pale_ale").size() >= 1)
	_check(s, ["lme_light", "hops_cascade", "yeast_us05", "priming_sugar"])
	s._on_buy_pressed()
	await wait_frames(1)
	assert_eq(GameState.start_brewing_issues("apartment_pale_ale").size(), 0)
