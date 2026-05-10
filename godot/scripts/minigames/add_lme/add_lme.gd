extends Control

## Pour LME — close-up mini-game.
##
## Stove + kettle visible at the back of the scene with a visible
## dial. A wooden spoon hangs in front of the kettle. The LME tin
## sits beside the stove. Three tap targets — the dial, the spoon,
## the tin — must be tapped in the right order for an ideal pour:
##   1. Burner off (tap dial)
##   2. Start stirring (tap spoon)
##   3. Pour LME (tap tin)
##
## Wrong order produces glob, scorch, or full catastrophic scorch
## per the existing logic. Visual feedback after each tap.

signal minigame_completed(outcome: Dictionary)

const RESULT_TEXT := {
	"IDEAL":               "Ideal — clean dissolve, no scorch.",
	"MILD_GLOB":           "Mild glob — LME pooled at the bottom.",
	"MODERATE_SCORCH":     "Moderate scorch — burner came off late.",
	"CATASTROPHIC_SCORCH": "SCORCH — LME hit hot kettle with no stirring.",
}
const RESULT_DISSOLUTION := {
	"IDEAL": 1.0, "MILD_GLOB": 0.7, "MODERATE_SCORCH": 0.85, "CATASTROPHIC_SCORCH": 0.5,
}
const RESULT_RISK := {
	"IDEAL": {},
	"MILD_GLOB": {"recipe_drift": 1.0},
	"MODERATE_SCORCH": {"off_flavor_temp": 3.0, "recipe_drift": 1.5},
	"CATASTROPHIC_SCORCH": {"off_flavor_temp": 6.5, "recipe_drift": 4.0},
}
const RESULT_XP := {
	"IDEAL":               {"process": 12, "temp_control": 8},
	"MILD_GLOB":           {"process": 8,  "temp_control": 5},
	"MODERATE_SCORCH":     {"process": 5,  "temp_control": 5},
	"CATASTROPHIC_SCORCH": {"process": 3,  "temp_control": 3},
}
const REVEAL_SECONDS := 1.5

@onready var _stage_title: Label = %StageTitle
@onready var _burner_off_button: Button = %BurnerOffButton
@onready var _stir_button: Button = %StirButton
@onready var _lme_pour_button: Button = %LmePourButton
@onready var _read_aloud_toggle: CheckBox = %ReadAloudToggle
@onready var _pre_warm_toggle: CheckBox = %PreWarmToggle
@onready var _result_label: Label = %ResultLabel
@onready var _stage_view: Control = %StageView

var _stage_meta: Dictionary = {}
var _action_order: Array = []
var _resolved: bool = false
var _pending_outcome: Dictionary = {}
var _t: float = 0.0
var _burner_on: bool = true
var _stirring: bool = false
var _pouring: bool = false
var _pour_progress: float = 0.0  # 0..1
var _stir_phase: float = 0.0

func _ready() -> void:
	set_process(true)
	_burner_off_button.pressed.connect(_on_action.bind("burner_off", _burner_off_button))
	_stir_button.pressed.connect(_on_action.bind("stir", _stir_button))
	_lme_pour_button.pressed.connect(_on_action.bind("lme_pour", _lme_pour_button))
	if _stage_view != null:
		_stage_view.draw.connect(_draw_stage)
		_stage_view.resized.connect(_stage_view.queue_redraw)
	_result_label.text = ""

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage

func _process(delta: float) -> void:
	_t += delta
	_stir_phase += delta * (8.0 if _stirring else 1.5)
	if _pouring and _pour_progress < 1.0:
		_pour_progress = min(1.0, _pour_progress + delta * 0.6)
	_stage_view.queue_redraw()

func _on_action(action_id: String, btn: Button) -> void:
	if _resolved or _action_order.has(action_id):
		return
	_action_order.append(action_id)
	# Update visual state.
	match action_id:
		"burner_off": _burner_on = false
		"stir":       _stirring = true
		"lme_pour":   _pouring = true
	# Don't disable the button — let the visual feedback (changed state)
	# carry the "this is done" message.
	if _action_order.size() == 3:
		_resolve()

func _resolve() -> void:
	_resolved = true
	var burner_idx: int = _action_order.find("burner_off")
	var stir_idx: int = _action_order.find("stir")
	var lme_idx: int = _action_order.find("lme_pour")
	var burner_off_before_lme: bool = burner_idx < lme_idx
	var stir_before_lme: bool = stir_idx < lme_idx
	var result_id: String
	if burner_off_before_lme and stir_before_lme:
		result_id = "IDEAL"
	elif burner_off_before_lme:
		result_id = "MILD_GLOB"
	elif stir_before_lme:
		result_id = "MODERATE_SCORCH"
	else:
		result_id = "CATASTROPHIC_SCORCH"
	var skills: Dictionary = GameState.data.get("skills", {})
	var care := CareFactor.from_breadth(_optional_taken(), 2)
	var notes: Array = [String(RESULT_TEXT[result_id])]
	_pending_outcome = {
		"actual": {
			"sequence": _action_order.duplicate(),
			"result": result_id,
			"lme_dissolution": float(RESULT_DISSOLUTION[result_id]),
		},
		"care_factor": care,
		"risk_deltas": Dictionary(RESULT_RISK[result_id]).duplicate(true),
		"xp_gained": Dictionary(RESULT_XP[result_id]).duplicate(true),
		"journal_notes": notes,
		"skill_snapshot": SkillXP.snapshot(skills),
	}
	_result_label.text = String(RESULT_TEXT[result_id])
	_result_label.modulate = _result_color(result_id)
	var reveal := get_tree().create_timer(REVEAL_SECONDS)
	reveal.timeout.connect(_emit_pending_outcome)

func _emit_pending_outcome() -> void:
	minigame_completed.emit(_pending_outcome)

func _optional_taken() -> int:
	var n := 0
	if _read_aloud_toggle.button_pressed:
		n += 1
	if _pre_warm_toggle.button_pressed:
		n += 1
	return n

func _result_color(result_id: String) -> Color:
	match result_id:
		"IDEAL":               return Color(0.55, 0.90, 0.55, 1)
		"MILD_GLOB":           return Color(0.95, 0.85, 0.50, 1)
		"MODERATE_SCORCH":     return Color(0.95, 0.55, 0.30, 1)
		"CATASTROPHIC_SCORCH": return Color(0.95, 0.35, 0.30, 1)
		_:                     return Color(1, 1, 1, 1)

# ---- Drawing ----

func _draw_stage() -> void:
	var sz: Vector2 = _stage_view.size
	if sz.x <= 0:
		return
	_stage_view.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.06, 0.06, 0.08, 1))
	# Counter line.
	var counter_y: float = sz.y * 0.65
	_stage_view.draw_rect(Rect2(0, counter_y, sz.x, 8), Palette.WOOD_LIGHT)
	_stage_view.draw_rect(Rect2(0, counter_y + 8, sz.x, sz.y - counter_y - 8), Palette.WOOD_DARK)
	_draw_stove(sz, counter_y)
	_draw_kettle(sz, counter_y)
	_draw_spoon(sz, counter_y)
	_draw_lme_tin(sz, counter_y)
	_position_hotspots(sz, counter_y)

func _draw_stove(sz: Vector2, counter_y: float) -> void:
	# Stove surface stretches behind kettle.
	var sx: float = sz.x * 0.5
	var stove_w: float = 220.0
	var stove_h: float = 28.0
	_stage_view.draw_rect(
		Rect2(sx - stove_w * 0.5, counter_y - stove_h, stove_w, stove_h),
		Palette.METAL_DARK,
	)
	_stage_view.draw_rect(
		Rect2(sx - stove_w * 0.5, counter_y - stove_h, stove_w, 3),
		Palette.METAL_SHINE,
	)
	# Burner ring under the kettle.
	var burner_y: float = counter_y - stove_h * 0.5
	_stage_view.draw_arc(Vector2(sx, burner_y), 28, 0, TAU, 32, Palette.METAL_OUTLINE, 1.0, true)
	# Flame visible if burner on.
	if _burner_on:
		var height: float = 26.0 + sin(_t * 8.0) * 3.0
		_stage_view.draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 18, burner_y),
			Vector2(sx, burner_y - height),
			Vector2(sx + 18, burner_y),
		]), Color(0.95, 0.55, 0.18, 0.7))
	# Dial knob (visual representation of the dial hotspot).
	var dial_x: float = sx + stove_w * 0.5 - 30
	var dial_y: float = counter_y - 8
	_stage_view.draw_circle(Vector2(dial_x, dial_y), 14, Palette.METAL_DARK)
	_stage_view.draw_circle(Vector2(dial_x, dial_y), 11, Palette.METAL_MID)
	var ang: float = PI if _burner_on else -PI / 2.0
	var tip := Vector2(dial_x, dial_y) + Vector2(cos(ang), sin(ang)) * 8
	_stage_view.draw_line(Vector2(dial_x, dial_y), tip, Palette.BRASS_LIGHT, 2.0, true)

func _draw_kettle(sz: Vector2, counter_y: float) -> void:
	var cx: float = sz.x * 0.5
	var bot_y: float = counter_y - 28
	var top_half: float = 80.0
	var bot_half: float = 68.0
	var kettle_h: float = 130.0
	var rim_y: float = bot_y - kettle_h
	# Body.
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
		Vector2(cx - top_half + wall_t, rim_y + 6),
		Vector2(cx + top_half - 3, rim_y + 6),
		Vector2(cx + bot_half - 3, bot_y - wall_t),
		Vector2(cx - bot_half + wall_t, bot_y - wall_t),
	]), Color(0.06, 0.06, 0.06, 1))
	# Hot water (color shifts as LME pours in).
	var water_top_y: float = rim_y + 22
	var water_color: Color = Color(0.55, 0.62, 0.55, 1)
	# As LME pours, color darkens toward wort brown.
	water_color = water_color.lerp(Color(0.32, 0.18, 0.10, 1), _pour_progress)
	# Stir-driven swirl.
	var samples: int = 18
	var top_pts: Array = []
	var amp: float = 4.0 if _stirring else 1.5
	for i in range(samples + 1):
		var f: float = float(i) / float(samples)
		var sx_l: float = cx + lerpf(-(top_half - wall_t - 2), top_half - wall_t - 2, f)
		var phase: float = f * PI * (4.0 if _stirring else 2.0)
		var sy: float = water_top_y + sin(_stir_phase + phase) * amp
		top_pts.append(Vector2(sx_l, sy))
	var poly := PackedVector2Array()
	for i in range(top_pts.size() - 1, -1, -1):
		poly.append(top_pts[i])
	poly.append(Vector2(cx - (bot_half - wall_t - 2), bot_y - wall_t))
	poly.append(Vector2(cx + (bot_half - wall_t - 2), bot_y - wall_t))
	_stage_view.draw_colored_polygon(poly, water_color)
	# Steam (always — water is hot).
	for i in range(3):
		var phase: float = fmod(_t * 0.6 + i * 0.33, 1.0)
		var alpha: float = (1.0 - phase) * 0.5
		_stage_view.draw_circle(
			Vector2(cx + (i - 1) * 8.0, water_top_y - phase * 50.0),
			4.0 + phase * 5.0,
			Color(0.85, 0.88, 0.92, alpha),
		)
	# LME stream pouring in if active.
	if _pouring and _pour_progress < 1.0:
		var stream_top_y: float = rim_y - 30
		_stage_view.draw_rect(
			Rect2(cx + 30 - 4, stream_top_y, 8, water_top_y - stream_top_y),
			Color(0.32, 0.20, 0.10, 1),
		)
	# Rim band.
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - top_half - 2, rim_y - 2),
		Vector2(cx + top_half + 2, rim_y - 2),
		Vector2(cx + top_half, rim_y + 6),
		Vector2(cx - top_half, rim_y + 6),
	]), Palette.METAL_LIGHT)

func _draw_spoon(sz: Vector2, counter_y: float) -> void:
	# Spoon hangs in front of the kettle area, slightly to the left.
	var cx: float = sz.x * 0.30
	var rim_y: float = counter_y - 28 - 130
	var handle_top: float = rim_y - 60
	# Stir motion: the spoon tilts left/right when stirring.
	var tilt: float = sin(_stir_phase) * 8.0 if _stirring else 0.0
	var handle_x_top: float = cx + tilt
	# Handle.
	_stage_view.draw_line(
		Vector2(handle_x_top, handle_top),
		Vector2(cx, rim_y + 30),
		Color(0.55, 0.42, 0.28, 1), 5.0, true,
	)
	# Bowl.
	_stage_view.draw_circle(Vector2(cx, rim_y + 36), 8, Color(0.62, 0.48, 0.32, 1))
	_stage_view.draw_circle(Vector2(cx + 1, rim_y + 37), 5, Color(0.42, 0.32, 0.22, 1))

func _draw_lme_tin(sz: Vector2, counter_y: float) -> void:
	# LME tin on the counter to the right of the kettle. Tilts forward
	# (toward the kettle) when pouring.
	var cx: float = sz.x * 0.78
	var bot_y: float = counter_y - 4
	var w: float = 56.0
	var h: float = 70.0
	var top_y: float = bot_y - h
	# If pouring, scale h based on _pour_progress (tin gets emptier visually).
	var fill_h: float = lerpf(h - 10, 4.0, _pour_progress)
	# Tin body.
	_stage_view.draw_rect(Rect2(cx - w * 0.5, top_y, w, h), Color(0.62, 0.45, 0.18, 1))
	# Lid.
	_stage_view.draw_rect(Rect2(cx - w * 0.5 - 2, top_y - 4, w + 4, 6), Color(0.42, 0.30, 0.12, 1))
	# Empty space at top.
	_stage_view.draw_rect(Rect2(cx - w * 0.5 + 2, top_y + 4, w - 4, h - fill_h - 4), Color(0.32, 0.25, 0.12, 1))
	# Label.
	_stage_view.draw_rect(Rect2(cx - w * 0.5 + 4, top_y + 12, w - 8, 16), Color(0.92, 0.86, 0.72, 1))

func _position_hotspots(sz: Vector2, counter_y: float) -> void:
	# Stove dial hotspot.
	var dial_x: float = sz.x * 0.5 + 80
	var dial_y: float = counter_y - 10
	_burner_off_button.position = Vector2(dial_x - 20, dial_y - 22)
	_burner_off_button.size = Vector2(40, 40)
	# Spoon hotspot (covers the handle).
	var spoon_x: float = sz.x * 0.30
	var rim_y: float = counter_y - 28 - 130
	_stir_button.position = Vector2(spoon_x - 20, rim_y - 60)
	_stir_button.size = Vector2(40, 100)
	# LME tin hotspot.
	var tin_x: float = sz.x * 0.78
	var tin_y: float = counter_y - 80
	_lme_pour_button.position = Vector2(tin_x - 30, tin_y - 8)
	_lme_pour_button.size = Vector2(60, 80)
