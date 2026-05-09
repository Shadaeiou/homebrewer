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

const STARTER_RECIPE_ID := "apartment_pale_ale"

@onready var day_label: Label = %DayLabel
@onready var cash_label: Label = %CashLabel
@onready var bottles_label: Label = %BottlesLabel
@onready var rest_button: Button = %RestButton
@onready var start_brewing_button: Button = %StartBrewingButton
@onready var start_brewing_hint: Label = %StartBrewingHint
@onready var version_label: Label = %VersionLabel
@onready var update_banner: PanelContainer = %UpdateBanner
@onready var update_label: Label = %UpdateLabel
@onready var update_button: Button = %UpdateButton
@onready var changelog_container: VBoxContainer = %ChangelogContainer

func _ready() -> void:
	version_label.text = Version.full()
	rest_button.pressed.connect(_on_rest_pressed)
	start_brewing_button.pressed.connect(_on_start_brewing_pressed)
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
	_render_start_brewing()

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
