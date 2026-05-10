extends Control

## Fill Kettle (close-up, v6).
##
## Distinct view from the apartment: the camera is "down at the sink",
## kettle takes the lower half of the screen, faucet hangs above. The
## kettle is rendered as a CROSS-SECTION so the player can see the
## water level rising inside through a cutaway side wall.
##
## Liquid physics:
##   - Surface wave is a sum of two sines with different frequencies,
##     amplitude scaled by recent fill activity (faucet on or recently off)
##   - Damped slosh after the faucet shuts off (amplitude decays toward 0)
##   - Splash particles spawn at the water-line impact point while the
##     faucet is on, drift outward and fade
##
## Player taps the faucet handle to toggle on/off. Faucet-off with water
## in the kettle commits the fill (after a short beat for wiggle). No
## target band — the player has to eyeball it from the cross-section.

signal minigame_completed(outcome: Dictionary)

const TARGET_GAL: float = 2.5
const MAX_GAL: float = 5.0
const BASE_DRIFT_GAL: float = 0.5
const FAUCET_PRECISION: float = 0.40
const FILL_RATE_GAL_PER_SEC: float = 0.85
const MIN_COMMIT_GAL: float = 0.5
const COMMIT_DELAY_SEC: float = 0.6
const XP_AWARD: Dictionary = {"process": 8}

# Drawing geometry — the close-up kettle is much bigger than the
# in-apartment kettle so liquid behavior reads clearly.
const KETTLE_W: float = 280.0       # widest point (rim)
const KETTLE_BOTTOM_W: float = 240.0
const KETTLE_H: float = 360.0
const RIM_THICKNESS: float = 12.0
const WALL_THICKNESS: float = 8.0
const FAUCET_HEIGHT: float = 140.0  # how tall the faucet renders above
const FAUCET_GAP: float = 24.0      # gap between spout tip and kettle rim

@onready var _readout: Label = %Readout
@onready var _faucet_button: Button = %FaucetButton
@onready var _stage_view: Control = %StageView

var _stage_meta: Dictionary = {}
var _filled_gal: float = 0.0
var _flow_starts: int = 0
var _resolved: bool = false
var _commit_timer: float = -1.0
var _is_on: bool = false

# Animation state
var _t: float = 0.0
var _slosh_amplitude: float = 0.0  # Current surface wave amplitude (px)
var _splash_particles: Array = []  # Each: {pos, vel, age, life}

func _ready() -> void:
	set_process(true)
	_faucet_button.pressed.connect(_toggle_faucet)
	_stage_view.draw.connect(_draw_stage)
	_stage_view.resized.connect(_stage_view.queue_redraw)
	_update_readout()

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage

func _process(delta: float) -> void:
	if _resolved:
		return
	_t += delta
	# Fill the kettle while faucet is on.
	if _is_on:
		_filled_gal = min(_filled_gal + FILL_RATE_GAL_PER_SEC * delta, MAX_GAL)
		# Slosh from active pour: scale amplitude with how full kettle is
		# (more water = more visible slosh).
		var fill_factor: float = clampf(_filled_gal / MAX_GAL, 0.0, 1.0)
		var target_amp: float = lerpf(2.0, 8.0, fill_factor)
		_slosh_amplitude = lerpf(_slosh_amplitude, target_amp, clampf(delta * 6.0, 0.0, 1.0))
		_spawn_splash(delta)
		if _filled_gal >= MAX_GAL:
			_set_on(false)
	else:
		# Damped slosh decay after the faucet is off.
		_slosh_amplitude = max(0.0, _slosh_amplitude - delta * 4.0)
	# Update particles.
	var alive: Array = []
	for p in _splash_particles:
		p["age"] += delta
		if p["age"] < p["life"]:
			p["pos"] += p["vel"] * delta
			p["vel"].y += 280.0 * delta  # gravity
			alive.append(p)
	_splash_particles = alive
	# Commit logic.
	if not _is_on and _commit_timer >= 0.0:
		_commit_timer -= delta
		if _commit_timer <= 0.0:
			_commit_timer = -1.0
			_commit_fill()
	_update_readout()
	_stage_view.queue_redraw()

func _spawn_splash(delta: float) -> void:
	# Spawn ~20 particles per second while pouring.
	var rate: float = 20.0
	var n: int = int(rate * delta + randf())
	var stage_size: Vector2 = _stage_view.size
	var kettle_cx: float = stage_size.x * 0.5
	var rim_y: float = _kettle_rim_y(stage_size)
	var fill_y: float = _water_surface_y(stage_size, _filled_gal / MAX_GAL)
	var impact_y: float = max(rim_y + 4.0, fill_y - 4.0)
	for i in range(n):
		var px: float = kettle_cx + randf_range(-3.0, 3.0)
		var py: float = impact_y
		var vx: float = randf_range(-60.0, 60.0)
		var vy: float = randf_range(-160.0, -40.0)
		_splash_particles.append({
			"pos": Vector2(px, py),
			"vel": Vector2(vx, vy),
			"age": 0.0,
			"life": randf_range(0.35, 0.7),
		})

func _toggle_faucet() -> void:
	_set_on(not _is_on)

func _set_on(state: bool) -> void:
	if state == _is_on:
		return
	_is_on = state
	if state:
		_flow_starts += 1
		_commit_timer = -1.0
	else:
		if _filled_gal >= MIN_COMMIT_GAL:
			_commit_timer = COMMIT_DELAY_SEC

func _update_readout() -> void:
	if _readout == null:
		return
	_readout.text = "%.2f / %.1f gal" % [_filled_gal, TARGET_GAL]

# ---- Drawing the close-up scene ----

func _kettle_rim_y(stage_size: Vector2) -> float:
	# Kettle is anchored to the bottom-center of the stage, leaving room
	# for the faucet above.
	var cy: float = stage_size.y * 0.62  # vertical center of kettle
	return cy - KETTLE_H * 0.5

func _kettle_bottom_y(stage_size: Vector2) -> float:
	return _kettle_rim_y(stage_size) + KETTLE_H

func _water_surface_y(stage_size: Vector2, fill_frac: float) -> float:
	# Inside-of-pot interior runs from rim_y + RIM_THICKNESS + WALL_THICKNESS
	# to bottom - WALL_THICKNESS.
	var top: float = _kettle_rim_y(stage_size) + RIM_THICKNESS + 4.0
	var bot: float = _kettle_bottom_y(stage_size) - WALL_THICKNESS - 2.0
	return bot - (bot - top) * clampf(fill_frac, 0.0, 1.0)

func _draw_stage() -> void:
	var stage_size: Vector2 = _stage_view.size
	if stage_size.x <= 0:
		return
	# Backdrop — soft radial vignette.
	_stage_view.draw_rect(Rect2(Vector2.ZERO, stage_size), Color(0.08, 0.07, 0.06, 1))
	# Tile band suggesting the splashback.
	_stage_view.draw_rect(
		Rect2(Vector2(0, stage_size.y * 0.20), Vector2(stage_size.x, stage_size.y * 0.40)),
		Color(0.10, 0.08, 0.07, 1),
	)
	_draw_kettle_cross_section(stage_size)
	_draw_faucet(stage_size)
	if _is_on:
		_draw_water_stream(stage_size)
	_draw_splash_particles()
	_position_faucet_button(stage_size)

func _draw_kettle_cross_section(stage_size: Vector2) -> void:
	var cx: float = stage_size.x * 0.5
	var rim_y: float = _kettle_rim_y(stage_size)
	var bottom_y: float = _kettle_bottom_y(stage_size)
	var top_half: float = KETTLE_W * 0.5
	var bot_half: float = KETTLE_BOTTOM_W * 0.5

	# Drop shadow under the kettle.
	var shadow_pts := PackedVector2Array([
		Vector2(cx - bot_half + 12, bottom_y - 4),
		Vector2(cx + bot_half + 18, bottom_y - 4),
		Vector2(cx + bot_half + 28, bottom_y + 14),
		Vector2(cx - bot_half + 22, bottom_y + 14),
	])
	_stage_view.draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.55))

	# Outer body silhouette (back wall — what you see THROUGH the cutaway).
	# This is just a faint outline so the kettle reads as a vessel.
	var outer_outline := PackedVector2Array([
		Vector2(cx - top_half, rim_y),
		Vector2(cx + top_half, rim_y),
		Vector2(cx + bot_half, bottom_y),
		Vector2(cx - bot_half, bottom_y),
		Vector2(cx - top_half, rim_y),
	])
	_stage_view.draw_polyline(outer_outline, Color(Palette.METAL_OUTLINE.r, Palette.METAL_OUTLINE.g, Palette.METAL_OUTLINE.b, 0.5), 1.0, true)

	# Front-left wall (cross-section view: only LEFT side of kettle drawn solid).
	# Right side is the cutaway — interior visible.
	var left_wall := PackedVector2Array([
		Vector2(cx - top_half, rim_y),
		Vector2(cx - top_half + WALL_THICKNESS, rim_y),
		Vector2(cx - bot_half + WALL_THICKNESS, bottom_y - WALL_THICKNESS),
		Vector2(cx + bot_half - WALL_THICKNESS, bottom_y - WALL_THICKNESS),
		Vector2(cx + bot_half, bottom_y),
		Vector2(cx - bot_half, bottom_y),
	])
	_stage_view.draw_colored_polygon(left_wall, Palette.METAL_MID)
	# Lit edge on left side.
	_stage_view.draw_polyline(PackedVector2Array([
		Vector2(cx - top_half, rim_y),
		Vector2(cx - bot_half, bottom_y),
	]), Palette.METAL_LIGHT, 2.0, true)

	# Right wall (the visible "back" of the kettle as cross-section).
	var right_wall_lit := PackedVector2Array([
		Vector2(cx + top_half - 4, rim_y),
		Vector2(cx + top_half, rim_y),
		Vector2(cx + bot_half, bottom_y),
		Vector2(cx + bot_half - 4, bottom_y - WALL_THICKNESS),
	])
	_stage_view.draw_colored_polygon(right_wall_lit, Palette.METAL_DARK)

	# Inside body — slightly darker than exterior to read as "interior".
	var inside := PackedVector2Array([
		Vector2(cx - top_half + WALL_THICKNESS, rim_y + RIM_THICKNESS),
		Vector2(cx + top_half - 4, rim_y + RIM_THICKNESS),
		Vector2(cx + bot_half - 4, bottom_y - WALL_THICKNESS),
		Vector2(cx - bot_half + WALL_THICKNESS, bottom_y - WALL_THICKNESS),
	])
	_stage_view.draw_colored_polygon(inside, Color(0.08, 0.08, 0.09, 1))

	# Water polygon inside the kettle — surface is animated.
	if _filled_gal > 0.0:
		_draw_water_inside(stage_size, cx, rim_y, bottom_y, top_half, bot_half)

	# Rim band on top.
	var rim_top := PackedVector2Array([
		Vector2(cx - top_half - 4, rim_y - 4),
		Vector2(cx + top_half + 4, rim_y - 4),
		Vector2(cx + top_half, rim_y + RIM_THICKNESS),
		Vector2(cx - top_half, rim_y + RIM_THICKNESS),
	])
	_stage_view.draw_colored_polygon(rim_top, Palette.METAL_LIGHT)
	var rim_lit := PackedVector2Array([
		Vector2(cx - top_half - 4, rim_y - 4),
		Vector2(cx + top_half + 4, rim_y - 4),
		Vector2(cx + top_half + 4, rim_y - 1),
		Vector2(cx - top_half - 4, rim_y - 1),
	])
	_stage_view.draw_colored_polygon(rim_lit, Palette.METAL_SHINE)

	# Two D-handles on the rim level (shown on each side).
	for side in [-1.0, 1.0]:
		var anchor := Vector2(cx + side * (top_half - 6), rim_y + 80)
		_draw_handle(anchor, side)

func _draw_water_inside(stage_size: Vector2, cx: float, rim_y: float,
		bottom_y: float, top_half: float, bot_half: float) -> void:
	var fill_frac: float = _filled_gal / MAX_GAL
	var inside_top: float = rim_y + RIM_THICKNESS + 4
	var inside_bot: float = bottom_y - WALL_THICKNESS - 2
	var span: float = inside_bot - inside_top
	var surface_y: float = inside_bot - span * fill_frac

	# Wave: surface line is a sum of sines for slosh feel.
	var t: float = (inside_top - rim_y) / max(KETTLE_H, 0.01)
	var inside_top_half: float = lerpf(top_half - WALL_THICKNESS - 2, bot_half - WALL_THICKNESS - 2, t)
	var t2: float = (inside_bot - rim_y) / max(KETTLE_H, 0.01)
	var inside_bot_half: float = lerpf(top_half - WALL_THICKNESS - 2, bot_half - WALL_THICKNESS - 2, t2)
	# Linear-interpolate inside half-width at surface_y.
	var ts: float = (surface_y - inside_top) / max(span, 0.01)
	var surface_half: float = lerpf(inside_top_half, inside_bot_half, ts)

	var wave_pts := PackedVector2Array()
	wave_pts.append(Vector2(cx + surface_half, surface_y))
	wave_pts.append(Vector2(cx + inside_bot_half, inside_bot))
	wave_pts.append(Vector2(cx - inside_bot_half, inside_bot))
	wave_pts.append(Vector2(cx - surface_half, surface_y))
	# Insert wave points across the surface (right to left so polygon winds correctly).
	var samples: int = 28
	var top_wave_pts: Array = []
	for i in range(samples + 1):
		var f: float = float(i) / float(samples)
		var sx: float = cx + lerpf(-surface_half, surface_half, f)
		var phase: float = f * PI * 4.0
		var wave: float = (
			sin(_t * 5.0 + phase) * 0.6 +
			sin(_t * 7.3 + phase * 1.7) * 0.4
		)
		var sy: float = surface_y + wave * _slosh_amplitude
		top_wave_pts.append(Vector2(sx, sy))
	# Build full polygon: surface (right→left) → bottom-left → bottom-right.
	var poly := PackedVector2Array()
	for i in range(top_wave_pts.size() - 1, -1, -1):
		poly.append(top_wave_pts[i])
	poly.append(Vector2(cx - inside_bot_half, inside_bot))
	poly.append(Vector2(cx + inside_bot_half, inside_bot))
	_stage_view.draw_colored_polygon(poly, Palette.WATER_MID)
	# Surface highlight line.
	_stage_view.draw_polyline(top_wave_pts, Palette.WATER_HIGHLIGHT, 2.0, true)
	# Subtle gradient on the bottom (deeper water).
	var bottom_band := PackedVector2Array([
		Vector2(cx - inside_bot_half, inside_bot - 6),
		Vector2(cx + inside_bot_half, inside_bot - 6),
		Vector2(cx + inside_bot_half, inside_bot),
		Vector2(cx - inside_bot_half, inside_bot),
	])
	_stage_view.draw_colored_polygon(bottom_band, Color(0.10, 0.20, 0.30, 0.75))

func _draw_handle(anchor: Vector2, side: float) -> void:
	var radius: float = 22.0
	var pts := PackedVector2Array()
	var steps: int = 18
	for i in range(steps + 1):
		var theta: float = lerpf(-PI / 2.0, PI / 2.0, float(i) / float(steps))
		pts.append(Vector2(
			anchor.x + side * cos(theta) * radius,
			anchor.y + sin(theta) * radius,
		))
	_stage_view.draw_polyline(pts, Palette.METAL_OUTLINE, 6.0, true)
	var color: Color = Palette.METAL_LIGHT if side < 0 else Palette.METAL_MID
	_stage_view.draw_polyline(pts, color, 3.0, true)

func _draw_faucet(stage_size: Vector2) -> void:
	# Render a generous gooseneck above the kettle: base/mount above the
	# rim by FAUCET_GAP, riser ascending higher into the splashback,
	# arch curving over the kettle center, spout pointing into the kettle.
	var cx: float = stage_size.x * 0.5
	var rim_y: float = _kettle_rim_y(stage_size)
	var spout_y: float = rim_y - FAUCET_GAP
	var riser_top: float = spout_y - 70.0
	var mount_y: float = spout_y - 110.0  # mount higher up off-screen-ish (the wall plate)

	# Riser.
	_stage_view.draw_rect(
		Rect2(cx - 7, riser_top, 14, mount_y - riser_top),
		Palette.BRASS_MID,
	)
	_stage_view.draw_rect(
		Rect2(cx - 7, riser_top, 3, mount_y - riser_top),
		Palette.BRASS_LIGHT,
	)
	# Arch — quadratic bezier from riser top to spout top.
	var p0 := Vector2(cx, riser_top)
	var p2 := Vector2(cx, spout_y)
	var p1 := Vector2(cx, riser_top - 30)  # peak directly above
	# Use a curve that arches OUT slightly (to simulate gooseneck).
	p1.x = cx + 30
	var arch_pts := PackedVector2Array()
	var steps: int = 18
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var a: Vector2 = p0.lerp(p1, t)
		var b: Vector2 = p1.lerp(p2, t)
		arch_pts.append(a.lerp(b, t))
	_stage_view.draw_polyline(arch_pts, Palette.BRASS_DARK, 14.0, true)
	_stage_view.draw_polyline(arch_pts, Palette.BRASS_MID, 10.0, true)
	# Spout tip — small downward nozzle.
	_stage_view.draw_rect(
		Rect2(cx - 8, spout_y - 4, 16, 8),
		Palette.BRASS_DARK,
	)
	_stage_view.draw_rect(
		Rect2(cx - 6, spout_y + 4, 12, 3),
		Palette.BRASS_DARK,
	)
	# Handle indicator on the riser side: lever angled differently when on/off.
	var lever_pivot := Vector2(cx - 7, riser_top + 18)
	var angle: float = -1.0 if _is_on else -2.4
	var tip := lever_pivot + Vector2(cos(angle), sin(angle)) * 28.0
	_stage_view.draw_line(lever_pivot, tip, Palette.BRASS_DARK, 6.0, true)
	_stage_view.draw_line(lever_pivot, tip, Palette.BRASS_MID, 4.0, true)
	_stage_view.draw_circle(tip, 5.0, Palette.BRASS_LIGHT)
	_stage_view.draw_circle(lever_pivot, 5.0, Palette.BRASS_DARK)

func _position_faucet_button(stage_size: Vector2) -> void:
	# The lever is the click target. Position the button to overlap.
	var cx: float = stage_size.x * 0.5
	var rim_y: float = _kettle_rim_y(stage_size)
	var spout_y: float = rim_y - FAUCET_GAP
	var riser_top: float = spout_y - 70.0
	var lever_cx: float = cx - 30
	var lever_cy: float = riser_top + 12
	# Place it on top of the lever, generous tap target.
	_faucet_button.position = Vector2(lever_cx - 30, lever_cy - 18)
	_faucet_button.size = Vector2(60, 60)

func _draw_water_stream(stage_size: Vector2) -> void:
	var cx: float = stage_size.x * 0.5
	var rim_y: float = _kettle_rim_y(stage_size)
	var spout_y: float = rim_y - FAUCET_GAP
	var fill_y: float = _water_surface_y(stage_size, _filled_gal / MAX_GAL)
	var impact_y: float = max(rim_y + 4.0, fill_y - 4.0)
	# Stream from spout to impact point with tiny wobble.
	var pts := PackedVector2Array()
	var pts_right := PackedVector2Array()
	var steps: int = 14
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var y: float = lerpf(spout_y + 4, impact_y, t)
		var wobble: float = sin(_t * 16.0 + t * 6.28) * 1.5
		var x_center: float = cx + wobble
		pts.append(Vector2(x_center - 4, y))
		pts_right.append(Vector2(x_center + 4, y))
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(p)
	for i in range(pts_right.size() - 1, -1, -1):
		poly.append(pts_right[i])
	_stage_view.draw_colored_polygon(poly, Palette.WATER_MID)
	_stage_view.draw_polyline(pts, Palette.WATER_HIGHLIGHT, 1.5, true)

func _draw_splash_particles() -> void:
	for p in _splash_particles:
		var pos: Vector2 = p["pos"]
		var age: float = p["age"]
		var life: float = p["life"]
		var alpha: float = clampf(1.0 - age / life, 0.0, 1.0)
		_stage_view.draw_circle(pos, 1.5, Color(Palette.WATER_HIGHLIGHT.r, Palette.WATER_HIGHLIGHT.g, Palette.WATER_HIGHLIGHT.b, alpha * 0.85))

# ---- Outcome / commit ----

func _care_factor() -> float:
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
		stopped_at, BASE_DRIFT_GAL, skill_factor,
		FAUCET_PRECISION, care_factor, rng,
	)
	actual_gal = clampf(actual_gal, 0.0, MAX_GAL)
	var notes: Array = ["Filled to ~%.2f gal (target %.1f) from the faucet." % [actual_gal, TARGET_GAL]]
	if _flow_starts >= 3:
		notes.append("Stopped and started the tap a few times.")
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
	# Reads the active brew's rng_state straight (no Time-based XOR). The
	# whole point of storing a seed on the brew is determinism: the same
	# brew + the same player actions should grade the same way every time
	# the outcome is computed (replays, debug reloads, headless tests).
	# The previous XOR-with-millisecond-clock broke that contract — same
	# brew + same actions could produce different outcomes depending on
	# how many ms had elapsed at commit time. The brew's seed itself was
	# randomized via randi() at brew creation, so per-brew variance is
	# preserved at the source.
	for b in GameState.data.get("brews_in_flight", []):
		if String(b.get("stage", "")) == BrewState.STAGE_BREWING_DAY:
			return int(b.get("rng_state", 0))
	return randi()
