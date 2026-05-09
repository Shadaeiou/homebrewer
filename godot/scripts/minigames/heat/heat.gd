extends Control

## Heat the water (close-up). Stove + kettle on burner, dial to control
## flame intensity, thermometer on the right, hold-the-target meter at
## top. No instruction text, no Continue button — the meter fills as
## the player keeps the temperature in the 160-170°F band; when full
## the step is committed.

signal minigame_completed(outcome: Dictionary)

const TARGET_LOW: float = 160.0
const TARGET_HIGH: float = 170.0
const SCORCH_THRESHOLD: float = 200.0
const HOLD_REQUIRED_SEC: float = 3.0
const STARTING_TEMP: float = 70.0
const AMBIENT_TEMP: float = 70.0

# Heat-input rate °F/sec for each dial position. Negative entries mean
# active cooling (off → drift toward ambient).
const DIAL_POS_OFF: int = 0
const DIAL_POS_LOW: int = 1
const DIAL_POS_MED: int = 2
const DIAL_POS_HIGH: int = 3
const DIAL_LABELS: Array = ["OFF", "LOW", "MED", "HIGH"]
const DIAL_HEAT_RATE: Array = [-2.0, 6.0, 14.0, 28.0]  # °F/sec

const XP_AWARD: Dictionary = {"temp_control": 8, "process": 4}

@onready var _stage_view: Control = %StageView
@onready var _dial_button: Button = %DialButton
@onready var _temp_label: Label = %TempLabel

var _stage_meta: Dictionary = {}
var _temp_f: float = STARTING_TEMP
var _dial_pos: int = DIAL_POS_OFF
var _hold_progress: float = 0.0  # seconds accumulated in target band
var _resolved: bool = false
var _scorched_at: float = 0.0  # peak temperature reached above scorch
var _t: float = 0.0
var _flame_flicker: float = 0.0

func _ready() -> void:
	set_process(true)
	_dial_button.pressed.connect(_cycle_dial)
	_stage_view.draw.connect(_draw_stage)
	_stage_view.resized.connect(_stage_view.queue_redraw)
	_update_label()

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage

func _process(delta: float) -> void:
	if _resolved:
		return
	_t += delta
	_flame_flicker += delta * 12.0
	# Temperature evolves toward equilibrium based on dial setting.
	var heat_rate: float = DIAL_HEAT_RATE[_dial_pos]
	# Heavy diminishing returns above the dial's "ceiling": OFF=ambient,
	# LOW=130, MED=185, HIGH=220 (forced boil). Rate scales toward that.
	var ceiling_per_pos: Array = [AMBIENT_TEMP, 130.0, 185.0, 220.0]
	var ceiling: float = ceiling_per_pos[_dial_pos]
	var diff: float = ceiling - _temp_f
	var move: float = sign(diff) * min(abs(diff), abs(heat_rate * delta))
	_temp_f += move
	# Scorch tracking — peak above SCORCH_THRESHOLD recorded.
	if _temp_f > _scorched_at:
		_scorched_at = _temp_f
	# Hold-target progress.
	if _temp_f >= TARGET_LOW and _temp_f <= TARGET_HIGH:
		_hold_progress += delta
		if _hold_progress >= HOLD_REQUIRED_SEC:
			_commit_outcome()
			return
	else:
		# Drift back toward zero if outside, but don't lose all progress
		# on a brief overshoot.
		_hold_progress = max(0.0, _hold_progress - delta * 0.3)
	_update_label()
	_stage_view.queue_redraw()

func _cycle_dial() -> void:
	_dial_pos = (_dial_pos + 1) % 4

func _update_label() -> void:
	_temp_label.text = "%d°F" % int(round(_temp_f))
	# Color the readout by zone.
	var col: Color = Palette.GRADE_C
	if _temp_f >= TARGET_LOW and _temp_f <= TARGET_HIGH:
		col = Palette.GRADE_A
	elif _temp_f > SCORCH_THRESHOLD:
		col = Palette.GRADE_D
	elif _temp_f > TARGET_HIGH:
		col = Palette.GRADE_C
	elif _temp_f < TARGET_LOW:
		col = Color(0.65, 0.78, 0.88, 1)  # cool blue
	_temp_label.add_theme_color_override("font_color", col)

# ---- Drawing ----

func _draw_stage() -> void:
	var sz: Vector2 = _stage_view.size
	if sz.x <= 0:
		return
	# Dim backdrop.
	_stage_view.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.06, 0.06, 0.08, 1))
	# Hold meter at top.
	_draw_hold_meter(sz)
	# Stove + kettle area.
	var stove_top: float = sz.y * 0.30
	var burner_y: float = sz.y * 0.65
	_draw_stove_panel(sz, stove_top, burner_y)
	_draw_burner(sz, burner_y)
	_draw_kettle_with_water(sz, burner_y)
	_draw_thermometer(sz)
	_draw_dial(sz)
	_position_dial_button(sz)

func _draw_hold_meter(sz: Vector2) -> void:
	var meter_w: float = sz.x * 0.6
	var meter_h: float = 8.0
	var x: float = (sz.x - meter_w) * 0.5
	var y: float = 18.0
	# Track.
	_stage_view.draw_rect(Rect2(x, y, meter_w, meter_h), Color(0.18, 0.16, 0.14, 1))
	# Filled portion.
	var fill_frac: float = clampf(_hold_progress / HOLD_REQUIRED_SEC, 0.0, 1.0)
	if fill_frac > 0.0:
		_stage_view.draw_rect(
			Rect2(x, y, meter_w * fill_frac, meter_h),
			Palette.GRADE_A,
		)
	# Outline.
	_stage_view.draw_rect(Rect2(x, y, meter_w, meter_h), Color(0, 0, 0, 0.5), false, 1.0)

func _draw_stove_panel(sz: Vector2, top: float, burner_y: float) -> void:
	# Stove deck — dark grey rectangle behind the burner.
	var deck_w: float = sz.x * 0.55
	var deck_x: float = (sz.x - deck_w) * 0.5
	var deck_h: float = 36.0
	_stage_view.draw_rect(
		Rect2(deck_x, burner_y - 8, deck_w, deck_h),
		Palette.METAL_DARK,
	)
	_stage_view.draw_rect(
		Rect2(deck_x, burner_y - 8, deck_w, 3),
		Palette.METAL_SHINE,
	)

func _draw_burner(sz: Vector2, burner_y: float) -> void:
	var cx: float = sz.x * 0.5
	var burner_r: float = 32.0
	# Burner well.
	_stage_view.draw_circle(Vector2(cx, burner_y), burner_r + 4, Color(0.06, 0.05, 0.04, 1))
	# Concentric rings (gas burner crown).
	for r in [burner_r, burner_r - 6, burner_r - 12]:
		_stage_view.draw_arc(
			Vector2(cx, burner_y), r, 0, TAU, 32,
			Palette.METAL_OUTLINE, 1.0, true,
		)
	# Flame — visible when dial > OFF.
	if _dial_pos > DIAL_POS_OFF:
		_draw_flame(Vector2(cx, burner_y), burner_r)

func _draw_flame(center: Vector2, base_r: float) -> void:
	# Flame size scales with dial position.
	var flame_h_target: Array = [0.0, 18.0, 32.0, 52.0]
	var height: float = flame_h_target[_dial_pos]
	# Flicker (noise).
	var flicker: float = sin(_flame_flicker * 1.7) * 2.0 + sin(_flame_flicker * 4.1) * 1.5
	height += flicker
	# Outer flame (orange).
	var outer := PackedVector2Array([
		Vector2(center.x - base_r * 0.7, center.y),
		Vector2(center.x - base_r * 0.4, center.y - height * 0.85),
		Vector2(center.x, center.y - height),
		Vector2(center.x + base_r * 0.4, center.y - height * 0.85),
		Vector2(center.x + base_r * 0.7, center.y),
	])
	_stage_view.draw_colored_polygon(outer, Color(0.95, 0.55, 0.18, 0.78))
	# Inner flame (yellow-blue).
	var inner_h: float = height * 0.65
	var inner := PackedVector2Array([
		Vector2(center.x - base_r * 0.4, center.y),
		Vector2(center.x - base_r * 0.18, center.y - inner_h * 0.7),
		Vector2(center.x, center.y - inner_h),
		Vector2(center.x + base_r * 0.18, center.y - inner_h * 0.7),
		Vector2(center.x + base_r * 0.4, center.y),
	])
	_stage_view.draw_colored_polygon(inner, Color(0.95, 0.85, 0.42, 0.85))
	# Blue base.
	var blue := PackedVector2Array([
		Vector2(center.x - base_r * 0.3, center.y),
		Vector2(center.x, center.y - 8),
		Vector2(center.x + base_r * 0.3, center.y),
	])
	_stage_view.draw_colored_polygon(blue, Color(0.42, 0.62, 0.92, 0.55))

func _draw_kettle_with_water(sz: Vector2, burner_y: float) -> void:
	# Kettle sits with its bottom on the burner. Cross-section so water
	# is visible inside.
	var cx: float = sz.x * 0.5
	var top_half: float = 90.0
	var bot_half: float = 76.0
	var kettle_h: float = 130.0
	var rim_y: float = burner_y - kettle_h
	var bot_y: float = burner_y
	# Drop shadow.
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - bot_half + 6, bot_y + 2),
		Vector2(cx + bot_half + 8, bot_y + 2),
		Vector2(cx + bot_half + 12, bot_y + 8),
		Vector2(cx - bot_half + 10, bot_y + 8),
	]), Color(0, 0, 0, 0.55))
	# Outer body (silhouette stroke).
	_stage_view.draw_polyline(PackedVector2Array([
		Vector2(cx - top_half, rim_y),
		Vector2(cx + top_half, rim_y),
		Vector2(cx + bot_half, bot_y),
		Vector2(cx - bot_half, bot_y),
		Vector2(cx - top_half, rim_y),
	]), Color(Palette.METAL_OUTLINE.r, Palette.METAL_OUTLINE.g, Palette.METAL_OUTLINE.b, 0.7), 1.5, true)
	# Left wall (cross-section: only left wall solid).
	var wall_t: float = 6.0
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - top_half, rim_y),
		Vector2(cx - top_half + wall_t, rim_y),
		Vector2(cx - bot_half + wall_t, bot_y - wall_t),
		Vector2(cx + bot_half - wall_t, bot_y - wall_t),
		Vector2(cx + bot_half, bot_y),
		Vector2(cx - bot_half, bot_y),
	]), Palette.METAL_MID)
	# Inside dark.
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - top_half + wall_t, rim_y + 4),
		Vector2(cx + top_half - 3, rim_y + 4),
		Vector2(cx + bot_half - 3, bot_y - wall_t),
		Vector2(cx - bot_half + wall_t, bot_y - wall_t),
	]), Color(0.08, 0.08, 0.09, 1))
	# Water filling most of the kettle (assumed already filled).
	var water_top_y: float = rim_y + 16
	var inside_top_half: float = top_half - wall_t - 2
	var inside_bot_half: float = bot_half - wall_t - 2
	# Steam wave on water surface — amplitude scales with how hot it is.
	var heat_factor: float = clampf((_temp_f - 100.0) / 110.0, 0.0, 1.0)
	var samples: int = 24
	var top_pts: Array = []
	for i in range(samples + 1):
		var f: float = float(i) / float(samples)
		var sx: float = cx + lerpf(-inside_top_half, inside_top_half, f)
		var phase: float = f * PI * 4.0
		var amp: float = 1.0 + heat_factor * 4.0
		var sy: float = water_top_y + sin(_t * 4.0 + phase) * amp
		top_pts.append(Vector2(sx, sy))
	var poly := PackedVector2Array()
	for i in range(top_pts.size() - 1, -1, -1):
		poly.append(top_pts[i])
	poly.append(Vector2(cx - inside_bot_half, bot_y - wall_t))
	poly.append(Vector2(cx + inside_bot_half, bot_y - wall_t))
	# Color shifts toward warm as it heats.
	var water_color: Color = Palette.WATER_MID.lerp(Color(0.55, 0.62, 0.55, 1), heat_factor * 0.6)
	_stage_view.draw_colored_polygon(poly, water_color)
	# Surface highlight.
	var top_packed := PackedVector2Array(top_pts)
	_stage_view.draw_polyline(top_packed, Palette.WATER_HIGHLIGHT, 1.5, true)
	# Steam — increases as it gets hotter.
	if _temp_f > 130.0:
		_draw_steam(cx, water_top_y, heat_factor)
	# Boiling bubbles when above ~205°F.
	if _temp_f > 205.0:
		_draw_boiling_bubbles(cx, water_top_y, inside_top_half)
	# Rim band.
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - top_half - 2, rim_y - 2),
		Vector2(cx + top_half + 2, rim_y - 2),
		Vector2(cx + top_half, rim_y + 6),
		Vector2(cx - top_half, rim_y + 6),
	]), Palette.METAL_LIGHT)

func _draw_steam(cx: float, surface_y: float, intensity: float) -> void:
	for i in range(4):
		var phase: float = fmod(_t * 0.7 + i * 0.25, 1.0)
		var rise_y: float = surface_y - phase * 60.0
		var drift_x: float = sin(_t * 1.2 + i * 1.7) * 12.0
		var alpha: float = (1.0 - phase) * 0.55 * intensity
		_stage_view.draw_circle(
			Vector2(cx + drift_x + (i - 2) * 6.0, rise_y),
			4.0 + phase * 6.0,
			Color(0.85, 0.88, 0.92, alpha),
		)

func _draw_boiling_bubbles(cx: float, surface_y: float, half_w: float) -> void:
	for i in range(6):
		var phase: float = fmod(_t * 1.5 + i * 0.18, 1.0)
		var bx: float = cx + sin(i * 11.7 + _t * 1.3) * half_w * 0.7
		var by: float = surface_y - phase * 6.0
		var r: float = 2.0 + sin(_t * 8.0 + i) * 0.5
		var alpha: float = (1.0 - phase) * 0.7
		_stage_view.draw_circle(Vector2(bx, by), r, Color(1, 1, 1, alpha))

func _draw_thermometer(sz: Vector2) -> void:
	# Vertical thermometer on the right side. 70°F at bottom, 220°F at top.
	var x: float = sz.x - 64
	var y_top: float = sz.y * 0.18
	var y_bot: float = sz.y * 0.82
	var height: float = y_bot - y_top
	# Tube background.
	_stage_view.draw_rect(Rect2(x, y_top, 14, height), Color(0.18, 0.16, 0.14, 1))
	# Mercury fill.
	var range_min: float = 70.0
	var range_max: float = 220.0
	var fill_frac: float = clampf((_temp_f - range_min) / (range_max - range_min), 0.0, 1.0)
	var fill_y: float = y_bot - height * fill_frac
	# Color shifts cool→hot.
	var mercury: Color = Color(0.35, 0.55, 0.78, 1).lerp(Color(0.85, 0.32, 0.22, 1), fill_frac)
	_stage_view.draw_rect(Rect2(x + 2, fill_y, 10, y_bot - fill_y), mercury)
	# Bulb at the bottom.
	_stage_view.draw_circle(Vector2(x + 7, y_bot + 6), 9, mercury)
	# Tick marks at 100, 150, 200.
	for tick_temp in [100.0, 150.0, 200.0]:
		var tf: float = (tick_temp - range_min) / (range_max - range_min)
		var ty: float = y_bot - height * tf
		_stage_view.draw_line(Vector2(x - 4, ty), Vector2(x + 18, ty), Palette.METAL_OUTLINE, 1.0, true)
	# Target band (160-170°F) highlighted.
	var t_low: float = (TARGET_LOW - range_min) / (range_max - range_min)
	var t_high: float = (TARGET_HIGH - range_min) / (range_max - range_min)
	var band_y_top: float = y_bot - height * t_high
	var band_y_bot: float = y_bot - height * t_low
	_stage_view.draw_rect(
		Rect2(x - 6, band_y_top, 26, band_y_bot - band_y_top),
		Color(Palette.GRADE_A.r, Palette.GRADE_A.g, Palette.GRADE_A.b, 0.18),
	)
	# Outline.
	_stage_view.draw_rect(Rect2(x, y_top, 14, height), Color(0, 0, 0, 0.6), false, 1.0)

func _draw_dial(sz: Vector2) -> void:
	# Dial on the bottom-center.
	var cx: float = sz.x * 0.5
	var cy: float = sz.y - 80.0
	var r: float = 38.0
	# Drop shadow.
	_stage_view.draw_circle(Vector2(cx + 1, cy + 2), r, Color(0, 0, 0, 0.55))
	# Body.
	_stage_view.draw_circle(Vector2(cx, cy), r, Palette.METAL_DARK)
	_stage_view.draw_circle(Vector2(cx, cy), r - 4, Palette.METAL_MID)
	_stage_view.draw_circle(Vector2(cx - 2, cy - 2), r - 8, Palette.METAL_LIGHT)
	# Position labels around the dial.
	# 4 positions at 9 o'clock, 12, 3, 6 (-PI, -PI/2, 0, PI/2).
	# OFF=top, LOW=right, MED=bottom, HIGH=left so cycling reads as
	# turning clockwise from OFF.
	var pos_angles: Array = [-PI / 2.0, 0.0, PI / 2.0, PI]
	for i in range(4):
		var angle: float = pos_angles[i]
		var label_pos: Vector2 = Vector2(cx, cy) + Vector2(cos(angle), sin(angle)) * (r + 14)
		# Drawing labels via draw_string would need a font ref; use tick instead.
		var tick_inner: Vector2 = Vector2(cx, cy) + Vector2(cos(angle), sin(angle)) * (r - 2)
		var tick_outer: Vector2 = Vector2(cx, cy) + Vector2(cos(angle), sin(angle)) * (r + 6)
		var tick_color: Color = Palette.METAL_LIGHT if i == _dial_pos else Palette.METAL_OUTLINE
		_stage_view.draw_line(tick_inner, tick_outer, tick_color, 2.5, true)
	# Indicator pointing to current position.
	var indicator_angle: float = pos_angles[_dial_pos]
	var tip: Vector2 = Vector2(cx, cy) + Vector2(cos(indicator_angle), sin(indicator_angle)) * (r - 6)
	_stage_view.draw_line(Vector2(cx, cy), tip, Palette.BRASS_LIGHT, 4.0, true)
	_stage_view.draw_circle(Vector2(cx, cy), 5, Palette.BRASS_DARK)
	# Dial label below ("OFF" / "LOW" / "MED" / "HIGH").
	# Drawing strings on the canvas requires a font lookup; the temp
	# label and the tick visual together convey state, so we leave the
	# wordmark to the regular Control label hierarchy elsewhere.

func _position_dial_button(sz: Vector2) -> void:
	# Big tap target over the dial.
	var cx: float = sz.x * 0.5
	var cy: float = sz.y - 80.0
	var r: float = 50.0
	_dial_button.position = Vector2(cx - r, cy - r)
	_dial_button.size = Vector2(r * 2, r * 2)

# ---- Outcome ----

func _commit_outcome() -> void:
	if _resolved:
		return
	_resolved = true
	var skills: Dictionary = GameState.data.get("skills", {})
	# Care factor: high if held within band, lower if scorched.
	var care: float = 0.85
	if _scorched_at > SCORCH_THRESHOLD:
		care = 0.50
	elif _temp_f >= TARGET_LOW and _temp_f <= TARGET_HIGH:
		care = 1.0
	var risk_deltas: Dictionary = {}
	if _scorched_at > SCORCH_THRESHOLD:
		risk_deltas["scorch_risk"] = clampf((_scorched_at - SCORCH_THRESHOLD) / 30.0, 0.0, 1.0) * 0.4
	var notes: Array = ["Heated kettle to %d°F." % int(round(_temp_f))]
	if _scorched_at > SCORCH_THRESHOLD:
		notes.append("Briefly scorched at %d°F." % int(round(_scorched_at)))
	var outcome: Dictionary = {
		"actual": {
			"final_temp_f": _temp_f,
			"peak_temp_f": _scorched_at,
			"hold_seconds": _hold_progress,
		},
		"care_factor":   care,
		"risk_deltas":   risk_deltas,
		"xp_gained":     XP_AWARD,
		"journal_notes": notes,
		"skill_snapshot": SkillXP.snapshot(skills),
	}
	minigame_completed.emit(outcome)
