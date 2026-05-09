extends Control

## Fill Kettle (real, v5) — Mini-game #1 per DESIGN.md 3.9 + Appendix A Step 2.
##
## Apartment-first layout: the apartment fills the entire viewport. The
## only UI chrome is a small readout chip; players advance by interacting
## with the world. Tap the brass faucet handle to start water; tap again
## to stop. Stopping with water in the kettle commits the fill — no
## "Done" button. Care factor derives from how the player worked the
## tap (multiple flow_starts = stopping to check the level).

signal minigame_completed(outcome: Dictionary)

const APARTMENT_SCENE: PackedScene = preload("res://scenes/lib/apartment_2d.tscn")

const TARGET_GAL: float = 2.5
const MAX_GAL: float = 5.0
const BASE_DRIFT_GAL: float = 0.5
const FAUCET_PRECISION: float = 0.40
const FILL_RATE_GAL_PER_SEC: float = 0.85
const MIN_COMMIT_GAL: float = 0.5  # Below this, faucet-off is treated as a misfire, not a commit.
const COMMIT_DELAY_SEC: float = 0.6  # Beat after the player turns the tap off.
const XP_AWARD: Dictionary = {"process": 8}

@onready var _readout: Label = %Readout
@onready var _viewport: Control = %ApartmentViewport

var _apartment: Apartment2D = null
var _kettle: Kettle2D = null
var _stage_meta: Dictionary = {}
var _filled_gal: float = 0.0
var _flow_starts: int = 0
var _resolved: bool = false
var _commit_timer: float = -1.0

func _ready() -> void:
	set_process(true)
	_mount_apartment()
	_update_readout()

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage

func _mount_apartment() -> void:
	_apartment = APARTMENT_SCENE.instantiate()
	_viewport.add_child(_apartment)
	# Wait one frame so the apartment's _ready spawns the faucet, then
	# wire interactions and place the kettle.
	await get_tree().process_frame
	_recenter_apartment()
	# Drop a kettle on the counter at the sink station.
	_kettle = Kettle2D.new()
	_kettle.name = "Kettle"
	const KETTLE_W: float = 244.0
	var sink: Vector2 = _apartment.station_anchor(Apartment2D.STATION_SINK)
	_kettle.position = Vector2(sink.x - KETTLE_W * 0.5, sink.y - 228)
	_kettle.target_fraction = TARGET_GAL / MAX_GAL
	_kettle.target_band_width = 36.0
	_kettle.target_color = Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.42)
	_apartment.add_child(_kettle)
	if _apartment.faucet != null:
		_apartment.faucet.toggled.connect(_on_faucet_toggled)
	# Re-center if the viewport gets resized (rotation, window resize, etc.).
	_viewport.resized.connect(_recenter_apartment)

func _recenter_apartment() -> void:
	if _apartment == null:
		return
	var vp_size: Vector2 = _viewport.size
	var offset: Vector2 = _apartment.camera_offset_for(Apartment2D.STATION_SINK, vp_size.x)
	# Vertical center: anchor the apartment so its mid-line sits at
	# viewport center. Apartment height is fixed; floor/window crop
	# naturally if the viewport is shorter.
	offset.y = (vp_size.y - Apartment2D.PANORAMA_H) * 0.5
	_apartment.position = offset

func _process(delta: float) -> void:
	if _resolved:
		return
	if _apartment == null or _apartment.faucet == null:
		return
	if _apartment.faucet.is_on:
		_filled_gal = min(_filled_gal + FILL_RATE_GAL_PER_SEC * delta, MAX_GAL)
		if _kettle != null:
			_kettle.set_fill(_filled_gal / MAX_GAL)
		_update_readout()
		if _filled_gal >= MAX_GAL:
			_apartment.faucet.set_on(false)
	elif _commit_timer >= 0.0:
		_commit_timer -= delta
		if _commit_timer <= 0.0:
			_commit_timer = -1.0
			_commit_fill()

func _on_faucet_toggled(is_on: bool) -> void:
	if is_on:
		_flow_starts += 1
		_commit_timer = -1.0  # Cancel any pending commit — they're filling again.
	else:
		# Faucet off with water in the kettle → commit after a short beat.
		# The beat lets the player wiggle the tap without immediately ending
		# the stage; if they re-open within COMMIT_DELAY_SEC it's cancelled.
		if _filled_gal >= MIN_COMMIT_GAL:
			_commit_timer = COMMIT_DELAY_SEC
	_update_readout()

func _update_readout() -> void:
	if _readout == null:
		return
	_readout.text = "%.2f / %.1f gal" % [_filled_gal, TARGET_GAL]
	var err: float = abs(_filled_gal - TARGET_GAL)
	if err < 0.10:
		_readout.add_theme_color_override("font_color", Palette.GRADE_A)
	elif err < 0.25:
		_readout.add_theme_color_override("font_color", Palette.GRADE_B)
	elif err < 0.50:
		_readout.add_theme_color_override("font_color", Palette.GRADE_C)
	else:
		_readout.add_theme_color_override("font_color", Palette.GRADE_D)

func _care_factor() -> float:
	# Care derives from how the player worked the tap. One flow_start is
	# the minimum (open, fill, close); 2+ means they stopped to check the
	# level — that's the careful behavior we used to read off a checkbox.
	if _flow_starts >= 3:
		return 1.0
	if _flow_starts >= 2:
		return 0.85
	return 0.7

func _commit_fill() -> void:
	if _resolved:
		return
	_resolved = true

	var skills: Dictionary = GameState.data.get("skills", {})
	var process_level: int = int(skills.get("process", {}).get("level", 0))
	var skill_factor: float = Drift.skill_factor_from_level(process_level)
	var care_factor: float = _care_factor()

	var rng := RandomNumberGenerator.new()
	rng.seed = _brew_rng_seed()

	var stopped_at: float = _filled_gal
	var actual_gal: float = Drift.compute_actual(
		stopped_at,
		BASE_DRIFT_GAL,
		skill_factor,
		FAUCET_PRECISION,
		care_factor,
		rng,
	)
	actual_gal = clampf(actual_gal, 0.0, MAX_GAL)

	var notes: Array = ["Filled to ~%.2f gal (target %.1f) from the faucet." % [actual_gal, TARGET_GAL]]
	if _flow_starts >= 3:
		notes.append("Stopped and started the tap a few times — careful work.")
	elif _flow_starts >= 2:
		notes.append("Paused once to check the level.")

	var outcome: Dictionary = {
		"actual": {
			"water_volume_gal":  actual_gal,
			"water_source":       "tap",
			"method":              "faucet",
			"player_stopped_at":  stopped_at,
			"flow_starts":         _flow_starts,
		},
		"care_factor":   care_factor,
		"risk_deltas":   {},
		"xp_gained":     XP_AWARD,
		"journal_notes": notes,
		"skill_snapshot": SkillXP.snapshot(skills),
	}
	minigame_completed.emit(outcome)

func _brew_rng_seed() -> int:
	for b in GameState.data.get("brews_in_flight", []):
		if String(b.get("stage", "")) == BrewState.STAGE_BREWING_DAY:
			return int(b.get("rng_state", 0)) ^ Time.get_ticks_msec()
	return randi()
