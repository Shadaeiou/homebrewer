extends Control

## Dashboard — the apartment view, persistent across all states.
## Per DESIGN.md 7.2 + 4.1 (the day-clock advance is the player's
## "Get some rest" tap; auto-saves and re-renders the day's content).
##
## v1 dashboard is intentionally minimal:
##   - Title + day counter
##   - Cash + bottle inventory readouts
##   - "Get some rest" button (advances the day clock)
##   - Version label + update banner (kept from the prior bootstrap)
##   - Changelog scroll
##
## Dashboard, brewery view, and brewing-day surfaces will fill in as Section
## 6 (UX/UI) lands and as mini-games are built.

const BREWING_DAY_SCENE := preload("res://scenes/brewing_day.tscn")
const BOTTLING_SCENE     := preload("res://scenes/minigames/bottling.tscn")
const TASTING_SCENE      := preload("res://scenes/minigames/tasting.tscn")

const STARTER_RECIPE_ID := "apartment_pale_ale"

@onready var day_label: Label = %DayLabel
@onready var cash_label: Label = %CashLabel
@onready var bottles_label: Label = %BottlesLabel
@onready var rest_button: Button = %RestButton
@onready var brews_header: Label = %BrewsHeader
@onready var brews_list: VBoxContainer = %BrewsList
@onready var start_brewing_button: Button = %StartBrewingButton
@onready var start_brewing_hint: Label = %StartBrewingHint
@onready var version_label: Label = %VersionLabel
@onready var update_banner: PanelContainer = %UpdateBanner
@onready var update_label: Label = %UpdateLabel
@onready var update_button: Button = %UpdateButton
@onready var changelog_container: VBoxContainer = %ChangelogContainer
@onready var dev_reset_button: Button = %DevResetButton
@onready var reset_confirm_dialog: ConfirmationDialog = %ResetConfirmDialog

func _ready() -> void:
	version_label.text = Version.full()
	rest_button.pressed.connect(_on_rest_pressed)
	start_brewing_button.pressed.connect(_on_start_brewing_pressed)
	dev_reset_button.pressed.connect(_on_dev_reset_pressed)
	reset_confirm_dialog.confirmed.connect(_on_dev_reset_confirmed)
	Updater.update_available.connect(_on_update_available)
	update_button.pressed.connect(Updater.install_update)
	GameState.state_loaded.connect(_render_state)
	GameState.day_advanced.connect(_on_day_advanced)
	_render_changelog()
	# State may already be loaded by the time we mount (SaveService.load_now
	# is call_deferred from its _ready). Render whatever we've got.
	_render_state()

func _on_rest_pressed() -> void:
	# The canonical day-clock advance per 4.1. SaveService auto-saves on this.
	TimeService.advance_day()

func _on_dev_reset_pressed() -> void:
	reset_confirm_dialog.popup_centered()

func _on_dev_reset_confirmed() -> void:
	SaveService.wipe_and_reset()

func _on_day_advanced(_new_day: int) -> void:
	_render_state()

func _render_state() -> void:
	# Defensive: GameState.data may be {} for a frame between _ready and load.
	if GameState.data.is_empty():
		day_label.text = "Day 0"
		cash_label.text = "$ —"
		bottles_label.text = "Bottles: —"
		return
	day_label.text = "Day %d" % TimeService.day_clock
	var cash_data: Dictionary = GameState.data.get("cash", {})
	cash_label.text = "$%d" % int(cash_data.get("balance", 0))
	var inv: Dictionary = GameState.data.get("inventory", {})
	var bottles: Dictionary = inv.get("bottles", {})
	cash_label.text = "$%d" % int(cash_data.get("balance", 0))
	bottles_label.text = "Bottles: %d available · %d in use" % [
		int(bottles.get("available", 0)),
		int(bottles.get("in_use", 0)),
	]
	_render_brews_in_flight()
	_render_start_brewing()

func _render_brews_in_flight() -> void:
	for child in brews_list.get_children():
		child.queue_free()
	var brews: Array = GameState.data.get("brews_in_flight", [])
	if brews.is_empty():
		brews_header.visible = false
		return
	brews_header.visible = true
	for brew in brews:
		brews_list.add_child(_brew_row(brew))

func _brew_row(brew: Dictionary) -> Control:
	# Bridge UI for the post-brew gap: per Appendix B the dashboard will
	# eventually surface a daily checklist with "Check fermenter" perception
	# entries, ambient morning summary, anomaly cues, etc. Until that
	# fermentation rhythm lands (step 10), at least show the brew exists,
	# where it is in its arc, and a tappable action when it's ready.
	var stage: String = String(brew.get("stage", ""))
	var snapshot: Dictionary = brew.get("recipe_snapshot", {})
	var name: String = String(snapshot.get("display_name", brew.get("recipe_id", "Brew")))
	var elapsed: int = int(brew.get("days_elapsed_in_stage", 0))
	var brew_id: String = String(brew.get("brew_id", ""))

	var row := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	row.add_child(inner)

	var title := Label.new()
	title.text = name
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.95, 0.91, 0.84))
	inner.add_child(title)

	var status := Label.new()
	status.text = _stage_status_text(stage, elapsed, snapshot)
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", _stage_status_color(stage, elapsed, snapshot))
	inner.add_child(status)

	# Conditional action button when the brew has reached a tappable beat.
	var ferm_days: int = int(snapshot.get("fermentation_days", 5))
	var cond_days: int = int(snapshot.get("condition_days", 14))
	if stage == BrewState.STAGE_FERMENTING and elapsed >= ferm_days:
		var btn := Button.new()
		btn.text = "Bottle this brew"
		btn.pressed.connect(func(): _on_bottle_brew(brew_id))
		inner.add_child(btn)
	elif stage == BrewState.STAGE_BOTTLED_CONDITIONING and elapsed >= cond_days:
		var btn := Button.new()
		btn.text = "Pour & taste"
		btn.pressed.connect(func(): _on_taste_brew(brew_id))
		inner.add_child(btn)
	return row

func _on_bottle_brew(brew_id: String) -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("mount_active_scene"):
		main.mount_active_scene(BOTTLING_SCENE, func(inst): inst.brew_id = brew_id)

func _on_taste_brew(brew_id: String) -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("mount_active_scene"):
		main.mount_active_scene(TASTING_SCENE, func(inst): inst.brew_id = brew_id)

func _stage_status_text(stage: String, elapsed: int, snapshot: Dictionary) -> String:
	match stage:
		BrewState.STAGE_BREWING_DAY:
			return "Brewing day in progress"
		BrewState.STAGE_FERMENTING:
			var ferm_days: int = int(snapshot.get("fermentation_days", 5))
			if elapsed >= ferm_days:
				return "Fermenting · ready to bottle (day %d of %d)" % [elapsed, ferm_days]
			return "Fermenting · day %d of %d" % [elapsed, ferm_days]
		BrewState.STAGE_BOTTLED_CONDITIONING:
			var cond_days: int = int(snapshot.get("condition_days", 14))
			if elapsed >= cond_days:
				return "Conditioning · ready to drink (day %d of %d)" % [elapsed, cond_days]
			return "Conditioning · day %d of %d" % [elapsed, cond_days]
		_:
			return stage

func _stage_status_color(stage: String, elapsed: int, snapshot: Dictionary) -> Color:
	if stage == BrewState.STAGE_FERMENTING:
		var ferm_days: int = int(snapshot.get("fermentation_days", 5))
		if elapsed >= ferm_days:
			return Color(0.55, 0.90, 0.55)  # green — ready
	if stage == BrewState.STAGE_BOTTLED_CONDITIONING:
		var cond_days: int = int(snapshot.get("condition_days", 14))
		if elapsed >= cond_days:
			return Color(0.55, 0.90, 0.55)
	return Color(0.78, 0.74, 0.70)

func _render_start_brewing() -> void:
	var issues: Array = GameState.start_brewing_issues(STARTER_RECIPE_ID)
	# Disable + show why if there are blockers; otherwise enable + hide hint.
	if issues.is_empty():
		start_brewing_button.disabled = false
		start_brewing_hint.visible = false
	else:
		start_brewing_button.disabled = true
		start_brewing_hint.text = " · ".join(issues)
		start_brewing_hint.visible = true

func _on_start_brewing_pressed() -> void:
	# Re-validate at click time — state may have changed since last render.
	if not GameState.start_brewing_issues(STARTER_RECIPE_ID).is_empty():
		_render_start_brewing()
		return
	var recipe: RecipeDef = load("res://data/recipes/%s.tres" % STARTER_RECIPE_ID)
	var brew_id: String = GameState.make_brew_id()
	var seed: int = int(GameState.data.get("rng_state", {}).get("next_brew_seed", 0))
	var brew := BrewState.make_new(
		brew_id,
		STARTER_RECIPE_ID,
		recipe.to_snapshot(),
		TimeService.day_clock,
		seed,
	)
	GameState.data["brews_in_flight"].append(brew)
	# Roll the next brew seed so the seed actually changes between brews.
	GameState.data["rng_state"]["next_brew_seed"] = randi()

	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("mount_active_scene"):
		main.mount_active_scene(BREWING_DAY_SCENE, func(inst): inst.brew_id = brew_id)

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
