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

const BREWING_DAY_SCENE     := preload("res://scenes/brewing_day.tscn")
const BOTTLING_SCENE         := preload("res://scenes/minigames/bottling.tscn")
const TASTING_SCENE          := preload("res://scenes/minigames/tasting.tscn")
const JOURNAL_SCENE          := preload("res://scenes/journal.tscn")
const CHECK_FERMENTER_MODAL  := preload("res://scenes/modals/check_fermenter.tscn")

const STARTER_RECIPE_ID := "apartment_pale_ale"

@onready var day_label: Label = %DayLabel
@onready var cash_label: Label = %CashLabel
@onready var bottles_label: Label = %BottlesLabel
@onready var rest_button: Button = %RestButton
@onready var morning_summary: Label = %MorningSummary
@onready var checklist_header: Label = %ChecklistHeader
@onready var checklist_list: VBoxContainer = %ChecklistList
@onready var journal_button: Button = %JournalButton
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
	journal_button.pressed.connect(_on_journal_pressed)
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

func _on_journal_pressed() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("mount_active_scene"):
		main.mount_active_scene(JOURNAL_SCENE)

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
	_render_morning_summary()
	_render_checklist()
	_render_start_brewing()

func _render_morning_summary() -> void:
	# Ambient context per 3.7 — never pre-discloses problems. Picks a line
	# tied to the day_clock + active-brew shape so the message feels like
	# a continuation of the world, not a UI status.
	var brews: Array = GameState.data.get("brews_in_flight", [])
	var day: int = TimeService.day_clock
	var lines: Array = []
	if day == 0 and brews.is_empty():
		lines = [
			"First day in the apartment. Kitchen still smells faintly of pasta.",
			"The stockpot sits on the stove. The bucket from the basement is in the closet.",
		]
	elif brews.is_empty():
		lines = [
			"Quiet morning. Nothing fermenting in the closet.",
			"Empty fermenter. Empty kettle. Could fix that.",
			"Calm day. The brewing supplies are clean and waiting.",
		]
	else:
		var any_fermenting := false
		var any_conditioning := false
		var any_ready := false
		for b in brews:
			var stage: String = String(b.get("stage", ""))
			var elapsed: int = int(b.get("days_elapsed_in_stage", 0))
			var snap: Dictionary = b.get("recipe_snapshot", {})
			if stage == BrewState.STAGE_FERMENTING:
				any_fermenting = true
				if elapsed >= int(snap.get("fermentation_days", 5)):
					any_ready = true
			elif stage == BrewState.STAGE_BOTTLED_CONDITIONING:
				any_conditioning = true
				if elapsed >= int(snap.get("condition_days", 14)):
					any_ready = true
		if any_ready:
			lines = ["Something's ready for you today."]
		elif any_fermenting:
			lines = [
				"Closet is quiet. The bucket is doing its thing.",
				"Faint yeast smell from the closet.",
				"Steady hum from the airlock if you put your ear to it.",
			]
		elif any_conditioning:
			lines = [
				"Bottles in the rack are settling in.",
				"Sediment dropping cleanly in the conditioning rack.",
			]
	if lines.is_empty():
		morning_summary.text = ""
		morning_summary.visible = false
		return
	# Stable per-day pick so the line doesn't flicker between renders.
	var pick: int = day % lines.size()
	morning_summary.text = String(lines[pick])
	morning_summary.visible = true

func _render_checklist() -> void:
	for child in checklist_list.get_children():
		child.queue_free()
	var brews: Array = GameState.data.get("brews_in_flight", [])
	checklist_header.visible = true
	if brews.is_empty():
		var empty := Label.new()
		empty.text = "Nothing on the list. Could start a brew."
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
		checklist_list.add_child(empty)
		return
	for brew in brews:
		checklist_list.add_child(_checklist_row(brew))

func _checklist_row(brew: Dictionary) -> Control:
	# Per 4.2: each active fermenter contributes one checklist line
	# ("Check fermenter — Pale Ale, day 3/5"). Tap → perception modal.
	# 3.7's "uniform action list" rule: the row never pre-discloses status
	# beyond stage + day-N-of-M; the actual "is something happening here"
	# read happens inside the modal, gated on equipment/skill (placeholder
	# for now — full perception layer is step 11).
	var stage: String = String(brew.get("stage", ""))
	var snapshot: Dictionary = brew.get("recipe_snapshot", {})
	var name: String = String(snapshot.get("display_name", brew.get("recipe_id", "Brew")))
	var elapsed: int = int(brew.get("days_elapsed_in_stage", 0))
	var brew_id: String = String(brew.get("brew_id", ""))

	var row := Button.new()
	row.flat = true
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0, 44)

	var label_text: String
	match stage:
		BrewState.STAGE_FERMENTING:
			var ferm: int = int(snapshot.get("fermentation_days", 5))
			label_text = "Check fermenter — %s, day %d/%d" % [name, elapsed, ferm]
		BrewState.STAGE_BOTTLED_CONDITIONING:
			var cond: int = int(snapshot.get("condition_days", 14))
			label_text = "Check conditioning — %s, day %d/%d" % [name, elapsed, cond]
		_:
			label_text = "%s · %s" % [name, stage]
	row.text = label_text
	row.add_theme_font_size_override("font_size", 13)

	# Visual cue when ready without saying so explicitly per 3.7. A small
	# ▶ marker on actionable rows; in-progress rows just sit there.
	if _is_actionable(stage, elapsed, snapshot):
		row.add_theme_color_override("font_color", Color(0.96, 0.78, 0.32))
		row.text = "▶  %s" % row.text

	row.pressed.connect(func(): _on_check_brew(brew_id))
	return row

func _is_actionable(stage: String, elapsed: int, snapshot: Dictionary) -> bool:
	if stage == BrewState.STAGE_FERMENTING:
		return elapsed >= int(snapshot.get("fermentation_days", 5))
	if stage == BrewState.STAGE_BOTTLED_CONDITIONING:
		return elapsed >= int(snapshot.get("condition_days", 14))
	return false

func _on_check_brew(brew_id: String) -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("push_modal"):
		main.push_modal(CHECK_FERMENTER_MODAL, func(inst): inst.brew_id = brew_id)

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
